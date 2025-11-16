#!/bin/bash
set -euo pipefail

# Handle Ctrl+C (SIGINT) and SIGTERM
cleanup() {
    echo ""
    echo "Interrupted! Cleaning up..."
    # Kill any running Docker containers
    docker ps --filter "ancestor=orangeopensource/hurl:1.8.0" --format "{{.ID}}" | xargs -r docker kill 2>/dev/null || true
    exit 130
}
trap cleanup SIGINT SIGTERM

# Run setup_sh-demo.hurl with variables from environment/config
# This script runs the Hurl configuration directly without CronJob

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

HURL_FILE="setup.hurl"
NAMESPACE="${NAMESPACE:-im-ns}"

echo "=== X-Road Setup via Hurl ==="
echo ""

# Check if hurl is installed and working
USE_DOCKER=false
if command -v hurl &> /dev/null; then
    # Test if hurl actually works (handles GLIBC issues)
    if ! hurl --version &>/dev/null; then
        echo "⚠️  Hurl is installed but not working (GLIBC compatibility issue)."
        echo "   Will use Docker instead."
        USE_DOCKER=true
    fi
else
    echo "⚠️  Hurl is not installed locally."
    echo "   Will use Docker instead."
    USE_DOCKER=true
fi

# When using Docker, 'localhost' inside container refers to the container itself,
# not the host machine. We need to use 'host.docker.internal' to access host's localhost.
# Replace localhost with host.docker.internal before building HURL_VARS array
if [ "$USE_DOCKER" = true ]; then
    if [ "${cs_host:-}" = "localhost" ]; then
        export cs_host="host.docker.internal"
    fi
    if [ "${ss0_host:-}" = "localhost" ]; then
        export ss0_host="host.docker.internal"
    fi
    if [ "${ca_host:-}" = "localhost" ]; then
        export ca_host="host.docker.internal"
    fi
    if [ "${ca_ocsp_host:-}" = "localhost" ]; then
        export ca_ocsp_host="host.docker.internal"
    fi
    if [ "${ca_acme_host:-}" = "localhost" ]; then
        export ca_acme_host="host.docker.internal"
    fi
    if [ "${ca_tsa_host:-}" = "localhost" ]; then
        export ca_tsa_host="host.docker.internal"
    fi
fi

if [ "$USE_DOCKER" = true ]; then
    echo ""
    echo "Using Docker to run Hurl..."
    if ! command -v docker &> /dev/null; then
        echo "Error: Docker is required but not installed."
        echo "Please install Docker or install Hurl: https://hurl.dev/docs/installation.html"
        exit 1
    fi
    
    # Check if Hurl Docker image exists
    if ! docker image inspect orangeopensource/hurl:1.8.0 &>/dev/null; then
        echo "Pulling Hurl Docker image..."
        docker pull orangeopensource/hurl:1.8.0
    fi
    
    echo ""
    echo "Note: For better Docker integration, use ./run_config_docker.sh"
    echo "      This script will run Hurl commands via Docker..."
    echo ""
    
    # We'll modify the hurl command to use Docker
    HURL_CMD="docker run --rm -i -v \"$(pwd):/workspace\" -w /workspace orangeopensource/hurl:1.8.0 hurl"
else
    HURL_CMD="hurl"
fi

# Check if Hurl file exists
if [ ! -f "$HURL_FILE" ]; then
    echo "Error: $HURL_FILE not found in current directory"
    exit 1
fi

# Variables should be set by the caller script (run_config_localhost.sh or run_config_fqdn.sh)
# Do NOT source vars.env here - let the caller handle it

# Get passwords from Kubernetes secrets (override any existing values)
echo "Fetching passwords from Kubernetes secrets..."
CS_SECRET="cs-1"
SS0_SECRET="mss-0"

# CS password
if kubectl get secret -n "$NAMESPACE" "$CS_SECRET" &>/dev/null; then
    CS_PASSWORD=$(kubectl get secret -n "$NAMESPACE" "$CS_SECRET" -o jsonpath='{.data.password}' 2>/dev/null | base64 -d)
    if [ -n "$CS_PASSWORD" ]; then
        export cs_host_password="$CS_PASSWORD"
        echo "✓ CS password loaded from secret"
    fi
else
    echo "⚠️  Warning: CS secret $CS_SECRET not found in namespace $NAMESPACE"
    echo "   You may need to set cs_host_password environment variable"
fi

