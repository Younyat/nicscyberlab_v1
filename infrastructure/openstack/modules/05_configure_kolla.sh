#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BASE_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

source "$SCRIPT_DIR/log_utils.sh"

VENV_PATH="${VENV_PATH:-$HOME/openstack_venv}"
CONFIG_DIR="/etc/kolla"
TEMPLATE_GLOBALS="$BASE_DIR/configs/globals.yml.template"

log "Configurando Kolla en $CONFIG_DIR"

# shellcheck source=/dev/null
source "$VENV_PATH/bin/activate"

sudo mkdir -p "$CONFIG_DIR"
sudo cp -r "$VENV_PATH/share/kolla-ansible/etc_examples/kolla/"* "$CONFIG_DIR"

sudo chown -R "$USER:$USER" "$CONFIG_DIR"

log "Generando passwords de Kolla"

kolla-genpwd

log "Detectando interfaz principal y subnet para VIP"

MAIN_IFACE=$(ip route | awk '/default/ {print $5; exit}')
MAIN_IP=$(ip -4 addr show "$MAIN_IFACE" | awk '/inet / {print $2}' | cut -d/ -f1)
SUBNET_BASE=$(echo "$MAIN_IP" | cut -d. -f1-3)

VIP=""
for i in $(seq 10 50); do
    IP="$SUBNET_BASE.$i"
    if ! ping -c 1 -W 1 "$IP" >/dev/null 2>&1; then
        VIP="$IP"
        break
    fi
done

if [ -z "$VIP" ]; then
    log "ERROR: No se encontró IP libre para VIP en rango $SUBNET_BASE.10-50"
    exit 1
fi

log "Interfaz principal: $MAIN_IFACE"
log "IP principal:       $MAIN_IP"
log "VIP seleccionada:   $VIP"

log "Generando /etc/kolla/globals.yml desde plantilla"

sudo tee "$CONFIG_DIR/globals.yml" >/dev/null <<EOF
kolla_base_distro: "ubuntu"
network_interface: "$MAIN_IFACE"
neutron_external_interface: "veth1"
kolla_internal_vip_address: "$VIP"
EOF

sudo chown "$USER:$USER" "$CONFIG_DIR/globals.yml"

log "Archivo globals.yml configurado correctamente"
