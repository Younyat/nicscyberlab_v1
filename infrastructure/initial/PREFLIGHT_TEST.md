# Initial Module Preflight Test

Professional, comprehensive preflight test for the Initial OpenStack Configuration Module.

## Overview

The `test_initial_module.sh` script validates **all conditions** required to successfully execute the Initial module without errors. It performs 10 distinct validation checks across multiple categories:

- **Structural Validation**: Module files, directories, permissions
- **Configuration Validation**: JSON syntax, required fields, format checks
- **URL Validation**: Image download source accessibility
- **Environment Validation**: OpenStack CLI, credentials, authentication
- **Service Validation**: OpenStack service availability
- **Conflict Detection**: Pre-existing resources that may be skipped

## Key Features

✓ **Non-Destructive**: Only validates, never modifies the system  
✓ **No Installation**: Does not install any packages  
✓ **No Creation**: Does not create any OpenStack resources  
✓ **No Downloads**: Does not download images (only checks URL availability)  
✓ **Idempotent**: Can be run multiple times safely  
✓ **Comprehensive Logging**: Text, JSON, and summary output formats  
✓ **Detailed Reporting**: Clear success/warning/error messages  

## Usage

```bash
cd infrastructure/initial
./test_initial_module.sh
```

Or specify custom config:

```bash
./test_initial_module.sh /path/to/custom/config.json
```

## Test Execution

### Example Output (Success)

```
[2025-12-06 16:07:44] [INFO] === Initial Module Preflight Test Started ===
[2025-12-06 16:07:44] [INFO] [TEST 1/10] Checking directory structure
[2025-12-06 16:07:44] [SUCCESS] Modules directory exists
[2025-12-06 16:07:44] [SUCCESS] Configuration file exists
[2025-12-06 16:07:44] [SUCCESS] All required modules present (11 files)
[2025-12-06 16:07:44] [SUCCESS] All modules are executable
[2025-12-06 16:07:44] [INFO] [TEST 2/10] Validating JSON syntax
[2025-12-06 16:07:44] [SUCCESS] jq is installed
[2025-12-06 16:07:44] [SUCCESS] JSON syntax is valid
[2025-12-06 16:07:44] [INFO] [TEST 3/10] Checking JSON required fields
[2025-12-06 16:07:44] [SUCCESS] All required JSON fields present
[2025-12-06 16:07:44] [INFO] [TEST 4/10] Validating JSON field values
[2025-12-06 16:07:44] [SUCCESS] External CIDR format valid: 10.0.2.0/24
[2025-12-06 16:07:44] [SUCCESS] Private CIDR format valid: 192.168.100.0/24
[2025-12-06 16:07:44] [SUCCESS] All flavor specifications valid
[2025-12-06 16:07:44] [INFO] === Initial Module Preflight Test Completed Successfully ===
[2025-12-06 16:07:44] [SUCCESS] All checks passed. System is ready for Initial module execution.

Summary:
  Passed:  14
  Warned:  0
  Failed:  0
```

### Example Output (With Warnings)

```
[2025-12-06 16:06:13] [WARNING] curl not found - skipping URL validation (will be installed by openstack module)
[2025-12-06 16:06:13] [WARNING] curl not available (non-critical)
```

These warnings are non-critical. Curl will be installed by the OpenStack installation module before the Initial module runs.

### Example Output (Failure)

```
[2025-12-06 16:07:44] [ERROR] openstack command not found (install with: pip install python-openstackclient)
Initial Module Preflight Test Summary
=====================================
Status: FAILED
Last Error: openstack command not found
```

Exit with error code `1` - the OpenStack CLI must be installed before running the Initial module.

## Test Categories

### TEST 1: Directory Structure (File Validation)

Validates that all required module files exist:

- Modules directory exists
- Configuration file exists
- All 11 required modules present:
  - `log_utils.sh`
  - `validate_environment.sh`
  - `load_config.sh`
  - `upload_images.sh`
  - `create_keypair.sh`
  - `create_networks.sh`
  - `create_security_groups.sh`
  - `create_flavors.sh`
  - `initial_setup.sh`
  - `openstack_cleanup.sh`
  - `generate_openrc.sh`
