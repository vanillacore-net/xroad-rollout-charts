#!/bin/bash

# Test CA installation script

set -euo pipefail

# Configuration
CHART_NAME="test-ca"
NAMESPACE="test-ca"
VALUES_FILE="values.yaml"

echo "=== Test CA Installation ==="

# Check if Helm is installed
if ! command -v helm &> /dev/null; then
    echo "--- Error: Helm is not installed. Please install Helm 3.0+ first."
    exit 1
fi

# Check if chart is already installed
if helm list -n "$NAMESPACE" | grep -q "$CHART_NAME"; then
    echo "--- Chart $CHART_NAME is already installed. Upgrading..."
    helm upgrade "$CHART_NAME" . \
        --values "$VALUES_FILE" \
        --namespace "$NAMESPACE" \
        --debug \
        --timeout 15m
else
    echo "--- Installing $CHART_NAME..."
    helm install "$CHART_NAME" . \
        --values "$VALUES_FILE" \
        --namespace "$NAMESPACE" \
        --create-namespace \
        --debug \
        --timeout 15m
fi

# Wait for pod to be ready (instead of waiting for LoadBalancer IP)
echo ""
echo "--- Waiting for test-ca pod to be ready..."
kubectl wait --namespace "$NAMESPACE" \
    --for=condition=ready pod \
    --selector=app.kubernetes.io/component=test-ca \
    --timeout=300s || {
    echo "⚠️  Warning: Pod readiness check timed out, but continuing..."
    echo "   Check pod status: kubectl get pods -n $NAMESPACE"
}

# Check installation status
echo ""
echo "=== Installation Status ==="
helm status "$CHART_NAME" -n "$NAMESPACE"

echo ""
echo "=== Pods Status ==="
kubectl get pods -n "$NAMESPACE"

echo ""
echo "=== Services Status ==="
kubectl get svc -n "$NAMESPACE"

echo ""
echo "=== Installation Complete ==="
echo "Chart: $CHART_NAME"
echo "Namespace: $NAMESPACE"
echo ""
echo "To check logs:"
echo "  kubectl logs -f deployment/testca -n $NAMESPACE"
echo ""