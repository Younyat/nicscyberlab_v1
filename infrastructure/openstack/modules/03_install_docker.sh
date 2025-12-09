#!/bin/bash
set -euo pipefail


log() {
    echo "[DOCKER-REPO] $1"
}

log "=== LIMPIANDO REPOSITORIOS Y CLAVES ANTIGUAS DE DOCKER ==="

# ------------------------------------------------------------
# 1. ELIMINAR ARCHIVOS .sources Y .list ANTIGUOS
# ------------------------------------------------------------
log "Eliminando archivos antiguos en /etc/apt/sources.list.d/"
sudo rm -f /etc/apt/sources.list.d/docker.sources \
           /etc/apt/sources.list.d/docker.list \
           /etc/apt/sources.list.d/docker*.list || true

# ------------------------------------------------------------
# 2. ELIMINAR KEYRINGS ANTIGUOS
# ------------------------------------------------------------
log "Eliminando keyrings antiguos"
sudo rm -f /usr/share/keyrings/docker-archive-keyring.gpg \
           /etc/apt/keyrings/docker.asc \
           /etc/apt/keyrings/docker.gpg || true

# ------------------------------------------------------------
# 3. CREAR NUEVO DIRECTORIO DE KEYRINGS
# ------------------------------------------------------------
log "Creando directorio de keyrings"
sudo mkdir -p /etc/apt/keyrings

# ------------------------------------------------------------
# 4. DESCARGAR Y GENERAR LA CLAVE OFICIAL DE DOCKER
# ------------------------------------------------------------
log "Descargando clave GPG oficial de Docker"
curl -fsSL https://download.docker.com/linux/ubuntu/gpg \
    | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg

sudo chmod a+r /etc/apt/keyrings/docker.gpg

# infrastructure/openstack/modules/03_install_docker.sh------------------------------------------------------------
# 5. AÑADIR EL REPOSITORIO OFICIAL DE DOCKER
# ------------------------------------------------------------
log "Creando archivo /etc/apt/sources.list.d/docker.list"

ARCH=$(dpkg --print-architecture)
CODENAME=$( . /etc/os-release && echo $VERSION_CODENAME )

echo "deb [arch=${ARCH} signed-by=/etc/apt/keyrings/docker.gpg] \
https://download.docker.com/linux/ubuntu ${CODENAME} stable" \
| sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

# ------------------------------------------------------------
# 6. ACTUALIZAR ÍNDICES DE APT
# ------------------------------------------------------------
log "Ejecutando apt update"
sudo apt update -y

log "=== CONFIGURACIÓN DEL REPO DOCKER COMPLETADA SIN ERRORES ==="



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



