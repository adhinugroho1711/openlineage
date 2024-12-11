#!/bin/bash

# Source utility functions
SCRIPT_DIR="$(dirname "$0")"
source "${SCRIPT_DIR}/utils.sh"

MARQUEZ_VERSION="0.40.0"
MARQUEZ_DIR="/opt/marquez"
MARQUEZ_PORT=3000
POSTGRES_USER="marquez"
POSTGRES_PASSWORD="marquez"
POSTGRES_DB="marquez"

log "Setting up Marquez..."

# Install Java if not present
if ! command -v java >/dev/null 2>&1; then
    log "Installing Java..."
    sudo apt-get update
    sudo apt-get install -y openjdk-11-jre-headless
fi

# Create Marquez directory
sudo mkdir -p $MARQUEZ_DIR
sudo chown -R $USER:$USER $MARQUEZ_DIR

# Download and verify Marquez
log "Downloading Marquez..."
MARQUEZ_JAR="marquez-${MARQUEZ_VERSION}.jar"
MARQUEZ_URL="https://github.com/MarquezProject/marquez/releases/download/v${MARQUEZ_VERSION}/${MARQUEZ_JAR}"

# Remove existing jar if it exists
rm -f "${MARQUEZ_DIR}/${MARQUEZ_JAR}"

# Download with wget and show progress
wget --progress=dot:giga "${MARQUEZ_URL}" -O "${MARQUEZ_DIR}/${MARQUEZ_JAR}.tmp"

# Verify the downloaded file
if [ ! -f "${MARQUEZ_DIR}/${MARQUEZ_JAR}.tmp" ]; then
    log_error "Failed to download Marquez JAR"
    exit 1
fi

# Check file size (should be more than 1MB)
FILE_SIZE=$(stat -f%z "${MARQUEZ_DIR}/${MARQUEZ_JAR}.tmp" 2>/dev/null || stat -c%s "${MARQUEZ_DIR}/${MARQUEZ_JAR}.tmp")
if [ "$FILE_SIZE" -lt 1000000 ]; then
    log_error "Downloaded file is too small (${FILE_SIZE} bytes). Minimum size should be 1MB"
    rm -f "${MARQUEZ_DIR}/${MARQUEZ_JAR}.tmp"
    exit 1
fi

# Verify it's a valid JAR file
if ! file "${MARQUEZ_DIR}/${MARQUEZ_JAR}.tmp" | grep -q "Java archive"; then
    log_error "Downloaded file is not a valid JAR file"
    rm -f "${MARQUEZ_DIR}/${MARQUEZ_JAR}.tmp"
    exit 1
fi

# Move temporary file to final location
mv "${MARQUEZ_DIR}/${MARQUEZ_JAR}.tmp" "${MARQUEZ_DIR}/${MARQUEZ_JAR}"
chmod +x "${MARQUEZ_DIR}/${MARQUEZ_JAR}"

# Setup PostgreSQL if not already installed
if ! command -v psql >/dev/null 2>&1; then
    log "Installing PostgreSQL..."
    sudo apt-get update
    sudo apt-get install -y postgresql postgresql-contrib
fi

# Start PostgreSQL if not running
if ! systemctl is-active --quiet postgresql; then
    sudo systemctl start postgresql
    sudo systemctl enable postgresql
fi

# Wait for PostgreSQL to be ready
log "Waiting for PostgreSQL to be ready..."
for i in {1..30}; do
    if sudo -u postgres psql -c '\l' >/dev/null 2>&1; then
        break
    fi
    sleep 1
done

# Create database and user
log "Setting up PostgreSQL database..."
sudo -u postgres psql -c "DROP DATABASE IF EXISTS ${POSTGRES_DB};"
sudo -u postgres psql -c "DROP USER IF EXISTS ${POSTGRES_USER};"
sudo -u postgres psql -c "CREATE USER ${POSTGRES_USER} WITH PASSWORD '${POSTGRES_PASSWORD}';"
sudo -u postgres psql -c "CREATE DATABASE ${POSTGRES_DB} OWNER ${POSTGRES_USER};"
sudo -u postgres psql -c "GRANT ALL PRIVILEGES ON DATABASE ${POSTGRES_DB} TO ${POSTGRES_USER};"

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
  url: jdbc:postgresql://localhost:5432/${POSTGRES_DB}
  user: ${POSTGRES_USER}
  password: ${POSTGRES_PASSWORD}

logging:
  level: INFO
  loggers:
    marquez: DEBUG
  appenders:
    - type: console
      logFormat: "%d{ISO8601} [%thread] %-5level %c{35} - %msg%n"
    - type: file
      currentLogFilename: ${MARQUEZ_DIR}/marquez.log
      archivedLogFilenamePattern: ${MARQUEZ_DIR}/marquez-%d.log.gz
      archivedFileCount: 5

migrateOnStartup: true
EOL

# Create systemd service file
sudo tee /etc/systemd/system/marquez.service > /dev/null << EOL
[Unit]
Description=Marquez Service
After=postgresql.service
Requires=postgresql.service

[Service]
Type=simple
User=$USER
WorkingDirectory=$MARQUEZ_DIR
Environment="JAVA_OPTS=-Xmx1g"
ExecStart=/usr/bin/java \${JAVA_OPTS} -jar ${MARQUEZ_DIR}/${MARQUEZ_JAR} server ${MARQUEZ_DIR}/marquez.yml
Restart=on-failure
RestartSec=5
StandardOutput=append:${MARQUEZ_DIR}/marquez.log
StandardError=append:${MARQUEZ_DIR}/marquez.error.log

[Install]
WantedBy=multi-user.target
EOL

# Stop Marquez if it's running
sudo systemctl stop marquez 2>/dev/null

# Clean up old logs
rm -f ${MARQUEZ_DIR}/marquez.log ${MARQUEZ_DIR}/marquez.error.log

# Reload systemd and start Marquez
sudo systemctl daemon-reload
sudo systemctl enable marquez
sudo systemctl start marquez

# Wait for Marquez to be ready
log "Waiting for Marquez to be ready..."
for i in {1..60}; do
    if curl -s http://localhost:${MARQUEZ_PORT}/api/v1/namespaces > /dev/null; then
        break
    fi
    echo -n "."
    sleep 2
done
echo ""

# Check if Marquez is running
if ! curl -s http://localhost:${MARQUEZ_PORT}/api/v1/namespaces > /dev/null; then
    log_error "Failed to start Marquez"
    echo "=== Marquez Service Status ==="
    sudo systemctl status marquez
    echo "=== Last 50 lines of Marquez log ==="
    tail -n 50 ${MARQUEZ_DIR}/marquez.log
    echo "=== Last 50 lines of Marquez error log ==="
    tail -n 50 ${MARQUEZ_DIR}/marquez.error.log
    exit 1
else
    log_success "Marquez setup completed successfully"
    log "Marquez API is running at http://localhost:${MARQUEZ_PORT}"
    log "Marquez Admin interface is available at http://localhost:3001"
fi
