#!/bin/bash

source "$(dirname "$0")/utils.sh"

setup_minio() {
    log "Setting up MinIO..."
    
    # Download and setup MinIO binary
    wget https://dl.min.io/server/minio/release/linux-amd64/minio
    chmod +x minio
    sudo mv minio /usr/local/bin/
    
    # Create MinIO user and directories
    sudo useradd -r minio-user -s /sbin/nologin || true
    sudo mkdir -p /usr/local/share/minio
    sudo mkdir -p /etc/minio
    sudo chown -R minio-user:minio-user /usr/local/share/minio
    sudo chown -R minio-user:minio-user /etc/minio
    
    # Create MinIO service file
    sudo tee /etc/systemd/system/minio.service << 'EOF'
[Unit]
Description=MinIO
Documentation=https://docs.min.io
Wants=network-online.target
After=network-online.target

[Service]
User=minio-user
Group=minio-user
Environment="MINIO_ROOT_USER=minioadmin"
Environment="MINIO_ROOT_PASSWORD=minioadmin"
ExecStart=/usr/local/bin/minio server /usr/local/share/minio --console-address :9001
Restart=always

[Install]
WantedBy=multi-user.target
EOF
    
    # Reload systemd and start MinIO
    sudo systemctl daemon-reload
    sudo systemctl enable minio
    sudo systemctl start minio
    
    check_status "MinIO setup"
}

# Run setup if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    setup_minio
fi
