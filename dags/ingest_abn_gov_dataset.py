from airflow import DAG
from airflow.operators.python_operator import PythonOperator
from airflow.providers.common.sql.operators.sql import SQLExecuteQueryOperator
from datetime import datetime
import os,sys, logging
import pandas as pd

sys.path.append(os.getenv("AIRFLOW_HOME"))
from config.base_settings import (
    DEFAULT_ABN_AU_GOV_DATASET_PATH,
    POSTGRES_CONN_ID,
    AIRFLOW_HOME
)
from includes.ingest_abn_gov_dataset.helper import (
    parse_and_load_xml,
    insert_raw_abr_data,
    insert_raw_dgr_data,
    insert_raw_other_entity_data
)
from includes.utils import ( save_to_parquet )

postgres_conn_id = POSTGRES_CONN_ID
# Define the template directory
template_searchpath = os.path.join(AIRFLOW_HOME, 'includes', 'sql')


def process_file(file_path, **kwargs):
    logging.info(f'Executing Process_file for - {file_path}')
    parsed_file_path = os.path.join(DEFAULT_ABN_AU_GOV_DATASET_PATH, 'parsed', os.path.basename(file_path))
    # Push the file name to XCom
    file_name = os.path.basename(file_path)
    kwargs['ti'].xcom_push(key='file_name', value=file_name)

    if os.path.exists(os.path.join(parsed_file_path, 'abr_data.parquet')):
        return file_path
    
    abr_data, dgr_data, other_entity_data = parse_and_load_xml(file_path)
    logging.info(f'parsed file for - {file_path}')
    
    # chec kif directory is present for $AIRFLOW_HOME/data/abn_master_dataset/parsed/$file_name
    if not os.path.exists(parsed_file_path):
        os.makedirs(parsed_file_path)
    
    # Save data to Parquet files
    save_to_parquet(abr_data, os.path.join(parsed_file_path, 'abr_data.parquet'))
    save_to_parquet(dgr_data, os.path.join(parsed_file_path, 'dgr_data.parquet'))
    save_to_parquet(other_entity_data, os.path.join(parsed_file_path, 'other_entity_data.parquet'))

    return file_path

def insert_raw_abr_data_task(file_path, **kwargs):
    logging.info(f'inserting abn data for - {file_path}')
    abr_data = pd.read_parquet(os.path.join(file_path, 'abr_data.parquet'))
    abr_data_records = abr_data.astype(object).where(pd.notnull(abr_data), None).to_records(index=False)
    insert_raw_abr_data(abr_data_records)

def insert_raw_dgr_data_task(file_path, **kwargs):
    logging.info(f'inserting abr data for - {file_path}')
    dgr_data = pd.read_parquet(os.path.join(file_path, 'dgr_data.parquet'))
    dgr_data_records = dgr_data.astype(object).where(pd.notnull(dgr_data), None).to_records(index=False)
    insert_raw_dgr_data(dgr_data_records)

def insert_raw_other_entity_data_task(file_path, **kwargs):
    logging.info(f'inserting other entity data for - {file_path}')
    other_entity_data = pd.read_parquet(os.path.join(file_path, 'other_entity_data.parquet'))
    other_entity_data_records = other_entity_data.astype(object).where(pd.notnull(other_entity_data), None).to_records(index=False)
    insert_raw_other_entity_data(other_entity_data_records)


# Define default arguments
default_args = {
    'owner': 'vinay',
    'start_date': datetime(2024, 5, 1),
    'retries': 0
}
# DAG
with DAG('ingest_au_gov_data', default_args=default_args, schedule_interval=None, template_searchpath=[template_searchpath]) as dag:
    
    previous_task = None
    for file_name in os.listdir(DEFAULT_ABN_AU_GOV_DATASET_PATH):
        if file_name.endswith('.xml'):
            full_file_path = os.path.join(DEFAULT_ABN_AU_GOV_DATASET_PATH, file_name)
            parsed_file_path = os.path.join(DEFAULT_ABN_AU_GOV_DATASET_PATH, 'parsed', file_name)
            task_id = f'parse_and_load_{file_name.split(".")[0]}'
            
            parse_and_load_task = PythonOperator(
                task_id=task_id,
                python_callable=process_file,
                op_kwargs={'file_path': full_file_path},
                provide_context=True,
                pool='limited_simultaneous_pool'
            )

            insert_abr_task = PythonOperator(
                task_id=f'insert_raw_abr_data_{file_name.split(".")[0]}',
                python_callable=insert_raw_abr_data_task,
                op_kwargs={'file_path': parsed_file_path},
                provide_context=True,
                pool='limited_simultaneous_pool'
            )

            insert_dgr_task = PythonOperator(
                task_id=f'insert_raw_dgr_data_{file_name.split(".")[0]}',
                python_callable=insert_raw_dgr_data_task,
                op_kwargs={'file_path': parsed_file_path},
                provide_context=True,
                pool='limited_simultaneous_pool'
            )

            insert_other_entity_task = PythonOperator(
                task_id=f'insert_raw_other_entity_data_{file_name.split(".")[0]}',
                python_callable=insert_raw_other_entity_data_task,
                op_kwargs={'file_path': parsed_file_path},
                provide_context=True,
                pool='limited_simultaneous_pool'
            )

            # SQL script execution task for each parsed file
            sql_task = SQLExecuteQueryOperator(
                task_id=f'execute_sql_script_{task_id}',
                sql='normalize_raw_abn_gov_dataset.sql',
                conn_id=postgres_conn_id,
                params={'task_id': f'{task_id}'},
                autocommit=False, # we are managing commit in the script
                pool='limited_simultaneous_pool'
            )

            # Setting dependencies
            if previous_task:
                previous_task >> parse_and_load_task

            parse_and_load_task >> insert_abr_task >> insert_dgr_task >> insert_other_entity_task >> sql_task
            
            # Updating previous_task to the last task of the current chain
            previous_task = sql_task

    
