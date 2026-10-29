#!/usr/bin/env bats

setup() {
    export REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
    export TEST_DIR="$(mktemp -d)"
    export MOCK_BIN="$TEST_DIR/bin"
    export SYSBIN="$TEST_DIR/sysbin"
    mkdir -p "$MOCK_BIN" "$SYSBIN"

    # Link host standard utilities into SYSBIN
    for cmd in chmod mkdir date uname id mktemp rm touch env sh bash cat sed awk grep sleep head tail cp mv tr dirname wc sha256sum shasum cut sort echo printf which [ basename tee; do
        p="$(which "$cmd" 2>/dev/null || true)"
        [ -n "$p" ] && ln -s "$p" "$SYSBIN/$cmd"
    done

    # Mock sudo: pass through arguments cleanly
    cat << 'EOF' > "$MOCK_BIN/sudo"
#!/bin/sh
while [ $# -gt 0 ]; do
    case "$1" in
        -*) shift ;;
        *) break ;;
    esac
done
exec "$@"
EOF
    chmod +x "$MOCK_BIN/sudo"

    # Mock chown: no-op to allow non-root test runs
    cat << 'EOF' > "$MOCK_BIN/chown"
#!/bin/sh
exit 0
EOF
    chmod +x "$MOCK_BIN/chown"

    # Mock uname: default to Linux unless overridden by MOCK_UNAME_S
    cat << 'EOF' > "$MOCK_BIN/uname"
#!/bin/sh
case "$1" in
    -s|"")
        echo "${MOCK_UNAME_S:-Linux}"
        ;;
    *)
        command uname "$@"
        ;;
esac
exit 0
EOF
    chmod +x "$MOCK_BIN/uname"

    # Smart mock curl for local files and checksum generation
    cat << 'EOF' > "$MOCK_BIN/curl"
#!/bin/bash
target_out=""
url=""
while [[ $# -gt 0 ]]; do
    case "$1" in
        -o)
            target_out="$2"
            shift 2
            ;;
        http*)
            url="$1"
            shift
            ;;
        *)
            shift
            ;;
    esac
done

if [[ "$MOCK_CURL_FAIL" == "1" ]]; then
    exit 1
fi

emit_content() {
    if [[ "$url" == *"checksums.sha256"* ]]; then
        if [[ "$MOCK_CORRUPT_CHECKSUM" == "1" ]]; then
            echo "deadbeefdeadbeef  scripts/shared/utils.sh"
            echo "deadbeefdeadbeef  scripts/linux/trivy-scan.sh"
            echo "deadbeefdeadbeef  scripts/macos/trivy-scan.sh"
        else
            for p in scripts/shared/utils.sh scripts/linux/trivy-scan.sh scripts/macos/trivy-scan.sh scripts/linux/install.sh scripts/linux/uninstall.sh; do
                if [ -f "$REPO_ROOT/$p" ]; then
                    h=$(sha256sum "$REPO_ROOT/$p" | awk '{print $1}')
                    echo "$h  $p"
                fi
            done
        fi
    elif [[ "$url" == *"scripts/shared/utils.sh"* ]]; then
        cat "$REPO_ROOT/scripts/shared/utils.sh"
    elif [[ "$url" == *"scripts/macos/trivy-scan.sh"* ]]; then
        cat "$REPO_ROOT/scripts/macos/trivy-scan.sh"
    elif [[ "$url" == *"scripts/linux/trivy-scan.sh"* || "$url" == *"trivy-scan.sh"* ]]; then
        cat "$REPO_ROOT/scripts/linux/trivy-scan.sh"
    elif [[ "$url" == *"aquasecurity/trivy"* ]]; then
        echo "#!/bin/sh"
        echo "echo 'mock trivy installer executed'"
    else
        echo "mock download content"
    fi
}

if [[ -n "$target_out" ]]; then
    emit_content > "$target_out"
else
    emit_content
fi
exit 0
EOF
    chmod +x "$MOCK_BIN/curl"

    # Mock docker
    cat << 'EOF' > "$MOCK_BIN/docker"
#!/bin/bash
if [[ "$MOCK_DOCKER_FAIL" == "1" ]]; then
    exit 1
fi
if [[ "$1" == "images" ]]; then
    if [[ "$MOCK_NO_IMAGES" == "1" ]]; then
        exit 0
    fi
    echo "alpine:latest"
    echo "nginx:1.25"
    exit 0
fi
exit 0
EOF
    chmod +x "$MOCK_BIN/docker"

    # Mock trivy
    cat << 'EOF' > "$MOCK_BIN/trivy"
