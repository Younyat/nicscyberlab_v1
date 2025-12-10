#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/log_utils.sh"

log "Instalando dependencias base requeridas por Kolla-Ansible (según Quick-Start)"

sudo apt update -y
sudo apt install -y \
    git \
    python3 python3-venv python3-dev python3-pip \
    libffi-dev gcc libssl-dev pkg-config \
    libdbus-1-dev build-essential cmake libglib2.0-dev \
    mariadb-server \
    bridge-utils iptables iproute2 \
    curl ca-certificates gnupg software-properties-common

log "Dependencias del sistema instaladas correctamente"
