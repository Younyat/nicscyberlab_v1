# Initial OpenStack Configuration Module

This module automates post-OpenStack-installation configuration and resource provisioning. It creates a complete cloud environment with networks, security groups, flavors, and handles image uploads and keypair management.

## Overview

The Initial module follows **Clean Architecture** principles, providing:

- **Idempotent Operations**: All scripts check for existence before creating resources
- **JSON-Based Configuration**: Centralized `initial_config.json` for all parameters
- **Strict Error Handling**: `set -euo pipefail` with explicit abort conditions
- **Comprehensive Logging**: Timestamped logs in text, JSON, and summary formats
- **No Manual Interaction**: Fully automated, script-driven configuration

## Quick Start

```bash
# Run preflight test (validates everything before execution)
./test_initial_module.sh

# Once test passes, run complete setup
./modules/initial_setup.sh configs/initial_config.json

# Cleanup resources (for testing/reset)
./modules/openstack_cleanup.sh configs/initial_config.json

# Generate credential file
./modules/generate_openrc.sh ~/.openrc
```

## Preflight Testing

Before executing the Initial module, run the comprehensive preflight test:

```bash
./test_initial_module.sh
```

**What the test validates:**
- Directory structure and module presence
- JSON configuration syntax and all required fields
- CIDR format validation
- Flavor specifications (vCPU, RAM, disk)
- Image entries and URL accessibility
- OpenStack CLI availability and authentication
- OpenStack service availability
- Resource conflicts (existing networks, security groups, etc.)

**Test output files:**
- `logs/test_initial_module.log` - Detailed execution log
- `logs/test_initial_module.json` - Structured log in JSON format
- `logs/test_initial_module_summary.txt` - Summary report

The test is **non-destructive** - it only validates, checks, and reports. It does NOT:
- Download images
- Create any resources
- Modify the system
- Install packages
- Execute destructive commands

Exit code `0` means all checks passed and the system is ready for Initial module execution.

## Directory Structure

```
infrastructure/initial/
├── README.md                  # This file
├── configs/
│   └── initial_config.json    # Central configuration file
├── modules/
│   ├── log_utils.sh           # Logging framework
│   ├── validate_environment.sh # Pre-flight environment checks
│   ├── load_config.sh         # JSON config validation and loading
│   ├── upload_images.sh       # Cloud image provisioning
│   ├── create_keypair.sh      # SSH keypair management
│   ├── create_networks.sh     # Network and subnet setup
│   ├── create_security_groups.sh # Security group and firewall rules
│   ├── create_flavors.sh      # VM flavor definitions
│   ├── initial_setup.sh       # Main orchestrator
│   ├── openstack_cleanup.sh   # Complete resource teardown
│   └── generate_openrc.sh     # Credential file generation
└── logs/
    ├── initial_setup.log      # Detailed execution log
    ├── initial_setup.json     # Structured log (JSON)
    └── initial_setup_summary.txt # Summary report
```

## Configuration Reference

### initial_config.json

Central configuration file controlling all resource creation:

```json
{
  "images": [
    {
      "name": "Ubuntu-24.04",
      "url": "https://cloud-images.ubuntu.com/noble/current/noble-server-cloudimg-amd64.img",
      "format": "qcow2",
      "properties": {"hw_scsi_model": "virtio-scsi", "hw_disk_bus": "scsi"}
    }
  ],
  "networks": {
    "external": {
      "name": "external",
      "cidr": "10.0.2.0/24",
      "subnet_name": "external_subnet"
    },
    "private": {
      "name": "private",
      "cidr": "192.168.100.0/24",
      "subnet_name": "private_subnet",
      "dns": ["8.8.8.8", "8.8.4.4"]
    }
  },
  "security_group": {
    "name": "cyberlab-secgroup"
  },
  "flavors": {
    "tiny": {"vcpu": 1, "ram": 512, "disk": 5},
    "small": {"vcpu": 1, "ram": 1024, "disk": 10},
    "medium": {"vcpu": 2, "ram": 2048, "disk": 20},
    "large": {"vcpu": 4, "ram": 4096, "disk": 40}
  },
  "keypair": {
    "name": "cyberlab-key",
    "path": "~/.ssh/cyberlab-key"
  }
}
```

### Configuration Parameters

**Images:**
- `name`: Display name in Glance
- `url`: Download URL (HTTP/HTTPS)
- `format`: Image format (qcow2, raw, vhd, vmdk)
- `properties`: Additional metadata for Glance

**Networks:**
- External: Floating IP network, no DHCP
- Private: Instance network with DNS servers