- All modules are executable

### TEST 2: JSON Syntax (Configuration Validation)

Validates JSON configuration file:

- `jq` tool is installed
- JSON is syntactically valid
- Detects JSON parsing errors before execution

### TEST 3: Required Fields (Configuration Validation)

Validates that all required JSON keys are present:

```json
{
  "images": {...},
  "networks": {
    "external": {"name", "cidr", "subnet_name"},
    "private": {"name", "cidr", "subnet_name", "dns"}
  },
  "security_group": {"name"},
  "flavors": {"tiny", "small", "medium", "large"},
  "keypair": {"name", "path"}
}
```

### TEST 4: Field Values (Configuration Validation)

Validates the content and format of configuration values:

- **CIDR Validation**: External and private network CIDRs match CIDR format (`10.0.2.0/24`)
- **Flavor Specifications**: All 4 flavors have:
  - Valid vCPU count (>= 1)
  - Valid RAM size (>= 256 MB)
  - Valid disk size (>= 1 GB)

### TEST 5: Image Entries (Configuration Validation)

Validates image configuration:

- Counts images in configuration
- Reports if no images configured (warning only - module will run)
- Validates each image entry structure

### TEST 6: Image URLs (Network/Accessibility)

Validates that cloud image download sources are reachable:

- Attempts HEAD request to each image URL
- Checks for HTTP 200, 301, 302, 403 responses
- **Non-blocking**: Warnings only - images can be re-downloaded during module execution
- Skips test if `curl` not installed (will be installed by OpenStack module)

### TEST 7: OpenStack CLI (Environment)

Validates OpenStack command-line interface availability:

- `openstack` command is installed and in PATH
- Reports OpenStack version
- Required for all subsequent module operations
- **Blocking failure**: Module cannot run without OpenStack CLI

### TEST 8: Environment Variables (Credentials)

Validates OpenStack credentials are loaded:

- `OS_AUTH_URL` set
- `OS_USERNAME` set
- `OS_PASSWORD` set
- `OS_PROJECT_NAME` set

Typically set by sourcing `admin-openrc.sh`:
```bash
source /path/to/admin-openrc.sh
```

**Blocking failure**: Cannot authenticate to OpenStack API without these.

### TEST 9: API Authentication (Service)

Tests OpenStack API connectivity and credentials:

- Attempts to issue an authentication token
- Validates connection to Keystone service
- Verifies credentials are correct
- No resources created or modified

**Blocking failure**: Credentials incorrect or API unavailable.

### TEST 10: Service Availability (Service)

Checks that required OpenStack services are operational:

- Image service (Glance) - for image upload
- Network service (Neutron) - for network creation
- Compute service (Nova) - for flavor definitions

**Non-blocking warning**: Some services may not be listed but still operational.

## Log Output

The test generates three log files in `logs/` directory:

### Detailed Log (`test_initial_module.log`)

Plain text format with timestamps, ideal for reading:

```
[2025-12-06 16:07:44] [INFO] === Initial Module Preflight Test Started ===
[2025-12-06 16:07:44] [SUCCESS] Modules directory exists
[2025-12-06 16:07:44] [SUCCESS] Configuration file exists
...
```

### Structured Log (`test_initial_module.json`)

JSON format, one object per line, suitable for parsing:

```json
{"timestamp": "2025-12-06T15:06:34Z", "level": "info", "message": "=== Initial Module Preflight Test Started ==="}
{"timestamp": "2025-12-06T15:06:34Z", "level": "success", "message": "Modules directory exists"}
...
```

### Summary Report (`test_initial_module_summary.txt`)

High-level summary with statistics:

```
Initial Module Preflight Test Summary
======================================
Execution Date: 2025-12-06 16:07:44
Status: PASSED

Test Results:
  Passed:  14
  Warned:  0
  Failed:  0

All validations completed successfully.
Ready to execute: ./modules/initial_setup.sh
```

## Exit Codes

- `0`: All tests passed - ready for Initial module execution
- `1`: One or more tests failed - resolve errors before executing Initial module

