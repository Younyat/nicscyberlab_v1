# Scenario Module - Cyber Range Deployment

Professional cyber range scenario deployment module for OpenStack. Creates complex multi-node attack-defense lab environments declaratively from JSON configuration.

## Overview

The Scenario module:

- **Declarative**: Define entire cyber range environments in JSON
- **No Terraform**: Uses only OpenStack CLI and bash
- **Idempotent**: Safe to run multiple times
- **Relative Paths**: Works from `scenario/` directory
- **Clean Architecture**: Modular, testable components
- **Professional Logging**: Clear, structured output

## Quick Start

```bash
# From repo root
source admin-openrc.sh
cd scenario

# Test scenario (validates without creating anything)
bash tester/test_scenario_module.sh

# Deploy scenario
bash scenario_manager.sh

# Destroy scenario
bash destroy_scenario.sh
```

## Directory Structure

```
scenario/
├── core/                          # Core modules
│   ├── log_utils.sh              # Logging utilities
│   ├── validate_scenario.sh       # Scenario validation (no creation)
│   ├── generate_nodes.sh          # Create instances, ports, floating IPs
│   ├── build_summary.sh           # Build deployment summary
│   └── destroy_nodes.sh           # Teardown all nodes
├── configs/
│   └── scenario_file.json         # Scenario definition
├── state/                         # Deployment state files
│   ├── summary.json              # Deployed nodes and IPs
│   ├── deployment_status.json    # Deployment status
│   └── destroy_status.json       # Destruction status
├── tester/
│   └── test_scenario_module.sh    # Preflight validation
├── scenario_manager.sh             # Main orchestrator (deploy)
└── destroy_scenario.sh             # Destruction orchestrator
```

## Configuration

### scenario_file.json Structure

```json
{
  "nodes": [
    {
      "id": "unique-node-id",
      "name": "instance-name",
      "type": "os-type",
      "properties": {
        "os": "ubuntu-24.04",
        "image": "ubuntu-24.04",
        "flavor": "cyberlab-small",
        "network": "private-net",
        "subnetwork": "private-subnet",
        "securityGroup": "cyberlab-secgroup",
        "sshKey": "cyberlab-key"
      }
    }
  ],
  "edges": [
    {
      "source": "node-id-1",
      "target": "node-id-2",
      "type": "attack|reconnaissance|communication",
      "description": "Edge description"
    }
  ],
  "metadata": {
    "name": "Scenario Name",
    "description": "Scenario description",
    "version": "1.0"
  }
}
```

**Node Properties:**
- `id`: Unique identifier (alphanumeric + underscore)
- `name`: OpenStack instance name
- `type`: Node category (kali, ubuntu, debian, etc.)
- `properties.os`: OS identifier for SSH user detection
- `properties.image`: OpenStack image name
- `properties.flavor`: OpenStack flavor name (must exist)
- `properties.network`: Network name (must exist)
- `properties.subnetwork`: Subnet name (must exist)
- `properties.securityGroup`: Security group name (must exist)
- `properties.sshKey`: SSH keypair name (must exist)

**Edge Properties (optional):**
- `source`: Source node ID
- `target`: Target node ID
- `type`: Edge type (for scenario documentation)
- `description`: Human-readable description

## Usage

### 1. Test Scenario (No Creation)

Validates configuration without modifying anything:

```bash
cd scenario
bash tester/test_scenario_module.sh
```

**Checks:**
- JSON syntax validity
- Required fields present
- All OpenStack resources exist (images, flavors, networks, etc.)
- OpenStack credentials loaded
- API connectivity

**Does NOT:**
- Create any instances
- Download anything
- Modify OpenStack

Exit code `0` = Ready to deploy

### 2. Deploy Scenario

Creates all nodes from configuration:

```bash
bash scenario_manager.sh
```

Or with custom config:

```bash
bash scenario_manager.sh /path/to/custom/scenario.json
```

**Process:**
1. Validates scenario configuration
2. Creates networks ports
3. Creates OpenStack instances
4. Waits for instances to be ACTIVE
5. Allocates floating IPs
6. Associates floating IPs with instances
7. Generates summary.json

**Produces:**
- `state/summary.json` - Deployed node details
- `state/deployment_status.json` - Deployment status
- Console output with SSH commands

