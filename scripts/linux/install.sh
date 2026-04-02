#!/bin/bash

# Check if we're running in bash; if not, adjust behavior
if [ -n "$BASH_VERSION" ]; then
    set -euo pipefail
else
    set -eu
fi

OSSEC_WODLES_DIR=${OSSEC_WODLES_DIR:-"/var/ossec/wodles"}
OSSEC_CONF_DIR=${OSSEC_CONF_DIR:-"/var/ossec/etc"}
OSSEC_LOG_DIR=${OSSEC_LOG_DIR:-"/var/ossec/logs"}
TRIVY_BIN_DIR=${TRIVY_BIN_DIR:-"/usr/bin"}

OSSEC_USER=${OSSEC_USER:-"root"}
OSSEC_GROUP=${OSSEC_GROUP:-"wazuh"}
TRIVY_VERSION=${TRIVY_VERSION:-"0.69.2"}
TRIVY_SCAN_SCRIPT_PATH=${TRIVY_SCAN_SCRIPT_PATH:-"$OSSEC_WODLES_DIR/trivy-scan.sh"}
TRIVY_SCAN_LOG_PATH=${TRIVY_SCAN_LOG_PATH:-"$OSSEC_LOG_DIR/trivy-scan.log"}
LOCAL_INTERNAL_OPTIONS_CONF=${LOCAL_INTERNAL_OPTIONS_CONF:-"$OSSEC_CONF_DIR/local_internal_options.conf"}
REMOTE_COMMANDS_CONFIG=${REMOTE_COMMANDS_CONFIG:-"wazuh_command.remote_commands=1"}

WAZUH_TRIVY_REPO_REF=${WAZUH_TRIVY_REPO_REF:-"main"}
TRIVY_SCAN_SCRIPT_URL=${TRIVY_SCAN_SCRIPT_URL:-"https://raw.githubusercontent.com/ADORSYS-GIS/wazuh-trivy/$WAZUH_TRIVY_REPO_REF/scripts/linux/trivy-scan.sh"}

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

# Check if a container engine (Docker or Podman or Containerd) is installed
has_container_engine() {
    if command_exists docker || command_exists podman || command_exists ctr; then
        return 0
    else
        return 1
    fi
}

install_trivy() {
    local installed_version=""
    if command_exists trivy; then
        installed_version="$(trivy --version 2>/dev/null | awk '/Version:/ {print $2}')"
        if [ "$installed_version" = "$TRIVY_VERSION" ]; then
            info_message "Trivy $TRIVY_VERSION is already installed, skipping installation."
            return
        else
            info_message "Trivy $installed_version found but $TRIVY_VERSION required. Reinstalling..."
        fi
    else
        info_message "Trivy not found. Installing Trivy $TRIVY_VERSION..."
    fi

    if ! (maybe_sudo curl -sfL https://raw.githubusercontent.com/aquasecurity/trivy/main/contrib/install.sh | sh -s -- -b "$TRIVY_BIN_DIR" "v$TRIVY_VERSION"); then
        error_message "Failed to install Trivy."
        exit 1
    fi
    success_message "Trivy $TRIVY_VERSION installed successfully."
}

setup_trivy_scan_script() {
    info_message "Downloading trivy-scan.sh script..."
    maybe_sudo mkdir -p "$(dirname "$TRIVY_SCAN_SCRIPT_PATH")"
    info_message "Trivy scan script URL: $TRIVY_SCAN_SCRIPT_URL"

    if ! (maybe_sudo curl -fSL --create-dirs -s "$TRIVY_SCAN_SCRIPT_URL" -o "$TRIVY_SCAN_SCRIPT_PATH"); then
        error_message "Failed to download trivy-scan.sh script."
        exit 1
    fi
    maybe_sudo chown "$OSSEC_USER:$OSSEC_GROUP" "$TRIVY_SCAN_SCRIPT_PATH"
    maybe_sudo chmod 750 "$TRIVY_SCAN_SCRIPT_PATH"
    success_message "trivy-scan.sh downloaded and configured."
}

configure_remote_commands() {
    info_message "Checking remote_commands config in $LOCAL_INTERNAL_OPTIONS_CONF..."
    if ! maybe_sudo grep -q "^$REMOTE_COMMANDS_CONFIG" "$LOCAL_INTERNAL_OPTIONS_CONF"; then
        echo "$REMOTE_COMMANDS_CONFIG" | maybe_sudo tee -a "$LOCAL_INTERNAL_OPTIONS_CONF" > /dev/null
        success_message "Remote commands configuration added."
    else
        info_message "Remote commands configuration already present."
    fi
}

create_trivy_log_file() {
    if [ ! -f "$TRIVY_SCAN_LOG_PATH" ]; then
        info_message "Creating trivy log file..."
        maybe_sudo touch "$TRIVY_SCAN_LOG_PATH"
        maybe_sudo chown "$OSSEC_USER:$OSSEC_GROUP" "$TRIVY_SCAN_LOG_PATH"
        success_message "Trivy log file created."
    else
        info_message "Trivy log file already exists, skipping."
    fi
}

if ! has_container_engine; then
    error_message "No container engine (Docker, Podman, or containerd) detected. Trivy cannot be installed."
    exit 1
fi
info_message "Container engine found. Proceeding with installation."
install_trivy
setup_trivy_scan_script
configure_remote_commands
create_trivy_log_file
