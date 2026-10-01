#!/bin/bash
# Scaffold a new LinuxKit package with boilerplate Dockerfile and build.yml

set -euo pipefail

if [ $# -lt 1 ]; then
    echo "Usage: $0 <package-name> [org] [architectures]"
    echo "  package-name: Name of the package (e.g., myapp)"
    echo "  org: Registry org (default: linuxkit)"
    echo "  architectures: Comma-separated list (default: amd64,arm64)"
    exit 1
fi

PACKAGE_NAME="$1"
ORG="${2:-linuxkit}"
ARCHES="${3:-amd64,arm64}"
PKG_DIR="pkg/${PACKAGE_NAME}"

if [ -d "$PKG_DIR" ]; then
    echo "❌ Package directory already exists: $PKG_DIR"
    exit 1
fi

echo "📦 Scaffolding new package: $PACKAGE_NAME"
mkdir -p "$PKG_DIR"

# Create build.yml
cat > "$PKG_DIR/build.yml" << EOF
image: ${ORG}/${PACKAGE_NAME}
org: ${ORG}
arches:
$(echo "$ARCHES" | tr ',' '\n' | while read -r arch; do echo "  - $arch"; done)
EOF

# Create Dockerfile
cat > "$PKG_DIR/Dockerfile" << 'DOCKERFILE'
FROM linuxkit/alpine:latest AS build
RUN apk add --no-cache \
    gcc \
    musl-dev \
    make

# Copy source
COPY . /tmp/src/
WORKDIR /tmp/src

# Build application
# TODO: Replace with your build commands
RUN echo "Build logic goes here"

# Final image
FROM scratch
# TODO: Copy your application and dependencies
# COPY --from=build /tmp/src/myapp /myapp
# ENTRYPOINT ["/myapp"]
DOCKERFILE

# Create .dockerignore
cat > "$PKG_DIR/.dockerignore" << 'DOCKERIGNORE'
.git
.gitignore
.gitlab-ci.yml
.github
tests
docs
README.md
LICENSE
*.md
DOCKERIGNORE

# Create build.sh (optional wrapper)
cat > "$PKG_DIR/build.sh" << 'BUILDSH'
#!/bin/bash
# Custom build script for package
set -euo pipefail

# TODO: Add custom build logic here
echo "Building ${PACKAGE_NAME}..."

# Example:
# make clean && make
BUILDSH
chmod +x "$PKG_DIR/build.sh"

echo "✅ Package scaffolded at: $PKG_DIR"
echo ""
echo "📝 Next steps:"
echo "  1. Edit $PKG_DIR/Dockerfile with your build logic"
echo "  2. Edit $PKG_DIR/build.yml metadata if needed"
echo "  3. Add any source files to $PKG_DIR/"
echo "  4. Test with: linuxkit pkg build $PKG_DIR/"
echo "  5. Push with: linuxkit pkg push $PKG_DIR/ (after 'docker login')"
echo ""
