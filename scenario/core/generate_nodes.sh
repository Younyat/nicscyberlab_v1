#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
BASE_DIR="$(cd "$SCRIPT_DIR/.." && pwd -P)"

# resolve relative paths against module base
resolve_path() {
    local p="$1"
    if [[ -z "$p" ]]; then
        echo ""
        return
    fi
    if [[ "$p" = /* ]]; then
        echo "$p"
    else
        echo "$BASE_DIR/${p#/}"
    fi
}

source "$SCRIPT_DIR/log_utils.sh"

SCENARIO_JSON_RAW="${1:-configs/scenario_file.json}"
SCENARIO_JSON="$(resolve_path "$SCENARIO_JSON_RAW")"
OUTDIR_RAW="${2:-state}"
OUTDIR="$(resolve_path "$OUTDIR_RAW")"
SUMMARY_TMP="$OUTDIR/summary.tmp.json"

DEFAULT_EXTERNAL_NET="external-net"


mkdir -p "$OUTDIR"

log_section "Generating nodes from scenario: $SCENARIO_JSON"

require_command jq
require_command openstack

check_os_credentials

on_error() {
    local rc=$?
    log_error "generate_nodes.sh failed with exit code $rc"
    exit $rc
}

trap on_error ERR

if [ ! -f "$SCENARIO_JSON" ]; then
    log_error "Scenario JSON not found: $SCENARIO_JSON"
    exit 1
fi

SUMMARY="[]"

while read -r node; do
    id=$(echo "$node" | jq -r '.id')
    name=$(echo "$node" | jq -r '.name')
    os=$(echo "$node" | jq -r '.properties.os')

    image=$(echo "$node" | jq -r '.properties.image')
    flavor=$(echo "$node" | jq -r '.properties.flavor')
    network=$(echo "$node" | jq -r '.properties.network')
    subnet=$(echo "$node" | jq -r '.properties.subnetwork')
    secgroup=$(echo "$node" | jq -r '.properties.securityGroup')
    sshkey=$(echo "$node" | jq -r '.properties.sshKey')

    safe=$(echo "$id" | tr -c '[:alnum:]_' '_')
    port_name="${safe}-port"

    log_section "Creating node: $name"

    # Create port
    log_info "Creating port: $port_name"
    PORT_ID=$(openstack port create "$port_name" \
        --network "$network" \
        --security-group "$secgroup" \
        -f value -c id 2>&1)

    if [ -z "$PORT_ID" ]; then
        log_error "Failed to create port: $port_name"
        exit 1
    fi

    log_info "Port created: $PORT_ID"

    # Create server
    log_info "Creating server: $name"
    SERVER_ID=$(openstack server create "$name" \
        --image "$image" \
        --flavor "$flavor" \
        --key-name "$sshkey" \
        --nic port-id="$PORT_ID" \
        -f value -c id 2>&1)

    if [ -z "$SERVER_ID" ]; then
        log_error "Failed to create server: $name"
        exit 1
    fi

    log_info "Server created: $SERVER_ID"
    log_info "Waiting for ACTIVE state (this may take 1-2 minutes)"

    MAX_ATTEMPTS=120
    attempt=0

    while true; do
        STATUS=$(openstack server show "$SERVER_ID" -f value -c status 2>&1 || echo "UNKNOWN")

        if [[ "$STATUS" == "ACTIVE" ]]; then
            log_info "Instance $name is ACTIVE"
            break
        fi

        if [[ "$STATUS" == "ERROR" ]]; then
            log_error "Instance $name entered ERROR state"
            exit 1
        fi

        if (( attempt >= MAX_ATTEMPTS )); then
            log_error "Timeout waiting for $name to become ACTIVE (after $((attempt*2))s)"
            exit 1
        fi

        attempt=$((attempt+1))
        sleep 2
    done

    # Create floating IP
    log_info "Allocating floating IP from $DEFAULT_EXTERNAL_NET"
    FIP=$(openstack floating ip create "$DEFAULT_EXTERNAL_NET" \
        -f value -c floating_ip_address 2>&1)

    if [ -z "$FIP" ]; then
        log_error "Failed to allocate floating IP"
        exit 1
    fi

    log_info "Floating IP allocated: $FIP"

    # Associate floating IP
    log_info "Associating floating IP to server"
    openstack server add floating ip "$SERVER_ID" "$FIP" 2>&1 || {
        log_error "Failed to associate floating IP"
        exit 1
    }

    log_info "Floating IP associated"

    # Determine SSH user based on OS
    case "$os" in
        ubuntu*) ssh_user="ubuntu" ;;
        debian*) ssh_user="debian" ;;
        kali*) ssh_user="kali" ;;
        centos*) ssh_user="centos" ;;
        fedora*) ssh_user="fedora" ;;
        *) ssh_user="ubuntu" ;;
    esac

    SUMMARY=$(echo "$SUMMARY" | jq \
        --arg id "$id" \
        --arg name "$name" \
        --arg server_id "$SERVER_ID" \
        --arg fip "$FIP" \
        --arg ssh_user "$ssh_user" \
        --arg port_name "$port_name" \
        '. += [{
            id: $id,
            name: $name,
            server_id: $server_id,
            floating_ip: $fip,
            ssh_user: $ssh_user,
            port_name: $port_name,
            created_at: now | todate
        }]')

    log_info "Node $name created successfully"
    log_info "SSH access: ssh -i ~/.ssh/cyberlab-key $ssh_user@$FIP"


done < <(jq -c '.nodes[]' "$SCENARIO_JSON")

echo "$SUMMARY" > "$SUMMARY_TMP"
log_info "Temporary summary stored at: $SUMMARY_TMP"
