#!/usr/bin/env bash
set -euo pipefail

log_info()  { echo "[INFO]  $*"; }
log_warn()  { echo "[WARN]  $*"; }
log_error() { echo "[ERROR] $*" >&2; }

print_exec_context() {
    log_info "Execution context:"
    log_info "  User     : $(whoami)"
    log_info "  UID      : $(id -u)"
    log_info "  Groups   : $(id -nG)"
    log_info "  Cwd      : $(pwd)"
}

require_not_root() {
    if [[ "$(id -u)" -eq 0 ]]; then
        log_error "This script should not be run as root. Use a normal user with sudo."
        exit 1
    fi
}

detect_ssh_key() {
    local key=""
    for f in "$HOME/.ssh/id_rsa" "$HOME/.ssh/id_ed25519" "$HOME/.ssh/"*; do
        if [[ -f "$f" ]] && grep -q "PRIVATE KEY" "$f" 2>/dev/null; then
            key="$f"
            break
        fi
    done
    if [[ -z "$key" ]]; then
        log_error "No SSH private key found in ~/.ssh"
        return 1
    fi
    chmod 600 "$key"
    echo "$key"
}
