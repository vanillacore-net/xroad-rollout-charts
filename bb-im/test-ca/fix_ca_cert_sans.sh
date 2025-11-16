#!/bin/bash

# Post-install script to regenerate OCSP and TSA certificates with SANs
# This script should be run after test-ca is installed and initialized

set -euo pipefail

NAMESPACE="test-ca"

echo "=== Fixing CA Certificates with SANs ==="
echo ""

# Find the test-ca pod
POD_NAME=$(kubectl get pods -n "${NAMESPACE}" --no-headers | grep "^ca-" | awk '{print $1}' | head -1)
if [[ -z "$POD_NAME" ]]; then
    echo "❌ Error: No test-ca pod found in namespace '${NAMESPACE}'"
    exit 1
fi

echo "Using pod: ${POD_NAME}"

# Check if CA certificate and key exist (required for signing)
echo ""
echo "--- Checking CA prerequisites..."
if ! kubectl exec -n "${NAMESPACE}" "${POD_NAME}" -c test-ca -- test -f /home/ca/CA/certs/ca.cert.pem 2>/dev/null; then
    echo "❌ CA certificate not found. CA may still be initializing."
    echo "   Please wait for CA certificate generation to complete."
    exit 1
fi

if ! kubectl exec -n "${NAMESPACE}" "${POD_NAME}" -c test-ca -- test -f /home/ca/CA/private/ca.key.pem 2>/dev/null; then
    echo "❌ CA private key not found. CA may still be initializing."
    echo "   Please wait for CA initialization to complete."
    exit 1
fi

echo "✅ CA certificate and private key exist (ready for signing)"

# Create temporary CSR config files with SANs
echo ""
echo "--- Creating CSR config files with SANs..."

# OCSP CSR config
# Note: authorityKeyIdentifier and subjectKeyIdentifier are added by CA during signing
OCSP_CSR_CONFIG=$(cat << 'EOF'
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
CN = Test CA OCSP

[ v3_req ]
basicConstraints = CA:FALSE
keyUsage = critical, digitalSignature
extendedKeyUsage = critical, OCSPSigning
subjectAltName = @ocsp_alt_names

[ ocsp_alt_names ]
DNS.1 = ocsp.im.assembly.govstack.global
DNS.2 = ca.test-ca.svc.cluster.local
DNS.3 = *.svc.cluster.local
EOF
)

# TSA CSR config
TSA_CSR_CONFIG=$(cat << 'EOF'
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
CN = Test CA TSA

[ v3_req ]
extendedKeyUsage = critical,timeStamping
keyUsage = critical,nonRepudiation
subjectAltName = @tsa_alt_names

[ tsa_alt_names ]
DNS.1 = tsa.im.assembly.govstack.global
DNS.2 = ca.test-ca.svc.cluster.local
DNS.3 = *.svc.cluster.local
EOF
)

# Copy CSR configs to pod
echo "--- Copying CSR configs to pod..."
echo "$OCSP_CSR_CONFIG" | kubectl exec -i -n "${NAMESPACE}" "${POD_NAME}" -c test-ca -- bash -c 'cat > /tmp/ocsp-csr.cnf'
echo "$TSA_CSR_CONFIG" | kubectl exec -i -n "${NAMESPACE}" "${POD_NAME}" -c test-ca -- bash -c 'cat > /tmp/tsa-csr.cnf'

# Regenerate OCSP certificate
echo ""
echo "--- Regenerating OCSP certificate with SANs..."
kubectl exec -n "${NAMESPACE}" "${POD_NAME}" -c test-ca -- bash -c '
export HOME=/home/ca/CA
cd /home/ca/CA

# Generate OCSP private key if it doesn'\''t exist
if [ ! -f private/ocsp.key.pem ]; then
    echo "Generating OCSP private key..."
    openssl genrsa -out private/ocsp.key.pem 2048
    chmod g+r private/ocsp.key.pem
fi

# Generate new CSR with SANs
openssl req -new -key private/ocsp.key.pem -out csr/ocsp-new.csr.pem -config /tmp/ocsp-csr.cnf

# Sign the certificate using x509, copying extensions from CSR and adding ocsp extension from CA.cnf
# The -copy_extensions copyall copies SANs from CSR, and -extensions adds the ocsp extension
openssl x509 -req -in csr/ocsp-new.csr.pem -CA /home/ca/CA/certs/ca.cert.pem -CAkey /home/ca/CA/private/ca.key.pem \
    -CAcreateserial -out certs/ocsp-new.cert.pem -days 7300 -sha256 \
    -copy_extensions copyall -extensions ocsp -extfile CA.cnf

# Backup old certificate and replace with new one
if [ -f certs/ocsp.cert.pem ]; then
    mv certs/ocsp.cert.pem certs/ocsp.cert.pem.old
fi
mv certs/ocsp-new.cert.pem certs/ocsp.cert.pem

# Copy to certs directory for external access
cp certs/ocsp.cert.pem ../certs/ocsp.pem

echo "✅ OCSP certificate regenerated with SANs"
'

# Regenerate TSA certificate
echo ""
echo "--- Regenerating TSA certificate with SANs..."
kubectl exec -n "${NAMESPACE}" "${POD_NAME}" -c test-ca -- bash -c '
export HOME=/home/ca/CA
cd /home/ca/CA

# Generate TSA private key if it doesn'\''t exist
if [ ! -f private/tsa.key.pem ]; then
    echo "Generating TSA private key..."
    openssl genrsa -out private/tsa.key.pem 2048
    chmod g+r private/tsa.key.pem
fi

# Generate new CSR with SANs
openssl req -new -key private/tsa.key.pem -out csr/tsa-new.csr.pem -config /tmp/tsa-csr.cnf

# Sign the certificate using x509, copying extensions from CSR and adding tsa_ext extension from CA.cnf
# The -copy_extensions copyall copies SANs from CSR, and -extensions adds the tsa_ext extension
openssl x509 -req -in csr/tsa-new.csr.pem -CA /home/ca/CA/certs/ca.cert.pem -CAkey /home/ca/CA/private/ca.key.pem \
    -CAcreateserial -out certs/tsa-new.cert.pem -days 7300 -sha256 \
    -copy_extensions copyall -extensions tsa_ext -extfile CA.cnf

# Backup old certificate and replace with new one
if [ -f certs/tsa.cert.pem ]; then
    mv certs/tsa.cert.pem certs/tsa.cert.pem.old
fi
mv certs/tsa-new.cert.pem certs/tsa.cert.pem

# Copy to certs directory for external access
cp certs/tsa.cert.pem ../certs/tsa.pem

echo "✅ TSA certificate regenerated with SANs"
'

# Verify certificates have SANs
echo ""
echo "=== Verifying Certificates Have SANs ==="
echo ""
echo "OCSP certificate SANs:"
kubectl exec -n "${NAMESPACE}" "${POD_NAME}" -c test-ca -- openssl x509 -in /home/ca/certs/ocsp.pem -noout -text 2>/dev/null | grep -A 5 "Subject Alternative Name" || echo "  (SANs not found)"

echo ""
echo "TSA certificate SANs:"
kubectl exec -n "${NAMESPACE}" "${POD_NAME}" -c test-ca -- openssl x509 -in /home/ca/certs/tsa.pem -noout -text 2>/dev/null | grep -A 5 "Subject Alternative Name" || echo "  (SANs not found)"

echo ""
echo "✅ Certificate regeneration complete!"
echo ""
echo "Note: You may need to restart the test-ca pod for services to use the new certificates:"
echo "  kubectl delete pod -n ${NAMESPACE} ${POD_NAME}"

