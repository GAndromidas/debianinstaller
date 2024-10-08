#!/bin/bash

# Script: install.sh
# Description: Script for setting up a Debian-based system (Ubuntu, Pop!_OS, Debian) with various configurations and installations.
# Author: George Andromidas

# Get the directory of the script
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"  # Define SCRIPT_DIR to get the script's directory

# ASCII art
clear
echo -e "${CYAN}"
cat << "EOF"
  _____       _     _             _____           _        _ _           
 |  __ \     | |   (_)           |_   _|         | |      | | |          
 | |  | | ___| |__  _  __ _ _ __   | |  _ __  ___| |_ __ _| | | ___ _ __ 
 | |  | |/ _ \ '_ \| |/ _` | '_ \  | | | '_ \/ __| __/ _` | | |/ _ \ '__|
 | |__| |  __/ |_) | | (_| | | | |_| |_| | | \__ \ || (_| | | |  __/ |   
 |_____/ \___|_.__/|_|\__,_|_| |_|_____|_| |_|___/\__\__,_|_|_|\___|_| 

EOF

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
CYAN='\033[0;36m'
RESET='\033[0m'

# Function to print messages with colors
print_info() {
    echo -e "${CYAN}$1${RESET}"
}

print_success() {
    echo -e "${GREEN}$1${RESET}"
}

print_warning() {
    echo -e "${YELLOW}$1${RESET}"
}

print_error() {
    echo -e "${RED}$1${RESET}"
}

# Check distribution type
DISTRO=$(lsb_release -si)

# Function to handle errors
handle_error() {
    print_error "$1"
    exit 1
}

# Function to install required dependencies
install_dependencies() {
    local dependencies=(lsb-release curl fzf figlet git unzip wget)
    for cmd in "${dependencies[@]}"; do
        if ! command -v "$cmd" &> /dev/null; then
            sudo apt-get install -y "$cmd" &> /dev/null || handle_error "Error: Failed to install $cmd."
        fi
    done
    # Commenting out the success message to keep it silent
    # print_success "All required dependencies are installed."
}

# Call the dependency check function at the start
install_dependencies

# Function to show installation menu
show_menu() {
    echo -e "${CYAN}Select an installation option:${RESET}"
    echo "1) Desktop Installation"
    echo "2) Server Installation"
    echo "3) Exit"
    read -rp "Enter your choice: " choice

    case $choice in
        1)
            print_info "Starting Desktop Installation..."
            FLAG="-d"  # Set FLAG for desktop installation
            install_programs  # Call the install_programs function
            ;;
        2)
            print_info "Starting Server Installation..."
            FLAG="-s"  # Set FLAG for server installation
            install_programs  # Call the install_programs function
            ;;
        3)
            print_info "Exiting..."
            exit 0
            ;;
        *)
            print_warning "Invalid choice. Please try again."
            show_menu  # Show the menu again for invalid input
            ;;
    esac
}

# Function to enable asterisks for password in sudoers
enable_asterisks_sudo() {
    print_info "Enabling password feedback in sudoers..."
    echo "Defaults pwfeedback" | sudo tee -a /etc/sudoers.d/pwfeedback > /dev/null || handle_error "Error: Failed to enable password feedback in sudoers."
    print_success "Password feedback enabled in sudoers."
}

# Function to update the system
update_system() {
    print_info "Updating system..."
    sudo apt-get update || handle_error "Error: Failed to update package list."
    sudo apt-get upgrade -y || handle_error "Error: Failed to upgrade packages."

    # Check for Snap and refresh packages
    if command -v snap &> /dev/null; then
        print_info "Refreshing Snap packages..."
        sudo snap refresh || handle_error "Error: Failed to refresh Snap packages."
    else
        print_warning "No Snap package manager found. Skipping Snap refresh."
    fi

    # Check for Flatpak and refresh packages
    if command -v flatpak &> /dev/null; then
        print_info "Refreshing Flatpak packages..."
        flatpak update -y || handle_error "Error: Failed to refresh Flatpak packages."
    else
        print_warning "No Flatpak package manager found. Skipping Flatpak refresh."
    fi

    print_success "System updated successfully."
}

# Function to install kernel headers
install_kernel_headers() {
    print_info "Installing kernel headers..."
    sudo apt-get install -y linux-headers-$(uname -r) build-essential || handle_error "Error: Failed to install kernel headers."
    print_success "Kernel headers installed successfully."
}

# Function to install media codecs (only for Ubuntu and Pop!_OS)
install_media_codecs() {
    if [ "$DISTRO" == "Ubuntu" ] || [ "$DISTRO" == "Pop!_OS" ]; then
        print_info "Installing media codecs..."
        print_info "This may take a few moments, please wait..."
        sudo apt-get install -y ubuntu-restricted-extras || handle_error "Error: Failed to install media codecs."
        print_success "Media codecs installed successfully."
    else
        print_warning "Skipping media codecs installation for $DISTRO."
    fi
}

