#!/usr/bin/env bash
#set -x
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd -P)"
STATE_DIR="$REPO_ROOT/state/tests"
LOG_DIR="$STATE_DIR/logs"
mkdir -p "$LOG_DIR"

# Defaults
DRY_RUN=0
START_DASHBOARD=0
URL_DEFAULT="http://localhost:5001"
URL="$URL_DEFAULT"
HEALTH_PATHS=("/" "_health" "api/health")
TIMEOUT=10
RETRIES=5
SLEEP_BETWEEN=2
REPORT_FILE=""

usage() {
    cat <<EOF
Usage: $(basename "$0") [OPTIONS]

Professional flight/health test for the dashboard and key endpoints.

Options:
  -h, --help          Show this help and exit
  -n, --dry-run       Validate environment and planned checks only
  --start             Start dashboard via start_dashboard.sh (background)
  --url URL           Base URL to test (default: $URL_DEFAULT)
  --timeout SEC       Per-request timeout seconds (default: $TIMEOUT)
  --retries N         Number of retries for service startup (default: $RETRIES)
  --sleep SEC         Seconds between retries when waiting for service (default: $SLEEP_BETWEEN)
  --log FILE          Write JSON report to FILE (default: state/tests/logs/flight_report_<ts>.json)

Examples:
  # dry run validations
  bash tests/flight_test.sh --dry-run

  # run full checks and start dashboard if needed
  bash tests/flight_test.sh --start --url http://localhost:5001

EOF
}

log() { printf '%s %s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$*"; }
log_info() { log "[INFO]" "$*"; }
log_warn() { log "[WARN]" "$*"; }
log_error() { log "[ERROR]" "$*"; }

# minimal JSON writer: uses python3 if available for safe encoding
json_dump() {
    local outfile="$1"; shift
    if command -v python3 >/dev/null 2>&1; then
        python3 - <<PY > "$outfile"
import json,sys
obj=$1
print(json.dumps(obj, indent=2))
PY
    else
        # fallback: naive (only used for simple values)
        echo "$1" > "$outfile"
    fi
}

# write report (with python3 if available)
write_report() {
    local payload="$1"
    if [[ -z "${REPORT_FILE:-}" ]]; then
        local ts
        ts=$(date -u +%Y%m%dT%H%M%SZ)
        REPORT_FILE="$LOG_DIR/flight_report_${ts}.json"
    fi
    if command -v python3 >/dev/null 2>&1; then
        python3 - <<PY > "$REPORT_FILE"
import json,sys
print(json.dumps($payload, indent=2))
PY
    else
        echo "$payload" > "$REPORT_FILE"
    fi
    log_info "Report written to $REPORT_FILE"
}

check_command() {
    if ! command -v "$1" >/dev/null 2>&1; then
        log_error "Required command missing: $1"
        return 1
    fi
}

wait_for_service() {
    local base_url="$1"
    local retries="$2"
    local timeout="$3"
    local sleep_sec="$4"
    local i=0
    while [[ $i -lt $retries ]]; do
        if curl -sS --max-time "$timeout" "$base_url" >/dev/null 2>&1; then
            return 0
        fi
        sleep "$sleep_sec"
        i=$((i+1))
    done
    return 1
}

perform_check() {
    local endpoint="$1"
    local full_url="$URL/${endpoint#"/"}"
    local start_ms end_ms dur_ms
    start_ms=$(date +%s%3N)
    if curl -sS -o /dev/null -w "%{http_code}" --max-time "$TIMEOUT" "$full_url" >/tmp/flight_http_code 2>/tmp/flight_err; then
        local code
        code=$(cat /tmp/flight_http_code)
        end_ms=$(date +%s%3N)
        dur_ms=$((end_ms-start_ms))
        rm -f /tmp/flight_http_code /tmp/flight_err
        echo "{\"endpoint\":\"$endpoint\",\"status\":\"pass\",\"http_code\":$code,\"time_ms\":$dur_ms}"
        return 0
    else
        local err
        err=$(sed -n '1,120p' /tmp/flight_err 2>/dev/null || true)
        end_ms=$(date +%s%3N)
        dur_ms=$((end_ms-start_ms))
        rm -f /tmp/flight_http_code /tmp/flight_err
        echo "{\"endpoint\":\"$endpoint\",\"status\":\"fail\",\"error\":\"$(echo "$err" | sed 's/"/\\"/g')\",\"time_ms\":$dur_ms}"
        return 1
    fi
}

# parse args
while [[ $# -gt 0 ]]; do
    case "$1" in
        -h|--help)
            usage; exit 0 ;;
        -n|--dry-run)
            DRY_RUN=1; shift ;;
        --start)
            START_DASHBOARD=1; shift ;;
        --url)
            URL="$2"; shift 2 ;;
        --timeout)
            TIMEOUT="$2"; shift 2 ;;
        --retries)
            RETRIES="$2"; shift 2 ;;
        --sleep)
            SLEEP_BETWEEN="$2"; shift 2 ;;
        --log)
            REPORT_FILE="$2"; shift 2 ;;
        *)
            echo "Unknown arg: $1"; usage; exit 2 ;;
    esac
