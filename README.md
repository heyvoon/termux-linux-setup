# 🐧 Termux Linux Desktop Setup

> **Transform your Android device into a fully functional Linux desktop** — with GPU acceleration, audio, Windows app support, and your choice of desktop environment.

<div align="center">

[![Termux](https://img.shields.io/badge/Termux-Android-blue?logo=android&logoColor=white)](https://termux.dev)
[![X11](https://img.shields.io/badge/Display-Termux--X11-orange?logo=x&logoColor=white)](https://github.com/termux/termux-x11)
[![DEs](https://img.shields.io/badge/Desktops-XFCE%20%7C%20LXQt%20%7C%20MATE%20%7C%20KDE-purple)](https://xfce.org)
[![GPU](https://img.shields.io/badge/GPU-Zink%20%7C%20Turnip-green?logo=opengl)](https://docs.mesa3d.org/drivers/zink.html)
[![Tested](https://img.shields.io/badge/Tested-Samsung%20SM--A226B%20%7C%20Android%2013-brightgreen)](#)
[![License](https://img.shields.io/github/license/heyvoon/termux-linux-setup)](LICENSE)

</div>

---

## ✨ Features

| Feature | Description |
|---------|-------------|
| 🖥️ **4 Desktop Environments** | Choose XFCE4 (recommended), LXQt (lightweight), MATE (classic), or KDE Plasma (modern) |
| 🎮 **Hardware GPU Acceleration** | Auto-detects Adreno GPUs → installs **Turnip** driver; others use **Zink** Vulkan-to-OpenGL translation |
| 🔊 **Audio Support** | PulseAudio server pre-configured for Termux-X11 compatibility |
| 🪟 **Windows App Support** | Wine + Box64 integration for running x86_64 Windows applications *(optional)* |
| 🐍 **Python Dev Environment** | Python 3 + Flask pre-installed with a hardware-accelerated demo server |
| 🌐 **Browser & Media** | Firefox, VLC, Git, cURL, and essential dev tools included by default |
| 🔐 **SSH Access** | Built-in OpenSSH setup guide — control your Android Linux desktop from your PC |
| ⚙️ **CLI Flags** | `--skip-wine`, `--skip-gpu`, `--dry-run`, `--help` for flexible, testable installs |
| 📝 **Full Logging** | Every step logged to `~/termux-setup-*.log` for easy debugging |
| 🧹 **Idempotent & Safe** | Skips already-installed packages; graceful error handling; no broken states |

---

## 📱 Tested Devices

| Device | Android | GPU | Status |
|--------|---------|-----|--------|
| **Samsung Galaxy A22 5G (SM-A226B)** | 13 | Mali-G57 MC2 | ✅ Fully functional (Zink) |
| OnePlus 9 | 12 | Adreno 660 | ✅ Turnip acceleration |
| Xiaomi Poco X3 Pro | 13 | Adreno 640 | ✅ Turnip acceleration |
| Google Pixel 6a | 14 | Mali-G78 MP10 | ✅ Zink (software fallback available) |

> 💡 **Tip**: Adreno GPUs (Qualcomm) get the best performance via **Turnip**. Mali/PowerVR devices use **Zink** with excellent compatibility.

---

## 🚀 Quick Start

### 1️⃣ Install Required Apps (One-Time Setup)

| App | Source | Why? |
|-----|--------|------|
| **Termux** | [F-Droid](https://f-droid.org/en/packages/com.termux/) | Play Store version is deprecated and broken |
| **Termux-X11** | [GitHub Releases](https://github.com/termux/termux-x11/releases/tag/nightly) | Acts as your external display server (download `app-arm64-v8a-debug.apk`) |

> ⚠️ **Critical**: Grant Termux **Storage** and **Display over other apps** permissions in Android Settings → Apps → Termux → Permissions.

### 2️⃣ Run the Installer

Open **Termux** and execute:

```bash
curl -O https://raw.githubusercontent.com/heyvoon/termux-linux-setup/main/termux-linux-setup.sh && \
chmod +x termux-linux-setup.sh && \
./termux-linux-setup.sh
```

### 3️⃣ Launch Your Desktop

```bash
# Start the Linux desktop
~/start-linux.sh

# Open the Termux-X11 app to view your desktop!

# Stop the desktop when done
~/stop-linux.sh
```

---

## 🔧 Advanced Usage

### CLI Flags
```bash
./termux-linux-setup.sh --help

# Skip heavy components for faster testing
./termux-linux-setup.sh --skip-wine --skip-gpu

# Preview commands without installing (dry-run)
./termux-linux-setup.sh --dry-run
```

### 🌐 SSH Into Termux From Your Desktop (Recommended!)
Control your Android Linux environment from your PC:

```bash
# On Termux (one-time setup)
pkg install openssh -y
passwd                          # Set a password
sshd                            # Start SSH server (port 8022)
ip addr show wlan0 | grep inet  # Note your IP address

# Optional: Keep SSH alive when screen is off
termux-wake-lock
```

```bash
# On your desktop (Linux/macOS/WSL)
ssh u0_aXXX@192.168.1.XX -p 8022
# Example: ssh u0_a123@192.168.1.45 -p 8022
```

> 🔐 **Pro Tip**: Set up SSH keys for passwordless login:
> ```bash
> # On desktop
> ssh-keygen -t ed25519
> ssh-copy-id -p 8022 u0_aXXX@192.168.1.XX
> ```

---

## 🛠️ What We Fixed & Improved

This isn't a generic script — it's been battle-tested and refined specifically for Android/Termux:

### 🐛 Critical Bug Fixes
| Issue | Solution |
|-------|----------|
| ❌ `plank` package removed from repos | Replaced with graceful fallback; auto-skips if unavailable |
| ❌ `vulkan-loader-android` doesn't exist | Uses `mesa-vulkan-drivers` + `vulkan-tools` (modern Termux standard) |
| ❌ `box64` requires `game-repo` | Auto-adds `game-repo`; conditionally installs with fallback |
| ❌ Heredoc syntax errors (`unexpected token '}'`) | All heredocs now use `<< 'MARKER'` to prevent variable expansion bugs |
| ❌ `pkill -9` corrupting sessions | Replaced with graceful `TERM` → wait → `KILL` sequence |

### ⚙️ Android-Specific Optimizations
| Enhancement | Benefit |
|-------------|---------|
| ✅ `XDG_RUNTIME_DIR` & `PULSE_RUNTIME_DIR` set to `$PREFIX/tmp` | Fixes PulseAudio/D-Bus failures on Android's restricted filesystem |
| ✅ `MESA_LOADER_DRIVER_OVERRIDE=zink` + `LIBGL_ALWAYS_SOFTWARE=0` | Forces hardware acceleration path; prevents silent fallback to `swrast` |
| ✅ `termux-x11 :0` (no legacy flag) | Compatible with Termux-X11 nightly builds; clean input handling |
| ✅ Explicit `dbus-daemon --session` startup | Resolves `Failed to get system bus` warnings in XFCE/MATE |
| ✅ `XDG_SESSION_TYPE=x11` + `XDG_SESSION_CLASS=user` | Silences ConsoleKit/UPower warnings (Android handles power natively) |
| ✅ Session cache cleanup (`~/.cache/sessions/*`) | Prevents Plank/old configs from auto-spawning on restart |

### 🧰 Developer Experience
| Feature | Why It Matters |
|---------|---------------|
| 📝 Full logging to `~/termux-setup-*.log` | Debug installs without guessing; share logs for support |
| 🔄 Idempotent package checks | Safe to re-run; skips already-installed components |
| 🚫 Graceful fallbacks | Missing packages warn but don't abort the entire install |
| 🧪 `--dry-run` mode | Test the script's logic before committing to installs |
| 📦 Dynamic `$PREFIX`/`$HOME` paths | Works on work profiles, secondary users, and external installs |

---

## ❓ Troubleshooting

### 🖥️ "X server already running on display :0"
```bash
# Force clean restart
~/stop-linux.sh
rm -rf ~/.cache/sessions/*
~/start-linux.sh
```

### 🎨 Black screen or no GPU acceleration
```bash
# Verify Zink is active
echo $GALLIUM_DRIVER  # Should output: zink

# Force re-init GPU env
source ~/.config/linux-gpu.sh
~/stop-linux.sh && ~/start-linux.sh
```

### 🔊 No audio
```bash
# Check PulseAudio status
pulseaudio --check -v

# Restart audio subsystem
pkill pulseaudio
pulseaudio --start --exit-idle-time=-1
export PULSE_SERVER="$PREFIX/tmp/pulse/native"
```

### 🪟 Wine fails to launch
```bash
# Verify Wine path
which wine
wine --version

# Re-init Wine prefix (first run only)
winecfg  # Creates ~/.wine
```

### 📱 Termux-X11 app shows "Connecting..."
1. Ensure Termux-X11 has **Display over other apps** permission
2. Run `~/start-linux.sh` *before* opening the Termux-X11 app
3. Wait ~5 seconds after `Launching Termux-X11...` before switching apps

---

## 🤝 Contributing

Found a bug? Want to add a new desktop environment or tool?

1. Fork the repo
2. Create a feature branch (`git checkout -b feat/amazing-idea`)
3. Test on at least one real device (emulators often miss Android quirks)
4. Open a PR with:
   - Device model & Android version tested
   - Screenshots/logs of the change
   - Clear description of the improvement

All contributions welcome — especially from users with non-Qualcomm GPUs!

---

## 📄 License

MIT License — Use, modify, and share freely.  
See [LICENSE](LICENSE) for details.

> ⚠️ **Disclaimer**: This script installs complex software stacks on Android. While tested extensively, always backup important data. The authors are not liable for device issues arising from use.

---

<div align="center">

**Made with ❤️ for the Termux community**  
*Last tested: Samsung SM-A226B • Android 13 • Termux 0.118.0 • Termux-X11 nightly*

[⬆️ Back to Top](#-termux-linux-desktop-setup)

</div>