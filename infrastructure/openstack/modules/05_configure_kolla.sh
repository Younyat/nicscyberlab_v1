#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BASE_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

source "$SCRIPT_DIR/log_utils.sh"

VENV_PATH="${VENV_PATH:-$HOME/openstack_venv}"
CONFIG_DIR="/etc/kolla"
INVENTORY="/etc/kolla/ansible/inventory/all-in-one"
EXAMPLES_DIR="$VENV_PATH/share/kolla-ansible"
TEMPLATE_GLOBALS="$BASE_DIR/configs/globals.yml.template"

log "Configurando Kolla-Ansible en $CONFIG_DIR"

# shellcheck source=/dev/null
source "$VENV_PATH/bin/activate"

sudo mkdir -p "$CONFIG_DIR"
sudo cp -rn "$EXAMPLES_DIR/etc_examples/kolla/." "$CONFIG_DIR/"
sudo chown -R "$USER:$USER" "$CONFIG_DIR"

log "Asegurando inventario all-in-one en $INVENTORY"
sudo mkdir -p "$(dirname "$INVENTORY")"
if [ ! -f "$INVENTORY" ]; then
    sudo cp "$EXAMPLES_DIR/ansible/inventory/all-in-one" "$INVENTORY"
    sudo chown -R "$USER:$USER" /etc/kolla
else
    log "Inventario existente detectado; no se sobrescribe"
fi

log "Ejecutando kolla-genpwd para garantizar contraseñas completas"
kolla-genpwd

MGMT_INTERFACE=${MGMT_INTERFACE:-$(ip route | awk '/default/ {print $5; exit}')}
if [ -z "$MGMT_INTERFACE" ]; then
    log "ERROR: No fue posible detectar la interfaz de red principal."
    exit 1
fi

if ! ip link show "$MGMT_INTERFACE" >/dev/null 2>&1; then
    log "ERROR: La interfaz $MGMT_INTERFACE no existe."
    exit 1
fi

if [ -n "${NEUTRON_EXTERNAL_INTERFACE:-}" ]; then
    EXTERNAL_INTERFACE="$NEUTRON_EXTERNAL_INTERFACE"
elif ip link show veth1 >/dev/null 2>&1; then
    EXTERNAL_INTERFACE="veth1"
else
    EXTERNAL_INTERFACE="$MGMT_INTERFACE"
    log "ADVERTENCIA: No se detectó interfaz externa; se usará $EXTERNAL_INTERFACE. Exporta NEUTRON_EXTERNAL_INTERFACE si necesitas una interfaz diferente."
fi

OPENSTACK_RELEASE=${OPENSTACK_RELEASE:-"master"}
NOVA_COMPUTE_VIRT_TYPE=${NOVA_COMPUTE_VIRT_TYPE:-"qemu"}

MAIN_IP=$(ip -4 addr show "$MGMT_INTERFACE" | awk '/inet / {print $2}' | head -n1 | cut -d/ -f1)
if [ -z "$MAIN_IP" ]; then
    log "ERROR: No se pudo obtener una IP v4 para $MGMT_INTERFACE."
    exit 1
fi

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
    log "ERROR: No se encontró una IP libre en ${SUBNET_BASE}.200-250 para usar como VIP."
    exit 1
fi

log "Interfaz management: $MGMT_INTERFACE"
log "Interfaz externa:    $EXTERNAL_INTERFACE"
log "VIP seleccionada:    $VIP"
if [ "$MGMT_INTERFACE" = "$EXTERNAL_INTERFACE" ]; then
    log "ADVERTENCIA: network_interface y neutron_external_interface son iguales. Considera proporcionar una interfaz externa dedicada (variable NEUTRON_EXTERNAL_INTERFACE) como indica la guía de Kolla."
fi

if [ ! -f "$TEMPLATE_GLOBALS" ]; then
    log "ERROR: Plantilla $TEMPLATE_GLOBALS no encontrada."
    exit 1
fi

TMP_FILE=$(mktemp)
sed -e "s/{{ MAIN_IFACE }}/$MGMT_INTERFACE/g" \
    -e "s/{{ NEUTRON_EXTERNAL_INTERFACE }}/$EXTERNAL_INTERFACE/g" \
    -e "s/{{ VIP }}/$VIP/g" \
    -e "s/{{ OPENSTACK_RELEASE }}/$OPENSTACK_RELEASE/g" \
    -e "s/{{ NOVA_COMPUTE_VIRT_TYPE }}/$NOVA_COMPUTE_VIRT_TYPE/g" \
    "$TEMPLATE_GLOBALS" > "$TMP_FILE"

sudo mv "$TMP_FILE" "$CONFIG_DIR/globals.yml"
sudo chown "$USER:$USER" "$CONFIG_DIR/globals.yml"

log "Archivo globals.yml generado a partir de la plantilla oficial"
