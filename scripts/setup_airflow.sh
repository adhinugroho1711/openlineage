#!/bin/bash

source "$(dirname "$0")/utils.sh"

setup_airflow() {
    log "Setting up Airflow..."
    
    # Create Python virtual environment
    python3 -m venv airflow_env
    source airflow_env/bin/activate
    
    # Install Airflow and providers
    AIRFLOW_VERSION=2.7.3
    PYTHON_VERSION="$(python3 --version | cut -d " " -f 2 | cut -d "." -f 1-2)"
    CONSTRAINT_URL="https://raw.githubusercontent.com/apache/airflow/constraints-${AIRFLOW_VERSION}/constraints-${PYTHON_VERSION}.txt"
    
    pip install "apache-airflow==${AIRFLOW_VERSION}" --constraint "${CONSTRAINT_URL}"
    pip install apache-airflow-providers-openlineage
    pip install apache-airflow-providers-mysql
    pip install pymysql pandas minio pyarrow
    
    # Create Airflow directories
    mkdir -p ~/airflow/dags
    export AIRFLOW_HOME=~/airflow
    
    # Copy configuration file
    mkdir -p ~/airflow/config
    cp "$(dirname "$0")/../config/airflow_config.yaml" ~/airflow/config/
    
    # Initialize Airflow DB
    airflow db init
    
    # Create Airflow admin user
    airflow users create \
        --username admin \
        --firstname Admin \
        --lastname User \
        --role Admin \
        --email admin@example.com \
        --password admin
    
    check_status "Airflow setup"
}

start_airflow() {
    log "Starting Airflow services..."
    source airflow_env/bin/activate
    export AIRFLOW_HOME=~/airflow
    
    # Use custom config
    export AIRFLOW__OPENLINEAGE__CONFIG_PATH=~/airflow/config/airflow_config.yaml
    
    airflow webserver --port 8080 &
    sleep 5
    airflow scheduler &
    sleep 5
    check_status "Airflow startup"
}

# Run setup if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    setup_airflow
    start_airflow
fi
