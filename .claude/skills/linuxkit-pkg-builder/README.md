# LinuxKit Package Builder Skill

A comprehensive skill for building, testing, and deploying LinuxKit packages with multi-architecture support.

## Skill Contents

```
linuxkit-pkg-builder/
├── SKILL.md                    # Main skill documentation
├── README.md                   # This file
├── evals/
│   └── evals.json             # Test cases for skill evaluation
└── scripts/
    ├── scaffold-package.sh     # Create new package boilerplate
    ├── build-and-test.sh       # Build and optionally push
    └── multi-arch-build.sh     # Build for multiple architectures
```

## Features

✅ **Package Scaffolding** — Generate boilerplate for new packages
✅ **Multi-Architecture Builds** — Build for amd64, arm64, s390x
✅ **Registry Management** — Push to Docker Hub, private registries
✅ **CI/CD Integration** — GitHub Actions, GitLab CI examples
✅ **Dependency Resolution** — Handle package dependencies
✅ **Build Troubleshooting** — Diagnose and fix build failures

## Quick Start

### 1. Create a New Package

```bash
.claude/skills/linuxkit-pkg-builder/scripts/scaffold-package.sh myapp myorg amd64,arm64
```

This creates:
- `pkg/myapp/build.yml` — package metadata
- `pkg/myapp/Dockerfile` — multi-stage build
- `pkg/myapp/build.sh` — optional build wrapper
- `pkg/myapp/.dockerignore` — build context optimization

### 2. Build Locally

```bash
linuxkit pkg build pkg/myapp/
```

### 3. Build Multi-Arch

```bash
.claude/skills/linuxkit-pkg-builder/scripts/multi-arch-build.sh pkg/myapp/ "amd64 arm64 s390x"
```

### 4. Build and Push

```bash
.claude/skills/linuxkit-pkg-builder/scripts/build-and-test.sh pkg/myapp/ --push
```

## When to Use This Skill

Trigger on:
- "build a LinuxKit package"
- "create multi-arch images"
- "push to registry"
- "new package for"
- "package build failed"
- "architecture support"
- "deploy to registry"
- "GitHub Actions for packages"

## Workflow Overview

1. **Scaffold** — Use scaffold-package.sh to create boilerplate
2. **Develop** — Edit Dockerfile with your build logic
3. **Test** — Run `linuxkit pkg build` to verify locally
4. **Push** — Authenticate with `docker login`, then push
5. **Automate** — Set up CI/CD with GitHub Actions

## Integration Points

- **LinuxKit CLI** — `linuxkit pkg build/push/manifest`
- **Docker CLI** — `docker login`, `docker push`, `docker manifest`
- **buildkit** — Multi-architecture build support
- **OCI Registries** — Docker Hub, GHCR, private registries

## Test Cases

Five realistic test cases in `evals/evals.json`:

1. Scaffold a new package structure
2. Fix dependency issues in failing builds
3. Multi-arch build and manifest workflow
4. GitHub Actions CI/CD setup
5. End-to-end explanation and walkthrough

## See Also

- LinuxKit CLAUDE.md for repository structure
- pkg/ directory for existing package examples
- bin/rtf for running tests
