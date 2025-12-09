#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/log_utils.sh"

log "Configurando repositorio de Docker"

sudo rm -f /etc/apt/sources.list.d/docker.list
sudo mkdir -p /usr/share/keyrings

curl -fsSL https://download.docker.com/linux/ubuntu/gpg | \
  sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg

ARCH=$(dpkg --print-architecture)
DISTRO=$(lsb_release -cs)

echo "deb [arch=$ARCH signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $DISTRO stable" | \
  sudo tee /etc/apt/sources.list.d/docker.list >/dev/null

sudo apt update -y
sudo apt install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin

log "Docker instalado. Habilitando servicio y agregando usuario al grupo docker"

sudo systemctl enable docker --now
sudo usermod -aG docker "$USER"


