#!/bin/bash

# Check if we're running in bash; if not, adjust behavior
if [ -n "$BASH_VERSION" ]; then
    set -euo pipefail
else
    set -eu
fi

LOG_LEVEL=${LOG_LEVEL:-"INFO"}
TRIVY_VERSION=${TRIVY_VERSION:-"v0.60.0"}
OSSEC_SHARED_DIR=${OSSEC_SHARED_DIR:-"/var/ossec/etc/shared"}
OSSEC_CONF_DIR=${OSSEC_CONF_DIR:-"/var/ossec/etc"}
OSSEC_LOG_DIR=${OSSEC_LOG_DIR:-"/var/ossec/logs"}
OSSEC_USER=${OSSEC_USER:-"root"}
OSSEC_GROUP=${OSSEC_GROUP:-"wazuh"}
TRIVY_SCAN_SCRIPT_PATH=${TRIVY_SCAN_SCRIPT_PATH:-"$OSSEC_SHARED_DIR/trivy-scan.sh"}
TRIVY_SCAN_LOG_PATH=${TRIVY_SCAN_LOG_PATH:-"$OSSEC_LOG_DIR/trivy-scan.log"}
TRIVY_SCAN_SCRIPT_URL=${TRIVY_SCAN_SCRIPT_URL:-"https://raw.githubusercontent.com/ADORSYS-GIS/wazuh-trivy/main/trivy-scan.sh"}
LOCAL_INTERNAL_OPTIONS_CONF=${LOCAL_INTERNAL_OPTIONS_CONF:-"$OSSEC_CONF_DIR/local_internal_options.conf"}
REMOTE_COMMANDS_CONFIG=${REMOTE_COMMANDS_CONFIG:-"wazuh_command.remote_commands=1"} 

# Define text formatting
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[1;34m'
BOLD='\033[1m'
NORMAL='\033[0m'

# Function for logging with timestamp
log() {
    local LEVEL="$1"
    shift
    local MESSAGE="$*"
    local TIMESTAMP
    TIMESTAMP=$(date +"%Y-%m-%d %H:%M:%S")
    echo -e "${TIMESTAMP} ${LEVEL} ${MESSAGE}"
}

# Logging helpers
info_message() {
    log "${BLUE}${BOLD}[===========> INFO]${NORMAL}" "$*"
}

warning_message() {
    log "${YELLOW}${BOLD}[ERROR]${NORMAL}" "$*"
}

error_message() {
    log "${RED}${BOLD}[ERROR]${NORMAL}" "$*"
}

success_message() {
    log "${GREEN}${BOLD}[SUCCESS]${NORMAL}" "$*"
}

# Check if a command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Ensure root privileges, either directly or through sudo
maybe_sudo() {
    if [ "$(id -u)" -ne 0 ]; then
        if command_exists sudo; then
            sudo "$@"
        else
            error_message "This script requires root privileges. Please run with sudo or as root."
            exit 1
        fi
    else
        "$@"
    fi
}

# Check if a container engine (Docker or Podman) is installed
has_container_engine() {
    if command_exists docker || command_exists podman || command_exists ctr; then
        return 0
    else
        return 1
    fi
}

# Install Trivy if it doesn't exist
install_trivy() {
    if ! command_exists trivy; then
        info_message "Trivy not found. Installing Trivy..."
        if has_container_engine; then
            # Use the official Trivy installation script
            info_message "Downloading and installing Trivy ${TRIVY_VERSION}..."
            if ! (maybe_sudo curl -sfL https://raw.githubusercontent.com/aquasecurity/trivy/main/contrib/install.sh | sh -s -- -b /usr/local/bin "$TRIVY_VERSION"); then
                error_message "Failed to install Trivy."
                exit 1
            fi
            success_message "Trivy installed successfully."
        else
            error_message "No container engine (Docker or Podman) found. Trivy requires a container engine to function."
            exit 1
        fi
    else
        info_message "Trivy is already installed, skipping installation."
    fi
}

# Download and configure the trivy_scan.sh script
setup_trivy_scan_script() {
    info_message "Downloading trivy_scan.sh script..."
    if ! (maybe_sudo curl -SL -s "$TRIVY_SCAN_SCRIPT_URL" -o "$TRIVY_SCAN_SCRIPT_PATH"); then
        error_message "Failed to download trivy_scan.sh script."
        exit 1
    fi

    info_message "Setting permissions for trivy_scan.sh..."
    maybe_sudo chown "$OSSEC_USER:$OSSEC_GROUP" "$TRIVY_SCAN_SCRIPT_PATH"
    maybe_sudo chmod 750 "$TRIVY_SCAN_SCRIPT_PATH"

    success_message "trivy_scan.sh script downloaded and configured successfully."
}

# Ensure the remote_commands configuration is present in local_internal_options.conf
configure_remote_commands() {
    info_message "Checking if remote_commands configuration is present in $LOCAL_INTERNAL_OPTIONS_CONF..."
    if ! maybe_sudo grep -q "^$REMOTE_COMMANDS_CONFIG" "$LOCAL_INTERNAL_OPTIONS_CONF"; then
        info_message "Adding remote_commands configuration to $LOCAL_INTERNAL_OPTIONS_CONF..."
        echo "$REMOTE_COMMANDS_CONFIG" | maybe_sudo tee -a "$LOCAL_INTERNAL_OPTIONS_CONF" > /dev/null
        success_message "Remote commands configuration added successfully."
    else
        info_message "Remote commands configuration is already present."
    fi
}

create_trivy_log_file() {

    if [ ! -f "$TRIVY_SCAN_LOG_PATH" ]; then
        info_message "Creating trivy log file..."
        maybe_sudo touch "$TRIVY_SCAN_LOG_PATH"
        maybe_sudo chown "$OSSEC_USER:$OSSEC_GROUP" "$TRIVY_SCAN_LOG_PATH"
        success_message "Trivy log file created successfully."
    else
        info_message "Trivy log file already exists, skipping."
    fi
}

# Main script execution
info_message "Starting Trivy installation check."

# Check for container engine
if has_container_engine; then
    info_message "Container engine found. Proceeding with Trivy installation check."
    install_trivy

    setup_trivy_scan_script

    configure_remote_commands
    
    create_trivy_log_file
else
    error_message "No container engine (Docker or Podman) detected. Trivy cannot be installed."
    exit 1
fi

success_message "Trivy setup completed."