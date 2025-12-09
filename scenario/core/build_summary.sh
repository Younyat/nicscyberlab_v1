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
SUMMARY_TMP="$OUTDIR/summary.tmp.json"
SUMMARY_FINAL="$OUTDIR/summary.json"

log_section "Building final summary.json"

on_error() {
    local rc=$?
    log_error "build_summary.sh failed with exit code $rc"
    exit $rc
}

trap on_error ERR

if [ ! -f "$SUMMARY_TMP" ]; then
    log_error "Temporary summary not found: $SUMMARY_TMP"
    exit 1
fi

require_command jq

jq '.' "$SUMMARY_TMP" > "$SUMMARY_FINAL"
rm -f "$SUMMARY_TMP"

log_info "Summary written to: $SUMMARY_FINAL"
log_info "Node count: $(jq '. | length' "$SUMMARY_FINAL")"

jq '.[] | "\(.name): \(.ssh_user)@\(.floating_ip)"' -r "$SUMMARY_FINAL" | while read -r line; do
    log_info "  $line"
done
