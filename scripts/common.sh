#!/bin/bash
# Common utilities shared across all scripts

# Define text formatting
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[1;34m'
BOLD='\033[1m'
NORMAL='\033[0m'

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

has_container_engine() {
    command_exists docker || command_exists podman || command_exists ctr
}

detect_container_engine() {
    if command_exists docker; then
        echo "docker"
    elif command_exists podman; then
        echo "podman"
    elif command_exists ctr; then
        echo "containerd"
    else
        error_message "No supported container engine found. Please install Docker, Podman, or containerd."
        exit 1
    fi
}

sed_alternative() {
    if command_exists gsed; then
        maybe_sudo gsed "$@"
    else
        maybe_sudo sed "$@"
    fi
}
