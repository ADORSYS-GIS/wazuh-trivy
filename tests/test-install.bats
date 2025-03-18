#!/usr/bin/env bats

setup() {
    # Determine the operating system
    if [ "$(uname)" = "Darwin" ]; then
        export OSSEC_WODLES_DIR="/Library/Ossec/wodles"
        export OSSEC_CONF_DIR="/Library/Ossec/etc"
        export OSSEC_LOG_DIR="/Library/Ossec/logs"
        export STAT_USER_FORMAT="-f %Su"
        export STAT_GROUP_FORMAT="-f %Sg"
    else
        export OSSEC_WODLES_DIR="/var/ossec/wodles"
        export OSSEC_CONF_DIR="/var/ossec/etc"
        export OSSEC_LOG_DIR="/var/ossec/logs"
        export STAT_USER_FORMAT="-c %U"
        export STAT_GROUP_FORMAT="-c %G"
    fi

    export OSSEC_USER="root"
    export OSSEC_GROUP="wazuh"
    export TRIVY_SCAN_SCRIPT_PATH="$OSSEC_WODLES_DIR/trivy-scan.sh"
    export TRIVY_SCAN_LOG_PATH="$OSSEC_LOG_DIR/trivy-scan.log"
    export LOCAL_INTERNAL_OPTIONS_CONF="$OSSEC_CONF_DIR/local_internal_options.conf"
}

@test "Trivy is installed" {
    run trivy --version
    [ "$status" -eq 0 ]
    [[ "$output" =~ "0.60.0" ]]
}

@test "trivy-scan.sh script is downloaded and configured" {
    run ./install.sh
    [ "$status" -eq 0 ]
    [ -f "$TRIVY_SCAN_SCRIPT_PATH" ]
    [ -x "$TRIVY_SCAN_SCRIPT_PATH" ]
    [ "$(sudo stat $STAT_USER_FORMAT "$TRIVY_SCAN_SCRIPT_PATH")" = "$OSSEC_USER" ]
    [ "$(sudo stat $STAT_GROUP_FORMAT "$TRIVY_SCAN_SCRIPT_PATH")" = "$OSSEC_GROUP" ]
}

@test "remote_commands configuration is present in local_internal_options.conf" {
    run ./install.sh
    [ "$status" -eq 0 ]
    grep -q "wazuh_command.remote_commands=1" "$LOCAL_INTERNAL_OPTIONS_CONF"
}

@test "Trivy log file is created" {
    run ./install.sh
    [ "$status" -eq 0 ]
    [ -f "$TRIVY_SCAN_LOG_PATH" ]
    [ "$(sudo stat $STAT_USER_FORMAT "$TRIVY_SCAN_LOG_PATH")" = "$OSSEC_USER" ]
    [ "$(sudo stat $STAT_GROUP_FORMAT "$TRIVY_SCAN_LOG_PATH")" = "$OSSEC_GROUP" ]
}