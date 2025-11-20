# X-Road Information Mediator Migration Analysis

## Overview

Downloaded X-Road configuration from `karsten@167.71.79.238:im-karsten` containing production-ready Helm charts and configurations for:
- Central Server (CS)
- Security Server (MSS)
- Test CA
- Auto-configuration tooling
- Example services

## Current Configuration vs Required Changes

### 1. Namespace Mismatch ⚠️ CRITICAL

**Current**: `im-ns`
**Required**: `xroad-im`

**Impact**: All manifests, Helm charts, and scripts reference `im-ns`. Our LoadBalancer services and NetworkPolicies use `xroad-im`.

**Files to Update**:
- `bb-im/x-road-csx/install_cs_1.sh` (line 10)
- `bb-im/x-road-ssx/install_ss_0.sh` / `install_ss_1.sh`
- All Helm templates that hardcode namespace

### 2. Service Type Mismatch ⚠️ CRITICAL

**Current**: `type: ClusterIP` with Ingress
**Required**: `type: LoadBalancer` with MetalLB

**Reason**:
- Current setup uses Traefik Ingress for external access
- Our infrastructure uses MetalLB LoadBalancer services
- We already have LoadBalancer manifests in `rollout/k8s/bb-im/xroad/` and `rollout/kubernetes/bb-im/`

**Solution**: Either:
1. **Option A** (Recommended): Keep Helm charts with ClusterIP, deploy our LoadBalancer services separately
2. **Option B**: Modify Helm chart values to use LoadBalancer type

### 3. DNS Configuration

**Current**: Uses `im.assembly.govstack.global` TLD
- `cs.im.assembly.govstack.global` (Central Server)
- `mss.im.assembly.govstack.global` (Security Server)
- `acme.im.assembly.govstack.global` (ACME)
- `ocsp.im.assembly.govstack.global` (OCSP)
- `tsa.im.assembly.govstack.global` (TSA)

**Our Setup**: Uses IP-based access via MetalLB VIP `10.0.0.100`
- Services accessed via VPN connection to cluster
- No external DNS configured

**Action**:
- Disable Ingress in Helm values (`Ingress.enabled: false`)
- Access services via LoadBalancer IPs or port-forwards

### 4. Pod Labels

**Current Helm Charts Use**:
- `app.kubernetes.io/name: xroad-central-server`
- `app.kubernetes.io/component: central-server`

**Our LoadBalancer Services Use**:
- `app: sandbox-xroad-cs` (Central Server)
- `app: sandbox-xroad-ss1` (Security Server)

**Impact**: Service selectors won't match pods

**Solution**:
1. Update Helm chart templates to add legacy labels
2. OR update our LoadBalancer service selectors to match Helm labels

### 5. Component Mapping

| Component | Helm Chart | Namespace | Current Name | Ports |
|-----------|-----------|-----------|--------------|-------|
| Central Server | `x-road-csx/` | `xroad-im` | `cs-1` | 4000, 4001, 8443, 9998 |
| Security Server | `x-road-ssx/` | `xroad-im` | `mss-0` | 4000, 5500, 5577, 8443 |
| Test CA | `test-ca/` | `xroad-im` | `test-ca` | 80, 443 (ACME, OCSP, TSA) |
| PostgreSQL | (embedded in CS chart) | `xroad-im` | `cs-1-db` | 5432 |

## Deployment Strategy

### Phase 1: Test CA Deployment
Test CA must be deployed FIRST as it provides trust anchors for CS and SS.

```bash
cd bb-im/test-ca
# Update namespace in install.sh
helm install test-ca . --namespace xroad-im --create-namespace
```

### Phase 2: Central Server Deployment

```bash
cd bb-im/x-road-csx
# Update values.yaml:
#   - Set Ingress.enabled: false
#   - Keep Service.type: ClusterIP
# Update install_cs_1.sh namespace to xroad-im
./install_cs_1.sh
```

### Phase 3: LoadBalancer Services
Deploy our existing LoadBalancer services:

```bash
kubectl apply -f rollout/kubernetes/bb-im/xroad-cs-admin-ui-4000-lb.yaml
kubectl apply -f rollout/kubernetes/bb-im/xroad-cs-admin-4001-lb.yaml
kubectl apply -f rollout/kubernetes/bb-im/xroad-cs-client-8443-lb.yaml
kubectl apply -f rollout/kubernetes/bb-im/xroad-cs-testca-9998-lb.yaml
```

### Phase 4: Security Server Deployment

```bash
cd bb-im/x-road-ssx
# Update values.yaml:
#   - Set Ingress.enabled: false
#   - Keep Service.type: ClusterIP
# Update install_ss_0.sh namespace to xroad-im
./install_ss_0.sh
```

### Phase 5: Security Server LoadBalancer Services

```bash
kubectl apply -f rollout/kubernetes/bb-im/xroad-ss-admin-ui-4000-lb.yaml
kubectl apply -f rollout/kubernetes/bb-im/xroad-ss-messaging-5500-lb.yaml
kubectl apply -f rollout/kubernetes/bb-im/xroad-ss-ocsp-5577-lb.yaml
kubectl apply -f rollout/kubernetes/bb-im/xroad-ss-client-8443-lb.yaml
```

## Required Changes Summary

### Immediate (Blocking Deployment):
1. ✅ Change namespace from `im-ns` to `xroad-im` in all scripts
2. ✅ Disable Ingress in Helm values files
3. ✅ Verify pod label compatibility with LoadBalancer service selectors

### Post-Deployment (Configuration):
4. Update hurl auto-configuration scripts for namespace
5. Configure Central Server via admin UI (port 4000)
6. Register Security Server with Central Server
7. Configure test services

### Optional (Future Enhancement):
8. Set up external DNS if needed
9. Configure proper TLS certificates (currently using test CA)
10. Enable Ingress if desired (would complement LoadBalancer services)

## Files Requiring Modification

### Critical Path Files:
- `bb-im/x-road-csx/install_cs_1.sh` - Update NAMESPACE variable
- `bb-im/x-road-csx/values.yaml` - Disable Ingress
- `bb-im/x-road-ssx/install_ss_0.sh` - Update NAMESPACE variable
- `bb-im/x-road-ssx/values.yaml` - Disable Ingress
- `bb-im/test-ca/install.sh` - Update namespace

### Secondary Files:
- `bb-im/hurl-auto-config/` - Update namespace in configuration scripts
- `bb-im/example-service/` - Update namespace for test services

## Pod Label Verification Needed

Check what labels the Helm charts actually create:
```bash
# After deploying CS
kubectl get deployment cs-1 -n xroad-im -o yaml | grep -A 10 "labels:"

# After deploying SS
kubectl get deployment mss-0 -n xroad-im -o yaml | grep -A 10 "labels:"
```

Then update LoadBalancer service selectors to match if needed.

## Risk Assessment

### High Risk:
- Namespace mismatch will cause deployment failures
- Service selector mismatch will leave LoadBalancers with no endpoints

### Medium Risk:
- Certificate configuration might need adjustment for new namespace
- Auto-configuration scripts may need namespace updates

### Low Risk:
- DNS names won't resolve but IP access works
- Ingress disabled won't affect MetalLB LoadBalancer access

## Next Steps

1. Create modified installation scripts with correct namespace
2. Test deploy in order: Test CA → CS → CS LoadBalancers → SS → SS LoadBalancers
3. Verify pod labels match LoadBalancer selectors
4. Document actual deployment for future reference
5. Update auto-configuration scripts for namespace
