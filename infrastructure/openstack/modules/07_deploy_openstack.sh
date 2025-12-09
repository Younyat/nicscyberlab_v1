#!/bin/bash   
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BASE_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
source "$SCRIPT_DIR/log_utils.sh"

VENV_PATH="${VENV_PATH:-$HOME/openstack_venv}"
CONFIG_DIR="/etc/kolla"
INVENTORY="/etc/kolla/ansible/inventory/all-in-one"
EXAMPLES_DIR="$VENV_PATH/share/kolla-ansible"

log "=== Iniciando configuración + despliegue de OpenStack con Kolla-Ansible ==="

# -------------------------------------------------------------
# 1. Activar virtualenv
# -------------------------------------------------------------
log "Activando entorno virtual: $VENV_PATH"
source "$VENV_PATH/bin/activate"

# -------------------------------------------------------------
# 2. Preparar /etc/kolla sin sobrescribir configuraciones existentes
# -------------------------------------------------------------
sudo mkdir -p "$CONFIG_DIR"
sudo chown "$USER:$USER" "$CONFIG_DIR"

if [ ! -f "$CONFIG_DIR/globals.yml" ] || [ ! -f "$CONFIG_DIR/passwords.yml" ]; then
    log "Copiando globals.yml y passwords.yml por primera vez"
    cp -r "$EXAMPLES_DIR/etc_examples/kolla/"* "$CONFIG_DIR"
else
    log "globals.yml y passwords.yml ya existen. No se sobrescriben."
fi

# -------------------------------------------------------------
# 3. Generar passwords solo si es necesario
# -------------------------------------------------------------
log "Verificando passwords..."
if grep -q "CHANGE ME" "$CONFIG_DIR/passwords.yml"; then
    log "Generando nuevas contraseñas con kolla-genpwd"
    kolla-genpwd
else
    log "passwords.yml ya contiene contraseñas válidas"
fi

# -------------------------------------------------------------
# 4. Detectar interfaz y calcular VIP
# -------------------------------------------------------------
log "Detectando interfaz principal y generando VIP"

MAIN_IFACE=$(ip route | awk '/default/ {print $5; exit}')
MAIN_IP=$(ip -4 addr show "$MAIN_IFACE" | awk '/inet / {print $2}' | cut -d/ -f1)
SUBNET_BASE=$(echo "$MAIN_IP" | cut -d. -f1-3)

VIP=""
for i in $(seq 200 250); do
    CANDIDATE="$SUBNET_BASE.$i"
    if ! ping -c 1 -W 1 "$CANDIDATE" >/dev/null 2>&1; then
        VIP="$CANDIDATE"
        break
    fi
done

if [ -z "$VIP" ]; then
    log "ERROR: No se encontró una IP libre para VIP"
    exit 1
fi

log "Interfaz principal detectada: $MAIN_IFACE"
log "IP principal:                $MAIN_IP"
log "VIP seleccionado:            $VIP"

# -------------------------------------------------------------
# 5. Generar globals.yml desde plantilla limpia
# -------------------------------------------------------------
log "Generando archivo globals.yml final"

sudo tee "$CONFIG_DIR/globals.yml" >/dev/null <<EOF
---
kolla_base_distro: "ubuntu"
openstack_release: "master"

network_interface: "$MAIN_IFACE"
neutron_external_interface: "$MAIN_IFACE"

kolla_internal_vip_address: "$VIP"

enable_haproxy: "yes"
enable_keepalived: "yes"
EOF

sudo chown "$USER:$USER" "$CONFIG_DIR/globals.yml"

log "globals.yml configurado correctamente"

# -------------------------------------------------------------
# 6. Preparar inventario AIO
# -------------------------------------------------------------
if [ ! -f "$INVENTORY" ]; then
    log "Creando inventario all-in-one"
    sudo mkdir -p /etc/kolla/ansible/inventory
    sudo cp "$EXAMPLES_DIR/ansible/inventory/all-in-one" "$INVENTORY"
    sudo chown -R "$USER:$USER" /etc/kolla
else
    log "Inventario ya existe: no se sobrescribe"
fi

# -------------------------------------------------------------
# 7. Instalar dependencias Galaxy
# -------------------------------------------------------------
log "Instalando dependencias Galaxy"
kolla-ansible install-deps | tee -a "$LOG_FILE"

# -------------------------------------------------------------
# 8. Bootstrap servers
# -------------------------------------------------------------
log "Ejecutando bootstrap-servers"
kolla-ansible bootstrap-servers -i "$INVENTORY" | tee -a "$LOG_FILE"

# -------------------------------------------------------------
# 9. Prechecks
# -------------------------------------------------------------
log "Ejecutando prechecks"
kolla-ansible prechecks -i "$INVENTORY" | tee -a "$LOG_FILE"

# -------------------------------------------------------------
# 10. Deploy
# -------------------------------------------------------------
log "Ejecutando deploy"
kolla-ansible deploy -i "$INVENTORY" | tee -a "$LOG_FILE"

# -------------------------------------------------------------
# 11. Post-deploy
# -------------------------------------------------------------
log "Ejecutando post-deploy"
kolla-ansible post-deploy -i "$INVENTORY" | tee -a "$LOG_FILE"

# -------------------------------------------------------------
# 12. Validación final
# -------------------------------------------------------------
log "=== Despliegue de OpenStack completado ==="

if [ -f /etc/kolla/admin-openrc.sh ]; then
    log "✔ admin-openrc.sh generado correctamente"
else
    log "⚠ ERROR: no se generó admin-openrc.sh"
fi

