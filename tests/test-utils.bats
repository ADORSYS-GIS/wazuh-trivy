#!/usr/bin/env bats

setup() {
    # Directory setup
    TEST_DIR="$(mktemp -d)"
    export TMP_DIR="$TEST_DIR"
    
    # Source the shared utilities
    REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
    # shellcheck source=scripts/shared/utils.sh
    source "$REPO_ROOT/scripts/shared/utils.sh"
}

teardown() {
    rm -rf "$TEST_DIR"
}

@test "command_exists detects existing commands" {
    run command_exists bash
    [ "$status" -eq 0 ]
    
    run command_exists sh
    [ "$status" -eq 0 ]
}

@test "command_exists returns non-zero for nonexistent commands" {
    run command_exists nonexistent_cmd_xyz_98765
    [ "$status" -ne 0 ]
}

@test "calculate_sha256 computes correct hash for empty file" {
    local empty_file="$TEST_DIR/empty.txt"
    touch "$empty_file"
    
    run calculate_sha256 "$empty_file"
    [ "$status" -eq 0 ]
    [ "$output" = "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855" ]
}

@test "calculate_sha256 computes correct hash for known content" {
    local sample_file="$TEST_DIR/sample.txt"
    printf "hello world" > "$sample_file"
    
    run calculate_sha256 "$sample_file"
    [ "$status" -eq 0 ]
    [ "$output" = "b94d27b9934d3e08a52e52d7da7dabfac484efe37a5380ee9088f7ace2efcde9" ]
}

@test "calculate_sha256 falls back to shasum if sha256sum is not available" {
    local sample_file="$TEST_DIR/sample.txt"
    printf "fallback test" > "$sample_file"
    
    command_exists() {
        if [[ "$1" == "sha256sum" ]]; then
            return 1
        elif [[ "$1" == "shasum" ]]; then
            return 0
        fi
        return 1
    }
    shasum() {
        echo "mockhash12345  $sample_file"
    }
    
    run calculate_sha256 "$sample_file"
    [ "$status" -eq 0 ]
    [ "$output" = "mockhash12345" ]
}

@test "calculate_sha256 returns error if neither sha256sum nor shasum is available" {
    local sample_file="$TEST_DIR/sample.txt"
    touch "$sample_file"
    
    command_exists() {
        return 1
    }
    
    run calculate_sha256 "$sample_file"
    [ "$status" -eq 1 ]
    [[ "$output" =~ "No SHA256 tool available" ]]
}

@test "verify_checksum succeeds on matching sha256" {
    local sample_file="$TEST_DIR/sample.txt"
    printf "hello world" > "$sample_file"
    local expected="b94d27b9934d3e08a52e52d7da7dabfac484efe37a5380ee9088f7ace2efcde9"
    
    run verify_checksum "$sample_file" "$expected"
    [ "$status" -eq 0 ]
}

@test "verify_checksum fails on mismatched sha256" {
    local sample_file="$TEST_DIR/sample.txt"
    printf "hello world" > "$sample_file"
    local wrong_hash="0000000000000000000000000000000000000000000000000000000000000000"
    
    run verify_checksum "$sample_file" "$wrong_hash"
    [ "$status" -ne 0 ]
    [[ "$output" =~ "Checksum verification FAILED" ]]
}

@test "info_message outputs formatted INFO log" {
    run info_message "Test informational message"
    [ "$status" -eq 0 ]
    [[ "$output" =~ "[INFO]" ]]
    [[ "$output" =~ "Test informational message" ]]
}

@test "warn_message outputs formatted WARNING log" {
    run warn_message "Test warning message"
    [ "$status" -eq 0 ]
    [[ "$output" =~ "[WARNING]" ]]
    [[ "$output" =~ "Test warning message" ]]
}

@test "error_message outputs formatted ERROR log" {
    run error_message "Test error message"
    [ "$status" -eq 0 ]
    [[ "$output" =~ "[ERROR]" ]]
    [[ "$output" =~ "Test error message" ]]
}

@test "success_message outputs formatted SUCCESS log" {
    run success_message "Test success message"
    [ "$status" -eq 0 ]
    [[ "$output" =~ "[SUCCESS]" ]]
    [[ "$output" =~ "Test success message" ]]
}

@test "print_step_header outputs formatted header" {
    run print_step_header "1" "Initialize environment"
    [ "$status" -eq 0 ]
    [[ "$output" =~ "STEP 1: Initialize environment" ]]
}

@test "error_exit prints message and exits with status 1" {
    run error_exit "Fatal abort triggered"
    [ "$status" -eq 1 ]
    [[ "$output" =~ "Fatal abort triggered" ]]
}

