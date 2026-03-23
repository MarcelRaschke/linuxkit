#!/usr/bin/env bash
# ============================================================================
# Kali NetHunter Chroot Setup for Pritom Tab10 Max M10-R02 (Android 14)
# ============================================================================
#
# This script sets up a Kali Linux chroot/proot environment on an Android
# tablet using Termux. No root required for proot mode; root unlocks full
# chroot mode with better hardware access.
#
# USAGE (run inside Termux on the tablet):
#   curl -fsSL https://raw.githubusercontent.com/.../nethunter-setup.sh | bash
#   # or after copying to the tablet:
#   bash nethunter-setup.sh [--root]
#
# OPTIONS:
#   --root      Use native chroot (requires root / Magisk)
#   --tools     Install Kali security tools after setup (needs network)
#   --vnc       Install VNC server for graphical desktop access
#   --help      Show this help
#
# REQUIREMENTS:
#   - Termux installed from F-Droid (NOT Google Play — Play version is outdated)
#   - At least 4 GB free storage for base install
#   - Internet connection during initial setup
#
# ============================================================================

set -euo pipefail

# ---- Configuration ---------------------------------------------------------

KALI_ROOTFS_URL_ARM64="https://kali.download/nethunter-images/current/rootfs/kalifs-arm64-full.tar.xz"
KALI_ROOTFS_URL_ARM64_MINIMAL="https://kali.download/nethunter-images/current/rootfs/kalifs-arm64-minimal.tar.xz"
KALI_INSTALL_DIR="${HOME}/kali-arm64"
KALI_LAUNCH_SCRIPT="${PREFIX}/bin/kali"
USE_ROOT=false
INSTALL_TOOLS=false
INSTALL_VNC=false
INSTALL_MINIMAL=false

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# ---- Argument parsing -------------------------------------------------------

for arg in "$@"; do
  case "$arg" in
    --root)     USE_ROOT=true ;;
    --tools)    INSTALL_TOOLS=true ;;
    --vnc)      INSTALL_VNC=true ;;
    --minimal)  INSTALL_MINIMAL=true ;;
    --help|-h)
      sed -n '3,30p' "$0"
      exit 0
      ;;
    *)
      echo -e "${RED}Unknown option: $arg${NC}"
      exit 1
      ;;
  esac
done

# ---- Helper functions -------------------------------------------------------

info()    { echo -e "${BLUE}[*]${NC} $*"; }
success() { echo -e "${GREEN}[+]${NC} $*"; }
warn()    { echo -e "${YELLOW}[!]${NC} $*"; }
error()   { echo -e "${RED}[-]${NC} $*"; exit 1; }

check_termux() {
  if [ -z "${PREFIX:-}" ] || [ ! -d "$PREFIX" ]; then
    error "This script must be run inside Termux. Install Termux from F-Droid."
  fi
  info "Termux detected: $PREFIX"
}

check_storage() {
  local avail
  avail=$(df -BG "$HOME" | awk 'NR==2 {print $4}' | tr -d 'G')
  if [ "${avail:-0}" -lt 4 ]; then
    warn "Available storage: ${avail}GB — at least 4GB recommended"
    read -rp "Continue anyway? [y/N] " confirm
    [[ "$confirm" =~ ^[Yy]$ ]] || exit 0
  fi
  success "Storage check passed (${avail}GB available)"
}

check_root() {
  if $USE_ROOT; then
    if ! command -v su &>/dev/null; then
      error "Root mode requested (--root) but 'su' not found. Install Magisk first."
    fi
    if ! su -c "id" &>/dev/null 2>&1; then
      error "Root access denied. Grant Termux root permissions in Magisk."
    fi
    success "Root access confirmed"
  fi
}

install_termux_deps() {
  info "Updating Termux packages..."
  pkg update -y -o Dpkg::Options::="--force-confnew" 2>/dev/null || true

  local deps=(curl wget tar proot proot-distro)
  if $USE_ROOT; then
    deps=(curl wget tar)
  fi

  info "Installing dependencies: ${deps[*]}"
  pkg install -y "${deps[@]}" 2>/dev/null || \
    apt-get install -y "${deps[@]}" 2>/dev/null || \
    error "Failed to install dependencies. Run 'pkg update' manually first."

  if $INSTALL_VNC; then
    info "Installing VNC dependencies..."
    pkg install -y tigervnc x11-repo 2>/dev/null || true
    pkg install -y xfce4 2>/dev/null || \
      warn "XFCE4 install failed — VNC will use basic window manager"
  fi

  success "Termux dependencies installed"
}

# ---- Rootfs download --------------------------------------------------------

