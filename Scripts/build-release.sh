#!/bin/bash
set -e

# Build Release Script for Motive
# Creates separate DMGs for arm64 (Apple Silicon) and x86_64 (Intel)
#
# Usage:
#   ./build-release.sh          # Build with current version
#   ./build-release.sh patch    # Bump patch version (0.1.0 → 0.1.1)
#   ./build-release.sh minor    # Bump minor version (0.1.0 → 0.2.0)
#   ./build-release.sh major    # Bump major version (0.1.0 → 1.0.0)

APP_NAME="Motive"
SCHEME="Motive"
PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
BUILD_DIR="$PROJECT_DIR/build"
RELEASE_DIR="$PROJECT_DIR/release"
PBXPROJ="$PROJECT_DIR/$APP_NAME.xcodeproj/project.pbxproj"

# OpenCode release URLs
OPENCODE_ARM64_URL="https://github.com/opencode-ai/opencode/releases/latest/download/opencode-mac-arm64.tar.gz"
OPENCODE_X64_URL="https://github.com/opencode-ai/opencode/releases/latest/download/opencode-mac-x86_64.tar.gz"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log() { echo -e "${GREEN}[BUILD]${NC} $1"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
error() { echo -e "${RED}[ERROR]${NC} $1"; exit 1; }
info() { echo -e "${BLUE}[INFO]${NC} $1"; }

# Clean previous builds
clean() {
    log "Cleaning previous builds..."
    rm -rf "$BUILD_DIR"
    rm -rf "$RELEASE_DIR"
    mkdir -p "$BUILD_DIR"
    mkdir -p "$RELEASE_DIR"
}

# Download OpenCode binary for specific architecture
download_opencode() {
    local arch=$1
    local url=$2
    local tarball="$BUILD_DIR/opencode-$arch.tar.gz"
    local dest="$BUILD_DIR/opencode-$arch"
    
    log "Downloading OpenCode for $arch..."
    curl -L -f "$url" -o "$tarball" || error "Failed to download OpenCode for $arch"
    
    log "Extracting OpenCode for $arch..."
    tar -xzf "$tarball" -C "$BUILD_DIR"
    mv "$BUILD_DIR/opencode" "$dest"
    rm "$tarball"
    
    chmod +x "$dest"
    log "Downloaded and extracted OpenCode for $arch"
}

# Build app for specific architecture
build_app() {
    local arch=$1
    local build_path="$BUILD_DIR/$arch"
    
    log "Building $APP_NAME for $arch..."
    
    xcodebuild -project "$PROJECT_DIR/$APP_NAME.xcodeproj" \
        -scheme "$SCHEME" \
        -configuration Release \
        -arch "$arch" \
        -derivedDataPath "$build_path" \
        ONLY_ACTIVE_ARCH=NO \
        MACOSX_DEPLOYMENT_TARGET=15.0 \
        clean build
    
    log "Build complete for $arch"
}

# Copy OpenCode binary into app bundle
inject_opencode() {
    local arch=$1
    local build_path="$BUILD_DIR/$arch"
    local app_path="$build_path/Build/Products/Release/$APP_NAME.app"
    local resources_path="$app_path/Contents/Resources"
    local opencode_src="$BUILD_DIR/opencode-$arch"
    
    log "Injecting OpenCode binary into $arch app bundle..."
    
    if [ ! -d "$app_path" ]; then
        error "App not found at $app_path"
    fi
    
    mkdir -p "$resources_path"
    cp "$opencode_src" "$resources_path/opencode"
    chmod +x "$resources_path/opencode"
    
    # Sign the binary
    log "Signing OpenCode binary..."
    codesign --remove-signature "$resources_path/opencode" 2>/dev/null || true
    codesign --force --sign - "$resources_path/opencode"
    
    log "OpenCode injected for $arch"
}

# Re-sign the entire app bundle
sign_app() {
    local arch=$1
    local build_path="$BUILD_DIR/$arch"
    local app_path="$build_path/Build/Products/Release/$APP_NAME.app"
    
    log "Signing app bundle for $arch..."
    
    # Sign with ad-hoc signature (use your Developer ID for distribution)
    codesign --force --deep --sign - "$app_path"
    
    log "App signed for $arch"
}

# Create DMG
create_dmg() {
    local arch=$1
    local build_path="$BUILD_DIR/$arch"
    local app_path="$build_path/Build/Products/Release/$APP_NAME.app"
    local dmg_name="$APP_NAME-$arch.dmg"
    local dmg_path="$RELEASE_DIR/$dmg_name"
    local staging_dir="$BUILD_DIR/dmg-staging-$arch"
    
    log "Creating DMG for $arch..."
    
    # Create staging directory
    rm -rf "$staging_dir"
    mkdir -p "$staging_dir"
    
    # Copy app
    cp -R "$app_path" "$staging_dir/"
    
    # Create symbolic link to Applications
    ln -s /Applications "$staging_dir/Applications"
    
    # Create DMG
    hdiutil create -volname "$APP_NAME" \
        -srcfolder "$staging_dir" \
        -ov -format UDZO \
        "$dmg_path"
    
    # Clean up
    rm -rf "$staging_dir"
    
    log "DMG created: $dmg_path"
}

# Get current version from project.pbxproj
get_version() {
    local version=$(grep "MARKETING_VERSION" "$PBXPROJ" | head -1 | sed 's/.*= *\([^;]*\);/\1/' | tr -d ' ')
    echo "${version:-0.1.0}"
}

# Bump version based on type (patch/minor/major)
bump_version() {
    local current=$1
    local bump_type=$2
    
    # Parse version components
    local major=$(echo "$current" | cut -d. -f1)
    local minor=$(echo "$current" | cut -d. -f2)
    local patch=$(echo "$current" | cut -d. -f3)
    
    # Default to 0 if not present
    major=${major:-0}
    minor=${minor:-0}
    patch=${patch:-0}
    
    case $bump_type in
        patch)
            patch=$((patch + 1))
            ;;
        minor)
            minor=$((minor + 1))
            patch=0
            ;;
        major)
            major=$((major + 1))
            minor=0
            patch=0
            ;;
        *)
            error "Invalid bump type: $bump_type (use: patch, minor, major)"
            ;;
    esac
    
    echo "$major.$minor.$patch"
}

