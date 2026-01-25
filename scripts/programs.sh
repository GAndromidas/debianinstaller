#!/bin/bash

# This script handles the installation of various programs based on user selection.
# It defines specific package sets for "Desktop" and "Server" modes.

# Source common functions
if [ -f "$(dirname "$0")/common.sh" ]; then
    source "$(dirname "$0")/common.sh"
else
    echo "Error: common.sh not found." >&2
    exit 1
fi

# --- Package Definitions ---

# A comprehensive list of packages for a full-featured desktop environment.
# GNOME-specific packages are handled conditionally later.
desktop_core_packages=(
    "android-tools-adb"
    "android-tools-fastboot"
    "bat"
    "bleachbit"
    "btop"
    "cmatrix"
    "cpufrequtils" # CLI tool for CPU scaling
    "dosfstools"
    "duf"
    "ffmpeg"
    "firefox"
    "fonts-firacode"
    "fonts-liberation"
    "fonts-noto-extra"
    "fwupd"
    "fzf"
    "gnome-disk-utility"
    "gufw" # GUI for UFW
    "hwinfo"
    "inxi"
    "ncdu"
    "net-tools"
    "nmap"
    "python3-pip"
    "samba"
    "sl"
    "speedtest-cli"
    "sshfs"
    "ttf-mscorefonts-installer"
    "unrar"
    "unzip"
    "vlc"
    "wget"
    "xdg-desktop-portal-gtk"
    "zoxide"
)

# A curated list of essential packages for a headless server environment.
server_core_packages=(
    "bat"
    "btop"
    "cmatrix"
    "curl"
    "duf"
    "fwupd"
    "fzf"
    "git"
    "hwinfo"
    "inxi"
    "ncdu"
    "net-tools"
    "nmap"
    "openssh-server"
    "samba"
    "sl"
    "speedtest-cli"
    "sshfs"
    "unrar"
    "unzip"
    "wget"
    "zoxide"
)

# --- Special Installers ---

# Function to download and install Hack Nerd Font from GitHub
install_nerd_fonts() {
    ui_info "Installing Hack Nerd Font for the terminal..."
    local font_name="Hack"
    local font_dir="$HOME/.local/share/fonts"
    local font_url="https://github.com/ryanoasis/nerd-fonts/releases/latest/download/${font_name}.zip"

    if [ "$DRY_RUN" = true ]; then
        ui_info "[DRY-RUN] Would download and install Hack Nerd Font from GitHub."
        return 0
    fi

    # Check if the font files already exist to avoid re-downloading
    if ls "${font_dir}/${font_name}"*NerdFont* >/dev/null 2>&1; then
        ui_success "Hack Nerd Font is already installed."
        return 0
    fi

    ui_info "Downloading Hack Nerd Font..."
    local temp_zip="/tmp/${font_name}.zip"
    if ! wget -q -O "$temp_zip" "$font_url"; then
        ui_error "Failed to download Hack Nerd Font."
        ERRORS+=("Nerd Font download")
        return 1
    fi

    ui_info "Extracting and installing font..."
    mkdir -p "$font_dir"
    if unzip -o "$temp_zip" -d "$font_dir" >/dev/null; then
        rm -f "$temp_zip"
        ui_success "Hack Nerd Font installed successfully."
    else
        ui_error "Failed to extract Hack Nerd Font."
        ERRORS+=("Nerd Font extraction")
        rm -f "$temp_zip"
        return 1
    fi

    ui_info "Updating font cache..."
    fc-cache -fv >/dev/null
}

install_docker() {
    echo ""
    read -rp "Install Docker Engine? [Y/n]: " response
    if [[ -n "$response" && ! "$response" =~ ^[Yy]$ ]]; then
        ui_warn "Skipping Docker installation."
        return 1
    fi

    ui_info "Installing Docker..."
    apt_install "docker.io"
    if command -v docker >/dev/null 2>&1 || [ "$DRY_RUN" = true ]; then
        ui_info "Adding current user to the 'docker' group..."
        if [ "$DRY_RUN" = false ]; then
            sudo usermod -aG docker "$USER"
            ui_success "User added to docker group. You may need to log out and back in for this to take effect."
        else
            ui_info "[DRY-RUN] Would add user $USER to docker group."
        fi
        ui_info "Enabling Docker service..."
        if [ "$DRY_RUN" = false ]; then
            sudo systemctl enable --now docker
        fi
        ui_success "Docker service enabled and started."
        return 0
    else
        ui_error "Docker installation failed."
        ERRORS+=("Docker installation")
        return 1
    fi
}

