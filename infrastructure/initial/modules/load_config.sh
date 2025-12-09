#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(dirname "$0")"
source "$SCRIPT_DIR/log_utils.sh"

CONFIG_FILE="$1"

if [ ! -f "$CONFIG_FILE" ]; then
    abort "Config file not found: $CONFIG_FILE"
fi

log "Loading configuration from $CONFIG_FILE"

if ! jq empty "$CONFIG_FILE" 2>/dev/null; then
    abort "Invalid JSON format in $CONFIG_FILE"
fi

log "Configuration loaded and validated"