**Example output:**
```
[INFO] Node kali-attacker created successfully
[INFO] SSH access: ssh -i ~/.ssh/cyberlab-key kali@10.0.2.45
[INFO] Node ubuntu-victim created successfully
[INFO] SSH access: ssh -i ~/.ssh/cyberlab-key ubuntu@10.0.2.46
```

### 3. Destroy Scenario

Removes all created resources:

```bash
bash destroy_scenario.sh
```

**Removes:**
- Floating IP associations
- Floating IPs (deallocates)
- Instances (servers)
- Ports
- Does NOT remove: networks, keypairs, images

**State:**
- Does NOT modify `scenario_file.json`
- Clears `summary.json`
- Updates `destroy_status.json`

## Core Scripts

### log_utils.sh

Provides logging functions used throughout module:

```bash
log_info "Info message"
log_warn "Warning message"
log_error "Error message" 
log_section "Section header"
require_command "command_name"
check_os_credentials
```

### validate_scenario.sh

Validates scenario without creating anything:

```bash
bash core/validate_scenario.sh configs/scenario_file.json
```

**Validations:**
- JSON syntax
- Nodes section exists
- All referenced OpenStack resources exist
- External network for floating IPs

### generate_nodes.sh

Creates all instances and networking:

```bash
bash core/generate_nodes.sh configs/scenario_file.json state/
```

**Creates:**
- Ports (one per node)
- Instances (servers)
- Floating IPs
- Associations

**Waits for:**
- Instance ACTIVE state (max 4 minutes)
- Port availability
- IP allocation

### build_summary.sh

Finalizes deployment summary:

```bash
bash core/build_summary.sh state/
```

**Produces:** `state/summary.json` with all node details including floating IPs and SSH commands.

### destroy_nodes.sh

Removes all created resources:

```bash
bash core/destroy_nodes.sh state/
```

**Removes in order:**
1. Floating IP associations
2. Floating IPs
3. Instances (with polling for deletion)
4. Ports

## State Files

### summary.json

Deployed nodes with connection details:

```json
[
  {
    "id": "attack-kali",
    "name": "kali-attacker",
    "server_id": "uuid-of-instance",
    "floating_ip": "10.0.2.45",
    "ssh_user": "kali",
    "port_name": "attack_kali-port",
    "created_at": "2025-12-06T17:30:00Z"
  },
  {
    "id": "victim-ubuntu",
    "name": "ubuntu-victim",
    "server_id": "uuid-of-instance",
    "floating_ip": "10.0.2.46",
    "ssh_user": "ubuntu",
    "port_name": "victim_ubuntu-port",
    "created_at": "2025-12-06T17:31:00Z"
  }
]
```

### deployment_status.json

Overall deployment status:

```json
{
  "status": "completed",
  "error": null
}
```

Values: `running`, `completed`, `error`

### destroy_status.json

Destruction status:

```json
{
  "status": "completed",
  "error": null
}
```

## SSH Access

After deployment, SSH commands are provided in console output:

```bash
ssh -i ~/.ssh/cyberlab-key kali@10.0.2.45
ssh -i ~/.ssh/cyberlab-key ubuntu@10.0.2.46
ssh -i ~/.ssh/cyberlab-key debian@10.0.2.47
```

SSH user is auto-detected from OS type:
- Ubuntu: `ubuntu`
- Debian: `debian`
- Kali: `kali`
- CentOS: `centos`
- Fedora: `fedora`

## Example Scenarios

### Simple Two-Node Scenario

`configs/scenario_file.json`:

```json
{
  "nodes": [
    {
      "id": "attacker",
      "name": "kali-1",
      "type": "kali",
      "properties": {
        "os": "kali-linux",
        "image": "kali-latest",
        "flavor": "cyberlab-medium",
        "network": "private-net",
        "subnetwork": "private-subnet",
        "securityGroup": "cyberlab-secgroup",
        "sshKey": "cyberlab-key"
      }
    },
    {
      "id": "target",
      "name": "ubuntu-1",
      "type": "ubuntu",
      "properties": {
        "os": "ubuntu-24.04",
        "image": "ubuntu-24.04",
        "flavor": "cyberlab-small",
        "network": "private-net",
        "subnetwork": "private-subnet",
        "securityGroup": "cyberlab-secgroup",
        "sshKey": "cyberlab-key"
      }
    }
  ],
  "metadata": {
    "name": "Simple Attack Range",
    "description": "One attacker, one victim"
  }
}
```

### Multi-OS Scenario

