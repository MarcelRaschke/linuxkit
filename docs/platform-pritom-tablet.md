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
This does **not** use LinuxKit but achieves similar results with less effort.

See [Kali NetHunter documentation](https://www.kali.org/docs/nethunter/) for
this approach.

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
