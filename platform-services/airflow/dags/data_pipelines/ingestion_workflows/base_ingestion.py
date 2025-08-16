from datetime import datetime, timedelta
from airflow import DAG
from airflow.operators.python import PythonOperator

default_args = {
    'owner': 'finportiq',
    'depends_on_past': False,
    'start_date': datetime(2024, 1, 1),
    'email_on_failure': False,
    'email_on_retry': False,
    'retries': 1,
    'retry_delay': timedelta(minutes=5)
}

def extract_data(**context):
    """Extract data from BASE layer components"""
    print("Extracting data from BASE layer...")
    return "extraction_complete"

def transform_data(**context):
    """Transform data using BASE layer processing"""
    print("Transforming data...")
    return "transformation_complete"

def load_data(**context):
    """Load data to destination"""
    print("Loading data...")
    return "load_complete"

with DAG(
    'base_data_ingestion',
    default_args=default_args,
    description='BASE layer data ingestion pipeline',
    schedule_interval=timedelta(hours=1),
    catchup=False,
    tags=['base-layer', 'ingestion']
) as dag:

    extract_task = PythonOperator(
        task_id='extract_data',
        python_callable=extract_data
    )

    transform_task = PythonOperator(
        task_id='transform_data',
        python_callable=transform_data
    )

    load_task = PythonOperator(
        task_id='load_data',
        python_callable=load_data
    )

    extract_task >> transform_task >> load_task