## Troubleshooting

### Error: "openstack command not found"

**Cause**: OpenStack CLI not installed or not in PATH

**Solution**:
```bash
# Install python-openstackclient
pip install python-openstackclient

# Verify installation
openstack --version
```

### Error: "Environment variables not set (admin-openrc.sh not loaded?)"

**Cause**: OpenStack credentials not loaded in shell environment

**Solution**:
```bash
# Source the admin credentials file
source /path/to/admin-openrc.sh

# Verify variables are set
echo $OS_AUTH_URL
echo $OS_USERNAME

# Re-run test
./test_initial_module.sh
```

### Error: "Failed to issue token"

**Cause**: OpenStack credentials invalid or API unreachable

**Verification**:
```bash
# Check if OpenStack services are running
openstack service list

# Verify credentials
echo "Auth URL: $OS_AUTH_URL"
echo "Username: $OS_USERNAME"
echo "Project: $OS_PROJECT_NAME"

# Test token manually
openstack token issue
```

### Error: "initial_config.json is not valid JSON"

**Cause**: JSON syntax error in configuration file

**Solution**:
```bash
# Validate JSON syntax
jq . configs/initial_config.json

# Look for syntax errors in output
# Fix any reported issues and re-run test
```

### Warning: "curl not found"

**Severity**: Non-critical warning

**Explanation**: curl will be installed by the OpenStack installation module before Initial module execution

**Resolution**: No action required - continue with execution

### Warning: "Network/Security group/Flavor already exists"

**Severity**: Non-critical warning

**Explanation**: Resources already created in OpenStack

**Resolution**: 
- Module will skip creation (idempotent behavior)
- To reset, run cleanup: `./modules/openstack_cleanup.sh configs/initial_config.json`

## Common Use Cases

### Pre-Execution Validation

```bash
# Run test to validate everything
./test_initial_module.sh

# If successful, proceed with module
./modules/initial_setup.sh
```

### CI/CD Integration

```bash
#!/bin/bash
set -e

cd infrastructure/initial
./test_initial_module.sh || exit 1

# Proceed with deployment
./modules/initial_setup.sh
```

### Debugging Configuration

```bash
# Run test to identify configuration issues
./test_initial_module.sh

# Review detailed log
cat logs/test_initial_module.log

# Parse JSON log for specific failures
jq 'select(.level=="error")' logs/test_initial_module.json
```

### Health Check

```bash
# Verify OpenStack environment is ready
./test_initial_module.sh

# Optional: Check specific resources
openstack token issue
openstack service list
openstack image list
```

## Performance

- Execution time: 5-10 seconds (varies based on network and OpenStack API responsiveness)
- No I/O intensive operations
- No downloads or large data transfers
- All operations are synchronous and sequential

## What NOT Tested

The preflight test validates **readiness** but does NOT test:

- Actual module execution (test is non-destructive)
- Resource creation functionality
- Image download performance
- Network configuration accuracy
- Security group rule application
- Flavor creation with compute resources

These are tested during actual module execution.

## Best Practices

1. **Always run before initial module execution**
   ```bash
   ./test_initial_module.sh && ./modules/initial_setup.sh
   ```

2. **Review warnings carefully**
   - Most warnings are non-blocking
   - Document any known issues before execution

3. **Check logs for detailed information**
   - Use detailed log for human review
   - Use JSON log for automated parsing

4. **Keep credentials secure**
   - admin-openrc.sh contains sensitive information
   - Don't commit to version control
   - Use restrictive file permissions (600)

5. **Run in the correct directory**
   ```bash
   cd infrastructure/initial
   ./test_initial_module.sh
   ```

## Related Documentation

- [Initial Module README](./README.md) - Complete module documentation
- [Preflight Test in OpenStack Module](../openstack/preflight/) - Similar test for OpenStack installation
- [Configuration Reference](./README.md#configuration-reference) - JSON configuration details

## Version

- **Version**: 1.0
- **Last Updated**: 2025-12-06
- **Compatibility**: Bash 4.0+, jq 1.6+, curl 7.0+, openstack-client 3.0+