# Function to install Starship prompt
install_starship() {
    print_info "Installing Starship prompt..."
    print_info "This may take a few moments, please wait..."
    curl -sS https://starship.rs/install.sh | sh -s -- -y || handle_error "Error: Starship prompt installation failed."
    mkdir -p "$HOME/.config"
    if [ -f "$HOME/debianinstaller/configs/starship.toml" ]; then
        mv "$HOME/debianinstaller/configs/starship.toml" "$HOME/.config/starship.toml" || handle_error "Error: Failed to move starship.toml."
        print_success "Starship prompt installed successfully."
        print_success "starship.toml moved to $HOME/.config/"
    else
        print_warning "starship.toml not found in $HOME/debianinstaller/configs/"
    fi
}

# Function to install ZSH and Oh-My-ZSH
install_zsh() {
    # Check if Oh-My-Zsh is already installed
    if [ -d "$HOME/.oh-my-zsh" ]; then
        print_warning "Oh-My-Zsh is already installed. Skipping installation."
        return
    fi

    print_info "Installing ZSH and Oh-My-ZSH..."
    print_info "This may take a few moments, please wait..."
    sudo apt-get install -y zsh || handle_error "Error: Failed to install ZSH."
    yes | sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" || handle_error "Error: Failed to install Oh-My-ZSH."
    print_success "ZSH and Oh-My-ZSH installed successfully."
}

# Function to install ZSH plugins
install_zsh_plugins() {
    print_info "Installing ZSH plugins..."
    print_info "This may take a few moments, please wait..."
    mkdir -p ~/.oh-my-zsh/custom/plugins

    # Check if plugins are already installed
    if [ -d ~/.oh-my-zsh/custom/plugins/zsh-autosuggestions ] && [ -d ~/.oh-my-zsh/custom/plugins/zsh-syntax-highlighting ]; then
        print_warning "ZSH plugins are already installed. Skipping installation."
        return
    fi

    git clone https://github.com/zsh-users/zsh-autosuggestions ~/.oh-my-zsh/custom/plugins/zsh-autosuggestions || handle_error "Error: Failed to install zsh-autosuggestions."
    git clone https://github.com/zsh-users/zsh-syntax-highlighting.git ~/.oh-my-zsh/custom/plugins/zsh-syntax-highlighting || handle_error "Error: Failed to install zsh-syntax-highlighting."
    print_success "ZSH plugins installed successfully."
}


# Function to change shell to ZSH
change_shell_to_zsh() {
    print_info "Changing shell to ZSH..."
    sudo chsh -s "$(which zsh)" $USER || handle_error "Error: Failed to change shell to ZSH."
    print_success "Shell changed to ZSH."
}

# Function to move .zshrc
move_zshrc() {
    print_info "Copying .zshrc to Home Folder..."
    cp "$HOME/debianinstaller/configs/.zshrc" "$HOME/" || handle_error "Error: Failed to copy .zshrc."
    sed -i '/^plugins=/c\plugins=(git zsh-autosuggestions zsh-syntax-highlighting)' "$HOME/.zshrc" || handle_error "Error: Failed to configure .zshrc."
    print_success ".zshrc copied and configured successfully."
}

# Function to install programs
install_programs() {
    print_info "Installing Programs..."
    (cd "$HOME/debianinstaller/scripts" && "$SCRIPT_DIR/scripts/programs.sh" "$FLAG") || handle_error "Error: Failed to install programs."
    print_success "Programs installed successfully."
}

# Function to install multiple Nerd Fonts
install_nerd_fonts() {
    print_info "Installing Nerd Fonts..."
    mkdir -p ~/.local/share/fonts
    wget -P ~/.local/share/fonts https://github.com/ryanoasis/nerd-fonts/releases/download/v3.0.2/JetBrainsMono.zip || handle_error "Error: Failed to download JetBrainsMono."
    cd ~/.local/share/fonts || handle_error "Error: Failed to change directory to fonts."
    unzip JetBrainsMono.zip || handle_error "Error: Failed to unzip JetBrainsMono."
    rm JetBrainsMono.zip || handle_error "Error: Failed to remove JetBrainsMono.zip."
    fc-cache -fv || handle_error "Error: Failed to refresh font cache."
    print_success "JetBrainsMono Nerd Font installed successfully."
}

# Function to enable services
enable_services() {
    print_info "Enabling Services..."
    local services=(
        "fstrim.timer"
        "ssh"
        "ufw"
    )
    for service in "${services[@]}"; do
        sudo systemctl enable --now "$service" || handle_error "Error: Failed to enable service $service."
    done
    print_success "Services enabled successfully."
}

# Function to install Fastfetch
install_fastfetch() {
    print_info "Installing Fastfetch..."
    (cd "$HOME/debianinstaller/scripts" && "$SCRIPT_DIR/scripts/fastfetch.sh") || handle_error "Error: Failed to install fastfetch."
    print_success "Fastfetch installed successfully."
}

