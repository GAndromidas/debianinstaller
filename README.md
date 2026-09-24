<div align="center">

# 🚀 Debianinstaller

[![Last Commit](https://img.shields.io/github/last-commit/GAndromidas/debianinstaller.svg?style=for-the-badge)](https://github.com/GAndromidas/debianinstaller/commits/main)
[![License](https://img.shields.io/badge/License-MIT-blue.svg?style=for-the-badge)](LICENSE)

**Professional Debian-based Distro Post-Installation Automation**

Transform your fresh Debian, Ubuntu, Linux Mint, Zorin OS, or Pop!_OS installation into a fully configured, optimized system with intelligent distribution detection and tailored optimizations.

[Installation](#-quick-start) • [Features](#-key-features) • [Modes](#-installation-modes)

</div>

---

## 📋 Overview

**Debianinstaller** is a sophisticated post-installation automation tool that intelligently configures Debian-based distributions based on your system. It applies targeted optimizations rather than one-size-fits-all settings, ensuring optimal performance for your specific distribution and hardware.

**Core Philosophy:**
- 🎯 **Distribution-Aware** - Detects Debian, Ubuntu, Mint, Zorin OS, Pop!_OS with version-specific support
- 🛡️ **Security-First** - Comprehensive hardening with UFW firewall plus Fail2ban SSH protection
- ⚡ **Performance-Optimized** - Intelligent package management and system tuning
- 🔄 **Reliable** - Robust error handling, resume support, and fallback mechanisms

---

## 🎯 Key Features

### 🔍 System Intelligence & Automation

- **Distribution Detection**
  - Automatically identifies Debian, Ubuntu, Linux Mint, Zorin OS, Pop!_OS
  - Version-specific package compatibility checking
  - Distribution-specific repository configuration
  - Codename detection for precise package management

- **Hardware-Aware Installation**
  - CPU type detection (x86_64, ARM64)
  - Multi-GPU detection and driver optimization (NVIDIA, AMD, Intel — every GPU reported, hybrids included)
  - Storage type detection and optimization
  - Desktop environment recognition and integration

- **Professional Dashboard Wizard**
  - Full-screen persistent installation dashboard with live progress bar
  - Real-time step tracking with per-step timing
  - Gum-enhanced interactive menus with arrow-key navigation
  - Automatic fallback to traditional prompts when gum is unavailable

- **Smart Package Management**
  - Package availability checking before installation
  - Automatic fallback to GitHub releases for missing packages
  - Batch installation with individual fallback
  - Professional progress indicators with verbose/quiet modes

### 🛡️ Security & Stability

- **Security Hardening (Enabled by Default)**
  - UFW firewall configuration with secure policies
  - Fail2ban SSH brute-force protection (sshd jail verified post-install)
  - System service optimization
  - Automatic security updates configuration

- **System Reliability**
  - Robust error handling and recovery
  - Resume functionality for interrupted installations (state in /var/tmp survives reboot)
  - Atomic state tracking with failure logging (COMPLETED/SKIPPED/FAILED)
  - Automatic sudo keepalive with cleanup on exit
  - Comprehensive logging and debugging
  - Read-only `--check` health verification that changes nothing

- **Data Integrity**
  - Automatic system maintenance tasks
  - Package cache optimization
  - System cleanup and maintenance
  - Log rotation and management

### 💻 Shell & Desktop Experience

- **Zsh + Starship**
  - Pre-configured Zsh with Oh-My-Zsh framework
  - Starship prompt for beautiful terminal design
  - Syntax highlighting and auto-completion
  - Custom aliases and productivity plugins

- **Universal Desktop Integration**
  - KDE Plasma: Custom shortcuts and optimizations
  - GNOME: Dark theme and system tweaks
  - XFCE, MATE, Cinnamon, Budgie: Full support
  - Cosmic DE: Next-generation environment support

### 🎮 Installation Modes

Choose the perfect setup for your use case:

| Mode | Description | Best For |
|------|-------------|----------|
| **Desktop** | Full-featured desktop with all recommended packages | General users, enthusiasts |
| **Server** | Headless configuration with Docker, SSH, server utilities | Servers, VMs, headless deployments |

### 🎮 Optional Gaming Mode

Transform your system into a gaming powerhouse with one click (Desktop mode only):

- Steam (with steam-installer fallback)
- Faugus Launcher (via Flatpak)
- MangoHud performance overlay
- GameMode for automatic performance tuning
- Discord for gaming communication
- Wine for Windows gaming compatibility
- ProtonPlus for Proton-GE management

---

### 📊 Supported Platforms

### Distributions
- ✅ **Debian** 12+ (Bookworm, Trixie)
- ✅ **Ubuntu** 22.04+ (Jammy, Noble, and later)
- ✅ **Linux Mint** 21.x, 22.x
- ✅ **Zorin OS** 16.x, 17.x+
- ✅ **Pop!_OS** 22.04+

### Hardware
- ✅ **CPU**: Intel, AMD (x86_64, ARM64)
- ✅ **GPU**: NVIDIA, AMD, Intel with appropriate drivers (multi-GPU hybrids reported)
- ✅ **Storage**: NVMe, SSD, HDD with optimizations
- ✅ **Form Factors**: Desktop, Laptop, Virtual Machines

### Desktop Environments
- ✅ **KDE Plasma** 5.x and 6.x
- ✅ **GNOME** 40+
- ✅ **XFCE**, **MATE**, **Cinnamon**, **Budgie**
- ✅ **Cosmic DE** (experimental)

---

## 🚀 Quick Start

### Requirements

- **Fresh Debian-based installation** (minimal base system)
- **Active internet connection**
- **User account with sudo privileges** (do NOT run as root)
- **2GB+ free disk space**

### Installation

```bash
# Clone and run
git clone https://github.com/gandromidas/debianinstaller.git
cd debianinstaller
./install.sh
```

**One-Click Setup:** The installer handles everything automatically - just select your preferred mode and let it configure your system.

### Installation Modes

| Mode | Use Case | Description |
|------|----------|-------------|
| **Desktop** | General desktop use | Full-featured setup with all recommended packages |
| **Server** | Headless deployments | Docker, SSH, server utilities |

With `--auto`, headless systems automatically get Server mode, everything else gets Desktop mode.

### Command-Line Options

```bash
./install.sh [OPTIONS]

OPTIONS:
  -h, --help      Show this help message and exit
  -V, --version   Show version information and exit
  -v, --verbose   Enable verbose output (show all package installation details)
  -q, --quiet     Quiet mode (minimal output)
  -d, --dry-run   Preview what will be installed without making changes
  -a, --auto      Automatically select the recommended installation mode
  -y, --yes       Non-interactive mode: accept safe/default prompts automatically
  -c, --check     Read-only health check (runs scripts/verify.sh, changes nothing)
```

Examples:

```bash
./install.sh                # Interactive install
./install.sh --verbose      # Detailed package installation output
./install.sh --dry-run      # Preview changes without making them
./install.sh --auto         # Automatically choose the recommended mode
./install.sh --yes          # Unattended run with safe/default choices
./install.sh --check        # Verify an installed system (read-only)
```

### Installation Steps

| # | Step | Module | Notes |
|---|------|--------|-------|
| 1 | System Preparation | `modules/system_preparation.sh` | Asks before continuing on failure |
| 2 | Shell Setup | `modules/shell_setup.sh` | Zsh + Oh-My-Zsh + Starship |
| 3 | Programs Installation | `modules/programs.sh` | Package lists from `configs/programs.yaml` |
| 4 | Gaming Mode | `modules/gaming_mode.sh` | Desktop only, opt-in; skipped on Server |
| 5 | Desktop Shortcuts | `modules/shortcuts.sh` | Skipped on Server |
| 6 | Fail2ban Setup | `modules/fail2ban.sh` | SSH brute-force protection |
| 7 | System Services | `modules/system_services.sh` | Essential services |
| 8 | Maintenance | `modules/maintenance.sh` | Cleanup and tuning |
| 9 | Apply Custom Configurations | `modules/apply_configs.sh` | Always runs (latest dotfiles) |

### Installation Experience

The installer provides a professional dashboard wizard with real-time progress tracking:

```
  ┌──────────────────────────────────────────────────────┐
  │ ● Debian Installer                        Step 1/9  │
  ├──────────────────────────────────────────────────────┤
  │  ███████████░░░░░░░░░░░░░░░░░  System Pre...  11%  │
  ├──────────────────────────────────────────────────────┤
  │   1  ✓ System Preparation                   12s     │
  │   2  ● Running...                                    │
  │   3  ○ Pending                                       │
  │   4  ○ Pending                                       │
  │   5  ○ Pending                                       │
  │   6  ○ Pending                                       │
  │   7  ○ Pending                                       │
  │   8  ○ Pending                                       │
  │   9  ○ Pending                                       │
  ├──────────────────────────────────────────────────────┤
  │ Log: /var/tmp/debianinstaller.log    Ctrl+C cancel │
  └──────────────────────────────────────────────────────┘
```

When **gum** is installed, the menu uses arrow-key navigation:

```
  Your OS is: Ubuntu 24.04

  This script will transform your fresh Debian-based installation
  into a fully configured, optimized system!

  > Desktop (Gaming) - Full desktop setup with gaming mode (recommended)
    Desktop (No Gaming) - Full desktop setup without gaming mode
    Server  - Minimal server setup (Docker, SSH, etc.)
    Exit - Cancel installation
```

Without gum, a traditional numbered menu is shown instead.

---

## 📦 Package Management

### Smart Installation System

- **Package Availability Checking**: Verifies package availability before installation
- **Automatic Fallback**: GitHub releases for missing packages (eza, fastfetch, ripgrep, fd)
- **Version Management**: Always installs latest stable versions
- **Multi-CPU-type package detection**: amd64/arm64 handled automatically

### Enhanced Package Tracking

After completion, the dashboard displays a full summary:

```
  ╔══════════════════════════════════════════════════════╗
  ║              Installation Complete                   ║
  ╚══════════════════════════════════════════════════════╝

  ✓  Step  1: System Preparation                 12s
  ✓  Step  2: Shell Setup                         45s
  ✓  Step  3: Programs Installation               2m 30s
  ◇  Step  4: Gaming Mode                      Skipped
  ✓  Step  5: Desktop Shortcuts                   8s
  ✓  Step  6: Fail2ban Setup                      15s
  ✓  Step  7: System Services                     22s
  ✓  Step  8: Maintenance                         10s
  ✓  Step  9: Apply Custom Configurations         5s

  ──────────────────────────────────────────────────────

    8 completed, 0 failed, 0 warnings, 1 skipped  |  Total: 4m 27s
```

### Package Sources

- **Official Repositories**: Primary source via apt package manager
- **GitHub Releases**: Automatic fallback for missing packages
- **Flatpak**: Modern sandboxed applications (Faugus Launcher)
- **Direct Downloads**: Vendor-specific packages (Discord, Starship)

> Package lists live in `configs/programs.yaml` and `configs/gaming_mode.yaml` — edit those files to change what gets installed, not the scripts.

---

## 🔧 Configuration & Customization

### Shell Environment

- **ZSH Configuration**: Modern shell with Oh-My-Zsh framework
- **Starship Prompt**: Beautiful, informative prompt system
- **Productivity Plugins**: Autosuggestions, syntax highlighting
- **Custom Aliases**: Enhanced command shortcuts

### Desktop Integration

- **Universal Shortcuts**: Meta+Enter for terminal, Meta+Q to close windows
- **Theme Optimization**: Dark mode and visual enhancements
- **Performance Tuning**: Desktop-specific optimizations
- **Service Management**: Essential system services configuration

### Security Configuration

- **Firewall Setup**: UFW with secure default policies
- **SSH Hardening**: Fail2ban brute-force protection
- **System Updates**: Automatic security update configuration (APT daily timers)
- **User Permissions**: Proper sudo and access control

---

## 🎮 Gaming Mode Details

### Gaming Stack

| Component | Source | Purpose |
|-----------|--------|---------|
| **Steam** | Repository | Native gaming platform |
| **Faugus Launcher** | Flatpak | Modern game launcher |
| **GameMode** | Repository | Performance optimization |
| **MangoHud** | Repository | FPS overlay |
| **Discord** | Direct Download | Gaming communication |
| **Wine** | Repository | Windows compatibility |
| **ProtonPlus** | Flatpak | Proton-GE management |

### Performance Features

- **GameMode**: Automatic CPU/GPU optimization during gaming
- **MangoHud**: Real-time FPS, temperature, and system stats overlay
- **Vulkan Tools**: Graphics API utilities and diagnostics
- **Wine Integration**: Windows game compatibility with optimized configuration

---

## 📁 Project Structure

```
debianinstaller/
├── install.sh              # Main installation script (flags, traps, step runner)
├── scripts/
│   ├── common.sh           # Compatibility facade (show_menu, prompt_reboot)
│   ├── verify.sh           # Read-only post-install health check
│   ├── lib/                # Shared libraries
│   │   ├── core.sh         # Logging, timing, globals
│   │   ├── ui.sh           # Gum/terminal UI helpers
│   │   ├── system.sh       # Distro detection, headless check
│   │   ├── package.sh      # apt install helpers
│   │   ├── config.sh       # YAML parsing helpers
│   │   ├── state.sh        # Resume state (COMPLETED/SKIPPED/FAILED)
│   │   └── dashboard.sh    # Wizard dashboard renderer
│   └── modules/            # One install step per file
│       ├── system_preparation.sh
│       ├── shell_setup.sh
│       ├── programs.sh
│       ├── gaming_mode.sh
│       ├── shortcuts.sh
│       ├── fail2ban.sh
│       ├── system_services.sh
│       ├── maintenance.sh
│       └── apply_configs.sh
├── configs/                # Configuration files and package lists
│   ├── programs.yaml       # Package lists (edit to change what is installed)
│   ├── gaming_mode.yaml    # Gaming package lists
│   ├── .zshrc              # ZSH configuration
│   ├── starship.toml       # Starship prompt config
│   └── MangoHud.conf       # Gaming overlay config
├── tests/
│   └── syntax.sh           # bash -n check over all scripts
└── README.md               # This documentation
```

---

## 🔄 Resume, Logs & Safety

### Resume

Progress is tracked in `/var/tmp/debianinstaller.state` (one `COMPLETED:`/`SKIPPED:`/`FAILED:` line per step). `/var/tmp` survives reboots, so re-running `./install.sh` after an interruption or reboot automatically skips finished steps. Legacy `~/.debianinstaller.state` files migrate automatically.

- Start fresh: `rm -f /var/tmp/debianinstaller.state`
- A stale `FAILED:` line from an earlier interrupted run is cleared automatically after a run reaches the end.

### Logs

- Installation log: `/var/tmp/debianinstaller.log` (legacy `~/.debianinstaller.log` migrates automatically)
- Every step's output is appended to the log; interactive prompts always use the terminal directly

### Safety

- Flags are parsed **before** any side effects — `--help`, `--version`, and `--check` never touch your system
- `--dry-run` never writes resume state and never installs helpers (including gum)
- `--check` / `./install.sh --check` execs `scripts/verify.sh`, which is fully read-only
- No `ERR` trap: expected non-zero exit codes inside steps can't abort the whole run
- `Ctrl+C` / termination is trapped for a clean stop with resume instructions, never a half-written state

### Verify

After rebooting into the configured system, run the read-only health check:

```bash
./install.sh --check
# or
bash scripts/verify.sh --verbose
```

It checks live booted state the install log cannot prove: GPU kernel drivers, UFW active status, fail2ban sshd jail, Wake-on-LAN flags, APT timers, zsh/starship, and gaming packages (via `dpkg -l`).

---

## 🧪 Testing

```bash
# Syntax-check every shell script in the repo
bash tests/syntax.sh

# Syntax-check a single file
bash -n install.sh
```

---

## 🔧 Troubleshooting

| Symptom | Fix |
|---------|-----|
| `This script should NOT be run as root` | Run as a regular user with sudo privileges |
| `No internet connection detected` | Check connectivity to debian.org |
| `Insufficient disk space` | Free at least 2GB on `/` |
| Sudo password prompt never appears | Steps redirect to the log; prompts use `/dev/tty` — run in a real terminal, not a pipe |
| Resume re-runs a finished step | Check `/var/tmp/debianinstaller.state` for its `COMPLETED:` line |
| Gum UI missing | Installed automatically via apt (GitHub `.deb` fallback); without it the classic menu is used |
| Verify reports UFW inactive | `sudo ufw enable`, then re-run `--check` |
| Verify reports sshd jail missing | Check `sudo fail2ban-client status` and `/etc/fail2ban/jail.local` |

---

## 🤝 Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

### Development Guidelines

1. **Distribution Compatibility**: Ensure changes work across all supported distributions
2. **Error Handling**: Implement robust error handling and user feedback
3. **Documentation**: Update documentation for new features
4. **Testing**: Run `bash tests/syntax.sh` and test on multiple distributions when possible

---

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

---

## 🙏 Acknowledgments

- **Debian Project**: For the stable foundation
- **Ubuntu Community**: For distribution-specific insights
- **Linux Mint Team**: For desktop environment expertise
- **Zorin OS Team**: For user experience innovations
- **Pop!_OS Team**: For modern desktop approaches

---

## 📞 Support

If you encounter any issues:

1. Check the [Issues](https://github.com/GAndromidas/debianinstaller/issues) page
2. Create a new issue with details about your system
3. Include the installation log from `/var/tmp/debianinstaller.log`

---

<div align="center">

**⭐ Star this repository if you find it helpful!**

Made with ❤️ for the Debian-based Linux community

</div>
