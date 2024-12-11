#!/bin/bash

source "$(dirname "$0")/utils.sh"

setup_mysql() {
    log "Setting up MySQL..."
    
    # Install MySQL server if not already installed
    if ! command -v mysql >/dev/null 2>&1; then
        log "Installing MySQL Server..."
        sudo apt-get install -y mysql-server mysql-client
        check_status "MySQL package installation"
    fi
    
    # Create MySQL user and group if they don't exist
    log "Creating MySQL user and group..."
    sudo groupadd mysql || true
    sudo useradd -r -g mysql -s /bin/false mysql || true
    
    # Ensure MySQL directories exist with correct permissions
    log "Setting up MySQL directories..."
    sudo mkdir -p /var/lib/mysql /var/run/mysqld
    sudo chown -R mysql:mysql /var/lib/mysql /var/run/mysqld
    sudo chmod 777 /var/run/mysqld
    
    # Start MySQL service
    log "Starting MySQL service..."
    sudo systemctl enable mysql
    sudo systemctl start mysql
    sleep 5
    
    # Secure MySQL installation
    log "Securing MySQL installation..."
    sudo mysql -e "
        ALTER USER 'root'@'localhost' IDENTIFIED WITH mysql_native_password BY 'root';
        DELETE FROM mysql.user WHERE User='';
        DELETE FROM mysql.user WHERE User='root' AND Host NOT IN ('localhost', '127.0.0.1', '::1');
        DROP DATABASE IF EXISTS test;
        DELETE FROM mysql.db WHERE Db='test' OR Db='test\\_%';
        FLUSH PRIVILEGES;
        CREATE DATABASE IF NOT EXISTS openlineage_demo;
    "
    check_status "MySQL secure installation"
    
    # Verify MySQL is running and accessible
    log "Verifying MySQL connection..."
    if mysql -u root -proot -e "SELECT 1;" >/dev/null 2>&1; then
        log "MySQL is running and accessible"
    else
        error "MySQL verification failed"
        exit 1
    fi
}

# Run setup if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    setup_mysql
fi