@test "detect_architecture detects x86_64 as amd64" {
    uname() {
        if [ "$1" = "-m" ]; then
            echo "x86_64"
        else
            command uname "$@"
        fi
    }
    
    run detect_architecture
    [ "$status" -eq 0 ]
    [ "$output" = "amd64" ]
}

@test "detect_architecture detects arm64 and aarch64" {
    uname() {
        if [ "$1" = "-m" ]; then
            echo "aarch64"
        else
            command uname "$@"
        fi
    }
    
    run detect_architecture
    [ "$status" -eq 0 ]
    [ "$output" = "arm64" ]
}

@test "detect_architecture fails on unsupported arch" {
    uname() {
        if [ "$1" = "-m" ]; then
            echo "mips64"
        else
            command uname "$@"
        fi
    }
    
    run detect_architecture
    [ "$status" -eq 1 ]
    [[ "$output" =~ "Unsupported architecture: mips64" ]]
}

@test "maybe_sudo executes directly when running as root" {
    id() {
        if [[ "$1" == "-u" ]]; then
            echo "0"
        else
            command id "$@"
        fi
    }
    
    run maybe_sudo echo "running as root"
    [ "$status" -eq 0 ]
    [ "$output" = "running as root" ]
}

@test "maybe_sudo delegates to sudo when running as non-root" {
    id() {
        if [[ "$1" == "-u" ]]; then
            echo "1000"
        else
            command id "$@"
        fi
    }
    sudo() {
        echo "mock-sudo: $*"
    }
    
    run maybe_sudo echo "privileged action"
    [ "$status" -eq 0 ]
    [ "$output" = "mock-sudo: echo privileged action" ]
}

@test "maybe_sudo errors when non-root and sudo is unavailable" {
    id() {
        if [[ "$1" == "-u" ]]; then
            echo "1000"
        else
            command id "$@"
        fi
    }
    command_exists() {
        if [[ "$1" == "sudo" ]]; then
            return 1
        fi
        return 0
    }
    
    run maybe_sudo echo "fail without sudo"
    [ "$status" -eq 1 ]
    [[ "$output" =~ "This script requires root privileges" ]]
}

@test "remove_file removes an existing file" {
    maybe_sudo() {
        "$@"
    }
    local target_file="$TEST_DIR/file_to_delete.txt"
    touch "$target_file"
    [ -f "$target_file" ]
    
    run remove_file "$target_file"
    [ "$status" -eq 0 ]
    [ ! -f "$target_file" ]
}

@test "remove_file removes an existing directory" {
    maybe_sudo() {
        "$@"
    }
    local target_dir="$TEST_DIR/dir_to_delete"
    mkdir -p "$target_dir"
    touch "$target_dir/nested.txt"
    [ -d "$target_dir" ]
    
    run remove_file "$target_dir"
    [ "$status" -eq 0 ]
    [ ! -d "$target_dir" ]
}

@test "remove_file succeeds when path does not exist" {
    maybe_sudo() {
        "$@"
    }
    run remove_file "$TEST_DIR/nonexistent_path_xyz"
    [ "$status" -eq 0 ]
}

@test "download_file fails when url or dest is missing" {
    run download_file "" ""
    [ "$status" -eq 1 ]
    [[ "$output" =~ "Usage: download_file" ]]
}

@test "download_file downloads successfully with curl" {
    local dest_file="$TEST_DIR/downloaded_curl.txt"
    
    maybe_sudo() {
        "$@"
    }
    curl() {
        local out_target=""
        while [[ $# -gt 0 ]]; do
            case "$1" in
                -o)
                    out_target="$2"
                    shift 2
                    ;;
                *)
                    shift
                    ;;
            esac
        done
        if [[ -n "$out_target" ]]; then
            echo "curl content" > "$out_target"
            return 0
        else
            echo "curl stdout content"
            return 0
        fi
    }
    
    run download_file "http://example.com/test.txt" "$dest_file" "test artifact"
    [ "$status" -eq 0 ]
    [ -f "$dest_file" ]
    [[ "$output" =~ "downloaded successfully" ]]
}

