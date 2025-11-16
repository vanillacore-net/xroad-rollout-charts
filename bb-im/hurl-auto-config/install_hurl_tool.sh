#!/bin/bash
set -euo pipefail

# Hurl Installation Script
# Installs the Hurl HTTP testing tool

INSTALL_DIR="${INSTALL_DIR:-/usr/local/bin}"
HURL_VERSION="${HURL_VERSION:-latest}"
OS_TYPE=$(uname -s | tr '[:upper:]' '[:lower:]')
ARCH=$(uname -m)

# Map architecture
case "$ARCH" in
    x86_64)
        ARCH="x86_64"
        ;;
    aarch64|arm64)
        ARCH="aarch64"
        ;;
    *)
        echo "Error: Unsupported architecture: $ARCH"
        exit 1
        ;;
esac

echo "=== Hurl Installation ==="
echo "OS: $OS_TYPE"
echo "Architecture: $ARCH"
echo "Install directory: $INSTALL_DIR"
echo ""

# Check if hurl is already installed
if command -v hurl &> /dev/null; then
    CURRENT_VERSION=$(hurl --version 2>/dev/null | head -n1 | awk '{print $2}' || echo "unknown")
    echo "⚠️  Hurl is already installed: $CURRENT_VERSION"
    read -p "Do you want to reinstall/update? (y/N) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "Installation cancelled."
        exit 0
    fi
fi

# Check if running as root for system-wide installation
if [ "$INSTALL_DIR" = "/usr/local/bin" ] && [ "$EUID" -ne 0 ]; then
    echo "⚠️  Installing to $INSTALL_DIR requires sudo privileges."
    echo "   Will use 'sudo' for installation."
    SUDO_CMD="sudo"
else
    SUDO_CMD=""
fi

