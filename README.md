# Debian Installation Script

## Description

This script is designed for setting up a Debian-based system (such as Ubuntu, Pop!_OS, Debian) with various configurations and installations. It automates the installation of essential tools, services, and configurations to streamline the setup process for both desktop and server environments.

![debianinstaller](https://github.com/GAndromidas/debianinstaller/blob/main/debianinstaller.png)

## Features

- **Dependency Installation**: Ensures all necessary dependencies are installed before proceeding with other tasks.
- **System Update**: Updates the system and refreshes Snap and Flatpak packages if available.
- **Kernel Headers Installation**: Installs the necessary kernel headers and build essentials.
- **Media Codecs**: Installs media codecs for Ubuntu and Pop!_OS.
- **ZSH & Oh-My-ZSH**: Installs ZSH, Oh-My-ZSH, and useful plugins, then sets ZSH as the default shell.
- **Starship Prompt**: Installs and configures the Starship prompt.
- **Nerd Fonts**: Installs JetBrainsMono Nerd Font.
- **Service Management**: Enables and configures essential services like `fstrim.timer`, `ssh`, and `ufw`.
- **Firewall Configuration**: Configures UFW firewall, allowing SSH and KDE Connect (if installed).
- **Fastfetch**: Installs and configures Fastfetch for system information display.
- **Fail2Ban**: Optional installation of Fail2Ban for added security.
- **System Cleanup**: Clears unused packages and cache and removes the script's working directory.
- **Reboot Prompt**: Prompts the user to reboot the system after completing all tasks.

## Usage

### Prerequisites

- Ensure you have `sudo` privileges on the system.
- The script is designed for Debian-based distributions (e.g., Ubuntu, Pop!_OS, Debian).

### Installation

1. **Clone the repository** (or place the script in the desired location):
    ```bash
    git clone https://github.com/GAndromidas/debianinstaller
    cd debianinstaller
    ```

2. **Run the script**:
    ```bash
    ./install.sh
    ```

### Script Options

When you run the script, you will be presented with an installation menu:
- **Desktop Installation**: Installs desktop-specific tools and configurations.
- **Server Installation**: Installs server-specific tools and configurations.
- **Exit**: Exits the script.

### Customization

- **Configurations**: Custom `.zshrc` and `starship.toml` files can be placed in the `configs/` directory of the script's repository before running the script. These will be automatically copied to the appropriate locations.

### Post-Installation

After running the script:
- Review the installed tools and configurations.
- If any installations or configurations failed, re-run the script or manually install the tools.
- The script offers an option to reboot the system after completion.

## Troubleshooting

- Ensure all dependencies are installed and accessible.
- If the script fails, it will provide error messages to help diagnose the issue.
- Run the script with `bash -x install.sh` for detailed debugging output.

## Contributing

Feel free to fork the repository and submit pull requests with enhancements, bug fixes, or new features.

## License

This script is open-source and available under the MIT License. See the `LICENSE` file for more details.
