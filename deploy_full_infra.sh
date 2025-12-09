#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
LOG_DIR="$SCRIPT_DIR/logs"
mkdir -p "$LOG_DIR"

echo "==========================================="
echo " nicscyberlab Full Infrastructure Deployer"
echo "==========================================="

usage() {
  cat <<EOF
Usage: $0 [--no-deps] [--config PATH]

Options:
  --no-deps      Skip running install_dependencies.sh
  --config PATH  Path to initial config JSON (default: infrastructure/initial/configs/initial_config.json)
  --help         Show this help

This script will (by default):
  1) Install system and Python dependencies (via install_dependencies.sh)
  2) Run the OpenStack installation orchestrator (infrastructure/openstack/install_openstack.sh)
  3) Run Initial module preflight and initial_setup to upload images, flavors, networks

Run as a regular user; some sub-scripts may prompt for sudo when required.
EOF
}

CONFIG_PATH="$SCRIPT_DIR/infrastructure/initial/configs/initial_config.json"
RUN_DEPS=true
BACKGROUND=false
LOGFILE="$SCRIPT_DIR/logs/deploy_full_infra.log"
PIDFILE="$SCRIPT_DIR/logs/deploy_full_infra.pid"

while [[ ${#} -gt 0 ]]; do
  case "$1" in
    --no-deps) RUN_DEPS=false; shift ;;
    --config) CONFIG_PATH="$2"; shift 2 ;;
    --background) BACKGROUND=true; shift ;;
    --help) usage; exit 0 ;;
    *) echo "Unknown arg: $1"; usage; exit 1 ;;
  esac
done

run_steps() {
  if $RUN_DEPS; then
    echo "[INFO] Installing system & Python dependencies..."
    bash "$SCRIPT_DIR/install_dependencies.sh" || { echo "[ERROR] install_dependencies.sh failed"; return 1; }
  else
    echo "[INFO] Skipping dependency installation (--no-deps)"
  fi

  echo "[INFO] Starting OpenStack install orchestrator..."
  if [[ -x "$SCRIPT_DIR/infrastructure/openstack/install_openstack.sh" ]]; then
    bash "$SCRIPT_DIR/infrastructure/openstack/install_openstack.sh" || { echo "[ERROR] install_openstack.sh failed"; return 2; }
  else
    echo "[ERROR] infrastructure/openstack/install_openstack.sh not found or not executable"; return 3
  fi

  echo "[INFO] OpenStack installation completed. Proceeding to Initial module preflight..."
  pushd "$SCRIPT_DIR/infrastructure/initial" >/dev/null

  echo "[INFO] Running test_initial_module.sh (preflight)"
  ./test_initial_module.sh || { echo "[ERROR] Preflight checks failed. Inspect infrastructure/initial/logs"; popd >/dev/null; return 4; }

  echo "[INFO] Preflight passed. Running Initial module: initial_setup.sh with config $CONFIG_PATH"
  if [[ -x ./modules/initial_setup.sh ]]; then
    ./modules/initial_setup.sh "$CONFIG_PATH" || { echo "[ERROR] initial_setup.sh failed. Check logs in infrastructure/initial/logs"; popd >/dev/null; return 5; }
  else
    echo "[ERROR] modules/initial_setup.sh not found or not executable"; popd >/dev/null; return 6
  fi

  echo "[INFO] Initial module completed successfully. Logs: infrastructure/initial/logs/initial_setup.log"
  popd >/dev/null
  return 0
}

if [[ "$BACKGROUND" == "true" ]]; then
  echo "[INFO] Running deployment in background. Logs -> $LOGFILE"
  nohup bash -c "run_steps" > "$LOGFILE" 2>&1 &
  echo $! > "$PIDFILE"
  echo "[INFO] Background PID: $(cat $PIDFILE)"
  exit 0
else
  run_steps || exit 1
fi

echo "[INFO] Starting OpenStack install orchestrator..."
if [[ -x "$SCRIPT_DIR/infrastructure/openstack/install_openstack.sh" ]]; then
  bash "$SCRIPT_DIR/infrastructure/openstack/install_openstack.sh" || { echo "[ERROR] install_openstack.sh failed"; exit 1; }
else
  echo "[ERROR] infrastructure/openstack/install_openstack.sh not found or not executable"; exit 1
fi

echo "[INFO] OpenStack installation completed. Proceeding to Initial module preflight..."
pushd "$SCRIPT_DIR/infrastructure/initial" >/dev/null

echo "[INFO] Running test_initial_module.sh (preflight)"
./test_initial_module.sh || { echo "[ERROR] Preflight checks failed. Inspect infrastructure/initial/logs"; popd >/dev/null; exit 1; }

echo "[INFO] Preflight passed. Running Initial module: initial_setup.sh with config $CONFIG_PATH"
if [[ -x ./modules/initial_setup.sh ]]; then
  ./modules/initial_setup.sh "$CONFIG_PATH" || { echo "[ERROR] initial_setup.sh failed. Check logs in infrastructure/initial/logs"; popd >/dev/null; exit 1; }
else
  echo "[ERROR] modules/initial_setup.sh not found or not executable"; popd >/dev/null; exit 1
fi

echo "[INFO] Initial module completed successfully. Logs: infrastructure/initial/logs/initial_setup.log"
popd >/dev/null

echo "[INFO] Full infrastructure deployment finished. You can now create scenarios and install tools from the UI or CLI."
echo "To monitor initial logs: tail -f infrastructure/initial/logs/initial_setup.log"

exit 0
