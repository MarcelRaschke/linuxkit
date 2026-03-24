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
#   --root          Use native chroot (requires root / Magisk)
#   --wifi-monitor  Configure WiFi monitor mode (only with --root, needs compatible adapter)
#   --tools         Install Kali security tools after setup (needs network)
#   --vnc           Install VNC server for graphical desktop access
#   --help          Show this help
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
SETUP_WIFI_MONITOR=false
KALI_STOP_SCRIPT="${PREFIX}/bin/kali-stop"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# ---- Argument parsing -------------------------------------------------------

for arg in "$@"; do
  case "$arg" in
    --root)          USE_ROOT=true ;;
    --wifi-monitor)  SETUP_WIFI_MONITOR=true ;;
    --tools)         INSTALL_TOOLS=true ;;
    --vnc)           INSTALL_VNC=true ;;
    --minimal)       INSTALL_MINIMAL=true ;;
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
      error "'su' not found — Magisk is not installed or not active.
  Install Magisk: https://github.com/topjohnwu/Magisk/releases
  Then open Termux, run 'su' to trigger the grant popup, and tap Grant.
  Re-run this script once root is confirmed: bash nethunter-setup.sh --root"
    fi
    if ! su -c "id" &>/dev/null 2>&1; then
      error "Root access denied. To fix:
  1. Open the Magisk app
  2. Tap the Superuser tab (shield icon)
  3. Find Termux in the list and set it to Allow
     -- OR -- open Termux, run 'su', and tap Grant in the popup
  4. Verify with: su -c \"id\"  (should print uid=0)
  5. Re-run: bash nethunter-setup.sh --root"
    fi
    success "Root access confirmed ($(su -c "id" 2>/dev/null | cut -d' ' -f1))"
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

  # Ensure mount point directories exist inside the rootfs
  for mp in proc sys dev dev/pts sdcard; do
    mkdir -p "${KALI_INSTALL_DIR}/${mp}"
  done

  cat > "$KALI_LAUNCH_SCRIPT" <<SCRIPT
#!/usr/bin/env bash
# Launch Kali Linux native chroot (requires Magisk root)
#
# Usage:
#   kali                     — interactive shell
#   kali <cmd> [args...]     — run command and exit
#   kali --stop              — unmount filesystems without entering chroot
#
# The script auto-unmounts on exit via a trap.

KALI_DIR="${KALI_INSTALL_DIR}"

# --- mount helper -----------------------------------------------------------

kali_mount() {
  su -c "
    mkdir -p \${KALI_DIR}/{proc,sys,dev,dev/pts,sdcard,run}
    mountpoint -q \${KALI_DIR}/proc    || mount -t proc  proc  \${KALI_DIR}/proc
    mountpoint -q \${KALI_DIR}/sys     || mount -t sysfs sys   \${KALI_DIR}/sys
    mountpoint -q \${KALI_DIR}/dev     || mount -o bind  /dev  \${KALI_DIR}/dev
    mountpoint -q \${KALI_DIR}/dev/pts || mount -o bind  /dev/pts \${KALI_DIR}/dev/pts
    mountpoint -q \${KALI_DIR}/sdcard  || mount -o bind  /sdcard  \${KALI_DIR}/sdcard
  " 2>/dev/null
}

# --- unmount helper (best-effort, lazy fallback) ----------------------------

kali_umount() {
  su -c "
    for mp in sdcard dev/pts dev sys proc run; do
      mountpoint -q \${KALI_DIR}/\${mp} && \
        umount -l \${KALI_DIR}/\${mp} 2>/dev/null || true
    done
  " 2>/dev/null
}

# --- stop-only mode ---------------------------------------------------------

if [ "\${1:-}" = "--stop" ]; then
  echo "Unmounting Kali chroot filesystems..."
  kali_umount && echo "Done." || echo "Nothing mounted or unmount failed."
  exit 0
fi

# --- mount and enter --------------------------------------------------------

kali_mount || { echo "Mount failed — is Magisk root active?"; exit 1; }

# Trap ensures cleanup even on Ctrl-C or unexpected exit
trap kali_umount EXIT INT TERM

CMD=("\${@:-/bin/bash --login}")

su -c "chroot \${KALI_DIR} /usr/bin/env -i \\
  HOME=/root \\
  PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin \\
  TERM=\${TERM:-xterm-256color} \\
  LANG=C.UTF-8 \\
  \${CMD[*]}"
SCRIPT
  chmod +x "$KALI_LAUNCH_SCRIPT"

  # kali-stop shortcut
  cat > "$KALI_STOP_SCRIPT" <<STOP
#!/usr/bin/env bash
exec "${KALI_LAUNCH_SCRIPT}" --stop
STOP
  chmod +x "$KALI_STOP_SCRIPT"

  success "Root chroot scripts created:"
  success "  kali       — enter Kali (auto-mounts, auto-unmounts on exit)"
  success "  kali-stop  — force unmount all Kali filesystems"
}

# ---- WiFi monitor mode (root only) -----------------------------------------

