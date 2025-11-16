# X-Road Security Server Installation - Ansible Playbook

This directory contains Ansible playbooks to install and configure a standalone Security Server using Helm with certificate handling via HTTPS endpoints.

**Note**: The Helm chart is included in `helm-chart/` directory for standalone distribution.

## Overview

This Ansible playbook:
1. Installs the Security Server in a target Kubernetes cluster using Helm
2. Configures the Security Server via UI (creates keys, signs certificates using HTTPS endpoints)
3. Establishes port-forward to the Security Server pod for UI access

**Note**: CA root certificate is obtained by Security Server from Global Configuration automatically.

**Important**: This playbook is designed for standalone Security Server installation where kubectl is configured only for the SS cluster. No access to Central Server or test-ca pod via kubectl is required.

## Prerequisites

- Ansible 2.9+ installed
- `kubectl` configured with access to the **standalone Security Server Kubernetes cluster**
- `helm` 3.0+ installed
- `openssl` installed on the control host
- Python `kubernetes` library: `pip install kubernetes`
- Network access to HTTPS endpoints:
  - `https://ocsp.im.assembly.govstack.global` (for certificate signing)
  - `https://acme.im.assembly.govstack.global` (for certificate signing)
  - `https://tsa.im.assembly.govstack.global` (for timestamping)
- **Note**: No kubectl access to Central Server or test-ca pod is required
- **Note**: CA root certificate is obtained by SS from Global Configuration, no need to fetch/store it

## Directory Structure

```
add-im/
├── ansible.cfg              # Ansible configuration
├── inventory.yml             # Inventory file
├── playbook.yml             # Main playbook
├── group_vars/
│   └── all/                 # All variables (auto-loaded by Ansible)
│       ├── all.yml          # Default variables
│       ├── config.yml       # Configuration parameters (user-defined)
│       └── secrets.yml      # Secret variables (user-defined)
├── helm-chart/              # Helm chart (copied for standalone distribution)
│   ├── templates/           # Helm chart templates
│   │   ├── _helpers.tpl
│   │   ├── _container-main.yaml
│   │   ├── _container-init-copy-certs.yaml
│   │   ├── _container-init-install-ca.yaml
│   │   ├── _traefik-ingress.yaml
│   │   ├── secret.yaml
│   │   └── security-server.yaml
│   ├── Chart.yaml          # Helm chart metadata
│   ├── values.yaml         # Helm values
│   └── secrets.yaml        # Helm secrets
├── roles/
│   ├── installation/
│   │   ├── library/
│   │   │   └── kubectl_port_forward.py  # Custom module for port-forward
│   │   └── tasks/
│   │       ├── main.yml     # Security Server installation tasks
│   │       └── port_forward.yml  # Port-forward management
│   └── configure/
│       └── tasks/
│           └── main.yml     # Security Server configuration tasks
└── README.md                # This file
```

## Usage

### Basic Usage

```bash
cd add-im
ansible-playbook playbook.yml
```

### With Custom Variables

```bash
ansible-playbook playbook.yml \
  -e ss_hostname=ss.example.com \
  -e ss_instance_id=1 \
  -e ss_namespace=x-road
```

### Install Only (Skip Configuration)

```bash
ansible-playbook playbook.yml --tags installation -e install_ss=true
```

### Configure Security Server Only

```bash
ansible-playbook playbook.yml --tags configure \
  -e ss_ui_password=your_password \
  -e ss_token_pin=your_pin
```

## Configuration Variables

Edit `group_vars/all/all.yml` or pass variables via `-e`:

