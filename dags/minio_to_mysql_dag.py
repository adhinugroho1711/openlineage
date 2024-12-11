from datetime import datetime, timedelta
from airflow import DAG
from airflow.operators.python import PythonOperator
from minio import Minio
import pandas as pd
import pymysql
import io

default_args = {
    'owner': 'airflow',
    'depends_on_past': False,
    'start_date': datetime(2024, 12, 11),
    'email_on_failure': False,
    'email_on_retry': False,
    'retries': 1,
    'retry_delay': timedelta(minutes=5),
}

MINIO_ENDPOINT = 'localhost:9000'
MINIO_ACCESS_KEY = 'minioadmin'
MINIO_SECRET_KEY = 'minioadmin'
MINIO_BUCKET = 'test_lineage'
MINIO_OBJECT = 'sales_data.parquet'

MYSQL_HOST = 'localhost'
MYSQL_USER = 'root'
MYSQL_PASSWORD = 'root'
MYSQL_DB = 'openlineage_demo'
MYSQL_TABLE = 'sales_data'

def extract_from_minio():
    client = Minio(
        MINIO_ENDPOINT,
        access_key=MINIO_ACCESS_KEY,
        secret_key=MINIO_SECRET_KEY,
        secure=False
    )
    
    try:
        data = client.get_object(MINIO_BUCKET, MINIO_OBJECT)
        parquet_buffer = io.BytesIO(data.read())
        df = pd.read_parquet(parquet_buffer)
        return df.to_dict('records')
    except Exception as e:
        print(f"Error reading from MinIO: {e}")
        raise e

def create_table():
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
    finally:
        conn.close()

def load_to_mysql(ti):
    data = ti.xcom_pull(task_ids='extract_from_minio')
    
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
    )

    extract_task = PythonOperator(
        task_id='extract_from_minio',
        python_callable=extract_from_minio,
    )

    load_task = PythonOperator(
        task_id='load_to_mysql',
        python_callable=load_to_mysql,
    )

    create_table_task >> extract_task >> load_task
