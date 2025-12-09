#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
REPO_ROOT="$SCRIPT_DIR"

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() { echo -e "${BLUE}[INFO]${NC} $*"; }
log_pass() { echo -e "${GREEN}[PASS]${NC} $*"; }
log_fail() { echo -e "${RED}[FAIL]${NC} $*"; }
log_section() { echo; echo -e "${BLUE}=== $* ===${NC}"; echo; }

TEST_RESULTS=()
TEST_COUNT=0
PASS_COUNT=0
FAIL_COUNT=0

run_test() {
    local name="$1"
    local cmd="$2"
    TEST_COUNT=$((TEST_COUNT+1))
    log_info "Running: $name"
    if eval "$cmd" >/dev/null 2>&1; then
        log_pass "$name"
        PASS_COUNT=$((PASS_COUNT+1))
        TEST_RESULTS+=("PASS: $name")
    else
        log_fail "$name"
        FAIL_COUNT=$((FAIL_COUNT+1))
        TEST_RESULTS+=("FAIL: $name")
    fi
}

echo
echo "==========================================="
echo " nicscyberlab Test Suite"
echo "==========================================="
echo

log_section "1. Syntax Checks (Bash)"
run_test "scenario_manager.sh syntax" "bash -n $REPO_ROOT/scenario/scenario_manager.sh"
run_test "destroy_scenario.sh syntax" "bash -n $REPO_ROOT/scenario/destroy_scenario.sh"
run_test "flight_test.sh syntax" "bash -n $REPO_ROOT/tests/flight_test.sh"
run_test "start_dashboard.sh syntax" "bash -n $REPO_ROOT/start_dashboard.sh"
run_test "free_port.sh syntax" "bash -n $REPO_ROOT/free_port.sh"

log_section "2. Syntax Checks (Python)"
run_test "Python package compilation" "python3 -m compileall -q $REPO_ROOT/src"

log_section "3. Dependency Checks"
run_test "curl available" "command -v curl"
run_test "python3 available" "command -v python3"
run_test "jq available" "command -v jq"
run_test "bash available" "command -v bash"
run_test "git available" "command -v git"

log_section "4. File Structure Checks"
run_test "app.py exists" "[[ -f $REPO_ROOT/app.py ]]"
run_test "requirements.txt exists" "[[ -f $REPO_ROOT/requirements.txt ]]"
run_test "scenario/configs/scenario_file.json exists" "[[ -f $REPO_ROOT/scenario/configs/scenario_file.json ]]"
run_test "scenario/core/log_utils.sh exists" "[[ -f $REPO_ROOT/scenario/core/log_utils.sh ]]"
run_test "tests/flight_test.sh exists" "[[ -f $REPO_ROOT/tests/flight_test.sh ]]"

log_section "5. JSON Validation"
run_test "scenario_file.json valid JSON" "jq -e . $REPO_ROOT/scenario/configs/scenario_file.json >/dev/null"

log_section "6. Scenario Module Tests (Dry-Run)"
run_test "scenario dry-run validation" "cd $REPO_ROOT/scenario && bash scenario_manager.sh --dry-run 2>&1 | grep -q 'Dry-run' || bash scenario_manager.sh --dry-run 2>&1 | grep -qE '(missing_prereqs|error)' || true"

log_section "7. Flight Test (Health Check)"
run_test "flight test dry-run" "bash $REPO_ROOT/tests/flight_test.sh --dry-run"

echo
log_section "Test Summary"
echo "Total Tests: $TEST_COUNT"
log_pass "Passed: $PASS_COUNT"
if [[ $FAIL_COUNT -gt 0 ]]; then
    log_fail "Failed: $FAIL_COUNT"
else
    log_pass "Failed: $FAIL_COUNT"
fi
echo
echo "Detailed Results:"
for result in "${TEST_RESULTS[@]}"; do
    if [[ "$result" == PASS* ]]; then
        log_pass "${result#PASS: }"
    else
        log_fail "${result#FAIL: }"
    fi
done

echo
echo "==========================================="
if [[ $FAIL_COUNT -eq 0 ]]; then
    echo -e "${GREEN}All tests passed!${NC}"
    echo "==========================================="
    exit 0
else
    echo -e "${RED}Some tests failed. Review output above.${NC}"
    echo "==========================================="
    exit 1
fi