# Determine download URL
if [ "$HURL_VERSION" = "latest" ]; then
    echo "Fetching latest Hurl version..."
    # Get tag name (no 'v' prefix in Hurl releases)
    TAG_NAME=$(curl -sL https://api.github.com/repos/Orange-OpenSource/hurl/releases/latest | \
               grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/')
    if [ -z "$TAG_NAME" ]; then
        echo "Error: Could not determine latest version. Using fallback..."
        TAG_NAME="8.2.0"  # Fallback version
    fi
    HURL_VERSION=$(echo "$TAG_NAME" | sed 's/^v//')
    echo "Found version: $HURL_VERSION"
else
    # Remove 'v' prefix if present
    TAG_NAME=$(echo "$HURL_VERSION" | sed 's/^v//')
    HURL_VERSION="$TAG_NAME"
fi

echo "Installing Hurl version: $HURL_VERSION"
echo ""

# Build download URL - Linux uses "unknown-linux-gnu" suffix
if [ "$OS_TYPE" = "linux" ]; then
    FILENAME="hurl-${HURL_VERSION}-${ARCH}-unknown-linux-gnu.tar.gz"
    DOWNLOAD_URL="https://github.com/Orange-OpenSource/hurl/releases/download/${TAG_NAME}/${FILENAME}"
elif [ "$OS_TYPE" = "darwin" ]; then
    if [ "$ARCH" = "aarch64" ]; then
        ARCH="arm64"
    fi
    FILENAME="hurl-${HURL_VERSION}-${ARCH}-osx.tar.gz"
    DOWNLOAD_URL="https://github.com/Orange-OpenSource/hurl/releases/download/${TAG_NAME}/${FILENAME}"
else
    echo "Error: Unsupported OS: $OS_TYPE"
    echo "Supported OS: Linux, macOS (Darwin)"
    exit 1
fi

echo "Download URL: $DOWNLOAD_URL"
echo ""

# Create temporary directory
TEMP_DIR=$(mktemp -d)
trap "rm -rf $TEMP_DIR" EXIT

cd "$TEMP_DIR"

# Download Hurl
echo "Downloading Hurl..."
DOWNLOAD_SUCCESS=false
if command -v wget &> /dev/null; then
    if wget -q "$DOWNLOAD_URL" -O "$FILENAME" 2>&1; then
        DOWNLOAD_SUCCESS=true
    fi
elif command -v curl &> /dev/null; then
    HTTP_CODE=$(curl -sSL -o "$FILENAME" -w "%{http_code}" "$DOWNLOAD_URL")
    if [ "$HTTP_CODE" = "200" ]; then
        DOWNLOAD_SUCCESS=true
    else
        echo "Error: Download failed with HTTP code: $HTTP_CODE"
        rm -f "$FILENAME"
    fi
else
    echo "Error: Neither wget nor curl is available. Please install one of them."
    exit 1
fi

if [ "$DOWNLOAD_SUCCESS" = false ] || [ ! -f "$FILENAME" ]; then
    echo "Error: Download failed!"
    echo "URL: $DOWNLOAD_URL"
    echo ""
    echo "Trying to find correct download URL..."
    # Try to get actual download URL from GitHub API
    if [ "$OS_TYPE" = "linux" ]; then
        PATTERN="${ARCH}.*unknown-linux-gnu.*tar.gz"
    else
        PATTERN="${ARCH}.*osx.*tar.gz"
    fi
    ACTUAL_URL=$(curl -sL "https://api.github.com/repos/Orange-OpenSource/hurl/releases/latest" | \
                 grep -o "\"browser_download_url\".*${PATTERN}\"" | \
                 cut -d '"' -f 4 | head -1)
    if [ -n "$ACTUAL_URL" ]; then
        echo "Found alternative URL: $ACTUAL_URL"
        echo "Retrying download..."
        if command -v wget &> /dev/null; then
            wget -q "$ACTUAL_URL" -O "$FILENAME"
        else
            curl -sSL "$ACTUAL_URL" -o "$FILENAME"
        fi
        if [ ! -f "$FILENAME" ]; then
            echo "Error: Alternative download also failed"
            exit 1
        fi
        DOWNLOAD_SUCCESS=true
    else
        echo "Please check the Hurl releases page:"
        echo "https://github.com/Orange-OpenSource/hurl/releases"
        exit 1
    fi
fi

echo "✓ Download completed"

# Extract archive
echo "Extracting archive..."
tar -xzf "$FILENAME"

# Find the hurl binary in extracted files
HURL_BINARY=$(find . -name "hurl" -type f -executable | head -n1)

if [ -z "$HURL_BINARY" ]; then
    echo "Error: Could not find 'hurl' binary in extracted archive"
    echo "Contents of archive:"
    ls -la
    exit 1
fi

# Install hurl binary
echo "Installing to $INSTALL_DIR..."
$SUDO_CMD mkdir -p "$INSTALL_DIR"
$SUDO_CMD cp "$HURL_BINARY" "$INSTALL_DIR/hurl"
$SUDO_CMD chmod +x "$INSTALL_DIR/hurl"

# Verify installation
if command -v hurl &> /dev/null; then
    INSTALLED_VERSION=$(hurl --version 2>/dev/null | head -n1 || echo "unknown")
    echo ""
    echo "✅ Hurl installed successfully!"
    echo "   Version: $INSTALLED_VERSION"
    echo "   Location: $(which hurl)"
    echo ""
    echo "Test it with:"
    echo "   hurl --version"
else
    # Check if it's in the install directory but not in PATH
    if [ -f "$INSTALL_DIR/hurl" ]; then
        echo ""
        echo "⚠️  Hurl installed to $INSTALL_DIR/hurl"
        echo "   But it's not in your PATH. Add it with:"
        echo "   export PATH=\"$INSTALL_DIR:\$PATH\""
        echo ""
        echo "   Or use: $INSTALL_DIR/hurl --version"
    else
        echo "❌ Installation failed!"
        exit 1
    fi
fi

# Cleanup
rm -rf "$TEMP_DIR"

echo ""
echo "Installation complete!"

