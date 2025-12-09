#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(dirname "$0")"
source "$SCRIPT_DIR/log_utils.sh"

OUTPUT="${1:-$HOME/openrc.sh}"

log "Extracting OpenStack credentials from clouds.yaml"

CLOUDS_YAML="$HOME/.config/openstack/clouds.yaml"

if [[ ! -f "$CLOUDS_YAML" ]]; then
    abort "clouds.yaml not found at $CLOUDS_YAML"
fi

log "Generating openrc.sh at $OUTPUT"

cat > "$OUTPUT" << 'EOF'
#!/bin/bash

export OS_AUTH_URL=$(python3 -c "import yaml; c=yaml.safe_load(open(os.path.expanduser('~/.config/openstack/clouds.yaml'))); print(c['clouds']['openstack']['auth']['auth_url'])")
export OS_PROJECT_ID=$(python3 -c "import yaml; c=yaml.safe_load(open(os.path.expanduser('~/.config/openstack/clouds.yaml'))); print(c['clouds']['openstack']['auth']['project_id'])")
export OS_PROJECT_NAME=$(python3 -c "import yaml; c=yaml.safe_load(open(os.path.expanduser('~/.config/openstack/clouds.yaml'))); print(c['clouds']['openstack']['auth']['project_name'])")
export OS_USER_DOMAIN_NAME=$(python3 -c "import yaml; c=yaml.safe_load(open(os.path.expanduser('~/.config/openstack/clouds.yaml'))); print(c['clouds']['openstack']['auth']['user_domain_name'])")
export OS_USERNAME=$(python3 -c "import yaml; c=yaml.safe_load(open(os.path.expanduser('~/.config/openstack/clouds.yaml'))); print(c['clouds']['openstack']['auth']['username'])")
export OS_PASSWORD=$(python3 -c "import yaml; c=yaml.safe_load(open(os.path.expanduser('~/.config/openstack/clouds.yaml'))); print(c['clouds']['openstack']['auth']['password'])")
export OS_REGION_NAME=$(python3 -c "import yaml; c=yaml.safe_load(open(os.path.expanduser('~/.config/openstack/clouds.yaml'))); print(c['clouds']['openstack']['region_name'])")
export OS_INTERFACE=$(python3 -c "import yaml; c=yaml.safe_load(open(os.path.expanduser('~/.config/openstack/clouds.yaml'))); print(c['clouds']['openstack']['interface'])")
export OS_IDENTITY_API_VERSION=$(python3 -c "import yaml; c=yaml.safe_load(open(os.path.expanduser('~/.config/openstack/clouds.yaml'))); print(c['clouds']['openstack']['identity_api_version'])")
EOF

chmod 600 "$OUTPUT"

log "Credentials file generated at $OUTPUT"
log "Source with: source $OUTPUT"
