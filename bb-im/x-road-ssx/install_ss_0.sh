#!/bin/bash

# X-Road Service Server (SS) Installation Script

set -euo pipefail

# Configuration
INSTANCE_ID="0"
CHART_NAME="xroad-ss${INSTANCE_ID}"
NAMESPACE="im-ns"
VALUES_FILE="values.yaml"
CERT_DIR="certs"

echo "=== X-Road Security Server (SS) Installation ==="

# Check if Helm is installed
if ! command -v helm &> /dev/null; then
    echo "--- Error: Helm is not installed. Please install Helm 3.0+ first."
    exit 1
fi

# Check if certificate files exist
if [ ! -d "$CERT_DIR" ]; then
    echo "--- Error: Certificate directory $CERT_DIR not found!"
    echo "Please create the directory and add your certificate files:"
    echo "  mkdir -p $CERT_DIR"
    echo "  # Add certificate.crt and certificate.key files"
    exit 1
fi

if [ ! -f "$CERT_DIR/certificate-ss.crt" ] || [ ! -f "$CERT_DIR/certificate-ss.key" ] || [ ! -f "$CERT_DIR/certificate-ss-ui.p12" ] || [ ! -f "$CERT_DIR/certificate-ss-internal.p12" ]; then
    echo "--- Error: Certificate files not found in $CERT_DIR/"
    echo "Required files:"
    echo "  - $CERT_DIR/certificate-ss.crt"
    echo "  - $CERT_DIR/certificate-ss.key"
    echo "  - $CERT_DIR/certificate-ss-ui.p12"
    echo "  - $CERT_DIR/certificate-ss-internal.p12"
    exit 1
fi

echo "--- ✓ Certificate files found"

# Update Helm dependencies
# echo "--- Updating Helm dependencies..."
# helm dependency update .

# Check if chart is already installed
if helm list -n "$NAMESPACE" | grep -q "$CHART_NAME"; then
    echo "--- Chart $CHART_NAME is already installed. Upgrading..."
    helm upgrade "$CHART_NAME" . \
        --values "$VALUES_FILE" \
        --set-string security-server.serverId="$INSTANCE_ID" \
        --namespace "$NAMESPACE" \
        --debug \
        --timeout 15m
else
    echo "--- Installing $CHART_NAME..."
    helm install "$CHART_NAME" . \
        --values "$VALUES_FILE" \
        --set-string security-server.serverId="$INSTANCE_ID" \
        --namespace "$NAMESPACE" \
        --create-namespace \
        --debug \
        --timeout 15m
fi

# Wait for pod to be ready (instead of waiting for LoadBalancer IP)
echo ""
echo "--- Waiting for MSS pod to be ready..."
kubectl wait --namespace "$NAMESPACE" \
    --for=condition=ready pod \
    --selector=app.kubernetes.io/component=security-server \
    --timeout=600s || {
    echo "⚠️  Warning: Pod readiness check timed out, but continuing..."
    echo "   Check pod status: kubectl get pods -n $NAMESPACE"
    echo "   Check pod logs: kubectl logs -n $NAMESPACE -l app.kubernetes.io/component=security-server"
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
echo "  kubectl logs -f deployment/$CHART_NAME -n $NAMESPACE"
echo ""
