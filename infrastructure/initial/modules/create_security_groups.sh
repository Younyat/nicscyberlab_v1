#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(dirname "$0")"
source "$SCRIPT_DIR/log_utils.sh"

CONFIG="$1"

log "Creating security groups from configuration"

sg_name=$(jq -r '.security_group.name' "$CONFIG")

if openstack security group show "$sg_name" >/dev/null 2>&1; then
    log "Security group already exists: $sg_name"
else
    log "Creating security group: $sg_name"
    openstack security group create "$sg_name" || abort "Failed to create security group"
fi

log "Adding ingress rules"

# SSH
openstack security group rule create --ingress --protocol tcp --dst-port 22 "$sg_name" 2>/dev/null || true

# HTTP
openstack security group rule create --ingress --protocol tcp --dst-port 80 "$sg_name" 2>/dev/null || true

# HTTPS
openstack security group rule create --ingress --protocol tcp --dst-port 443 "$sg_name" 2>/dev/null || true

# Wazuh Agent
openstack security group rule create --ingress --protocol tcp --dst-port 1514 "$sg_name" 2>/dev/null || true

# Wazuh Cluster
openstack security group rule create --ingress --protocol tcp --dst-port 1515 "$sg_name" 2>/dev/null || true

# Wazuh Cluster UDP
openstack security group rule create --ingress --protocol udp --dst-port 55000 "$sg_name" 2>/dev/null || true

# Kibana
openstack security group rule create --ingress --protocol tcp --dst-port 5601 "$sg_name" 2>/dev/null || true

# Custom Port
openstack security group rule create --ingress --protocol tcp --dst-port 8888 "$sg_name" 2>/dev/null || true

log "Security group setup completed"
