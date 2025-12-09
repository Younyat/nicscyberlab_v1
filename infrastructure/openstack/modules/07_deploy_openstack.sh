#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/log_utils.sh"

VENV_PATH="${VENV_PATH:-$HOME/openstack_venv}"

log "Iniciando despliegue de OpenStack con Kolla-Ansible"

# shellcheck source=/dev/null
source "$VENV_PATH/bin/activate"

INVENTORY="/etc/kolla/ansible/inventory/all-in-one"

if [ ! -f "$INVENTORY" ]; then
    log "Inventario all-in-one no encontrado en $INVENTORY, intentando copiar desde ejemplos"
    EXAMPLES_DIR="$VENV_PATH/share/kolla-ansible/ansible/inventory"
    sudo mkdir -p /etc/kolla/ansible/inventory
    sudo cp "$EXAMPLES_DIR/all-in-one" "$INVENTORY"
    sudo chown -R "$USER:$USER" /etc/kolla
    log "Inventario all-in-one copiado"
fi

log "Ejecutando bootstrap-servers"
kolla-ansible bootstrap-servers -i "$INVENTORY" | tee -a "$LOG_FILE"

log "Ejecutando prechecks"
kolla-ansible prechecks -i "$INVENTORY" | tee -a "$LOG_FILE"

log "Ejecutando deploy"
kolla-ansible deploy -i "$INVENTORY" | tee -a "$LOG_FILE"

log "Ejecutando post-deploy"
kolla-ansible post-deploy -i "$INVENTORY" | tee -a "$LOG_FILE"

log "Despliegue de OpenStack completado"

if [ -f /etc/kolla/admin-openrc.sh ]; then
    log "Archivo /etc/kolla/admin-openrc.sh generado correctamente"
else
    log "Advertencia: /etc/kolla/admin-openrc.sh no encontrado. Revisa los logs."
fi
