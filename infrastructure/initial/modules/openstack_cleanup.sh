#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(dirname "$0")"
source "$SCRIPT_DIR/log_utils.sh"

CONFIG="${1:-$SCRIPT_DIR/../configs/initial_config.json}"

log "Starting OpenStack cleanup"

# Delete instances (they use resources)
log "Deleting instances"
openstack server list --format json | jq -r '.[].ID' | while read -r instance_id; do
    openstack server delete "$instance_id" 2>/dev/null || true
done

# Delete router
log "Deleting router"
openstack router unset cyberlab-router --external-gateway 2>/dev/null || true
openstack router remove subnet cyberlab-router $(jq -r '.networks.private.subnet_name' "$CONFIG") 2>/dev/null || true
openstack router delete cyberlab-router 2>/dev/null || true

# Delete networks
log "Deleting networks"
openstack network delete $(jq -r '.networks.private.name' "$CONFIG") 2>/dev/null || true
openstack network delete $(jq -r '.networks.external.name' "$CONFIG") 2>/dev/null || true

# Delete security groups
log "Deleting security groups"
openstack security group delete $(jq -r '.security_group.name' "$CONFIG") 2>/dev/null || true

# Delete flavors
log "Deleting flavors"
for flavor in tiny small medium large; do
    openstack flavor delete "cyberlab-$flavor" 2>/dev/null || true
done

# Delete keypairs
log "Deleting keypairs"
openstack keypair delete $(jq -r '.keypair.name' "$CONFIG") 2>/dev/null || true

# Delete images
log "Deleting images"
jq -r '.images[].name' "$CONFIG" | while read -r image; do
    openstack image delete "$image" 2>/dev/null || true
done

log "Cleanup completed"
