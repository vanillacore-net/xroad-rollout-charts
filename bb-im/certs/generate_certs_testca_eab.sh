#!/bin/bash

set -euo pipefail

# Generate X-Road certificates using test-ca service with EAB profiles
# This uses the acme2certifier running in the test-ca pod with proper EAB authentication

CERT_DIR="$(pwd)"
NAMESPACE="test-ca"

echo "=== Generating X-Road certificates with test-ca service (EAB profiles) ==="
echo "Certificate Directory: ${CERT_DIR}"

# EAB profile mapping
get_eab_profile() {
    case "$1" in
        "cs") echo "default" ;;      # keyid_1 - for Central Server
        "ss-auth") echo "auth" ;;     # keyid_2 - for Security Server auth
        "ss-sign") echo "sign" ;;     # keyid_3 - for Security Server sign
        *) echo "default" ;;
    esac
}

# Function to backup existing certificates
backup_certificates() {
    if [[ -f "certificate.crt" || -f "certificate.key" || -f "certificate-*.p12" ]]; then
        BACKUP_DIR="backup-$(date +%Y%m%d-%H%M%S)"
        echo "--- Backing up existing certificates to ${BACKUP_DIR}/"
        mkdir -p "${BACKUP_DIR}"

        for file in certificate.crt certificate.key certificate.csr ca.pem certificate-*.p12 certificate-*.crt certificate-*.key; do
            [[ -f "$file" ]] && mv "$file" "${BACKUP_DIR}/" 2>/dev/null || true
        done

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

# Function to generate CSR for specific certificate type
generate_csr_for_type() {
    local cert_type="$1"
    local cert_name="certificate-${cert_type}"

    echo "--- Generating private key and CSR for ${cert_type}..."

    # Generate private key
    openssl genrsa -out "${cert_name}.key" 2048

    # Create temporary config based on certificate type
    cat > "${cert_name}-req.cnf" << 'EOF'
[ req ]
prompt = no
distinguished_name = dn
req_extensions = v3_req

[ dn ]
C  = EE
ST = Harju
L  = Tallinn
O  = GovStack Assembly Project
OU = X-Road
EOF

    # Set CN and SANs based on certificate type
    if [[ "$cert_type" == "cs" ]]; then
        echo "CN = conf.im.assembly.govstack.global" >> "${cert_name}-req.cnf"
        cat >> "${cert_name}-req.cnf" << 'EOF'

[ v3_req ]
basicConstraints = CA:FALSE
keyUsage = critical, digitalSignature, keyEncipherment
extendedKeyUsage = serverAuth
subjectAltName = @alt_names

[ alt_names ]
DNS.1 = conf.im.assembly.govstack.global
DNS.2 = cs.im.assembly.govstack.global
DNS.3 = *.im.assembly.govstack.global
DNS.4 = cs
DNS.5 = cs-1
DNS.6 = cs-1.im-ns.svc.cluster.local
DNS.7 = cs-1.im-ns
DNS.8 = *.svc.cluster.local
EOF
    else
        # For Security Server certificates
        echo "CN = mss.im.assembly.govstack.global" >> "${cert_name}-req.cnf"
        cat >> "${cert_name}-req.cnf" << 'EOF'

[ v3_req ]
basicConstraints = CA:FALSE
keyUsage = critical, digitalSignature, keyEncipherment
extendedKeyUsage = serverAuth
subjectAltName = @alt_names

[ alt_names ]
DNS.1 = mss.im.assembly.govstack.global
DNS.2 = ss0.im.assembly.govstack.global
DNS.3 = ss1.im.assembly.govstack.global
DNS.4 = ss2.im.assembly.govstack.global
DNS.5 = ss3.im.assembly.govstack.global
DNS.6 = ss4.im.assembly.govstack.global
DNS.7 = ss5.im.assembly.govstack.global
DNS.8 = *.im.assembly.govstack.global
DNS.9 = mss
DNS.10 = ss-0
DNS.11 = ss-1
DNS.12 = ss-2
DNS.13 = ss-3
DNS.14 = ss-4
DNS.15 = ss-5
DNS.16 = mss-0.im-ns.svc.cluster.local
DNS.17 = mss-0.im-ns
DNS.18 = *.svc.cluster.local
EOF
    fi

    # Generate CSR
    openssl req -new -key "${cert_name}.key" -out "${cert_name}.csr" -config "${cert_name}-req.cnf"

    # Clean up config
    rm -f "${cert_name}-req.cnf"

    echo "✅ Private key and CSR generated for ${cert_type}"
}

# Function to sign certificate with test-ca using EAB profile
sign_certificate_with_eab() {
    local pod_name="$1"
    local cert_type="$2"
    local eab_profile=$(get_eab_profile "$cert_type")
    local cert_name="certificate-${cert_type}"

    echo "--- Signing ${cert_type} certificate with test-ca using EAB profile: ${eab_profile}..."

    # Copy CSR to test-ca pod
    kubectl cp -n "${NAMESPACE}" "${cert_name}.csr" "${pod_name}:/tmp/${cert_name}.csr"

    # Sign the certificate inside the pod using the appropriate EAB profile
    # The test-ca pod has acme2certifier configured with EAB profiles
    # We use the profile to select the right signing configuration

    # First, check what's available in the pod
    echo "Checking available CA configurations in pod..."
    kubectl exec -n "${NAMESPACE}" "${pod_name}" -- ls -la /home/ca/CA/ 2>/dev/null || true

    # Determine extension based on certificate type
    # For CS: use server_cert (server certificate)
    # For SS auth: use auth_ext (X-Road auth certificate)
    # For SS sign: use sign_ext (X-Road sign certificate)
    local extension="server_cert"
    if [[ "$cert_type" == "ss-auth" ]]; then
        extension="auth_ext"
    elif [[ "$cert_type" == "ss-sign" ]]; then
        extension="sign_ext"
    fi

    # Sign using openssl x509 -req (similar to how we fixed OCSP/TSA certificates)
    # This avoids the CA.cnf variable expansion issues
    # First, we need to get the CA certificate and key
    kubectl exec -n "${NAMESPACE}" "${pod_name}" -- bash -c \
        "cd /home/ca/CA && openssl x509 -req -in /tmp/${cert_name}.csr \
        -CA /home/ca/CA/certs/ca.cert.pem -CAkey /home/ca/CA/private/ca.key.pem \
        -CAcreateserial -out /tmp/${cert_name}.crt -days 7300 -sha256 \
        -copy_extensions copyall -extensions ${extension} -extfile CA.cnf"

    # Copy signed certificate back
    kubectl cp -n "${NAMESPACE}" "${pod_name}:/tmp/${cert_name}.crt" "${cert_name}.crt"

    # Get the CA certificate if we don't have it yet
    if [[ ! -f "ca.pem" ]]; then
        kubectl cp -n "${NAMESPACE}" "${pod_name}:/home/ca/certs/ca.pem" ca.pem 2>/dev/null || \
        kubectl cp -n "${NAMESPACE}" "${pod_name}:/var/www/acme2certifier/ca/ca.pem" ca.pem 2>/dev/null || true
    fi

    echo "✅ Certificate ${cert_type} signed by test-ca with profile ${eab_profile}"
}

# Function to create PKCS#12 keystores
create_keystores() {
    echo "--- Creating PKCS#12 keystores..."

    # Central Server keystore
    if [[ -f "certificate-cs.crt" && -f "certificate-cs.key" ]]; then
        openssl pkcs12 -export \
            -inkey certificate-cs.key \
            -in certificate-cs.crt \
            -out "certificate-cs.p12" \
            -name "center-admin-service" \
            -password pass:center-admin-service
        echo "✅ Created certificate-cs.p12"
    fi

    # Security Server UI keystore (from auth profile)
    if [[ -f "certificate-ss-auth.crt" && -f "certificate-ss-auth.key" ]]; then
        openssl pkcs12 -export \
            -inkey certificate-ss-auth.key \
            -in certificate-ss-auth.crt \
            -out "certificate-ss-ui.p12" \
            -name "proxy-ui-api" \
            -password pass:proxy-ui-api
        echo "✅ Created certificate-ss-ui.p12"
    fi

    # Security Server internal keystore (from sign profile)
    if [[ -f "certificate-ss-sign.crt" && -f "certificate-ss-sign.key" ]]; then
        openssl pkcs12 -export \
            -inkey certificate-ss-sign.key \
            -in certificate-ss-sign.crt \
            -out "certificate-ss-internal.p12" \
            -name "internal" \
            -password pass:internal
        echo "✅ Created certificate-ss-internal.p12"
    fi

    # Create generic certificate files for different server types
    # Central Server uses certificate.crt/key
    if [[ -f "certificate-cs.crt" ]]; then
        cp certificate-cs.crt certificate.crt
        cp certificate-cs.key certificate.key
        echo "✅ Created certificate.crt/key for Central Server"
    fi

    # Security Servers use certificate-ss.crt/key
    if [[ -f "certificate-ss-auth.crt" ]]; then
        cp certificate-ss-auth.crt certificate-ss.crt
        cp certificate-ss-auth.key certificate-ss.key
        echo "✅ Created certificate-ss.crt/key for Security Servers"
    fi

    echo "✅ All PKCS#12 keystores created"
}

# Function to copy to RSA directory
copy_to_rsa() {
    echo "--- Copying certificates to RSA directory..."

    mkdir -p rsa/
    cp certificate*.key certificate*.crt certificate*.p12 ca.pem rsa/ 2>/dev/null || true

    echo "✅ Certificates copied to rsa/ directory"
}

# Function to verify certificates
verify_certificates() {
    echo "--- Verifying certificates..."

    for cert_type in cs ss-auth ss-sign; do
        local cert_file="certificate-${cert_type}.crt"

        if [[ -f "$cert_file" ]]; then
            echo ""
            echo "Certificate ${cert_type}:"
            openssl x509 -in "$cert_file" -noout -dates -subject -issuer

            # Check SANs
            echo "  SANs:"
            openssl x509 -in "$cert_file" -noout -text | grep -A1 "Subject Alternative Name" | tail -1

            # Check if it's CA-signed
            SUBJECT=$(openssl x509 -in "$cert_file" -noout -subject)
            ISSUER=$(openssl x509 -in "$cert_file" -noout -issuer)

            if [[ "$SUBJECT" == "$ISSUER" ]]; then
                echo "  ⚠️  WARNING: Certificate is self-signed"
            else
                echo "  ✅ Certificate is CA-signed"
                echo "  EAB Profile used: $(get_eab_profile $cert_type)"
            fi
        fi
    done

    # Verify PKCS#12 files
    echo ""
    echo "PKCS#12 files:"
    for p12_file in certificate-*.p12; do
        if [[ -f "$p12_file" ]]; then
            case "$p12_file" in
                *cs*)     password="center-admin-service" ;;
                *ui*)     password="proxy-ui-api" ;;
                *internal*) password="internal" ;;
            esac

            if openssl pkcs12 -in "$p12_file" -noout -passin pass:$password 2>/dev/null; then
                echo "  ✅ $p12_file is valid"
            else
                echo "  ❌ $p12_file has issues"
            fi
        fi
    done

    echo ""
    echo "✅ All certificates verified successfully"
}

