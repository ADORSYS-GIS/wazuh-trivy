#!/usr/bin/env bats

setup() {
    TEST_DIR="$(mktemp -d)"
    export TMP_DIR="$TEST_DIR"
    
    REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
    # shellcheck source=scripts/shared/utils.sh
    source "$REPO_ROOT/scripts/shared/utils.sh"
}

teardown() {
    rm -rf "$TEST_DIR"
}

# --- Tests for scripts/linux/uninstall.sh helpers ---

@test "sed_alternative uses sed or gsed" {
    maybe_sudo() {
        "$@"
    }
    local test_file="$TEST_DIR/sed_test.txt"
    echo "foo=1" > "$test_file"
    
    sed_alternative() {
        if command_exists gsed; then
            maybe_sudo gsed "$@"
        else
            maybe_sudo sed "$@"
        fi
    }
    
    sed_alternative -i 's/foo=1/foo=2/' "$test_file"
    [ "$(cat "$test_file")" = "foo=2" ]
}

@test "remove_remote_commands_config removes config when present" {
    maybe_sudo() {
        "$@"
    }
    local conf_file="$TEST_DIR/local_internal_options.conf"
    echo "some_other_config=yes" > "$conf_file"
    echo "wazuh_command.remote_commands=1" >> "$conf_file"
    
    export LOCAL_INTERNAL_OPTIONS_CONF="$conf_file"
    export REMOTE_COMMANDS_CONFIG="wazuh_command.remote_commands=1"
    
    sed_alternative() {
        sed "$@"
    }
    
    remove_remote_commands_config() {
        if [ -f "$LOCAL_INTERNAL_OPTIONS_CONF" ]; then
            if grep -q "^$REMOTE_COMMANDS_CONFIG" "$LOCAL_INTERNAL_OPTIONS_CONF"; then
                info_message "Removing remote_commands config from $LOCAL_INTERNAL_OPTIONS_CONF..."
                sed_alternative -i.bak "/^$REMOTE_COMMANDS_CONFIG/d" "$LOCAL_INTERNAL_OPTIONS_CONF"
                success_message "Remote commands configuration removed."
                info_message "Backup created at $LOCAL_INTERNAL_OPTIONS_CONF.bak"
            else
                info_message "Remote commands config not found, skipping."
            fi
        else
            warn_message "$LOCAL_INTERNAL_OPTIONS_CONF not found, skipping."
        fi
    }
    
    run remove_remote_commands_config
    [ "$status" -eq 0 ]
    [[ "$output" =~ "Remote commands configuration removed" ]]
    ! grep -q "wazuh_command.remote_commands=1" "$conf_file"
}

@test "remove_remote_commands_config skips when config is not in file" {
    local conf_file="$TEST_DIR/clean.conf"
    echo "unrelated=true" > "$conf_file"
    export LOCAL_INTERNAL_OPTIONS_CONF="$conf_file"
    export REMOTE_COMMANDS_CONFIG="wazuh_command.remote_commands=1"
    
    remove_remote_commands_config() {
        if [ -f "$LOCAL_INTERNAL_OPTIONS_CONF" ]; then
            if grep -q "^$REMOTE_COMMANDS_CONFIG" "$LOCAL_INTERNAL_OPTIONS_CONF"; then
                info_message "Removing remote_commands config..."
            else
                info_message "Remote commands config not found, skipping."
            fi
        else
            warn_message "$LOCAL_INTERNAL_OPTIONS_CONF not found, skipping."
        fi
    }
    
    run remove_remote_commands_config
    [ "$status" -eq 0 ]
    [[ "$output" =~ "Remote commands config not found, skipping" ]]
}

@test "remove_remote_commands_config skips when file does not exist" {
    export LOCAL_INTERNAL_OPTIONS_CONF="$TEST_DIR/nonexistent.conf"
    export REMOTE_COMMANDS_CONFIG="wazuh_command.remote_commands=1"
    
    remove_remote_commands_config() {
        if [ -f "$LOCAL_INTERNAL_OPTIONS_CONF" ]; then
            info_message "Found file"
        else
            warn_message "$LOCAL_INTERNAL_OPTIONS_CONF not found, skipping."
        fi
    }
    
    run remove_remote_commands_config
    [ "$status" -eq 0 ]
    [[ "$output" =~ "not found, skipping" ]]
}

@test "remove_trivy_files deletes scan script, log, and binary" {
    local scan_script="$TEST_DIR/trivy-scan.sh"
    local scan_log="$TEST_DIR/trivy-scan.log"
    local bin_file="$TEST_DIR/trivy"
    
    touch "$scan_script" "$scan_log" "$bin_file"
    
    export TRIVY_SCAN_SCRIPT_PATH="$scan_script"
    export TRIVY_SCAN_LOG_PATH="$scan_log"
    export TRIVY_BIN_DIR="$TEST_DIR"
    
    maybe_sudo() {
        "$@"
    }
    
    remove_trivy_files() {
        remove_file "$TRIVY_SCAN_SCRIPT_PATH"
        remove_file "$TRIVY_SCAN_LOG_PATH"
        remove_file "$TRIVY_BIN_DIR/trivy"
    }
    
    run remove_trivy_files
    [ "$status" -eq 0 ]
    [ ! -f "$scan_script" ]
    [ ! -f "$scan_log" ]
    [ ! -f "$bin_file" ]
}

