#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MODULES_DIR="$SCRIPT_DIR/modules"

# Exportamos VENV_PATH para que todos los módulos usen la misma ruta
export VENV_PATH="${VENV_PATH:-$HOME/openstack_venv}"

# 1. Utilidades de log y permisos
bash "$MODULES_DIR/00_check_permissions.sh"

# 2. Dependencias del sistema
bash "$MODULES_DIR/01_install_system_dependencies.sh"

# 3. Docker
bash "$MODULES_DIR/03_install_docker.sh"

# 4. Entorno virtual Python
bash "$MODULES_DIR/02_setup_python_venv.sh"

# 5. Instalar Kolla-Ansible y dependencias Python
bash "$MODULES_DIR/04_install_kolla.sh"

# 6. Configurar Kolla (configs base, passwords, globals)
bash "$MODULES_DIR/05_configure_kolla.sh"

# 7. Configurar red (veth, bridge, NAT)
bash "$MODULES_DIR/06_setup_networking.sh"

# 8. Desplegar OpenStack
bash "$MODULES_DIR/07_deploy_openstack.sh"
