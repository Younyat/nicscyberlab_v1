#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/log_utils.sh"

log "Instalando dependencias del sistema"

sudo apt update -y
sudo apt install -y \
    python3.12 python3.12-venv python3.12-dev \
    git iptables bridge-utils wget curl dbus pkg-config \
    build-essential libdbus-1-dev libglib2.0-dev \
    apt-transport-https ca-certificates gnupg software-properties-common

log "Dependencias del sistema instaladas correctamente"
