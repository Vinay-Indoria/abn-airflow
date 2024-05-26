from includes.utils import remove_extension, extract_australian_entity_name, extract_australian_industries, extract_abn, get_domain
from airflow.providers.amazon.aws.hooks.s3 import S3Hook
from warcio.archiveiterator import ArchiveIterator
from airflow.exceptions import AirflowFailException
from io import BytesIO
from bs4 import BeautifulSoup
from aiohttp import ClientSession
import pandas as pd
import logging
import os
import gzip
import shutil
import re
import asyncio

from config.base_settings import (
    BASE_CCRWL_S3_BUCKET,
    BASE_CCRWL_S3_INDEX_KEY_PATH,
    DEFAULT_DOWNLOAD_PATH,
    INDEX_FILE_PARQUET_BATCH_SIZE,
    CCRAWL_HTTPS_DOMAIN,
    DEFAULT_ABN_MINING_DOWNLOAD_PATH,
    POSTGRES_CONN_ID
)

from includes.utils import ( batch_insert_postgres, remove_null_chars )

def check_data_availability(op_args, **kwargs):
    # Access data returned by get_data using XCom
    index_data_xcom_arr = op_args
    if index_data_xcom_arr:
        # pulling the first tuple element of the first array
        # since we have data then we are sure we have the filename
        file_name = index_data_xcom_arr[0]
        logging.info("File name retrieved from database: {}".format(file_name))

        return file_name
    else:
        raise AirflowFailException("No data returned from Postgres table.")


def download_S3_index_file(**kwargs):
    # Access data returned by check_data using XCom
    # we are sure.. we will get something here
    ti = kwargs["ti"]
    file_name = ti.xcom_pull(task_ids="retrieve_index_data.check_data_returned")
    if not file_name:
        raise AirflowFailException("No file name found.")

    # location where we will store our file
    # /opt/airflow/data/xxx.gz
    destination_path = DEFAULT_DOWNLOAD_PATH + "{}".format(file_name)

    # we will not download the file if it exists
    # we can further decide if we need to delete existing file and create new
    if os.path.exists(destination_path):
        logging.info(f"File {destination_path} already exists")
        # Delete the folder and its contents
        shutil.rmtree(destination_path)

    try:
        s3_hook = S3Hook(aws_conn_id="aws_conn")
        # ${AIRFLOW_HOME}/data/${file_name}
        destination_path = DEFAULT_DOWNLOAD_PATH + "{}".format(file_name)
        complete_S3_key = "{}{}".format(BASE_CCRWL_S3_INDEX_KEY_PATH, file_name)
        logging.info(
            f"Successfully downloaded {complete_S3_key} from bucket {BASE_CCRWL_S3_BUCKET} to {destination_path}"
        )
        # the generated filename looks like
        # ${AIRFLOW_HOME}/data/${file_name}/airflow_tmp_***/${file_name}
        local_file_name = s3_hook.download_file(
            key=complete_S3_key,
            bucket_name=BASE_CCRWL_S3_BUCKET,
            local_path=destination_path,
            preserve_file_name=True,
        )
        logging.info(
            f"Successfully downloaded {complete_S3_key} from bucket {BASE_CCRWL_S3_BUCKET} to {destination_path}"
        )

        return local_file_name
    except Exception as e:
        raise AirflowFailException("{}".format(e))


def extract_index_file_from_path(**kwargs):
    ti = kwargs["ti"]
    destination_path = ti.xcom_pull(task_ids="download_index_from_S3_url")

    if not destination_path:
        raise AirflowFailException("No destination path found.")

    destination_path_wo_ext = remove_extension(destination_path)

    try:
        with gzip.open(destination_path, "rb") as f_in:
            with open(destination_path_wo_ext, "wb") as f_out:
                shutil.copyfileobj(f_in, f_out)
        logging.info(f"Extracted {destination_path} to {destination_path_wo_ext}")

        return destination_path_wo_ext
    except Exception as e:
        logging.error(f"An error occurred during extraction: {e}")
        raise AirflowFailException(f"An error occurred during extraction: {e}")


