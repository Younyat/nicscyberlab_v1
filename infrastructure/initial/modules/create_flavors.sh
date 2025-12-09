#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(dirname "$0")"
source "$SCRIPT_DIR/log_utils.sh"

CONFIG="$1"

log "Creating flavors from configuration"

# Extract flavor configs
declare -A flavors=(
    [tiny]=$(jq -r '.flavors.tiny | "\(.vcpu),\(.ram),\(.disk)"' "$CONFIG")
    [small]=$(jq -r '.flavors.small | "\(.vcpu),\(.ram),\(.disk)"' "$CONFIG")
    [medium]=$(jq -r '.flavors.medium | "\(.vcpu),\(.ram),\(.disk)"' "$CONFIG")
    [large]=$(jq -r '.flavors.large | "\(.vcpu),\(.ram),\(.disk)"' "$CONFIG")
)

for flavor in tiny small medium large; do
    flavor_name="cyberlab-$flavor"
    IFS=',' read -r vcpu ram disk <<< "${flavors[$flavor]}"
    
    if openstack flavor show "$flavor_name" >/dev/null 2>&1; then
        log "Flavor already exists: $flavor_name"
    else
        log "Creating flavor: $flavor_name (vCPU=$vcpu, RAM=${ram}MB, Disk=${disk}GB)"
        openstack flavor create --vcpus "$vcpu" --ram "$ram" --disk "$disk" "$flavor_name" || abort "Failed to create flavor"
    fi
done

log "Flavor setup completed"
