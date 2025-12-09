#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(dirname "$0")"
CONFIG="${1:-$SCRIPT_DIR/../configs/initial_config.json}"

if [[ ! -f "$CONFIG" ]]; then
    echo "ERROR: Configuration file not found: $CONFIG"
    exit 1
fi

LOG_DIR="$SCRIPT_DIR/../logs"
mkdir -p "$LOG_DIR"

# Run validation
"$SCRIPT_DIR/validate_environment.sh"

# Load and validate config
"$SCRIPT_DIR/load_config.sh" "$CONFIG"

# Execute setup modules in sequence
"$SCRIPT_DIR/upload_images.sh" "$CONFIG"
"$SCRIPT_DIR/create_keypair.sh" "$CONFIG"
"$SCRIPT_DIR/create_networks.sh" "$CONFIG"
"$SCRIPT_DIR/create_security_groups.sh" "$CONFIG"
"$SCRIPT_DIR/create_flavors.sh" "$CONFIG"

echo "Initial OpenStack setup completed successfully"