def process_index_file_line(line):
    """
    Processes a single line from the file.

    Args:
        line: A string containing a line from the file.

    Returns:
        A dictionary containing extracted fields (url, status, mime, etc.)
            if the line matches the AU domain pattern and has a status of 200.
        None otherwise.
    """
    # early exit if there is no .au
    if ".au" not in line:
        return None

    url_pattern = r'"url": "(.*?)"'
    status_pattern = r'"status": "(.*?)"'
    mime_pattern = r'"mime": "(.*?)"'
    length_pattern = r'"length": "(.*?)"'
    offset_pattern = r'"offset": "(.*?)"'
    filename_pattern = r'"filename": "(.*?)"'

    # Extract fields using regular expressions
    url = (
        re.search(url_pattern, line).group(1) if re.search(url_pattern, line) else None
    )
    status = (
        re.search(status_pattern, line).group(1)
        if re.search(status_pattern, line)
        else None
    )
    mime = (
        re.search(mime_pattern, line).group(1)
        if re.search(mime_pattern, line)
        else None
    )
    length = (
        re.search(length_pattern, line).group(1)
        if re.search(length_pattern, line)
        else None
    )
    offset = (
        re.search(offset_pattern, line).group(1)
        if re.search(offset_pattern, line)
        else None
    )
    filename = (
        re.search(filename_pattern, line).group(1)
        if re.search(filename_pattern, line)
        else None
    )

    domain_start_pattern = r"^(https?://[^/]*\.au(?:/|$))(?:about|privacy|contact)?$"
    # Check if URL matches AU domain pattern and status is 200
    if url and re.match(domain_start_pattern, url) and status == "200":
        return {
            "url": url,
            "status": status,
            "mime": mime,
            "length": length,
            "offset": offset,
            "filename": filename,
            "line": line,
        }
    else:
        return None


def clean_parse_extract_urls(**kwargs):
    ti = kwargs["ti"]
    raw_file_name = ti.xcom_pull(task_ids="extract_urls.extract_index_file")

    if not raw_file_name:
        raise AirflowFailException("Not able to find the extracted file path.")
    total_records = 0
    ti.xcom_push(key="total_records", value=13870847)
    ti.xcom_push(key="au_data_present", value=True)
    ti.xcom_push(key="filtered_au_records", value=174305)
    
    # Open the file for reading
    with open(raw_file_name, "r") as f:
        # Initialize an empty list to store filtered data
        filtered_data = []
        for line in f:
            total_records += 1
            # Process each line and append to filtered data if valid
            result = process_index_file_line(line.strip())
            if result:
                filtered_data.append(result)
    # total number of records for reference
    ti.xcom_push(key="total_records", value=total_records)

    # Check if any data was filtered
    if filtered_data:
        # Create a pandas DataFrame from the filtered data list
        au_domain_df = pd.DataFrame(filtered_data)
        # we will keep only unique records
        au_domain_df = au_domain_df.drop_duplicates(subset=["url"])
        # total number of filtered_records
        ti.xcom_push(key="filtered_au_records", value=au_domain_df.shape[0])
        parquet_dest = os.path.join(
            DEFAULT_DOWNLOAD_PATH, "parquet", os.path.basename(raw_file_name)
        )
        # Save the DataFrame to Parquet format
        au_domain_df.to_parquet(parquet_dest)
        print("Filtering and saving successful!")
        ti.xcom_push(key="au_data_present", value=True)
        return parquet_dest
    else:
        print("No data matched the filtering criteria.")
        ti.xcom_push(key="au_data_present", value=False)


def check_au_urls_in_index_file(**kwargs):
    ti = kwargs["ti"]
    au_data_present = ti.xcom_pull(
        task_ids="extract_urls.extract_parsing_urls", key="au_data_present"
    )

    if bool(au_data_present):
        # data present
        return "read_parquet_and_save_batches"
    else:
        return "mark_index_file_processed"


