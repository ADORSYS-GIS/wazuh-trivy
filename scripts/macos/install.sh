#!/bin/bash
# macOS-specific install logic

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../common.sh
. "$SCRIPT_DIR/../common.sh"

OSSEC_WODLES_DIR=${OSSEC_WODLES_DIR:-"/Library/Ossec/wodles"}
OSSEC_CONF_DIR=${OSSEC_CONF_DIR:-"/Library/Ossec/etc"}
OSSEC_LOG_DIR=${OSSEC_LOG_DIR:-"/Library/Ossec/logs"}
TRIVY_BIN_DIR=${TRIVY_BIN_DIR:-"/usr/local/bin"}

OSSEC_USER=${OSSEC_USER:-"root"}
OSSEC_GROUP=${OSSEC_GROUP:-"wazuh"}
TRIVY_VERSION=${TRIVY_VERSION:-"0.60.0"}
TRIVY_SCAN_SCRIPT_PATH=${TRIVY_SCAN_SCRIPT_PATH:-"$OSSEC_WODLES_DIR/trivy-scan.sh"}
TRIVY_SCAN_LOG_PATH=${TRIVY_SCAN_LOG_PATH:-"$OSSEC_LOG_DIR/trivy-scan.log"}
TRIVY_SCAN_SCRIPT_URL=${TRIVY_SCAN_SCRIPT_URL:-"https://raw.githubusercontent.com/ADORSYS-GIS/wazuh-trivy/main/trivy-scan.sh"}
LOCAL_INTERNAL_OPTIONS_CONF=${LOCAL_INTERNAL_OPTIONS_CONF:-"$OSSEC_CONF_DIR/local_internal_options.conf"}
REMOTE_COMMANDS_CONFIG=${REMOTE_COMMANDS_CONFIG:-"wazuh_command.remote_commands=1"}

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
    if ! (maybe_sudo curl -SL -s "$TRIVY_SCAN_SCRIPT_URL" -o "$TRIVY_SCAN_SCRIPT_PATH"); then
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

run_install() {
    if ! has_container_engine; then
        error_message "No container engine (Docker, Podman, or containerd) detected. Trivy cannot be installed."
        exit 1
    fi
    info_message "Container engine found. Proceeding with installation."
    install_trivy
    setup_trivy_scan_script
    configure_remote_commands
    create_trivy_log_file
}
