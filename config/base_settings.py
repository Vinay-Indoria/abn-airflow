import os

# imported from .env
DEFAULT_SCHEMA = os.environ.get("DEFAULT_SCHEMA")
CCRWL_INDEX_TABLE = os.environ.get("CCRWL_INDEX_TABLE")
BASE_CCRWL_S3_INDEX_URL = os.environ.get("BASE_CCRWL_S3_INDEX_URL")
# BASE_CCRWL_INDEX_URL = os.environ.get('BASE_CCRWL_INDEX_URL')
BASE_CCRWL_S3_BUCKET = os.environ.get("BASE_CCRWL_S3_BUCKET")
BASE_CCRWL_S3_INDEX_KEY_PATH = os.environ.get("BASE_CCRWL_S3_INDEX_KEY_PATH")
CCRAWL_HTTPS_DOMAIN = os.getenv("CCRAWL_HTTPS_DOMAIN")
AIRFLOW_HOME = os.getenv("AIRFLOW_HOME")
DEFAULT_REL_DOWNLOAD_PATH = os.getenv("DEFAULT_REL_DOWNLOAD_PATH")
DEFAULT_REL_ABN_AU_GOV_DATASET = os.getenv("DEFAULT_REL_ABN_AU_GOV_DATASET")

# derived
if not AIRFLOW_HOME:
    raise ValueError("Environment variable AIRFLOW_HOME is not set.")
if not DEFAULT_REL_DOWNLOAD_PATH:
    raise ValueError("Environment variable DEFAULT_REL_DOWNLOAD_PATH is not set.")
if not DEFAULT_REL_ABN_AU_GOV_DATASET:
    raise ValueError("Environment variable DEFAULT_REL_ABN_AU_GOV_DATASET is not set.")

DEFAULT_DOWNLOAD_PATH = os.path.join(AIRFLOW_HOME, DEFAULT_REL_DOWNLOAD_PATH)
DEFAULT_ABN_AU_GOV_DATASET_PATH = os.path.join(AIRFLOW_HOME, DEFAULT_REL_DOWNLOAD_PATH, DEFAULT_REL_ABN_AU_GOV_DATASET)
DEFAULT_ABN_MINING_DOWNLOAD_PATH = os.path.join(DEFAULT_DOWNLOAD_PATH, 'abn_mining', 'downloads')

# constants
POSTGRES_CONN_ID = 'postgres_local'
MINING_DAG_RUN_STAT_TABLE = "mining_dag_run_stats"
MINING_DAG_ABN_DATA_TABLE = "mining_abn_data_raw"
INDEX_FILE_PARQUET_BATCH_SIZE = 1000
AUSTRALIAN_INDUSTRIES = [
    "Agriculture", "Mining", "Manufacturing", "Construction", "Wholesale Trade", "Retail Trade",
    "Accommodation and Food Services", "Transport and Logistics", "Information Media and Telecommunications",
    "Financial and Insurance Services", "Rental, Hiring, and Real Estate Services",
    "Professional, Scientific, and Technical Services", "Administrative and Support Services",
    "Public Administration and Safety", "Education and Training", "Health Care and Social Assistance",
    "Arts and Recreation Services", "Utilities"
]
ENTITY_SUFFIXES = [
    "Pty Ltd", "Ltd", "NL", "Incorporated", "Inc", "Co-operative Ltd", "Corporation",
    "Partnership", "Unit Trust", "Sole Trader", "Association Inc", "Co-operative"
]
