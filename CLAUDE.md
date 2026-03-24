# CLAUDE.md — LinuxKit

## Project Overview

LinuxKit is a toolkit for building custom, minimal, and immutable Linux distributions using containers. It produces secure-by-default images deployable to cloud (AWS, GCP, Azure), hypervisors (QEMU, HyperKit, Hyper-V, VMware, VirtualBox), and bare metal (Equinix Metal, Raspberry Pi). Supports x86_64, arm64, and s390x architectures.

## Repository Structure

```
src/cmd/linuxkit/   # Main CLI tool (Go) — the core of the project
  pkglib/           # Package build library
  moby/             # Image assembly (moby tool logic)
  spec/             # OCI/image spec helpers
  registry/         # Registry interaction
  cache_*.go        # Local image cache management
  run_*.go          # Platform-specific runners (qemu, hyperkit, aws, gcp, azure, vmware, etc.)
  push_*.go         # Push targets (cloud providers, registries)
pkg/                # ~42 system packages (init, containerd, runc, sshd, dhcpcd, etc.)
kernel/             # Kernel builds (5.4.x through 6.12.x)
tools/              # Build tool images (go-compile, mkimage-*, alpine base, grub, etc.)
test/               # RTF-based test suite
docs/               # Documentation (40+ markdown files)
projects/           # Long-term collaborative projects (kubernetes, compose, etc.)
examples/           # Example LinuxKit YAML configurations
scripts/            # Utility scripts
```

## Build Commands

### CLI Tool

```bash
make                    # Build linuxkit binary (output: bin/linuxkit)
make local-build        # Build locally with Go (no Docker)
make local-test         # Run Go unit tests: go test -mod=vendor ./...
make local-check        # Run linters: gofmt, go vet, golangci-lint, ineffassign
make local              # All three: local-check + local-build + local-test
make test-cross         # Cross-compile for darwin, windows, linux
```

### Packages

```bash
cd pkg && make build              # Build all packages
linuxkit pkg build pkg/<name>/    # Build a single package
cd pkg && make push               # Push all packages
```

### Tests

```bash
make test                           # Run full test suite via RTF
bin/rtf -l <label> run -x           # Run tests by label
bin/rtf run -x <pattern>            # Run tests matching pattern
```

Test labels: `linuxkit.packages`, `linuxkit.kernel`, `linuxkit.build`, `linuxkit.platforms`, `linuxkit.security`, `linuxkit.examples`

## Language & Tooling

- **Go 1.24.3** (toolchain 1.24.12) — primary language for CLI
- Vendor mode: `GO_FLAGS=-mod=vendor` (all dependencies vendored)
- Linting: `golangci-lint v2.0.2`, `go vet`, `gofmt -s`, `ineffassign`
- CI: GitHub Actions with matrix builds across 6 OS/arch combos and 12 test shards
- Builds use a Docker-based `go-compile` container for reproducibility

## Coding Conventions

### Go
- Format with `gofmt -s`
- Vendored dependencies (`-mod=vendor`) — run `go mod vendor` after dependency changes
- All Go source lives under `src/cmd/linuxkit/`

### Shell Scripts
- Use tabs for indentation (Alpine/Linux kernel style)
- Run `shellcheck` on scripts

### C Code
- Follow Linux kernel coding guidelines
- Validate with `checkpatch.pl --no-tree --file <source>`

### Git Commits
- Max 50-char imperative summary line
- Sign off required: `Signed-off-by: Name <email>` (DCO)
- Squash into logical units before PR
- Reference issues: `Closes #XXXX` or `Fixes #XXXX`

## Package Structure

Each package in `pkg/<name>/` contains:
- `build.yml` — package metadata (image name, dependencies, org)
- `Dockerfile` — multi-stage build (typically Alpine-based with scratch final image)
- Supporting scripts and config files

Packages are OCI images built with `linuxkit pkg build` and pushed with `linuxkit pkg push`.

## Key Architecture Notes

- LinuxKit images are assembled from YAML configs (see `linuxkit.yml`, `examples/`)
- The YAML defines: kernel, init, onboot, onshutdown, services, and files sections
- Images are immutable — no package manager at runtime
- All system components run as containers (containerd + runc)
- Output formats: ISO, raw, QCOW2, VHD, VMDK, AWS AMI, GCP image, tar