# Update version in project.pbxproj
set_version() {
    local new_version=$1
    
    log "Updating version to $new_version in project.pbxproj..."
    
    # Replace all MARKETING_VERSION occurrences
    sed -i '' "s/MARKETING_VERSION = [^;]*;/MARKETING_VERSION = $new_version;/g" "$PBXPROJ"
    
    log "Version updated to $new_version"
}

# Main build process
main() {
    local bump_type=$1
    
    log "Starting release build for $APP_NAME"
    log "Project directory: $PROJECT_DIR"
    
    # Get current version
    CURRENT_VERSION=$(get_version)
    info "Current version: $CURRENT_VERSION"
    
    # Bump version if requested
    if [ -n "$bump_type" ]; then
        VERSION=$(bump_version "$CURRENT_VERSION" "$bump_type")
        set_version "$VERSION"
        log "Version bumped: $CURRENT_VERSION → $VERSION ($bump_type)"
    else
        VERSION="$CURRENT_VERSION"
        info "Building with current version: $VERSION"
    fi
    
    # Clean
    clean
    
    # Download OpenCode binaries
    download_opencode "arm64" "$OPENCODE_ARM64_URL"
    download_opencode "x86_64" "$OPENCODE_X64_URL"
    
    # Build for arm64 (Apple Silicon)
    log "=== Building for Apple Silicon (arm64) ==="
    build_app "arm64"
    inject_opencode "arm64"
    sign_app "arm64"
    create_dmg "arm64"
    
    # Build for x86_64 (Intel)
    log "=== Building for Intel (x86_64) ==="
    build_app "x86_64"
    inject_opencode "x86_64"
    sign_app "x86_64"
    create_dmg "x86_64"
    
    # Rename with version
    mv "$RELEASE_DIR/$APP_NAME-arm64.dmg" "$RELEASE_DIR/$APP_NAME-$VERSION-arm64.dmg"
    mv "$RELEASE_DIR/$APP_NAME-x86_64.dmg" "$RELEASE_DIR/$APP_NAME-$VERSION-x86_64.dmg"
    
    log "=== Build Complete ==="
    log "Release files:"
    ls -la "$RELEASE_DIR"
}

# Run
main "$@"
