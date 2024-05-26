# Use the official Airflow image as the base image
FROM apache/airflow:2.9.1

COPY requirements.txt /opt/airflow/

# Install AWS dependencies
RUN pip install --no-cache-dir -r /opt/airflow/requirements.txt

# Update PATH to include AWS CLI
ENV PATH=/root/.local/bin:$PATH
