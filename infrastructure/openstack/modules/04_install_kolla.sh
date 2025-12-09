#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BASE_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

source "$SCRIPT_DIR/log_utils.sh"

VENV_PATH="${VENV_PATH:-$HOME/openstack_venv}"
REQ_FILE="$BASE_DIR/configs/requirements-kolla.txt"

log "Instalando dependencias Python para Kolla-Ansible desde $REQ_FILE"

# shellcheck source=/dev/null
source "$VENV_PATH/bin/activate"

pip install --upgrade pip
pip install -r "$REQ_FILE" --no-cache-dir

log "Dependencias Python y Kolla-Ansible instaladas correctamente"
