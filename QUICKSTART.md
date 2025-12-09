# NicsyberLab v1 - Quick Start Guide

## Prerequisites

Before starting, ensure you have:

- Ubuntu 22.04 or 24.04 LTS
- 32+ GB RAM
- 8+ CPU cores
- 200+ GB disk space
- Network connectivity

## Installation Steps

### Step 1: Clone Repository

```bash
git clone https://github.com/younyat/nicscyberlab_v1.git
cd nicscyberlab_v1
```

### Step 2: OpenStack Installation

```bash
cd infrastructure/openstack

# Test system readiness
bash preflight/preflight_openstack_tester.sh

# Install OpenStack (45m - 2h)
bash install_openstack.sh

# Verify installation
source admin-openrc.sh
openstack service list
```

### Step 3: Initial OpenStack Configuration

```bash
cd infrastructure/initial

# Test configuration resources
bash test_initial_module.sh

# Deploy configuration (15-30m, includes image downloads)
bash modules/initial_setup.sh

### Automated Full Deploy

If you want the installer to perform dependency installation, OpenStack deploy and the Initial module (images, flavors, networks) in one go, use the new wrapper:

```bash
# From repository root
bash deploy_full_infra.sh
```

You can skip dependency installation if you already ran it:

```bash
bash deploy_full_infra.sh --no-deps
```

# Verify resources
openstack image list
openstack network list
openstack flavor list
```

### Step 4: Scenario Deployment

```bash
source admin-openrc.sh
cd scenario

# Test scenario
bash tester/test_scenario_module.sh

# Deploy cyber range (3-5m for 3 nodes)
bash scenario_manager.sh

# View deployed nodes
cat state/summary.json | jq '.'

# Access instances
ssh -i ~/.ssh/cyberlab-key ubuntu@<floating-ip>
```

### Step 5: Cleanup (when done)

```bash
cd scenario
bash destroy_scenario.sh
```

## Module Overview

### infrastructure/openstack/
- **Purpose**: Install OpenStack with Kolla-Ansible
- **Time**: 45m - 2h
- **Result**: Full OpenStack environment

### infrastructure/initial/
- **Purpose**: Configure OpenStack resources
- **Time**: 15-30m
- **Result**: Images, networks, flavors, security groups, keypairs

### scenario/
- **Purpose**: Deploy cyber range scenarios
- **Time**: 3-5m per scenario
- **Result**: Running instances ready for use

## Documentation

- `infrastructure/openstack/README.md` - Installation details
- `infrastructure/initial/README.md` - Configuration reference
- `scenario/README.md` - Scenario deployment guide

## Troubleshooting

### OpenStack CLI not found

```bash
pip install python-openstackclient
```

### Credentials not loaded

```bash
source admin-openrc.sh  # From repo root
```

### Image download timeout

Increase timeout in `infrastructure/initial/modules/upload_images.sh` or use local mirrors.

### Instance creation timeout

Wait for compute services to stabilize (first deployment may take longer).

## Support

Refer to:
- Module-specific README files
- PREFLIGHT_TEST.md files for testing guides
- Inline script comments for details
- Troubleshooting sections in docs

---

**Framework Version**: 1.0  
**Status**: Production Ready  
**Created**: 2025-12-06