# helper function to read BATCH_SIZE records from a data frame and write to local_file_batch_parquet_dir directory in BATCH_SIZE record size parquet files
def save_batches_to_local(df, local_file_batch_parquet_dir, BATCH_SIZE):
    batches = []
    total_batches = (len(df) // BATCH_SIZE) + 1
    for i in range(total_batches):
        batch_df = df[i * BATCH_SIZE : (i + 1) * BATCH_SIZE]
        batch_file = f"batch_{i}.parquet"
        batch_path = f"{local_file_batch_parquet_dir}/{batch_file}"
        batch_df.to_parquet(batch_path)
        batches.append(batch_path)
    return batches


def read_parquet_and_save_batches(**kwargs):
    ti = kwargs["ti"]
    filtered_index_file_parquet = ti.xcom_pull(
        task_ids="extract_urls.extract_parsing_urls"
    )

    if not filtered_index_file_parquet:
        raise AirflowFailException(
            f"Not able to find the Parquet version of filtered au records"
        )

    # filtered_index_file_parquet format /opt/airflow/data/parquet/cdx-00004
    # we will create a path similar to /opt/airflow/data/parquet/batch/cdx-00004/ to hold the batch files
    parquet_directory = os.path.dirname(filtered_index_file_parquet)
    current_file_name = os.path.basename(filtered_index_file_parquet)

    # we will create a path similar to /opt/airflow/data/parquet/batch/cdx-00004/ to hold the batch files
    current_file_batch_dir = os.path.join(parquet_directory, "batch", current_file_name)
    if not os.path.exists(current_file_batch_dir):
        os.makedirs(current_file_batch_dir)

    # index of all the batch files created - /opt/airflow/data/parquet/batch/cdx-00004/index
    parquet_batch_index_path = os.path.join(current_file_batch_dir, "index")
    
    # reading the given parquet path
    df = pd.read_parquet(filtered_index_file_parquet)

    # breaking the big file into smaller chunks for processing of size INDEX_FILE_PARQUET_BATCH_SIZE records
    batches = save_batches_to_local(
        df, current_file_batch_dir, INDEX_FILE_PARQUET_BATCH_SIZE
    )

    # Save the batch paths to an index file
    # a single file where we have list of all paths that have to be processed
    with open(parquet_batch_index_path, "w") as f:
        for batch in batches:
            f.write(f"{batch}\n")

    # passing it down
    return parquet_batch_index_path

# download files in batches
def batch_download_process(batch_file, download_path, batch_size=250):
    # batch file woudl look like $AIRFLOW_HOME/data/parquet/batch/{cdx-00004}/batch_{0}.parquet
    logging.info(f'batch_download_process started for - {batch_file}')
    df = pd.read_parquet(batch_file)
    # getting the batch name out of the base_filename
    batch_file_name, _ = os.path.splitext(os.path.basename(batch_file))
    # getting the {cdx-00004} part from the batch_file path
    index_file_name = os.path.basename(os.path.dirname(batch_file))
    # keeping downloads path according to index file name like $AIRFLOW_HOME/data/abn_mining/downloads/{cdx-00004}
    index_specific_download_path = os.path.join(download_path, index_file_name)
    # create the specific directory if not exists
    if not os.path.exists(index_specific_download_path):
        os.makedirs(index_specific_download_path)

    s3_file_info = [(f'{CCRAWL_HTTPS_DOMAIN}{row["filename"]}', int(row["offset"]), int(row["length"]), row["filename"], row["url"]) for _, row in df.iterrows()]
    
    total_files = len(s3_file_info)
    for start in range(0, total_files, batch_size):
        end = min(start + batch_size, total_files)
        batch_identifier = f"{batch_file_name}_batch_{start}_{end}"

        # keeping downloads path according to index and batch file name like $AIRFLOW_HOME/data/abn_mining/downloads/{cdx-00004}/batch_{0}_{250}
        batch_specific_download_path = os.path.join(index_specific_download_path, batch_identifier)
        if not os.path.exists(batch_specific_download_path):
            os.makedirs(batch_specific_download_path)

        asyncio.run(download_files_in_batch(s3_file_info[start:end], batch_specific_download_path))
        yield batch_specific_download_path

async def download_files_in_batch(s3_file_info, download_path):
    session = ClientSession()
    tasks = []
    try:
        for info in s3_file_info:
            s3_url, offset, length, filename, url = info
            local_path = os.path.join(download_path, os.path.basename(filename))
            tasks.append(fetch_warc_file(session, s3_url, offset, length, local_path))
        await asyncio.gather(*tasks)
    finally:
        await session.close()

async def fetch_warc_file(session, s3_url, offset, length, local_path):
    headers = {'Range': f'bytes={offset}-{offset+length-1}'}
    async with session.get(s3_url, headers=headers) as response:
        if response.status == 206:
            with open(local_path, 'wb') as f:
                while True:
                    chunk = await response.content.read(1024)  # Adjust the chunk size as needed
                    if not chunk:
                        break
                    f.write(chunk)
        else:
            logging.error(f"Failed to fetch data: {response.status} for {s3_url}")

def process_prefetched_files(download_path):
    df_columns = ['warc_url', 'warc_date', 'content', 'warc_filename', 'domain', 'abn_number', 'industries', 'business_entity_name']
    records_df = pd.DataFrame(columns=df_columns)
    # since the url is $AIRFLOW_HOME/data/abn_mining/downloads/{cdx-00004}/batch_{0}_{250}
    # we need cdx-00004 fro mthe givne URL
    main_file = os.path.basename(os.path.dirname(download_path))
    processed_file_path = os.path.join(DEFAULT_DOWNLOAD_PATH,f'{main_file}.gz','processed')
    failed_file_path = os.path.join(DEFAULT_DOWNLOAD_PATH,f'{main_file}.gz','failed')
    logging.info(f'Processed path - {processed_file_path}')
    logging.info(f'Failed path - {failed_file_path}')

    if not os.path.exists(processed_file_path):
        os.makedirs(processed_file_path)
    
    if not os.path.exists(failed_file_path):
        os.makedirs(failed_file_path)
        
    total_file_records = 0
    failed_parsing = []
    
    for root, _, files in os.walk(download_path):
        for file in files:
            total_file_records += 1
            batch_file_path = os.path.join(root, file)
            file_records = process_local_warc(batch_file_path)
            if file_records:
                records_df = pd.concat([records_df, pd.DataFrame(file_records)], ignore_index=True)
            else:
                failed_parsing.append(batch_file_path)
    
    if not records_df.empty:
        output_file = os.path.join(processed_file_path, f'{os.path.basename(download_path)}.parquet')
        records_df.to_parquet(output_file, index=False) 
    
    if failed_parsing:
        failed_df = pd.DataFrame(failed_parsing)
        failed_file = os.path.join(failed_file_path, f'{os.path.basename(download_path)}.parquet')
        failed_df.to_parquet(failed_file, index=False)
            
    return total_file_records, records_df.shape[0]

def process_local_warc(file_path):
    try:
        with open(file_path, 'rb') as f:
            compressed_content = f.read()
            with gzip.GzipFile(fileobj=BytesIO(compressed_content)) as gz:
                warc_content = gz.read()

            stream = BytesIO(warc_content)
            records = []
            for record in ArchiveIterator(stream):
                content = record.content_stream().read()
                record_data = {
                    'warc_url': record.rec_headers.get_header('WARC-Target-URI'),
                    'warc_date': record.rec_headers.get_header('WARC-Date'),
                    'domain': get_domain(record.rec_headers.get_header('WARC-Target-URI')),
                    'content': content,
                }
                record_data['warc_filename'] = os.path.basename(file_path)

                html_parsed_soup_obj = BeautifulSoup(content, 'html.parser')
                content_text = html_parsed_soup_obj.get_text()
                record_data['business_entity_name'] = extract_australian_entity_name(content_text)
                record_data['industries'] = extract_australian_industries(content_text)
                record_data['abn_number'] = extract_abn(content_text)
                # cleaning abn number ofr spaces and non-braking space in bytes like \xA0
                if record_data['abn_number']:
                    record_data['abn_number'] = re.sub(r'\s+', '', record_data['abn_number'])
                records.append(record_data)

            return records
    except Exception as e:
        logging.error(f"Error processing WARC record - {file_path}: {e}")
        return None

def insert_all_parquet_files(**kwargs):
    download_path = kwargs['download_path']
    table_name = kwargs['table_name']
    schema = kwargs['schema']
    index_file_name = kwargs['index_file_name']
    
    parquet_files = list_parquet_files(download_path)
    insert_parquet_to_postgres(parquet_files, index_file_name, schema, table_name, POSTGRES_CONN_ID)
    return index_file_name

def list_parquet_files(download_path):
    parquet_files = []
    for root, _, files in os.walk(download_path):
        for file in files:
            if file.endswith(".parquet"):
                parquet_files.append(os.path.join(root, file))
    return parquet_files

def insert_parquet_to_postgres(parquet_file_paths, index_file_name, schema, table_name, postgres_conn_id):
    insert_sql = f"INSERT INTO {schema}.{table_name} (warc_url, warc_date, page_content, warc_file_name, domain_name, abn, industries, business_entity_name, index_file_name) VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s)"  # Adjust columns as needed

    for parquet_file in parquet_file_paths:
        df = pd.read_parquet(parquet_file)
        # Add the static value 'index_file_name' to the DataFrame
        df['index_file_name'] = index_file_name
        # Remove null characters from all string columns
        df = df.applymap(remove_null_chars)
        logging.info(f'working with batch file - {parquet_file}')
        data = df.to_records(index=False).tolist()
        batch_insert_postgres(insert_sql, data, postgres_conn_id, batch_size=250)
        logging.info(f"Inserted data from {parquet_file} into {table_name}")