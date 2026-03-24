#!/data/data/com.termux/files/usr/bin/bash
# =============================================================================
# kali-boot.sh — Termux:Boot script for auto-starting Kali services
# =============================================================================
#
# INSTALL:
#   1. Install Termux:Boot from F-Droid (NOT Google Play)
#   2. Open the Termux:Boot app once to activate it as a boot receiver
#   3. Copy this script into ~/.termux/boot/ :
#
#        mkdir -p ~/.termux/boot
#        cp kali-boot.sh ~/.termux/boot/
#        chmod +x ~/.termux/boot/kali-boot.sh
#
#   4. Reboot the tablet — this script runs automatically after boot
#
# REQUIREMENTS:
#   - Termux from F-Droid (v0.118+)
#   - Kali chroot set up via nethunter-setup.sh (creates the 'kali' command)
#   - termux-api package for wake-lock: pkg install termux-api
#
# CUSTOMIZATION:
#   Edit the "User configuration" section below to enable/disable services.
# =============================================================================

# ---- User configuration -----------------------------------------------------

# Keep the CPU awake so services are not killed by Android's battery saver.
# Requires: pkg install termux-api
ENABLE_WAKE_LOCK=true

# Seconds to wait after boot before starting services.
# Android's networking stack needs time to initialize.
BOOT_DELAY=15

# Start the Kali SSH server on boot (recommended).
# Connect over USB tethering or WiFi: ssh -p 2222 root@<tablet-ip>
#
# SECURITY WARNING: SSH starts with PasswordAuthentication=yes and
# PermitRootLogin=yes. Before exposing the tablet to any network, set
# a strong root password inside Kali:
#   kali passwd root
#
# RECOMMENDED: Switch to key-based authentication to disable passwords.
# Inside Kali, add your public key once, then disable password auth:
#   mkdir -p /root/.ssh && chmod 700 /root/.ssh
#   echo "ssh-ed25519 AAAA... yourkey" >> /root/.ssh/authorized_keys
#   chmod 600 /root/.ssh/authorized_keys
# Then change the sshd line below to add: -o "PasswordAuthentication no"
START_SSH=true
SSH_PORT=2222

# Start a VNC server on boot for graphical desktop access.
# Requires: nethunter-setup.sh --vnc
# Connect with any VNC client to <tablet-ip>:5901, password set via 'vncpasswd'
START_VNC=false
VNC_GEOMETRY="1280x800"
VNC_DEPTH=24
VNC_DISPLAY=":1"

# Log file for boot-time output (useful for debugging startup issues).
LOGFILE="${HOME}/.kali-boot.log"

# ---- Boot sequence ----------------------------------------------------------

exec >> "$LOGFILE" 2>&1
echo ""
echo "=== Kali boot script started: $(date) ==="

if $ENABLE_WAKE_LOCK; then
  if command -v termux-wake-lock &>/dev/null; then
    termux-wake-lock
    echo "[OK] Wake lock acquired"
  else
    echo "[WW] termux-wake-lock not found — install: pkg install termux-api"
  fi
fi

echo "[*] Waiting ${BOOT_DELAY}s for Android to initialize networking..."
sleep "$BOOT_DELAY"

# Verify the 'kali' launcher exists before attempting to start services
if ! command -v kali &>/dev/null; then
  echo "[!!] 'kali' command not found — run nethunter-setup.sh first"
  exit 1
fi

if $START_SSH; then
  echo "[*] Starting Kali SSH server on port ${SSH_PORT}..."
  kali /usr/sbin/sshd -p "${SSH_PORT}" \
    -o "PermitRootLogin yes" \
    -o "PasswordAuthentication yes" \
    -o "PrintLastLog no" && \
    echo "[OK] SSH started" || \
    echo "[!!] SSH failed to start"
fi

if $START_VNC; then
  echo "[*] Starting Kali VNC server ${VNC_DISPLAY} (${VNC_GEOMETRY})..."
  kali vncserver "${VNC_DISPLAY}" \
    -geometry "${VNC_GEOMETRY}" \
    -depth "${VNC_DEPTH}" \
    -localhost no && \
    echo "[OK] VNC started on display ${VNC_DISPLAY}" || \
    echo "[!!] VNC failed to start"
fi

# Print current IP addresses for reference
echo "[*] Network addresses:"
ip -4 addr show 2>/dev/null | grep "inet " | awk '{print "    " $2 "  (" $NF ")"}'

echo "=== Boot sequence complete: $(date) ==="