@test "download_file downloads successfully with wget when curl is missing" {
    local dest_file="$TEST_DIR/downloaded_wget.txt"
    
    maybe_sudo() {
        "$@"
    }
    command_exists() {
        if [[ "$1" == "curl" ]]; then
            return 1
        elif [[ "$1" == "wget" ]]; then
            return 0
        fi
        command -v "$1" >/dev/null 2>&1
    }
    
    wget() {
        local out_target=""
        while [[ $# -gt 0 ]]; do
            case "$1" in
                -O)
                    out_target="$2"
                    shift 2
                    ;;
                *)
                    shift
                    ;;
            esac
        done
        if [[ "$out_target" == "-" ]]; then
            echo "wget piped content"
            return 0
        elif [[ -n "$out_target" ]]; then
            echo "wget content" > "$out_target"
            return 0
        fi
        return 1
    }
    
    run download_file "http://example.com/test.txt" "$dest_file" "wget artifact"
    [ "$status" -eq 0 ]
    [ -f "$dest_file" ]
    [[ "$output" =~ "downloaded successfully" ]]
}

@test "download_file fails when neither curl nor wget is available" {
    maybe_sudo() {
        "$@"
    }
    command_exists() {
        if [[ "$1" == "curl" || "$1" == "wget" ]]; then
            return 1
        fi
        command -v "$1" >/dev/null 2>&1
    }
    
    run download_file "http://example.com/test.txt" "$TEST_DIR/none.txt" "test" 1
    [ "$status" -eq 1 ]
    [[ "$output" =~ "Neither curl nor wget is available" ]]
}

@test "download_and_verify_file succeeds with valid local checksum file" {
    local dest_file="$TEST_DIR/verified_file.txt"
    local checksum_file="$TEST_DIR/checksums.sha256"
    
    printf "trusted payload" > "$dest_file"
    local hash
    hash=$(calculate_sha256 "$dest_file")
    echo "$hash  verified_file.txt" > "$checksum_file"
    
    download_file() {
        printf "trusted payload" > "$2"
        return 0
    }
    
    run download_and_verify_file "http://example.com/verified.txt" "$dest_file" "verified_file.txt" "Verified File" "" "$checksum_file"
    [ "$status" -eq 0 ]
    [[ "$output" =~ "downloaded and verified successfully" ]]
}

@test "download_and_verify_file fails when checksum mismatch occurs" {
    local dest_file="$TEST_DIR/bad_file.txt"
    local checksum_file="$TEST_DIR/checksums.sha256"
    
    echo "0000000000000000000000000000000000000000000000000000000000000000  bad_file.txt" > "$checksum_file"
    
    download_file() {
        printf "corrupt payload" > "$2"
        return 0
    }
    
    run download_and_verify_file "http://example.com/bad.txt" "$dest_file" "bad_file.txt" "Bad File" "" "$checksum_file"
    [ "$status" -eq 1 ]
    [[ "$output" =~ "checksum verification failed" ]]
}

@test "download_and_verify_file fails when pattern not found in checksum file" {
    local dest_file="$TEST_DIR/unlisted.txt"
    local checksum_file="$TEST_DIR/checksums.sha256"
    
    echo "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855  other.txt" > "$checksum_file"
    
    download_file() {
        touch "$2"
        return 0
    }
    
    run download_and_verify_file "http://example.com/unlisted.txt" "$dest_file" "unlisted.txt" "Unlisted" "" "$checksum_file"
    [ "$status" -eq 1 ]
    [[ "$output" =~ "No checksum found" ]]
}

@test "download_and_verify_file fails when checksum file does not exist" {
    download_file() {
        touch "$2"
        return 0
    }
    
    run download_and_verify_file "http://example.com/f.txt" "$TEST_DIR/f.txt" "f.txt" "F" "" "$TEST_DIR/nonexistent.sha256"
    [ "$status" -eq 1 ]
    [[ "$output" =~ "Checksum file not found" ]]
}

@test "download_and_verify_file handles external checksum URL download" {
    local dest_file="$TEST_DIR/remote_verified.txt"
    
    download_file() {
        local url="$1"
        local target="$2"
        if [[ "$url" == *"checksums"* ]]; then
            printf "d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2  target.tar.gz\n" > "$target"
        else
            printf "content" > "$target"
        fi
        return 0
    }
    verify_checksum() {
        return 0
    }
    
    run download_and_verify_file "http://example.com/target.tar.gz" "$dest_file" "target.tar.gz" "Target" "http://example.com/checksums.sha256"
    [ "$status" -eq 0 ]
    [[ "$output" =~ "downloaded and verified successfully" ]]
}

@test "cleanup removes TMP_DIR when set" {
    local temp_scratch="$TEST_DIR/scratch"
    mkdir -p "$temp_scratch"
    export TMP_DIR="$temp_scratch"
    
    [ -d "$TMP_DIR" ]
    run cleanup
    [ "$status" -eq 0 ]
    [ ! -d "$temp_scratch" ]
}
