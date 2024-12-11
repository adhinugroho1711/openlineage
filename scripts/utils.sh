#!/bin/bash

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Logging functions
log() {
    echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')]${NC} $1"
}

error() {
    echo -e "${RED}[$(date +'%Y-%m-%d %H:%M:%S')] ERROR:${NC} $1"
}

warning() {
    echo -e "${YELLOW}[$(date +'%Y-%m-%d %H:%M:%S')] WARNING:${NC} $1"
}

# Function to check if command succeeded
check_status() {
    if [ $? -eq 0 ]; then
        log "✅ $1 successful"
    else
        error "❌ $1 failed"
        exit 1
    fi
}

# Function to check if a process is running
check_process() {
    pgrep -f "$1" >/dev/null
    return $?
}

# Function to stop services
stop_services() {
    log "Stopping services..."
    
    # Stop Airflow processes
    pkill -f "airflow webserver" || true
    pkill -f "airflow scheduler" || true
    
    # Stop Marquez
    pkill -f "marquez" || true
    
    # Stop MinIO
    sudo systemctl stop minio || true
    
    # Stop MySQL
    sudo systemctl stop mysql || true
    
    log "All services stopped"
}

# Cleanup function
cleanup() {
    log "Cleaning up previous installation..."
    stop_services
    
    # Remove previous installations
    rm -rf ~/airflow
    rm -rf ~/marquez-0.35.0*
    rm -rf ~/minio
    
    # Remove virtual environment
    rm -rf airflow_env
    
    # Clean MySQL completely if exists
    if command -v mysql >/dev/null 2>&1; then
        log "Removing existing MySQL installation..."
        sudo apt remove --purge -y mysql-server mysql-client mysql-common mysql-server-core-* mysql-client-core-*
        sudo rm -rf /etc/mysql /var/lib/mysql
        sudo apt autoremove -y
        sudo apt autoclean
    fi
    
    check_status "Cleanup"
}
