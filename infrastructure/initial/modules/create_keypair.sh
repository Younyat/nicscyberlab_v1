#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(dirname "$0")"
source "$SCRIPT_DIR/log_utils.sh"

CONFIG="$1"

name=$(jq -r '.keypair.name' "$CONFIG")
path=$(jq -r '.keypair.path' "$CONFIG" | sed "s|~|$HOME|g")

log "Creating keypair: $name"

mkdir -p "$(dirname "$path")"

if [ ! -f "$path" ]; then
    log "Generating SSH keypair at $path"
    ssh-keygen -t rsa -b 4096 -f "$path" -N "" >/dev/null 2>&1
else
    log "SSH keypair already exists at $path"
fi

if openstack keypair show "$name" >/dev/null 2>&1; then
    log "Keypair already exists in OpenStack: $name"
else
    log "Uploading public key to OpenStack"
    openstack keypair create --public-key "${path}.pub" "$name" || \
        abort "Failed to create keypair in OpenStack"
fi

log "Keypair setup completed"
