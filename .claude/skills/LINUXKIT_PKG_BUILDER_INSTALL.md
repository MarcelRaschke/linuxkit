# LinuxKit Package Builder Skill - Installation & Deployment Guide

## Quick Start (2 minutes)

### Option 1: Direct Installation (Local)

```bash
# Copy skill to your .claude/skills directory
cp -r /home/user/linuxkit/.claude/skills/linuxkit-pkg-builder ~/.claude/skills/

# Verify installation
ls -la ~/.claude/skills/linuxkit-pkg-builder/
```

### Option 2: From Archive

```bash
# Extract the skill package
cd ~/.claude/skills/
tar -xzf linuxkit-pkg-builder.skill.tar.gz

# Verify
ls -la linuxkit-pkg-builder/
```

---

## Installation Files

### What's Included

```
linuxkit-pkg-builder/
├── SKILL.md                           # Main skill documentation
├── README.md                          # Quick reference
├── scripts/
│   ├── scaffold-package.sh           # Create new package boilerplate
│   ├── build-and-test.sh             # Build + optional push automation
│   └── multi-arch-build.sh           # Multi-architecture builds
└── evals/
    └── evals.json                    # Test cases for validation
```

### File Sizes

- **SKILL.md**: 9.6 KB (core documentation)
- **README.md**: 2.9 KB (quick reference)
- **scripts/*.sh**: 6.9 KB total (automation)
- **evals/**: 2.5 KB (test cases)
- **Total**: ~21.9 KB

---

## Deployment Checklist

- [ ] Copy skill to `~/.claude/skills/linuxkit-pkg-builder/`
- [ ] Make scripts executable: `chmod +x ~/.claude/skills/linuxkit-pkg-builder/scripts/*.sh`
- [ ] Verify SKILL.md is readable
- [ ] Test skill loading (see verification below)
- [ ] Update Claude configuration if needed

---

## Verification

### Verify Installation

```bash
# Check files exist
ls -la ~/.claude/skills/linuxkit-pkg-builder/SKILL.md
ls -la ~/.claude/skills/linuxkit-pkg-builder/scripts/

# Verify scripts are executable
test -x ~/.claude/skills/linuxkit-pkg-builder/scripts/scaffold-package.sh && echo "✅ Scripts executable"
```

### Test Skill Triggering

In Claude Code or Claude.ai, try:

```
"I need to create a new LinuxKit package called myapp for amd64 and arm64 architectures"
```

The skill should trigger automatically and provide scaffolding guidance.

---

## Usage Examples

### 1. Scaffold a New Package

```bash
~/.claude/skills/linuxkit-pkg-builder/scripts/scaffold-package.sh mypackage myorg amd64,arm64
```

### 2. Build and Push

```bash
~/.claude/skills/linuxkit-pkg-builder/scripts/build-and-test.sh pkg/mypackage/ --push --platforms linux/amd64,linux/arm64
```

### 3. Multi-Architecture Build

```bash
~/.claude/skills/linuxkit-pkg-builder/scripts/multi-arch-build.sh pkg/init/ "amd64 arm64 s390x"
```

---

## Triggering Scenarios

The skill will automatically trigger on:

- "Build a LinuxKit package"
- "Create multi-architecture images"
- "Push to Docker registry"
- "New package for"
- "Package build failed"
- "GitHub Actions for packages"
- "Multi-arch build workflow"
- "LinuxKit pkg build"
- "Dockerfile for package"
- "Registry push"

---

## Configuration

### Optional: Customize Script Locations

If you place scripts elsewhere, update references in your workflows:

```bash
# Default location
~/.claude/skills/linuxkit-pkg-builder/scripts/scaffold-package.sh

# Custom location (if needed)
export LINUXKIT_SKILL_PATH="/path/to/skills/linuxkit-pkg-builder"
$LINUXKIT_SKILL_PATH/scripts/scaffold-package.sh
```

### Optional: Environment Variables

Scripts respect these variables:

```bash
# For scaffold-package.sh
PACKAGE_NAME="myapp"
ORG="myorg"
ARCHES="amd64,arm64"

# For build-and-test.sh
PKG_PATH="pkg/init"
PUSH_ENABLED="true"
PLATFORMS="linux/amd64,linux/arm64,linux/s390x"
```

---

## Troubleshooting

### Skill Not Triggering?

1. Verify SKILL.md exists: `cat ~/.claude/skills/linuxkit-pkg-builder/SKILL.md | head -5`
2. Check file permissions: `ls -la ~/.claude/skills/linuxkit-pkg-builder/`
3. Restart Claude Code/session
4. Try explicit mention: "Use the linuxkit-pkg-builder skill"

### Scripts Not Executing?

```bash
# Make executable
chmod +x ~/.claude/skills/linuxkit-pkg-builder/scripts/*.sh

# Verify
file ~/.claude/skills/linuxkit-pkg-builder/scripts/scaffold-package.sh
```

### Permission Denied?

```bash
# Check ownership
ls -la ~/.claude/skills/linuxkit-pkg-builder/

# Fix ownership if needed
chown -R $USER ~/.claude/skills/linuxkit-pkg-builder/
chmod -R u+rx ~/.claude/skills/linuxkit-pkg-builder/scripts/
```

---

## Uninstallation

To remove the skill:

```bash
rm -rf ~/.claude/skills/linuxkit-pkg-builder/
```

---

## Support & Updates

### Check Version

```bash
head -5 ~/.claude/skills/linuxkit-pkg-builder/SKILL.md | grep -i "name:"
```

### View Documentation

```bash
cat ~/.claude/skills/linuxkit-pkg-builder/README.md
cat ~/.claude/skills/linuxkit-pkg-builder/SKILL.md | less
```

### Run Tests

```bash
cat ~/.claude/skills/linuxkit-pkg-builder/evals/evals.json | jq '.evals | length'
```

---

## Next Steps

1. **Install** the skill in your `.claude/skills/` directory
2. **Test** by asking Claude to scaffold a package
3. **Use** the automation scripts for your LinuxKit workflows
4. **Customize** scripts as needed for your environment

---

## Distribution

### Share with Team

```bash
# Create shareable archive
cd ~/.claude/skills/
tar -czf linuxkit-pkg-builder-latest.tar.gz linuxkit-pkg-builder/

# Share file or instructions
ls -lh linuxkit-pkg-builder-latest.tar.gz
```

### Installation for Others

```bash
# Recipient extracts and installs
mkdir -p ~/.claude/skills/
cd ~/.claude/skills/
tar -xzf linuxkit-pkg-builder-latest.tar.gz
chmod +x linuxkit-pkg-builder/scripts/*.sh
```

---

**Installation complete!** The linuxkit-pkg-builder skill is ready for production use.
