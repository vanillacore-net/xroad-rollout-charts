#!/bin/bash

# X-Road Hurl Auto Config Provisioning Installation

set -euo pipefail

# Configuration
CHART_NAME="xroad-hurl"
NAMESPACE="im-ns"
VALUES_FILE="values.yaml"
CERT_DIR="ca"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPT="get-certificates.sh"

echo "=== X-Road Hurl Auto Config Provisioning Installation ==="

# Check if Helm is installed
if ! command -v helm &> /dev/null; then
    echo "--- Error: Helm is not installed. Please install Helm 3.0+ first."
    exit 1
fi

cd "$SCRIPT_DIR"

echo "--- Obtaining certificates from test-ca..."

if [ ! -x "$SCRIPT" ]; then
  chmod +x "$SCRIPT"
  echo "chmod +x $SCRIPT"
fi
./"$SCRIPT"

# Check if certificate files exist
if [ ! -d "$CERT_DIR" ]; then
    echo "--- Error: Certificate directory $CERT_DIR not found!"
    echo "Please create the directory and add your certificate files:"
    echo "  mkdir -p $CERT_DIR"
    echo "  # Expected files: ca.pem ocsp.pem tsa.pem"
    echo "  # These can be found in test-ca container: /home/ca/certs/"
    echo "  # Obtain them automatically via $SCRIPT"
    exit 1
fi

# Create hurl-cert secret from certificate files
echo "--- Creating hurl-cert secret from certificate files..."
kubectl create secret generic hurl-cert \
    --from-file=ca.pem="${CERT_DIR}/ca.pem" \
    --from-file=ocsp.pem="${CERT_DIR}/ocsp.pem" \
    --from-file=tsa.pem="${CERT_DIR}/tsa.pem" \
    --namespace="$NAMESPACE" \
    --dry-run=client -o yaml | kubectl apply -f -

# Update Helm dependencies
echo "--- Updating Helm dependencies..."
helm dependency update .

# Check if chart is already installed
if helm list -n "$NAMESPACE" | grep -q "$CHART_NAME"; then
    echo "--- Chart $CHART_NAME is already installed. Upgrading..."
    helm upgrade "$CHART_NAME" . \
        --values "$VALUES_FILE" \
        --namespace "$NAMESPACE" \
        --wait \
        --debug \
        --timeout 15m \
        --atomic
else
    echo "--- Installing $CHART_NAME..."
    helm install "$CHART_NAME" . \
        --values "$VALUES_FILE" \
        --namespace "$NAMESPACE" \
        --create-namespace \
        --wait \
        --debug \
        --timeout 15m \
        --atomic
fi

# Check installation status
echo ""
echo "=== Installation Status ==="
helm status "$CHART_NAME" -n "$NAMESPACE"

echo ""
echo "Available config jobs:"
kubectl get cronjob -n $NAMESPACE

echo ""
echo "To trigger automatic config provisioning run:"
echo "kubectl create job --from=cronjob/<cronjob-name> <manual-job-name>"
echo ""
echo "=== Installation Complete ==="
echo "Chart: $CHART_NAME"
echo "Namespace: $NAMESPACE"