#!/bin/bash
if [[ "$1" == "--version" ]]; then
    echo "Version: ${MOCK_TRIVY_VERSION:-0.69.2}"
    exit 0
fi
echo '"Package","Version Installed","Vulnerability ID","Severity"'
echo '"openssl","1.1.1","CVE-2023-0001","HIGH"'
exit 0
EOF
    chmod +x "$MOCK_BIN/trivy"

    # Set up isolated directories
    export OSSEC_WODLES_DIR="$TEST_DIR/wodles"
    export OSSEC_CONF_DIR="$TEST_DIR/etc"
    export OSSEC_LOG_DIR="$TEST_DIR/logs"
    export TRIVY_BIN_DIR="$TEST_DIR/bin"
    export OSSEC_USER="$(id -un)"
    export OSSEC_GROUP="$(id -gn)"
    export LOCAL_INTERNAL_OPTIONS_CONF="$OSSEC_CONF_DIR/local_internal_options.conf"
    export TRIVY_SCAN_SCRIPT_PATH="$OSSEC_WODLES_DIR/trivy-scan.sh"
    export TRIVY_SCAN_LOG_PATH="$OSSEC_LOG_DIR/trivy-scan.log"
    export LOG_FILE="$TRIVY_SCAN_LOG_PATH"
    export TEMPLATE_FILE="$TEST_DIR/trivy-custom.tmpl"
    export WAZUH_TRIVY_REPO_REF="main"
    export WAZUH_TRIVY_REPO_URL="https://raw.githubusercontent.com/ADORSYS-GIS/wazuh-trivy/$WAZUH_TRIVY_REPO_REF"

    mkdir -p "$OSSEC_WODLES_DIR" "$OSSEC_CONF_DIR" "$OSSEC_LOG_DIR" "$TRIVY_BIN_DIR"
    touch "$LOCAL_INTERNAL_OPTIONS_CONF"

    export ORIGINAL_PATH="$PATH"
    export PATH="$MOCK_BIN:$SYSBIN"
}

teardown() {
    export PATH="$ORIGINAL_PATH"
    rm -rf "$TEST_DIR"
}

# =============================================================================
# scripts/linux/install.sh tests
# =============================================================================

@test "scripts/linux/install.sh: executes successfully and installs all components" {
    run bash "$REPO_ROOT/scripts/linux/install.sh"
    [ "$status" -eq 0 ]
    [ -f "$TRIVY_SCAN_SCRIPT_PATH" ]
    [ -x "$TRIVY_SCAN_SCRIPT_PATH" ]
    [ -f "$TRIVY_SCAN_LOG_PATH" ]
    grep -q "wazuh_command.remote_commands=1" "$LOCAL_INTERNAL_OPTIONS_CONF"
    [[ "$output" =~ "Container engine found" ]]
    [[ "$output" =~ "already installed, skipping installation" ]]
    [[ "$output" =~ "trivy-scan.sh downloaded and configured" ]]
}

@test "scripts/linux/install.sh: reinstalls trivy when version does not match" {
    export MOCK_TRIVY_VERSION="0.50.0"
    run bash "$REPO_ROOT/scripts/linux/install.sh"
    [ "$status" -eq 0 ]
    [[ "$output" =~ "found but 0.69.2 required. Reinstalling..." ]]
    [[ "$output" =~ "Trivy 0.69.2 installed successfully" ]]
}

@test "scripts/linux/install.sh: installs trivy when binary is not found" {
    rm -f "$MOCK_BIN/trivy"
    run bash "$REPO_ROOT/scripts/linux/install.sh"
    [ "$status" -eq 0 ]
    [[ "$output" =~ "Trivy not found. Installing Trivy 0.69.2..." ]]
    [[ "$output" =~ "Trivy 0.69.2 installed successfully" ]]
}

@test "scripts/linux/install.sh: fails when no container engine is available" {
    rm -f "$MOCK_BIN/docker"
    run bash "$REPO_ROOT/scripts/linux/install.sh"
    [ "$status" -eq 1 ]
    [[ "$output" =~ "No container engine (Docker, Podman, or containerd) detected" ]]
}

@test "scripts/linux/install.sh: aborts on utils checksum mismatch" {
    export MOCK_CORRUPT_CHECKSUM="1"
    run bash "$REPO_ROOT/scripts/linux/install.sh"
    [ "$status" -eq 1 ]
    [[ "$output" =~ "Checksum verification failed for utils.sh" ]]
}

