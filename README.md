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
- 🛡️ **Security-First** - Comprehensive hardening with Fail2ban and firewall configuration
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
  - CPU architecture detection (x86_64, ARM64)
  - GPU driver optimization (NVIDIA, AMD, Intel)
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
  - Fail2ban SSH brute-force protection
  - System service optimization
  - Automatic security updates configuration

- **System Reliability**
  - Robust error handling and recovery
  - Resume functionality for interrupted installations
  - Atomic state tracking with failure logging
  - Automatic sudo keepalive with cleanup on exit
  - Comprehensive logging and debugging
  - Clean environment management
  - Package dependency resolution

- **Data Integrity**
  - Automatic system maintenance tasks
  - Package cache optimization
  - System cleanup and maintenance
  - Log rotation and management

### 🎮 Installation Modes

Choose the perfect setup for your use case:

| Mode | Description | Best For |
|------|-------------|----------|
| **Desktop** | Full-featured desktop with all recommended packages | General users, enthusiasts |
| **Server** | Headless configuration with Docker, Portainer, and SSH | Servers, VMs, headless deployments |

### 🎮 Optional Gaming Mode

Transform your system into a gaming powerhouse with one click:

- Steam, Faugus Launcher (via Flatpak)
- MangoHud performance overlay
- GameMode for automatic performance tuning
- Discord for gaming communication
- Wine for Windows gaming compatibility
- ProtonPlus for Proton-GE management

### 🚀 User Experience

- **Professional Dashboard Wizard**
  - Full-screen persistent installation dashboard with live progress bar
  - Real-time step tracking with timing for each phase
  - Gum-enhanced UI with arrow-key menus and confirmations
  - Automatic fallback to traditional prompts when gum is unavailable
  - Batch installation with intelligent fallback
  - Verbose/quiet/dry-run modes for flexibility
  - Real-time package tracking and error reporting

- **Enhanced Terminal Environment**
  - Pre-configured Zsh with Oh-My-Zsh framework
  - Starship prompt for beautiful terminal design
  - Syntax highlighting and auto-completion
  - Custom aliases and productivity plugins

- **Universal Desktop Integration**
  - KDE Plasma: Custom shortcuts and optimizations
  - GNOME: Dark theme and system tweaks
  - XFCE, MATE, Cinnamon, Budgie: Full support
  - Cosmic DE: Next-generation environment support

---

### 📊 Supported Platforms

### Distributions
- ✅ **Debian** 12+ (Bookworm, Trixie)
- ✅ **Ubuntu** 22.04+ (Jammy, Noble, Mantic, Resolute Raccoon)
- ✅ **Linux Mint** 21.x, 22.x (Vanessa, Vera, Victoria, Wilma)
- ✅ **Zorin OS** 16.x, 17.x
- ✅ **Pop!_OS** 22.04+

### Hardware
- ✅ **CPU**: Intel, AMD (x86_64, ARM64)
- ✅ **GPU**: NVIDIA, AMD, Intel with appropriate drivers
- ✅ **Storage**: NVMe, SSD, HDD with optimizations
- ✅ **Form Factors**: Desktop, Laptop, Virtual Machines

### Desktop Environments
- ✅ **KDE Plasma** 5.x and 6.x
- ✅ **GNOME** 40+
- ✅ **XFCE**, **MATE**, **Cinnamon**, **Budgie**
- ✅ **Cosmic DE** (experimental)

---

## 🚀 Quick Start

### Prerequisites

- **Fresh Debian-based installation** (minimal base system)
- **Active internet connection**
- **User account with sudo privileges**
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

### Command-Line Options

```bash
./install.sh [OPTIONS]

OPTIONS:
  -h, --help      Show this help message and exit
  -v, --verbose   Enable verbose output (show all package installation details)
  -q, --quiet     Quiet mode (minimal output)
  -d, --dry-run   Preview what will be installed without making changes
```

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
  │ Log: ~/.debianinstaller.log            Ctrl+C cancel │
  └──────────────────────────────────────────────────────┘
```

When **gum** is installed, the menu uses arrow-key navigation:
```
  Your OS is: Ubuntu 24.04
  
  This script will transform your fresh Debian-based installation
  into a fully configured, optimized system!
  
  > Desktop - Full desktop setup (recommended)
    Server  - Minimal server setup
    Exit - Cancel installation
```

Without gum, a traditional numbered menu is shown instead.

---

## 📦 Package Management

### Smart Installation System

- **Package Availability Checking**: Verifies package availability before installation
- **Automatic Fallback**: GitHub releases for missing packages (eza, fastfetch, ripgrep, fd)
- **Version Management**: Always installs latest stable versions
- **Architecture Support**: Multi-architecture package detection

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

    8 completed, 0 failed, 1 skipped  |  Total: 4m 27s
```

### Package Sources

- **Official Repositories**: Primary source via apt package manager
- **GitHub Releases**: Automatic fallback for missing packages
- **Flatpak**: Modern sandboxed applications (Faugus Launcher)
- **Direct Downloads**: Vendor-specific packages (Discord, Starship)

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
- **System Updates**: Automatic security update configuration
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
├── install.sh              # Main installation script
├── scripts/                # Core functionality modules
│   ├── common.sh          # UI toolkit, dashboard wizard, shared utilities
│   ├── programs.sh        # Package installation logic
│   ├── shell_setup.sh     # ZSH and terminal configuration
│   ├── gaming_mode.sh     # Gaming mode setup
│   ├── shortcuts.sh       # Desktop environment shortcuts
│   ├── fail2ban.sh        # Security configuration
│   ├── system_services.sh  # Service management
│   ├── maintenance.sh      # System cleanup tasks
│   └── apply_configs.sh   # Configuration application
├── configs/                # Configuration files
│   ├── .zshrc             # ZSH configuration
│   ├── starship.toml      # Starship prompt config
│   └── MangoHud.conf      # Gaming overlay config
└── README.md              # This documentation
```

---

## 🤝 Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

### Development Guidelines

1. **Distribution Compatibility**: Ensure changes work across all supported distributions
2. **Error Handling**: Implement robust error handling and user feedback
3. **Documentation**: Update documentation for new features
4. **Testing**: Test on multiple distributions when possible

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
3. Include the installation log from `~/.debianinstaller.log`

---

<div align="center">

**⭐ Star this repository if you find it helpful!**

Made with ❤️ for the Debian-based Linux community

</div>


