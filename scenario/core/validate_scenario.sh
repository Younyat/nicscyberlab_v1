#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
BASE_DIR="$(cd "$SCRIPT_DIR/.." && pwd -P)"

# helper to resolve relative paths against module base
resolve_path() {
    local p="$1"
    if [[ -z "$p" ]]; then
        echo ""
        return
    fi
    if [[ "$p" = /* ]]; then
        echo "$p"
    else
        echo "$BASE_DIR/${p#/}"
    fi
}

source "$SCRIPT_DIR/log_utils.sh"

SCENARIO_JSON_RAW="${1:-configs/scenario_file.json}"
SCENARIO_JSON="$(resolve_path "$SCENARIO_JSON_RAW")"

log_section "Validating scenario file: $SCENARIO_JSON"

require_command jq
require_command openstack

if [ ! -f "$SCENARIO_JSON" ]; then
    log_error "Scenario JSON not found: $SCENARIO_JSON"
    exit 1
fi

if ! jq empty "$SCENARIO_JSON" >/dev/null 2>&1; then
    log_error "Scenario JSON is not valid JSON"
    exit 1
fi

check_os_credentials

on_error() {
    local rc=$?
    log_error "validate_scenario.sh failed with exit code $rc"
    exit $rc
}

trap on_error ERR

# Validate nodes section exists
if [ "$(jq '.nodes | length' "$SCENARIO_JSON")" -eq 0 ]; then
    log_error "Scenario has no nodes defined"
    exit 1
fi

log_info "Found $(jq '.nodes | length' "$SCENARIO_JSON") nodes in scenario"

# Validate edges section (optional)
if ! jq '.edges' "$SCENARIO_JSON" >/dev/null 2>&1; then
    log_warn "Scenario has no 'edges' section. Continuing."
else
    log_info "Found $(jq '.edges | length' "$SCENARIO_JSON") edges in scenario"
fi

log_info "Validating required OpenStack resources for each node"

while read -r node; do
    name=$(echo "$node" | jq -r '.name')
    image=$(echo "$node" | jq -r '.properties.image')
    flavor=$(echo "$node" | jq -r '.properties.flavor')
    network=$(echo "$node" | jq -r '.properties.network')
    subnet=$(echo "$node" | jq -r '.properties.subnetwork')
    secgroup=$(echo "$node" | jq -r '.properties.securityGroup')
    sshkey=$(echo "$node" | jq -r '.properties.sshKey')

    log_info "Checking node: $name"

    if ! openstack image show "$image" >/dev/null 2>&1; then
        log_error "Image not found: $image"
        exit 1
    fi

    if ! openstack flavor show "$flavor" >/dev/null 2>&1; then
        log_error "Flavor not found: $flavor"
        exit 1
    fi

    if ! openstack network show "$network" >/dev/null 2>&1; then
        log_error "Network not found: $network"
        exit 1
    fi

    if ! openstack subnet show "$subnet" >/dev/null 2>&1; then
        log_error "Subnet not found: $subnet"
        exit 1
    fi

    if ! openstack security group show "$secgroup" >/dev/null 2>&1; then
        log_error "Security group not found: $secgroup"
        exit 1
    fi

    if ! openstack keypair show "$sshkey" >/dev/null 2>&1; then
        log_error "SSH keypair not found: $sshkey"
        exit 1
    fi

    log_info "All resources found for node: $name"

done < <(jq -c '.nodes[]' "$SCENARIO_JSON")

log_info "Validating external network for floating IPs"

DEFAULT_EXTERNAL_NET="external-net"
if ! openstack network show "$DEFAULT_EXTERNAL_NET" >/dev/null 2>&1; then
    log_error "External network not found: $DEFAULT_EXTERNAL_NET"
    exit 1
fi

log_info "Scenario validation completed successfully"
