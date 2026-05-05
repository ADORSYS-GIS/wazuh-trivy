#!/bin/bash

# Check if we're running in bash; if not, adjust behavior
if [ -n "$BASH_VERSION" ]; then
    set -euo pipefail
else
    set -eu
fi

# OS guard early in the script
if [[ "$(uname -s)" != "Darwin" ]]; then
    printf "%s\n" "[ERROR] This installation script is intended for macOS systems. Please use the appropriate script for your operating system." >&2
    exit 1
fi

# Repository reference
WAZUH_TRIVY_REPO_REF=${WAZUH_TRIVY_REPO_REF:-"main"}
WAZUH_TRIVY_REPO_URL="https://raw.githubusercontent.com/ADORSYS-GIS/wazuh-trivy/${WAZUH_TRIVY_REPO_REF}"

# Source shared utilities
TMP_DIR=$(mktemp -d)
if ! curl -fsSL "${WAZUH_TRIVY_REPO_URL}/scripts/shared/utils.sh" -o "$TMP_DIR/utils.sh"; then
    echo "Failed to download utils.sh"
    exit 1
fi

# Function to calculate SHA256 (cross-platform bootstrap)
calculate_sha256_bootstrap() {
    local file="$1"
    if command -v sha256sum >/dev/null 2>&1; then
        sha256sum "$file" | awk '{print $1}'
    else
        shasum -a 256 "$file" | awk '{print $1}'
    fi
    return 0
}

# Download checksums and verify utils.sh integrity BEFORE sourcing it
if ! curl -fsSL "${WAZUH_TRIVY_REPO_URL}/checksums.sha256" -o "$TMP_DIR/checksums.sha256"; then
    echo "Failed to download checksums.sha256"
    exit 1
fi

EXPECTED_HASH=$(grep "scripts/shared/utils.sh" "$TMP_DIR/checksums.sha256" | awk '{print $1}')
ACTUAL_HASH=$(calculate_sha256_bootstrap "$TMP_DIR/utils.sh")

if [[ -z "$EXPECTED_HASH" ]] || [[ "$EXPECTED_HASH" != "$ACTUAL_HASH" ]]; then
    echo "Error: Checksum verification failed for utils.sh" >&2
    echo "Expected hash: $EXPECTED_HASH" >&2
    echo "Actual hash: $ACTUAL_HASH" >&2
    exit 1
fi

# shellcheck disable=SC1091
. "$TMP_DIR/utils.sh"

# Register cleanup to run on exit
trap cleanup EXIT

OSSEC_WODLES_DIR=${OSSEC_WODLES_DIR:-"/Library/Ossec/wodles"}
OSSEC_CONF_DIR=${OSSEC_CONF_DIR:-"/Library/Ossec/etc"}
OSSEC_LOG_DIR=${OSSEC_LOG_DIR:-"/Library/Ossec/logs"}
TRIVY_BIN_DIR=${TRIVY_BIN_DIR:-"/usr/local/bin"}

OSSEC_USER=${OSSEC_USER:-"root"}
OSSEC_GROUP=${OSSEC_GROUP:-"wazuh"}
TRIVY_VERSION=${TRIVY_VERSION:-"0.69.2"}
TRIVY_SCAN_SCRIPT_PATH=${TRIVY_SCAN_SCRIPT_PATH:-"$OSSEC_WODLES_DIR/trivy-scan.sh"}
TRIVY_SCAN_LOG_PATH=${TRIVY_SCAN_LOG_PATH:-"$OSSEC_LOG_DIR/trivy-scan.log"}
LOCAL_INTERNAL_OPTIONS_CONF=${LOCAL_INTERNAL_OPTIONS_CONF:-"$OSSEC_CONF_DIR/local_internal_options.conf"}
REMOTE_COMMANDS_CONFIG=${REMOTE_COMMANDS_CONFIG:-"wazuh_command.remote_commands=1"}

TRIVY_SCAN_SCRIPT_URL=${TRIVY_SCAN_SCRIPT_URL:-"https://raw.githubusercontent.com/ADORSYS-GIS/wazuh-trivy/$WAZUH_TRIVY_REPO_REF/scripts/macos/trivy-scan.sh"}

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

    download_and_verify_file "$TRIVY_SCAN_SCRIPT_URL" "$TRIVY_SCAN_SCRIPT_PATH" "scripts/macos/trivy-scan.sh" "trivy-scan.sh" "${WAZUH_TRIVY_REPO_URL}/checksums.sha256" "$TMP_DIR/checksums.sha256"
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

