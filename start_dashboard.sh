#!/usr/bin/env bash
set -euo pipefail

PORT=5001
TIMEOUT=20000
APP_PATH="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"

echo "============================================="
echo " Preparing dashboard environment..."
echo "============================================="

if [ -f "$APP_PATH/free_port.sh" ]; then
  chmod +x "$APP_PATH/free_port.sh"
  echo "Applied execute permission to free_port.sh"
else
  echo "free_port.sh not found in $APP_PATH"
  exit 1
fi

echo "Releasing port $PORT if in use..."
bash "$APP_PATH/free_port.sh" "$PORT"

if ! command -v gunicorn >/dev/null 2>&1; then
  echo "Gunicorn not found. Installing..."
  if [ -n "${VIRTUAL_ENV:-}" ]; then
    pip install gunicorn
  else
    sudo pip install gunicorn
  fi
else
  echo "Gunicorn already installed"
fi

cd "$APP_PATH" || exit 1

exec gunicorn -w 4 -b "localhost:$PORT" --timeout "$TIMEOUT" app:app
