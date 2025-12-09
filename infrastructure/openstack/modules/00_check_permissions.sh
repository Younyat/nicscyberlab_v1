#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/log_utils.sh"

log "Iniciando comprobación de permisos"

check_not_root

if ! sudo -v >/dev/null 2>&1; then
    log "ERROR: El usuario no tiene permisos sudo o requiere contraseña y no se puede validar."
    exit 1
fi

log "Permisos sudo verificados correctamente"
