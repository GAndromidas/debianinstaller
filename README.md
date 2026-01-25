# Debian Installer

A comprehensive post-installation script for Debian and Debian-based systems (like Ubuntu, Linux Mint, Pop!_OS, and Zorin OS), designed to automate the setup of a fully configured and optimized environment.

## Features

-   **Interactive Menu**: Simple, clean interface to choose your installation type.
-   **Two distinct modes**:
    -   **Desktop Mode**: Sets up a complete graphical environment with essential applications, development tools, media codecs, and optional gaming software.
    -   **Server Mode**: Configures a headless server with crucial services like SSH, Samba, and optional containerization with Docker and Portainer.
-   **Universal Shortcuts**: Sets `Meta+Enter` to open a terminal and `Meta+Q` to kill a window on GNOME and KDE Plasma environments.
-   **Automated Shell Setup**: Installs and configures ZSH, Oh My Zsh, useful plugins, and the modern Starship prompt.
-   **Security Hardening**: Automatically configures UFW (Uncomplicated Firewall) and installs Fail2ban to protect against SSH brute-force attacks.
-   **System Optimization**: Enables essential system services and performs system maintenance and cleanup at the end of the installation.
-   **Re-runnable**: Safely re-run the script to install new features or packages without overwriting your existing custom configurations.

## Requirements

-   A fresh installation of a Debian-based operating system.
-   A regular user account with `sudo` privileges.
-   An active internet connection.

## Usage

1.  **Clone the repository:**
    ```bash
    git clone https://github.com/GAndromidas/debianinstaller.git
    ```

2.  **Navigate to the directory:**
    ```bash
    cd debianinstaller
    ```

3.  **Make the script executable:**
    ```bash
    chmod +x install.sh
    ```

4.  **Run the installer:**
    ```bash
    ./install.sh
    ```
    You will be prompted for your `sudo` password and then guided through the installation choices.

## Installation Steps

The script automates the following steps:

1.  **System Preparation**: Updates package lists and installs essential utilities.
2.  **Shell Setup**: Configures an enhanced terminal experience with ZSH, Oh My Zsh, plugins, Starship, and Fastfetch.
3.  **Program Installation**: Installs a curated list of software based on whether you selected "Desktop" or "Server" mode, including Nerd Fonts.
4.  **Gaming Mode (Desktop Only)**: Optionally installs Steam, Lutris, GameMode, and other gaming-related tools.
5.  **Desktop Shortcuts (Desktop Only)**: Configures universal keybindings for terminal and killing windows.
6.  **Fail2ban Setup**: Installs and configures Fail2ban for SSH security.
7.  **System Services**: Enables and configures key services like the firewall and `fstrim` for SSDs.
8.  **Maintenance**: Cleans up unused packages and cache files to free up disk space.

## Customization

You can easily customize the shell environment before running the installer. Simply edit the configuration files located in the `configs/` directory:

-   `.zshrc`: The main configuration file for the ZSH shell.
-   `starship.toml`: The configuration for the Starship cross-shell prompt.
-   `config.jsonc`: The configuration for the Fastfetch system information tool.

## License

This project is licensed under the MIT License. See the `LICENSE` file for details.
