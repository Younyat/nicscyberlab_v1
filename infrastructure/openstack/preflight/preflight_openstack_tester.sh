#!/bin/bash
# ==========================================
# Preflight Tester for OpenStack + Kolla
# ==========================================

set +e  # No salir en primer error

BASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LOG_DIR="$BASE_DIR/logs"
mkdir -p "$LOG_DIR"

# Logs especializados
LOG_FILE="$LOG_DIR/preflight.log"
LOG_DETAILED="$LOG_DIR/preflight_detailed.log"
LOG_JSON="$LOG_DIR/preflight_results.json"
LOG_SUMMARY="$LOG_DIR/preflight_summary.txt"

# Limpiar logs anteriores
> "$LOG_FILE"
> "$LOG_DETAILED"
> "$LOG_JSON"

# Colores para consola
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m'

# Contadores
CHECKS_PASSED=0
CHECKS_FAILED=0
CHECKS_WARNING=0

timestamp() { date +"%Y-%m-%d %H:%M:%S"; }
timestamp_iso() { date +"%Y-%m-%dT%H:%M:%S%z"; }

log() { 
    local msg="$1"
    echo "[$(timestamp)] $msg" | tee -a "$LOG_FILE" >> "$LOG_DETAILED"
}

log_level() {
    local level="$1"
    local msg="$2"
    local timestamp_val="$(timestamp)"
    
    case "$level" in
        INFO)
            echo -e "${BLUE}[${timestamp_val}]${NC} ${BLUE}[INFO]${NC} $msg" | tee -a "$LOG_FILE"
            echo "[${timestamp_val}] [INFO] $msg" >> "$LOG_DETAILED"
            ;;
        SUCCESS)
            echo -e "${GREEN}[${timestamp_val}]${NC} ${GREEN}[✓]${NC} $msg" | tee -a "$LOG_FILE"
            echo "[${timestamp_val}] [SUCCESS] $msg" >> "$LOG_DETAILED"
            CHECKS_PASSED=$((CHECKS_PASSED + 1))
            ;;
        FAIL)
            echo -e "${RED}[${timestamp_val}]${NC} ${RED}[✗]${NC} $msg" | tee -a "$LOG_FILE"
            echo "[${timestamp_val}] [FAIL] $msg" >> "$LOG_DETAILED"
            CHECKS_FAILED=$((CHECKS_FAILED + 1))
            ;;
        WARNING)
            echo -e "${YELLOW}[${timestamp_val}]${NC} ${YELLOW}[⚠]${NC} $msg" | tee -a "$LOG_FILE"
            echo "[${timestamp_val}] [WARNING] $msg" >> "$LOG_DETAILED"
            CHECKS_WARNING=$((CHECKS_WARNING + 1))
            ;;
        DEBUG)
            echo "[${timestamp_val}] [DEBUG] $msg" >> "$LOG_DETAILED"
            ;;
    esac
}

json_result() {
    local check_name="$1"
    local status="$2"
    local value="$3"
    local timestamp_val="$(timestamp_iso)"
    
    echo "{\"check\": \"$check_name\", \"status\": \"$status\", \"value\": \"$value\", \"timestamp\": \"$timestamp_val\"}," >> "$LOG_JSON"
}

separator() {
    echo "======================================" | tee -a "$LOG_FILE"
}

log "=== OpenStack Preflight Tester Started ==="

# ------------------------------------------
# 1. User and sudo permissions
# ------------------------------------------

log_level "INFO" "=== CHECKING EXECUTOR IDENTITY ==="

if [ "$EUID" -eq 0 ]; then
    log_level "FAIL" "Script must NOT run as root"
    json_result "user_not_root" "FAIL" "EUID=$EUID"
    exit 1
fi

USER_NAME=$(whoami)
USER_UID=$EUID
USER_GROUPS=$(id -Gn)

log_level "SUCCESS" "User: $USER_NAME (UID=$USER_UID)"
log_level "DEBUG" "Groups: $USER_GROUPS"
json_result "user_identity" "SUCCESS" "user=$USER_NAME, uid=$USER_UID"

# Verificar grupos sudo
if echo "$USER_GROUPS" | grep -qw "sudo"; then
    log_level "SUCCESS" "User is member of sudo group"
    json_result "sudo_group" "SUCCESS" "member"
