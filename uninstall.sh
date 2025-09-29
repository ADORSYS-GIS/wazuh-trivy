#!/bin/bash

# Check if we're running in bash; if not, adjust behavior
if [ -n "$BASH_VERSION" ]; then
    set -euo pipefail
else
    set -eu
fi

LOG_LEVEL=${LOG_LEVEL:-"INFO"}
TRIVY_VERSION=${TRIVY_VERSION:-"v0.60.0"}

if [ "$(uname)" = "Darwin" ]; then
    OSSEC_WODLES_DIR=${OSSEC_WODLES_DIR:-"/Library/Ossec/wodles"}
    OSSEC_CONF_DIR=${OSSEC_CONF_DIR:-"/Library/Ossec/etc"}
    OSSEC_LOG_DIR=${OSSEC_LOG_DIR:-"/Library/Ossec/logs"}
    TRIVY_BIN_DIR=${TRIVY_BIN_DIR:-"/usr/local/bin"}
else
    OSSEC_WODLES_DIR=${OSSEC_WODLES_DIR:-"/var/ossec/wodles"}
    OSSEC_CONF_DIR=${OSSEC_CONF_DIR:-"/var/ossec/etc"}
    OSSEC_LOG_DIR=${OSSEC_LOG_DIR:-"/var/ossec/logs"}
    TRIVY_BIN_DIR=${TRIVY_BIN_DIR:-"/usr/bin"}
fi
OSSEC_USER=${OSSEC_USER:-"root"}
OSSEC_GROUP=${OSSEC_GROUP:-"wazuh"}
TRIVY_SCAN_SCRIPT_PATH=${TRIVY_SCAN_SCRIPT_PATH:-"$OSSEC_WODLES_DIR/trivy-scan.sh"}
TRIVY_SCAN_LOG_PATH=${TRIVY_SCAN_LOG_PATH:-"$OSSEC_LOG_DIR/trivy-scan.log"}
LOCAL_INTERNAL_OPTIONS_CONF=${LOCAL_INTERNAL_OPTIONS_CONF:-"$OSSEC_CONF_DIR/local_internal_options.conf"}
REMOTE_COMMANDS_CONFIG=${REMOTE_COMMANDS_CONFIG:-"wazuh_command.remote_commands=1"} 

# Define text formatting
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[1;34m'
BOLD='\033[1m'
NORMAL='\033[0m'

# Logging functions
log() {
    local LEVEL="$1"
    shift
    local MESSAGE="$*"
    local TIMESTAMP
    TIMESTAMP=$(date +"%Y-%m-%d %H:%M:%S")
    echo -e "${TIMESTAMP} ${LEVEL} ${MESSAGE}"
}
info_message()    { log "${BLUE}${BOLD}[INFO]${NORMAL}" "$*"; }
warning_message() { log "${YELLOW}${BOLD}[WARN]${NORMAL}" "$*"; }
error_message()   { log "${RED}${BOLD}[ERROR]${NORMAL}" "$*"; }
success_message() { log "${GREEN}${BOLD}[SUCCESS]${NORMAL}" "$*"; }

command_exists() {
    command -v "$1" >/dev/null 2>&1
}

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

sed_alternative() {
    if command_exists gsed; then
        maybe_sudo gsed "$@"
    else
        maybe_sudo sed "$@"
    fi
}

remove_trivy_binary() {
    if [ -f "$TRIVY_BIN_DIR/trivy" ]; then
        info_message "Removing Trivy binary from $TRIVY_BIN_DIR..."
        maybe_sudo rm -f "$TRIVY_BIN_DIR/trivy"
        success_message "Trivy binary removed."
    else
        info_message "No Trivy binary found at $TRIVY_BIN_DIR, skipping."
    fi
}

remove_trivy_scan_script() {
    if [ -f "$TRIVY_SCAN_SCRIPT_PATH" ]; then
        info_message "Removing trivy-scan.sh script..."
        maybe_sudo rm -f "$TRIVY_SCAN_SCRIPT_PATH"
        success_message "trivy-scan.sh removed."
    else
        info_message "No trivy-scan.sh found, skipping."
    fi
}

remove_trivy_log_file() {
    if [ -f "$TRIVY_SCAN_LOG_PATH" ]; then
        info_message "Removing Trivy scan log file..."
        maybe_sudo rm -f "$TRIVY_SCAN_LOG_PATH"
        success_message "Trivy log file removed."
    else
        info_message "No Trivy log file found, skipping."
    fi
}

remove_remote_commands_config() {
    if [ -f "$LOCAL_INTERNAL_OPTIONS_CONF" ]; then
        if grep -q "^$REMOTE_COMMANDS_CONFIG" "$LOCAL_INTERNAL_OPTIONS_CONF"; then
            info_message "Removing remote_commands configuration from $LOCAL_INTERNAL_OPTIONS_CONF..."
            sed_alternative -i.bak "/^$REMOTE_COMMANDS_CONFIG/d" "$LOCAL_INTERNAL_OPTIONS_CONF"
            success_message "Remote commands configuration removed."
            info_message "Backup created at $LOCAL_INTERNAL_OPTIONS_CONF.bak"
        else
            info_message "Remote commands config not found in $LOCAL_INTERNAL_OPTIONS_CONF, skipping."
        fi
    else
        warning_message "$LOCAL_INTERNAL_OPTIONS_CONF not found, skipping remote commands cleanup."
    fi
}

# Main uninstall process
info_message "Starting Trivy uninstallation process..."

remove_trivy_binary
remove_trivy_scan_script
remove_trivy_log_file
remove_remote_commands_config

success_message "Trivy uninstall completed."