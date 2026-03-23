# LinuxKit on Pritom Tab10 Max M10-R02 (Android 14, ARM64)

This document describes how to build and boot LinuxKit with Kali Linux security
tools on the Pritom Tab10 Max M10-R02 tablet running Android 14.

## Hardware Overview

| Component   | Details                                  |
|-------------|------------------------------------------|
| Display     | 10.1" IPS, 1280×800                      |
| CPU         | ARM64 (SoC vendor varies by batch)       |
| RAM         | 4 GB                                     |
| Storage     | 64 GB eMMC                               |
| OS          | Android 14 (stock)                       |
| Connectivity| WiFi 802.11 b/g/n, Bluetooth 5.0, USB-C |

> **Note:** The M10-R02 revision may use different SoCs across production
> batches (AllWinner, MediaTek, or Rockchip). Identify your exact chip with
> `adb shell getprop ro.board.platform` before building a custom kernel.


## Approach Options

There are two practical ways to run LinuxKit with Kali tools on this tablet:

### Option A: Native Boot (Full Linux, recommended for advanced users)

Boot LinuxKit directly as the operating system after unlocking the bootloader.
This requires complete replacement of Android and full hardware driver support.

**Pros:** Full hardware access, best performance
**Cons:** Requires unlocked bootloader, loses Android, complex kernel setup

### Option B: Kali NetHunter Chroot (easier, Android preserved)

Run Kali Linux inside Android via a chroot/proot environment using Termux.
This does **not** use LinuxKit but achieves similar results with less effort
and preserves your Android installation.

**Pros:** No bootloader unlock needed, Android continues to work, faster setup
**Cons:** Slightly reduced performance vs native, some kernel features restricted

See [`contrib/android-kali/`](../contrib/android-kali/) for automated setup scripts.

---

## Option B: Kali NetHunter Chroot (Termux + proot)

### Prerequisites

