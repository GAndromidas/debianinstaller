#!/bin/bash

# Function to print error messages
print_error() {
    echo "Error: $1"
}

# Desktop programs
desktop_programs=(
    adb
    bleachbit
    btop
    cmatrix
    curl
    eza
    fail2ban
    fastboot
    ffmpeg
    git
    gnome-tweaks
    gufw
    hwinfo
    inxi
    net-tools
    openssh-server
    preload
    python3-pip
    sl
    speedtest-cli
    ttf-mscorefonts-installer
    ubuntu-restricted-extras
    ufw
    vlc
    zoxide
)

# Server programs
server_programs=(
    btop
    cmatrix
    curl
    eza
    fail2ban
    git
    hwinfo
    net-tools
    preload
    sl
    speedtest-cli
    samba
    ranger
    ufw
    xdg-user-dirs
    zoxide
)

# Function to install programs for Desktop environment
install_desktop_programs() {
    echo "Installing programs for Desktop environment..."
    sudo apt-get update
    sudo apt-get install -y "${desktop_programs[@]}"
    if [ $? -eq 0 ]; then
        echo "Desktop programs installed successfully."
    else
        echo "Failed to install Desktop programs."
        exit 1
    fi
}

# Function to install programs for Server environment
install_server_programs() {
    echo "Installing programs for Server environment..."
    sudo apt-get update
    sudo apt-get install -y "${server_programs[@]}"
    if [ $? -eq 0 ]; then
        echo "Server programs installed successfully."
    else
        echo "Failed to install Server programs."
        exit 1
    fi
}

# Main script
# Get the flag from command line argument
FLAG="$1"

# Set programs to install based on installation mode
case "$FLAG" in
    "-d")
        installation_mode="desktop"
        install_desktop_programs
        ;;
    "-s")
        installation_mode="server"
        install_server_programs
        ;;
    *)
        print_error "Invalid flag. Exiting."
        exit 1
        ;;
esac