from pyspark.sql import SparkSession
from pyspark.sql.functions import col, udf
from pyspark.sql.types import StringType
import re, sys, os, logging

SPARK_PARQUET_BASE_PATH = "/data/parquet/"


# Define a User Defined Function (UDF) to extract individual fields
def extract_field(text, pattern):
    match = re.search(pattern, text)
    if match:
        return match.group(1)
    else:
        return None


def read_and_clean_file(file_path):
    file_name = os.path.basename(file_path)
    df = spark.read.text(file_path)
    # rename the given default column
    df = df.withColumnRenamed("value", "page_details")
    # new data set for only .au in the read data
    au_df = df.filter(df.page_details.like("%.au%"))

    # some patterns to clean and pull specific data into individual columns
    url_pattern = r'"url": "(.*?)"'
    status_pattern = r'"status": "(.*?)"'
    mime_pattern = r'"mime": "(.*?)"'
    length_pattern = r'"length": "(.*?)"'
    offset_pattern = r'"offset": "(.*?)"'
    filename_pattern = r'"filename": "(.*?)"'

    # Register the UDFs
    extract_url_udf = udf(lambda text: extract_field(text, url_pattern), StringType())
    extract_status_udf = udf(
        lambda text: extract_field(text, status_pattern), StringType()
    )
    extract_mime_udf = udf(lambda text: extract_field(text, mime_pattern), StringType())
    extract_length_udf = udf(
        lambda text: extract_field(text, length_pattern), StringType()
    )
    extract_offset_udf = udf(
        lambda text: extract_field(text, offset_pattern), StringType()
    )
    extract_filename_udf = udf(
        lambda text: extract_field(text, filename_pattern), StringType()
    )

    # Apply the UDFs to extract individual fields
    au_df = au_df.withColumn("url", extract_url_udf(au_df["page_details"]))
    au_df = au_df.withColumn("status", extract_status_udf(au_df["page_details"]))
    au_df = au_df.withColumn("mime", extract_mime_udf(au_df["page_details"]))
    au_df = au_df.withColumn("length", extract_length_udf(au_df["page_details"]))
    au_df = au_df.withColumn("offset", extract_offset_udf(au_df["page_details"]))
    au_df = au_df.withColumn("filename", extract_filename_udf(au_df["page_details"]))

    # pattern to pull homepage, about, privacy and contact pages
    pattern = r"^(https?://[^/]*\.au(?:/|$))(?:about|privacy|contact)?$"
    # Check if the URL matches the pattern
    has_au_domain = au_df.filter(col("url").rlike(pattern))
    # we will pull only 200 status code domains
    has_au_domain_succcess = has_au_domain.filter(col("status") == 200)
    # as the final step we would remove duplicates from URL
    au_filtered_no_duplicates = has_au_domain_succcess.dropDuplicates(["url"])
    # spark local cluster has /data directory, we will export the given dataset to parquet format
    # path would look like /data/parquet/cdx-0004
    df_parquet_export_path = f"{SPARK_PARQUET_BASE_PATH}{file_name}"
    au_filtered_no_duplicates.write.parquet(df_parquet_export_path)
    return df_parquet_export_path


if __name__ == "__main__":
    # Check if the correct number of arguments is provided
    """if len(sys.argv) != 2:
    print('Usage: clean_extract_parsing_url.py <file_path>')
    sys.exit(1)"""
    logging.info("{}".format(sys.argv[1]))
    # Retrieve the file path argument from command-line
    file_path = sys.argv[1]

    # Create SparkSession
    spark = SparkSession.builder.appName("Read index File").getOrCreate()

    try:
        read_and_clean_file(file_path)
    except Exception as e:
        print(f"An error occurred: {e}")
        sys.exit(1)
    finally:
        spark.stop()
