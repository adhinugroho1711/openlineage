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

# Function to start all services
start_services() {
    log_info "Starting all services..."
    
    # Start MySQL
    log_info "Starting MySQL..."
    sudo systemctl start mysql
    
    # Start MinIO
    log_info "Starting MinIO..."
    sudo systemctl start minio
    
    # Start Marquez
    log_info "Starting Marquez..."
    sudo systemctl start marquez
    
    # Start Airflow
    log_info "Starting Airflow..."
    source ~/airflow_env/bin/activate
    airflow webserver -D
    airflow scheduler -D
    
    log_success "All services started"
}

# Function to stop all services
stop_services() {
    log_info "Stopping all services..."
    
    # Stop Airflow
    log_info "Stopping Airflow..."
    source ~/airflow_env/bin/activate
    pkill -f "airflow webserver"
    pkill -f "airflow scheduler"
    
    # Stop other services
    log_info "Stopping other services..."
    sudo systemctl stop marquez
    sudo systemctl stop minio
    sudo systemctl stop mysql
    
    log_success "All services stopped"
}

# Function to check services status
check_services_status() {
    log_info "Checking services status..."
    
    # Check MySQL
    if systemctl is-active --quiet mysql; then
        log_success "MySQL is running"
    else
        log_error "MySQL is not running"
    fi
    
    # Check Marquez
    if systemctl is-active --quiet marquez; then
        log_success "Marquez is running"
    else
        log_error "Marquez is not running"
    fi
    
    # Check MinIO
    if systemctl is-active --quiet minio; then
        log_success "MinIO is running"
    else
        log_error "MinIO is not running"
    fi
    
    # Check Airflow processes
    if pgrep -f "airflow webserver" > /dev/null; then
        log_success "Airflow Webserver is running"
    else
        log_error "Airflow Webserver is not running"
    fi
    
    if pgrep -f "airflow scheduler" > /dev/null; then
        log_success "Airflow Scheduler is running"
    else
        log_error "Airflow Scheduler is not running"
    fi
}

# Function to generate sample data
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