| Variable | Default | Description |
|----------|---------|-------------|
| `govstack_instance` | `assembly` | GovStack instance identifier (from config.yml) |
| `govstack_tld_domain` | `govstack.global` | GovStack top-level domain (from config.yml) |
| `bb_cluster` | `bb-im-second-cluster` | BB cluster name (from config.yml) |
| `bb_domain` | `{{ bb_cluster }}.{{ govstack_instance }}.{{ govstack_tld_domain }}` | BB domain (from config.yml) |
| `bb_member` | `{name, class, code, ...}` | BB member configuration (from config.yml) |
| `ss_hostname` | `ss.{{ bb_domain }}` | Security Server hostname (uses bb_domain) |
| `ss_instance_id` | `0` | Security Server instance ID |
| `ss_namespace` | `im-ns` | Target Kubernetes namespace |
| `cert_dir` | `{{ playbook_dir }}/certs` | Directory for certificates |
| `cert_validity_days` | `7300` | Certificate validity in days |
| `helm_tld_domain` | `{{ bb_domain }}` | Top-level domain for Helm chart (uses bb_domain) |
| `helm_timeout` | `15m` | Helm installation timeout |
| `testca_ocsp_url` | `https://ocsp.im.assembly.govstack.global` | OCSP HTTPS endpoint for certificate signing |
| `testca_acme_url` | `https://acme.im.assembly.govstack.global` | ACME HTTPS endpoint (for reference) |
| `testca_tsa_url` | `https://tsa.im.assembly.govstack.global` | TSA HTTPS endpoint |
| `ss_port_forward_enabled` | `false` | Enable port-forward for SS pod (disabled when using Ingress) |
| `ss_port_forward_local_port` | `4000` | Local port for SS port-forward |
| `ss_port_forward_remote_port` | `4000` | Remote port in SS pod |
| `ss_ingress_enabled` | `true` | Enable Ingress for SS UI access |
| `ss_ingress_hostname` | `ss-ui.{{ helm_tld_domain }}` | Ingress FQDN for SS UI |
| `ss_ui_username` | `xrd` | Security Server UI username |
| `ss_ui_password` | `""` | Security Server UI password (must be provided) |
| `ss_token_pin` | `""` | Security Server token PIN (must be provided) |
| `ss_owner_member_class` | `{{ bb_member.class }}` | Owner member class (uses bb_member.class) |
| `ss_owner_member_code` | `{{ bb_member.code }}` | Owner member code (uses bb_member.code) |
| `ss_security_server_code` | `{{ bb_member.server.code }}` | Security Server code (from bb_member.server.code) |
| `ss_cert_country` | `{{ bb_member.cert.C \| default('EU') }}` | Certificate country code (from bb_member.cert.C, default: EU) |
| `ss_cert_organization` | `{{ bb_member.cert.O \| default(bb_member.name) }}` | Certificate organization (from bb_member.cert.O, default: bb_member.name) |
| `gconf_anchor` | `""` | Global config anchor (empty to fetch from CS) |
| `cs_xsrf_token` | `""` | CS XSRF token (required if fetching anchor) |

## How It Works

### Certificate Generation

**Note**: Certificate generation is handled by the `configure` role via SS UI:
1. **Create certificate directory**: Ensures the certificate directory exists
2. **Create keys via SS UI**: Creates auth and sign keys
3. **Generate CSRs via SS UI**: Generates Certificate Signing Requests
4. **Sign CSRs**: Signs CSRs via test-ca HTTPS endpoint (`https://ocsp.im.assembly.govstack.global/testca/sign`)
5. **Import certificates**: Imports signed certificates via SS UI
6. **Create keystores**: Creates PKCS#12 keystores if needed

**Note**: CA root certificate is obtained by SS from Global Configuration automatically, so there's no need to fetch or store it separately.

### Installation

1. **Verify prerequisites**: Checks for Helm and kubectl
2. **Create namespace**: Creates the target namespace if it doesn't exist
3. **Verify certificates**: Ensures all required certificate files exist
4. **Create Kubernetes secret**: Creates a secret with the certificates
5. **Install Helm chart**: Installs or upgrades the Security Server using Helm
6. **Wait for pod**: Waits for the Security Server pod to be ready
7. **Start port-forward**: Establishes kubectl port-forward to the Security Server pod (for UI access)

### Security Server Configuration

1. **Check SS UI**: Verifies Security Server UI is accessible via port-forward
2. **Login**: Logs in to Security Server UI and obtains XSRF token
3. **Upload anchor**: Uploads global configuration anchor from Central Server
4. **Initialize SS**: Initializes Security Server with owner member and server code
5. **Token login**: Logs in to the software token
6. **Get CA name**: Retrieves CA name from Security Server
7. **Add auth key**: Creates authentication key with CSR
8. **Sign auth CSR**: Signs auth CSR via test-ca HTTPS endpoint
9. **Import auth cert**: Imports signed auth certificate
10. **Add sign key**: Creates signing key with CSR
11. **Sign sign CSR**: Signs sign CSR via test-ca HTTPS endpoint
12. **Import sign cert**: Imports signed sign certificate
13. **Register auth cert**: Registers auth certificate with Central Server
14. **Activate auth cert**: Activates auth certificate on Security Server
15. **Set TSA**: Configures timestamping service

