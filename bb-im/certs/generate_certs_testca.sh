#!/bin/bash

set -euo pipefail

# Generate X-Road certificates using test-ca service
# This script automates the process of creating CA-signed certificates

CERT_DIR="$(pwd)"
NAMESPACE="test-ca"

echo "=== Generating X-Road certificates with test-ca service ==="
echo "Certificate Directory: ${CERT_DIR}"

# Function to backup existing certificates
backup_certificates() {
    if [[ -f "certificate.crt" || -f "certificate.key" || -f "certificate-*.p12" ]]; then
        BACKUP_DIR="backup-$(date +%Y%m%d-%H%M%S)"
        echo "--- Backing up existing certificates to ${BACKUP_DIR}/"
        mkdir -p "${BACKUP_DIR}"

        [[ -f "certificate.crt" ]] && mv certificate.crt "${BACKUP_DIR}/"
        [[ -f "certificate.key" ]] && mv certificate.key "${BACKUP_DIR}/"
        [[ -f "certificate.csr" ]] && mv certificate.csr "${BACKUP_DIR}/"
        [[ -f "ca.pem" ]] && mv ca.pem "${BACKUP_DIR}/"
        mv certificate-*.p12 "${BACKUP_DIR}/" 2>/dev/null || true

        echo "✅ Certificates backed up to ${BACKUP_DIR}/"
    fi
}

# Function to find test-ca pod
find_testca_pod() {
    local pod_name=$(kubectl get pods -n "${NAMESPACE}" --no-headers | grep "^ca-" | awk '{print $1}' | head -1)
    if [[ -z "$pod_name" ]]; then
        echo "❌ Error: No test-ca pod found in namespace '${NAMESPACE}'"
        echo "Please ensure test-ca is running: kubectl get pods -n ${NAMESPACE}"
        exit 1
    fi
    echo "$pod_name"
}

# Function to generate private key and CSR
generate_csr() {
    echo "--- Generating private key and CSR..."

    if [[ ! -f "definition.cnf" ]]; then
        echo "❌ Error: definition.cnf not found. Please ensure it exists in the current directory."
        exit 1
    fi

    # Generate new private key
    openssl genrsa -out certificate.key 2048

    # Generate certificate signing request
    openssl req -new -key certificate.key -out certificate.csr -config definition.cnf

    echo "✅ Private key and CSR generated"
}

# Function to sign certificate with test-ca
sign_certificate() {
    local pod_name="$1"

    echo "--- Signing certificate with test-ca (pod: ${pod_name})..."

    # Copy CSR to test-ca pod
    kubectl cp certificate.csr "${NAMESPACE}/${pod_name}:/tmp/certificate.csr"

    # Sign the certificate inside the pod
    kubectl exec -n "${NAMESPACE}" "${pod_name}" -- bash -c \
        "cd /home/ca/CA && openssl ca -in /tmp/certificate.csr -out /tmp/certificate.crt -config CA.cnf -batch"

    # Copy signed certificate back
    kubectl cp "${NAMESPACE}/${pod_name}:/tmp/certificate.crt" certificate.crt

    # Also get the CA certificate
    kubectl cp "${NAMESPACE}/${pod_name}:/home/ca/certs/ca.pem" ca.pem

    echo "✅ Certificate signed by test-ca"
}

# Function to create PKCS#12 keystores
create_keystores() {
    echo "--- Creating PKCS#12 keystores..."

    # Central Server keystore
    openssl pkcs12 -export \
        -inkey certificate.key \
        -in certificate.crt \
        -out "certificate-cs.p12" \
        -name "center-admin-service" \
        -password pass:center-admin-service

    # Security Server UI keystore
    openssl pkcs12 -export \
        -inkey certificate.key \
        -in certificate.crt \
        -out "certificate-ss-ui.p12" \
        -name "proxy-ui-api" \
        -password pass:proxy-ui-api

    # Security Server internal keystore
    openssl pkcs12 -export \
        -inkey certificate.key \
        -in certificate.crt \
        -out "certificate-ss-internal.p12" \
        -name "internal" \
        -password pass:internal

    echo "✅ PKCS#12 keystores created"
}

# Function to copy to RSA directory
copy_to_rsa() {
    echo "--- Copying certificates to RSA directory..."

    mkdir -p rsa/
    cp certificate.key certificate.crt certificate-*.p12 rsa/

    echo "✅ Certificates copied to rsa/ directory"
}