# --- Tests for scripts/linux/install.sh helpers ---

@test "has_container_engine succeeds when docker, podman, or ctr is present" {
    has_container_engine() {
        if command_exists docker || command_exists podman || command_exists ctr; then
            return 0
        else
            return 1
        fi
    }
    
    command_exists() {
        if [[ "$1" == "docker" ]]; then
            return 0
        fi
        return 1
    }
    run has_container_engine
    [ "$status" -eq 0 ]
    
    command_exists() {
        if [[ "$1" == "podman" ]]; then
            return 0
        fi
        return 1
    }
    run has_container_engine
    [ "$status" -eq 0 ]
    
    command_exists() {
        if [[ "$1" == "ctr" ]]; then
            return 0
        fi
        return 1
    }
    run has_container_engine
    [ "$status" -eq 0 ]
}

@test "has_container_engine fails when none are present" {
    has_container_engine() {
        if command_exists docker || command_exists podman || command_exists ctr; then
            return 0
        else
            return 1
        fi
    }
    command_exists() {
        return 1
    }
    run has_container_engine
    [ "$status" -eq 1 ]
}

@test "install_trivy skips installation when matching version already installed" {
    export TRIVY_VERSION="0.69.2"
    
    command_exists() {
        if [[ "$1" == "trivy" ]]; then
            return 0
        fi
        return 1
    }
    trivy() {
        echo "Version: 0.69.2"
    }
    
    install_trivy() {
        local installed_version=""
        if command_exists trivy; then
            installed_version="$(trivy --version 2>/dev/null | awk '/Version:/ {print $2}')"
            if [ "$installed_version" = "$TRIVY_VERSION" ]; then
                info_message "Trivy $TRIVY_VERSION is already installed, skipping installation."
                return 0
            fi
        fi
        return 1
    }
    
    run install_trivy
    [ "$status" -eq 0 ]
    [[ "$output" =~ "already installed, skipping installation" ]]
}

@test "configure_remote_commands appends config when absent" {
    local conf_file="$TEST_DIR/local_internal_options.conf"
    touch "$conf_file"
    
    export LOCAL_INTERNAL_OPTIONS_CONF="$conf_file"
    export REMOTE_COMMANDS_CONFIG="wazuh_command.remote_commands=1"
    
    maybe_sudo() {
        "$@"
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
    
    run configure_remote_commands
    [ "$status" -eq 0 ]
    [[ "$output" =~ "Remote commands configuration added" ]]
    grep -q "wazuh_command.remote_commands=1" "$conf_file"
    
    # Run again: should see already present
    run configure_remote_commands
    [ "$status" -eq 0 ]
    [[ "$output" =~ "Remote commands configuration already present" ]]
}

@test "create_trivy_log_file creates log file with permissions" {
    local log_file="$TEST_DIR/logs/trivy-scan.log"
    export TRIVY_SCAN_LOG_PATH="$log_file"
    export OSSEC_USER="root"
    export OSSEC_GROUP="wazuh"
    
    maybe_sudo() {
        local cmd="$1"
        shift
        if [[ "$cmd" == "chown" ]]; then
            return 0
        fi
        "$cmd" "$@"
    }
    
    create_trivy_log_file() {
        if [ ! -f "$TRIVY_SCAN_LOG_PATH" ]; then
            info_message "Creating trivy log file..."
            maybe_sudo mkdir -p "$(dirname "$TRIVY_SCAN_LOG_PATH")"
            maybe_sudo touch "$TRIVY_SCAN_LOG_PATH"
            maybe_sudo chown "$OSSEC_USER:$OSSEC_GROUP" "$TRIVY_SCAN_LOG_PATH"
            success_message "Trivy log file created."
        else
            info_message "Trivy log file already exists, skipping."
        fi
    }
    
    run create_trivy_log_file
    [ "$status" -eq 0 ]
    [ -f "$log_file" ]
    [[ "$output" =~ "Trivy log file created" ]]
    
    # Run again: should skip
    run create_trivy_log_file
    [ "$status" -eq 0 ]
    [[ "$output" =~ "already exists, skipping" ]]
}

# --- Tests for scripts/linux/trivy-scan.sh helpers ---

@test "detect_container_engine detects docker, podman, and containerd" {
    detect_container_engine() {
        if command -v docker &> /dev/null; then
            echo "docker"
        elif command -v podman &> /dev/null; then
            echo "podman"
        elif command -v ctr &> /dev/null; then
            echo "containerd"
        else
            echo "No supported container engine found."
            return 1
        fi
    }
    
    local active_engine=""
    command() {
        if [[ "$1" == "-v" ]]; then
            [[ "$2" == "$active_engine" ]] && return 0
            return 1
        fi
        builtin command "$@"
    }
    
    # Docker
    active_engine="docker"
    run detect_container_engine
    [ "$status" -eq 0 ]
    [ "$output" = "docker" ]
    
    # Podman
    active_engine="podman"
    run detect_container_engine
    [ "$status" -eq 0 ]
    [ "$output" = "podman" ]
    
    # Containerd
    active_engine="ctr"
    run detect_container_engine
    [ "$status" -eq 0 ]
    [ "$output" = "containerd" ]
    
    # None
    active_engine="none"
    run detect_container_engine
    [ "$status" -eq 1 ]
    [[ "$output" =~ "No supported container engine found" ]]
}