install_portainer() {
    echo ""
    read -rp "Install Portainer for Docker management? [Y/n]: " response
    if [[ -n "$response" && ! "$response" =~ ^[Yy]$ ]]; then
        ui_warn "Skipping Portainer installation."
        return
    fi

    ui_info "Installing Portainer..."
    if [ "$DRY_RUN" = true ]; then
        ui_info "[DRY-RUN] Would run 'docker volume create portainer_data' and 'docker run ... portainer/portainer-ce:latest'."
        return
    fi

    ui_info "Creating Docker volume for Portainer data..."
    if sudo docker volume create portainer_data &>/dev/null; then
        ui_success "Created Docker volume for Portainer data."
    else
        ui_error "Failed to create Docker volume for Portainer."
        ERRORS+=("Portainer volume creation")
        return
    fi

    ui_info "Starting Portainer container..."
    if sudo docker run -d -p 8000:8000 -p 9443:9443 --name=portainer --restart=always -v /var/run/docker.sock:/var/run/docker.sock -v portainer_data:/data portainer/portainer-ce:latest &>/dev/null; then
        ui_success "Portainer container is running."
        ui_info "You can access Portainer at https://<your-server-ip>:9443"
    else
        ui_error "Failed to start the Portainer container."
        ERRORS+=("Portainer container start")
    fi
}

# Function to install desktop-specific Flatpak applications
install_flatpak_apps() {
    if ! command -v flatpak >/dev/null 2>&1; then
        ui_warn "Flatpak command not found. Skipping Flatpak app installations."
        return
    fi

    # Conditionally install Extensions Manager if running in a GNOME environment
    if [[ "${XDG_CURRENT_DESKTOP}" == *"GNOME"* ]]; then
        ui_info "GNOME desktop detected. Installing Extensions Manager from Flatpak..."
        if [ "$DRY_RUN" = true ]; then
            ui_info "[DRY-RUN] Would install 'com.mattjakeman.ExtensionManager' from Flathub."
            return
        fi

        if sudo flatpak install -y flathub com.mattjakeman.ExtensionManager; then
            ui_success "Extensions Manager installed successfully."
        else
            ui_error "Failed to install Extensions Manager from Flatpak."
            ERRORS+=("Flatpak Extensions Manager install")
        fi
    fi
}


# --- Installation Mode Handlers ---

run_desktop_install() {
    ui_info "Installing core desktop packages..."
    # Handle special EULA for MS Core Fonts
    if [[ " ${desktop_core_packages[*]} " =~ " ttf-mscorefonts-installer " ]]; then
        ui_info "Accepting EULA for Microsoft Core Fonts..."
        if [ "$DRY_RUN" = false ]; then
            echo ttf-mscorefonts-installer msttcorefonts/accepted-mscorefonts-eula select true | sudo debconf-set-selections
        fi
    fi
    apt_install "${desktop_core_packages[@]}"

    # Conditionally install GNOME Tweaks if running in a GNOME environment
    if [[ "${XDG_CURRENT_DESKTOP}" == *"GNOME"* ]]; then
        ui_info "GNOME desktop detected. Installing GNOME Tweaks..."
        apt_install "gnome-tweaks"
    fi

    install_nerd_fonts
    install_flatpak_apps
}

run_server_install() {
    ui_info "Installing core server packages..."
    apt_install "${server_core_packages[@]}"
    install_nerd_fonts

    if install_docker; then
        install_portainer
    fi
}

# --- Main Execution ---

# Check if INSTALL_MODE is set from the main script
if [ -z "$INSTALL_MODE" ]; then
    ui_error "INSTALL_MODE variable is not set. Cannot determine which programs to install."
    exit 1
fi

case "$INSTALL_MODE" in
    desktop)
        run_desktop_install
        ;;
    server)
        run_server_install
        ;;
    *)
        ui_error "Invalid installation mode: '$INSTALL_MODE'. Please use 'desktop' or 'server'."
        exit 1
        ;;
esac

ui_success "Program installation phase completed."
