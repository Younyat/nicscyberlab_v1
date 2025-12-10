#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/log_utils.sh"

VENV_PATH="${VENV_PATH:-$HOME/openstack_venv}"

log "Creando entorno virtual en $VENV_PATH"

python3 -m venv "$VENV_PATH"
# shellcheck source=/dev/null
source "$VENV_PATH/bin/activate"

python -m ensurepip --upgrade
python -m pip install --upgrade pip setuptools wheel

log "Entorno virtual activado: $(which python)"
