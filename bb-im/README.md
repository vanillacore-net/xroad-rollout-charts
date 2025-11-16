# X-Road Information Mediator - Building Block Infrastructure

## Overview

This directory contains the X-Road Central Server and Security Server infrastructure for the Information Mediator Building Block.

The stack provides:
- Central Server (CS) with persistence and database
- Security Server (MSS) with persistence
- Custom certificates for Central Server and Security Server based on self-signed or custom CA
- test-ca used as trust anchor for CA, TSA, and OCSP services
- Automated configuration of applications, certificates, and additional members
- Example APIs (example-service) for service simulation

## Current Deployment

| DNS Name | K8s Namespace | Description |
| --- | --- | --- |
| `acme.im.assembly.govstack.global` | `im-ns` | Trust anchor (ACME) |
| `ocsp.im.assembly.govstack.global` | `im-ns` | Trust anchor (OCSP) |
| `tsa.im.assembly.govstack.global` | `im-ns` | Trust anchor (TSA) |
| `cs.im.assembly.govstack.global` | `im-ns` | X-Road Central Server |
| `mss.im.assembly.govstack.global` | `im-ns` | X-Road Security Server (MSS) |
| `conf.im.assembly.govstack.global` | `im-ns` | Central Server configuration endpoint |

## Service Names

With `serverId` enabled:
- **Central Server**:
  - Deployment name: `cs-1` (from `fullnameOverride: "cs"` + `serverId: "1"`)
  - Service name: `cs-1` (matches deployment name)
  - Pod names: `cs-1-*` (e.g., `cs-1-6f7c7cc56c-7f4js`)
  - Database StatefulSet: `cs-1-db`
  - Secret name: `cs-1`
- **Security Server**:
  - Deployment name: `mss-0` (from `fullnameOverride: "mss"` + `serverId: "0"`)
  - Service name: `mss-0` (matches deployment name)
  - Pod names: `mss-0-*` (e.g., `mss-0-6f7c7cc56c-7f4js`)
  - Secret name: `mss-0`
- **Test CA**: Service name `ca`, Helm release `test-ca`

**Note:** The `serverId` allows running multiple instances (e.g., `cs-1`, `cs-2`, `mss-0`, `mss-1`).

## LoadBalancer Services

- `xroad-cs-admin-lb` - Port 4000 (CS Admin UI) - MetalLB IP: `10.0.0.100`
- `xroad-cs-reg-lb` - Port 4001 (CS Registration) - MetalLB IP: `10.0.0.100`
- `xroad-ss-messaging-lb` - Port 5500 (MSS Messaging) - MetalLB IP: `10.0.0.100`
- `xroad-ss-ocsp-lb` - Port 5577 (MSS OCSP Response) - MetalLB IP: `10.0.0.100`

## Installation & Further Information

- **Central Server Quick Reference**: See `x-road-csx/QUICK_REFERENCE.md`
- **Hurl Auto-Configuration**: See `hurl-auto-config/QUICK_START.md`
- **Certificate Management**: See `certs/README.md`
- **Configuration Summary**: See `CONVERSATION_SUMMARY.md` (may be outdated)

## Helm Charts

- **Central Server**: `x-road-csx/` (Helm release: `xroad-cs1`)
- **Security Server**: `x-road-ssx/` (Helm release: `xroad-ss0`)
- **Test CA**: `test-ca/` (Helm release: `test-ca`)

## Notes

- All services are deployed in the `im-ns` namespace
- MetalLB is used for LoadBalancer services (not AWS NLB)
- Service names use `fullnameOverride` (e.g., `cs`, `mss`), but secret names may differ (e.g., `cs-1`, `mss-0`)