@test "scripts/linux/install.sh: idempotency preserves existing configuration" {
    # First install
    run bash "$REPO_ROOT/scripts/linux/install.sh"
    [ "$status" -eq 0 ]

    # Second install
    run bash "$REPO_ROOT/scripts/linux/install.sh"
    [ "$status" -eq 0 ]
    [[ "$output" =~ "Remote commands configuration already present" ]]
    [[ "$output" =~ "Trivy log file already exists, skipping" ]]
}

# =============================================================================
# scripts/linux/uninstall.sh tests
# =============================================================================

@test "scripts/linux/uninstall.sh: removes trivy files and config cleanly" {
    # Create target files
    touch "$TRIVY_SCAN_SCRIPT_PATH" "$TRIVY_SCAN_LOG_PATH" "$TRIVY_BIN_DIR/trivy"
    echo "other_option=true" > "$LOCAL_INTERNAL_OPTIONS_CONF"
    echo "wazuh_command.remote_commands=1" >> "$LOCAL_INTERNAL_OPTIONS_CONF"

    run bash "$REPO_ROOT/scripts/linux/uninstall.sh"
    [ "$status" -eq 0 ]
    [ ! -f "$TRIVY_SCAN_SCRIPT_PATH" ]
    [ ! -f "$TRIVY_SCAN_LOG_PATH" ]
    [ ! -f "$TRIVY_BIN_DIR/trivy" ]
    ! grep -q "wazuh_command.remote_commands=1" "$LOCAL_INTERNAL_OPTIONS_CONF"
    grep -q "other_option=true" "$LOCAL_INTERNAL_OPTIONS_CONF"
    [ -f "$LOCAL_INTERNAL_OPTIONS_CONF.bak" ]
    [[ "$output" =~ "Remote commands configuration removed" ]]
}

@test "scripts/linux/uninstall.sh: skips config removal when not present" {
    echo "other_option=true" > "$LOCAL_INTERNAL_OPTIONS_CONF"
    run bash "$REPO_ROOT/scripts/linux/uninstall.sh"
    [ "$status" -eq 0 ]
    [[ "$output" =~ "Remote commands config not found, skipping" ]]
}

@test "scripts/linux/uninstall.sh: skips config removal when file does not exist" {
    rm -f "$LOCAL_INTERNAL_OPTIONS_CONF"
    run bash "$REPO_ROOT/scripts/linux/uninstall.sh"
    [ "$status" -eq 0 ]
    [[ "$output" =~ "not found, skipping" ]]
}

@test "scripts/linux/uninstall.sh: aborts on utils checksum mismatch" {
    export MOCK_CORRUPT_CHECKSUM="1"
    run bash "$REPO_ROOT/scripts/linux/uninstall.sh"
    [ "$status" -eq 1 ]
    [[ "$output" =~ "Checksum verification failed for utils.sh" ]]
}

# =============================================================================
# scripts/linux/trivy-scan.sh tests
# =============================================================================

@test "scripts/linux/trivy-scan.sh: scans docker images and logs results" {
    run bash "$REPO_ROOT/scripts/linux/trivy-scan.sh"
    [ "$status" -eq 0 ]
    [ -f "$TRIVY_SCAN_LOG_PATH" ]
    grep -q 'Trivy:"alpine:latest"' "$TRIVY_SCAN_LOG_PATH"
    grep -q 'CVE-2023-0001' "$TRIVY_SCAN_LOG_PATH"
}

@test "scripts/linux/trivy-scan.sh: works with podman engine" {
    rm -f "$MOCK_BIN/docker"
    cat << 'EOF' > "$MOCK_BIN/podman"
#!/bin/bash
if [[ "$1" == "images" ]]; then
    echo "fedora:latest"
    exit 0
fi
exit 0
EOF
    chmod +x "$MOCK_BIN/podman"

    run bash "$REPO_ROOT/scripts/linux/trivy-scan.sh"
    [ "$status" -eq 0 ]
    grep -q 'Trivy:"fedora:latest"' "$TRIVY_SCAN_LOG_PATH"
}

@test "scripts/linux/trivy-scan.sh: works with containerd ctr engine" {
    rm -f "$MOCK_BIN/docker"
    cat << 'EOF' > "$MOCK_BIN/ctr"
#!/bin/bash
if [[ "$1" == "namespaces" ]]; then
    echo "k8s.io"
    exit 0
fi
if [[ "$1" == "-n" && "$3" == "images" ]]; then
    echo "docker.io/library/busybox:latest"
    exit 0
fi
exit 0
EOF
    chmod +x "$MOCK_BIN/ctr"

    run bash "$REPO_ROOT/scripts/linux/trivy-scan.sh"
    [ "$status" -eq 0 ]
    grep -q 'Trivy:"docker.io/library/busybox:latest"' "$TRIVY_SCAN_LOG_PATH"
}

