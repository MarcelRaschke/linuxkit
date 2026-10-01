#!/bin/bash
set -euo pipefail

# LinuxKit Session Start Hook
# Installs build dependencies for Claude Code on the web sessions
# Ensures tests and linters work without Docker

# Only run in remote web environment
if [ "${CLAUDE_CODE_REMOTE:-}" != "true" ]; then
  exit 0
fi

echo "📦 Installing LinuxKit build dependencies..."

# Set up Go paths
export GOPATH="${GOPATH:-$HOME/go}"
export PATH="$GOPATH/bin:$PATH"

# Verify Go is available
if ! command -v go &> /dev/null; then
  echo "❌ Go is not installed. Please install Go 1.24.3+"
  exit 1
fi

GO_VERSION=$(go version | grep -oP 'go\K[0-9]+\.[0-9]+')
echo "✓ Go $GO_VERSION is available"

# Verify git is available
if ! command -v git &> /dev/null; then
  echo "❌ Git is not installed"
  exit 1
fi
echo "✓ Git is available"

# Install golangci-lint (v2.0.2)
echo "Installing golangci-lint v2.0.2..."
go install github.com/golangci/golangci-lint/cmd/golangci-lint@v2.0.2 2>/dev/null || true

# Verify golangci-lint installation
if ! command -v golangci-lint &> /dev/null; then
  echo "⚠️  golangci-lint installation check failed, trying again..."
  export GOPATH="${GOPATH:-$HOME/go}"
  export PATH="$GOPATH/bin:$PATH"
  go install github.com/golangci/golangci-lint/cmd/golangci-lint@v2.0.2
fi

if command -v golangci-lint &> /dev/null; then
  LINT_VERSION=$(golangci-lint version 2>/dev/null | head -1 || echo "installed")
  echo "✓ golangci-lint installed: $LINT_VERSION"
else
  echo "⚠️  golangci-lint verification skipped (may be unavailable in this environment)"
fi

# Install ineffassign
echo "Installing ineffassign..."
go install github.com/gordonklaus/ineffassign@latest 2>/dev/null || true

if command -v ineffassign &> /dev/null; then
  echo "✓ ineffassign installed"
else
  echo "⚠️  ineffassign verification skipped (may be unavailable in this environment)"
fi

echo ""
echo "✅ Session setup complete!"
echo ""

# Persist environment variables for the session
if [ -n "${CLAUDE_ENV_FILE:-}" ]; then
  echo "export GOPATH=\"${GOPATH}\"" >> "$CLAUDE_ENV_FILE"
  echo "export PATH=\"$GOPATH/bin:\$PATH\"" >> "$CLAUDE_ENV_FILE"
fi

echo "Available commands:"
echo "  make local-check  - Run linters (gofmt, go vet, golangci-lint, ineffassign)"
echo "  make local-build  - Build the linuxkit binary"
echo "  make local-test   - Run Go tests"
echo "  make local        - Run all: check + build + test"
echo ""
