#!/bin/bash

# Run Hurl configuration using FQDN hostnames (via Ingress/LoadBalancer)
# This requires proper DNS configuration and LoadBalancer external IPs

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

echo "=== X-Road Setup via Hurl (FQDN/Ingress) ==="
echo ""
echo "⚠️  Make sure DNS is configured and LoadBalancers have external IPs!"
echo ""

# Load variables from vars.env (these contain FQDN hostnames)
VARS_FILE="config/vars.env"
if [ -f "$VARS_FILE" ]; then
    echo "Loading variables from $VARS_FILE..."
    set -a  # automatically export all variables
    source "$VARS_FILE"
    set +a
    echo "✓ Variables loaded from $VARS_FILE"
else
    echo "⚠️  Warning: $VARS_FILE not found"
    echo "   Using default FQDN values"
fi

# Ensure FQDN values are set (use defaults if vars.env didn't set them)
export cs_host="${cs_host:-cs.im.assembly.govstack.global}"
export cs_conf_host="${cs_conf_host:-conf.im.assembly.govstack.global}"
export cs_host_port="${cs_host_port:-:443}"
export ss0_host="${ss0_host:-mss.im.assembly.govstack.global}"
export ss0_host_port="${ss0_host_port:-:443}"
export ca_host="${ca_host:-ca.test-ca.svc.cluster.local}"
export ca_ocsp_host="${ca_ocsp_host:-ocsp.im.assembly.govstack.global}"
export ca_ocsp_port="${ca_ocsp_port:-443}"
export ca_acme_host="${ca_acme_host:-acme.im.assembly.govstack.global}"
export ca_acme_port="${ca_acme_port:-443}"
export ca_tsa_host="${ca_tsa_host:-tsa.im.assembly.govstack.global}"
export ca_tsa_port="${ca_tsa_port:-443}"

echo ""
echo "Using FQDN hostnames:"
echo "  CS: $cs_host"
echo "  MSS: $ss0_host"
echo "  CA OCSP: $ca_ocsp_host"
echo "  CA ACME: $ca_acme_host"
echo "  CA TSA: $ca_tsa_host"
echo ""

# Run the main config script
pwd
exec ./run_config.sh