# Function to create fastfetch config
create_fastfetch_config() {
    print_info "Creating fastfetch config..."
    fastfetch --gen-config || handle_error "Error: Failed to create fastfetch config."
    print_info "Copying fastfetch config from repository to ~/.config/fastfetch/..."
    cp "$HOME/debianinstaller/configs/config.jsonc" "$HOME/.config/fastfetch/config.jsonc" || handle_error "Error: Failed to copy fastfetch config."
    print_success "fastfetch config copied successfully."
}

# Function to configure UFW firewall
configure_ufw() {
    print_info "Configuring Firewall..."
    
    if command -v ufw > /dev/null 2>&1; then
        print_info "Using UFW for firewall configuration."

        # Enable UFW
        sudo ufw enable
        
        # Set default policies
        sudo ufw default deny incoming
        print_info "Default policy set to deny all incoming connections."
        
        sudo ufw default allow outgoing
        print_info "Default policy set to allow all outgoing connections."
        
        # Allow SSH
        if ! sudo ufw status | grep -q "22/tcp"; then
            sudo ufw allow ssh
            print_success "SSH allowed through UFW."
        else
            print_warning "SSH is already allowed. Skipping SSH service configuration."
        fi

        # Check if KDE Connect is installed
        if dpkg -l | grep -q kdeconnect; then
            # Allow specific ports for KDE Connect
            sudo ufw allow 1714:1764/udp
            sudo ufw allow 1714:1764/tcp
            print_success "KDE Connect ports allowed through UFW."
        else
            print_warning "KDE Connect is not installed. Skipping KDE Connect service configuration."
        fi

        print_success "Firewall configured successfully."
    else
        print_error "UFW not found. Please install UFW."
        return 1
    fi
}

# Function to install Fail2Ban with confirmation
install_fail2ban() {
    echo -e "${CYAN}"
    figlet "Fail2Ban"
    echo -e "${NC}"

    read -rp "Do you want to install Fail2Ban? (Y/n): " confirm_install
    confirm_install="${confirm_install,,}"  # Convert to lowercase

    # Default to 'y' if Enter is pressed
    if [[ -z "$confirm_install" || "$confirm_install" == "y" ]]; then
        print_info "Installing Fail2Ban..."
        (cd "$HOME/debianinstaller/scripts" && "$SCRIPT_DIR/scripts/fail2ban.sh") || handle_error "Error: Failed to install fail2ban."
        print_success "Fail2Ban installed successfully."
    else
        print_warning "Skipping Fail2Ban installation."
    fi
}

# Function to clear unused packages and cache
clear_unused_packages_cache() {
    print_info "Clearing Unused Packages and Cache..."
    sudo apt-get autoremove -y || handle_error "Error: Failed to clear unused packages."
    sudo apt-get clean || handle_error "Error: Failed to clean package cache."
    print_success "Unused packages and cache cleared successfully."
}

# Function to delete the debianinstaller folder
delete_debianinstaller_folder() {
    print_info "Deleting Debianinstaller Folder..."
    sudo rm -rf "$HOME/debianinstaller" || handle_error "Error: Failed to delete Debianinstaller folder."
    print_success "Debianinstaller folder deleted successfully."
}

# Function to clean up temporary files
cleanup() {
    print_info "Cleaning up temporary files..."
    rm -rf "$HOME/debianinstaller/temp"  # Example: remove a temp directory if it exists
    print_success "Cleanup completed successfully."
}

# Function to reboot system
reboot_system() {
    echo -e "${CYAN}"
    figlet "Reboot System"
    echo -e "${NC}"
    
    print_info "Rebooting System..."
    printf "${YELLOW}Do you want to reboot now? (Y/n)${RESET} "

    read -rp "" confirm_reboot

    # Convert input to lowercase for case-insensitive comparison
    confirm_reboot="${confirm_reboot,,}"

    # Handle empty input (Enter pressed)
    if [[ -z "$confirm_reboot" ]]; then
        confirm_reboot="y"  # Apply "yes" if Enter is pressed
    fi

    # Validate input
    while [[ ! "$confirm_reboot" =~ ^(y|n)$ ]]; do
        read -rp "Invalid input. Please enter 'Y' to reboot now or 'n' to cancel: " confirm_reboot
        confirm_reboot="${confirm_reboot,,}"
    done

    if [[ "$confirm_reboot" == "y" ]]; then
        print_info "Rebooting now..."
        sudo reboot || handle_error "Error: Failed to reboot the system."
    else
        print_warning "Reboot canceled. You can reboot manually later by typing 'sudo reboot'."
    fi
}

# Call the show_menu function at the start
show_menu

# Call functions in the desired order
enable_asterisks_sudo
update_system
install_kernel_headers
install_media_codecs
install_starship
install_zsh
install_zsh_plugins
change_shell_to_zsh
move_zshrc
install_nerd_fonts
enable_services
install_fastfetch
create_fastfetch_config
configure_ufw
install_fail2ban
clear_unused_packages_cache
delete_debianinstaller_folder

# Perform cleanup before reboot
cleanup

# Reboot system
reboot_system
