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
    apt-transport-https
    btop
    ca-certificates
    cmatrix
    curl
    eza
    git
    gnupg2
    hwinfo
    net-tools
    preload
    ranger
    samba
    software-properties-common
    sl
    speedtest-cli
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
        echo -e "\033[32mDesktop programs installed successfully:\033[0m"
        for program in "${desktop_programs[@]}"; do
            echo -e "\033[34m- $program\033[0m"  # Blue color for program names
        done
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
        echo -e "\033[32mServer programs installed successfully:\033[0m"
        for program in "${server_programs[@]}"; do
            echo -e "\033[34m- $program\033[0m"  # Blue color for program names
        done
        install_docker  # Call the Docker, Portainer, and Watchtower installation function
        install_casaos  # Call the CasaOS installation function after server programs installation
    else
        echo "Failed to install Server programs."
        exit 1
    fi
}

# Function to install Docker, Portainer, and Watchtower
install_docker() {
    echo "Installing Docker..."
    sudo apt-get install -y docker.io
    echo "Installing Portainer..."
    # Check if Portainer is already installed
    if ! sudo docker ps -a | grep -q portainer; then
        sudo docker volume create portainer_data
        sudo docker run -d -p 8000:8000 -p 9000:9000 --name=portainer \
        --restart=always \
        -v /var/run/docker.sock:/var/run/docker.sock \
        -v portainer_data:/data \
        portainer/portainer-ce
    else
        echo "Portainer is already installed."
    fi
    echo "Installing Watchtower..."
    sudo docker run -d \
        --name watchtower \
        -v /var/run/docker.sock:/var/run/docker.sock \
        containrrr/watchtower
}

# Function to install CasaOS
install_casaos() {
    echo -e "${CYAN}"
    figlet "CasaOS"  # Display CasaOS banner
    echo -e "${NC}"

    read -p "Do you want to install CasaOS? (Y/n): " choice
    choice=${choice:-y}  # Default to 'y' if no input is given
    if [[ "$choice" =~ ^[Yy]$ ]]; then  # Check for 'Y' or 'y'
        echo "Installing CasaOS..."
        curl -fsSL https://get.casaos.io | sudo bash
    else
        echo "Skipping CasaOS installation."
    fi
}

# Main script
# Get the flag from command line argument
FLAG="$1"

# Set programs to install based on installation mode
case "$FLAG" in
    "-d")
        installation_mode="desktop"
        echo -e "\033[33mSelected flag: Desktop installation\033[0m"  # Yellow for flag selection
        install_desktop_programs
        ;;
    "-s")
        installation_mode="server"
        echo -e "\033[33mSelected flag: Server installation\033[0m"  # Yellow for flag selection
        install_server_programs
        ;;
    *)
        print_error "Invalid flag. Exiting."
        exit 1
        ;;
esac
