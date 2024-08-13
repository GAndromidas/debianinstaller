#!/bin/bash

# Script: install.sh
# Description: Script for setting up a Debian-based system (Ubuntu, Pop!_OS, Debian) with various configurations and installations.
# Author: George Andromidas

# ASCII art
clear
echo -e "${CYAN}"
cat << "EOF"
 _____       _     _              ___           _        _ _           
|  __ \     | |   (_)            |_ _|_ __  ___| |_ __ _| | | ___ _ __ 
| |  | | ___| |__  _  __ _ _ __   | || '_ \/ __| __/ _` | | |/ _ \ '__|
| |  | |/ _ \ '_ \| |/ _` | '_ \  | || | | \__ \ || (_| | | |  __/ |   
| |__| |  __/ |_) | | (_| | | | |_| || | | |__) \__\__,_|_|_|\___|_|   
|_____/ \___|_.__/|_|\__,_|_| |_(_)_||_| |_|___/

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

# Function to set the hostname (only for Pop!_OS)
set_hostname() {
    if [ "$DISTRO" == "Pop" ]; then
        print_info "Please enter the desired hostname for Pop!_OS:"
        read -p "Hostname: " hostname
        sudo hostnamectl set-hostname "$hostname"
        if [ $? -ne 0 ]; then
            print_error "Error: Failed to set the hostname."
            exit 1
        else
            print_success "Hostname set to $hostname successfully."
        fi
    else
        print_warning "Skipping hostname configuration for $DISTRO."
    fi
}

# Function to enable asterisks for password in sudoers
enable_asterisks_sudo() {
    print_info "Enabling password feedback in sudoers..."
    echo "Defaults pwfeedback" | sudo tee -a /etc/sudoers.d/pwfeedback > /dev/null
    print_success "Password feedback enabled in sudoers."
}

# Function to update the system
update_system() {
    print_info "Updating system..."
    sudo apt update
    sudo apt upgrade -y
    print_success "System updated successfully."
}

# Function to install kernel headers
install_kernel_headers() {
    print_info "Installing kernel headers..."
    sudo apt install -y linux-headers-$(uname -r) build-essential
    if [ $? -ne 0 ]; then
        print_error "Error: Failed to install kernel headers."
        exit 1
    else
        print_success "Kernel headers installed successfully."
    fi
}

# Function to install media codecs (only for Ubuntu and Pop!_OS)
install_media_codecs() {
    if [ "$DISTRO" == "Ubuntu" ] || [ "$DISTRO" == "Pop" ]; then
        print_info "Installing media codecs..."
        sudo apt install -y ubuntu-restricted-extras
        print_success "Media codecs installed successfully."
    else
        print_warning "Skipping media codecs installation for $DISTRO."
    fi
}

# Function to install ZSH and Oh-My-ZSH
install_zsh() {
    print_info "Installing ZSH and Oh-My-ZSH..."
    sudo apt install -y zsh
    yes | sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
    print_success "ZSH and Oh-My-ZSH installed successfully."
}

# Function to install ZSH plugins
install_zsh_plugins() {
    print_info "Installing ZSH plugins..."
    git clone https://github.com/zsh-users/zsh-autosuggestions ~/.oh-my-zsh/custom/plugins/zsh-autosuggestions
    git clone https://github.com/zsh-users/zsh-syntax-highlighting.git ~/.oh-my-zsh/custom/plugins/zsh-syntax-highlighting
    print_success "ZSH plugins installed successfully."
}

# Function to change shell to ZSH
change_shell_to_zsh() {
    print_info "Changing shell to ZSH..."
    sudo chsh -s "$(which zsh)" $USER
    print_success "Shell changed to ZSH."
}

# Function to move .zshrc
move_zshrc() {
    print_info "Copying .zshrc to Home Folder..."
    cp "$HOME/debianinstaller/configs/.zshrc" "$HOME/"
    sed -i '/^plugins=/c\plugins=(git zsh-autosuggestions zsh-syntax-highlighting)' "$HOME/.zshrc"
    print_success ".zshrc copied and configured successfully."
}

