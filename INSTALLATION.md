# Installation & Testing Guide

## Quick Start

### 1. Install Dependencies

```bash
bash install_dependencies.sh
```

This script will:
- ✅ Detect your OS (Ubuntu/Debian optimized)
- ✅ Update package manager
- ✅ Install system dependencies (curl, jq, python3, gunicorn, flask, etc.)
- ✅ Install Python dependencies from `requirements.txt`
- ✅ Verify critical commands

**Requires sudo** for system package installation.

### 2. Run Full Test Suite

```bash
bash run_tests.sh
```

This runs **19 comprehensive tests** covering:

#### Syntax Checks (Bash & Python)
- All shell scripts validate with `bash -n`
- Python code compiles cleanly

#### Dependency Validation
- Critical commands present: `curl`, `python3`, `jq`, `bash`, `git`

#### File Structure
- All required config files exist
- JSON configs are valid

#### Functional Tests (Offline Mode)
- Scenario manager dry-run validation
- Flight test health-check dry-run

**Expected output:** `All tests passed!` (exit code 0)

---

## Dependencies Overview

### System Dependencies
Automatically installed by `install_dependencies.sh`:

| Package | Purpose |
|---------|---------|
| `python3` | Python runtime |
| `python3-pip` | Python package manager |
| `python3-venv` | Virtual environment support |
| `curl` | HTTP requests (flight test, API calls) |
| `wget` | File download utility |
| `git` | Version control |
| `jq` | JSON parsing/manipulation |
| `python3-flask` | Web framework (dashboard) |
| `python3-gunicorn` | WSGI application server |
| `openssh-client` | SSH client (remote node management) |
| `openssh-server` | SSH server (optional) |

### Python Dependencies (requirements.txt)

```
flask==3.0.2              # Web framework for dashboard
gunicorn==20.1.0          # WSGI server
python-openstackclient    # OpenStack CLI SDK
pyyaml>=6.0               # YAML config parsing
jinja2>=3.1.0             # Template engine
requests>=2.28.0          # HTTP library
click>=8.1.0              # CLI framework
pydantic>=2.0.0           # Data validation
```

---

## Usage Examples

### Start Dashboard with Health Check
```bash
# Start dashboard and run flight tests
bash tests/flight_test.sh --start

# Custom URL and port
bash tests/flight_test.sh --start --url http://localhost:5001

# Custom timeout and retries
bash tests/flight_test.sh --start --timeout 20 --retries 10
```

### Deploy Scenario (Offline Mode)
```bash
# Validate only (no OpenStack calls)
bash scenario/scenario_manager.sh --dry-run

# Full deployment (requires OpenStack CLI + credentials)
bash scenario/scenario_manager.sh scenario/configs/scenario_file.json
```

### Monitor Installation
```bash
# Watch real-time logs
tail -f state/tests/logs/flight_report_*.json

# Check deployment status
cat scenario/state/deployment_status.json | jq .
```

---

## Troubleshooting

### Issue: `sudo: command not found`
**Fix:** Run `install_dependencies.sh` with `sudo` or user with sudoers access.

```bash
sudo bash install_dependencies.sh
```

### Issue: `pip3: command not found`
**Fix:** Install python3-pip first:
```bash
sudo apt-get install -y python3-pip
```

### Issue: Tests fail with "openstack command not found"
**Expected:** The flight test works offline. Full OpenStack deployment requires:
```bash
source admin-openrc.sh  # Load OpenStack credentials
bash scenario/scenario_manager.sh scenario/configs/scenario_file.json
```

### Issue: Port 5001 already in use
**Fix:** Free the port:
```bash
bash free_port.sh 5001
```

Or use a different port:
```bash
bash tests/flight_test.sh --start --url http://localhost:5002
```

---

## File Structure After Installation

```
nicscyberlab_v1/
├── app.py                        # Flask dashboard app
├── requirements.txt              # Python dependencies
├── install_dependencies.sh       # Dependency installer
├── run_tests.sh                  # Test orchestrator
├── start_dashboard.sh            # Dashboard startup script
├── free_port.sh                  # Port killer utility
│
├── scenario/
│   ├── scenario_manager.sh       # Main orchestrator
│   ├── destroy_scenario.sh       # Cleanup script
│   ├── configs/
│   │   └── scenario_file.json    # Scenario config
│   ├── core/
│   │   ├── log_utils.sh          # Logging utilities
│   │   ├── validate_scenario.sh  # Validator
│   │   ├── generate_nodes.sh     # Node creator
│   │   └── build_summary.sh      # Summary generator
│   ├── state/
│   │   ├── deployment_status.json # Deployment state
│   │   └── logs/                 # Scenario logs
│   └── tester/
│       └── test_scenario_module.sh # Scenario tester
│
├── tests/
│   └── flight_test.sh            # Health/smoke test
│
├── src/
│   ├── models/
│   │   └── tools.py              # Data models
│   ├── services/
│   │   ├── tools_installer_service.py
│   │   └── tools_uninstaller_service.py
│   ├── controllers/
│   │   └── tools_controller.py
│   └── entrypoints/
│       └── cli/
│           ├── install_tools_cli.py
│           └── uninstall_tools_cli.py
│
└── state/
    └── tests/
        └── logs/
            └── flight_report_<timestamp>.json  # Test reports
```

---

## CI/CD Integration

### GitHub Actions Example
```yaml
name: Tests
on: [push, pull_request]
jobs:
  test:
    runs-on: ubuntu-22.04
    steps:
      - uses: actions/checkout@v3
      - name: Install dependencies
        run: bash install_dependencies.sh
      - name: Run tests
        run: bash run_tests.sh
```

### GitLab CI Example
```yaml
test:
  image: ubuntu:22.04
  script:
    - apt-get update && apt-get install -y sudo
    - bash install_dependencies.sh
    - bash run_tests.sh
```

---

## Support & Next Steps

1. **After installation:**
   - Run `bash run_tests.sh` to validate setup
   - Start dashboard: `bash start_dashboard.sh`
   - Monitor logs: Check `state/` directory

2. **For OpenStack deployment:**
   - Source your OpenStack admin credentials: `source admin-openrc.sh`
   - Run: `bash scenario/scenario_manager.sh`
   - Monitor status: `cat scenario/state/deployment_status.json | jq`

3. **For tools installation:**
   - Run: `python3 -m src.entrypoints.cli.install_tools_cli` (Python)
   - Or: `bash tools-installer/tools_install_master.sh` (Bash)

4. **For health checks:**
   - Run: `bash tests/flight_test.sh --dry-run` (offline)
   - Run: `bash tests/flight_test.sh --start` (with dashboard)
   - View reports: `cat state/tests/logs/flight_report_*.json | jq`

---

## Version Info

- **Created:** 2025-12-06
- **Tested on:** Ubuntu 24.04 LTS
- **Python:** 3.10+
- **Bash:** 5.0+

---

For more information, see individual module READMEs:
- `scenario/README.md`
- `tools-installer/README.md`
- `infrastructure/README.md`
