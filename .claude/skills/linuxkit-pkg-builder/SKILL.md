---
name: linuxkit-pkg-builder
description: |
  **Build, test, and deploy LinuxKit packages with automation.** Use this skill whenever the user is working with LinuxKit package workflows — building system packages, creating multi-architecture images, running tests, or pushing to registries. Triggers on: package builds, Dockerfile creation, multi-arch compilation, package testing, container image deployment, registry pushes, build.yml configuration, or any mention of `linuxkit pkg build/push`.
compatibility: |
  - Go 1.24+ (linuxkit primary language)
  - Docker (for container image builds)
  - Linux/macOS environment with linuxkit installed
  - OCI-compliant registry access (Docker Hub, private registries)
---

# LinuxKit Package Builder Skill

This skill automates the complete LinuxKit package lifecycle: building OCI images from source, testing across architectures, and deploying to registries.

## When to Use This Skill

Invoke this skill when the user:
- Needs to build a new LinuxKit system package (init, containerd, runc, sshd, dhcpcd, etc.)
- Is creating multi-architecture (x86_64, arm64, s390x) container images
- Wants to set up package tests using the RTF (Runtime Framework) test suite
- Needs to push built packages to a Docker registry or private registry
- Is debugging package build failures or dependency issues
- Wants to scaffold a new package with boilerplate Dockerfile + build.yml
- Is automating package CI/CD or infrastructure workflows

## Package Structure Overview

Each LinuxKit package in `pkg/<name>/` contains:

```
pkg/<name>/
├── build.yml          # Package metadata (image name, dependencies, org)
├── Dockerfile         # Multi-stage build (Alpine-based, scratch final)
├── build.sh           # Optional: custom build script
├── test.sh            # Optional: test script
└── [config files]     # Any supporting files (config, scripts, etc.)
```

### build.yml Schema

The `build.yml` file defines package metadata:

```yaml
image: myorg/mypackage                # OCI image name (required)
org: myorg                            # Registry org for publishing (optional)
arches:                               # Supported architectures (optional)
  - amd64
  - arm64
  - s390x
deps:                                 # Package dependencies (optional)
  - pkg/init
  - pkg/containerd
```

### Dockerfile Pattern (Alpine-based)

LinuxKit packages follow a multi-stage pattern:

```dockerfile
FROM linuxkit/alpine:latest AS build
RUN apk add --no-cache gcc musl-dev  # Build dependencies
COPY . /tmp/src/
WORKDIR /tmp/src
RUN make

FROM scratch
COPY --from=build /tmp/src/output /    # Final artifact
ENTRYPOINT ["/myapp"]
```

## Common Workflows

### 1. Build a Single Package

```bash
linuxkit pkg build pkg/<name>/              # Build single package
linuxkit pkg build --platforms linux/amd64,linux/arm64 pkg/<name>/  # Multi-arch
```

**What happens:**
- Reads `build.yml` and `Dockerfile`
- Builds the container image
- Produces an OCI image in the local cache

### 2. Build and Push to Registry

```bash
linuxkit pkg push pkg/<name>/               # Build + push (requires org in build.yml)
linuxkit pkg build --push pkg/<name>/       # Explicit push flag
```

**Prerequisites:**
- `build.yml` must contain `org:` field
- Must be authenticated to the registry (docker login)

### 3. Multi-Architecture Builds

For packages supporting multiple architectures:

```bash
linuxkit pkg build --platforms linux/amd64,linux/arm64,linux/s390x pkg/<name>/
```

This produces a manifest list (index) with all architectures. Requires buildkit with multi-arch support.

### 4. Run Package Tests

LinuxKit uses RTF (Runtime Framework) for testing:

```bash
bin/rtf run -x test/pkg/<package-name>/    # Run tests for a package
bin/rtf run -x 'test/pkg/.*init.*'         # Regex pattern matching
```

Test files are in `test/` directory with RTF syntax (.rtf files).

### 5. Build All Packages

```bash
cd pkg && make build                        # Build all packages (via Makefile)
cd pkg && make push                         # Build and push all
```

## Automation Patterns

### Generate New Package Boilerplate

When creating a new package, generate:

1. **build.yml** with metadata and architecture support
2. **Dockerfile** with Alpine base, multi-stage pattern, and scratch final image
3. **build.sh** wrapper script for build logic
4. **.dockerignore** to optimize context

### Multi-Arch Build Matrix

For packages supporting x86_64, arm64, s390x:

```bash
for arch in amd64 arm64 s390x; do
  linuxkit pkg build --platforms linux/$arch pkg/<name>/
done
```

Or use buildkit's manifest list to combine:

```bash
linuxkit pkg manifest pkg/<name>/           # Create/update multi-arch manifest
```

### Registry Management

**Tag a package remotely (without downloading):**

```bash
linuxkit pkg remote-tag <old-image> <new-image> --registry <registry-url>
```

**Export a cached image to tar:**

```bash
linuxkit cache export <image-name> --output image.tar
```

**Import from tar:**