setup_wifi_monitor() {
  if ! $USE_ROOT; then
    warn "--wifi-monitor requires --root (skipping)"
    return
  fi
  info "Configuring WiFi monitor mode support..."

  # Check for iw on the Android side
  if ! su -c "which iw" &>/dev/null 2>&1; then
    info "Installing iw in Termux (needed outside chroot for nl80211 control)..."
    pkg install -y iw 2>/dev/null || \
      warn "Could not install iw in Termux — install manually: pkg install iw"
  fi

  # Install aircrack-ng and iw inside Kali
  local wifi_script="${KALI_INSTALL_DIR}/tmp/wifi-monitor-setup.sh"
  cat > "$wifi_script" <<'INNER'
#!/bin/bash
export DEBIAN_FRONTEND=noninteractive
apt-get update -qq
apt-get install -y aircrack-ng iw wireless-tools rfkill
# Confirm iw is available
iw --version && echo "iw installed OK"
INNER
  chmod +x "$wifi_script"
  su -c "chroot ${KALI_INSTALL_DIR} /bin/bash /tmp/wifi-monitor-setup.sh"
  rm -f "$wifi_script"

  # Append a wmon helper inside the chroot launch script
  cat >> "$KALI_LAUNCH_SCRIPT" <<'SHORTCUT'

# ---------------------------------------------------------------------------
# WiFi monitor mode helpers (run inside Kali with: kali wmon <iface>)
# These require root on the Android kernel. Adjust interface name as needed.
# Common names on Mediatek: wlan0, wlan1  |  check with: ip link
#
# Enable:  kali wmon wlan0
# Disable: kali wmon-off wlan0
# List:    kali wmon-list
# ---------------------------------------------------------------------------
SHORTCUT

  # Create wmon helper scripts inside the rootfs
  cat > "${KALI_INSTALL_DIR}/usr/local/bin/wmon" <<'WMON'
#!/bin/bash
# Enable monitor mode on a WiFi interface
# Usage: wmon <interface>  [channel]
IFACE="${1:?Usage: wmon <interface> [channel]}"
CHAN="${2:-}"
ip link set "$IFACE" down
iw dev "$IFACE" set type monitor
ip link set "$IFACE" up
[ -n "$CHAN" ] && iw dev "$IFACE" set channel "$CHAN"
echo "Monitor mode enabled on $IFACE"
iw dev "$IFACE" info
WMON
  chmod +x "${KALI_INSTALL_DIR}/usr/local/bin/wmon"

  cat > "${KALI_INSTALL_DIR}/usr/local/bin/wmon-off" <<'WMON_OFF'
#!/bin/bash
# Disable monitor mode, restore managed mode
# Usage: wmon-off <interface>
IFACE="${1:?Usage: wmon-off <interface>}"
ip link set "$IFACE" down
iw dev "$IFACE" set type managed
ip link set "$IFACE" up
echo "Managed mode restored on $IFACE"
WMON_OFF
  chmod +x "${KALI_INSTALL_DIR}/usr/local/bin/wmon-off"

  cat > "${KALI_INSTALL_DIR}/usr/local/bin/wmon-list" <<'WMON_LIST'
#!/bin/bash
# List wireless interfaces and their current modes
iw dev 2>/dev/null || ip link show
WMON_LIST
  chmod +x "${KALI_INSTALL_DIR}/usr/local/bin/wmon-list"

  success "WiFi monitor mode configured."
  success "  Inside Kali: wmon wlan0 [channel]   — enable monitor mode"
  success "              wmon-off wlan0           — restore managed mode"
  success "              wmon-list                — list interfaces"
  warn "Note: Monitor mode requires a WiFi chip that supports nl80211 monitor"
  warn "      The Pritom Tab10's built-in RTL8188EU / Mediatek chip may not"
  warn "      support monitor mode — an external USB WiFi adapter is recommended."
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

  if $SETUP_WIFI_MONITOR; then
    setup_wifi_monitor
  fi

  echo ""
  echo -e "${GREEN}============================================${NC}"
  echo -e "${GREEN}  Setup complete!                          ${NC}"
  echo -e "${GREEN}============================================${NC}"
  echo ""
  echo -e "  Enter Kali:        ${YELLOW}kali${NC}"
  if $USE_ROOT; then
  echo -e "  Unmount (cleanup): ${YELLOW}kali-stop${NC}"
  fi
  echo -e "  Install tools:     ${YELLOW}kali apt-get install kali-tools-top10${NC}"
  if $INSTALL_VNC; then
  echo -e "  Start desktop:     ${YELLOW}kali --vnc${NC}"
  fi
  echo -e "  Start SSH:         ${YELLOW}kali service ssh start${NC}"
  if $SETUP_WIFI_MONITOR; then
  echo -e "  Monitor mode:      ${YELLOW}kali wmon wlan1 6${NC}  (inside Kali)"
  echo -e "  Restore managed:   ${YELLOW}kali wmon-off wlan1${NC}"
  fi
  echo ""
  echo -e "  ${BLUE}Auto-start on boot:${NC} Install Termux:Boot from F-Droid, then:"
  echo -e "    mkdir -p ~/.termux/boot"
  # shellcheck disable=SC2028
  echo -e "    echo 'kali service ssh start' > ~/.termux/boot/kali-boot.sh"
  echo -e "    chmod +x ~/.termux/boot/kali-boot.sh"
  echo ""
  echo -e "  ${YELLOW}Legal:${NC} Use security tools only on systems you are authorized to test."
  echo ""
}

main "$@"
