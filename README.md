# Debian-Based System Setup Script

## Description
This script automates the setup of a Debian-based system (Ubuntu, Pop!_OS, Debian) by performing various configurations and installations. It's designed to streamline the initial setup process for new installations or after system updates.

## Author
- **George Andromidas**

## Features
- Sets the hostname (specifically for Pop!_OS).
- Enables password feedback in sudoers.
- Updates the system.
- Installs kernel headers.
- Installs media codecs (for Ubuntu and Pop!_OS).
- Installs ZSH and Oh-My-ZSH with plugins.
- Configures ZSH as the default shell.
- Installs Starship prompt with custom configuration.
- Installs specified programs and dependencies.
- Installs multiple Nerd Fonts.
- Enables and starts necessary services.
- Creates fastfetch configuration.
- Configures UFW firewall.
- Clears unused packages and cache.
- Deletes the installation folder upon completion.
- Offers the option to reboot the system.

## Prerequisites
- This script assumes it's running on a Debian-based distribution (Ubuntu, Pop!_OS, Debian).
- Internet connection is required for package installations and downloads.

## Usage
1. Clone this repository to your local machine.
2. Navigate to the directory containing `install.sh`.
3. Make the script executable if needed: `chmod +x install.sh`.
4. Run the script with elevated privileges: `sudo ./install.sh`.
5. Follow the prompts and instructions provided by the script.

## Notes
- Always review and understand scripts before executing them with elevated privileges.
- Customize configurations or add/remove functions based on your specific requirements.
- Some functions may prompt for user input or require confirmation during execution.

## Disclaimer
- Use this script at your own risk. The author takes no responsibility for any damage caused by the use of this script.
