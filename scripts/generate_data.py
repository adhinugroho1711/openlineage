#!/usr/bin/env python3

import pandas as pd
import numpy as np
from minio import Minio
from datetime import datetime, timedelta
import io

def generate_dummy_data():
    np.random.seed(42)
    base_date = datetime.now()
    # Convert numpy.int64 to Python int
    random_days = [int(x) for x in np.random.randint(0, 30, 1000)]
    dates = [base_date - timedelta(days=x) for x in random_days]
    
    data = {
        'transaction_id': [f'TRX-{i:06d}' for i in range(1000)],
        'customer_name': [f'Customer-{np.random.randint(1, 101):03d}' for _ in range(1000)],
        'product_id': [f'PRD-{np.random.randint(1, 51):03d}' for _ in range(1000)],
        'quantity': [int(x) for x in np.random.randint(1, 100, 1000)],
        'unit_price': np.random.uniform(10.0, 1000.0, 1000).round(2).tolist(),
        'transaction_date': dates,
        'payment_method': np.random.choice(['CASH', 'CREDIT', 'DEBIT', 'E-WALLET'], 1000).tolist(),
        'store_location': np.random.choice(['JAKARTA', 'BANDUNG', 'SURABAYA', 'MEDAN', 'MAKASSAR'], 1000).tolist(),
        'category': np.random.choice(['ELECTRONICS', 'FASHION', 'FOOD', 'BOOKS', 'SPORTS'], 1000).tolist()
    }
    
    df = pd.DataFrame(data)
    df['total_amount'] = (df['quantity'] * df['unit_price']).round(2)
    df['status'] = np.where(df['total_amount'] > 5000, 'HIGH_VALUE',
                           np.where(df['total_amount'] > 1000, 'MEDIUM_VALUE', 'LOW_VALUE'))
    return df

def upload_to_minio(df):
    client = Minio(
        "localhost:9000",
        access_key="minioadmin",
        secret_key="minioadmin",
        secure=False
    )
    
    bucket_name = "testlineage"  # Changed to valid bucket name
    
    try:
        # Check if bucket exists and create if it doesn't
        if not client.bucket_exists(bucket_name):
            client.make_bucket(bucket_name)
            print(f"Created bucket: {bucket_name}")
        else:
            print(f"Using existing bucket: {bucket_name}")
        
        # Convert DataFrame to parquet format
        print("Converting data to parquet format...")
        parquet_buffer = io.BytesIO()
        df.to_parquet(parquet_buffer, engine='pyarrow', index=False)
        parquet_buffer.seek(0)
        parquet_length = len(parquet_buffer.getvalue())
        
        # Upload file
        print(f"Uploading data ({parquet_length} bytes)...")
        client.put_object(
            bucket_name,
            "sales_data.parquet",
            parquet_buffer,
            parquet_length,
            content_type="application/octet-stream"
        )
        print(f"Successfully uploaded sales_data.parquet to bucket: {bucket_name}")
        
        # Verify upload
        try:
            stat = client.stat_object(bucket_name, "sales_data.parquet")
            print(f"Verified upload - File size: {stat.size} bytes")
        except Exception as e:
            print(f"Warning: Could not verify upload: {str(e)}")
            
    except Exception as e:
        print(f"Error: {str(e)}")
        raise e

if __name__ == "__main__":
    print("Generating dummy data...")
    try:
        df = generate_dummy_data()
        print("Sample of generated data:")
        print(df.head())
        print("\nData Summary:")
        print(df.info())
        
        print("\nUploading to MinIO...")
        upload_to_minio(df)
        print("Process completed!")
    except Exception as e:
        print(f"Error occurred: {str(e)}")
        raise e
