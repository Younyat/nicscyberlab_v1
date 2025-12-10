#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/log_utils.sh"

if [[ "${SKIP_INIT_RUNONCE:-false}" == "true" ]]; then
    log "SKIP_INIT_RUNONCE=true -> se omite la creación de recursos demo."
    exit 0
fi

VENV_PATH="${VENV_PATH:-$HOME/openstack_venv}"
OPENRC="/etc/kolla/admin-openrc.sh"
INIT_RUNONCE="$VENV_PATH/share/kolla-ansible/init-runonce"
FLAG_FILE="$LOG_DIR/init_runonce.done"

log "Ejecutando tareas post-deploy recomendadas (python-openstackclient + init-runonce)"

if [ -f "$FLAG_FILE" ]; then
    log "init-runonce ya se ejecutó anteriormente (flag: $FLAG_FILE)"
    exit 0
fi

if [ ! -f "$OPENRC" ]; then
    log "ERROR: $OPENRC no existe; no se puede ejecutar init-runonce."
    exit 1
fi

# shellcheck source=/dev/null
source "$VENV_PATH/bin/activate"

if ! pip show python-openstackclient >/dev/null 2>&1; then
    log "Instalando python-openstackclient dentro del entorno virtual"
    pip install python-openstackclient
else
    log "python-openstackclient ya está instalado"
fi

log "Cargando credenciales de admin-openrc"
# shellcheck source=/dev/null
source "$OPENRC"

if [ ! -x "$INIT_RUNONCE" ]; then
    log "ERROR: Script init-runonce no encontrado en $INIT_RUNONCE"
    exit 1
fi

log "Lanzando init-runonce (creación de recursos demo)"
"$INIT_RUNONCE" | tee -a "$LOG_FILE"

touch "$FLAG_FILE"
log "init-runonce completado. Flag registrado en $FLAG_FILE"
