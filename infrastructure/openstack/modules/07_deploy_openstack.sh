#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/log_utils.sh"

VENV_PATH="${VENV_PATH:-$HOME/openstack_venv}"
CONFIG_DIR="/etc/kolla"
INVENTORY="/etc/kolla/ansible/inventory/all-in-one"

log "=== Iniciando despliegue de OpenStack con Kolla-Ansible ==="

if [ ! -f "$CONFIG_DIR/globals.yml" ] || [ ! -f "$CONFIG_DIR/passwords.yml" ]; then
    log "ERROR: /etc/kolla no está configurado. Ejecuta 05_configure_kolla.sh primero."
    exit 1
fi

if [ ! -f "$INVENTORY" ]; then
    log "ERROR: Inventario $INVENTORY inexistente. Revisa el módulo de configuración."
    exit 1
fi

log "Activando entorno virtual: $VENV_PATH"
# shellcheck source=/dev/null
source "$VENV_PATH/bin/activate"

log "Instalando dependencias Galaxy (kolla-ansible install-deps)"
kolla-ansible install-deps | tee -a "$LOG_FILE"

log "Ejecutando bootstrap-servers"
kolla-ansible bootstrap-servers -i "$INVENTORY" | tee -a "$LOG_FILE"

log "Ejecutando prechecks"
kolla-ansible prechecks -i "$INVENTORY" | tee -a "$LOG_FILE"

# ====================================================================
# CAMBIO CLAVE: AÑADIR -vvv para logs detallados (verbose)
# Esto es crucial para ver el traceback de Python del error JSON.
# ====================================================================
log "Ejecutando deploy con logs detallados (-vvv)"
kolla-ansible deploy -i "$INVENTORY" -vvv | tee -a "$LOG_FILE" 

log "Ejecutando post-deploy"
kolla-ansible post-deploy -i "$INVENTORY" | tee -a "$LOG_FILE"

if [ -f /etc/kolla/admin-openrc.sh ]; then
   log "✔ admin-openrc.sh generado correctamente"
else
   log "⚠ admin-openrc.sh no se encontró. Revisa los logs de post-deploy."
fi

log "=== Despliegue de OpenStack completado ==="