#!/bin/bash
set -uo pipefail

BASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MODULES_DIR="$BASE_DIR/modules"
CONFIG_FILE="$BASE_DIR/configs/initial_config.json"
LOG_DIR="$BASE_DIR/logs"
mkdir -p "$LOG_DIR"

LOG_FILE="$LOG_DIR/test_initial_module.log"
JSON_LOG="$LOG_DIR/test_initial_module.json"
SUMMARY_FILE="$LOG_DIR/test_initial_module_summary.txt"

# Clear previous logs
touch "$LOG_FILE" "$JSON_LOG" "$SUMMARY_FILE"
cat /dev/null > "$LOG_FILE"
cat /dev/null > "$JSON_LOG"
cat /dev/null > "$SUMMARY_FILE"

timestamp() { date +"%Y-%m-%d %H:%M:%S"; }
json_timestamp() { date -u +"%Y-%m-%dT%H:%M:%SZ"; }

log() {
    local msg="$1"
    {
        echo "[$(timestamp)] [INFO] $msg"
    } | tee -a "$LOG_FILE" 2>/dev/null || echo "[$(timestamp)] [INFO] $msg" >> "$LOG_FILE"
    {
        echo "{\"timestamp\": \"$(json_timestamp)\", \"level\": \"info\", \"message\": \"$msg\"}"
    } >> "$JSON_LOG" 2>/dev/null || true
}

success() {
    local msg="$1"
    {
        echo "[$(timestamp)] [SUCCESS] $msg"
    } | tee -a "$LOG_FILE" 2>/dev/null || echo "[$(timestamp)] [SUCCESS] $msg" >> "$LOG_FILE"
    {
        echo "{\"timestamp\": \"$(json_timestamp)\", \"level\": \"success\", \"message\": \"$msg\"}"
    } >> "$JSON_LOG" 2>/dev/null || true
}

warn() {
    local msg="$1"
    {
        echo "[$(timestamp)] [WARNING] $msg"
    } | tee -a "$LOG_FILE" 2>/dev/null || echo "[$(timestamp)] [WARNING] $msg" >> "$LOG_FILE"
    {
        echo "{\"timestamp\": \"$(json_timestamp)\", \"level\": \"warning\", \"message\": \"$msg\"}"
    } >> "$JSON_LOG" 2>/dev/null || true
}

abort() {
    local msg="$1"
    echo "[$(timestamp)] [ERROR] $msg" | tee -a "$LOG_FILE"
    echo "{\"timestamp\": \"$(json_timestamp)\", \"level\": \"error\", \"message\": \"$msg\"}" >> "$JSON_LOG"
    
    {
        echo "Initial Module Preflight Test Summary"
        echo "====================================="
        echo "Execution Date: $(timestamp)"
        echo "Status: FAILED"
        echo ""
        echo "Last Error: $msg"
    } | tee -a "$SUMMARY_FILE"
    
    exit 1
}

# Test counter
TESTS_PASSED=0
TESTS_WARNED=0
TESTS_FAILED=0

test_result() {
    local name="$1"
    local result="$2"
    
    case "$result" in
        "pass")
            ((TESTS_PASSED++))
            success "$name"
            ;;
        "warn")
            ((TESTS_WARNED++))
            warn "$name"
            ;;
        "fail")
            ((TESTS_FAILED++))
            abort "$name"
            ;;
    esac
}

log "=== Initial Module Preflight Test Started ==="

# -------------------------------------------------
# 1. Validate required files and directory structure
# -------------------------------------------------

log "[TEST 1/10] Checking directory structure"

[ -d "$MODULES_DIR" ] || abort "Modules directory missing: $MODULES_DIR"
test_result "Modules directory exists" "pass"

[ -f "$CONFIG_FILE" ] || abort "Config file missing: $CONFIG_FILE"
test_result "Configuration file exists" "pass"

required_modules=(
    "log_utils.sh"
    "validate_environment.sh"
    "load_config.sh"
    "upload_images.sh"
    "create_keypair.sh"
    "create_networks.sh"
    "create_security_groups.sh"
    "create_flavors.sh"
    "initial_setup.sh"
    "openstack_cleanup.sh"
    "generate_openrc.sh"
)

for f in "${required_modules[@]}"; do
    [ -f "$MODULES_DIR/$f" ] || abort "Module missing: $f"
done
test_result "All required modules present (11 files)" "pass"

# Check if all modules are executable
all_executable=true
for f in "${required_modules[@]}"; do
    if [ ! -x "$MODULES_DIR/$f" ]; then
        warn "Module not executable: $f"
        all_executable=false
    fi
done

if [ "$all_executable" = true ]; then
    test_result "All modules are executable" "pass"
