# X-Road BB-IM Deployment Guide

## Overview

This guide covers deploying X-Road Information Mediator to the BB-IM cluster using the downloaded configurations adapted for our infrastructure.

## Prerequisites

1. **VPN Access**: Connected to BB-IM cluster via VPN
   ```bash
   sudo wg-quick up wireguard/bb-im/admin.conf
   ```

2. **Kubeconfig**: BB-IM kubeconfig configured
   ```bash
   export KUBECONFIG=k8s/bb-im/kubeconfig
   ```

3. **Namespace**: Verify xroad-im namespace exists
   ```bash
   kubectl get namespace xroad-im || kubectl create namespace xroad-im
   ```

4. **MetalLB**: Verify MetalLB is running and configured
   ```bash
   kubectl get pods -n metallb-system
   kubectl get ipaddresspool -n metallb-system
   ```

## Key Differences from Original Setup

| Aspect | Original | Our Setup |
|--------|----------|-----------|
| Namespace | `im-ns` | `xroad-im` |
| External Access | Ingress (Traefik) | LoadBalancer (MetalLB) |
| DNS | `*.im.assembly.govstack.global` | IP-based (10.0.0.100) |
| Service Type | ClusterIP + Ingress | ClusterIP + separate LoadBalancer |
| Access Method | Public DNS | VPN + LoadBalancer VIP |

## External Access Architecture

### DNS Mapping
- **Central Server**: `cs.im.assembly.govstack.global` → 49.13.243.37 (BB-IM gateway) → 10.0.0.100
- **Security Server**: 49.13.243.43 (BB-IM-SECOND gateway) → 10.0.0.100

### MetalLB Virtual IP (VIP)
All LoadBalancer services share VIP **10.0.0.100** using annotation:
\`\`\`yaml
metallb.universe.tf/allow-shared-ip: "shared-vip"
\`\`\`

### Traffic Flow - Central Server
\`\`\`
External User
  ↓
cs.im.assembly.govstack.global (DNS)
  ↓
49.13.243.37 (BB-IM Gateway External IP)
  ↓ (DNAT via iptables)
10.0.0.100:port (MetalLB VIP)
  ↓
Central Server Pod
\`\`\`

### Port Access Patterns
| Port | Service | VPN Access | External Access | Gateway |
|------|---------|-----------|-----------------|---------|
| 4000 | Admin UI | ✅ 10.0.0.100 | ❌ NOT forwarded | - |
| 4001 | Registration | ✅ 10.0.0.100 | ✅ cs.im...global:4001 | 49.13.243.37 |
| 8443 | Client HTTPS | ✅ 10.0.0.100 | ✅ cs.im...global:8443 | 49.13.243.37 |
| 9998 | Test CA | ✅ 10.0.0.100 | ✅ via gateway | 49.13.243.37 |
| 5500 | SS Messaging | ✅ 10.0.0.100 | ✅ via gateway | 49.13.243.43 |
| 5577 | SS OCSP | ✅ 10.0.0.100 | ✅ via gateway | 49.13.243.43 |

**Admin UI Access**: Only accessible via VPN connection - NOT exposed externally.

## Deployment Order

**CRITICAL**: Components must be deployed in this exact order due to dependencies.

### Step 1: Deploy Test CA (Trust Anchor)

Test CA provides ACME, OCSP, and TSA services required by Central Server and Security Server.

```bash
cd bb-im/test-ca

# Make script executable
chmod +x install.sh

# Deploy
./install.sh
```

**Verify**:
```bash
kubectl get pods -n xroad-im -l app.kubernetes.io/name=test-ca
kubectl get svc -n xroad-im -l app.kubernetes.io/name=test-ca
```

Expected output:
- Pod: `test-ca-*` in Running state
- Services: `ca` (port 80), others for ACME/OCSP/TSA

### Step 2: Deploy Central Server

Central Server is the governance component that manages the X-Road ecosystem.

```bash
cd bb-im/x-road-csx

# Make script executable
chmod +x install_cs_1.sh

# Deploy
./install_cs_1.sh
```

**Verify**:
```bash
kubectl get pods -n xroad-im -l app.kubernetes.io/component=central-server
kubectl get svc -n xroad-im | grep cs-1
```

Expected output:
- Pod: `cs-1-*` in Running state
- Service: `cs-1` (ClusterIP)
- StatefulSet: `cs-1-db` (PostgreSQL database)

### Step 3: Deploy Central Server LoadBalancer Services

These expose Central Server ports externally via MetalLB.

```bash
cd metallb-services/bb-im

