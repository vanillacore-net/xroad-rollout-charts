#!/bin/bash

set -euo pipefail

NAMESPACE="${NAMESPACE:-im-ns}"
CS_SECRET="${CS_SECRET:-cs-1}"
MSS_SECRET="${MSS_SECRET:-mss-0}"

echo "CS password (user: xrd):"
kubectl get secret -n "$NAMESPACE" "$CS_SECRET" -o jsonpath="{.data.password}" | base64 -d
echo ""

echo "MSS password (user: xrd):"
kubectl get secret -n "$NAMESPACE" "$MSS_SECRET" -o jsonpath="{.data.password}" | base64 -d
echo ""