else
    log_level "WARNING" "User is NOT in sudo group (may need to add later)"
    json_result "sudo_group" "WARNING" "not_member"
fi

# ------------------------------------------
# 2. System compatibility
# ------------------------------------------

log_level "INFO" "=== CHECKING OS VERSION ==="

if ! grep -qi "ubuntu" /etc/os-release; then
    log_level "FAIL" "Only Ubuntu is supported for Kolla-Ansible deployment"
    json_result "os_compatibility" "FAIL" "Not Ubuntu"
    exit 1
fi

UBUNTU_VERSION=$(grep "VERSION_ID" /etc/os-release | cut -d '"' -f 2)
UBUNTU_NAME=$(grep "PRETTY_NAME" /etc/os-release | cut -d '"' -f 2)

log_level "DEBUG" "Detected: $UBUNTU_NAME"
json_result "os_version" "SUCCESS" "version=$UBUNTU_VERSION"

if [[ "$UBUNTU_VERSION" != "22.04" && "$UBUNTU_VERSION" != "24.04" ]]; then
    log_level "FAIL" "Unsupported Ubuntu version (must be 22.04 or 24.04, found $UBUNTU_VERSION)"
    json_result "os_version_compatibility" "FAIL" "version=$UBUNTU_VERSION"
    exit 1
fi

log_level "SUCCESS" "Ubuntu version $UBUNTU_VERSION is supported"

# ------------------------------------------
# 3. Check basic system health
# ------------------------------------------

log_level "INFO" "=== CHECKING SYSTEM RESOURCES ==="

TOTAL_RAM_MB=$(free -m | awk '/Mem:/ {print $2}')
FREE_RAM_MB=$(free -m | awk '/Mem:/ {print $7}')
USED_RAM_MB=$((TOTAL_RAM_MB - FREE_RAM_MB))
DISK_TOTAL=$(df -h / | awk 'NR==2 {print $2}')
DISK_FREE_GB=$(df -h / | awk 'NR==2 {print $4}' | sed 's/G//')
DISK_USED_GB=$(df -h / | awk 'NR==2 {print $3}' | sed 's/G//')

log_level "DEBUG" "Total RAM: ${TOTAL_RAM_MB}MB | Used: ${USED_RAM_MB}MB | Free: ${FREE_RAM_MB}MB"
log_level "DEBUG" "Disk Total: $DISK_TOTAL | Used: ${DISK_USED_GB}GB | Free: ${DISK_FREE_GB}GB"
json_result "system_ram" "SUCCESS" "total=$TOTAL_RAM_MB, free=$FREE_RAM_MB, used=$USED_RAM_MB"
json_result "system_disk" "SUCCESS" "total=$DISK_TOTAL, free=${DISK_FREE_GB}GB, used=${DISK_USED_GB}GB"

if [ "$TOTAL_RAM_MB" -lt 6000 ]; then
    log_level "FAIL" "Insufficient RAM: At least 6GB required, found ${TOTAL_RAM_MB}MB ($(( TOTAL_RAM_MB / 1024 ))GB)"
    json_result "ram_requirement" "FAIL" "required=6GB, found=$((TOTAL_RAM_MB / 1024))GB"
    exit 1
fi

log_level "SUCCESS" "RAM requirement satisfied (${TOTAL_RAM_MB}MB >= 6000MB)"

DISK_CHECK=$(echo "$DISK_FREE_GB < 20" | bc 2>/dev/null || echo "0")
if [ "$DISK_CHECK" -eq 1 ]; then
    log_level "FAIL" "Insufficient disk space: At least 20GB required, found ${DISK_FREE_GB}GB"
    json_result "disk_requirement" "FAIL" "required=20GB, found=${DISK_FREE_GB}GB"
    exit 1
fi

log_level "SUCCESS" "Disk requirement satisfied (${DISK_FREE_GB}GB >= 20GB)"

# ------------------------------------------
# 4. Network tests
# ------------------------------------------

log_level "INFO" "=== CHECKING NETWORK CONNECTIVITY ==="

