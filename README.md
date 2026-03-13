# Debian Installer

A comprehensive post-installation script for Debian and Debian-based systems, designed to automate the setup of a fully configured and optimized environment with enhanced compatibility across multiple distributions.

## Enhanced Distribution Support

✅ **Fully Supported Distributions:**
- **Debian**: 12.x, 13.x (Trixie)
- **Ubuntu**: 22.04 LTS, 24.04 LTS, 24.10, 25.04, 25.10, 26.04 LTS
- **Linux Mint**: 21.x, 22.x
- **Zorin OS**: 16, 17, 18
- **Pop!_OS**: 22.04 LTS, 24.04 LTS

✅ **Desktop Environment Support:**
- GNOME (Ubuntu, Pop!_OS legacy, Debian default)
- KDE Plasma (Kubuntu, Debian KDE)
- XFCE (Xubuntu, Debian XFCE)
- MATE (Ubuntu MATE, Debian MATE)
- Cinnamon (Linux Mint)
- Budgie
- Cosmic DE (Pop!_OS Cosmic epoch 1.0.8+)

## Features

-   **Enhanced Distribution Detection**: Automatically detects your specific distribution and version for optimal compatibility
-   **Smart Package Management**: Checks package availability before installation and skips unavailable packages
-   **Fallback Installation**: Installs essential tools (eza, fastfetch, ripgrep, fd) via GitHub releases when not available in repositories
-   **Distribution-Specific Optimizations**: Applies tailored settings for each supported distribution
-   **Repository Configuration**: Automatically enables appropriate repositories (universe, multiverse, contrib, non-free)
-   **Interactive Menu**: Simple, clean interface to choose your installation type.
-   **Two distinct modes**:
    -   **Desktop Mode**: Sets up a complete graphical environment with essential applications, development tools, media codecs, and optional gaming software.
    -   **Server Mode**: Configures a headless server with crucial services like SSH, Samba, and optional containerization with Docker and Portainer.
-   **Universal Shortcuts**: Sets `Meta+Enter` to open a terminal and `Meta+Q` to kill a window on GNOME, KDE, XFCE, MATE, Cinnamon, Pop!_OS, and Cosmic DE environments.
-   **Automated Shell Setup**: Installs and configures ZSH, Oh My Zsh, useful plugins, and the modern Starship prompt.
-   **Security Hardening**: Automatically configures UFW (Uncomplicated Firewall) and installs Fail2ban to protect against SSH brute-force attacks.
-   **System Optimization**: Enables essential system services and performs distribution-specific optimizations.
-   **Re-runnable**: Safely re-run the script to install new features or packages without overwriting your existing custom configurations.

## Requirements

-   A fresh installation of a supported Debian-based operating system (see list above)
-   A regular user account with `sudo` privileges.
-   An active internet connection.
-   Minimum 2GB free disk space.

## Usage

1.  **Clone the repository:**
    ```bash
    git clone https://github.com/GAndromidas/debianinstaller.git
    ```

2.  **Navigate to the directory:**
    ```bash
    cd debianinstaller
    ```

3.  **Test compatibility (optional but recommended):**
    ```bash
    chmod +x test_compatibility.sh
    ./test_compatibility.sh
    ```

4.  **Make the script executable:**
    ```bash
    chmod +x install.sh
    ```

5.  **Run the installer:**
    ```bash
    ./install.sh
    ```
    You will be prompted for your `sudo` password and then guided through the installation choices.

## Command Line Options

-   `./install.sh` - Run with interactive prompts
-   `./install.sh --verbose` - Show detailed package installation output
-   `./install.sh --dry-run` - Preview what will be installed without making changes
-   `./install.sh --help` - Show help message

## Installation Steps

The script automates the following steps:

1.  **Distribution Detection & Compatibility Check**: Identifies your distribution and verifies compatibility
2.  **System Preparation**: Updates package lists, installs essential utilities, and configures distribution-specific repositories
3.  **Shell Setup**: Configures an enhanced terminal experience with ZSH, Oh My Zsh, plugins, Starship, and Fastfetch
4.  **Program Installation**: Installs a curated list of software based on your selection, with distribution-specific package filtering
5.  **Gaming Mode (Desktop Only)**: Optionally installs Steam, Faugus Launcher, GameMode, and other gaming-related tools
6.  **Desktop Shortcuts (Desktop Only)**: Configures universal keybindings for your specific desktop environment
7.  **Fail2ban Setup**: Installs and configures Fail2ban for SSH security
8.  **System Services**: Enables essential services and applies distribution-specific optimizations
9.  **Maintenance**: Performs system cleanup and maintenance tasks

## What's New in This Version

### 🚀 Enhanced Compatibility
- **Smart Distribution Detection**: Automatically detects Debian, Ubuntu, Linux Mint, Zorin OS, and Pop!_OS with version-specific support
- **Package Availability Checking**: Prevents installation failures by checking package availability before installation
- **Repository Management**: Automatically enables appropriate repositories for each distribution
- **Desktop Environment Support**: Full support for GNOME, KDE, XFCE, MATE, Cinnamon, and Budgie

### 🔧 Distribution-Specific Features
- **Debian**: Enables contrib/non-free repositories, installs firmware packages
- **Ubuntu/Linux Mint/Zorin OS**: Enables universe/multiverse repositories, includes ubuntu-restricted-extras
- **Pop!_OS**: Includes Pop Shell and System76 power management optimizations
- **Pop!_OS Cosmic**: Cosmic DE support with manual shortcut configuration guidance

### 🛠️ Improved Error Handling
- Graceful handling of missing packages across different distributions
- Better error reporting and logging
- Non-critical failures won't stop the entire installation

### 🧪 Testing Tools
- New compatibility test script (`./test_compatibility.sh`) to verify system compatibility before running the main installer

## Troubleshooting

### Common Issues and Solutions

1.  **Package Not Available Errors**: The script automatically skips unavailable packages and uses fallback installation methods for essential tools
2.  **Repository Issues**: The script attempts to enable required repositories automatically
3.  **Desktop Environment Not Detected**: Some environments may require manual shortcut configuration
4.  **Permission Denied**: Ensure you're running as a regular user with sudo privileges, not as root
5.  **GitHub Installation Fails**: If fallback installations fail, check internet connection and try running the script again

### Log Files

- Installation log: `~/.debianinstaller.log`
- State tracking: `~/.debianinstaller.state` (for resuming interrupted installations)

## Contributing

Contributions are welcome! Please ensure:
1.  Test changes across multiple distributions
2.  Update the compatibility test script when adding new features
3.  Follow the existing code style and error handling patterns

## License

This project is licensed under the MIT License. See the `LICENSE` file for details.

## Customization

You can easily customize the shell environment before running the installer. Simply edit the configuration files located in the `configs/` directory:

-   `.zshrc`: The main configuration file for the ZSH shell.
-   `starship.toml`: The configuration for the Starship cross-shell prompt.
-   `config.jsonc`: The configuration for the Fastfetch system information tool.

## License

This project is licensed under the MIT License. See the `LICENSE` file for details.
