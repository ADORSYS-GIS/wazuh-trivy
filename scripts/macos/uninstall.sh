#!/bin/bash
# macOS-specific uninstall logic

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../common.sh
. "$SCRIPT_DIR/../common.sh"

OSSEC_WODLES_DIR=${OSSEC_WODLES_DIR:-"/Library/Ossec/wodles"}
OSSEC_CONF_DIR=${OSSEC_CONF_DIR:-"/Library/Ossec/etc"}
OSSEC_LOG_DIR=${OSSEC_LOG_DIR:-"/Library/Ossec/logs"}
TRIVY_BIN_DIR=${TRIVY_BIN_DIR:-"/usr/local/bin"}

TRIVY_SCAN_SCRIPT_PATH=${TRIVY_SCAN_SCRIPT_PATH:-"$OSSEC_WODLES_DIR/trivy-scan.sh"}
TRIVY_SCAN_LOG_PATH=${TRIVY_SCAN_LOG_PATH:-"$OSSEC_LOG_DIR/trivy-scan.log"}
LOCAL_INTERNAL_OPTIONS_CONF=${LOCAL_INTERNAL_OPTIONS_CONF:-"$OSSEC_CONF_DIR/local_internal_options.conf"}
REMOTE_COMMANDS_CONFIG=${REMOTE_COMMANDS_CONFIG:-"wazuh_command.remote_commands=1"}

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
            info_message "Removing remote_commands config from $LOCAL_INTERNAL_OPTIONS_CONF..."
            # macOS sed requires a backup extension with -i
            maybe_sudo sed -i.bak "/^$REMOTE_COMMANDS_CONFIG/d" "$LOCAL_INTERNAL_OPTIONS_CONF"
            success_message "Remote commands configuration removed."
            info_message "Backup created at $LOCAL_INTERNAL_OPTIONS_CONF.bak"
        else
            info_message "Remote commands config not found, skipping."
        fi
    else
        warning_message "$LOCAL_INTERNAL_OPTIONS_CONF not found, skipping."
    fi
}

run_uninstall() {
    remove_trivy_binary
    remove_trivy_scan_script
    remove_trivy_log_file
    remove_remote_commands_config
}
