#!/bin/bash

BASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LOG_DIR="$BASE_DIR/logs"
mkdir -p "$LOG_DIR"

LOG_FILE="$LOG_DIR/install_openstack.log"

timestamp() {
    date +"%Y-%m-%d %H:%M:%S"
}

log() {
    local msg="$1"
    echo "[$(timestamp)] $msg" | tee -a "$LOG_FILE"
}

check_not_root() {
    if [ "$EUID" -eq 0 ]; then
        echo "[$(timestamp)] ERROR: Este script no debe ejecutarse como root." | tee -a "$LOG_FILE"
        exit 1
    else
        log "Usuario ejecutor: $(whoami) (UID=$EUID)"
        log "Grupos: $(id -Gn)"
    fi
}
