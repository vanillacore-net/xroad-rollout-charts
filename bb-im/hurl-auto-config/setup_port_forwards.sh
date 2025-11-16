#!/bin/bash

# Setup port-forwards for Hurl configuration
# Run this script in a separate terminal before running run_config.sh

set -euo pipefail

NAMESPACE="${NAMESPACE:-im-ns}"
CA_NAMESPACE="test-ca"

echo "=== Setting up Port-Forwards for Hurl Configuration ==="
echo ""
echo "This script will create port-forwards for:"
echo "  - CS: localhost:4000 → cs-1:4000"
echo "  - MSS: localhost:4040 → mss-0:4000"
echo "  - CA OCSP: localhost:8888 → ca:8888"
echo "  - CA ACME: localhost:8887 → ca:8887"
echo "  - CA TSA: localhost:8899 → ca:8899"
echo ""
echo "Press Ctrl+C to stop all port-forwards"
echo ""

# Function to cleanup port-forwards on exit
cleanup() {
    echo ""
    echo "Cleaning up port-forwards..."
    kill $CS_PID $MSS_PID $OCSP_PID $ACME_PID $TSA_PID 2>/dev/null || true
    exit 0
}
trap cleanup SIGINT SIGTERM

# Get service names
CS_SVC="cs-1"
MSS_SVC="mss-0"
CA_SVC="ca"

# Start port-forwards in background
echo "Starting port-forwards..."
echo ""

# CS port-forward
# Bind to 0.0.0.0 to allow Docker containers to access via host.docker.internal
echo "  → CS: 0.0.0.0:4000 → $CS_SVC:4000"
kubectl port-forward -n "$NAMESPACE" --address 0.0.0.0 svc/$CS_SVC 4000:4000 > /dev/null 2>&1 &
CS_PID=$!
sleep 1

# MSS port-forward (external port 4040 maps to service port 4040, which targets pod port 4000)
# Bind to 0.0.0.0 to allow Docker containers to access via host.docker.internal
echo "  → MSS: 0.0.0.0:4040 → $MSS_SVC:4040"
kubectl port-forward -n "$NAMESPACE" --address 0.0.0.0 svc/$MSS_SVC 4040:4040 > /dev/null 2>&1 &
MSS_PID=$!
sleep 1

# CA OCSP port-forward
# Bind to 0.0.0.0 to allow Docker containers to access via host.docker.internal
echo "  → CA OCSP: 0.0.0.0:8888 → $CA_SVC:8888"
kubectl port-forward -n "$CA_NAMESPACE" --address 0.0.0.0 svc/$CA_SVC 8888:8888 > /dev/null 2>&1 &
OCSP_PID=$!
sleep 1

# CA ACME port-forward
# Bind to 0.0.0.0 to allow Docker containers to access via host.docker.internal
echo "  → CA ACME: 0.0.0.0:8887 → $CA_SVC:8887"
kubectl port-forward -n "$CA_NAMESPACE" --address 0.0.0.0 svc/$CA_SVC 8887:8887 > /dev/null 2>&1 &
ACME_PID=$!
sleep 1

# CA TSA port-forward
# Bind to 0.0.0.0 to allow Docker containers to access via host.docker.internal
echo "  → CA TSA: 0.0.0.0:8899 → $CA_SVC:8899"
kubectl port-forward -n "$CA_NAMESPACE" --address 0.0.0.0 svc/$CA_SVC 8899:8899 > /dev/null 2>&1 &
TSA_PID=$!
sleep 1

echo ""
echo "✅ All port-forwards started!"
echo ""
echo "PIDs:"
echo "  CS:   $CS_PID (port 4000)"
echo "  MSS:  $MSS_PID (port 4040)"
echo "  OCSP: $OCSP_PID (port 8888)"
echo "  ACME: $ACME_PID (port 8887)"
echo "  TSA:  $TSA_PID (port 8899)"
echo ""
echo "Port-forwards are running. Keep this terminal open."
echo "Press Ctrl+C to stop all port-forwards."
echo ""

# Wait for user interrupt
wait

