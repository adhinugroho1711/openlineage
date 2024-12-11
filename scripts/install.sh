#!/bin/bash

source "$(dirname "$0")/utils.sh"

# Main installation function
install() {
    log "Starting OpenLineage installation..."
    
    # Update system and install basic dependencies
    log "Installing system dependencies..."
    sudo apt update
    sudo apt install -y openjdk-11-jdk \
                    python3-pip \
                    python3-venv \
                    build-essential \
                    libpq-dev \
                    python3-dev \
                    wget \
                    mysql-server \
                    mysql-client \
                    libmysqlclient-dev
    check_status "Dependencies installation"
    
    # Run individual setup scripts
    source "$(dirname "$0")/setup_mysql.sh"
    setup_mysql
    
    source "$(dirname "$0")/setup_minio.sh"
    setup_minio
    
    source "$(dirname "$0")/setup_marquez.sh"
    setup_marquez
    
    source "$(dirname "$0")/setup_airflow.sh"
    setup_airflow
    
    log "Installation completed successfully!"
}

# Start all services
start_services() {
    log "Starting all services..."
    
    # Start MySQL if not running
    if ! systemctl is-active --quiet mysql; then
        sudo systemctl start mysql
    fi
    
    # Start MinIO if not running
    if ! systemctl is-active --quiet minio; then
        sudo systemctl start minio
    fi
    
    # Start Marquez
    source "$(dirname "$0")/setup_marquez.sh"
    start_marquez
    
    # Start Airflow
    source "$(dirname "$0")/setup_airflow.sh"
    start_airflow
    
    log "All services started successfully!"
}

# Generate sample data
generate_data() {
    log "Generating sample data..."
    source airflow_env/bin/activate
    python "$(dirname "$0")/generate_data.py"
    check_status "Data generation"
}

# Main execution
case "$1" in
    "install")
        cleanup
        install
        ;;
    "start")
        start_services
        ;;
    "stop")
        stop_services
        ;;
    "generate-data")
        generate_data
        ;;
    "status")
        log "Checking services status..."
        systemctl status mysql
        systemctl status minio
        ps aux | grep -E "marquez|airflow"
        ;;
    *)
        echo "Usage: $0 {install|start|stop|generate-data|status}"
        exit 1
        ;;
esac
