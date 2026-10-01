#!/bin/bash
# Build a package for multiple architectures and create manifest

set -euo pipefail

if [ $# -lt 1 ]; then
    echo "Usage: $0 <package-path> [architectures]"
    echo "  package-path: Path to package (e.g., pkg/init)"
    echo "  architectures: Space-separated list (default: amd64 arm64 s390x)"
    exit 1
fi

PKG_PATH="$1"
ARCHES="${2:-amd64 arm64 s390x}"

if [ ! -d "$PKG_PATH" ] || [ ! -f "$PKG_PATH/build.yml" ]; then
    echo "❌ Invalid package path: $PKG_PATH"
    exit 1
fi

PACKAGE_NAME=$(basename "$PKG_PATH")
IMAGE_NAME=$(grep "^image:" "$PKG_PATH/build.yml" | cut -d' ' -f2)
ORG=$(grep "^org:" "$PKG_PATH/build.yml" | cut -d' ' -f2)

echo "🏛️  Multi-arch build for: $PACKAGE_NAME"
echo "📦 Image: $IMAGE_NAME"
echo "🏗️  Architectures: $ARCHES"
echo ""

# Build for each architecture
BUILT_IMAGES=()
for arch in $ARCHES; do
    case "$arch" in
        amd64)
            PLATFORM="linux/amd64"
            ;;
        arm64)
            PLATFORM="linux/arm64"
            ;;
        s390x)
            PLATFORM="linux/s390x"
            ;;
        *)
            echo "❌ Unknown architecture: $arch"
            exit 1
            ;;
    esac

    echo "▶️  Building for $arch ($PLATFORM)..."
    if linuxkit pkg build --platforms "$PLATFORM" "$PKG_PATH"; then
        echo "✅ Built for $arch"
        BUILT_IMAGES+=("$IMAGE_NAME:$arch")
    else
        echo "❌ Build failed for $arch"
        exit 1
    fi
    echo ""
done

echo "✅ All architectures built successfully"
echo ""
echo "📊 Built images:"
for img in "${BUILT_IMAGES[@]}"; do
    echo "  - $img"
done
echo ""

# Offer to create manifest
echo "Next steps:"
echo "  1. Tag each image: docker tag $IMAGE_NAME:amd64 <registry>/image:amd64"
echo "  2. Push each: docker push <registry>/image:amd64"
echo "  3. Create manifest: docker manifest create --amend <registry>/image:latest \\"
echo "       <registry>/image:amd64 <registry>/image:arm64 <registry>/image:s390x"
echo "  4. Annotate architectures: docker manifest annotate <registry>/image:latest \\"
echo "       <registry>/image:arm64 --os linux --arch arm64"
echo "  5. Push manifest: docker manifest push <registry>/image:latest"
echo ""
echo "Or use: linuxkit pkg manifest $PKG_PATH/"
echo ""
