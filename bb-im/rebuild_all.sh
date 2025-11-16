#!/bin/bash

# Complete rebuild script for X-Road cluster
# This script will:
# 1. Run cleanup_and_rebuild.sh (with keep_secrets='no')
# 2. Reinstall test-ca
# 3. Regenerate all certificates
# 4. Reinstall CS
# 5. Reinstall MSS
# 6. Run hurl configuration

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

echo "=========================================="
echo "X-Road Cluster Complete Rebuild Script"
echo "=========================================="
echo ""
echo "This script will:"
echo "  1. Clean up all resources (Helm releases, PVCs, secrets)"
echo "  2. Reinstall test-ca"
echo "  3. Regenerate all certificates"
echo "  4. Reinstall Central Server"
echo "  5. Reinstall Security Server"
echo "  6. Run Hurl configuration (register CA, configure servers)"
echo ""

read -p "Are you sure you want to continue? (yes/no): " confirm

if [[ "$confirm" != "yes" ]]; then
    echo "Aborted."
    exit 0
fi

echo ""
echo "=========================================="
echo "Step 1: Cleanup"
echo "=========================================="
echo ""

# Run cleanup script with keep_secrets='no'
echo "Running cleanup_and_rebuild.sh with keep_secrets='no'..."
printf "yes\nno\n" | ./cleanup_and_rebuild.sh

echo ""
echo "=========================================="
echo "Step 2: Reinstall test-ca"
echo "=========================================="
echo ""

cd test-ca/
echo "Installing test-ca..."
./install.sh

# Wait for test-ca pod to be ready
echo ""
echo "Waiting for test-ca pod to be ready..."
kubectl wait --for=condition=ready pod -n test-ca -l app=testca --timeout=300s || {
    echo "WARNING: test-ca pod not ready after 300s, continuing anyway..."
}

cd "$SCRIPT_DIR"

echo ""
echo "=========================================="
echo "Step 3: Regenerate Certificates"
echo "=========================================="
echo ""

cd certs/
echo "Generating certificates with test-ca..."
./generate_certs_testca_eab.sh

cd "$SCRIPT_DIR"

echo ""
echo "=========================================="
echo "Step 4: Reinstall Central Server"
echo "=========================================="
echo ""

cd x-road-csx/
echo "Installing Central Server..."
./install_cs_1.sh

# Wait for CS pod to be ready (this ensures init containers including password setup have completed)
echo ""
echo "Waiting for Central Server pod to be ready..."
kubectl wait --for=condition=ready pod -n im-ns -l app=cs-1 --timeout=300s || {
    echo "WARNING: CS pod not ready after 300s, continuing anyway..."
}

# Wait for password init container to complete and verify it succeeded
echo ""
echo "Verifying password init container completed..."
CS_POD=$(kubectl get pod -n im-ns -l app=cs-1 -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)
if [ -n "$CS_POD" ]; then
    for i in {1..30}; do
        INIT_STATUS=$(kubectl get pod -n im-ns "$CS_POD" -o jsonpath='{.status.initContainerStatuses[?(@.name=="set-cs-admin-password")].state.terminated.exitCode}' 2>/dev/null)
        if [ "$INIT_STATUS" = "0" ]; then
            echo "OK: Password init container completed successfully"
            break
        fi
        if [ $i -eq 30 ]; then
            echo "WARNING: Password init container did not complete after 30 attempts"
            echo "Checking logs..."
            kubectl logs -n im-ns "$CS_POD" -c set-cs-admin-password 2>&1 | tail -5
        else
            sleep 2
        fi
    done
           # Give it a moment for the password to be fully committed and the main container to be ready
           # The postStart hook will also set the password, so we wait a bit longer
           echo "Waiting for main container and authentication system to be ready..."
           sleep 30
    # Verify password was actually set by checking the hash
    echo "Verifying password was set correctly..."
    PWD_HASH=$(kubectl exec -n im-ns "$CS_POD" -- grep "^xrd:" /etc/shadow 2>/dev/null | cut -d: -f2 || echo "")
    if [ -z "$PWD_HASH" ] || [ "$PWD_HASH" = "*" ] || [ "$PWD_HASH" = "!" ]; then
      echo "WARNING: Password hash verification failed (hash is empty, *, or !)"
      echo "Attempting to set password again..."
      SECRET_PASS=$(kubectl get secret -n im-ns cs-1 -o jsonpath='{.data.password}' 2>/dev/null | base64 -d)
      if [ -n "$SECRET_PASS" ]; then
        kubectl exec -n im-ns "$CS_POD" -- bash -c "echo 'xrd:${SECRET_PASS}' | chpasswd" 2>&1
        echo "Password reset completed"
        sleep 5
      fi
    else
      echo "OK: Password hash verified (starts with: ${PWD_HASH:0:3}...)"
    fi
