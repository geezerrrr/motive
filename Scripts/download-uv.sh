#!/bin/bash
#
# Download uv binary for bundling with Motive
#
# uv is a fast Python package installer that can run browser-use
# without requiring users to install Python/pip/uvx manually.
#
# Usage: ./download-uv.sh
#

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
RESOURCES_DIR="$PROJECT_ROOT/Motive/Resources"

# Detect architecture
ARCH=$(uname -m)
if [ "$ARCH" = "arm64" ]; then
    UV_ARCH="aarch64"
elif [ "$ARCH" = "x86_64" ]; then
    UV_ARCH="x86_64"
else
    echo "Unsupported architecture: $ARCH"
    exit 1
fi

UV_URL="https://github.com/astral-sh/uv/releases/latest/download/uv-${UV_ARCH}-apple-darwin.tar.gz"

echo "=== Downloading uv binary ==="
echo "Architecture: $ARCH -> $UV_ARCH"
echo "URL: $UV_URL"

# Create temp directory
TEMP_DIR=$(mktemp -d)
cd "$TEMP_DIR"

# Download and extract
echo ""
echo "Downloading..."
curl -LsSf "$UV_URL" -o uv.tar.gz

echo "Extracting..."
tar -xzf uv.tar.gz

# Find the uv binary
UV_BINARY=$(find . -name "uv" -type f | head -1)
if [ -z "$UV_BINARY" ]; then
    echo "ERROR: uv binary not found in archive"
    ls -la
    exit 1
fi

# Check binary
echo ""
echo "Binary info:"
file "$UV_BINARY"
ls -lh "$UV_BINARY"

# Copy to Resources
echo ""
echo "Copying to $RESOURCES_DIR..."
mkdir -p "$RESOURCES_DIR"
cp "$UV_BINARY" "$RESOURCES_DIR/uv"
chmod +x "$RESOURCES_DIR/uv"

# Cleanup
rm -rf "$TEMP_DIR"

# Verify
echo ""
echo "=== Done ==="
echo "uv binary installed at: $RESOURCES_DIR/uv"
"$RESOURCES_DIR/uv" --version

echo ""
echo "Next steps:"
echo "1. Add 'uv' to Xcode project (if not already)"
echo "2. OpenCode can now use: \$RESOURCES_PATH/uv tool run browser-use <command>"
