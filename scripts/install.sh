#!/bin/bash

# Source utility functions
SCRIPT_DIR="$(dirname "$0")"
source "${SCRIPT_DIR}/utils.sh"

PYTHON_VERSION="3.10"
AIRFLOW_VERSION="2.7.3"
AIRFLOW_HOME="/home/ubuntu/airflow"
VENV_DIR="/home/ubuntu/airflow_env"

# Function to install system dependencies
install_dependencies() {
    log "Installing system dependencies..."
    
    # Update package list
    sudo apt-get update
    
    # Install Python and other dependencies
    sudo apt-get install -y \
        python${PYTHON_VERSION} \
        python${PYTHON_VERSION}-venv \
        python3-pip \
        build-essential \
        libssl-dev \
        libffi-dev \
        python3-dev \
        pkg-config \
        curl \
        wget \
        lsof
    
    check_status "System dependencies installation"
}

# Function to create and setup Python virtual environment
setup_virtualenv() {
    log "Setting up Python virtual environment..."
    
    # Create virtual environment if it doesn't exist
    if [ ! -d "$VENV_DIR" ]; then
        python${PYTHON_VERSION} -m venv "$VENV_DIR"
    fi
    
    # Activate virtual environment
    source "$VENV_DIR/bin/activate"
    
    # Upgrade pip
    pip install --upgrade pip
    
    check_status "Virtual environment setup"
}

# Function to cleanup previous installation
cleanup() {
    log "Cleaning up previous installation..."
    
    # Stop all services
    stop_services
    
    # Remove virtual environment if exists
    if [ -d "$VENV_DIR" ]; then
        rm -rf "$VENV_DIR"
    fi
    
    # Remove Airflow home directory if exists
    if [ -d "$AIRFLOW_HOME" ]; then
        rm -rf "$AIRFLOW_HOME"
    fi
    
    check_status "Cleanup"
}

# Function to start all services
start_services() {
    log "Starting all services..."
    
    # Start PostgreSQL
    if command -v psql >/dev/null 2>&1; then
        sudo systemctl start postgresql
        wait_for_service "postgresql" 30
    fi
    
    # Start MySQL
    if command -v mysql >/dev/null 2>&1; then
        sudo systemctl start mysql
        wait_for_service "mysql" 30
    fi
    
    # Start MinIO
    if command -v minio >/dev/null 2>&1; then
        sudo systemctl start minio
        wait_for_service "minio" 30
    fi
    
    # Start Marquez
    if [ -f "/etc/systemd/system/marquez.service" ]; then
        sudo systemctl start marquez
        wait_for_service "marquez" 30
    fi
    
    # Start Airflow
    if [ -d "$VENV_DIR" ]; then
        source "$VENV_DIR/bin/activate"
        airflow webserver -D
        airflow scheduler -D
        sleep 5
        if pgrep -f "airflow webserver" > /dev/null && pgrep -f "airflow scheduler" > /dev/null; then
            log_success "Airflow started successfully"
        else
            log_error "Failed to start Airflow"
        fi
    fi
}

# Function to stop all services
stop_services() {
    log "Stopping all services..."
    
    # Stop Airflow if running
    if [ -d "$VENV_DIR" ]; then
        source "$VENV_DIR/bin/activate" 2>/dev/null
        pkill -f "airflow webserver" 2>/dev/null
        pkill -f "airflow scheduler" 2>/dev/null
    fi
    
    # Stop other services
    sudo systemctl stop marquez 2>/dev/null
    sudo systemctl stop minio 2>/dev/null
    sudo systemctl stop mysql 2>/dev/null
    sudo systemctl stop postgresql 2>/dev/null
    
    log_success "All services stopped"
}

# Function to setup all components
setup_all() {
    log "Setting up all components..."
    
    # Setup MySQL
    bash "${SCRIPT_DIR}/setup_mysql.sh"
    
    # Setup MinIO
    bash "${SCRIPT_DIR}/setup_minio.sh"
    
    # Setup Marquez
    bash "${SCRIPT_DIR}/setup_marquez.sh"
    
    # Setup Airflow
    bash "${SCRIPT_DIR}/setup_airflow.sh"
    
    log_success "Setup completed"
}

# Function to generate sample data
generate_data() {
    log "Generating sample data..."
    if [ ! -d "$VENV_DIR" ]; then
        log_error "Virtual environment not found. Please run setup first."
        exit 1
    fi
    
    # Activate virtual environment and install requirements
    source "$VENV_DIR/bin/activate"
    
    log "Installing Python dependencies..."
    pip install -r "${SCRIPT_DIR}/../requirements.txt"
    check_status "Dependencies installation"
    
    log "Running data generation script..."
    python3 "${SCRIPT_DIR}/generate_data.py"
    check_status "Data generation"
}

# Function to check services status
check_services_status() {
    log "Checking services status..."
    
    # Check PostgreSQL
    if systemctl is-active --quiet postgresql; then
        log_success "PostgreSQL is running"
    else
        log_error "PostgreSQL is not running"
    fi
    
    # Check MySQL
    if systemctl is-active --quiet mysql; then
        log_success "MySQL is running"
    else
        log_error "MySQL is not running"
    fi
    
    # Check MinIO
    if systemctl is-active --quiet minio; then
        log_success "MinIO is running"
    else
        log_error "MinIO is not running"
    fi
    
    # Check Marquez
    if systemctl is-active --quiet marquez; then
        log_success "Marquez is running"
    else
        log_error "Marquez is not running"
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

# Main installation function
install() {
    cleanup
    log "Starting OpenLineage installation..."
    install_dependencies
    setup_virtualenv
    setup_all
    start_services
    log_success "Installation completed successfully!"
}

# Main script logic
case "$1" in
    "install")
        install
        ;;
    "setup")
        setup_all
        ;;
    "start")
        start_services
        ;;
    "stop")
        stop_services
        ;;
    "status")
        check_services_status
        ;;
    "generate-data")
        generate_data
        ;;
    *)
        echo "Usage: $0 {install|setup|start|stop|status|generate-data}"
        exit 1
        ;;
esac
