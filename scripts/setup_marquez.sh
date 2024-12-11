#!/bin/bash

# Source utility functions
source "$(dirname "$0")/utils.sh"

MARQUEZ_VERSION="0.40.0"
MARQUEZ_DIR="/opt/marquez"
MARQUEZ_PORT=3000

log_info "Setting up Marquez..."

# Install Java if not present
if ! command -v java >/dev/null 2>&1; then
    log_info "Installing Java..."
    sudo apt-get update
    sudo apt-get install -y openjdk-11-jre-headless
fi

# Create Marquez directory
sudo mkdir -p $MARQUEZ_DIR
sudo chown -R $USER:$USER $MARQUEZ_DIR

# Download Marquez if not already present
if [ ! -f "$MARQUEZ_DIR/marquez-${MARQUEZ_VERSION}.jar" ]; then
    log_info "Downloading Marquez..."
    wget -q "https://github.com/MarquezProject/marquez/releases/download/v${MARQUEZ_VERSION}/marquez-${MARQUEZ_VERSION}.jar" -O "$MARQUEZ_DIR/marquez-${MARQUEZ_VERSION}.jar"
fi

# Create Marquez config
cat > $MARQUEZ_DIR/marquez.yml << EOL
server:
  applicationConnectors:
    - type: http
      port: ${MARQUEZ_PORT}
  adminConnectors:
    - type: http
      port: 3001

db:
  driverClass: org.postgresql.Driver
  url: jdbc:postgresql://localhost:5432/marquez
  user: marquez
  password: marquez

migrateOnStartup: true
EOL

# Create systemd service file
sudo tee /etc/systemd/system/marquez.service > /dev/null << EOL
[Unit]
Description=Marquez Service
After=network.target

[Service]
Type=simple
User=$USER
WorkingDirectory=$MARQUEZ_DIR
ExecStart=/usr/bin/java -jar $MARQUEZ_DIR/marquez-${MARQUEZ_VERSION}.jar server $MARQUEZ_DIR/marquez.yml
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
EOL

# Setup PostgreSQL if not already installed
if ! command -v psql >/dev/null 2>&1; then
    log_info "Installing PostgreSQL..."
    sudo apt-get update
    sudo apt-get install -y postgresql postgresql-contrib
fi

# Start PostgreSQL if not running
if ! systemctl is-active --quiet postgresql; then
    sudo systemctl start postgresql
    sudo systemctl enable postgresql
fi

# Create database and user
log_info "Setting up PostgreSQL database..."
sudo -u postgres psql -c "CREATE USER marquez WITH PASSWORD 'marquez';" || true
sudo -u postgres psql -c "CREATE DATABASE marquez OWNER marquez;" || true
sudo -u postgres psql -c "GRANT ALL PRIVILEGES ON DATABASE marquez TO marquez;" || true

# Reload systemd and start Marquez
sudo systemctl daemon-reload
sudo systemctl enable marquez
sudo systemctl start marquez

# Wait for Marquez to be ready
log_info "Waiting for Marquez to be ready..."
for i in {1..30}; do
    if curl -s http://localhost:${MARQUEZ_PORT}/api/v1/namespaces > /dev/null; then
        break
    fi
    sleep 2
done

# Check if Marquez is running
if curl -s http://localhost:${MARQUEZ_PORT}/api/v1/namespaces > /dev/null; then
    log_success "Marquez setup completed successfully"
    log_info "Marquez API is running at http://localhost:${MARQUEZ_PORT}"
    log_info "Marquez Admin interface is available at http://localhost:3001"
else
    log_error "Failed to start Marquez"
    sudo systemctl status marquez
    exit 1
fi
