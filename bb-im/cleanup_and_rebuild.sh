#!/bin/bash

# Complete cleanup and rebuild script for X-Road cluster
# This script will:
# 1. Delete all Helm releases (CS, MSS, CA)
# 2. Delete all PersistentVolumeClaims
# 3. Delete all application secrets (keeping test-ca-trust if needed)
# 4. Provide instructions for certificate regeneration

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

echo "=========================================="
echo "X-Road Cluster Cleanup and Rebuild Script"
echo "=========================================="
echo ""
echo "WARNING: This will delete ALL data!"
echo "   - Helm releases (xroad-cs1, xroad-ss0, test-ca)"
echo "   - PersistentVolumeClaims (all CS, MSS, CA data)"
echo "   - Application secrets (CS, MSS certificates and passwords)"
echo ""
read -p "Are you sure you want to continue? (yes/no): " confirm

if [[ "$confirm" != "yes" ]]; then
    echo "Aborted."
    exit 0
fi

echo ""
read -p "Keep application secrets (CS, MSS certificates and passwords)? (yes/no) [default: no]: " keep_secrets
KEEP_SECRETS="${keep_secrets:-no}"

echo ""
echo "=== Step 1: Deleting Helm Releases ==="
echo ""

# Delete CS release
if helm list -n im-ns | grep -q "xroad-cs1"; then
    echo "Deleting xroad-cs1 release..."
    helm uninstall xroad-cs1 -n im-ns || echo "  (already deleted or not found)"
else
    echo "xroad-cs1 release not found"
fi

# Delete MSS release
if helm list -n im-ns | grep -q "xroad-ss0"; then
    echo "Deleting xroad-ss0 release..."
    helm uninstall xroad-ss0 -n im-ns || echo "  (already deleted or not found)"
else
    echo "xroad-ss0 release not found"
fi

# Delete CA release
if helm list -n test-ca | grep -q "test-ca"; then
    echo "Deleting test-ca release..."
    helm uninstall test-ca -n test-ca || echo "  (already deleted or not found)"
else
    echo "test-ca release not found"
fi

echo ""
echo "=== Step 2: Waiting for pods to terminate ==="
echo "Waiting 30 seconds for pods to terminate..."
sleep 30

echo ""
echo "=== Step 3: Deleting PersistentVolumeClaims ==="
echo ""

# Delete CS PVCs
for pvc in pvc-cs-1-config pvc-cs-1-lib pvc-cs-1-pgdata; do
    if kubectl get pvc -n im-ns "$pvc" &>/dev/null; then
        echo "Deleting PVC: $pvc"
        kubectl delete pvc -n im-ns "$pvc" --wait=false || echo "  (failed to delete)"
    else
        echo "PVC $pvc not found"
    fi
done

# Delete MSS PVCs
for pvc in pvc-mss-0-config pvc-mss-0-dbdata pvc-mss-0-lib; do
    if kubectl get pvc -n im-ns "$pvc" &>/dev/null; then
        echo "Deleting PVC: $pvc"
        kubectl delete pvc -n im-ns "$pvc" --wait=false || echo "  (failed to delete)"
    else
        echo "PVC $pvc not found"
    fi
done

# Delete CA PVC
if kubectl get pvc -n test-ca pvc-ca-home &>/dev/null; then
    echo "Deleting PVC: pvc-ca-home"
    kubectl delete pvc -n test-ca pvc-ca-home --wait=false || echo "  (failed to delete)"
else
    echo "PVC pvc-ca-home not found"
fi

echo ""
echo "=== Step 4: Deleting Application Secrets ==="
echo ""

if [[ "$KEEP_SECRETS" == "yes" ]]; then
    echo "Keeping application secrets (as requested)"
    echo "  - CS secrets (cs-1, cs-1-cert) will be preserved"
    echo "  - MSS secrets (mss-0, mss-0-cert) will be preserved"
    echo "  - test-ca-trust secret is always preserved"
else
    # Delete CS secrets (but keep test-ca-trust)
    for secret in cs-1 cs-1-cert; do
        if kubectl get secret -n im-ns "$secret" &>/dev/null; then
            echo "Deleting secret: $secret"
            kubectl delete secret -n im-ns "$secret" || echo "  (failed to delete)"
        else
            echo "Secret $secret not found"
        fi
    done

    # Delete MSS secrets
    for secret in mss-0 mss-0-cert; do
        if kubectl get secret -n im-ns "$secret" &>/dev/null; then
            echo "Deleting secret: $secret"
            kubectl delete secret -n im-ns "$secret" || echo "  (failed to delete)"
        else
            echo "Secret $secret not found"
        fi
    done
fi

echo ""
echo "=== Step 5: Cleanup Summary ==="
echo ""
echo "Cleanup completed!"
echo ""
echo "Remaining resources:"
echo "  - test-ca-trust secret (always kept for CA trust)"
if [[ "$KEEP_SECRETS" == "yes" ]]; then
    echo "  - CS secrets (cs-1, cs-1-cert) - preserved"
    echo "  - MSS secrets (mss-0, mss-0-cert) - preserved"
fi
echo "  - Namespaces (im-ns, test-ca)"
echo ""
echo "=========================================="
echo "Next Steps:"
echo "=========================================="
echo ""
echo "1. Reinstall test-ca (must be done before certificate generation):"
echo "   cd test-ca/"
echo "   ./install.sh"
echo ""
echo "2. Regenerate all certificates:"
echo "   cd certs/"
echo "   ./generate_certs_testca_eab.sh"
echo ""
echo "3. Reinstall CS:"
echo "   cd x-road-csx/"
echo "   ./install_cs_1.sh"
echo ""
echo "4. Reinstall MSS:"
echo "   cd x-road-ssx/"
echo "   ./install_ss_0.sh"
echo ""
echo "5. Run configuration:"
echo "   cd hurl-auto-config/"
echo "   ./run_config_fqdn.sh"
echo ""

