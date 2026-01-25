#!/bin/bash
#
# Build browser-use-sidecar as a standalone binary
#
# This script bundles browser-use's CLI into a single executable.
# The sidecar provides direct browser control without requiring 
# users to install Python/uvx.
#
# Commands available (same as browser-use CLI):
#   browser-use-sidecar open <url> [--headed]
#   browser-use-sidecar state
#   browser-use-sidecar click <index>
#   browser-use-sidecar input <index> <text>
#   browser-use-sidecar type <text>
#   browser-use-sidecar scroll <direction>
#   browser-use-sidecar keys <key>
#   browser-use-sidecar screenshot [<filename>]
#   browser-use-sidecar close
#   ... and all other browser-use commands
#

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
BUILD_DIR="$SCRIPT_DIR/build"
DIST_DIR="$SCRIPT_DIR/dist"
VENV_DIR="$SCRIPT_DIR/.venv"

echo "=== Building browser-use-sidecar ==="
echo "Script dir: $SCRIPT_DIR"
echo "Project root: $PROJECT_ROOT"

# Clean previous builds
echo ""
echo "Cleaning previous builds..."
rm -rf "$BUILD_DIR" "$DIST_DIR"

# Create/activate virtual environment
echo ""
echo "Setting up Python virtual environment..."
if [ ! -d "$VENV_DIR" ]; then
    python3 -m venv "$VENV_DIR"
fi
source "$VENV_DIR/bin/activate"

# Install dependencies
echo ""
echo "Installing dependencies..."
pip install --upgrade pip
pip install -r "$SCRIPT_DIR/requirements.txt"

# Install browser-use with CLI support
echo ""
echo "Installing browser-use CLI extras..."
pip install "browser-use[cli]>=0.11.4"

# Install Chromium via browser-use
echo ""
echo "Installing Chromium browser..."
browser-use install || echo "Note: browser-use install may require manual setup"

# Build with PyInstaller
echo ""
echo "Building standalone binary with PyInstaller..."
cd "$SCRIPT_DIR"

# Build with PyInstaller
# Using runtime_hook.py to patch urllib.request.getproxies for macOS system proxy
pyinstaller \
    --name browser-use-sidecar \
    --onefile \
    --clean \
    --noconfirm \
    --runtime-hook runtime_hook.py \
    --collect-all browser_use \
    --collect-all cdp_use \
    --collect-all bubus \
    main.py

# Verify build
if [ ! -f "$DIST_DIR/browser-use-sidecar" ]; then
    echo "ERROR: Build failed - binary not found"
    exit 1
fi

# Make executable
chmod +x "$DIST_DIR/browser-use-sidecar"

# Get file size
SIZE=$(du -h "$DIST_DIR/browser-use-sidecar" | cut -f1)
echo ""
echo "Build successful!"
echo "Binary: $DIST_DIR/browser-use-sidecar"
echo "Size: $SIZE"

# Test the binary
echo ""
echo "Testing binary..."
"$DIST_DIR/browser-use-sidecar" --help || echo "Note: --help may not work without full setup"

# Copy to Resources (optional - can be done by Xcode build phase)
RESOURCES_DIR="$PROJECT_ROOT/Motive/Resources"
if [ -d "$RESOURCES_DIR" ]; then
    echo ""
    echo "Copying to Resources..."
    rm -rf "$RESOURCES_DIR/browser-use-sidecar"
    cp "$DIST_DIR/browser-use-sidecar" "$RESOURCES_DIR/"
    echo "Copied to: $RESOURCES_DIR/browser-use-sidecar"
fi

echo ""
echo "=== Build complete ==="
echo ""
echo "The sidecar binary wraps browser-use's CLI (CDP-based, no Playwright)."
echo "Usage is identical to 'browser-use' command:"
echo ""
echo "  browser-use-sidecar open https://example.com --headed"
echo "  browser-use-sidecar state"
echo "  browser-use-sidecar click 5"
echo "  browser-use-sidecar input 3 \"search text\""
echo "  browser-use-sidecar close"
echo ""
echo "Next steps:"
echo "1. Add browser-use-sidecar to Xcode project"
echo "2. Add to 'Copy Bundle Resources' build phase"
