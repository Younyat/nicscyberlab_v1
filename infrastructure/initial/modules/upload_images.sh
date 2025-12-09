#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(dirname "$0")"
source "$SCRIPT_DIR/log_utils.sh"

CONFIG="$1"

upload=$(jq -r '.images.upload' "$CONFIG")
if [ "$upload" != "true" ]; then
    log "Image upload disabled in config"
    exit 0
fi

log "Uploading images to Glance"

IMAGE_DIR="$HOME/openstack_images"
mkdir -p "$IMAGE_DIR"

jq -r '.images.list | to_entries[] | "\(.key)=\(.value)"' "$CONFIG" |
while IFS="=" read -r name url; do
    FILE="$IMAGE_DIR/${name}.qcow2"
    
    if [ ! -f "$FILE" ]; then
        log "Downloading $name from $url"
        if ! wget -q -O "$FILE" "$url" 2>/dev/null; then
            log "WARNING: Failed to download $name"
            continue
        fi
    else
        log "Image file already cached: $name"
    fi

    if openstack image show "$name" >/dev/null 2>&1; then
        log "Image already exists in Glance: $name"
    else
        log "Uploading $name to Glance"
        openstack image create "$name" \
          --disk-format qcow2 \
          --container-format bare \
          --file "$FILE" \
          --public || log "WARNING: Failed to upload $name"
    fi
done

log "Image upload phase completed"
