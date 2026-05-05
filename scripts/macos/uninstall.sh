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

# Variables
OSSEC_WODLES_DIR=${OSSEC_WODLES_DIR:-"/Library/Ossec/wodles"}
OSSEC_CONF_DIR=${OSSEC_CONF_DIR:-"/Library/Ossec/etc"}
OSSEC_LOG_DIR=${OSSEC_LOG_DIR:-"/Library/Ossec/logs"}
TRIVY_BIN_DIR=${TRIVY_BIN_DIR:-"/usr/local/bin"}

TRIVY_SCAN_SCRIPT_PATH=${TRIVY_SCAN_SCRIPT_PATH:-"$OSSEC_WODLES_DIR/trivy-scan.sh"}
TRIVY_SCAN_LOG_PATH=${TRIVY_SCAN_LOG_PATH:-"$OSSEC_LOG_DIR/trivy-scan.log"}
LOCAL_INTERNAL_OPTIONS_CONF=${LOCAL_INTERNAL_OPTIONS_CONF:-"$OSSEC_CONF_DIR/local_internal_options.conf"}
REMOTE_COMMANDS_CONFIG=${REMOTE_COMMANDS_CONFIG:-"wazuh_command.remote_commands=1"}

sed_alternative() {
    if command_exists gsed; then
        maybe_sudo gsed "$@"
    else
        maybe_sudo sed "$@"
    fi
}

remove_trivy_files() {
    remove_file "$TRIVY_SCAN_SCRIPT_PATH"
    remove_file "$TRIVY_SCAN_LOG_PATH"
    remove_file "$TRIVY_BIN_DIR/trivy"
}

remove_remote_commands_config() {
    if [ -f "$LOCAL_INTERNAL_OPTIONS_CONF" ]; then
        if grep -q "^$REMOTE_COMMANDS_CONFIG" "$LOCAL_INTERNAL_OPTIONS_CONF"; then
            info_message "Removing remote_commands config from $LOCAL_INTERNAL_OPTIONS_CONF..."
            # macOS sed requires a backup extension with -i
            sed_alternative -i.bak "/^$REMOTE_COMMANDS_CONFIG/d" "$LOCAL_INTERNAL_OPTIONS_CONF"
            success_message "Remote commands configuration removed."
            info_message "Backup created at $LOCAL_INTERNAL_OPTIONS_CONF.bak"
        else
            info_message "Remote commands config not found, skipping."
        fi
    else
        warning_message "$LOCAL_INTERNAL_OPTIONS_CONF not found, skipping."
    fi
}

remove_trivy_files
remove_remote_commands_config