download_kali_rootfs() {
  local url
  if $INSTALL_MINIMAL; then
    url="$KALI_ROOTFS_URL_ARM64_MINIMAL"
    info "Downloading Kali Linux ARM64 minimal rootfs..."
  else
    url="$KALI_ROOTFS_URL_ARM64"
    info "Downloading Kali Linux ARM64 full rootfs (~1.5GB)..."
  fi

  local tarball="${TMPDIR:-/tmp}/kali-rootfs.tar.xz"

  if [ -f "$tarball" ]; then
    info "Existing tarball found, verifying..."
    if ! file "$tarball" | grep -q 'XZ compressed\|gzip compressed'; then
      warn "Corrupt tarball detected, re-downloading..."
      rm -f "$tarball"
    fi
  fi

  if [ ! -f "$tarball" ]; then
    curl -L --retry 5 --retry-delay 3 --progress-bar -o "$tarball" "$url" || \
      wget -O "$tarball" "$url" || \
      error "Failed to download Kali rootfs. Check your internet connection."
  fi

  info "Extracting Kali rootfs to $KALI_INSTALL_DIR ..."
  mkdir -p "$KALI_INSTALL_DIR"
  proot --link2symlink tar -xJf "$tarball" -C "$KALI_INSTALL_DIR" \
    --exclude='dev' 2>/dev/null || \
    tar -xJf "$tarball" -C "$KALI_INSTALL_DIR" \
      --exclude='dev' 2>/dev/null || \
    error "Extraction failed."

  rm -f "$tarball"
  success "Kali rootfs extracted"
}

# ---- System configuration ---------------------------------------------------

configure_kali_rootfs() {
  info "Configuring Kali chroot environment..."

  # resolv.conf for DNS
  cat > "$KALI_INSTALL_DIR/etc/resolv.conf" <<'EOF'
nameserver 8.8.8.8
nameserver 8.8.4.4
nameserver 1.1.1.1
EOF

  # hosts file
  cat > "$KALI_INSTALL_DIR/etc/hosts" <<'EOF'
127.0.0.1   localhost
127.0.1.1   kali
::1         localhost ip6-localhost ip6-loopback
EOF

  # hostname
  echo "kali-tablet" > "$KALI_INSTALL_DIR/etc/hostname"

  # profile additions for convenience
  cat >> "$KALI_INSTALL_DIR/root/.bashrc" <<'EOF'

# Kali tablet setup
export TERM=xterm-256color
export LANG=en_US.UTF-8
alias ll='ls -la'
alias cls='clear'
# Start services if available
[ -f /etc/init.d/ssh ] && service ssh start 2>/dev/null || true
EOF

  success "Kali rootfs configured"
}

# ---- Launch script ----------------------------------------------------------

create_launch_script_proot() {
  info "Creating proot launch script at $KALI_LAUNCH_SCRIPT ..."
  cat > "$KALI_LAUNCH_SCRIPT" <<SCRIPT
#!/usr/bin/env bash
# Launch Kali Linux proot environment

KALI_DIR="${KALI_INSTALL_DIR}"

# Bind mounts
BINDS=(
  "-b" "/proc"
  "-b" "/sys"
  "-b" "/dev"
  "-b" "/dev/pts"
  "-b" "/sdcard"
)

# If a command was passed, execute it; otherwise start a shell
CMD=("\${@:-/bin/bash --login}")

exec proot \\
  --link2symlink \\
  -0 \\
  -r "\${KALI_DIR}" \\
  "\${BINDS[@]}" \\
  -w /root \\
  /usr/bin/env -i \\
    HOME=/root \\
    PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin \\
    TERM="\${TERM:-xterm-256color}" \\
    LANG=C.UTF-8 \\
    "\${CMD[@]}"
SCRIPT
  chmod +x "$KALI_LAUNCH_SCRIPT"
  success "Launch script created: run 'kali' in Termux to enter Kali"
}

create_launch_script_root() {
  info "Creating native chroot launch script at $KALI_LAUNCH_SCRIPT ..."
  cat > "$KALI_LAUNCH_SCRIPT" <<SCRIPT
#!/usr/bin/env bash
# Launch Kali Linux native chroot (requires root)

KALI_DIR="${KALI_INSTALL_DIR}"

# Mount required filesystems
su -c "
  mount -o bind /proc  \${KALI_DIR}/proc   2>/dev/null || true
  mount -o bind /sys   \${KALI_DIR}/sys    2>/dev/null || true
  mount -o bind /dev   \${KALI_DIR}/dev    2>/dev/null || true
  mount -o bind /dev/pts \${KALI_DIR}/dev/pts 2>/dev/null || true
  mount -o bind /sdcard \${KALI_DIR}/sdcard 2>/dev/null || true
  chroot \${KALI_DIR} /usr/bin/env -i \\
    HOME=/root \\
    PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin \\
    TERM=\${TERM:-xterm-256color} \\
    LANG=C.UTF-8 \\
    \${@:-/bin/bash --login}
"
SCRIPT
  chmod +x "$KALI_LAUNCH_SCRIPT"
  success "Root chroot launch script created: run 'kali' in Termux (with root)"
}

# ---- Optional: Kali security tools -----------------------------------------

