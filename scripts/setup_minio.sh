#!/bin/bash

# Source utility functions
SCRIPT_DIR="$(dirname "$0")"
source "${SCRIPT_DIR}/utils.sh"

MINIO_ROOT_USER="minioadmin"
MINIO_ROOT_PASSWORD="minioadmin"
MINIO_DATA_DIR="/tmp/minio/data"

log "Setting up MinIO..."

# Detect architecture
ARCH=$(uname -m)
case $ARCH in
    aarch64|arm64)
        MINIO_ARCH="arm64"
        ;;
    x86_64)
        MINIO_ARCH="amd64"
        ;;
    *)
        log_error "Unsupported architecture: $ARCH"
        exit 1
        ;;
esac

# Install MinIO if not already installed
if ! command -v minio >/dev/null 2>&1; then
    log "Installing MinIO for $ARCH architecture..."
    
    # Download MinIO binary directly
    wget -q "https://dl.min.io/server/minio/release/linux-${MINIO_ARCH}/minio" -O minio
    
    if [ $? -ne 0 ]; then
        log_error "Failed to download MinIO"
        exit 1
    fi
    
    chmod +x minio
    sudo mv minio /usr/local/bin/
    
    if [ $? -ne 0 ]; then
        log_error "Failed to install MinIO"
        exit 1
    fi
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
log "Waiting for MinIO to be ready..."
for i in {1..30}; do
    if curl -s http://localhost:9000/minio/health/live > /dev/null; then
        break
    fi
    sleep 1
done

# Check if MinIO is running
if curl -s http://localhost:9000/minio/health/live > /dev/null; then
    log_success "MinIO setup completed successfully"
    log "MinIO is running at http://localhost:9000"
    log "MinIO Console is available at http://localhost:9001"
    log "Access Key: ${MINIO_ROOT_USER}"
    log "Secret Key: ${MINIO_ROOT_PASSWORD}"
else
    log_error "Failed to start MinIO"
    sudo systemctl status minio
    exit 1
fi
