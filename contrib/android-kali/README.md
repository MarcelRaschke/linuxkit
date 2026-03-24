# Kali Linux on Android (NetHunter Chroot)

Scripts for setting up a Kali Linux environment on ARM64 Android tablets
(e.g. Pritom Tab10 Max M10-R02, Android 14) using Termux + proot/chroot.

This is **Option B** from [`docs/platform-pritom-tablet.md`](../../docs/platform-pritom-tablet.md)
and does **not** require an unlocked bootloader. Android continues to run normally.

## Quick Start

1. Install **Termux** from [F-Droid](https://f-droid.org/en/packages/com.termux/)
   (not from Google Play)

2. Open Termux and run:
   ```bash
   curl -fsSL https://raw.githubusercontent.com/marcelraschke/linuxkit/main/contrib/android-kali/nethunter-setup.sh | bash
   ```

3. Enter the Kali environment:
   ```bash
   kali
   ```

## Options

| Flag         | Description                                          |
|--------------|------------------------------------------------------|
| `--minimal`  | Download minimal rootfs (~200MB) instead of full     |
| `--tools`    | Install `kali-tools-top10` during setup              |
| `--vnc`      | Configure VNC server for graphical desktop (XFCE4)  |
| `--root`     | Use native chroot instead of proot (requires Magisk) |

Example — minimal install with security tools:
```bash
bash nethunter-setup.sh --minimal --tools
```

Example — full install with graphical desktop:
```bash
bash nethunter-setup.sh --vnc
```

## Directory Structure

```
contrib/android-kali/
├── README.md               # This file
└── nethunter-setup.sh      # Automated setup script
```

## Root Mode (Magisk)

`--root` uses a native chroot with full kernel access (raw sockets, WiFi monitor
mode, iptables). It requires [Magisk](https://github.com/topjohnwu/Magisk/releases)
and a Termux root grant.

**Before running `--root`, grant Termux root access:**

1. Open **Magisk** → tap the **Superuser** tab (shield icon)
2. In Termux, run `su` — a Magisk popup appears → tap **Grant**
3. Check **Remember choice** to avoid repeated prompts
4. Verify: `su -c "id"` → should print `uid=0(root) ...`

Then run the setup:

```bash
bash nethunter-setup.sh --root --tools
```

If `su -c "id"` fails after granting, try `pkg install tsu` and grant `tsu`
in the Superuser tab as well. See
[Root Mode with Magisk](../../docs/platform-pritom-tablet.md#root-mode-with-magisk)
for full Magisk installation steps and a troubleshooting table.

## Requirements

- Termux from F-Droid (v0.118+)
- 4 GB free storage (2 GB for `--minimal`)
- Internet connection for initial download
- Root (Magisk) only required for `--root` mode

## What the Script Does

1. Updates Termux packages and installs `proot` / `proot-distro`
2. Downloads the official Kali Linux ARM64 rootfs from `kali.download`
3. Extracts it to `~/kali-arm64/`
4. Configures DNS, hostname, and `.bashrc`
5. Creates a `kali` launch command in `$PREFIX/bin/kali`

## After Setup

```bash
# Enter Kali shell
kali

# Install additional tools (inside Kali)
apt-get update && apt-get install nmap wireshark-cli metasploit-framework

# Start SSH server (inside Kali)
service ssh start

# Start VNC desktop (if --vnc was used)
kali --vnc
# Connect with a VNC client to <tablet-ip>:5901, password: kali1234
```

## See Also

- [`docs/platform-pritom-tablet.md`](../../docs/platform-pritom-tablet.md) — Full platform documentation
- [`examples/kali-pritom-tablet.yml`](../../examples/kali-pritom-tablet.yml) — LinuxKit native boot configuration
- [Kali NetHunter documentation](https://www.kali.org/docs/nethunter/)