# SS0 password
if kubectl get secret -n "$NAMESPACE" "$SS0_SECRET" &>/dev/null; then
    SS0_PASSWORD=$(kubectl get secret -n "$NAMESPACE" "$SS0_SECRET" -o jsonpath='{.data.password}' 2>/dev/null | base64 -d)
    if [ -n "$SS0_PASSWORD" ]; then
        export ss0_host_password="$SS0_PASSWORD"
        echo "✓ SS0 password loaded from secret"
    fi
else
    echo "⚠️  Warning: SS0 secret $SS0_SECRET not found in namespace $NAMESPACE"
    echo "   You may need to set ss0_host_password environment variable"
fi

# SS1 password (if exists)
if kubectl get secret -n "$NAMESPACE" "ss-1" &>/dev/null; then
    SS1_PASSWORD=$(kubectl get secret -n "$NAMESPACE" "ss-1" -o jsonpath='{.data.password}' 2>/dev/null | base64 -d)
    if [ -n "$SS1_PASSWORD" ]; then
        export ss1_host_password="$SS1_PASSWORD"
        echo "✓ SS1 password loaded from secret"
    fi
fi

# Get token PINs from secrets
if kubectl get secret -n "$NAMESPACE" "$CS_SECRET" &>/dev/null; then
    CS_PIN=$(kubectl get secret -n "$NAMESPACE" "$CS_SECRET" -o jsonpath='{.data.tokenPin}' 2>/dev/null | base64 -d)
    if [ -n "$CS_PIN" ]; then
        export cs_host_pin="$CS_PIN"
        echo "✓ CS token PIN loaded from secret"
    fi
fi

# SS0 token PIN
if kubectl get secret -n "$NAMESPACE" "$SS0_SECRET" &>/dev/null; then
    SS0_PIN=$(kubectl get secret -n "$NAMESPACE" "$SS0_SECRET" -o jsonpath='{.data.tokenPin}' 2>/dev/null | base64 -d)
    if [ -n "$SS0_PIN" ]; then
        export ss0_host_pin="$SS0_PIN"
        echo "✓ SS0 token PIN loaded from secret"
    fi
fi

# Set defaults if not already set
export cs_host="${cs_host:-cs.im.assembly.govstack.global}"
export ss0_host="${ss0_host:-mss.im.assembly.govstack.global}"
export ss1_host="${ss1_host:-ss1.im.assembly.govstack.global}"

# CA defaults
export ca_host="${ca_host:-ca.test-ca.svc.cluster.local}"
export ca_ocsp_host="${ca_ocsp_host:-ocsp.im.assembly.govstack.global}"
export ca_ocsp_port="${ca_ocsp_port:-443}"
export ca_acme_host="${ca_acme_host:-acme.im.assembly.govstack.global}"
export ca_acme_port="${ca_acme_port:-443}"
export ca_tsa_host="${ca_tsa_host:-tsa.im.assembly.govstack.global}"
export ca_tsa_port="${ca_tsa_port:-443}"

# Display configuration
echo ""
echo "=== Configuration ==="
echo "CS Host: $cs_host"
echo "SS0 Host: $ss0_host"
echo "SS1 Host: ${ss1_host:-not set}"
echo "CA Host: $ca_host"
echo "CS Password: ${cs_host_password:+***set***}"
echo "SS0 Password: ${ss0_host_password:+***set***}"
echo "SS1 Password: ${ss1_host_password:+***set***}"
echo "CS PIN: ${cs_host_pin:+***set***}"
echo ""

# Check required variables
MISSING_VARS=()
[ -z "${cs_host_password:-}" ] && MISSING_VARS+=("cs_host_password")
[ -z "${ss0_host_password:-}" ] && MISSING_VARS+=("ss0_host_password")
[ -z "${cs_host_pin:-}" ] && MISSING_VARS+=("cs_host_pin")
[ -z "${ss0_host_pin:-}" ] && MISSING_VARS+=("ss0_host_pin")

