#!/bin/bash

# Bastion installation script

set -euo pipefail

# Configuration
CHART_NAME="bastion"
NAMESPACE="${NAMESPACE:-default}"
VALUES_FILE="values.yaml"
SECRETS_FILE="secrets.yaml"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

echo "=== Bastion Installation ==="

# Check if Helm is installed
if ! command -v helm &> /dev/null; then
    echo "--- Error: Helm is not installed. Please install Helm 3.0+ first."
    exit 1
fi

# Check if secrets file exists
if [ -f "$SECRETS_FILE" ]; then
    echo "--- Found secrets file: $SECRETS_FILE"
    VALUES_ARGS=("--values" "$VALUES_FILE" "--values" "$SECRETS_FILE")
else
    echo "--- Warning: secrets.yaml not found. Using values.yaml only."
    echo "   Create secrets.yaml to add SSH authorized keys."
    VALUES_ARGS=("--values" "$VALUES_FILE")
fi

# Check if chart is already installed
if helm list -n "$NAMESPACE" | grep -q "$CHART_NAME"; then
    echo "--- Chart $CHART_NAME is already installed. Upgrading..."
    helm upgrade "$CHART_NAME" . \
        "${VALUES_ARGS[@]}" \
        --namespace "$NAMESPACE" \
        --timeout 10m
else
    echo "--- Installing $CHART_NAME..."
    helm install "$CHART_NAME" . \
        "${VALUES_ARGS[@]}" \
        --namespace "$NAMESPACE" \
        --create-namespace \
        --timeout 10m
fi

# Wait for pod to be ready
echo ""
echo "--- Waiting for bastion pod to be ready..."
kubectl wait --namespace "$NAMESPACE" \
    --for=condition=ready pod \
    --selector=app.kubernetes.io/name=bastion \
    --timeout=300s || {
    echo "Warning: Pod readiness check timed out, but continuing..."
    echo "   Check pod status: kubectl get pods -n $NAMESPACE"
}

# Get pod name and service info
POD_NAME=$(kubectl get pods -n "$NAMESPACE" -l app.kubernetes.io/name=bastion -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || echo "")
SERVICE_NAME=$(kubectl get svc -n "$NAMESPACE" -l app.kubernetes.io/name=bastion -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || echo "")

echo ""
echo "=== Installation Status ==="
helm status "$CHART_NAME" -n "$NAMESPACE"

echo ""
echo "=== Pods Status ==="
kubectl get pods -n "$NAMESPACE" -l app.kubernetes.io/name=bastion

echo ""
echo "=== Service Status ==="
kubectl get svc -n "$NAMESPACE" -l app.kubernetes.io/name=bastion

echo ""
echo "=== Installation Complete ==="
echo "Chart: $CHART_NAME"
echo "Namespace: $NAMESPACE"
if [ -n "$POD_NAME" ]; then
    echo ""
    echo "To connect via SSH:"
    echo "  kubectl port-forward -n $NAMESPACE svc/$SERVICE_NAME 22:22"
    echo "  ssh root@localhost"
    echo ""
    echo "Or exec into the pod:"
    echo "  kubectl exec -it -n $NAMESPACE $POD_NAME -- /bin/bash"
fi
echo ""