# Deploy LoadBalancer services
kubectl apply -f xroad-cs-admin-ui-4000-lb.yaml
kubectl apply -f xroad-cs-admin-4001-lb.yaml
kubectl apply -f xroad-cs-client-8443-lb.yaml
kubectl apply -f xroad-cs-testca-9998-lb.yaml
```

**Verify**:
```bash
kubectl get svc -n xroad-im | grep xroad-cs
```

Expected output: All services should have `EXTERNAL-IP: 10.0.0.100`

**CRITICAL ISSUE TO FIX**: Our LoadBalancer services use selector `app: sandbox-xroad-cs` but Helm chart likely uses `app.kubernetes.io/*` labels. Check with:
```bash
kubectl get deployment cs-1 -n xroad-im -o yaml | grep -A 5 "labels:"
```

If labels don't match, update LoadBalancer service selectors to match actual pod labels.

### Step 4: Configure Central Server

Access Central Server Admin UI via VPN:

```bash
# Via LoadBalancer VIP (recommended)
https://10.0.0.100:4000

# Via kubectl port-forward (alternative)
kubectl port-forward -n xroad-im deployment/cs-1 4000:4000
https://localhost:4000
```

**Initial Configuration**:
1. Login with default credentials (check secrets)
2. Complete Central Server initialization wizard
3. Configure member classes, trust services, etc.
4. Generate Security Server registration codes

### Step 5: Deploy Security Server

Security Server mediates messages between service providers and consumers.

```bash
cd bb-im/x-road-ssx

# Make script executable
chmod +x install_ss_1.sh

# Deploy
./install_ss_1.sh
```

**Verify**:
```bash
kubectl get pods -n xroad-im -l app.kubernetes.io/component=security-server
kubectl get svc -n xroad-im | grep mss-0
```

Expected output:
- Pod: `mss-0-*` in Running state
- Service: `mss-0` (ClusterIP)

### Step 6: Deploy Security Server LoadBalancer Services

```bash
cd metallb-services/bb-im

# Deploy LoadBalancer services
kubectl apply -f xroad-ss-admin-ui-40001-lb.yaml
kubectl apply -f xroad-ss-messaging-5500-lb.yaml
kubectl apply -f xroad-ss-ocsp-5577-lb.yaml
kubectl apply -f xroad-ss-client-8443-lb.yaml
```

**Verify**:
```bash
kubectl get svc -n xroad-im | grep xroad-ss
```

Expected output: All services should have `EXTERNAL-IP: 10.0.0.100` with different ports

**Note**: SS Admin UI uses port **40001** externally (mapping to container port 4000) to avoid conflict with CS Admin UI.

### Step 7: Register Security Server with Central Server

1. **Access Security Server Admin UI**:
   ```
   https://10.0.0.100:40001
   ```

2. **Complete SS Initialization**:
   - Configure server owner
   - Generate signing key
   - Generate authentication certificate request
   - Note the registration code

3. **Register in Central Server** (https://10.0.0.100:4000):
   - Navigate to Security Servers
   - Add new Security Server using registration code
   - Approve registration request

4. **Complete Registration in SS**:
   - Verify Central Server approved registration
   - Configure member subsystems
   - Add service descriptions

## Port Reference

| Service | Port | External Access | Purpose |
|---------|------|-----------------|---------|
| CS Admin UI | 4000 | VPN only | Central Server administration |
| CS Registration | 4001 | VPN + Gateway | Member registration |
| CS Client HTTPS | 8443 | VPN + Gateway | Configuration distribution |
| CS Test CA | 9998 | VPN + Gateway | Test certificate authority |
| SS Admin UI | 40001 | VPN only | Security Server administration |
| SS Messaging | 5500 | VPN + Gateway | Inter-server messaging |
| SS OCSP | 5577 | VPN + Gateway | Certificate validation |
| SS Client HTTPS | 8443 | VPN + Gateway | Service mediation |

**VPN only**: Gateway does NOT forward (LoadBalancer exposes on VIP but gateway iptables blocks)
**VPN + Gateway**: Gateway forwards to downstream clusters (BB-IM-SECOND)

## NetworkPolicy Configuration

NetworkPolicies are already deployed:
```bash
kubectl get networkpolicy -n xroad-im
```

They allow traffic on all X-Road ports from any source (pods, nodes, external) to enable LoadBalancer traffic flow.

## Troubleshooting

### Pod Not Starting
```bash
# Check pod status
kubectl describe pod <pod-name> -n xroad-im

# Check logs
kubectl logs <pod-name> -n xroad-im

# Check events
kubectl get events -n xroad-im --sort-by='.lastTimestamp'
```

### LoadBalancer No External IP
```bash
# Check MetalLB controller
kubectl logs -n metallb-system deployment/controller

# Check IP pool
kubectl get ipaddresspool -n metallb-system -o yaml

# Verify sharing key matches
kubectl get svc -n xroad-im -o yaml | grep "metallb.universe.tf/allow-shared-ip"
```

### Service Has No Endpoints
```bash
# Check service selector
kubectl get svc <service-name> -n xroad-im -o yaml | grep -A 3 "selector:"

# Check pod labels
kubectl get pods -n xroad-im --show-labels

# Verify labels match
kubectl get endpoints <service-name> -n xroad-im
```

**If selectors don't match**: Update LoadBalancer service selectors to match actual Helm-generated pod labels.

### Cannot Access Admin UI
```bash
# Verify LoadBalancer service has endpoints
kubectl get endpoints -n xroad-im | grep admin-ui

# Verify pod is running
kubectl get pods -n xroad-im -l app.kubernetes.io/component=central-server

# Test connectivity from within cluster
kubectl run -it --rm debug --image=curlimages/curl --restart=Never -- curl -k https://cs-1:4000
```

## Post-Deployment

### Optional Components

1. **Example Services** (for testing):
   ```bash
   cd bb-im/example-service
   # Update namespace in templates to xroad-im
   helm install example-service . -n xroad-im
   ```

2. **Auto-Configuration** (hurl scripts):
   ```bash
   cd bb-im/hurl-auto-config
   # Update namespace and endpoints
   # Review and run configuration scripts
   ```

### Backup and Restore

Document backup procedures for:
- Persistent volumes (CS config, lib, dbdata)
- PostgreSQL database dumps
- Certificates and keys
- Configuration snapshots

## Next Steps

1. Configure trust services (CA, TSA, OCSP)
2. Add member organizations
3. Register additional Security Servers
4. Configure service descriptions
5. Test service mediation
6. Set up monitoring and logging
7. Document operational procedures

## References

- Central Server Quick Reference: `bb-im/x-road-csx/QUICK_REFERENCE.md`
- Certificate Management: `bb-im/certs/README.md`
- Hurl Auto-Config: `bb-im/hurl-auto-config/`
- Migration Analysis: `MIGRATION_ANALYSIS.md`