if [ ${#MISSING_VARS[@]} -gt 0 ]; then
    echo "⚠️  Warning: Missing required variables:"
    for var in "${MISSING_VARS[@]}"; do
        echo "   - $var"
    done
    echo ""
    echo "You can set them as environment variables:"
    echo "  export cs_host_password='your-password'"
    echo "  export ss0_host_password='your-password'"
    echo "  export cs_host_pin='your-pin'"
    echo "  export ss0_host_pin='your-pin'"
    echo ""
    read -p "Continue anyway? (y/N) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 1
    fi
fi

# Check if CA certificates are needed
if [ ! -d "ca" ]; then
    echo "⚠️  CA certificates directory not found."
    echo "   Run ./get_certificates.sh to fetch them (or they will be fetched from pods during execution)"
    echo ""
fi

# Build hurl command with all variables
echo "=== Running Hurl Setup ==="
echo "Executing: $HURL_FILE"
echo ""

# Build Hurl variables array
# All variables are passed via --variable flags (not environment variables)
# This ensures clean variable passing to both local and Docker execution
HURL_VARS=(
    --variable "cs_host=$cs_host"
    --variable "cs_conf_host=$cs_conf_host"
    --variable "ss0_host=$ss0_host"
    --variable "ca_host=$ca_host"
    --variable "ca_ocsp_host=$ca_ocsp_host"
    --variable "ca_ocsp_port=$ca_ocsp_port"
    --variable "ca_acme_host=$ca_acme_host"
    --variable "ca_acme_port=$ca_acme_port"
    --variable "ca_tsa_host=$ca_tsa_host"
    --variable "ca_tsa_port=$ca_tsa_port"
)

# Add optional port variables if set
[ -n "${cs_host_port:-}" ] && HURL_VARS+=(--variable "cs_host_port=$cs_host_port")
[ -n "${ss0_host_port:-}" ] && HURL_VARS+=(--variable "ss0_host_port=$ss0_host_port")

# Add optional password and pin variables if set
[ -n "${cs_host_password:-}" ] && HURL_VARS+=(--variable "cs_host_password=$cs_host_password")
[ -n "${ss0_host_password:-}" ] && HURL_VARS+=(--variable "ss0_host_password=$ss0_host_password")
[ -n "${ss1_host_password:-}" ] && HURL_VARS+=(--variable "ss1_host_password=$ss1_host_password")
[ -n "${cs_host_pin:-}" ] && HURL_VARS+=(--variable "cs_host_pin=$cs_host_pin")
[ -n "${ss0_host_pin:-}" ] && HURL_VARS+=(--variable "ss0_host_pin=$ss0_host_pin")
[ -n "${ss1_host_pin:-}" ] && HURL_VARS+=(--variable "ss1_host_pin=$ss1_host_pin")

# Add optional Security Server 1 variables if set
[ -n "${ss1_host:-}" ] && HURL_VARS+=(--variable "ss1_host=$ss1_host")

# Run hurl (via Docker if needed)
if [ "$USE_DOCKER" = true ]; then
    echo "Executing via Docker..."
    
    # The Hurl Docker image has hurl as entrypoint, so we override it
    # Build arguments array properly
    # --init: Use tini to handle signals properly (SIGINT, SIGTERM)
    # --interactive: Keep STDIN open for signal handling
    # --add-host: Add host.docker.internal to container's /etc/hosts
    DOCKER_ARGS=(
        --rm
        --init
        --interactive
        --add-host=host.docker.internal:host-gateway
        -v "$SCRIPT_DIR:/workspace"
        -w /workspace
        --entrypoint ""
    )
    
    # Build the hurl command with all arguments
    # Flags should be before the file argument for better compatibility
    HURL_CMD_ARGS=(
        "/usr/bin/hurl"
        --test
        --very-verbose
        --insecure
        --retry
        --retry-interval=10000
    )
    
    # Add all variables to the command
    for var in "${HURL_VARS[@]}"; do
        HURL_CMD_ARGS+=("$var")
    done
    
    # Add the Hurl file as the last argument
    HURL_CMD_ARGS+=("$HURL_FILE")
    
    # Run Docker command
    # Signals (Ctrl+C) will be forwarded to the container via --init (tini)
    # Redirect stderr to stdout so verbose output is captured in logs
    docker run "${DOCKER_ARGS[@]}" \
        orangeopensource/hurl:1.8.0 \
        "${HURL_CMD_ARGS[@]}" 2>&1
else
    # Run local hurl
    # Flags should be before the file argument for better compatibility
    # Redirect stderr to stdout so verbose output is captured in logs
    hurl --test \
        --very-verbose \
        --insecure \
        --retry \
        --retry-interval=10000 \
        "${HURL_VARS[@]}" \
        "$HURL_FILE" 2>&1
fi

EXIT_CODE=$?

echo ""
if [ $EXIT_CODE -eq 0 ]; then
    echo "✅ Setup completed successfully!"
else
    echo "❌ Setup failed with exit code: $EXIT_CODE"
fi

exit $EXIT_CODE