**Security Groups:**
- Named: `cyberlab-secgroup`
- Rules: SSH(22), HTTP(80), HTTPS(443), Wazuh(1514,1515,55000), Kibana(5601), Custom(8888)

**Flavors:**
- `cyberlab-tiny`: 1 vCPU, 512 MB RAM, 5 GB disk
- `cyberlab-small`: 1 vCPU, 1 GB RAM, 10 GB disk
- `cyberlab-medium`: 2 vCPU, 2 GB RAM, 20 GB disk
- `cyberlab-large`: 4 vCPU, 4 GB RAM, 40 GB disk

**Keypair:**
- Automatically generated if missing at specified path
- Registered with OpenStack for instance access

## Module Details

### validate_environment.sh

Pre-flight checks before configuration begins:

- OpenStack CLI installed and in PATH
- jq available for JSON parsing
- OpenStack authentication configured
- Valid token obtained

**Usage:**
```bash
./modules/validate_environment.sh
```

**Exit Codes:**
- `0`: All checks passed
- `1`: Missing dependency or authentication failure

### load_config.sh

Validates JSON configuration and loads parameters:

- Syntax validation (proper JSON)
- Required fields check
- Availability for downstream modules

**Usage:**
```bash
./modules/load_config.sh configs/initial_config.json
```

### upload_images.sh

Provisions cloud images to Glance image registry:

- Downloads from specified URLs
- Creates if not exists (idempotent)
- Caches downloads in `/tmp/openstack_images`
- Sets properties from configuration

**Usage:**
```bash
./modules/upload_images.sh configs/initial_config.json
```

**Idempotency:**
Checks `openstack image show $name` before creation. Re-running skips existing images.

### create_keypair.sh

Manages SSH keypair for instance access:

- Generates new RSA 4096-bit key if missing
- Registers public key with OpenStack
- Stores private key with secure permissions (600)

**Usage:**
```bash
./modules/create_keypair.sh configs/initial_config.json
```

**Idempotency:**
Checks `openstack keypair show` before creation.

**Key Location:**
Default: `~/.ssh/cyberlab-key` (configurable in initial_config.json)

### create_networks.sh

Establishes network infrastructure:

**External Network (Floating IPs):**
- Network: `external` (10.0.2.0/24)
- Subnet: `external_subnet`
- DHCP: Disabled
- Usage: Floating IP allocation

**Private Network (Instances):**
- Network: `private` (192.168.100.0/24)
- Subnet: `private_subnet`
- DHCP: Enabled
- DNS: 8.8.8.8, 8.8.4.4

**Router:**
- Name: `cyberlab-router`
- External gateway: `external` network
- Internal interface: `private_subnet`

**Usage:**
```bash
./modules/create_networks.sh configs/initial_config.json
```

**Idempotency:**
Checks `openstack network show`, `openstack subnet show`, and `openstack router show` before creation.

### create_security_groups.sh

Configures firewall rules for instances:

**Security Group:** `cyberlab-secgroup`

**Ingress Rules (IPv4):**
- Port 22 (SSH)
- Port 80 (HTTP)
- Port 443 (HTTPS)
- Port 1514 (Wazuh Agent)
- Port 1515 (Wazuh Cluster)
- Port 55000 (Wazuh Cluster UDP)
- Port 5601 (Kibana)
- Port 8888 (Custom Application)

**Usage:**
```bash
./modules/create_security_groups.sh configs/initial_config.json
```

**Idempotency:**
Rules use `2>/dev/null || true` to ignore duplicate creation errors.

### create_flavors.sh

Defines VM size templates:

**Flavor List:**
- `cyberlab-tiny`: 1 vCPU, 512 MB, 5 GB (test/demo)
- `cyberlab-small`: 1 vCPU, 1 GB, 10 GB (lightweight services)
- `cyberlab-medium`: 2 vCPU, 2 GB, 20 GB (standard services)
- `cyberlab-large`: 4 vCPU, 4 GB, 40 GB (heavy workloads)

**Usage:**
```bash
./modules/create_flavors.sh configs/initial_config.json
```

**Idempotency:**
Checks `openstack flavor show` before creation.

### initial_setup.sh

Main orchestrator executing all configuration modules:

**Execution Order:**
1. Validate environment
2. Load configuration
3. Upload images
4. Create keypair
5. Create networks
6. Create security groups
7. Create flavors

**Usage:**
```bash
./modules/initial_setup.sh configs/initial_config.json
```

**Default Config:**
If no argument provided, uses `configs/initial_config.json`

**Return Value:**
- Succeeds if all modules complete without error
- Exits immediately on first failure (set -e)

