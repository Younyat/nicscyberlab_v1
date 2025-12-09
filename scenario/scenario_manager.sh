#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
# Base directory for scenario module
BASE_DIR="$SCRIPT_DIR"
CORE_DIR="$BASE_DIR/core"
STATE_DIR="$BASE_DIR/state"

umask 027

mkdir -p "$STATE_DIR"

# resolve a given path: if absolute return as-is, otherwise relative to BASE_DIR
resolve_path() {
    local p="$1"
    if [[ -z "$p" ]]; then
        echo ""
        return
    fi
    if [[ "$p" = /* ]]; then
        echo "$p"
    else
        # strip leading ./ or /
        echo "$BASE_DIR/${p#./}"
    fi
}

# defaults (can be overridden via flags)
SCENARIO_JSON_RAW="configs/scenario_file.json"
DRY_RUN=0

usage() {
    cat <<EOF
Usage: $(basename "$0") [OPTIONS] [SCENARIO_JSON]

Options:
  -h, --help        Show this help
  -n, --dry-run     Do not perform actions, validate only
  -s, --state DIR   State directory (default: $STATE_DIR)
  --log FILE        Log file path (default: state/logs/scenario_manager.log)

SCENARIO_JSON can be a path to the scenario JSON (default: configs/scenario_file.json)
EOF
}

# parse args (simple loop to allow positional at end)
while [[ $# -gt 0 ]]; do
    case "$1" in
        -h|--help)
            usage
            exit 0
            ;;
        -n|--dry-run)
            DRY_RUN=1
            shift
            ;;
        -s|--state)
            STATE_DIR="$(resolve_path "$2")"
            shift 2
            ;;
        --log)
            LOG_FILE="$2"
            shift 2
            ;;
        --)
            shift
            break
            ;;
        -* )
            echo "Unknown option: $1" >&2; usage; exit 2
            ;;
        * )
            SCENARIO_JSON_RAW="$1"
            shift
            ;;
    esac
done

mkdir -p "$STATE_DIR"
LOG_DIR="$STATE_DIR/logs"
mkdir -p "$LOG_DIR"
LOG_FILE="${LOG_FILE:-$LOG_DIR/scenario_manager.log}"

SCENARIO_JSON="$(resolve_path "$SCENARIO_JSON_RAW")"
DEPLOY_STATUS="$(resolve_path "state/deployment_status.json")"
LOCKFILE="$(resolve_path "state/scenario_manager.lock")"

# atomic write helper for JSON status
write_deploy_status() {
    local status="$1"
    local err="$2"
    local ts
    ts=$(date -u +%Y-%m-%dT%H:%M:%SZ)
    local pid="$$"
    local payload
    # use python3 to ensure proper JSON escaping if available, otherwise fallback
    if command -v python3 >/dev/null 2>&1; then
        payload=$(python3 - <<PY
import json,sys
obj={
  "status": sys.argv[1],
  "error": None if sys.argv[2] in ("", "null") else sys.argv[2],
  "timestamp": sys.argv[3],
  "pid": int(sys.argv[4])
}
print(json.dumps(obj))
PY
        "$status" "${err:-null}" "$ts" "$pid")
    else
        # minimal safe output
        if [[ -z "${err:-}" || "${err}" == "null" ]]; then err=null; else err="\"$err\""; fi
        payload="{\"status\":\"$status\",\"error\":$err,\"timestamp\":\"$ts\",\"pid\":$pid}"
    fi
    local tmp
    tmp=$(mktemp --tmpdir "$STATE_DIR" .deploystatus.XXXXXX) || tmp="$STATE_DIR/.deploystatus.$$"
    printf '%s\n' "$payload" > "$tmp" && mv -f "$tmp" "$DEPLOY_STATUS" || echo "$payload" > "$DEPLOY_STATUS"
}

# ensure core log utils exists before sourcing
if [[ ! -f "$CORE_DIR/log_utils.sh" ]]; then
    echo "[ERROR] Missing $CORE_DIR/log_utils.sh" >&2
    write_deploy_status "error" "missing_log_utils"
    exit 1
fi

source "$CORE_DIR/log_utils.sh"

log_section "Scenario deployment started"

write_deploy_status "running" null

# lock to prevent concurrent runs
exec 200>"$LOCKFILE" || {
    log_error "Unable to open lockfile $LOCKFILE"
    write_deploy_status "error" "lock_open_failed"
    exit 1
}
if ! flock -n 200; then
    log_error "Another instance is running (lock: $LOCKFILE)"
    write_deploy_status "error" "locked"
    exit 1
fi

cleanup() {
    local rc=$?
    # release the lock
    if [[ -n "${LOCKFILE:-}" ]]; then
        flock -u 200 || true
        rm -f "$LOCKFILE" 2>/dev/null || true
    fi
    # on non-zero exit, ensure status recorded
    if [[ $rc -ne 0 ]]; then
        write_deploy_status "error" "exit_$rc"
        log_error "Exiting with code $rc"
    fi
}

on_signal() {
    local sig="$1"
    log_warn "Caught signal $sig, aborting"
    write_deploy_status "cancelled" "signal_$sig"
    exit 130
}

trap on_signal INT TERM
trap cleanup EXIT

check_command() {
    local cmd="$1"
    if ! command -v "$cmd" >/dev/null 2>&1; then
        log_error "Missing required command: $cmd"
        return 1
    fi
}

log_info "Using scenario JSON: $SCENARIO_JSON"

if [[ $DRY_RUN -eq 1 ]]; then
    log_info "Running in dry-run mode: validations only"
fi

# Basic dependency checks (jq and python3 recommended)
MISSING=0
for c in bash python3 jq; do
    if ! check_command "$c"; then
        MISSING=1
    fi
done
if [[ $MISSING -ne 0 ]]; then
    write_deploy_status "error" "missing_prereqs"
    log_error "One or more required commands missing (needs: bash, python3, jq)"
    exit 2
fi

# validate JSON exists
if [[ ! -f "$SCENARIO_JSON" ]]; then
    log_error "Scenario JSON not found: $SCENARIO_JSON"
    write_deploy_status "error" "scenario_json_missing"
    exit 1
fi

# validate JSON shape using jq (fail early)
if ! jq -e . >/dev/null 2>&1 < "$SCENARIO_JSON"; then
    log_error "Scenario JSON is not valid JSON: $SCENARIO_JSON"
    write_deploy_status "error" "invalid_json"
    exit 1
fi

if ! bash "$CORE_DIR/validate_scenario.sh" "$SCENARIO_JSON"; then
    write_deploy_status "error" "validation_failed"
    log_error "Scenario validation failed"
    exit 1
fi

if [[ $DRY_RUN -eq 0 ]]; then
    if ! bash "$CORE_DIR/generate_nodes.sh" "$SCENARIO_JSON" "$STATE_DIR"; then
        write_deploy_status "error" "generation_failed"
        log_error "Node generation failed"
        exit 1
    fi

    if ! bash "$CORE_DIR/build_summary.sh" "$STATE_DIR"; then
        write_deploy_status "error" "summary_failed"
        log_error "Summary building failed"
        exit 1
    fi
fi

write_deploy_status "completed" null

log_section "Scenario deployment completed successfully"
log_info "Node summary available at: $STATE_DIR/summary.json"
log_info "Deployment status: $DEPLOY_STATUS"

# release traps and exit cleanly
trap - INT TERM EXIT
exec 200>&-
