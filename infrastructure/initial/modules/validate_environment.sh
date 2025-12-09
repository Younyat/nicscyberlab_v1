#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(dirname "$0")"
source "$SCRIPT_DIR/log_utils.sh"

log "Validating OpenStack environment"

if ! command -v openstack >/dev/null; then
    abort "OpenStack CLI is not available"
fi

if ! command -v jq >/dev/null; then
    abort "jq is required for config parsing"
fi

if ! openstack token issue >/dev/null 2>&1; then
    abort "OpenStack API authentication failed"
fi

log "Environment validated successfully"
