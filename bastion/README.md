# Bastion Helm Chart

A Helm chart for deploying a bastion pod in Kubernetes with SSH access on port 22 and common development tools.

## Features

- SSH server on port 22 (container port 22)
- Pre-installed tools: vim, curl, wget, git, net-tools, ping, dnsutils, jq, less, tree, htop, python3, pip, ansible, sudo
- Configurable via Helm values
- SSH key-based authentication
- Persistent SSH host keys (optional)

## Installation

### Quick Start

```bash
cd bastion/
./install.sh
```

### Custom Installation

1. Edit `values.yaml` to configure:
   - SSH authorized keys
   - Additional packages
   - Resources
   - Namespace

2. Install with Helm:
```bash
helm install bastion . --namespace default --create-namespace
```

## Configuration

### SSH Keys

**Option 1: Use secrets.yaml (Recommended)**

Add your SSH public keys to `secrets.yaml`:

```yaml
ssh:
  authorizedKeys:
    - "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAAB... user@host"
    - "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAAB... another@host"
```

**Option 2: Use existing Kubernetes secret**

Reference an existing secret in `values.yaml`:

```yaml
ssh:
  authorizedKeysSecret: "my-ssh-keys-secret"
```

**Note**: The `secrets.yaml` file contains sensitive data and should be kept secure. Consider adding it to `.gitignore` if committing to version control.

### Accessing the Bastion

#### Port Forward (Recommended)

```bash
kubectl port-forward -n default svc/bastion 22:22
ssh root@localhost
```

#### Direct Pod Access

```bash
kubectl exec -it -n default <pod-name> -- /bin/bash
```

## Default Values

- **Image**: `ubuntu:22.04`
- **Service Type**: `ClusterIP`
- **Service Port**: `22` (maps to container port 22)
- **Namespace**: `default`
- **Replicas**: `1`
- **Persistent Storage**: `5Gi` (enabled by default)

## Uninstallation

```bash
helm uninstall bastion -n default
```