install_kali_tools() {
  info "Installing Kali security tools (this may take 10-30 minutes)..."

  local tool_script="${KALI_INSTALL_DIR}/tmp/install-tools.sh"
  cat > "$tool_script" <<'INNER'
#!/bin/bash
export DEBIAN_FRONTEND=noninteractive
apt-get update -qq

# Core tools
apt-get install -y --no-install-recommends \
  kali-tools-top10 \
  nmap \
  tcpdump \
  wireshark-common \
  tshark \
  netcat-openbsd \
  socat \
  curl \
  wget \
  git \
  python3 \
  python3-pip \
  openssh-server \
  tmux \
  vim

# Clean up
apt-get clean
rm -rf /var/lib/apt/lists/*
INNER
  chmod +x "$tool_script"

  if $USE_ROOT; then
    su -c "chroot ${KALI_INSTALL_DIR} /bin/bash /tmp/install-tools.sh"
  else
    proot --link2symlink -0 -r "$KALI_INSTALL_DIR" \
      -b /proc -b /dev -b /sys \
      /bin/bash /tmp/install-tools.sh
  fi

  rm -f "$tool_script"
  success "Kali tools installed"
}

# ---- Optional: VNC server ---------------------------------------------------

configure_vnc() {
  info "Configuring VNC server inside Kali..."

  local vnc_setup="${KALI_INSTALL_DIR}/tmp/vnc-setup.sh"
  cat > "$vnc_setup" <<'INNER'
#!/bin/bash
export DEBIAN_FRONTEND=noninteractive
apt-get update -qq
apt-get install -y tigervnc-standalone-server xfce4 xfce4-terminal dbus-x11
mkdir -p /root/.vnc
# Default VNC password: "kali1234" — change with 'vncpasswd' inside kali
echo "kali1234" | vncpasswd -f > /root/.vnc/passwd
chmod 600 /root/.vnc/passwd
cat > /root/.vnc/xstartup <<'EOF'
#!/bin/bash
export DISPLAY=:1
xrdb $HOME/.Xresources 2>/dev/null || true
startxfce4 &
EOF
chmod +x /root/.vnc/xstartup
echo "VNC configured. Run 'vncserver :1 -geometry 1280x800 -depth 24' inside kali."
INNER
  chmod +x "$vnc_setup"

  if $USE_ROOT; then
    su -c "chroot ${KALI_INSTALL_DIR} /bin/bash /tmp/vnc-setup.sh"
  else
    proot --link2symlink -0 -r "$KALI_INSTALL_DIR" \
      -b /proc -b /dev -b /sys \
      /bin/bash /tmp/vnc-setup.sh
  fi

  rm -f "$vnc_setup"

  # Add VNC start shortcut to Termux
  cat >> "$KALI_LAUNCH_SCRIPT" <<'SHORTCUT'

# Run with --vnc to start VNC server
if [ "${1:-}" = "--vnc" ]; then
  kali vncserver :1 -geometry 1280x800 -depth 24 -localhost no
  echo "VNC running on $(hostname -I | awk '{print $1}'):5901"
  echo "Default password: kali1234  (change with 'kali vncpasswd')"
fi
SHORTCUT
  success "VNC configured. Run 'kali --vnc' to start graphical desktop"
}

# ---- Main -------------------------------------------------------------------

main() {
  echo ""
  echo -e "${BLUE}============================================${NC}"
  echo -e "${BLUE}  Kali Linux NetHunter Setup               ${NC}"
  echo -e "${BLUE}  Pritom Tab10 Max M10-R02 / Android 14    ${NC}"
  echo -e "${BLUE}============================================${NC}"
  echo ""

  check_termux
  check_storage
  check_root

  install_termux_deps

  if [ -d "$KALI_INSTALL_DIR/usr" ]; then
    warn "Kali rootfs already exists at $KALI_INSTALL_DIR"
    read -rp "Re-download and overwrite? [y/N] " confirm
    if [[ "$confirm" =~ ^[Yy]$ ]]; then
      rm -rf "$KALI_INSTALL_DIR"
    else
      info "Using existing rootfs"
    fi
  fi

  if [ ! -d "$KALI_INSTALL_DIR/usr" ]; then
    download_kali_rootfs
  fi

  configure_kali_rootfs

  if $USE_ROOT; then
    create_launch_script_root
  else
    create_launch_script_proot
  fi

  if $INSTALL_TOOLS; then
    install_kali_tools
  fi

  if $INSTALL_VNC; then
    configure_vnc
  fi

  echo ""
  echo -e "${GREEN}============================================${NC}"
  echo -e "${GREEN}  Setup complete!                          ${NC}"
  echo -e "${GREEN}============================================${NC}"
  echo ""
  echo -e "  Enter Kali:        ${YELLOW}kali${NC}"
  echo -e "  Install tools:     ${YELLOW}kali apt-get install kali-tools-top10${NC}"
  if $INSTALL_VNC; then
  echo -e "  Start desktop:     ${YELLOW}kali --vnc${NC}"
  fi
  echo -e "  Start SSH:         ${YELLOW}kali service ssh start${NC}"
  echo ""
  echo -e "  ${YELLOW}Legal:${NC} Use security tools only on systems you are authorized to test."
  echo ""
}

main "$@"
