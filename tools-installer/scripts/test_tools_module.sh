#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
TOOLS_ROOT="$(cd "$SCRIPT_DIR/.." && pwd -P)"
SCRIPTS_DIR="$TOOLS_ROOT/scripts"
TMP_DIR="$TOOLS_ROOT/../tools-installer-tmp"
BASE_DIR="$(cd "$TOOLS_ROOT/.." && pwd -P)"
ADMIN_OPENRC="$BASE_DIR/admin-openrc.sh"

# shellcheck source=/dev/null
source "$SCRIPTS_DIR/shared_utils.sh"

require_not_root
print_exec_context

log_info "Running dry-run test for tools-installer"

bash "$SCRIPTS_DIR/validate_env.sh"

# shellcheck source=/dev/null
source "$ADMIN_OPENRC"

SSH_KEY="$(detect_ssh_key)"
log_info "SSH key: $SSH_KEY"

for FILE in "$TMP_DIR"/*_tools.json; do
    [[ -f "$FILE" ]] || continue
    INSTANCE=$(jq -r '.instance // .name' "$FILE")
    IP_FLOAT=$(jq -r '.ip_floating // empty' "$FILE")
    IP_PRIV=$(jq -r '.ip_private // empty' "$FILE")
    IP="${IP_FLOAT:-$IP_PRIV}"
    TOOLS=$(jq -r '.tools[]' "$FILE" 2>/dev/null || true)
    log_info "File: $FILE -> $INSTANCE @ $IP"
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
        log_warn "Cannot SSH to $IP (dry-run). Skipping execution plan for $INSTANCE"
        continue
    fi
    log_info "Would install on $INSTANCE as $SSH_USER: $TOOLS"
    for TOOL in $TOOLS; do
        INSTALL_SCRIPT="$SCRIPTS_DIR/install_${TOOL}.sh"
        if [[ ! -f "$INSTALL_SCRIPT" ]]; then
            log_warn "Missing $INSTALL_SCRIPT"
            continue
        fi
        echo "  Would copy $INSTALL_SCRIPT -> /tmp/install_${TOOL}.sh and run sudo bash /tmp/install_${TOOL}.sh '$IP'"
    done
done

log_info "Dry-run test completed"