### openstack_cleanup.sh

Removes all created resources for testing/reset:

**Deletion Order:**
1. Instances
2. Router and associations
3. Networks and subnets
4. Security groups
5. Flavors
6. Keypairs
7. Images

**Usage:**
```bash
./modules/openstack_cleanup.sh configs/initial_config.json
```

**Caution:**
This script is **destructive**. Use only for testing or intentional teardown.

**Idempotency:**
All deletion commands redirect errors to `/dev/null`. Safe to re-run.

### generate_openrc.sh

Extracts OpenStack credentials from `clouds.yaml`:

**Generated File Location:**
- Default: `$HOME/openrc.sh`
- Configurable: `./modules/generate_openrc.sh /custom/path/openrc.sh`

**Environment Variables:**
- `OS_AUTH_URL`: Keystone endpoint
- `OS_PROJECT_ID` and `OS_PROJECT_NAME`: Project scope
- `OS_USER_DOMAIN_NAME` and `OS_USERNAME`: Authentication
- `OS_PASSWORD`: User password
- `OS_REGION_NAME`: OpenStack region
- `OS_INTERFACE`: API endpoint type
- `OS_IDENTITY_API_VERSION`: Keystone API version

**Usage:**
```bash
# Generate default location
./modules/generate_openrc.sh

# Generate custom location
./modules/generate_openrc.sh ~/.my_openrc

# Source credentials
source ~/.openrc
openstack server list
```

## Logging

### Log Files

All modules generate logs in `logs/` directory:

**Text Log:** `initial_setup.log`
```
[2025-12-06 16:30:15] Creating security groups from configuration
[2025-12-06 16:30:15] Security group already exists: cyberlab-secgroup
[2025-12-06 16:30:15] Adding ingress rules
```

**JSON Log:** `initial_setup.json`
```json
[
  {"timestamp": "2025-12-06T16:30:15Z", "level": "info", "module": "create_security_groups.sh", "message": "Creating security groups from configuration"},
  {"timestamp": "2025-12-06T16:30:15Z", "level": "info", "module": "create_security_groups.sh", "message": "Security group already exists: cyberlab-secgroup"}
]
```

**Summary Report:** `initial_setup_summary.txt`
```
Initial OpenStack Setup Summary
===============================
Execution Date: 2025-12-06 16:30:15
Status: COMPLETED
Duration: 45 seconds

Modules Executed:
[OK] validate_environment.sh
[OK] load_config.sh
[OK] upload_images.sh
[OK] create_keypair.sh
[OK] create_networks.sh
[OK] create_security_groups.sh
[OK] create_flavors.sh
```

### Log Functions

From `log_utils.sh`:

```bash
log "Message"          # Standard info log with timestamp
abort "Error message"  # Log error and exit with code 1
```

## Troubleshooting

### Authentication Fails

**Symptom:** "ERROR: OpenStack CLI not authenticated"

**Solution:**
```bash
# Source clouds.yaml for authentication
eval $(openstack token issue -f value -c command)

# Or manually configure credentials
export OS_AUTH_URL=https://keystone.example.com
export OS_USERNAME=admin
export OS_PASSWORD=password
export OS_PROJECT_NAME=admin
export OS_REGION_NAME=RegionOne
export OS_IDENTITY_API_VERSION=3
```

### Image Download Timeout

**Symptom:** "Failed to download image from URL"

**Solution:**
- Verify URL accessibility: `wget -q --spider https://url`
- Check download timeout: Increase timeout in `upload_images.sh` line 12
- Use local file mirror: Modify `images[].url` in initial_config.json

### Network Creation Fails with "External Network Exists"

**Symptom:** "Failed to create external network"

**Solution:**
- Check existing networks: `openstack network list`
- Modify CIDR in initial_config.json if network already exists
- Or run cleanup first: `./modules/openstack_cleanup.sh`

### Security Group Rules Not Applied

**Symptom:** Ports not accessible from outside

**Solution:**
1. Verify security group created: `openstack security group list`
2. Check rules applied: `openstack security group show cyberlab-secgroup`
3. Ensure instance assigned security group at launch time
4. Check floating IP association: `openstack floating ip list`

### Keypair Access Denied

**Symptom:** "Permission denied (publickey)" when SSH-ing

**Solution:**
```bash
# Verify private key permissions
ls -la ~/.ssh/cyberlab-key
# Should show: -rw------- (600)

# Check public key in OpenStack
openstack keypair show cyberlab-key

# If permissions wrong, fix them
chmod 600 ~/.ssh/cyberlab-key

# Retry SSH
ssh -i ~/.ssh/cyberlab-key ubuntu@instance-ip
```