```bash
linuxkit cache import image.tar
```

## Dependency Management

Packages can depend on other packages (e.g., sshd depends on init). Declare in `build.yml`:

```yaml
image: myorg/sshd
deps:
  - pkg/init              # Build init first, use in Dockerfile
  - pkg/containerd
```

Then reference in Dockerfile:

```dockerfile
FROM myorg/init:latest AS init
FROM alpine:latest AS build
...
COPY --from=init / /rootfs/
```

## Output Formats & Architecture

### Supported Architectures

- `amd64` — x86_64 (Intel/AMD)
- `arm64` — ARMv8 (Raspberry Pi 4, Apple Silicon emulation)
- `s390x` — IBM System z (mainframe)

### Cache Management

All built packages are stored in `~/.linuxkit/cache/`. Before rebuilding:

```bash
linuxkit cache clean                   # Remove all cached images
linuxkit cache rm <image>              # Remove specific image
```

Use `--disable-cache` flag during build to bypass cache:

```bash
linuxkit pkg build --disable-cache pkg/<name>/
```

## Troubleshooting Build Failures

**"image not found" errors:**
- Ensure parent package dependency is built first
- Check `build.yml` deps list matches Dockerfile COPYs

**Registry push failures:**
- Verify `docker login` to the target registry
- Check `org:` field in build.yml matches registry org
- Ensure authenticated user has push permissions

**Multi-arch build hangs:**
- Confirm buildkit is installed: `buildctl --version`
- Use `--network host` flag if buildkit containers can't reach internet

**Dockerfile syntax errors:**
- Validate with `docker build --dry-run` or `buildkit`
- Check Alpine package availability: `apk search <pkg>`

## Integration with Infrastructure/Deployment

### CI/CD Pipeline Integration

Automate package builds in GitHub Actions or GitLab CI:

```yaml
# GitHub Actions example
jobs:
  build-packages:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - uses: docker/setup-buildx-action@v2
      - run: |
          cd pkg && make build
          cd pkg && make push
        env:
          REGISTRY: docker.io
          REGISTRY_USERNAME: ${{ secrets.DOCKER_USERNAME }}
          REGISTRY_PASSWORD: ${{ secrets.DOCKER_PASSWORD }}
```

### Automated Registry Deployment

After building, tag and push with metadata:

```bash
linuxkit pkg build pkg/init/
linuxkit pkg remote-tag myorg/init:latest myorg/init:v1.2.3
linuxkit pkg remote-tag myorg/init:latest myorg/init:production
```

### Multi-Registry Publish

Push the same image to multiple registries:

```bash
docker tag myorg/init:latest docker.io/myorg/init:latest
docker tag myorg/init:latest ghcr.io/myorg/init:latest
docker push docker.io/myorg/init:latest
docker push ghcr.io/myorg/init:latest
```

## Best Practices

✅ **DO:**
- Keep Dockerfiles simple and focused (one service per package)
- Use Alpine as base image (lightweight, standard in LinuxKit)
- Test packages locally before pushing: `linuxkit pkg build` then inspect
- Pin dependency versions in build.yml
- Build multi-arch early to catch architecture-specific issues
- Use `.dockerignore` to reduce build context size
- Tag releases with semantic versioning (v1.0.0, v1.1.0)

❌ **DON'T:**
- Skip local testing before registry push
- Use `latest` tag for production — always use semantic versions
- Build without specifying architectures (may only build local arch)
- Forget to login to registry before pushing
- Commit sensitive credentials in Dockerfile or build.yml
- Use `FROM scratch` without multi-stage build (makes debugging hard)

## Example: Build a New Package

**Scenario:** Create a package for a custom tool (myapp).

### Step 1: Create Directory

```bash
mkdir -p pkg/myapp
cd pkg/myapp
```

### Step 2: Create build.yml

```yaml
image: linuxkit/myapp
org: linuxkit
arches:
  - amd64
  - arm64
```

### Step 3: Create Dockerfile

```dockerfile
FROM linuxkit/alpine:latest AS build
RUN apk add --no-cache go git
COPY . /tmp/myapp/
WORKDIR /tmp/myapp/
RUN go build -o myapp .

FROM scratch
COPY --from=build /tmp/myapp/myapp /myapp
ENTRYPOINT ["/myapp"]
```

### Step 4: Build

```bash
linuxkit pkg build pkg/myapp/                        # Local arch
linuxkit pkg build --platforms linux/amd64,linux/arm64 pkg/myapp/  # Multi-arch
```

### Step 5: Push (Optional)

```bash
linuxkit pkg push pkg/myapp/                        # Requires docker login
```

### Step 6: Verify in Cache

```bash
linuxkit cache ls | grep myapp
```

## References

- [LinuxKit Documentation](https://github.com/linuxkit/linuxkit)
- [OCI Image Spec](https://github.com/opencontainers/image-spec)
- [Dockerfile Best Practices](https://docs.docker.com/develop/dev-best-practices/)
- [Alpine Linux Packages](https://pkgs.alpinelinux.org/)