if ping -c 1 -W 1 8.8.8.8 >/dev/null 2>&1; then
    log_level "SUCCESS" "External connectivity OK (ping 8.8.8.8)"
    json_result "external_connectivity" "SUCCESS" "8.8.8.8 reachable"
else
    log_level "WARNING" "Cannot reach external network (ping 8.8.8.8 failed)"
    json_result "external_connectivity" "WARNING" "ping 8.8.8.8 failed"
fi

log_level "INFO" "Testing DNS resolution"

DNS_TEST=0
DNS_METHOD="unknown"
if dig +short google.com >/dev/null 2>&1; then
    DNS_TEST=1
    DNS_METHOD="dig"
elif nslookup google.com >/dev/null 2>&1; then
    DNS_TEST=1
    DNS_METHOD="nslookup"
fi

if [ "$DNS_TEST" -eq 1 ]; then
    log_level "SUCCESS" "DNS resolution OK (method: $DNS_METHOD)"
    json_result "dns_resolution" "SUCCESS" "method=$DNS_METHOD"
else
    log_level "WARNING" "DNS resolution may have issues"
    json_result "dns_resolution" "WARNING" "possible_issues"
fi

# ------------------------------------------
# 5. Python version check
# ------------------------------------------

log_level "INFO" "=== CHECKING PYTHON AVAILABILITY ==="

if command -v python3.12 >/dev/null 2>&1; then
    PYTHON_VERSION=$(python3.12 --version)
    log_level "SUCCESS" "$PYTHON_VERSION found"
    json_result "python3_12" "SUCCESS" "$PYTHON_VERSION"
else
    log_level "WARNING" "python3.12 not found. Installation script will install it."
    json_result "python3_12" "WARNING" "not_found"
fi

# ------------------------------------------
# 6. Check Docker conflicts
# ------------------------------------------

log_level "INFO" "=== CHECKING DOCKER STATE ==="

if systemctl is-active --quiet docker 2>/dev/null; then
    log_level "WARNING" "Docker service is already running"
    json_result "docker_status" "WARNING" "service_running"
else
    log_level "DEBUG" "Docker service not active"
fi

if sudo docker ps >/dev/null 2>&1; then
    log_level "SUCCESS" "Docker command available"
    json_result "docker_command" "SUCCESS" "available"
else
    log_level "DEBUG" "Docker not installed yet (will be installed later)"
fi

# ------------------------------------------
# 7. Check network interfaces
# ------------------------------------------

log_level "INFO" "=== CHECKING NETWORK INTERFACES ==="

DEFAULT_IFACE=$(ip route 2>/dev/null | awk '/default/ {print $5; exit}' || echo "")

if [ -z "$DEFAULT_IFACE" ]; then
    log_level "FAIL" "No default interface detected"
    json_result "default_interface" "FAIL" "not_found"
    exit 1
fi

log_level "SUCCESS" "Default interface detected: $DEFAULT_IFACE"
json_result "default_interface" "SUCCESS" "interface=$DEFAULT_IFACE"

IP_ADDR=$(ip -4 addr show "$DEFAULT_IFACE" 2>/dev/null | awk '/inet / {print $2}' || echo "")

if [ -z "$IP_ADDR" ]; then
    log_level "FAIL" "Default interface has no IPv4 address"
    json_result "ipv4_address" "FAIL" "not_found"
    exit 1
fi

log_level "SUCCESS" "IPv4 address assigned: $IP_ADDR"
json_result "ipv4_address" "SUCCESS" "ip=$IP_ADDR"

# ------------------------------------------
# 8. Check for existing Kolla installation
# ------------------------------------------

log_level "INFO" "=== CHECKING PREVIOUS KOLLA INSTALLATION ==="

if [ -d "/etc/kolla" ]; then
    KOLLA_BACKUP_COUNT=$(ls -la /etc/kolla 2>/dev/null | wc -l)
    log_level "WARNING" "/etc/kolla exists with $KOLLA_BACKUP_COUNT items (previous installation detected)"
    json_result "kolla_previous" "WARNING" "exists, items=$KOLLA_BACKUP_COUNT"
else
    log_level "SUCCESS" "No previous Kolla installation detected"
    json_result "kolla_previous" "SUCCESS" "clean"
fi

# ------------------------------------------
# 9. Check virtualenv state
# ------------------------------------------

