#!/bin/bash

set -euo pipefail

NAMESPACE="${NAMESPACE:-im-ns}"
CS_SECRET="${CS_SECRET:-cs-1}"
MSS_SECRET="${MSS_SECRET:-mss-0}"

# CS
CS_PASSWORD=$(kubectl get secret -n "$NAMESPACE" "$CS_SECRET" -o jsonpath="{.data.password}" | base64 -d)
CS_POD=$(kubectl get pods -n "$NAMESPACE" -l app.kubernetes.io/component=central-server -o jsonpath='{.items[0].metadata.name}')
echo "xrd:${CS_PASSWORD}" | kubectl exec -i -n "$NAMESPACE" "$CS_POD" -- chpasswd

# MSS
MSS_PASSWORD=$(kubectl get secret -n "$NAMESPACE" "$MSS_SECRET" -o jsonpath="{.data.password}" | base64 -d)
MSS_POD=$(kubectl get pods -n "$NAMESPACE" -l app.kubernetes.io/component=security-server -o jsonpath='{.items[0].metadata.name}')
echo "xrd:${MSS_PASSWORD}" | kubectl exec -i -n "$NAMESPACE" "$MSS_POD" -- chpasswd