### Module Fails But Continues

**Symptom:** Error message appears but setup continues

**Solution:**
This shouldn't happen with `set -euo pipefail`. If it does:
1. Check for `2>/dev/null || true` patterns (intentional error suppression)
2. Verify script shebang: `#!/bin/bash` (not `/bin/sh`)
3. Run with `bash -x` for debug output: `bash -x ./modules/module_name.sh`

## Configuration Examples

### Custom Network CIDR

**Before:** `initial_config.json`
```json
"networks": {
  "private": {
    "cidr": "192.168.100.0/24"
  }
}
```

**After:** Custom /22 for larger deployments
```json
"networks": {
  "private": {
    "cidr": "192.168.0.0/22"
  }
}
```

### Additional Cloud Images

**Add to** `initial_config.json`:
```json
"images": [
  {
    "name": "Debian-12",
    "url": "https://cloud.debian.org/images/cloud/bookworm/latest/debian-12-genericcloud-amd64.qcow2",
    "format": "qcow2"
  },
  {
    "name": "CentOS-8",
    "url": "https://cloud.centos.org/centos/8/x86_64/images/CentOS-8-GenericCloud-8.3.1-20201211.0.x86_64.qcow2",
    "format": "qcow2"
  }
]
```

### Additional Security Group Rules

**Add to** `create_security_groups.sh`:
```bash
# Custom port for application
openstack security group rule create --ingress --protocol tcp --dst-port 9200 "$sg_name" 2>/dev/null || true
```

### Additional Flavors

**Add to** `initial_config.json`:
```json
"flavors": {
  "xlarge": {"vcpu": 8, "ram": 8192, "disk": 80},
  "gpu": {"vcpu": 4, "ram": 16384, "disk": 100}
}
```

Then run: `./modules/create_flavors.sh configs/initial_config.json`

## Testing Individual Modules

Each module is independent and can be tested in isolation:

```bash
# Test environment validation
./modules/validate_environment.sh

# Test config loading
./modules/load_config.sh configs/initial_config.json

# Test image upload (takes time - downloads images)
./modules/upload_images.sh configs/initial_config.json

# Test keypair creation
./modules/create_keypair.sh configs/initial_config.json

# Test network creation
./modules/create_networks.sh configs/initial_config.json

# Test security groups
./modules/create_security_groups.sh configs/initial_config.json

# Test flavors
./modules/create_flavors.sh configs/initial_config.json
```

## Production Deployment Checklist

- [ ] Modify `initial_config.json` with your environment values
- [ ] Test with `validate_environment.sh` first
- [ ] Review security group rules for your use case
- [ ] Adjust flavor specifications for your hardware
- [ ] Backup `initial_config.json` (contains sensitive info in production)
- [ ] Run `initial_setup.sh` against test OpenStack first
- [ ] Verify all resources created: `openstack image list`, `openstack network list`, etc.
- [ ] Test instance launch with created flavors and security groups
- [ ] Generate credentials with `generate_openrc.sh` for operations team
- [ ] Document any customizations to configuration

## Security Considerations

1. **Configuration File**: Contains no sensitive data by default, but may in production. Use restrictive file permissions:
   ```bash
   chmod 600 configs/initial_config.json
   ```

2. **Keypair Private Key**: Generated in `~/.ssh/` with 600 permissions. Never commit to version control.

3. **Security Group Rules**: Ingress only - egress unrestricted by default. Tighten as needed.

4. **Network Isolation**: Private network isolated from external; use router for controlled access.

5. **Cleanup Script**: Use `openstack_cleanup.sh` only in controlled environments. Highly destructive.

## Performance Notes

- Image upload: Depends on URL download speed (5-15 minutes for Ubuntu images)
- Network creation: < 10 seconds
- Flavor registration: < 5 seconds per flavor
- Total execution time: 10-20 minutes (mostly image downloads)

## References

- OpenStack CLI Documentation: https://docs.openstack.org/python-openstackclient/latest/
- Glance Image Service: https://docs.openstack.org/glance/latest/
- Neutron Networking: https://docs.openstack.org/neutron/latest/
- Nova Compute: https://docs.openstack.org/nova/latest/

## Support

For issues or questions:

1. Check logs in `logs/` directory
2. Review troubleshooting section above
3. Run with debug output: `bash -x modules/module_name.sh config.json`
4. Verify OpenStack CLI works: `openstack image list`
5. Check authentication: `openstack token issue`

---

**Version:** 1.0  
**Last Updated:** 2025-12-06  
**Compatibility:** OpenStack (all versions with python-openstackclient)
