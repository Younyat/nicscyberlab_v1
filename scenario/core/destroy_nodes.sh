#!/usr/bin/env bash
set -euo pipefail


SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
BASE_DIR="$(cd "$SCRIPT_DIR/.." && pwd -P)"

# resolve relative paths against module base
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

OUTDIR_RAW="${1:-state}"
OUTDIR="$(resolve_path "$OUTDIR_RAW")"
SUMMARY_JSON="$OUTDIR/summary.json"

log_section "Destroying nodes from summary: $SUMMARY_JSON"

require_command jq
require_command openstack
check_os_credentials

on_error() {
    local rc=$?
    log_error "destroy_nodes.sh failed with exit code $rc"
    exit $rc
}

trap on_error ERR

if [ ! -f "$SUMMARY_JSON" ]; then
    log_warn "summary.json not found. Nothing to destroy."
    exit 0
fi

NODE_COUNT=$(jq '. | length' "$SUMMARY_JSON")
log_info "Found $NODE_COUNT nodes to destroy"

while read -r node; do
    id=$(echo "$node" | jq -r '.id')
    name=$(echo "$node" | jq -r '.name')
    fip=$(echo "$node" | jq -r '.floating_ip')
    port_name=$(echo "$node" | jq -r '.port_name')

    log_section "Destroying node: $name"

    # Delete floating IP
    if [ -n "$fip" ] && [ "$fip" != "null" ] && openstack floating ip show "$fip" >/dev/null 2>&1; then
        log_info "Deleting floating IP: $fip"
        openstack floating ip delete "$fip" 2>&1 || log_warn "Failed to delete floating IP (may be in use)"
    else
        log_info "Floating IP already gone or not defined"
    fi

    # Delete server
    if openstack server show "$name" >/dev/null 2>&1; then
        log_info "Deleting server: $name"
        openstack server delete "$name" 2>&1 || log_warn "Failed to delete server"
    else
        log_info "Server already deleted"
    fi

    # Wait for server to be fully deleted
    log_info "Waiting for server deletion to complete"
    for i in {1..30}; do
        if ! openstack server show "$name" >/dev/null 2>&1; then
            log_info "Server fully deleted"
            break
        fi
        sleep 2
    done

    # Delete port
    if [ -n "$port_name" ] && [ "$port_name" != "null" ] && openstack port show "$port_name" >/dev/null 2>&1; then
        log_info "Deleting port: $port_name"
        openstack port delete "$port_name" 2>&1 || log_warn "Failed to delete port"
    else
        log_info "Port already deleted or not defined"
    fi

    log_info "Node $name destroyed"

done < <(jq -c '.[]' "$SUMMARY_JSON")

log_info "All nodes processed"
