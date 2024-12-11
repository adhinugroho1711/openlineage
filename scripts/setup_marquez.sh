#!/bin/bash

source "$(dirname "$0")/utils.sh"

setup_marquez() {
    log "Setting up Marquez..."
    
    # Download and extract Marquez
    wget https://github.com/MarquezProject/marquez/releases/download/0.35.0/marquez-0.35.0.tar.gz
    tar -xzvf marquez-0.35.0.tar.gz
    rm marquez-0.35.0.tar.gz
    
    # Copy configuration
    mkdir -p ~/marquez-0.35.0/conf
    cp "$(dirname "$0")/../config/marquez_config.yaml" ~/marquez-0.35.0/conf/marquez.yml
    
    check_status "Marquez setup"
}

start_marquez() {
    log "Starting Marquez..."
    cd ~/marquez-0.35.0
    
    # Start Marquez with custom config
    ./bin/marquez.sh --config conf/marquez.yml &
    sleep 10
    cd - > /dev/null
    check_status "Marquez startup"
}

# Run setup if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    setup_marquez
    start_marquez
fi