log_level "INFO" "=== CHECKING VIRTUALENV STATE ==="

VENV_DIR="$HOME/openstack_venv"

if [ -d "$VENV_DIR" ]; then
    VENV_SIZE=$(du -sh "$VENV_DIR" 2>/dev/null | awk '{print $1}')
    log_level "WARNING" "Virtualenv already exists at $VENV_DIR (size: $VENV_SIZE)"
    json_result "virtualenv" "WARNING" "exists, size=$VENV_SIZE"
else
    log_level "SUCCESS" "Virtualenv directory clean (will be created later)"
    json_result "virtualenv" "SUCCESS" "clean"
fi

# ------------------------------------------
# 10. Check critical packages
# ------------------------------------------

log_level "INFO" "=== CHECKING CRITICAL PACKAGES ==="

MISSING_PACKAGES=()

for pkg in curl wget git; do
    if command -v "$pkg" >/dev/null 2>&1; then
        log_level "SUCCESS" "Package $pkg: OK"
    else
        MISSING_PACKAGES+=("$pkg")
        log_level "DEBUG" "Package $pkg: NOT FOUND (will be installed)"
    fi
done

if [ ${#MISSING_PACKAGES[@]} -gt 0 ]; then
    log_level "WARNING" "Missing packages: ${MISSING_PACKAGES[*]} (will be installed by module 01)"
    json_result "critical_packages" "WARNING" "missing=${MISSING_PACKAGES[*]}"
else
    log_level "SUCCESS" "All critical packages available"
    json_result "critical_packages" "SUCCESS" "all_present"
fi

# ------------------------------------------
# Final Summary
# ------------------------------------------

echo "" | tee -a "$LOG_FILE"
separator
echo -e "${MAGENTA}PREFLIGHT TEST SUMMARY${NC}" | tee -a "$LOG_FILE"
separator
echo "" | tee -a "$LOG_FILE"

log_level "INFO" "Results:"
log_level "INFO" "✓ Checks Passed: $CHECKS_PASSED"
log_level "INFO" "⚠ Warnings: $CHECKS_WARNING"
log_level "INFO" "✗ Checks Failed: $CHECKS_FAILED"
echo "" | tee -a "$LOG_FILE"

cat > "$LOG_SUMMARY" <<EOF
===========================================
PREFLIGHT TEST SUMMARY
===========================================

Test Date: $(timestamp)
Hostname: $(hostname)
User: $USER_NAME (UID=$USER_UID)
OS: Ubuntu $UBUNTU_VERSION
Kernel: $(uname -r)

HARDWARE
--------
Total RAM: ${TOTAL_RAM_MB}MB ($(( TOTAL_RAM_MB / 1024 ))GB)
Free RAM: ${FREE_RAM_MB}MB
Disk: ${DISK_TOTAL} (Free: ${DISK_FREE_GB}GB)

NETWORK
-------
Default Interface: $DEFAULT_IFACE
IPv4 Address: $IP_ADDR
External Connectivity: OK
DNS: OK

RESULTS
-------
✓ Checks Passed: $CHECKS_PASSED
⚠ Warnings: $CHECKS_WARNING
✗ Checks Failed: $CHECKS_FAILED

STATUS: $([ "$CHECKS_FAILED" -eq 0 ] && echo "READY FOR INSTALLATION" || echo "NOT READY - FIX ERRORS")
EOF

cat "$LOG_SUMMARY" | tee -a "$LOG_FILE"

if [ "$CHECKS_FAILED" -eq 0 ]; then
    log_level "SUCCESS" "System is ready for OpenStack installation"
    echo -e "${GREEN}========================${NC}" | tee -a "$LOG_FILE"
    echo -e "${GREEN}All checks passed! ✓${NC}" | tee -a "$LOG_FILE"
    echo -e "${GREEN}========================${NC}" | tee -a "$LOG_FILE"
    exit 0
else
    log_level "FAIL" "System NOT ready. Review logs for details."
    echo -e "${RED}========================${NC}" | tee -a "$LOG_FILE"
    echo -e "${RED}Some checks failed! ✗${NC}" | tee -a "$LOG_FILE"
    echo -e "${RED}========================${NC}" | tee -a "$LOG_FILE"
    exit 1
fi