## Connectivity

### Test-CA Connectivity (HTTPS Only)

**Important**: kubectl access to test-ca pod is **not available** in standalone SS context. All test-ca operations use HTTPS endpoints only.

- **CA Certificate**: Obtained by Security Server from Global Configuration automatically
- **Certificate Signing**: Done via HTTPS endpoint `https://ocsp.im.assembly.govstack.global/testca/sign`

### Security Server Port-Forward

The playbook uses a custom Ansible module `kubectl_port_forward` to manage kubectl port-forward connections to the Security Server pod:

- **Start**: Starts port-forward in the background and saves the PID
- **Stop**: Stops the port-forward process using the saved PID
- **Automatic cleanup**: Ensures port-forward is stopped even if playbook fails

The port-forward to Security Server pod is used for:
- Accessing the Security Server UI via `https://localhost:4000` (when enabled)
- Configuration and management operations
- Testing connectivity after installation

**Note**: When `ss_ingress_enabled` is `true`, the Security Server UI is accessible via Ingress at `https://ss-ui.{{ helm_tld_domain }}` instead of port-forward.

## Certificate Files Generated

After running the playbook, the following files are created in `certs/`:

- `certificate-ss-auth.crt` - Authentication certificate (created via SS UI)
- `certificate-ss-auth.key` - Authentication private key (created via SS UI)
- `certificate-ss-sign.crt` - Signing certificate (created via SS UI)
- `certificate-ss-sign.key` - Signing private key (created via SS UI)
- `certificate-ss.crt` - Main certificate (copy of auth)
- `certificate-ss.key` - Main key (copy of auth)
- `certificate-ss-ui.p12` - UI keystore (password: proxy-ui-api)
- `certificate-ss-internal.p12` - Internal keystore (password: internal)

**Note**: CA root certificate is obtained by SS from Global Configuration, not stored locally.

## Troubleshooting

### CA Certificate

The Security Server obtains the CA root certificate from Global Configuration automatically.
No manual fetching or installation is required.

### Certificate signing fails

- Verify the OCSP signing endpoint is accessible: `curl -k https://ocsp.im.assembly.govstack.global/testca/sign`
- Check that the CSR format matches what the endpoint expects
- Review Security Server logs for certificate import errors

### SS Port-forward fails to start

Check if the port is already in use:
```bash
lsof -i :4000
```

Kill any existing port-forward processes:
```bash
pkill -f "kubectl port-forward.*security-server"
```

**Note**: If using Ingress (`ss_ingress_enabled: true`), port-forward is disabled and the UI is accessible via the Ingress hostname.

### Helm installation fails

Check if the chart is already installed:
```bash
helm list -n <namespace>
```

View Helm release status:
```bash
helm status <chart-name> -n <namespace>
```

## Differences from Original Scripts

1. **Ansible-based**: Uses Ansible instead of bash scripts
2. **HTTPS-only connectivity**: Uses HTTPS endpoints (ocsp/tsa/acme.im.assembly.govstack.global) exclusively for test-ca access - no kubectl access to test-ca pod required
3. **Standalone SS context**: Designed for standalone Security Server installation where kubectl is configured only for the SS cluster
4. **Port-forward management**: Properly manages kubectl port-forward lifecycle for Security Server pod only
5. **Flexible certificate signing**: Supports HTTPS API signing or pre-signed certificates
6. **Idempotent**: Can be run multiple times safely
7. **Better error handling**: More robust error checking and reporting
8. **Modular**: Separated into roles for installation and configuration

## Related Documentation

- **Helm Chart Metadata**: See `helm-chart/Chart.yaml` for chart version and description
- **Helm Chart Values**: See `helm-chart/values.yaml` for configuration options

## Notes

- **Test-CA Connectivity**: Uses HTTPS endpoints only (`https://ocsp.im.assembly.govstack.global`, etc.). kubectl access to test-ca pod is not available in standalone SS context.
- **Certificate Signing**: Done via SS UI using `https://ocsp.im.assembly.govstack.global/testca/sign` endpoint
- **Security Server Connectivity**: Uses kubectl port-forward to access the SS pod UI and services.
- **Certificates**: Created via SS UI in the configure role, not on the control host.
- **Cluster Access**: kubectl is configured for standalone SS cluster only. No access to Central Server or test-ca pod.
- **Helm Chart**: The playbook installs the Helm chart from `helm-chart/` directory (included in this package)

