#!/bin/bash

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
echo "Welcome to the program installer script."
echo "Choose an option:"
echo "1. Desktop"
echo "2. Server"
read -p "Enter your choice (1 or 2): " choice
case $choice in
    1)
        install_desktop_programs
        ;;
    2)
        install_server_programs
        ;;
    *)
        echo "Invalid choice. Please enter '1' or '2'."
        exit 1
        ;;
esac
