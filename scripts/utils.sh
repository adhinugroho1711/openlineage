#!/bin/bash

# Colors for logging
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Logging functions
log() {
    echo -e "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
}

log_success() {
    echo -e "[$(date '+%Y-%m-%d %H:%M:%S')] ${GREEN}✓ $1${NC}"
}

log_error() {
    echo -e "[$(date '+%Y-%m-%d %H:%M:%S')] ${RED}❌ $1${NC}"
}

log_warning() {
    echo -e "[$(date '+%Y-%m-%d %H:%M:%S')] ${YELLOW}⚠ $1${NC}"
}

# Function to check command status
check_status() {
    if [ $? -eq 0 ]; then
        log_success "$1 successful"
        return 0
    else
        log_error "$1 failed"
        return 1
    fi
}

# Function to check if a service is running
check_service() {
    local service_name=$1
    if systemctl is-active --quiet "$service_name"; then
        log_success "$service_name is running"
        return 0
    else
        log_error "$service_name is not running"
        return 1
    fi
}

# Function to wait for service to be ready
wait_for_service() {
    local service_name=$1
    local max_attempts=$2
    local attempt=1
    
    while [ $attempt -le $max_attempts ]; do
        if systemctl is-active --quiet "$service_name"; then
            log_success "$service_name is ready"
            return 0
        fi
        log "Waiting for $service_name... (attempt $attempt/$max_attempts)"
        sleep 2
        attempt=$((attempt + 1))
    done
    
    log_error "$service_name failed to start after $max_attempts attempts"
    return 1
}

# Function to check port availability
check_port() {
    local port=$1
    if ! lsof -i :$port > /dev/null; then
        log_success "Port $port is available"
        return 0
    else
        log_error "Port $port is already in use"
        return 1
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
