#!/usr/bin/env bash
set -euo pipefail

PORT="$1"

if [[ -z "$PORT" ]]; then
  echo "Usage: $0 <port>" >&2
  exit 1
fi

PIDS=$(ss -ltnp 2>/dev/null | awk -v p=":$PORT" '$4~p {print $6}' | cut -d',' -f2 | cut -d'=' -f2 | sort -u)
if [[ -z "$PIDS" ]]; then
  echo "No process listening on port $PORT"
  exit 0
fi

echo "Killing processes on port $PORT: $PIDS"
for pid in $PIDS; do
  if [[ "$pid" =~ ^[0-9]+$ ]]; then
    kill -9 "$pid" && echo "Killed $pid" || echo "Failed to kill $pid"
  fi
done
