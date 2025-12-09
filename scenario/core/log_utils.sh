#!/usr/bin/env bash
set -euo pipefail

log_info() {
    echo "[INFO] $*"
}

log_warn() {
    echo "[WARN] $*"
}

log_error() {
    echo "[ERROR] $*" >&2
}

log_section() {
    echo
    echo "------------------------------------------------------------"
    echo "$*"
    echo "------------------------------------------------------------"
}

require_command() {
    local cmd="$1"
    if ! command -v "$cmd" >/dev/null 2>&1; then
        log_error "Missing required command: $cmd"
        exit 1
    fi
}

check_os_credentials() {
    if ! openstack token issue >/dev/null 2>&1; then
        log_error "Invalid or missing OpenStack credentials. Run: source admin-openrc.sh"
        exit 1
    fi
}
