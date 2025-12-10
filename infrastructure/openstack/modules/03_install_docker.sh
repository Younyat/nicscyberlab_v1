#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/log_utils.sh"

log "Configurando repositorio oficial de Docker (limpieza previa + instalación limpia)"

# Limpieza de posibles restos de repos anteriores
sudo rm -f /etc/apt/sources.list.d/docker.sources \
            /etc/apt/sources.list.d/docker.list \
            /etc/apt/sources.list.d/docker*.list || true
sudo rm -f /usr/share/keyrings/docker-archive-keyring.gpg \
            /etc/apt/keyrings/docker.asc \
            /etc/apt/keyrings/docker.gpg || true

sudo mkdir -p /etc/apt/keyrings

log "Descargando clave GPG oficial de Docker"
curl -fsSL https://download.docker.com/linux/ubuntu/gpg \
  | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
sudo chmod a+r /etc/apt/keyrings/docker.gpg

ARCH=$(dpkg --print-architecture)
CODENAME=$(. /etc/os-release && echo "$VERSION_CODENAME")

log "Registrando el repositorio estable de Docker para ${CODENAME} (${ARCH})"
echo "deb [arch=${ARCH} signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu ${CODENAME} stable" \
  | sudo tee /etc/apt/sources.list.d/docker.list >/dev/null

log "Instalando Docker Engine y runtime soportado por Kolla"
sudo apt update -y
sudo apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

log "Habilitando servicio docker y añadiendo usuario actual al grupo docker"
sudo systemctl enable --now docker
if id -nG "$USER" | grep -qw docker; then
  log "El usuario $(whoami) ya pertenece al grupo docker"
else
  sudo usermod -aG docker "$USER"
  log "Usuario añadido al grupo docker (es necesario un nuevo login para aplicar el cambio)"
fi

log "Instalación de Docker completada"