Different operating systems in one range:

```json
{
  "nodes": [
    {"id": "attacker", "name": "kali-1", "properties": {"os": "kali-linux", "image": "kali-latest", ...}},
    {"id": "ubuntu-web", "name": "ubuntu-web-1", "properties": {"os": "ubuntu-24.04", "image": "ubuntu-24.04", ...}},
    {"id": "debian-db", "name": "debian-db-1", "properties": {"os": "debian-12", "image": "debian-12", ...}},
    {"id": "old-ubuntu", "name": "ubuntu-old-1", "properties": {"os": "ubuntu-20.04", "image": "ubuntu-20.04", ...}}
  ]
}
```

## Troubleshooting

### Error: "Invalid or missing OpenStack credentials"

**Solution:**
```bash
source admin-openrc.sh
bash tester/test_scenario_module.sh
```

### Error: "Image not found"

**Solution:**
```bash
# List available images
openstack image list

# Update scenario_file.json with correct image names
```

### Error: "Flavor not found"

**Solution:**
```bash
# List available flavors
openstack flavor list

# Use existing flavors: cyberlab-tiny, cyberlab-small, cyberlab-medium, cyberlab-large
```

### Error: "Timeout waiting for instance to become ACTIVE"

**Possible causes:**
- OpenStack compute service overloaded
- Resource quota exceeded
- Network issues

**Solution:**
```bash
# Check instance status manually
openstack server list

# Check compute service logs in OpenStack
# Try again with fewer instances or wait and retry
bash destroy_scenario.sh  # Clean up
bash scenario_manager.sh  # Retry
```

### Instance stuck in ERROR state

**Solution:**
```bash
# Delete stuck instance manually
openstack server delete <instance-name>

# Run destroy to clean up everything
bash destroy_scenario.sh

# Fix scenario configuration and retry
```

## Performance Notes

- Instance creation: 1-2 minutes per instance
- Port creation: < 1 second per port
- Floating IP allocation: < 10 seconds
- Total time for 3-node scenario: 3-5 minutes

## Prerequisites

- OpenStack environment configured and running
- `admin-openrc.sh` sourced with valid credentials
- Required images created (ubuntu-24.04, debian-12, kali-latest, etc.)
- Required flavors created (cyberlab-tiny, cyberlab-small, cyberlab-medium, cyberlab-large)
- Network and security group created (private-net, private-subnet, cyberlab-secgroup)
- SSH keypair created (cyberlab-key)
- External network available (external-net)

See `infrastructure/initial/` module for setup.

## Security Considerations

1. **Floating IPs**: Allocated from external network - instances are reachable from public
2. **Security Groups**: All nodes use same security group - adjust firewall rules as needed
3. **SSH Keys**: Stored in `~/.ssh/cyberlab-key` - protect from unauthorized access
4. **Networks**: Private network isolated from external except via floating IPs

## Advanced Usage

### Custom Scenario Definition

Create your own `configs/my_scenario.json`:

```bash
cp configs/scenario_file.json configs/my_scenario.json
# Edit configs/my_scenario.json
bash scenario_manager.sh configs/my_scenario.json
```

### Selective Node Creation

Edit `scenario_file.json` nodes array to include only desired nodes.

### State Inspection

```bash
# View deployment summary
cat state/summary.json | jq '.'

# View deployment status
cat state/deployment_status.json | jq '.'

# List created instances
openstack server list
```

### Manual Cleanup

If automation fails:

```bash
# List floating IPs and delete manually
openstack floating ip list
openstack floating ip delete <ip>

# Delete instances
openstack server list
openstack server delete <instance-name>

# Delete ports
openstack port list | grep -i port_name
openstack port delete <port-id>

# Then run automated destroy
bash destroy_scenario.sh
```

## References

- [OpenStack CLI Documentation](https://docs.openstack.org/python-openstackclient/latest/)
- [OpenStack Networking (Neutron)](https://docs.openstack.org/neutron/latest/)
- [OpenStack Compute (Nova)](https://docs.openstack.org/nova/latest/)

## Version

- **Version**: 1.0
- **Last Updated**: 2025-12-06
- **Compatibility**: OpenStack with python-openstackclient

## Author Notes

- No Terraform required
- Pure bash + OpenStack CLI + JSON
- Relative paths from `scenario/` directory
- Idempotent and non-destructive validation
- Professional error handling and logging
