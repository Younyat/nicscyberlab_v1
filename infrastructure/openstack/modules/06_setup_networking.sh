#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/log_utils.sh"

log "Configurando red virtual para OpenStack (veth + uplinkbridge)"

EXTERNAL_IFACE=$(ip route | awk '/default/ {print $5; exit}')
log "Interfaz externa detectada: $EXTERNAL_IFACE"

# Crear veth solo si no existe
if ! ip link show veth0 >/dev/null 2>&1; then
    sudo ip link add veth0 type veth peer name veth1
    log "Interfaz veth0/veth1 creada"
else
    log "veth0/veth1 ya existen, no se recrean"
fi

sudo ip link set dev veth0 up
sudo ip link set dev veth1 up

# Crear puente uplinkbridge solo si no existe
if ! ip link show uplinkbridge >/dev/null 2>&1; then
    sudo brctl addbr uplinkbridge
    log "Bridge uplinkbridge creado"
else
    log "Bridge uplinkbridge ya existe"
fi

sudo brctl addif uplinkbridge veth0 2>/dev/null || true
sudo ip link set dev uplinkbridge up

# Asignar IP al puente si no la tiene
if ! ip addr show uplinkbridge | grep -q "10.0.2.1/24"; then
    sudo ip addr add 10.0.2.1/24 dev uplinkbridge
    log "IP 10.0.2.1/24 asignada a uplinkbridge"
else
    log "IP 10.0.2.1/24 ya estaba asignada a uplinkbridge"
fi

# Habilitar IP forwarding
sudo sysctl -w net.ipv4.ip_forward=1 >/dev/null
if ! grep -q "^net.ipv4.ip_forward=1" /etc/sysctl.conf; then
    echo "net.ipv4.ip_forward=1" | sudo tee -a /etc/sysctl.conf >/dev/null
fi
sudo sysctl -p >/dev/null

# Reglas NAT idempotentes
NAT_RULE_EXISTS=$(sudo iptables -t nat -S POSTROUTING | grep -F "-s 10.0.2.0/24 -o $EXTERNAL_IFACE -j MASQUERADE" || true)
if [ -z "$NAT_RULE_EXISTS" ]; then
    sudo iptables -t nat -A POSTROUTING -s 10.0.2.0/24 -o "$EXTERNAL_IFACE" -j MASQUERADE
    log "Regla NAT añadida para 10.0.2.0/24 sobre $EXTERNAL_IFACE"
else
    log "Regla NAT ya existente para 10.0.2.0/24 sobre $EXTERNAL_IFACE"
fi

FORWARD_RULE_EXISTS=$(sudo iptables -S FORWARD | grep -F "-s 10.0.2.0/24 -j ACCEPT" || true)
if [ -z "$FORWARD_RULE_EXISTS" ]; then
    sudo iptables -A FORWARD -s 10.0.2.0/24 -j ACCEPT
    log "Regla FORWARD añadida para 10.0.2.0/24"
else
    log "Regla FORWARD ya existente para 10.0.2.0/24"
fi

log "Red uplinkbridge + veth configurada correctamente"
