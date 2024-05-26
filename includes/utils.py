from airflow.exceptions import AirflowFailException
from airflow.hooks.postgres_hook import PostgresHook
from config.base_settings import ENTITY_SUFFIXES, AUSTRALIAN_INDUSTRIES, POSTGRES_CONN_ID
from urllib.parse import urlparse
import pandas as pd
import numpy as np
import requests
import logging
import os
import re


def download_file_from_url_to_local(url, destination_path):
    try:
        response = requests.get(url)
        response.raise_for_status()  # Check that the request was successful\

        with open(destination_path, "wb") as file:
            file.write(response.content)

        return destination_path

    except requests.RequestException as e:
        logging.error(f"Failed to download file from {url}: {e}")
        raise AirflowFailException(f"Failed to download file: {e}")


def remove_extension(file_path):
    root, _ = os.path.splitext(file_path)
    return root

def extract_australian_entity_name(html_text_content):
    # Check for copyright text with copyright symbol
    copyright_pattern = re.compile(r'(?:&copy;|&#169;)\s*([^<]+)', re.IGNORECASE)
    copyright_match = copyright_pattern.search(html_text_content)
    if copyright_match:
        # Extract the entity name
        entity_name = copyright_match.group(1).strip()
        # Check if the entity name includes one of the specified suffixes
        if any(suffix in entity_name for suffix in ENTITY_SUFFIXES):
            return entity_name
    
    # Fallback to original method
    # Create a regex pattern to start from any special character followed by any characters
    pattern = re.compile(r'[^\w\s]\s*([^<]+)', re.IGNORECASE)

    match = pattern.search(html_text_content)

    # Extract the first entity name if a match is found
    if match:
        # Extract the entity name from the special character
        entity_name = match.group(1).strip()
        # Check if the entity name includes one of the specified suffixes
        if any(suffix in entity_name for suffix in ENTITY_SUFFIXES):
            return entity_name
    else:
        return None

def extract_australian_industries(html_text_content):
    html_text_content_lower = html_text_content.lower()
    # Convert industries list to lowercase for case-insensitive matching
    industries_lower = [industry.lower() for industry in AUSTRALIAN_INDUSTRIES]
    # Check for the presence of industries
    mentioned_industries = [industry for industry in industries_lower if industry in html_text_content_lower]
    # Print the results
    if mentioned_industries:
        # we will send comma separated list
        return ','.join(mentioned_industries)
    else:
        return None

def extract_abn(html_text_content):
    # Regular expression pattern to match ABN numbers in various formats
    abn_pattern = r"\bABN\b[\s:]*([0-9]{2}[\s]?[0-9]{3}[\s]?[0-9]{3}[\s]?[0-9]{3})"
    # Find all matches in the HTML content
    matches = re.findall(abn_pattern, html_text_content)
    # If there are matches, return the first one
    if matches:
        return matches[0]
    return None

# Function to extract the domain from a URL
def get_domain(url):
    parsed_url = urlparse(url)
    return parsed_url.netloc

def adapt_value(val):
    if isinstance(val, pd.Timestamp):
        return val.to_pydatetime() if not pd.isnull(val) else None
    elif isinstance(val, pd._libs.tslibs.nattype.NaTType):
        return None
    elif isinstance(val, (pd.Timedelta, pd.Timedelta)):
        return str(val) if not pd.isnull(val) else None
    elif isinstance(val, (pd._libs.interval.Interval, pd.Interval)):
        return str(val) if not pd.isnull(val) else None
    elif isinstance(val, pd.Period):
        return str(val) if not pd.isnull(val) else None
    elif isinstance(val, pd.Categorical):
        return val.categories[val.codes] if not pd.isnull(val) else None
    elif isinstance(val, (int, float, bool)):
        return val
    elif pd.isnull(val):
        return None
    elif isinstance(val, (np.generic, np.ndarray)):
        return val.item()
    else:
        return val

def batch_insert(cursor, insert_sql, data, batch_size=50000):
    for i in range(0, len(data), batch_size):
        batch = data[i:i+batch_size]
        cursor.executemany(insert_sql, batch)
        

def batch_insert_postgres(sql, data, conn_id = POSTGRES_CONN_ID, batch_size = 50000):
    postgres_hook = PostgresHook(postgres_conn_id=conn_id)
    conn = postgres_hook.get_conn()
    cur = conn.cursor()
    adapted_data = [
        tuple(map(adapt_value, row)) for row in data
    ]
    batch_insert(cur, sql, adapted_data, batch_size)
    conn.commit()
    cur.close()
    conn.close()

def save_to_parquet(data, file_path):
    df = pd.DataFrame(data)
    df.to_parquet(file_path, index=False)

def remove_null_chars(s):
    if isinstance(s, str):
        return s.replace('\x00', '')
    return s