# Function to install Starship prompt
install_starship() {
    print_info "Installing Starship prompt..."
    curl -sS https://starship.rs/install.sh | sh -s -- -y
    if [ $? -eq 0 ]; then
        mkdir -p "$HOME/.config"
        if [ -f "$HOME/debianinstaller/configs/starship.toml" ]; then
            mv "$HOME/debianinstaller/configs/starship.toml" "$HOME/.config/starship.toml"
            print_success "Starship prompt installed successfully."
            print_success "starship.toml moved to $HOME/.config/"
        else
            print_warning "starship.toml not found in $HOME/debianinstaller/configs/"
        fi
    else
        print_error "Starship prompt installation failed."
    fi
}

# Function to install programs
install_programs() {
    print_info "Installing Programs..."
    (cd "$HOME/debianinstaller/scripts" && ./programs.sh)
    # Install fastfetch from the specific script
    (cd "$HOME/debianinstaller/scripts" && ./fastfetch.sh)
    # Install fail2ban from the specific script
    (cd "$HOME/debianinstaller/scripts" && ./fail2ban.sh)
    print_success "Programs installed successfully."
}

# Function to install multiple Nerd Fonts
install_nerd_fonts() {
    print_info "Installing Nerd Fonts..."
    mkdir -p ~/.local/share/fonts
    fonts=("Hack" "FiraCode" "JetBrainsMono" "Noto")
    for font in "${fonts[@]}"; do
        wget -O "$font.zip" "https://github.com/ryanoasis/nerd-fonts/releases/download/v2.1.0/$font.zip"
        unzip -o "$font.zip" -d ~/.local/share/fonts/
        rm "$font.zip"
    done
    fc-cache -fv
    print_success "Nerd Fonts installed successfully."
}

# Function to enable services
enable_services() {
    print_info "Enabling Services..."
    local services=(
        "fstrim.timer"
        "bluetooth"
        "ssh"
        "ufw"
    )
    for service in "${services[@]}"; do
        sudo systemctl enable --now "$service"
    done
    print_success "Services enabled successfully."
}

# Function to create fastfetch config
create_fastfetch_config() {
    print_info "Creating fastfetch config..."
    fastfetch --gen-config
    print_success "fastfetch config created successfully."
    print_info "Copying fastfetch config from repository to ~/.config/fastfetch/..."
    cp "$HOME/debianinstaller/configs/config.jsonc" "$HOME/.config/fastfetch/config.jsonc"
    print_success "fastfetch config copied successfully."
}

# Function to configure UFW firewall
configure_ufw() {
    print_info "Configuring UFW..."
    sudo apt install -y ufw
    sudo ufw enable
    sudo ufw allow ssh
    if dpkg -l | grep -q kdeconnect; then
        sudo ufw allow 1714:1764/tcp
        sudo ufw allow 1714:1764/udp
    fi
    print_success "UFW configured successfully."
}

# Function to clear unused packages and cache
clear_unused_packages_cache() {
    print_info "Clearing Unused Packages and Cache..."
    sudo apt autoremove -y
    sudo apt clean
    print_success "Unused packages and cache cleared successfully."
}

# Function to delete the debianinstaller folder
delete_debianinstaller_folder() {
    print_info "Deleting Debianinstaller Folder..."
    sudo rm -rf "$HOME/debianinstaller"
    print_success "Debianinstaller folder deleted successfully."
}

# Function to reboot system
reboot_system() {
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
        sudo reboot
    else
        print_warning "Reboot canceled. You can reboot manually later by typing 'sudo reboot'."
    fi
}

# Call functions in the desired order
set_hostname
enable_asterisks_sudo
update_system
install_kernel_headers
install_media_codecs
install_zsh
install_zsh_plugins
change_shell_to_zsh
move_zshrc
install_starship
install_programs
install_nerd_fonts
enable_services
create_fastfetch_config
configure_ufw
clear_unused_packages_cache
delete_debianinstaller_folder
reboot_system
