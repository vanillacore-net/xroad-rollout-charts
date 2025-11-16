#!/bin/bash

# Run Hurl configuration using localhost port-forwards
# Make sure setup_port_forwards.sh is running first!

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

echo "=== X-Road Setup via Hurl (Localhost/Port-Forward) ==="
echo ""
echo "⚠️  Make sure port-forwards are running!"
echo "    Run: ./setup_port_forwards.sh in another terminal"
echo ""
read -p "Press Enter to continue or Ctrl+C to cancel..."
echo ""

# Load variables from vars.env first
VARS_FILE="config/vars.env"
if [ -f "$VARS_FILE" ]; then
    echo "Loading variables from $VARS_FILE..."
    set -a  # automatically export all variables
    source "$VARS_FILE"
    set +a
fi

# Override hostnames and ports to use localhost (port-forwards)
export cs_host="localhost"
export cs_host_port=":4000"
export ss0_host="localhost"
export ss0_host_port=":4040"
export ca_host="localhost"
export ca_ocsp_host="localhost"
export ca_ocsp_port="8888"
export ca_acme_host="localhost"
export ca_acme_port="8887"
export ca_tsa_host="localhost"
export ca_tsa_port="8899"

# Run the main config script
exec ./run_config.sh

