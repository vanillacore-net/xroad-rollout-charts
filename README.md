# X-Road Rollout Charts

X-Road deployment configurations for Kubernetes with MetalLB LoadBalancer support. This repository contains Helm charts and MetalLB service definitions for deploying X-Road Information Mediator Building Block to GovStack clusters.

## Repository Overview

This repository provides a complete X-Road deployment solution adapted for Kubernetes clusters with MetalLB load balancing, designed for multi-cluster deployments with network isolation and VPN access.

### Key Features

- **Helm Charts**: Ready-to-deploy X-Road components (Central Server, Security Server, Test CA)
- **MetalLB Integration**: LoadBalancer service definitions for external access
- **Multi-Cluster Support**: Separate configurations for BB-IM (Central Server) and BB-IM-SECOND (Security Server)
- **Network Policies**: Security-focused network isolation
- **VPN-Based Access**: Designed for secure VPN-only administrative access

## Repository Structure

```
xroad-rollout-charts/
├── docs/                           # Documentation
│   ├── deployment-guide.md         # Complete deployment instructions
│   └── migration-analysis.md       # Migration notes and analysis
├── metallb-services/               # MetalLB LoadBalancer definitions
│   ├── bb-im/                      # Central Server LoadBalancers (5 files)
│   │   ├── 06-network-policies.yaml
│   │   ├── xroad-cs-admin-ui-4000-lb.yaml
│   │   ├── xroad-cs-admin-4001-lb.yaml
│   │   ├── xroad-cs-client-8443-lb.yaml
│   │   └── xroad-cs-testca-9998-lb.yaml
│   └── bb-im-second/               # Security Server LoadBalancers (5 files)
│       ├── 06-network-policies.yaml
│       ├── xroad-ss-admin-ui-4000-lb.yaml
│       ├── xroad-ss-client-8443-lb.yaml
│       ├── xroad-ss-messaging-5500-lb.yaml
│       └── xroad-ss-ocsp-5577-lb.yaml
├── bb-im/                          # BB-IM Helm charts and configs
│   ├── test-ca/                    # Test Certificate Authority
│   ├── x-road-csx/                 # Central Server Helm chart
│   ├── x-road-ssx/                 # Security Server Helm chart
│   ├── hurl-auto-config/           # Automated configuration scripts
│   └── example-service/            # Example API services
├── add-im/                         # Additional IM configurations
└── bastion/                        # Bastion host Helm chart
```

## Quick Start

### Prerequisites

1. **Kubernetes Cluster**: Running cluster with kubectl access
2. **MetalLB**: Installed and configured with IP address pool
3. **Helm 3**: For deploying Helm charts
4. **VPN Access**: For administrative access to X-Road components

### Deployment Overview

**For complete deployment instructions, see [docs/deployment-guide.md](docs/deployment-guide.md)**

#### BB-IM Cluster (Central Server)

1. Deploy Helm charts (Test CA, Central Server)
2. Deploy MetalLB LoadBalancer services from `metallb-services/bb-im/`
3. Access Central Server at `https://10.0.0.100:4000`

#### BB-IM-SECOND Cluster (Security Server)

1. Deploy Helm charts (Security Server)
2. Deploy MetalLB LoadBalancer services from `metallb-services/bb-im-second/`
3. Access Security Server at `https://10.0.0.100:40001`

## Architecture

### Two-Step Deployment Pattern

X-Road deployment uses a **two-step process**:

1. **Step 1: Helm Chart Deployment** - Creates pods, ClusterIP services (internal only)
2. **Step 2: MetalLB LoadBalancers** - Creates LoadBalancer services for external access

**Why two steps?** Helm charts create ClusterIP services with no external access. Separate LoadBalancer services provide flexibility and avoid modifying upstream Helm charts.

### Port Reference

| Component | Port | Access | Purpose |
|-----------|------|--------|---------|
| **BB-IM (Central Server)** |
| CS Admin UI | 4000 | VPN only | Central Server administration |
| CS Registration | 4001 | VPN + Gateway | Security Server registration |
| CS Client HTTPS | 8443 | VPN + Gateway | Configuration distribution |
| CS Test CA | 9998 | VPN + Gateway | Test certificate authority |
| **BB-IM-SECOND (Security Server)** |
| SS Admin UI | 40001 | VPN only | Security Server administration |
| SS Messaging | 5500 | VPN + Gateway | Inter-server messaging |
| SS OCSP | 5577 | VPN + Gateway | Certificate validation |
| SS Client HTTPS | 8443 | VPN + Gateway | Service mediation |

**Access Types**:
- **VPN only**: LoadBalancer exposes on VIP, gateway does NOT forward
- **VPN + Gateway**: LoadBalancer exposes on VIP, gateway forwards to public

## Documentation

- **[Deployment Guide](docs/deployment-guide.md)**: Complete step-by-step deployment instructions
- **[Migration Analysis](docs/migration-analysis.md)**: Migration notes from upstream

## Key Differences from Upstream

| Aspect | Upstream | This Repository |
|--------|----------|-----------------|
| Namespace | `im-ns` | `xroad-im` |
| External Access | Ingress (Traefik) | LoadBalancer (MetalLB) |
| DNS | `*.im.assembly.govstack.global` | IP-based (10.0.0.100) |
| Service Type | ClusterIP + Ingress | ClusterIP + LoadBalancer |
| Access Method | Public DNS | VPN + LoadBalancer VIP |

## Troubleshooting

See [docs/deployment-guide.md](docs/deployment-guide.md) for comprehensive troubleshooting guidance.

## License

X-Road is licensed under the MIT License. See original X-Road repository for details.
