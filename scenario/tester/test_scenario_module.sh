#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
BASE_DIR="$SCRIPT_DIR"
CORE_DIR="$BASE_DIR/core"
CONFIG_RAW="configs/scenario_file.json"
CONFIG_FILE="$BASE_DIR/${CONFIG_RAW}"

source "$CORE_DIR/log_utils.sh"

log_section "Scenario module preflight test"

log_info "Checking required commands"
require_command jq

if command -v openstack >/dev/null 2>&1; then
    log_info "openstack CLI available"
    HAS_OPENSTACK=1
else
    log_warn "openstack CLI not available — skipping live resource checks"
    HAS_OPENSTACK=0
fi

log_info "Checking configuration file"
if [ ! -f "$CONFIG_FILE" ]; then
    log_error "Scenario config not found: $CONFIG_FILE"
    exit 1
fi

log_info "Validating JSON syntax"
if ! jq empty "$CONFIG_FILE" >/dev/null 2>&1; then
    log_error "Scenario JSON not valid"
    exit 1
fi

if [[ "$HAS_OPENSTACK" -eq 1 ]]; then
    log_info "Checking OpenStack credentials"
    check_os_credentials

    log_info "Running scenario validation (live checks)"
    bash "$CORE_DIR/validate_scenario.sh" "$CONFIG_FILE"
else
    log_info "Running scenario validation (offline checks)"
    # Quick structure checks: nodes exists and has required properties
    NODE_COUNT=$(jq '.nodes | length' "$CONFIG_FILE")
    if [[ "$NODE_COUNT" -eq 0 ]]; then
        log_error "Scenario has no nodes defined"
        exit 1
    fi
    # check minimal fields in first node
    sample=$(jq -r '.nodes[0]' "$CONFIG_FILE")
    for field in name properties; do
        if ! jq -e ".nodes[0] | has(\"$field\")" "$CONFIG_FILE" >/dev/null; then
            log_error "Required field missing in node: $field"
            exit 1
        fi
    done
    log_info "Offline structure checks passed"
fi

log_section "Scenario module preflight test passed"
log_info "Ready to deploy: bash scenario_manager.sh"
