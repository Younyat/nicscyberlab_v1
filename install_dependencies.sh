#!/usr/bin/env bash
set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

log_info() { echo -e "${GREEN}[INFO]${NC} $*"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $*"; }
log_error() { echo -e "${RED}[ERROR]${NC} $*"; exit 1; }

echo "==========================================="
echo " nicscyberlab Dependency Installer"
echo "==========================================="
echo

# Detect OS
if [[ -f /etc/os-release ]]; then
    . /etc/os-release
    OS=$ID
else
    log_error "Cannot detect OS"
fi

if [[ "$OS" != "ubuntu" && "$OS" != "debian" ]]; then
    log_warn "This script is optimized for Ubuntu/Debian. Your OS is: $OS"
fi

log_info "Detected OS: $OS"

# Update package manager
log_info "Updating package manager..."
sudo apt-get update -qq || log_error "Failed to update package manager"

# Option to use Docker official repository for up-to-date docker packages
USE_DOCKER_OFFICIAL=false
if [[ "${1:-}" == "--docker-official" ]]; then
    USE_DOCKER_OFFICIAL=true
fi

# System dependencies
log_info "Installing system dependencies..."
SYS_DEPS=(
    "python3"
    "python3-pip"
    "python3-venv"
    "curl"
    "wget"
    "git"
    "jq"
    "python3-flask"
    "python3-gunicorn"
    "openssh-client"
    "openssh-server"
)

# Extra common build/runtime dependencies useful on Ubuntu 22.04 / 24.04
EXTRA_DEPS=(
    "build-essential"
    "gcc"
    "make"
    "python3-dev"
    "libssl-dev"
    "libffi-dev"
    "libpq-dev"
    "docker.io"
    "docker-compose-plugin"
)

for dep in "${SYS_DEPS[@]}"; do
    if dpkg -l | grep -q "^ii  $dep"; then
        log_info "✓ $dep already installed"
    else
        log_info "Installing $dep..."
        sudo apt-get install -y -qq "$dep" || log_error "Failed to install $dep"
    fi
done

for dep in "${EXTRA_DEPS[@]}"; do
    if dpkg -l | grep -q "^ii  $dep"; then
        log_info "✓ $dep already installed"
    else
        log_info "Installing $dep..."
        sudo apt-get install -y -qq "$dep" || log_error "Failed to install $dep"
    fi
done

if $USE_DOCKER_OFFICIAL; then
        log_info "Configuring Docker official repository (to get latest Docker Engine)..."
        sudo apt-get remove -y docker docker-engine docker.io containerd runc || true
        sudo apt-get update -qq
        sudo apt-get install -y -qq ca-certificates curl gnupg lsb-release
        curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
        echo \
            "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu \$(lsb_release -cs) stable" \
            | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
        sudo apt-get update -qq
        sudo apt-get install -y -qq docker-ce docker-ce-cli containerd.io docker-compose-plugin || log_warn "docker-ce install failed; fallback may be needed"
        log_info "Docker official repo installed (docker-ce/docker-compose-plugin)."
fi

log_info "System dependencies installed successfully"
echo

# Python dependencies from requirements.txt
REQUIREMENTS_FILE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)/requirements.txt"

if [[ ! -f "$REQUIREMENTS_FILE" ]]; then
    log_error "requirements.txt not found at $REQUIREMENTS_FILE"
fi

log_info "Installing Python dependencies from $REQUIREMENTS_FILE..."

VENV_DIR="$PWD/.venv"

# Create and use a virtual environment by default
if [[ "$1" != "--system" ]]; then
    if [[ ! -d "$VENV_DIR" ]]; then
        log_info "Creating Python virtual environment at $VENV_DIR"
        python3 -m venv "$VENV_DIR" || log_error "Failed to create virtualenv"
    fi
    # Activate venv for this script's execution
    # shellcheck source=/dev/null
    source "$VENV_DIR/bin/activate"
    log_info "Using virtualenv: $VENV_DIR"
    pip install --upgrade pip setuptools wheel
    pip install -r "$REQUIREMENTS_FILE" || log_error "Failed to install Python dependencies in virtualenv"
else
    # system-wide install (use with caution)
    if command -v pip3 >/dev/null 2>&1; then
        log_info "Using system pip3 (system-wide install)..."
        pip3 install --break-system-packages -r "$REQUIREMENTS_FILE" 2>/dev/null || pip3 install -r "$REQUIREMENTS_FILE" || log_error "Failed to install Python dependencies system-wide"
    else
        log_error "pip3 not found. Please install python3-pip first."
    fi
fi

log_info "Python dependencies installed successfully"
echo

# Verify critical commands
log_info "Verifying critical commands..."
CRITICAL_CMDS=("python3" "curl" "jq" "bash" "git")
for cmd in "${CRITICAL_CMDS[@]}"; do
    if command -v "$cmd" >/dev/null 2>&1; then
        log_info "✓ $cmd is available"
    else
        log_warn "⚠ $cmd not found - some features may not work"
    fi
done

echo
log_info "Installation complete!"
echo
echo "To run tests:"
echo "  bash run_tests.sh"
echo
echo "To start the dashboard:"
echo "  bash start_dashboard.sh"
echo
