#!/bin/bash

# Source utility functions
source "$(dirname "$0")/utils.sh"

MINIO_ROOT_USER="minioadmin"
MINIO_ROOT_PASSWORD="minioadmin"
MINIO_DATA_DIR="/tmp/minio/data"

log_info "Setting up MinIO..."

# Install MinIO if not already installed
if ! command -v minio >/dev/null 2>&1; then
    log_info "Installing MinIO..."
    wget https://dl.min.io/server/minio/release/linux-amd64/archive/minio_20231205001649.0.0_amd64.deb -O minio.deb
    sudo dpkg -i minio.deb
    rm minio.deb
fi

# Create data directory
sudo mkdir -p $MINIO_DATA_DIR
sudo chown -R $USER:$USER $MINIO_DATA_DIR

# Create systemd service file
sudo tee /etc/systemd/system/minio.service > /dev/null << EOL
[Unit]
Description=MinIO
Documentation=https://docs.min.io
Wants=network-online.target
After=network-online.target

[Service]
Type=simple
Environment="MINIO_ROOT_USER=${MINIO_ROOT_USER}"
Environment="MINIO_ROOT_PASSWORD=${MINIO_ROOT_PASSWORD}"
ExecStart=/usr/local/bin/minio server ${MINIO_DATA_DIR} --console-address :9001 --address :9000
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
EOL

# Reload systemd and start MinIO
sudo systemctl daemon-reload
sudo systemctl enable minio
sudo systemctl start minio

# Wait for MinIO to be ready
log_info "Waiting for MinIO to be ready..."
for i in {1..30}; do
    if curl -s http://localhost:9000/minio/health/live > /dev/null; then
        break
    fi
    sleep 1
done

# Check if MinIO is running
if curl -s http://localhost:9000/minio/health/live > /dev/null; then
    log_success "MinIO setup completed successfully"
    log_info "MinIO is running at http://localhost:9000"
    log_info "MinIO Console is available at http://localhost:9001"
    log_info "Access Key: ${MINIO_ROOT_USER}"
    log_info "Secret Key: ${MINIO_ROOT_PASSWORD}"
else
    log_error "Failed to start MinIO"
    sudo systemctl status minio
    exit 1
fi

# Run setup if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    setup_minio
fi
