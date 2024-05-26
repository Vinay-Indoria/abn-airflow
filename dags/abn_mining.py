from airflow import DAG
from airflow.providers.postgres.operators.postgres import PostgresOperator
from airflow.providers.common.sql.operators.sql import SQLExecuteQueryOperator
from airflow.operators.python_operator import PythonOperator, BranchPythonOperator
from airflow.utils.task_group import TaskGroup
from airflow.operators.dummy import DummyOperator
from airflow.decorators import task

from datetime import datetime, timedelta

import sys, os, logging

sys.path.append(os.getenv("AIRFLOW_HOME"))
from config.base_settings import (
    DEFAULT_SCHEMA,
    CCRWL_INDEX_TABLE,
    MINING_DAG_RUN_STAT_TABLE,
    DEFAULT_ABN_MINING_DOWNLOAD_PATH,
    MINING_DAG_ABN_DATA_TABLE,
    DEFAULT_DOWNLOAD_PATH,
    AIRFLOW_HOME
)
from includes.abn_mining.helper import (
    check_data_availability,
    download_S3_index_file,
    extract_index_file_from_path,
    clean_parse_extract_urls,
    check_au_urls_in_index_file,
    read_parquet_and_save_batches,
    batch_download_process,
    process_prefetched_files,
    insert_all_parquet_files
)
template_searchpath = os.path.join(AIRFLOW_HOME, 'includes', 'sql')

@task
def prefetch_and_process_s3_files(parquet_batch_index_path, download_path):
    with open(parquet_batch_index_path, "r") as f:
        batch_files = [line.strip() for line in f]

    total_files_processed = 0
    successfully_parsed = 0
    # we will cretae the directory if not present
    if not os.path.exists(download_path):
        os.makedirs(download_path)

    for batch_file in batch_files:
        for downloaded_path in batch_download_process(batch_file, download_path):
            logging.info(f'path yieled for - {downloaded_path}')
            batch_total_files_processed, batch_successful_parse = process_prefetched_files(downloaded_path)
            logging.info(f'Batch total, batch successful - {batch_total_files_processed}, {batch_successful_parse}')
            total_files_processed += batch_total_files_processed
            successfully_parsed += batch_successful_parse

    return {"total_downloaded_files_count": total_files_processed, "successful_parse_count": successfully_parsed}



