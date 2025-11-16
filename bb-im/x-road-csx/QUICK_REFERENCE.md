# Central Server Quick Reference

## Current Status (Updated: 2025-01-XX)

**Pod Status:**
- Pod Name: `cs-1-*` (e.g., `cs-1-6f7c7cc56c-7f4js`) - check with `kubectl get pods -n im-ns -l app.kubernetes.io/component=central-server`
- Namespace: `im-ns`
- Status: ✅ Running (1/1 Ready)
- Database: `cs-1-db-0` (1/1 Ready) - StatefulSet name: `cs-1-db`

**Admin Credentials:**
- Username: `xrd`
- Password: Retrieved from Kubernetes secret `cs-1` (see "Retrieve Secrets" section below)
- Token PIN: Retrieved from Kubernetes secret `cs-1` (see "Retrieve Secrets" section below)

## Central Server Initialization

**Initialization is done via `hurl-auto-config` scripts.**

### To Run Initialization:

Run the hurl-auto-config setup from the bb-im directory:

```bash
cd bb-im/hurl-auto-config
./run_config_fqdn.sh
```

### Configuration

The initialization uses configuration from `hurl-auto-config/config/vars.env`:

- `cs_host` - Central Server host (default: `cs.im.assembly.govstack.global`)
- `cs_host_port` - Port specification (default: `:4000`)
- `cs_host_password` - Admin password (loaded from Kubernetes secret `cs-1`)
- `cs_host_pin` - Token PIN (loaded from Kubernetes secret `cs-1`)

### What the Initialization Does:

1. Checks Central Server status
2. Logs in and retrieves XSRF token
3. Initializes Central Server with instance ID and address
4. Configures Central Server settings
5. Adds CA configuration (OCSP, ACME, TSA)
6. Configures Security Servers

See `hurl-auto-config/parts/` for the individual Hurl configuration files.

## Access Admin Interface

**URL:** `https://localhost:4000` (via port-forward)

**Alternatives:**
- `https://cs-ui.im.assembly.govstack.global` (via Ingress, port 443)
- `https://10.0.0.100:4000` (via LoadBalancer `xroad-cs-admin-lb`)

**LoadBalancer Services:**
- `xroad-cs-admin-lb` - Port 4000 (Admin UI) - MetalLB IP: `10.0.0.100`
- `xroad-cs-reg-lb` - Port 4001 (Registration) - MetalLB IP: `10.0.0.100`

## Known Issues

None currently known.

## Next Steps After Initialization

1. Add Certification Service (CA)
2. Add OCSP Responder
3. Add Timestamping Service (TSA)
4. Configure Security Servers

## Retrieve Secrets

```bash
# Get admin password (single base64 decode)
kubectl get secret cs-1 -n im-ns -o jsonpath='{.data.password}' | base64 -d

# Get token PIN
kubectl get secret cs-1 -n im-ns -o jsonpath='{.data.tokenPin}' | base64 -d

# Get database password
kubectl get secret cs-1 -n im-ns -o jsonpath='{.data.dbPassword}' | base64 -d
```

**Note:** The secret name is `cs-1` (not `cs`). The service name is `cs` (from `fullnameOverride: "cs"`).

**Note:** Do not hardcode passwords in documentation files. Always retrieve them from Kubernetes secrets when needed.