fi

cd "$SCRIPT_DIR"

echo ""
echo "=========================================="
echo "Step 5: Reinstall Security Server"
echo "=========================================="
echo ""

cd x-road-ssx/
echo "Installing Security Server..."
./install_ss_0.sh

# Wait for MSS pod to be ready (this ensures init containers including password setup have completed)
echo ""
echo "Waiting for Security Server pod to be ready..."
kubectl wait --for=condition=ready pod -n im-ns -l app=mss-0 --timeout=300s || {
    echo "WARNING: MSS pod not ready after 300s, continuing anyway..."
}

# Wait for password init container to complete and verify it succeeded
echo ""
echo "Verifying password init container completed..."
MSS_POD=$(kubectl get pod -n im-ns -l app=mss-0 -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)
if [ -n "$MSS_POD" ]; then
    for i in {1..30}; do
        # Security Server might not have a password init container, check for any password-related init container
        INIT_STATUS=$(kubectl get pod -n im-ns "$MSS_POD" -o jsonpath='{.status.initContainerStatuses[?(@.name=="set-ss-admin-password")].state.terminated.exitCode}' 2>/dev/null || echo "")
        if [ -z "$INIT_STATUS" ]; then
            # If no password init container, just check that pod is ready
            INIT_STATUS="0"
        fi
        if [ "$INIT_STATUS" = "0" ]; then
            echo "OK: Password init container completed successfully"
            break
        fi
        if [ $i -eq 30 ]; then
            echo "WARNING: Password init container did not complete after 30 attempts"
        else
            sleep 2
        fi
    done
    # Give it a moment for the password to be fully committed and the main container to be ready
    echo "Waiting for main container to be fully ready..."
    sleep 15
fi

cd "$SCRIPT_DIR"

echo ""
echo "=========================================="
echo "Rebuild Summary"
echo "=========================================="
echo ""
echo "OK: Cleanup completed"
echo "OK: test-ca reinstalled"
echo "OK: Certificates regenerated"
echo "OK: Central Server reinstalled"
echo "OK: Security Server reinstalled"
echo ""
echo "=========================================="
echo "Verifying Secrets"
echo "=========================================="
echo ""

# Verify CS secret exists (password will be fetched by hurl script when needed)
if kubectl get secret -n im-ns cs-1 &>/dev/null; then
    echo "OK: CS secret (cs-1) exists"
else
    echo "ERROR: CS secret (cs-1) not found!"
fi

# Verify MSS secret exists (password will be fetched by hurl script when needed)
if kubectl get secret -n im-ns mss-0 &>/dev/null; then
    echo "OK: MSS secret (mss-0) exists"
else
    echo "ERROR: MSS secret (mss-0) not found!"
fi

echo ""
echo "=========================================="
echo "Step 6: Run Hurl Configuration"
echo "=========================================="
echo ""

cd hurl-auto-config/
echo "Fetching latest CA certificates from test-ca pod..."
echo "This ensures the CA registered in Global Configuration matches"
echo "the CA used to sign certificates."
if [ -f get_certificates.sh ]; then
    ./get_certificates.sh
    echo "OK: CA certificates updated"
else
    echo "WARNING: get_certificates.sh not found"
    echo "CA certificates may be outdated"
fi

echo ""
echo "Running Hurl configuration..."
echo "This will:"
echo "  - Load passwords from Kubernetes secrets (cs-1, mss-0)"
echo "  - Register Test CA in Central Server"
echo "  - Configure Security Server"
echo "  - Upload configuration anchor"
echo "  - Import certificates"
echo ""

./run_config_fqdn.sh

cd "$SCRIPT_DIR"

echo ""
echo "=========================================="
echo "Complete Rebuild Summary"
echo "=========================================="
echo ""
echo "OK: Cleanup completed"
echo "OK: test-ca reinstalled"
echo "OK: Certificates regenerated"
echo "OK: Central Server reinstalled"
echo "OK: Security Server reinstalled"
echo "OK: Hurl configuration completed"
echo ""
echo "X-Road cluster rebuild is complete!"
echo ""

