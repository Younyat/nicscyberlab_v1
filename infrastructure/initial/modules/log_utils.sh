#!/bin/bash

BASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LOG_DIR="$BASE_DIR/logs"
mkdir -p "$LOG_DIR"

LOG_FILE="$LOG_DIR/initial.log"

timestamp() { date +"%Y-%m-%d %H:%M:%S"; }

log() {
    echo "[$(timestamp)] $1" | tee -a "$LOG_FILE"
}

abort() {
    log "ERROR: $1"
    exit 1
}
