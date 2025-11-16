#!/bin/bash

set -euo pipefail

# Script directory (where certificates will be saved)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CERT_DIR="${SCRIPT_DIR}/ca"

# Configuration
NAMESPACE="test-ca"
POD_NAME=$(kubectl get pods -n test-ca --no-headers | grep "ca-" | awk '{print $1}')
if [ -z "$POD_NAME" ]; then
    echo "--- No pod found with name starting with 'ca-' in namespace '$NAMESPACE'"
    exit 1
fi

echo "--- Found pod: $POD_NAME"

# Create ca directory if it doesn't exist
mkdir -p "$CERT_DIR"

echo "--- Fetching CA certificates to $CERT_DIR/"

# Copy CA certificates for hurl tests (relative path: ca/*)
# Hurl expects: certificate: file,ca/ca.pem; (relative to Hurl file location)
kubectl exec -n $NAMESPACE $POD_NAME -c test-ca -- cat /home/ca/certs/ca.pem > "${CERT_DIR}/ca.pem"
kubectl exec -n $NAMESPACE $POD_NAME -c test-ca -- cat /home/ca/certs/ocsp.pem > "${CERT_DIR}/ocsp.pem"
kubectl exec -n $NAMESPACE $POD_NAME -c test-ca -- cat /home/ca/certs/tsa.pem > "${CERT_DIR}/tsa.pem"

echo "✓ Certificates saved:"
echo "  - ${CERT_DIR}/ca.pem"
echo "  - ${CERT_DIR}/ocsp.pem"
echo "  - ${CERT_DIR}/tsa.pem" 