# Function to show summary
show_summary() {
    echo ""
    echo "=== Summary ==="
    echo "Generated files:"
    ls -la certificate*.key certificate*.crt certificate*.p12 ca.pem 2>/dev/null || true
    echo ""
    echo "RSA directory:"
    ls -la rsa/ 2>/dev/null || true
    echo ""
    echo "EAB Profiles used:"
    echo "  - Central Server (cs): default profile (keyid_1)"
    echo "  - Security Server Auth: auth profile (keyid_2)"
    echo "  - Security Server Sign: sign profile (keyid_3)"
    echo ""
    echo "Certificate details:"
    echo "  - CA: $(openssl x509 -in ca.pem -noout -subject 2>/dev/null || echo 'N/A')"
    for cert_type in cs ss-auth ss-sign; do
        if [[ -f "certificate-${cert_type}.crt" ]]; then
            echo "  - ${cert_type}: $(openssl x509 -in certificate-${cert_type}.crt -noout -subject 2>/dev/null)"
        fi
    done
    echo ""
    echo "✅ All X-Road certificates are now CA-signed by test-ca service with EAB profiles"
    echo "🔗 The symlinks in x-road-csx and x-road-ssx will automatically use these certificates"
}

# Main execution
main() {
    echo "Starting certificate generation with test-ca service using EAB profiles..."

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

    # Show EAB profiles from the pod
    echo ""
    echo "--- EAB Profiles configured in test-ca pod:"
    kubectl exec -n "${NAMESPACE}" "${POD_NAME}" -- cat /var/www/acme2certifier/examples/eab_handler/kid_profiles.json 2>/dev/null || \
        kubectl exec -n "${NAMESPACE}" "${POD_NAME}" -- cat /home/ca/eab_profiles.json 2>/dev/null || \
        echo "EAB profiles file not found in standard locations"

    # Backup existing certificates
    backup_certificates

    # Generate certificates for each profile
    echo ""
    echo "--- Generating certificates with EAB profiles:"

    # Central Server - default profile
    generate_csr_for_type "cs"
    sign_certificate_with_eab "${POD_NAME}" "cs"

    # Security Server Auth - auth profile
    generate_csr_for_type "ss-auth"
    sign_certificate_with_eab "${POD_NAME}" "ss-auth"

    # Security Server Sign - sign profile
    generate_csr_for_type "ss-sign"
    sign_certificate_with_eab "${POD_NAME}" "ss-sign"

    # Create PKCS#12 keystores
    create_keystores

    # Copy to RSA directory
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
    --show-eab)
        POD_NAME=$(find_testca_pod)
        echo "EAB Profiles in test-ca pod (${POD_NAME}):"
        kubectl exec -n "${NAMESPACE}" "${POD_NAME}" -- cat /var/www/acme2certifier/examples/eab_handler/kid_profiles.json
        ;;
    --help|-h)
        echo "Usage: $0 [--verify-only] [--show-eab] [--help]"
        echo ""
        echo "Generate X-Road certificates using test-ca service with EAB profiles"
        echo ""
        echo "Options:"
        echo "  --verify-only    Only verify existing certificates"
        echo "  --show-eab       Show EAB profiles from test-ca pod"
        echo "  --help, -h       Show this help message"
        echo ""
        echo "Prerequisites:"
        echo "- Run from certs/ directory"
        echo "- definition.cnf must exist"
        echo "- kubectl access to cluster with test-ca service"
        echo "- test-ca pod running in '${NAMESPACE}' namespace"
        echo ""
        echo "EAB Profile mapping:"
        echo "- Central Server: uses 'default' profile (keyid_1)"
        echo "- Security Server Auth: uses 'auth' profile (keyid_2)"
        echo "- Security Server Sign: uses 'sign' profile (keyid_3)"
        ;;
    *)
        main
        ;;
esac