# Configure DAG parameters
default_args = {
    "owner": "vinay",
    "retries": 0,
    "retry_delay": timedelta(minutes=2),
    "start_date": datetime(2024, 5, 15),  # Set your desired start date
}
with DAG(
    dag_id="ingest_cmoncrwl_abn_data",
    default_args=default_args,
    schedule_interval=None,  # Run manually or set a schedule here
    template_searchpath=[template_searchpath],
) as dag:

    # Fetch data from Postgres table
    with TaskGroup("retrieve_index_data") as data_access:
        # Define Postgres connection details (replace with your credentials)
        postgres_conn_id = "postgres_local"  # Replace with your connection ID
        # we will get only the filename
        sql_stmt = "SELECT file_name FROM {}.{} WHERE is_processed=False ORDER BY id limit 1".format(
            DEFAULT_SCHEMA, CCRWL_INDEX_TABLE
        )  # Replace with your query
        # Fetch data from Postgres table
        get_data = SQLExecuteQueryOperator(
            task_id="get_index_data_from_postgres",
            conn_id=postgres_conn_id,
            sql=sql_stmt,
            dag=dag,
        )

        # Check if data is returned (using XCom)
        check_data = PythonOperator(
            task_id="check_data_returned",
            python_callable=check_data_availability,
            trigger_rule="all_success",  # Run only if get_data succeeds
            provide_context=True,  # To access XCom values
            op_args=get_data.output,  # Dependency on get_data
            dag=dag,
        )

        get_data >> check_data

    # logging data for stats for given filename
    insert_dag_run_status = SQLExecuteQueryOperator(
        task_id="insert_dag_run_status",
        conn_id=postgres_conn_id,
        sql="""
        INSERT INTO {{ params.schema }}.{{ params.table }} (dag_run_id, file_name, execution_timestamp)
        VALUES ('{{ dag_run.run_id }}', '{{ ti.xcom_pull(task_ids='retrieve_index_data.check_data_returned', key='return_value') }}', '{{ ts }}')
        """,
        params={"schema": DEFAULT_SCHEMA, "table": MINING_DAG_RUN_STAT_TABLE},
        dag=dag,
    )

    download_index_file_from_S3_url = PythonOperator(
        task_id="download_index_from_S3_url",
        python_callable=download_S3_index_file,
        provide_context=True,  # To access XCom values
        trigger_rule="all_success",
        dag=dag,  # Added DAG reference
    )

    with TaskGroup("extract_urls") as file_cleanup_n_url_extraction:
        # we will first unzip the file we downloaded
        extract_downloaded_index_file = PythonOperator(
            task_id="extract_index_file",
            python_callable=extract_index_file_from_path,
            provide_context=True,  # To access XCom values
            trigger_rule="all_success",
            dag=dag,  # Added DAG reference
        )

        # we will now use spark to run through this file.
        # unzipped version of .gz index file can go upto 4 GB as well
        # we will extract only homepage, about, contact and
        extract_parsing_urls = PythonOperator(
            task_id="extract_parsing_urls",
            python_callable=clean_parse_extract_urls,
            provide_context=True,  # To access XCom values
            trigger_rule="all_success",
            dag=dag,  # Added DAG reference
        )

        # update stats
        update_dag_run_status = SQLExecuteQueryOperator(
            task_id="update_dag_run_status",
            conn_id=postgres_conn_id,
            sql="""
            UPDATE {{ params.schema }}.{{ params.table }} 
            SET total_records='{{ti.xcom_pull(task_ids="extract_urls.extract_parsing_urls", key="total_records")}}', 
            filtered_au_records='{{ti.xcom_pull(task_ids="extract_urls.extract_parsing_urls", key="filtered_au_records") | default(0, true)}}'
            WHERE dag_run_id='{{ dag_run.run_id }}'
            """,
            params={"schema": DEFAULT_SCHEMA, "table": MINING_DAG_RUN_STAT_TABLE},
            trigger_rule="all_success",
            dag=dag,
        )

        extract_downloaded_index_file >> extract_parsing_urls >> update_dag_run_status

    check_for_au_records = BranchPythonOperator(
        task_id="check_for_au_records",
        python_callable=check_au_urls_in_index_file,
        provide_context=True,
        trigger_rule="all_success",
        dag=dag,  # Added DAG reference
    )

    # one of the options in Branch operator if there is no records we will mark the file as processed in ccrwl_index
    mark_index_file_processed = SQLExecuteQueryOperator(
        task_id="mark_index_file_processed",
        conn_id=postgres_conn_id,
        sql="""
        UPDATE {{ params.schema }}.{{ params.table }} 
        SET is_processed='True' 
        WHERE file_name='{{ ti.xcom_pull(task_ids="retrieve_index_data.check_data_returned") }}'
        """,
        params={"schema": DEFAULT_SCHEMA, "table": CCRWL_INDEX_TABLE},
        trigger_rule="all_success",
        dag=dag,  # Added DAG reference
    )

    read_parquet_and_save_batches = PythonOperator(
        task_id="read_parquet_and_save_batches",
        python_callable=read_parquet_and_save_batches,
        provide_context=True,
        trigger_rule="all_success",
        dag=dag,  # Added DAG reference
    )

    end = DummyOperator(
        task_id="end",
        trigger_rule="all_success",
        dag=dag,  # Added DAG reference
    )

    # Prefetch and process S3 files in batches
    prefetch_process_files = prefetch_and_process_s3_files(
        parquet_batch_index_path='{{ti.xcom_pull(task_ids="read_parquet_and_save_batches")}}',
        download_path=DEFAULT_ABN_MINING_DOWNLOAD_PATH
    )

    # Add the task to the DAG
    insert_parquet_files_task = PythonOperator(
        task_id="insert_parquet_files_to_postgres",
        python_callable=insert_all_parquet_files,
        provide_context=True,
        op_kwargs={
            'download_path': os.path.join(DEFAULT_DOWNLOAD_PATH, '{{ ti.xcom_pull(task_ids="retrieve_index_data.check_data_returned") }}', 'processed'),
            'schema': DEFAULT_SCHEMA,  
            'table_name': MINING_DAG_ABN_DATA_TABLE,
            'index_file_name': '{{ ti.xcom_pull(task_ids="retrieve_index_data.check_data_returned") }}'
        },
        trigger_rule="all_success",
        dag=dag,
    )

    # SQL script to normalize and cleanup abn data
    normalize_abn_data = SQLExecuteQueryOperator(
        task_id=f'normalize_abn_data',
        sql='normalize_raw_abn_mining_data.sql',
        conn_id=postgres_conn_id,
        params={'task_id': 'insert_parquet_files_to_postgres'},
        autocommit=False, # we are managing commit in the script
    )

    # SQL script to normalize and cleanup abn data
    update_dag_index_stats_count = SQLExecuteQueryOperator(
        task_id=f'update_dag_index_stats_count',
        sql='update_abn_status_count.sql',
        conn_id=postgres_conn_id,
        params={
            'task_id': 'prefetch_and_process_s3_files',
            'file_name_task_id': 'insert_parquet_files_to_postgres',
            },
        autocommit=False, # we are managing commit in the script
    )

    # one of the options in Branch operator if there is no records we will mark the file as processed in ccrwl_index
    mark_index_file_processed_eof = SQLExecuteQueryOperator(
        task_id="mark_index_file_processed_eof",
        conn_id=postgres_conn_id,
        sql="""
        UPDATE {{ params.schema }}.{{ params.table }} 
        SET is_processed='True' 
        WHERE file_name='{{ ti.xcom_pull(task_ids="retrieve_index_data.check_data_returned") }}'
        """,
        params={"schema": DEFAULT_SCHEMA, "table": CCRWL_INDEX_TABLE},
        trigger_rule="all_success",
        dag=dag,  # Added DAG reference
    )

    # Set check_data as the downstream task (DAG exits if check_data fails)
    (
        data_access
        >> insert_dag_run_status
        >> download_index_file_from_S3_url
        >> file_cleanup_n_url_extraction
        >> check_for_au_records
    )
    check_for_au_records >> mark_index_file_processed >> end
    #check_for_au_records >> read_parquet_and_save_batches >> create_dynamic_process_tasks('{{ti.xcom_pull(task_ids="read_parquet_and_save_batches")}}') >> end
    check_for_au_records >> read_parquet_and_save_batches >> prefetch_process_files >> insert_parquet_files_task >> normalize_abn_data  >> update_dag_index_stats_count >> mark_index_file_processed_eof >> end