done

# Basic dependency check
DEPEND_MISS=0
for cmd in curl date; do
    if ! check_command "$cmd"; then DEPEND_MISS=1; fi
done
if [[ $DEPEND_MISS -ne 0 ]]; then
    log_error "Missing dependencies. Install curl/date.";
    exit 2
fi

# If dry-run, show planned checks and exit
if [[ $DRY_RUN -eq 1 ]]; then
    log_info "Dry-run: planned checks for URL: $URL"
    for p in "${HEALTH_PATHS[@]}"; do
        log_info "  - Check: $URL/$p"
    done
    log_info "No changes will be made in dry-run mode."
    write_report "{\"timestamp\":\"$(date -u +%Y-%m-%dT%H:%M:%SZ)\",\"mode\":\"dry-run\",\"url\":\"$URL\",\"checks\":[] }"
    exit 0
fi

STARTED_PID=""
if [[ $START_DASHBOARD -eq 1 ]]; then
    if [[ -x "$REPO_ROOT/start_dashboard.sh" ]]; then
        log_info "Starting dashboard in background via start_dashboard.sh"
        bash "$REPO_ROOT/start_dashboard.sh" &>/dev/null &
        STARTED_PID=$!
        log_info "Started dashboard PID $STARTED_PID"
        # wait for service
        if ! wait_for_service "$URL" "$RETRIES" "$TIMEOUT" "$SLEEP_BETWEEN"; then
            log_error "Dashboard did not become available at $URL after $RETRIES attempts"
            write_report "{\"timestamp\":\"$(date -u +%Y-%m-%dT%H:%M:%SZ)\",\"status\":\"fail\",\"error\":\"service_not_ready\"}"
            kill ${STARTED_PID:-0} 2>/dev/null || true
            exit 2
        fi
    else
        log_error "start_dashboard.sh not found or not executable at $REPO_ROOT/start_dashboard.sh"
        exit 1
    fi
fi

# Perform checks
TOTAL=0; PASS=0; FAIL=0
CHECKS_JSON='[]'
for p in "${HEALTH_PATHS[@]}"; do
    TOTAL=$((TOTAL+1))
    result=$(perform_check "$p") || true
    # Use jq to safely add to JSON array
    CHECKS_JSON=$(echo "$CHECKS_JSON" | jq --argjson check "$result" '. += [$check]')
    if echo "$result" | grep -q '"status":"pass"'; then PASS=$((PASS+1)); else FAIL=$((FAIL+1)); fi
done

STATUS="pass"
if [[ $FAIL -gt 0 && $PASS -gt 0 ]]; then STATUS="partial"; fi
if [[ $PASS -eq 0 && $FAIL -gt 0 ]]; then STATUS="fail"; fi

PAYLOAD="{\"timestamp\":\"$(date -u +%Y-%m-%dT%H:%M:%SZ)\",\"url\":\"$URL\",\"status\":\"$STATUS\",\"summary\":{\"total\":$TOTAL,\"pass\":$PASS,\"fail\":$FAIL},\"checks\":$CHECKS_JSON}"

write_report "$PAYLOAD"

# cleanup started dashboard if we started it
if [[ -n "$STARTED_PID" ]]; then
    log_info "Stopping dashboard PID $STARTED_PID"
    kill "$STARTED_PID" 2>/dev/null || true
fi

if [[ "$STATUS" == "pass" ]]; then
    log_info "Flight test PASSED: $PASS/$TOTAL checks"
    exit 0
elif [[ "$STATUS" == "partial" ]]; then
    log_warn "Flight test PARTIAL: $PASS/$TOTAL checks"
    exit 1
else
    log_error "Flight test FAILED: $PASS/$TOTAL checks"
    exit 2
fi
