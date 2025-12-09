# OpenStack Installation Framework

> Framework profesional e idempotente para despliegue de OpenStack con Kolla-Ansible en Ubuntu LTS

## 📋 Tabla de Contenidos

- [Descripción General](#descripción-general)
- [Requisitos Previos](#requisitos-previos)
- [Estructura del Proyecto](#estructura-del-proyecto)
- [Preflight Testing](#preflight-testing)
- [Testing Modular](#testing-modular)
- [Instalación Completa](#instalación-completa)
- [Troubleshooting](#troubleshooting)
- [Logs y Monitoreo](#logs-y-monitoreo)

---

## 🎯 Descripción General

Este framework automatiza la instalación y configuración de OpenStack usando **Kolla-Ansible** en sistemas Ubuntu 22.04 o 24.04 LTS.

### Características Principales

- [OK] **Idempotente**: Seguro ejecutar múltiples veces
- [OK] **Modular**: Cada paso es independiente y testeable
- [OK] **Preflight Checks**: Validación previa completa
- [OK] **Logging Profesional**: Trazabilidad completa en `logs/`
- [OK] **Minimalist**: Solo herramientas esenciales
- [OK] **Auto-detección**: Interfaces de red, VIPs, etc.

---

## 📦 Requisitos Previos

### Hardware Mínimo
- **RAM**: ≥ 6 GB
- **Disco**: ≥ 20 GB libres
- **CPU**: 2+ cores (recomendado 4+)

### Software
- **OS**: Ubuntu 22.04 LTS o 24.04 LTS
- **Conexión**: Internet activa + DNS operativo
- **Usuario**: No root, con privilegios sudo

### Dependencias de Sistema
Se instalan automáticamente:
- Python 3.12 + venv
- Docker CE
- Git, curl, wget
- build-essential, libssl-dev, libffi-dev

---

## 📁 Estructura del Proyecto

```
infrastructure/openstack/
├── install_openstack.sh              # Script principal orquestador
├── preflight/
│   └── preflight_openstack_tester.sh  # Validación previa
├── modules/
│   ├── log_utils.sh                   # Utilidades de logging
│   ├── 00_check_permissions.sh        # Validar permisos sudo
│   ├── 01_install_system_dependencies.sh  # Deps del sistema
│   ├── 02_setup_python_venv.sh        # Entorno virtual
│   ├── 03_install_docker.sh                # Docker
│   ├── 04_install_kolla.sh            # Kolla-Ansible
│   ├── 05_configure_kolla.sh          # Config Kolla + VIP
│   ├── 06_setup_networking.sh         # veth + bridge + NAT
│   └── 07_deploy_openstack.sh         # Despliegue final
├── configs/
│   ├── requirements-kolla.txt         # Deps Python
│   ├── globals.yml.template           # Template Kolla
│   └── network.yaml                   # Config de red (referencia)
└── logs/
    ├── preflight.log                  # Logs del preflight
    ├── install_openstack.log          # Logs de instalación
    └── *.log                          # Logs por fecha/hora
```

---

## 🧪 Preflight Testing

El preflight tester valida que el sistema está listo ANTES de instalar.

### Ejecución

```bash
cd infrastructure/openstack/preflight
bash preflight_openstack_tester.sh
```

### Validaciones Realizadas

| Validación | Descripción | Error si falla |
|---|---|---|
| **Usuario no root** | Script NO debe ser root | Exit code 1 |
| **Sudo válido** | Usuario tiene sudo sin interactivo | Exit code 1 |
| **Ubuntu LTS** | Solo 22.04 o 24.04 | Exit code 1 |
| **RAM mínima** | ≥ 6 GB | Exit code 1 |
| **Disco mínimo** | ≥ 20 GB libres | Exit code 1 |
| **Ping externo** | Conectividad a 8.8.8.8 | Exit code 1 |
| **DNS** | Resolución de google.com | Exit code 1 |
| **Interfaz de red** | Interfaz default + IPv4 | Exit code 1 |
| **Python 3.12** | Check (WARNING si no está) | Warning |
| **Docker** | Detectar conflictos | Warning |
| **Kolla previo** | Detectar `/etc/kolla` | Warning |
| **Virtualenv previo** | Detectar `$HOME/openstack_venv` | Warning |

### Salida Esperada (Éxito)

```
[2025-12-06 14:30:15] === OpenStack Preflight Tester Started ===
[2025-12-06 14:30:15] Checking executor identity
[2025-12-06 14:30:15] User: usuario (UID=1000)
[2025-12-06 14:30:15] Groups: usuario adm sudo docker
[2025-12-06 14:30:15] Sudo permissions OK
[2025-12-06 14:30:15] Checking OS version
[2025-12-06 14:30:15] Detected Ubuntu version: 22.04
[2025-12-06 14:30:15] Ubuntu version OK
...
[2025-12-06 14:30:20] All preflight checks passed successfully
[2025-12-06 14:30:20] System is ready for OpenStack installation
```

---

## 🔧 Testing Modular

Cada módulo puede testearse de forma independiente.

### Módulo 00: Validar Permisos

```bash
bash infrastructure/openstack/modules/00_check_permissions.sh
```

**Valida:**
- Usuario no es root
- Sudo disponible sin contraseña interactiva

**Logs:** `infrastructure/openstack/logs/install_openstack.log`

---

### Módulo 01: Instalar Dependencias del Sistema

```bash
bash infrastructure/openstack/modules/01_install_system_dependencies.sh
```

**Instala:**
- `python3.12 python3.12-venv python3.12-dev`
- `git iptables bridge-utils wget curl dbus pkg-config`
- `build-essential libdbus-1-dev libglib2.0-dev`
- `apt-transport-https ca-certificates gnupg software-properties-common`

**Verificación post-instalación:**

```bash
# Python
python3.12 --version

# Git
git --version

# Build tools
gcc --version

# Bridge tools
brctl --version

# iptables
iptables --version
```

**Logs:** `infrastructure/openstack/logs/install_openstack.log`

---

### Módulo 02: Setup Python Virtualenv

```bash
export VENV_PATH="$HOME/openstack_venv"
bash infrastructure/openstack/modules/02_setup_python_venv.sh
```

**Crea:**
- Virtualenv en `$HOME/openstack_venv`
- Instala pip, setuptools, wheel actualizado

**Verificación post-instalación:**

```bash
# Activar venv
source "$HOME/openstack_venv/bin/activate"

# Verificar
which python
python --version

# Desactivar
deactivate
```

**Logs:** `infrastructure/openstack/logs/install_openstack.log`

---

### Modulo 03: Instalar Docker

```bash
bash infrastructure/openstack/modules/03_install_docker.sh
```

**Instala:**
- Docker CE + CLI + containerd + compose plugin

**Verificación post-instalación:**

```bash
# Docker
docker --version
docker ps
```

**Logs:** `infrastructure/openstack/logs/install_openstack.log`

---

### Módulo 04: Instalar Kolla-Ansible

```bash
export VENV_PATH="$HOME/openstack_venv"
bash infrastructure/openstack/modules/04_install_kolla.sh
```

**Instala desde `configs/requirements-kolla.txt`:**
- `ansible==11.5.0`
- `ansible-core==2.18.5`
- `kolla-ansible` (master branch)
- `openstacksdk==4.5.0`
- `python-openstackclient==8.0.0`
- `docker==7.1.0`
- `netaddr==1.3.0`

**Verificación post-instalación:**

```bash
source "$HOME/openstack_venv/bin/activate"

# Ansible
ansible --version

# Kolla
kolla-ansible --version
kolla-genpwd --version

# OpenStack CLI
openstack --version

# Docker Python SDK
python -c "import docker; print(docker.__version__)"
```

**Logs:** `infrastructure/openstack/logs/install_openstack.log`

---

### Módulo 05: Configurar Kolla

```bash
export VENV_PATH="$HOME/openstack_venv"
bash infrastructure/openstack/modules/05_configure_kolla.sh
```

**Realiza:**
- Copia configuración base desde Kolla a `/etc/kolla/`
- **Auto-genera** `passwords.yml` con credenciales seguras
- **Auto-detecta** interfaz principal y subnet
- **Auto-busca** VIP libre en rango x.x.x.10-50
- Genera `globals.yml` dinámicamente

**Verificación post-instalación:**

```bash
# Verificar directorios
ls -la /etc/kolla/

# Verificar passwords
cat /etc/kolla/passwords.yml | head -20

# Verificar globals.yml
cat /etc/kolla/globals.yml

# Verificar VIP detectada
grep "kolla_internal_vip_address" /etc/kolla/globals.yml
```

**Variables de entorno detectadas automáticamente:**

```bash
MAIN_IFACE: eth0 (o la interfaz default)
MAIN_IP:   192.168.1.100 (IP de la interfaz)
SUBNET_BASE: 192.168.1
VIP:       192.168.1.15 (primera IP libre)
```

**Logs:** `infrastructure/openstack/logs/install_openstack.log`

---

### Módulo 06: Configurar Networking (veth + bridge)

```bash
bash infrastructure/openstack/modules/06_setup_networking.sh
```

**Crea:**
- Par veth0/veth1 (virtual ethernet)
- Bridge `uplinkbridge`
- IP 10.0.2.1/24 en bridge
- Reglas NAT para tráfico externo
- IP forwarding en sysctl

**Arquitectura de Red:**

```
┌─────────────────────────────────────────┐
│         Host (Ubuntu)                   │
├─────────────────────────────────────────┤
│                                         │
│  eth0 (defecto) ──────┐                │
│                       │                 │
│  veth0 ──┐            │ Externo       │
│          ├─ uplinkbridge ──┘           │
│  veth1 ──┘     │                       │
│          10.0.2.1/24                  │
│                │                       │
│          ┌─────┴──────┐               │
│          │  NAT       │               │
│          │  FORWARD   │               │
│          └─────┬──────┘               │
│                │                       │
│         OpenStack containers         │
│                                       │
└─────────────────────────────────────────┘
```

**Verificación post-instalación:**

```bash
# Ver interfaces
ip link show | grep -E "veth|uplinkbridge"

# Ver IPs
ip addr show | grep -E "veth|uplinkbridge"

# Ver puente
brctl show

# Ver reglas NAT
sudo iptables -t nat -L POSTROUTING

# Ver reglas FORWARD
sudo iptables -L FORWARD

# Probar conectividad
sudo ip netns exec (si usas netns)
```

**Logs:** `infrastructure/openstack/logs/install_openstack.log`

---

### Módulo 07: Despliegue OpenStack

```bash
export VENV_PATH="$HOME/openstack_venv"
bash infrastructure/openstack/modules/07_deploy_openstack.sh
```

**Ejecuta (en orden):**
1. `kolla-ansible bootstrap-servers` - Prepara hosts
2. `kolla-ansible prechecks` - Valida precondiciones
3. `kolla-ansible deploy` - Despliega servicios OpenStack
4. `kolla-ansible post-deploy` - Configuración post-instalación

**Duración aproximada:** 30-60 minutos (primera vez)

**Verificación post-instalación:**

```bash
# Verificar servicios Docker
docker ps

# Sourced en admin-openrc.sh
source /etc/kolla/admin-openrc.sh

# Probar acceso OpenStack
openstack service list
openstack image list
openstack compute service list
```

**Logs:** 
- `infrastructure/openstack/logs/install_openstack.log`
- `infrastructure/openstack/logs/preflight.log`

---

## 🚀 Instalación Completa

### Paso 1: Ejecutar Preflight

```bash
cd infrastructure/openstack/preflight
bash preflight_openstack_tester.sh
```

Si todo está OK, continúa al Paso 2.

### Paso 2: Ejecutar Instalador

```bash
cd infrastructure/openstack
bash install_openstack.sh
```

Este script ejecutará **en orden**:
1. ✅ Validar permisos
2. ✅ Instalar deps del sistema
3. ✅ Instalar Docker
4. ✅ Crear virtualenv Python
5. ✅ Instalar Kolla-Ansible
6. ✅ Configurar Kolla
7. ✅ Configurar networking
8. ✅ Desplegar OpenStack

### Paso 3: Verificar Instalación

```bash
# Sourcer credenciales
source /etc/kolla/admin-openrc.sh

# Listar servicios
openstack service list

# Ver imagen por defecto
openstack image list
```

---

## 📊 Logs y Monitoreo

### Ubicación de Logs

```
infrastructure/openstack/logs/
├── preflight.log                    # Preflight checks
├── install_openstack.log            # Instalación completa
```

### Ver logs en tiempo real

```bash
# Durante instalación (en otra terminal)
tail -f infrastructure/openstack/logs/install_openstack.log

# Ver solo errores
grep "ERROR" infrastructure/openstack/logs/install_openstack.log

# Ver warnings
grep "WARNING" infrastructure/openstack/logs/install_openstack.log
```

### Formato de logs

```
[2025-12-06 14:30:15] Usuario ejecutor: usuario (UID=1000)
[2025-12-06 14:30:16] Instalando dependencias del sistema
[2025-12-06 14:31:45] Dependencias del sistema instaladas correctamente
```

---

## 🐛 Troubleshooting

### Error: "Script must NOT run as root"

```bash
# ❌ INCORRECTO
sudo bash install_openstack.sh

# ✅ CORRECTO
bash install_openstack.sh
# (El script pedirá sudo internamente cuando sea necesario)
```

### Error: "User does not have valid sudo privileges"

```bash
# Verificar grupo sudo
groups $USER

# Si no está en sudo:
sudo usermod -aG sudo $USER
newgrp sudo
```

### Error: "At least 6GB RAM required"

```bash
# Ver RAM disponible
free -h

# Liberar memoria
sync && echo 3 | sudo tee /proc/sys/vm/drop_caches
```

### Error: "At least 20GB free disk required"

```bash
# Ver espacio disponible
df -h /

# Limpiar
sudo apt autoclean
sudo apt autoremove
```

### Error: "Cannot reach external network"

```bash
# Probar conectividad
ping -c 1 8.8.8.8

# Verificar DNS
nslookup google.com

# Ver rutas
ip route
```

### Error: "DNS resolution failed"

```bash
# Ver resolvers
cat /etc/resolv.conf

# Probar manualmente
nslookup google.com 8.8.8.8
```

### Error: "Docker: permission denied"

```bash
# Agregar usuario a grupo docker
sudo usermod -aG docker $USER

# Aplicar cambios sin logout
newgrp docker

# Verificar
docker ps
```

### Error: "No default interface detected"

```bash
# Ver interfaces
ip link show

# Ver rutas
ip route

# Configurar interfaz manualmente si es necesario
sudo ip link set <iface> up
```

### Error: "Unsupported Ubuntu version"

```bash
# Ver versión instalada
lsb_release -a
cat /etc/os-release

# Solo Ubuntu 22.04 o 24.04 son soportadas
```

---

## 🔄 Idempotencia (Ejecutar Múltiples Veces)

Los módulos están diseñados para ser **idempotentes**:

```bash
# Ejecutar múltiples veces es seguro
bash install_openstack.sh
bash install_openstack.sh  # Otra vez
bash install_openstack.sh  # Y otra vez

# Verificaciones idempotentes:
# - No recreará veth si ya existe
# - No reinstalará paquetes si ya están
# - No overwrite passwords si ya existen
```

---

## 📝 Configuración Avanzada

### Cambiar ruta del virtualenv

```bash
export VENV_PATH="/opt/openstack_venv"
bash infrastructure/openstack/install_openstack.sh
```

### Cambiar IP del VIP

El módulo 05 auto-detecta. Para forzar:

```bash
# Editar manualmente después de instalación
sudo nano /etc/kolla/globals.yml

# Cambiar:
# kolla_internal_vip_address: "192.168.1.20"

# Reconfigurar
source $HOME/openstack_venv/bin/activate
kolla-ansible reconfigure -i /etc/kolla/ansible/inventory/all-in-one
```

### Cambiar interfaz de red

```bash
# Editar globals.yml
sudo nano /etc/kolla/globals.yml

# Cambiar:
# network_interface: "eth1"

# Reconfigurar
source $HOME/openstack_venv/bin/activate
kolla-ansible reconfigure -i /etc/kolla/ansible/inventory/all-in-one
```

---

## 🆘 Soporte y Recursos

### Documentación Oficial
- [Kolla-Ansible Docs](https://docs.openstack.org/kolla-ansible/)
- [OpenStack Deployment Guide](https://docs.openstack.org/)

### Verificar logs
```bash
cat infrastructure/openstack/logs/install_openstack.log
cat infrastructure/openstack/logs/preflight.log
```

### Ver estado de servicios Docker
```bash
docker ps
docker logs <container_id>
```

### Verificar credenciales generadas
```bash
cat /etc/kolla/passwords.yml
source /etc/kolla/admin-openrc.sh
env | grep OS_
```

---

## 📄 Licencia

Framework de código abierto para propósitos educativos y de laboratorio.

---

**Versión:** 1.0.0  
**Última actualización:** 2025-12-06  
**Mantenedor:** NicsCyberLab
