#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
BASE_DIR="$SCRIPT_DIR"
CORE_DIR="$BASE_DIR/core"
STATE_DIR_RAW="state"
STATE_DIR="$(cd "$BASE_DIR" >/dev/null && echo "$BASE_DIR/$STATE_DIR_RAW")"

mkdir -p "$STATE_DIR"

# resolve helper
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

if [[ ! -f "$CORE_DIR/log_utils.sh" ]]; then
    echo "[ERROR] Missing $CORE_DIR/log_utils.sh" >&2
    exit 1
fi

source "$CORE_DIR/log_utils.sh"

DESTROY_STATUS="$(resolve_path "state/destroy_status.json")"

log_section "Scenario destruction started"

write_status() {
    local s="$1"; local e="$2"
    printf '{"status":"%s","error":%s}\n' "$s" "$(printf '%s' "${e:-null}" | python3 -c 'import json,sys; s=sys.stdin.read().strip(); print(json.dumps(s) if s!="" and s!="null" else "null")')" > "$DESTROY_STATUS" 2>/dev/null || echo "{\"status\":\"$s\",\"error\":\"$e\"}" > "$DESTROY_STATUS"
}

write_status "running" null

on_error() {
    local rc=$?
    log_error "Unexpected error during destruction (exit $rc)"
    write_status "error" "unexpected_failure"
    exit $rc
}

trap on_error ERR

if ! bash "$CORE_DIR/destroy_nodes.sh" "$STATE_DIR"; then
    write_status "error" "destroy_failed"
    log_error "Node destruction failed"
    exit 1
fi

write_status "completed" null

log_section "Scenario destruction completed successfully"
log_info "Destruction status: $DESTROY_STATUS"

trap - ERR