@test "scripts/linux/trivy-scan.sh: exits when no container engine detected" {
    rm -f "$MOCK_BIN/docker" "$MOCK_BIN/podman" "$MOCK_BIN/ctr"
    run bash "$REPO_ROOT/scripts/linux/trivy-scan.sh"
    [ "$status" -eq 1 ]
    [[ "$output" =~ "No supported container engine found" ]]
}

@test "scripts/linux/trivy-scan.sh: logs and exits when no images found" {
    export MOCK_NO_IMAGES="1"
    run bash "$REPO_ROOT/scripts/linux/trivy-scan.sh"
    [ "$status" -eq 1 ]
    grep -q "Trivy: No images found. Exiting..." "$TRIVY_SCAN_LOG_PATH"
}

# =============================================================================
# OS guard tests
# =============================================================================

@test "scripts/linux/install.sh: aborts on non-Linux system" {
    export MOCK_UNAME_S="Darwin"
    run bash "$REPO_ROOT/scripts/linux/install.sh"
    [ "$status" -eq 1 ]
    [[ "$output" =~ "intended for Linux systems" ]]
}

@test "scripts/linux/uninstall.sh: aborts on non-Linux system" {
    export MOCK_UNAME_S="Darwin"
    run bash "$REPO_ROOT/scripts/linux/uninstall.sh"
    [ "$status" -eq 1 ]
    [[ "$output" =~ "intended for Linux systems" ]]
}

@test "scripts/macos/install.sh: aborts on non-macOS system" {
    export MOCK_UNAME_S="Linux"
    run bash "$REPO_ROOT/scripts/macos/install.sh"
    [ "$status" -eq 1 ]
    [[ "$output" =~ "intended for macOS systems" ]]
}

@test "scripts/macos/uninstall.sh: aborts on non-macOS system" {
    export MOCK_UNAME_S="Linux"
    run bash "$REPO_ROOT/scripts/macos/uninstall.sh"
    [ "$status" -eq 1 ]
    [[ "$output" =~ "intended for macOS systems" ]]
}

# =============================================================================
# macOS execution tests (with Darwin OS mock)
# =============================================================================

@test "scripts/macos/install.sh: executes successfully under Darwin" {
    export MOCK_UNAME_S="Darwin"
    run bash "$REPO_ROOT/scripts/macos/install.sh"
    [ "$status" -eq 0 ]
    [ -f "$TRIVY_SCAN_SCRIPT_PATH" ]
    [ -x "$TRIVY_SCAN_SCRIPT_PATH" ]
    [ -f "$TRIVY_SCAN_LOG_PATH" ]
    grep -q "wazuh_command.remote_commands=1" "$LOCAL_INTERNAL_OPTIONS_CONF"
    [[ "$output" =~ "Container engine found" ]]
    [[ "$output" =~ "trivy-scan.sh downloaded and configured" ]]
}

@test "scripts/macos/uninstall.sh: removes trivy files and config under Darwin" {
    export MOCK_UNAME_S="Darwin"
    touch "$TRIVY_SCAN_SCRIPT_PATH" "$TRIVY_SCAN_LOG_PATH" "$TRIVY_BIN_DIR/trivy"
    echo "wazuh_command.remote_commands=1" >> "$LOCAL_INTERNAL_OPTIONS_CONF"

    run bash "$REPO_ROOT/scripts/macos/uninstall.sh"
    [ "$status" -eq 0 ]
    [ ! -f "$TRIVY_SCAN_SCRIPT_PATH" ]
    [ ! -f "$TRIVY_SCAN_LOG_PATH" ]
    [ ! -f "$TRIVY_BIN_DIR/trivy" ]
    ! grep -q "wazuh_command.remote_commands=1" "$LOCAL_INTERNAL_OPTIONS_CONF"
}

@test "scripts/macos/trivy-scan.sh: scans docker images and logs results" {
    export MOCK_UNAME_S="Darwin"
    run bash "$REPO_ROOT/scripts/macos/trivy-scan.sh"
    [ "$status" -eq 0 ]
    [ -f "$TRIVY_SCAN_LOG_PATH" ]
    grep -q 'Trivy:"alpine:latest"' "$TRIVY_SCAN_LOG_PATH"
}

