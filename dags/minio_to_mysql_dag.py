from datetime import datetime, timedelta
from airflow import DAG
from airflow.operators.python import PythonOperator
from openlineage.airflow import OpenLineageProvider
from openlineage.client.run import Dataset
from openlineage.common.dataset import Source, Field
from openlineage.common.models import DbTableName
from minio import Minio
import pandas as pd
import pymysql
import io
import os

# OpenLineage configuration
OPENLINEAGE_URL = "http://localhost:5000"
os.environ['OPENLINEAGE_URL'] = OPENLINEAGE_URL
os.environ['OPENLINEAGE_API_KEY'] = ''

default_args = {
    'owner': 'airflow',
    'depends_on_past': False,
    'start_date': datetime(2024, 12, 11),
    'email_on_failure': False,
    'email_on_retry': False,
    'retries': 1,
    'retry_delay': timedelta(minutes=5),
}

# MinIO configuration
MINIO_ENDPOINT = 'localhost:9000'
MINIO_ACCESS_KEY = 'minioadmin'
MINIO_SECRET_KEY = 'minioadmin'
MINIO_BUCKET = 'testlineage'
MINIO_OBJECT = 'sales_data.parquet'

# MySQL configuration
MYSQL_HOST = 'localhost'
MYSQL_USER = 'root'
MYSQL_PASSWORD = 'root'
MYSQL_DB = 'openlineage_demo'
MYSQL_TABLE = 'sales_data'

def get_minio_dataset():
    return Dataset(
        namespace=f"s3://{MINIO_ENDPOINT}",
        name=f"{MINIO_BUCKET}/{MINIO_OBJECT}",
        source=Source(
            type="s3",
            scheme="s3"
        )
    )

def get_mysql_dataset():
    return Dataset(
        namespace=f"mysql://{MYSQL_HOST}:{3306}",
        name=f"{MYSQL_DB}.{MYSQL_TABLE}",
        source=Source(
            type="mysql",
            scheme="mysql"
        ),
        fields=[
            Field("transaction_id", "VARCHAR"),
            Field("customer_name", "VARCHAR"),
            Field("product_id", "VARCHAR"),
            Field("quantity", "INT"),
            Field("unit_price", "DECIMAL"),
            Field("transaction_date", "DATETIME"),
            Field("payment_method", "VARCHAR"),
            Field("store_location", "VARCHAR"),
            Field("category", "VARCHAR"),
            Field("total_amount", "DECIMAL"),
            Field("status", "VARCHAR")
        ]
    )

def extract_from_minio(**context):
    """Extract data from MinIO"""
    client = Minio(
        MINIO_ENDPOINT,
        access_key=MINIO_ACCESS_KEY,
        secret_key=MINIO_SECRET_KEY,
        secure=False
    )
    
    try:
        # Get data from MinIO
        data = client.get_object(MINIO_BUCKET, MINIO_OBJECT)
        parquet_buffer = io.BytesIO(data.read())
        df = pd.read_parquet(parquet_buffer)
        
        # Add OpenLineage metadata
        context['task_instance'].xcom_push(
            key='openlineage.inputs.datasets', 
            value=[get_minio_dataset()]
        )
        
        return df.to_dict('records')
    except Exception as e:
        print(f"Error reading from MinIO: {e}")
        raise e

def create_table(**context):
    """Create MySQL table if not exists"""
    conn = pymysql.connect(
        host=MYSQL_HOST,
        user=MYSQL_USER,
        password=MYSQL_PASSWORD,
        db=MYSQL_DB
    )
    
    try:
        with conn.cursor() as cursor:
            cursor.execute("""
                CREATE TABLE IF NOT EXISTS sales_data (
                    transaction_id VARCHAR(10) PRIMARY KEY,
                    customer_name VARCHAR(50),
                    product_id VARCHAR(10),
                    quantity INT,
                    unit_price DECIMAL(10,2),
                    transaction_date DATETIME,
                    payment_method VARCHAR(20),
                    store_location VARCHAR(50),
                    category VARCHAR(20),
                    total_amount DECIMAL(12,2),
                    status VARCHAR(20)
                )
            """)
        conn.commit()
        
        # Add OpenLineage metadata
        context['task_instance'].xcom_push(
            key='openlineage.outputs.datasets', 
            value=[get_mysql_dataset()]
        )
    finally:
        conn.close()

def load_to_mysql(**context):
    """Load data into MySQL"""
    data = context['task_instance'].xcom_pull(task_ids='extract_from_minio')
    
    if not data:
        raise ValueError("No data received from MinIO")
    
    conn = pymysql.connect(
        host=MYSQL_HOST,
        user=MYSQL_USER,
        password=MYSQL_PASSWORD,
        db=MYSQL_DB
    )
    
    try:
        with conn.cursor() as cursor:
            cursor.execute(f"TRUNCATE TABLE {MYSQL_TABLE}")
            for record in data:
                columns = ', '.join(record.keys())
                values = ', '.join(['%s'] * len(record))
                query = f"INSERT INTO {MYSQL_TABLE} ({columns}) VALUES ({values})"
                cursor.execute(query, list(record.values()))
        conn.commit()
        
        # Add OpenLineage metadata
        context['task_instance'].xcom_push(
            key='openlineage.inputs.datasets', 
            value=[get_minio_dataset()]
        )
        context['task_instance'].xcom_push(
            key='openlineage.outputs.datasets', 
            value=[get_mysql_dataset()]
        )
    except Exception as e:
        print(f"Error writing to MySQL: {e}")
        conn.rollback()
        raise e
    finally:
        conn.close()

with DAG(
    'minio_to_mysql_pipeline',
    default_args=default_args,
    description='Pipeline from MinIO to MySQL with OpenLineage tracking',
    schedule_interval=timedelta(days=1),
    catchup=False
) as dag:

    create_table_task = PythonOperator(
        task_id='create_table',
        python_callable=create_table,
        provide_context=True,
    )

    extract_task = PythonOperator(
        task_id='extract_from_minio',
        python_callable=extract_from_minio,
        provide_context=True,
    )

    load_task = PythonOperator(
        task_id='load_to_mysql',
        python_callable=load_to_mysql,
        provide_context=True,
    )

    create_table_task >> extract_task >> load_task