# Function to verify certificates
verify_certificates() {
    echo "--- Verifying certificates..."

    if [[ -f "certificate.crt" ]]; then
        echo "Certificate details:"
        openssl x509 -in certificate.crt -noout -dates -subject -issuer

        # Check if it's CA-signed
        SUBJECT=$(openssl x509 -in certificate.crt -noout -subject | cut -d= -f2-)
        ISSUER=$(openssl x509 -in certificate.crt -noout -issuer | cut -d= -f2-)

        if [[ "$SUBJECT" == "$ISSUER" ]]; then
            echo "⚠️  WARNING: Certificate is self-signed"
            return 1
        else
            echo "✅ Certificate is CA-signed by: $ISSUER"
        fi
    fi

    # Verify PKCS#12 files
    for p12_file in certificate-*.p12; do
        if [[ -f "$p12_file" ]]; then
            case "$p12_file" in
                *cs*)     password="center-admin-service" ;;
                *ui*)     password="proxy-ui-api" ;;
                *internal*) password="internal" ;;
            esac

            if openssl pkcs12 -in "$p12_file" -noout -passin pass:$password 2>/dev/null; then
                echo "✅ $p12_file is valid"
                # Also verify the certificate inside is CA-signed
                issuer=$(openssl pkcs12 -in "$p12_file" -nokeys -clcerts -passin pass:$password 2>/dev/null | openssl x509 -noout -issuer 2>/dev/null)
                echo "   Issuer: $issuer"
            else
                echo "❌ $p12_file has issues"
                return 1
            fi
        fi
    done

    echo "✅ All certificates verified successfully"
}

# Function to show summary
show_summary() {
    echo ""
    echo "=== Summary ==="
    echo "Generated files:"
    ls -la certificate.key certificate.crt certificate-*.p12 ca.pem 2>/dev/null || true
    echo ""
    echo "RSA directory:"
    ls -la rsa/ 2>/dev/null || true
    echo ""
    echo "Certificate chain:"
    echo "- CA: $(openssl x509 -in ca.pem -noout -subject 2>/dev/null || echo 'N/A')"
    echo "- Certificate: $(openssl x509 -in certificate.crt -noout -subject 2>/dev/null || echo 'N/A')"
    echo ""
    echo "✅ All X-Road certificates are now CA-signed by test-ca service"
    echo "🔗 The symlinks in x-road-csx and x-road-ssx will automatically use these certificates"
}

# Main execution
main() {
    echo "Starting certificate generation with test-ca service..."

    # Check if we're in the right directory
    if [[ ! -f "definition.cnf" ]]; then
        echo "❌ Error: Please run this script from the certs/ directory"
        echo "Expected to find definition.cnf in current directory"
        exit 1
    fi

    # Check kubectl access
    if ! kubectl get namespaces &>/dev/null; then
        echo "❌ Error: kubectl not accessible or not configured"
        echo "Please ensure you have access to the Kubernetes cluster"
        exit 1
    fi

    # Check if test-ca namespace exists
    if ! kubectl get namespace "${NAMESPACE}" &>/dev/null; then
        echo "❌ Error: Namespace '${NAMESPACE}' not found"
        echo "Please ensure test-ca is deployed"
        exit 1
    fi

    # Find test-ca pod
    POD_NAME=$(find_testca_pod)
    echo "Using test-ca pod: ${POD_NAME}"

    # Backup existing certificates
    backup_certificates

    # Generate new certificates
    generate_csr
    sign_certificate "${POD_NAME}"
    create_keystores
    copy_to_rsa

    # Verify everything
    if verify_certificates; then
        show_summary
    else
        echo "❌ Certificate verification failed"
        exit 1
    fi
}

# Handle command line arguments
case "${1:-}" in
    --verify-only)
        verify_certificates
        ;;
    --help|-h)
        echo "Usage: $0 [--verify-only] [--help]"
        echo ""
        echo "Generate X-Road certificates using test-ca service"
        echo ""
        echo "Options:"
        echo "  --verify-only    Only verify existing certificates"
        echo "  --help, -h       Show this help message"
        echo ""
        echo "Prerequisites:"
        echo "- Run from certs/ directory"
        echo "- definition.cnf must exist"
        echo "- kubectl access to cluster with test-ca service"
        echo "- test-ca pod running in '${NAMESPACE}' namespace"
        ;;
    *)
        main
        ;;
esac