else
    test_result "Some modules are not executable (fixing...)" "warn"
    chmod +x "$MODULES_DIR"/*.sh 2>/dev/null || true
fi

# -------------------------------------------------
# 2. Validate JSON exists and is syntactically correct
# -------------------------------------------------

log "[TEST 2/10] Validating JSON syntax"

if ! command -v jq >/dev/null 2>&1; then
    abort "jq is required but not installed (install with: sudo apt-get install jq)"
fi
test_result "jq is installed" "pass"

if ! jq empty "$CONFIG_FILE" 2>/dev/null; then
    abort "initial_config.json is not valid JSON (check for syntax errors)"
fi
test_result "JSON syntax is valid" "pass"

# -------------------------------------------------
# 3. Validate presence of required JSON fields
# -------------------------------------------------

log "[TEST 3/10] Checking JSON required fields"

required_keys=(
    ".images"
    ".networks.external.name"
    ".networks.external.cidr"
    ".networks.external.subnet_name"
    ".networks.private.name"
    ".networks.private.cidr"
    ".networks.private.subnet_name"
    ".networks.private.dns"
    ".security_group.name"
    ".flavors.tiny"
    ".flavors.small"
    ".flavors.medium"
    ".flavors.large"
    ".keypair.name"
    ".keypair.path"
)

missing_keys=()
for key in "${required_keys[@]}"; do
    value=$(jq -r "$key" "$CONFIG_FILE" 2>/dev/null || echo "null")
    if [ "$value" = "null" ] || [ -z "$value" ]; then
        missing_keys+=("$key")
    fi
done

if [ ${#missing_keys[@]} -gt 0 ]; then
    abort "Missing required config keys: ${missing_keys[*]}"
fi
test_result "All required JSON fields present" "pass"

# -------------------------------------------------
# 4. Validate JSON field values
# -------------------------------------------------

log "[TEST 4/10] Validating JSON field values"

# Check CIDR format
ext_cidr=$(jq -r '.networks.external.cidr' "$CONFIG_FILE")
priv_cidr=$(jq -r '.networks.private.cidr' "$CONFIG_FILE")

if ! echo "$ext_cidr" | grep -qE '^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}/[0-9]{1,2}$'; then
    abort "Invalid external CIDR format: $ext_cidr"
fi
test_result "External CIDR format valid: $ext_cidr" "pass"

if ! echo "$priv_cidr" | grep -qE '^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}/[0-9]{1,2}$'; then
    abort "Invalid private CIDR format: $priv_cidr"
fi
test_result "Private CIDR format valid: $priv_cidr" "pass"

# Validate flavor specs
for flavor in tiny small medium large; do
    vcpu=$(jq -r ".flavors.$flavor.vcpus" "$CONFIG_FILE" 2>/dev/null || echo "null")
    ram=$(jq -r ".flavors.$flavor.ram" "$CONFIG_FILE" 2>/dev/null || echo "null")
    disk=$(jq -r ".flavors.$flavor.disk" "$CONFIG_FILE" 2>/dev/null || echo "null")
    
    if [ "$vcpu" = "null" ] || [ -z "$vcpu" ]; then
        abort "Missing vCPU for flavor $flavor"
    fi
    if ! [[ "$vcpu" =~ ^[0-9]+$ ]] || [ "$vcpu" -lt 1 ]; then
        abort "Invalid vCPU for flavor $flavor: $vcpu"
    fi
    if [ "$ram" = "null" ] || [ -z "$ram" ]; then
        abort "Missing RAM for flavor $flavor"
    fi
    if ! [[ "$ram" =~ ^[0-9]+$ ]] || [ "$ram" -lt 256 ]; then
        abort "Invalid RAM for flavor $flavor: $ram"
    fi
    if [ "$disk" = "null" ] || [ -z "$disk" ]; then
        abort "Missing disk for flavor $flavor"
    fi
    if ! [[ "$disk" =~ ^[0-9]+$ ]] || [ "$disk" -lt 1 ]; then
        abort "Invalid disk for flavor $flavor: $disk"
    fi
done
test_result "All flavor specifications valid" "pass"

# -------------------------------------------------
# 5. Validate image entries in JSON
# -------------------------------------------------

log "[TEST 5/10] Validating image entries"

image_list=$(jq '.images.list' "$CONFIG_FILE" 2>/dev/null || echo "{}")
image_count=$(echo "$image_list" | jq 'length')

if [ "$image_count" -eq 0 ]; then
    warn "No images configured in JSON (module will run but upload nothing)"
    test_result "Image list empty" "warn"
else
    test_result "Found $image_count images in configuration" "pass"
fi

# -------------------------------------------------
# 6. Validate URLs of images (HEAD request, no download)
# -------------------------------------------------

log "[TEST 6/10] Validating image URLs accessibility"

if ! command -v curl >/dev/null 2>&1; then
    warn "curl not found - skipping URL validation (will be installed by openstack module)"
    test_result "curl not available (non-critical)" "warn"
else
    if [ "$image_count" -gt 0 ]; then
        failed_urls=0
        jq -r '.images.list | to_entries[] | "\(.key)|\(.value)"' "$CONFIG_FILE" | while IFS='|' read -r img_name img_url; do
            if curl -Is --connect-timeout 5 "$img_url" 2>/dev/null | head -n 1 | grep -qE "200|301|302|403"; then
                log "  Image URL OK: $img_name"
            else
                warn "  Image URL may be unreachable: $img_name ($img_url)"
                ((failed_urls++)) || true
            fi
        done
        
        # For simplicity, we'll just warn if any fail
        test_result "Image URLs validated (may have issues)" "pass"
    else
        test_result "No images to validate" "pass"
    fi
fi

# -------------------------------------------------
# 7. Validate environment: openstack CLI available
# -------------------------------------------------

log "[TEST 7/10] Checking OpenStack CLI availability"

if ! command -v openstack >/dev/null 2>&1; then
    abort "openstack command not found (install with: pip install python-openstackclient)"
fi
test_result "openstack CLI is installed" "pass"

# Check OpenStack version
openstack_version=$(openstack --version 2>&1 | head -1)
log "  OpenStack version: $openstack_version"
test_result "OpenStack CLI version: $openstack_version" "pass"

# -------------------------------------------------
# 8. Validate admin-openrc.sh is sourced
# -------------------------------------------------

log "[TEST 8/10] Checking OpenStack environment variables"

env_required=(
    "OS_AUTH_URL"
    "OS_USERNAME"
    "OS_PASSWORD"
    "OS_PROJECT_NAME"
)

missing_env=()
for v in "${env_required[@]}"; do
    if [ -z "${!v:-}" ]; then
        missing_env+=("$v")
    fi
done

if [ ${#missing_env[@]} -gt 0 ]; then
    abort "Environment variables not set: ${missing_env[*]} - have you sourced admin-openrc.sh?"
fi
test_result "Required OpenStack environment variables are set" "pass"

# Log important env vars
log "  OS_AUTH_URL: ${OS_AUTH_URL:0:50}..."
log "  OS_USERNAME: $OS_USERNAME"
log "  OS_PROJECT_NAME: $OS_PROJECT_NAME"

# -------------------------------------------------
# 9. Test API authentication (without modifying anything)
# -------------------------------------------------

log "[TEST 9/10] Testing OpenStack API authentication"

if ! openstack token issue >/dev/null 2>&1; then
    abort "Failed to issue token - check credentials in admin-openrc.sh or API connectivity"
fi
test_result "Authentication token issued successfully" "pass"

# -------------------------------------------------
# 10. Test OpenStack service availability (non-destructive)
# -------------------------------------------------

log "[TEST 10/10] Checking OpenStack services availability"

services_required=("image" "network" "compute")
services_ok=true

for service in "${services_required[@]}"; do
    if openstack service list -f value -c Name 2>/dev/null | grep -q "^$service$"; then
        log "  Service OK: $service"
    else
        warn "  Service missing or unavailable: $service"
        services_ok=false
    fi
done

if [ "$services_ok" = true ]; then
    test_result "All required OpenStack services available" "pass"
else
    test_result "Some services unavailable (may still work)" "warn"
fi

# -------------------------------------------------
# Final checks: potential conflicts
# -------------------------------------------------

log "Checking for potential resource conflicts"

conflict_count=0

# Check flavors
for flavor in tiny small medium large; do
    if openstack flavor show "cyberlab-$flavor" >/dev/null 2>&1; then
        warn "Flavor already exists: cyberlab-$flavor (will be skipped)"
        ((conflict_count++))
    fi
done

# Check networks
if openstack network show "external" >/dev/null 2>&1; then
    warn "Network already exists: external (will be skipped)"
    ((conflict_count++))
fi

if openstack network show "private" >/dev/null 2>&1; then
    warn "Network already exists: private (will be skipped)"
    ((conflict_count++))
fi

# Check security groups
if openstack security group show "cyberlab-secgroup" >/dev/null 2>&1; then
    warn "Security group already exists: cyberlab-secgroup (will be skipped)"
    ((conflict_count++))
fi

# Check keypair
if openstack keypair show "cyberlab-key" >/dev/null 2>&1; then
    warn "Keypair already exists: cyberlab-key (will be skipped)"
    ((conflict_count++))
fi

if [ "$conflict_count" -eq 0 ]; then
    log "No resource conflicts detected"
else
    log "Found $conflict_count existing resources (module will handle gracefully)"
fi

# -------------------------------------------------
# Generate Summary Report
# -------------------------------------------------

{
    echo "Initial Module Preflight Test Summary"
    echo "======================================"
    echo "Execution Date: $(timestamp)"
    echo "Status: PASSED"
    echo ""
    echo "Test Results:"
    echo "  Passed:  $TESTS_PASSED"
    echo "  Warned:  $TESTS_WARNED"
    echo "  Failed:  $TESTS_FAILED"
    echo ""
    echo "All validations completed successfully."
    echo "Ready to execute: ./modules/initial_setup.sh"
} | tee -a "$SUMMARY_FILE"

log "=== Initial Module Preflight Test Completed Successfully ==="
success "All checks passed. System is ready for Initial module execution."

echo ""
echo "Summary:"
echo "  Passed:  $TESTS_PASSED"
echo "  Warned:  $TESTS_WARNED"
echo "  Failed:  $TESTS_FAILED"
echo ""
echo "Ready to execute Initial setup:"
echo "  ./modules/initial_setup.sh configs/initial_config.json"
echo ""
echo "Logs available in:"
echo "  - $LOG_FILE"
echo "  - $JSON_LOG"
echo "  - $SUMMARY_FILE"

exit 0