- **Termux** from [F-Droid](https://f-droid.org/en/packages/com.termux/)
  (the Google Play version is outdated and unsupported)
- At least **4 GB** free internal storage (2 GB for minimal install)
- Internet connection during initial setup
- Optional: **Magisk** (root) for native chroot with full hardware access

### Quick Setup

Open Termux and run the automated setup script:

```bash
curl -fsSL \
  https://raw.githubusercontent.com/marcelraschke/linuxkit/main/contrib/android-kali/nethunter-setup.sh \
  | bash
```

Or copy the script from this repository and run locally:

```bash
bash contrib/android-kali/nethunter-setup.sh
```

Available options:

```
--minimal   Download minimal rootfs (~200MB) instead of full (~1.5GB)
--tools     Install kali-tools-top10 automatically
--vnc       Set up VNC server + XFCE4 graphical desktop
--root      Use native chroot (requires Magisk root)
```

### Manual Setup

If you prefer to set up manually:

**Step 1: Install Termux dependencies**

```bash
pkg update && pkg install -y proot curl tar
```

**Step 2: Download the Kali ARM64 rootfs**

```bash
# Full install (~1.5GB)
wget -O ~/kali-rootfs.tar.xz \
  https://kali.download/nethunter-images/current/rootfs/kalifs-arm64-full.tar.xz

# Minimal install (~200MB)
wget -O ~/kali-rootfs.tar.xz \
  https://kali.download/nethunter-images/current/rootfs/kalifs-arm64-minimal.tar.xz
```

**Step 3: Extract the rootfs**

```bash
mkdir -p ~/kali-arm64
proot --link2symlink tar -xJf ~/kali-rootfs.tar.xz \
  -C ~/kali-arm64 --exclude='dev'
rm ~/kali-rootfs.tar.xz
```

**Step 4: Configure DNS and hostname**

```bash
echo -e "nameserver 8.8.8.8\nnameserver 1.1.1.1" > ~/kali-arm64/etc/resolv.conf
echo "kali-tablet" > ~/kali-arm64/etc/hostname
```

**Step 5: Create a launch script**

```bash
cat > $PREFIX/bin/kali <<'EOF'
#!/usr/bin/env bash
exec proot --link2symlink -0 \
  -r ~/kali-arm64 \
  -b /proc -b /sys -b /dev -b /dev/pts \
  -b /sdcard \
  -w /root \
  /usr/bin/env -i \
    HOME=/root \
    PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin \
    TERM="${TERM:-xterm-256color}" \
    LANG=C.UTF-8 \
    "${@:-/bin/bash --login}"
EOF
chmod +x $PREFIX/bin/kali
```

**Step 6: Enter Kali**

```bash
kali
```

### Installing Security Tools

Inside the Kali proot environment:

```bash
# Update package lists
apt-get update

# Top 10 Kali tools (recommended starting point)
apt-get install -y kali-tools-top10

# Wireless security assessment tools
apt-get install -y kali-tools-wireless

# Web application testing
apt-get install -y kali-tools-web

# Individual tools
apt-get install -y nmap tcpdump wireshark-cli netcat-openbsd \
  metasploit-framework burpsuite sqlmap john hydra nikto \
  aircrack-ng hashcat responder impacket-scripts
```

### SSH Access

Enable SSH inside the Kali environment for remote access over USB tethering:

```bash
# Inside Kali
apt-get install -y openssh-server
# Set a password for the root account
passwd root
# Start SSH (proot uses non-standard port by default)
/usr/sbin/sshd -p 2222 -o "PermitRootLogin yes" -o "PasswordAuthentication yes"
```

Connect from your computer:

```bash
# Enable USB tethering on the tablet first (Android Settings → Network)
ssh -p 2222 root@<tablet-usb-ip>
```

### Graphical Desktop via VNC

Install a lightweight desktop environment for graphical tools:

```bash
# Inside Kali
apt-get install -y tigervnc-standalone-server xfce4 xfce4-terminal dbus-x11

# Set VNC password
vncpasswd

# Start VNC server (tablet display is 1280×800)
vncserver :1 -geometry 1280x800 -depth 24 -localhost no
```

Connect with a VNC client (e.g. RealVNC Viewer, TigerVNC) to `<tablet-ip>:5901`.

To stop the VNC server:

```bash
vncserver -kill :1
```

### Limitations of proot Mode

Running without root (proot mode) has some restrictions:

- **Raw sockets** limited — some network scanners need root privileges
- **Kernel modules** cannot be loaded — e.g. no `monitor mode` for WiFi
- **Device access** restricted — cannot directly open `/dev/rfkill`, USB raw devices
- **iptables/nftables** require root on the Android kernel

For full capabilities (including WiFi monitor mode and raw socket operations),
use the `--root` flag with Magisk-rooted Android, or use
[Option A](#option-a-native-linuxkit-boot) for native Linux boot.

---

## Option A: Native LinuxKit Boot

### Prerequisites

- **Unlocked bootloader** — Required. The process varies by firmware version.
  Check the Pritom support forum or XDA Developers for your specific firmware.
- **ADB and fastboot** installed on your development machine
- **Docker** with `buildx` and `--platform linux/arm64` support
- **LinuxKit CLI** installed (`go install github.com/linuxkit/linuxkit/src/cmd/linuxkit@latest`)

### Step 1: Identify Your SoC

```bash
adb shell getprop ro.board.platform
adb shell cat /proc/cpuinfo | grep Hardware
```

Common results and their kernel configs:

| `ro.board.platform` | SoC Family   | Kernel Config Needed          |
|---------------------|--------------|-------------------------------|
| `rk3566` / `rk3568` | Rockchip     | `CONFIG_ARCH_ROCKCHIP=y`      |
| `mt8183` / `mt8168` | MediaTek     | `CONFIG_ARCH_MEDIATEK=y`      |
| `sun50i*`           | AllWinner    | `CONFIG_ARCH_SUNXI=y`         |

### Step 2: Build a Custom ARM64 Kernel

The default `linuxkit/kernel:6.12.59` is a generic ARM64 server kernel.
For the tablet you need to enable device-specific drivers.

Clone the LinuxKit kernel config and modify:

```bash
cp kernel/6.12.x/config-aarch64 kernel/6.12.x/config-aarch64-tablet
```

Add or change these options in `config-aarch64-tablet`:

```
# Platform SoC (choose one based on your hardware)
CONFIG_ARCH_ROCKCHIP=y      # for Rockchip RK35xx
# CONFIG_ARCH_MEDIATEK=y    # for MediaTek MT8xxx
# CONFIG_ARCH_SUNXI=y       # for AllWinner

# Touchscreen support
CONFIG_INPUT_TOUCHSCREEN=y
CONFIG_TOUCHSCREEN_GOODIX=m   # Goodix GT911 (common on budget tablets)
CONFIG_TOUCHSCREEN_ELAN=m     # ELAN touchscreens

# Display / DRM (for graphical output beyond framebuffer)
CONFIG_DRM=y
CONFIG_DRM_PANFROST=m         # ARM Mali GPU driver (open source)

# eMMC storage (MediaTek)
CONFIG_MMC_MTK=m
# eMMC storage (Rockchip)
CONFIG_MMC_DW=m
CONFIG_MMC_DW_ROCKCHIP=m

# WiFi (common embedded chipsets)
CONFIG_WLAN_VENDOR_MEDIATEK=y
CONFIG_MT7921E=m              # MediaTek WiFi
CONFIG_WLAN_VENDOR_REALTEK=y
CONFIG_RTW88=m                # Realtek WiFi (alternative)

# USB OTG / USB-C
CONFIG_USB_DWC3=m
CONFIG_USB_DWC3_OF_SIMPLE=m
CONFIG_USB_ROLES_INTEL_XHCI=m
```

Build the custom kernel (requires Docker with arm64 support):

```bash
cd kernel
make ARCH=aarch64 build_tag=6.12.x CONFIG=config-aarch64-tablet
```

### Step 3: Build the LinuxKit Image

```bash
linuxkit build \
  -arch arm64 \
  -format raw-efi \
  examples/kali-pritom-tablet.yml
```

This produces `kali-pritom-tablet-efi.img`.

### Step 4: Pre-build a Kali Tools Image (optional, for offline use)

The default configuration pulls `kalilinux/kali-rolling:arm64` at boot time,
which requires internet access. For offline use, build a custom image:

```dockerfile
# Dockerfile.kali-tablet
FROM kalilinux/kali-rolling:arm64
RUN apt-get update && apt-get install -y \
    kali-tools-top10 \
    kali-tools-wireless \
    kali-tools-web \
    nmap \
    tcpdump \
    wireshark-cli \
    netcat-openbsd \
    && rm -rf /var/lib/apt/lists/*
ENTRYPOINT ["/bin/bash", "-l"]
```

```bash
docker buildx build \
  --platform linux/arm64 \
  -t my-kali-tablet:latest \
  -f Dockerfile.kali-tablet \
  --load .
```

Then update `kali-pritom-tablet.yml` to use `my-kali-tablet:latest` instead of
`kalilinux/kali-rolling:arm64`.

### Step 5: Flash and Boot

#### Via fastboot (if bootloader supports standard fastboot):

```bash
fastboot boot kali-pritom-tablet-efi.img
```

#### Via USB booting / SD card:

Some tablets support booting from a USB drive or SD card. Write the EFI image:

```bash
# Write to a USB drive or SD card (replace /dev/sdX)
dd if=kali-pritom-tablet-efi.img of=/dev/sdX bs=4M status=progress
```

Then hold Volume Down during boot to select the USB/SD boot option.

---

## Networking

### USB Tethering (recommended)

Connect the tablet to your computer via USB-C and enable USB tethering in
Android settings (before rebooting into LinuxKit). The DHCP client in the
LinuxKit config will acquire an IP address automatically.

### USB-to-Ethernet Adapter

Attach a USB-C to Ethernet adapter. The kernel's `r8152` or `ax88179` driver
covers most USB Ethernet adapters. Add a `modprobe` to the `onboot` section:

```yaml
onboot:
  - name: usb-ethernet
    image: linuxkit/modprobe:4248cdc3494779010e7e7488fc17b6fd45b73aeb
    command: ["modprobe", "r8152"]
```

### WiFi

WiFi requires a custom kernel with the correct driver for your tablet's WiFi
chip. Identify the chip:

```bash
adb shell lsmod | grep -i wifi
adb shell ls /sys/bus/sdio/devices/
```

---

## Console Access

LinuxKit boots with a framebuffer text console on the tablet display (`tty0`).
Use a USB OTG adapter with a USB keyboard for interactive access.

SSH access is also available once networking is configured. Add your SSH
public key to `etc/ssh/authorized_keys` in the YAML `files` section.

---

## Limitations

The default `linuxkit/kernel:6.12.59` does **not** support:

- **Touchscreen** — `CONFIG_INPUT_TOUCHSCREEN` is disabled; requires custom kernel
- **WiFi** — Most embedded WiFi chips need vendor-specific drivers
- **GPU / DRM** — `CONFIG_DRM` is disabled; text console via framebuffer only
- **Bluetooth** — Not compiled in for generic ARM64 server kernel
- **Suspend/Resume** — Power management for mobile SoCs is not configured

These limitations can be resolved by building a custom kernel as described in
[Step 2](#step-2-build-a-custom-arm64-kernel) above. The LinuxKit kernel build
infrastructure makes this straightforward — see [`kernels.md`](./kernels.md)
for details.

---

## Kali Security Tools in the Container

Once booted, access the Kali environment:

```bash
# From the getty terminal on the tablet display
ctr run --rm --tty kalilinux/kali-rolling:arm64 kali /bin/bash

# Or connect via SSH and exec into the running container
ssh root@<tablet-ip>
ctr task exec --exec-id kali kali-tools /bin/bash
```

Common Kali tools available in `kali-tools-top10`:

| Tool         | Purpose                        |
|--------------|--------------------------------|
| `nmap`       | Network discovery and scanning |
| `metasploit` | Penetration testing framework  |
| `burpsuite`  | Web application proxy          |
| `sqlmap`     | SQL injection testing          |
| `john`       | Password cracking              |
| `wireshark`  | Network packet analysis        |
| `aircrack-ng`| WiFi security assessment       |
| `netcat`     | Network utility                |
| `hydra`      | Login brute-force testing      |
| `nikto`      | Web server scanner             |

> **Legal notice:** Only use security testing tools on networks and systems
> for which you have explicit written authorization.

---

## See Also

- [`kernels.md`](./kernels.md) — Building and customizing LinuxKit kernels
- [`platform-rpi3.md`](./platform-rpi3.md) — Similar setup for Raspberry Pi 3b (ARM64)
- [`../examples/kali-pritom-tablet.yml`](../examples/kali-pritom-tablet.yml) — Example YAML configuration
