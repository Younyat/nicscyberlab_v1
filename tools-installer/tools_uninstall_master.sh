#!/usr/bin/env bash
set -euo pipefail
trap 'echo "ERROR on line ${LINENO}" >&2' ERR

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
SCRIPTS_DIR="$SCRIPT_DIR/scripts"
UNINSTALL_DIR="$SCRIPT_DIR/uninstall"
LOGS_DIR="$SCRIPT_DIR/logs"
TMP_DIR="$SCRIPT_DIR/../tools-installer-tmp"
BASE_DIR="$(cd "$SCRIPT_DIR/.." && pwd -P)"
ADMIN_OPENRC="$BASE_DIR/admin-openrc.sh"

# shellcheck source=/dev/null
source "$SCRIPTS_DIR/shared_utils.sh"

require_not_root
print_exec_context

mkdir -p "$LOGS_DIR"

# shellcheck source=/dev/null
source "$ADMIN_OPENRC"

SSH_KEY="$(detect_ssh_key)"
log_info "Using SSH key: $SSH_KEY"

FOUND_JSON=false
for FILE in "$TMP_DIR"/*_tools.json; do
    [[ -f "$FILE" ]] || continue
    FOUND_JSON=true
    INSTANCE=$(jq -r '.instance // .name' "$FILE")
    IP_FLOAT=$(jq -r '.ip_floating // empty' "$FILE")
    IP_PRIV=$(jq -r '.ip_private // empty' "$FILE")
    IP="${IP_FLOAT:-$IP_PRIV}"
    TOOLS=$(jq -r '.tools[]' "$FILE" 2>/dev/null || true)
    if [[ -z "$INSTANCE" || -z "$IP" ]]; then
        log_warn "Incomplete JSON: $FILE"
        continue
    fi
    log_info "Processing $FILE -> $INSTANCE @ $IP"
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
        log_error "Cannot SSH to $IP"
        continue
    fi
    for TOOL in $TOOLS; do
        UNINSTALL_SCRIPT="$UNINSTALL_DIR/uninstall_${TOOL}.sh"
        LOG_FILE="$LOGS_DIR/${INSTANCE// /_}_${TOOL}_uninstall.log"
        if [[ ! -f "$UNINSTALL_SCRIPT" ]]; then
            log_warn "Missing uninstaller: $UNINSTALL_SCRIPT"
            continue
        fi
        chmod +x "$UNINSTALL_SCRIPT" || true
        log_info "Uninstalling $TOOL on $INSTANCE"
        scp -o StrictHostKeyChecking=no -i "$SSH_KEY" "$UNINSTALL_SCRIPT" "$SSH_USER@$IP:/tmp/uninstall_${TOOL}.sh"
        ssh -o StrictHostKeyChecking=no -i "$SSH_KEY" "$SSH_USER@$IP" "sudo bash /tmp/uninstall_${TOOL}.sh '$IP'" >"$LOG_FILE" 2>&1 || {
            log_error "Failed uninstalling $TOOL on $INSTANCE. See $LOG_FILE"
            continue
        }
        log_info "Uninstalled $TOOL on $INSTANCE"
    done
done

if [[ "$FOUND_JSON" = false ]]; then
    log_warn "No *_tools.json files found"
fi

log_info "Uninstallation process completed. Logs: $LOGS_DIR"
