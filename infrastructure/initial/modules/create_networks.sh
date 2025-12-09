#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(dirname "$0")"
source "$SCRIPT_DIR/log_utils.sh"

CONFIG="$1"

log "Creating networks from configuration"

ext_name=$(jq -r '.networks.external.name' "$CONFIG")
ext_cidr=$(jq -r '.networks.external.cidr' "$CONFIG")
ext_sub=$(jq -r '.networks.external.subnet_name' "$CONFIG")

priv_name=$(jq -r '.networks.private.name' "$CONFIG")
priv_cidr=$(jq -r '.networks.private.cidr' "$CONFIG")
priv_sub=$(jq -r '.networks.private.subnet_name' "$CONFIG")

dns1=$(jq -r '.networks.private.dns[0]' "$CONFIG")
dns2=$(jq -r '.networks.private.dns[1]' "$CONFIG")

# Create external network
if openstack network show "$ext_name" >/dev/null 2>&1; then
    log "External network already exists: $ext_name"
else
    log "Creating external network: $ext_name"
    openstack network create --external "$ext_name" || abort "Failed to create external network"
fi

# Create external subnet
if openstack subnet show "$ext_sub" >/dev/null 2>&1; then
    log "External subnet already exists: $ext_sub"
else
    log "Creating external subnet: $ext_sub"
    openstack subnet create --network "$ext_name" \
      --subnet-range "$ext_cidr" \
      --no-dhcp \
      "$ext_sub" || abort "Failed to create external subnet"
fi

# Create private network
if openstack network show "$priv_name" >/dev/null 2>&1; then
    log "Private network already exists: $priv_name"
else
    log "Creating private network: $priv_name"
    openstack network create "$priv_name" || abort "Failed to create private network"
fi

# Create private subnet
if openstack subnet show "$priv_sub" >/dev/null 2>&1; then
    log "Private subnet already exists: $priv_sub"
else
    log "Creating private subnet: $priv_sub"
    openstack subnet create --network "$priv_name" \
      --subnet-range "$priv_cidr" \
      --dns-nameserver "$dns1" \
      --dns-nameserver "$dns2" \
      "$priv_sub" || abort "Failed to create private subnet"
fi

# Create router
ROUTER="cyberlab-router"

if openstack router show "$ROUTER" >/dev/null 2>&1; then
    log "Router already exists: $ROUTER"
else
    log "Creating router: $ROUTER"
    openstack router create "$ROUTER" || abort "Failed to create router"
fi

log "Setting external gateway on router"
openstack router set "$ROUTER" --external-gateway "$ext_name" 2>/dev/null || true

log "Adding private subnet to router"
openstack router add subnet "$ROUTER" "$priv_sub" 2>/dev/null || true

log "Network setup completed"
