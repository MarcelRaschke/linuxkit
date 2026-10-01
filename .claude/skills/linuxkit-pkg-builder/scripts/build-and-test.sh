#!/bin/bash
# Build, test, and optionally push a LinuxKit package

set -euo pipefail

if [ $# -lt 1 ]; then
    echo "Usage: $0 <package-path> [--push] [--platforms linux/amd64,linux/arm64]"
    echo "  package-path: Path to package (e.g., pkg/init)"
    echo "  --push: Also push to registry (requires docker login)"
    echo "  --platforms: Specify architectures (default: native)"
    exit 1
fi

PKG_PATH="$1"
PUSH_ENABLED=false
PLATFORMS=""

# Parse additional arguments
shift || true
while [ $# -gt 0 ]; do
    case "$1" in
        --push)
            PUSH_ENABLED=true
            shift
            ;;
        --platforms)
            PLATFORMS="$2"
            shift 2
            ;;
        *)
            echo "Unknown option: $1"
            exit 1
            ;;
    esac
done

if [ ! -d "$PKG_PATH" ] || [ ! -f "$PKG_PATH/build.yml" ]; then
    echo "❌ Invalid package path: $PKG_PATH (missing build.yml)"
    exit 1
fi

PACKAGE_NAME=$(basename "$PKG_PATH")
echo "🏗️  Building package: $PACKAGE_NAME"

# Extract image name from build.yml
IMAGE_NAME=$(grep "^image:" "$PKG_PATH/build.yml" | cut -d' ' -f2)
echo "📦 Image: $IMAGE_NAME"

# Build command
BUILD_CMD="linuxkit pkg build"
if [ -n "$PLATFORMS" ]; then
    BUILD_CMD="$BUILD_CMD --platforms $PLATFORMS"
    echo "🏛️  Platforms: $PLATFORMS"
fi
BUILD_CMD="$BUILD_CMD $PKG_PATH"

# Execute build
echo ""
echo "▶️  Running: $BUILD_CMD"
echo ""
if ! eval "$BUILD_CMD"; then
    echo "❌ Build failed"
    exit 1
fi
echo ""
echo "✅ Build succeeded"

# Verify in cache
if linuxkit cache ls | grep -q "$IMAGE_NAME"; then
    echo "✓ Image verified in cache"
else
    echo "⚠️  Warning: Image not found in cache (may be pushed already)"
fi

# Push if requested
if [ "$PUSH_ENABLED" = true ]; then
    echo ""
    echo "🚀 Pushing to registry..."

    # Check if org is defined (required for push)
    ORG=$(grep "^org:" "$PKG_PATH/build.yml" | cut -d' ' -f2)
    if [ -z "$ORG" ]; then
        echo "❌ Push requires 'org:' field in build.yml"
        exit 1
    fi

    # Verify docker login
    if ! docker info > /dev/null 2>&1; then
        echo "❌ Docker not available. Run 'docker login' first."
        exit 1
    fi

    PUSH_CMD="linuxkit pkg push $PKG_PATH"
    echo "▶️  Running: $PUSH_CMD"
    if ! eval "$PUSH_CMD"; then
        echo "❌ Push failed"
        exit 1
    fi
    echo "✅ Push succeeded"
fi

echo ""
echo "🎉 Package build complete: $IMAGE_NAME"
echo ""
