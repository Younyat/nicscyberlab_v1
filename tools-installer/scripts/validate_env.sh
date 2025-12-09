#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
TOOLS_ROOT="$(cd "$SCRIPT_DIR/.." && pwd -P)"
TMP_DIR="$TOOLS_ROOT/../tools-installer-tmp"
SCRIPTS_DIR="$TOOLS_ROOT/scripts"
LOGS_DIR="$TOOLS_ROOT/logs"
BASE_DIR="$(cd "$TOOLS_ROOT/.." && pwd -P)"
ADMIN_OPENRC="$BASE_DIR/admin-openrc.sh"

# shellcheck source=/dev/null
source "$SCRIPTS_DIR/shared_utils.sh"

require_not_root
print_exec_context

log_info "Validating tools-installer environment"

if [[ ! -d "$TMP_DIR" ]]; then
    log_error "Missing JSON dir: $TMP_DIR"
    exit 1
fi

if [[ ! -d "$SCRIPTS_DIR" ]]; then
    log_error "Missing scripts dir: $SCRIPTS_DIR"
    exit 1
fi

mkdir -p "$LOGS_DIR"

REQUIRED_CMDS=(jq ssh scp openstack)
for cmd in "${REQUIRED_CMDS[@]}"; do
    if ! command -v "$cmd" >/dev/null 2>&1; then
        log_error "Missing required command: $cmd"
        exit 1
    fi
done

if [[ ! -f "$ADMIN_OPENRC" ]]; then
    log_error "Missing admin-openrc.sh at $ADMIN_OPENRC"
    exit 1
fi

# shellcheck source=/dev/null
source "$ADMIN_OPENRC"

if ! openstack token issue >/dev/null 2>&1; then
    log_error "Failed to obtain OpenStack token"
    exit 1
fi

SSH_KEY="$(detect_ssh_key)"
log_info "SSH key: $SSH_KEY"

FOUND_JSON=false
for FILE in "$TMP_DIR"/*_tools.json; do
    [[ -f "$FILE" ]] || continue
    FOUND_JSON=true
    log_info "Validating JSON: $FILE"
    if ! jq empty "$FILE" >/dev/null 2>&1; then
        log_error "Malformed JSON: $FILE"
        exit 1
    fi
    INSTANCE=$(jq -r '.instance // .name' "$FILE")
    TOOLS=$(jq -r '.tools[]' "$FILE" 2>/dev/null || true)
    if [[ -z "$INSTANCE" || "$INSTANCE" == "null" ]]; then
        log_error "JSON missing instance/name: $FILE"
        exit 1
    fi
    for TOOL in $TOOLS; do
        if [[ ! -f "$SCRIPTS_DIR/install_${TOOL}.sh" ]]; then
            log_error "Missing installer for $TOOL: $SCRIPTS_DIR/install_${TOOL}.sh"
            exit 1
        fi
    done
done

if [[ "$FOUND_JSON" = false ]]; then
    log_warn "No *_tools.json files found in $TMP_DIR"
fi

# Validate SSH connectivity to instances
for FILE in "$TMP_DIR"/*_tools.json; do
    [[ -f "$FILE" ]] || continue
    INSTANCE=$(jq -r '.instance // .name' "$FILE")
    IP_FLOAT=$(jq -r '.ip_floating // empty' "$FILE")
    IP_PRIV=$(jq -r '.ip_private // empty' "$FILE")
    IP="${IP_FLOAT:-$IP_PRIV}"
    if [[ -z "$IP" ]]; then
        log_error "No IP found in $FILE"
        exit 1
    fi
    log_info "Checking instance $INSTANCE at $IP"
    if ! openstack server show "$INSTANCE" >/dev/null 2>&1; then
        log_error "Instance not found in OpenStack: $INSTANCE"
        exit 1
    fi
    IMAGE_JSON=$(openstack server show "$INSTANCE" -f json | jq -r '.image')
    IMAGE_NAME="$IMAGE_JSON"
    if echo "$IMAGE_JSON" | jq empty >/dev/null 2>&1; then
        IMAGE_NAME=$(echo "$IMAGE_JSON" | jq -r '.name')
    fi
    CANDIDATES=("ubuntu" "debian" "kali")
    if echo "$IMAGE_NAME" | grep -qi "debian"; then
        CANDIDATES=("debian" "ubuntu" "kali")
    elif echo "$IMAGE_NAME" | grep -qi "kali"; then
        CANDIDATES=("kali" "root" "ubuntu")
    fi
    SSH_USER=""
    for u in "${CANDIDATES[@]}"; do
        if ssh -o BatchMode=yes -o StrictHostKeyChecking=no -i "$SSH_KEY" "$u@$IP" "echo ok" >/dev/null 2>&1; then
            SSH_USER="$u"
            break
        fi
    done
    if [[ -z "$SSH_USER" ]]; then
        log_error "Cannot SSH to $IP with candidates ${CANDIDATES[*]}"
        exit 1
    fi
    log_info "SSH OK to $IP as $SSH_USER"
done

log_info "Environment validation completed"
exit 0
