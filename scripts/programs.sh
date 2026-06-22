#!/bin/bash

# This script handles the installation of various programs based on user selection.
# It defines specific package sets for "Desktop" and "Server" modes.

# Source common.sh is already sourced by the main install.sh

# Ensure distribution is detected and variables are available
if [ -z "$DISTRO_NAME" ]; then
    detect_distribution
fi

# --- Package Definitions ---

# A comprehensive list of packages for a full-featured desktop environment.
# Some packages are distribution-specific and will be filtered by install_package_smart()
get_desktop_packages() {
    local packages=(
        "android-tools-adb"
        "android-tools-fastboot"
        "bat"
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
        "wmctrl" # Window management tool for shortcuts
        "unrar"
        "unzip"
        "vlc"
        "wget"
        "xdg-desktop-portal-gtk"
        "zoxide"
    )
    
    # Add distribution-specific packages
    if [ "$IS_UBUNTU" = true ] || [ "$IS_MINT" = true ] || [ "$IS_ZORIN" = true ]; then
        packages+=("ubuntu-restricted-extras")
    fi
    
    if [ "$IS_DEBIAN" = true ]; then
        packages+=("firmware-linux" "firmware-linux-nonfree")
    fi
    
    # Handle Pop!_OS specific packages
    if [ "$IS_POP_OS" = true ]; then
        packages+=("pop-shell")
        
        # For Pop!_OS with Cosmic DE, add Cosmic-specific packages if available
        if [ "$XDG_CURRENT_DESKTOP" = "COSMIC" ]; then
            ui_info "Pop!_OS Cosmic detected - adding Cosmic-specific packages"
            # Add Cosmic-specific packages when they become available
            if is_package_available "cosmic-session"; then
                packages+=("cosmic-session")
            fi
            if is_package_available "cosmic-term"; then
                packages+=("cosmic-term")
            fi
            if is_package_available "cosmic-settings"; then
                packages+=("cosmic-settings")
            fi
        fi
    fi
    
    echo "${packages[@]}"
}

# A curated list of essential packages for a headless server environment.
get_server_packages() {
    local packages=(
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
    
    # Add distribution-specific server packages
    if [ "$IS_DEBIAN" = true ]; then
        packages+=("firmware-linux" "firmware-linux-nonfree")
    fi
    
    echo "${packages[@]}"
}

# --- Fallback Installation Functions ---

# Function to install eza (modern ls replacement) via GitHub release if not in repos
install_eza_fallback() {
    ui_info "Installing eza via GitHub release (fallback method)..."
    
    if command -v eza >/dev/null 2>&1; then
        ui_success "eza is already installed"
        return 0
    fi
    
    if [ "$DRY_RUN" = true ]; then
        ui_info "[DRY-RUN] Would install eza via GitHub release"
        return 0
    fi
    
    local latest_version
    latest_version=$(curl -s "https://api.github.com/repos/eza-community/eza/releases/latest" | grep -Po '"tag_name": "\K.*?(?=")' || echo "v0.18.0")
    
    if [ -z "$latest_version" ]; then
        ui_warn "Could not fetch latest eza version, using fallback version"
        latest_version="v0.18.0"
    fi
    
    # Detect architecture
    local arch
    arch=$(uname -m)
    case "$arch" in
        x86_64) arch="x86_64-unknown-linux-gnu" ;;
        aarch64) arch="aarch64-unknown-linux-gnu" ;;
        *) 
            ui_warn "Unsupported architecture for eza: $arch"
            return 1
            ;;
    esac
    
    local download_url="https://github.com/eza-community/eza/releases/download/${latest_version}/eza_${arch#v}.tar.gz"
    local temp_dir="/tmp/eza_install"
    
    ui_info "Downloading eza $latest_version for $arch..."
    
    # Create temp directory
    mkdir -p "$temp_dir"
    
    # Download and extract
    if curl -L "$download_url" -o "$temp_dir/eza.tar.gz" && \
       tar -xzf "$temp_dir/eza.tar.gz" -C "$temp_dir" && \
       sudo mv "$temp_dir/eza" /usr/local/bin/ && \
       sudo chmod +x /usr/local/bin/eza; then
        ui_success "eza installed successfully via GitHub release"
        INSTALLED_PACKAGES+=("eza")
    else
        ui_error "Failed to install eza via GitHub release"
        ERRORS+=("eza fallback install")
        return 1
    fi
    
    # Cleanup
    rm -rf "$temp_dir"
}

# Function to install fastfetch via GitHub release if not in repos
install_fastfetch_fallback() {
    ui_info "Installing fastfetch via GitHub release (fallback method)..."
    
    if command -v fastfetch >/dev/null 2>&1; then
        ui_success "fastfetch is already installed"
        return 0
    fi
    
    if [ "$DRY_RUN" = true ]; then
        ui_info "[DRY-RUN] Would install fastfetch via GitHub release"
        return 0
    fi
    
    local latest_version
    latest_version=$(curl -s "https://api.github.com/repos/fastfetch-cli/fastfetch/releases/latest" | grep -Po '"tag_name": "\K.*?(?=")' || echo "2.12.2")
    
    if [ -z "$latest_version" ]; then
        ui_warn "Could not fetch latest fastfetch version, using fallback version"
        latest_version="2.12.2"
    fi
    
    # Detect architecture
    local arch
    arch=$(uname -m)
    case "$arch" in
        x86_64) arch="x86_64" ;;
        aarch64) arch="aarch64" ;;
        *) 
            ui_warn "Unsupported architecture for fastfetch: $arch"
            return 1
            ;;
    esac
    
    local download_url="https://github.com/fastfetch-cli/fastfetch/releases/download/${latest_version}/fastfetch-linux-${arch}.tar.gz"
    local temp_dir="/tmp/fastfetch_install"
    
    ui_info "Downloading fastfetch $latest_version for $arch..."
    
    # Create temp directory
    mkdir -p "$temp_dir"
    
    # Download and extract
    if curl -L "$download_url" -o "$temp_dir/fastfetch.tar.gz" && \
       tar -xzf "$temp_dir/fastfetch.tar.gz" -C "$temp_dir" && \
       sudo mv "$temp_dir/usr/bin/fastfetch" /usr/local/bin/ && \
       sudo chmod +x /usr/local/bin/fastfetch; then
        ui_success "fastfetch installed successfully via GitHub release"
        INSTALLED_PACKAGES+=("fastfetch")
    else
        ui_error "Failed to install fastfetch via GitHub release"
        ERRORS+=("fastfetch fallback install")
        return 1
    fi
    
    # Cleanup
    rm -rf "$temp_dir"
}

# Function to install ripgrep (rg) via GitHub release if not in repos
install_ripgrep_fallback() {
    ui_info "Installing ripgrep via GitHub release (fallback method)..."
    
    if command -v rg >/dev/null 2>&1; then
        ui_success "ripgrep is already installed"
        return 0
    fi
    
    if [ "$DRY_RUN" = true ]; then
        ui_info "[DRY-RUN] Would install ripgrep via GitHub release"
        return 0
    fi
    
    local latest_version
    latest_version=$(curl -s "https://api.github.com/repos/BurntSushi/ripgrep/releases/latest" | grep -Po '"tag_name": "\K.*?(?=")' || echo "14.1.0")
    
    if [ -z "$latest_version" ]; then
        ui_warn "Could not fetch latest ripgrep version, using fallback version"
        latest_version="14.1.0"
    fi
    
    # Detect architecture
    local arch
    arch=$(uname -m)
    case "$arch" in
        x86_64) arch="x86_64-unknown-linux-musl" ;;
        aarch64) arch="aarch64-unknown-linux-musl" ;;
        *) 
            ui_warn "Unsupported architecture for ripgrep: $arch"
            return 1
            ;;
    esac
    
    local download_url="https://github.com/BurntSushi/ripgrep/releases/download/${latest_version}/ripgrep-${arch}.tar.gz"
    local temp_dir="/tmp/ripgrep_install"
    
    ui_info "Downloading ripgrep $latest_version for $arch..."
    
    # Create temp directory
    mkdir -p "$temp_dir"
    
    # Download and extract
    if curl -L "$download_url" -o "$temp_dir/ripgrep.tar.gz" && \
       tar -xzf "$temp_dir/ripgrep.tar.gz" -C "$temp_dir" && \
       sudo mv "$temp_dir/rg" /usr/local/bin/ && \
       sudo chmod +x /usr/local/bin/rg; then
        ui_success "ripgrep installed successfully via GitHub release"
        INSTALLED_PACKAGES+=("ripgrep")
    else
        ui_error "Failed to install ripgrep via GitHub release"
        ERRORS+=("ripgrep fallback install")
        return 1
    fi
    
    # Cleanup
    rm -rf "$temp_dir"
}

# Function to install fd (find replacement) via GitHub release if not in repos
install_fd_fallback() {
    ui_info "Installing fd via GitHub release (fallback method)..."
    
    if command -v fd >/dev/null 2>&1; then
        ui_success "fd is already installed"
        return 0
    fi
    
    if [ "$DRY_RUN" = true ]; then
        ui_info "[DRY-RUN] Would install fd via GitHub release"
        return 0
    fi
    
    local latest_version
    latest_version=$(curl -s "https://api.github.com/repos/sharkdp/fd/releases/latest" | grep -Po '"tag_name": "\K.*?(?=")' || echo "v9.0.0")
    
    if [ -z "$latest_version" ]; then
        ui_warn "Could not fetch latest fd version, using fallback version"
        latest_version="v9.0.0"
    fi
    
    # Detect architecture
    local arch
    arch=$(uname -m)
    case "$arch" in
        x86_64) arch="x86_64-unknown-linux-gnu" ;;
        aarch64) arch="aarch64-unknown-linux-gnu" ;;
        *) 
            ui_warn "Unsupported architecture for fd: $arch"
            return 1
            ;;
    esac
    
    local download_url="https://github.com/sharkdp/fd/releases/download/${latest_version}/fd-${latest_version#v}-${arch}.tar.gz"
    local temp_dir="/tmp/fd_install"
    
    ui_info "Downloading fd $latest_version for $arch..."
    
    # Create temp directory
    mkdir -p "$temp_dir"
    
    # Download and extract
    if curl -L "$download_url" -o "$temp_dir/fd.tar.gz" && \
       tar -xzf "$temp_dir/fd.tar.gz" -C "$temp_dir" && \
       sudo mv "$temp_dir/fd-${latest_version#v}-${arch}/fd" /usr/local/bin/ && \
       sudo chmod +x /usr/local/bin/fd; then
        ui_success "fd installed successfully via GitHub release"
        INSTALLED_PACKAGES+=("fd")
    else
        ui_error "Failed to install fd via GitHub release"
        ERRORS+=("fd fallback install")
        return 1
    fi
    
    # Cleanup
    rm -rf "$temp_dir"
}

# Function to install ucaresystem-core from GitHub
install_ucaresystem_core() {
    ui_info "Installing ucaresystem-core from GitHub..."
    
    if [ "$DRY_RUN" = true ]; then
        ui_info "[DRY-RUN] Would install ucaresystem-core from GitHub."
        return 0
    fi
    
    # Get latest release info
    local latest_release=$(curl -s "https://api.github.com/repos/Utappia/uCareSystem/releases/latest" | grep -o '"tag_name": "[^"]*' | cut -d'"' -f4)
    
    if [ -z "$latest_release" ]; then
        ui_error "Failed to fetch latest ucaresystem-core release."
        return 1
    fi
    
    ui_info "Downloading ucaresystem-core ${latest_release}..."
    
    # Use the .deb package for Ubuntu/Debian systems
    local version_number="${latest_release#v}"
    local download_url="https://github.com/Utappia/uCareSystem/releases/download/${latest_release}/ucaresystem-core_${version_number}_all.deb"
    local temp_deb="/tmp/ucaresystem-core_${version_number}_all.deb"
    
    # Download and install the .deb package
    if curl -L "$download_url" -o "$temp_deb" && \
       [ -f "$temp_deb" ] && \
       sudo dpkg -i "$temp_deb" 2>/dev/null; then
        ui_success "ucaresystem-core installed successfully."
        rm -f "$temp_deb"
        return 0
    else
        ui_error "Failed to install ucaresystem-core."
        rm -f "$temp_deb"
        return 1
    fi
}

# Function to install packages with fallback support
install_with_fallback() {
    local package_name="$1"
    local fallback_function="$2"
    
    # First try to install from repository
    if is_package_available "$package_name"; then
        apt_install "$package_name"
        return 0
    else
        ui_warn "Package '$package_name' not available in repositories, trying fallback method..."
        $fallback_function
        return $?
    fi
}

# --- Special Installers ---

# Function to download and install Hack Nerd Font from GitHub
install_nerd_fonts() {
    ui_info "Installing Hack Nerd Font for the terminal..."
    local font_name="Hack"
    local font_dir="$HOME/.local/share/fonts"
    local font_url="https://github.com/ryanoasis/nerd-fonts/releases/latest/download/${font_name}.zip"

    if [ "$DRY_RUN" = true ]; then
        ui_info "[DRY-RUN] Would install Hack Nerd Font."
        return 0
    fi

    # Create font directory if it doesn't exist
    mkdir -p "$font_dir"

    # Download font
    if wget -q --show-progress "$font_url" -O "/tmp/${font_name}.zip"; then
        # Extract font
        if unzip -q "/tmp/${font_name}.zip" -d "$font_dir"; then
            # Remove Windows-compatible fonts (keep only *.ttf and *.otf)
            find "$font_dir" -name "*Windows*" -delete
            # Rebuild font cache
            fc-cache -fv >/dev/null 2>&1
            ui_success "Hack Nerd Font installed successfully."
        else
            ui_error "Failed to extract Hack Nerd Font."
            ERRORS+=("Nerd Font extraction")
        fi
        # Cleanup
        rm -f "/tmp/${font_name}.zip"
    else
        ui_error "Failed to download Hack Nerd Font."
        ERRORS+=("Nerd Font download")
    fi
}

# Function to add repository GPG keys with distribution-specific handling
add_repository_key() {
    local key_url="$1"
    local key_name="$2"
    local key_path="$3"
    
    if [ "$DRY_RUN" = true ]; then
        ui_info "[DRY-RUN] Would add GPG key: $key_name"
        return 0
    fi
    
    ui_info "Adding GPG key for $key_name..."
    
    # Use different methods based on distribution
    if [ "$IS_DEBIAN" = true ]; then
        # Debian prefers /usr/share/keyrings directory
        if curl -fsSL "$key_url" | sudo gpg --dearmor -o "$key_path"; then
            ui_success "GPG key added successfully for $key_name"
            return 0
        fi
    elif [ "$IS_UBUNTU" = true ] || [ "$IS_MINT" = true ] || [ "$IS_ZORIN" = true ]; then
        # Ubuntu-based distributions
        if curl -fsSL "$key_url" | sudo gpg --dearmor -o "$key_path"; then
            ui_success "GPG key added successfully for $key_name"
            return 0
        fi
    elif [ "$IS_POP_OS" = true ]; then
        # Pop!_OS specific handling
        if curl -fsSL "$key_url" | sudo gpg --dearmor -o "$key_path"; then
            ui_success "GPG key added successfully for $key_name"
            return 0
        fi
    else
        # Fallback method
        if curl -fsSL "$key_url" | sudo apt-key add - >/dev/null 2>&1; then
            ui_success "GPG key added successfully for $key_name (legacy method)"
            return 0
        fi
    fi
    
    ui_error "Failed to add GPG key for $key_name"
    ERRORS+=("GPG key addition failed: $key_name")
    return 1
}

# Function to get distribution-specific Docker repository
get_docker_repository() {
    if [ "$IS_POP_OS" = true ]; then
        # Pop!_OS has its own Docker repository
        echo "https://download.docker.com/linux/pop-os"
        return 0
    elif [ "$IS_UBUNTU" = true ]; then
        echo "https://download.docker.com/linux/ubuntu"
        return 0
    elif [ "$IS_MINT" = true ]; then
        # Linux Mint can use Ubuntu repository but with proper handling
        echo "https://download.docker.com/linux/ubuntu"
        return 0
    elif [ "$IS_ZORIN" = true ]; then
        # Zorin OS uses Ubuntu repository
        echo "https://download.docker.com/linux/ubuntu"
        return 0
    else
        # Default to Ubuntu for other Debian-based
        echo "https://download.docker.com/linux/ubuntu"
        return 0
    fi
}

# Function to install Docker
install_docker() {
    if command -v docker >/dev/null 2>&1; then
        ui_success "Docker is already installed."
        return 0
    fi

    ui_info "Installing Docker..."
    if [ "$DRY_RUN" = true ]; then
        ui_info "[DRY-RUN] Would install Docker."
        return 0
    fi

    # Get distribution-specific repository and key
    local docker_repo
    docker_repo=$(get_docker_repository)
    local docker_key_url="${docker_repo}/gpg"
    local docker_key_path="/usr/share/keyrings/docker-archive-keyring.gpg"
    
    # Add Docker's official GPG key using distribution-specific method
    if add_repository_key "$docker_key_url" "Docker" "$docker_key_path"; then
        # Get the Ubuntu codename, with fallback for newer releases
        local ubuntu_codename
        ubuntu_codename=$(lsb_release -cs 2>/dev/null || echo "noble")
        
        # Special handling for Ubuntu 26.04+ if Docker doesn't support codename yet
        if [ "$ubuntu_codename" = "resolute" ]; then
            ui_info "Ubuntu 26.04 'resolute' detected - checking Docker repository support..."
            # Try to check if Docker supports this codename by testing repository
            if curl -fsSL "${docker_repo}/dists/$ubuntu_codename/Release" >/dev/null 2>&1; then
                ui_success "Docker repository supports Ubuntu 26.04 'resolute'"
            else
                ui_warn "Docker repository doesn't yet support Ubuntu 26.04, using Ubuntu 24.04 'noble' as fallback"
                ubuntu_codename="noble"
            fi
        fi
        
        # Add Docker repository with distribution-specific handling
        echo \
            "deb [arch=$(dpkg --print-architecture) signed-by=$docker_key_path] $docker_repo \
            $ubuntu_codename stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
        sudo apt-get update
        apt_install docker-ce docker-ce-cli containerd.io
        sudo usermod -aG docker "$USER"
        ui_success "Docker installed successfully. Please log out and log back in to use Docker without sudo."
    else
        ui_error "Failed to add Docker GPG key."
        ERRORS+=("Docker GPG key")
    fi
}

# Function to install Portainer (Docker management UI)
install_portainer() {
    if [ "$DRY_RUN" = true ]; then
        ui_info "[DRY-RUN] Would create Portainer container."
        return 0
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
    ui_info "Installing core desktop packages for $DISTRO_NAME $DISTRO_VERSION..."
    
    # Get distribution-specific package list
    local desktop_packages
    read -ra desktop_packages <<< "$(get_desktop_packages)"
    
    # Handle special EULA for MS Core Fonts
    if [[ " ${desktop_packages[*]} " =~ " ttf-mscorefonts-installer " ]]; then
        ui_info "Accepting EULA for Microsoft Core Fonts..."
        if [ "$DRY_RUN" = false ]; then
            echo ttf-mscorefonts-installer msttcorefonts/accepted-mscorefonts-eula select true | sudo debconf-set-selections
        fi
    fi
    
    # Use the smart installer that checks package availability
    install_package_smart "${desktop_packages[@]}"

    # Install eza and fastfetch with fallback support
    install_with_fallback "eza" "install_eza_fallback"
    install_with_fallback "fastfetch" "install_fastfetch_fallback"
    install_with_fallback "ripgrep" "install_ripgrep_fallback"
    install_with_fallback "fd-find" "install_fd_fallback"

    # Install ucaresystem-core from GitHub (always latest version)
    install_ucaresystem_core

    # Conditionally install GNOME Tweaks if running in a GNOME environment
    if [[ "${XDG_CURRENT_DESKTOP}" == *"GNOME"* ]]; then
        ui_info "GNOME desktop detected. Installing GNOME Tweaks..."
        if is_package_available "gnome-tweaks"; then
            apt_install "gnome-tweaks"
        else
            ui_warn "GNOME Tweaks not available on this distribution"
        fi
    fi

    install_nerd_fonts
    install_flatpak_apps
}

run_server_install() {
    ui_info "Installing core server packages for $DISTRO_NAME $DISTRO_VERSION..."
    
    # Get distribution-specific package list
    local server_packages
    read -ra server_packages <<< "$(get_server_packages)"
    
    # Use the smart installer that checks package availability
    install_package_smart "${server_packages[@]}"
    
    # Install eza and fastfetch with fallback support
    install_with_fallback "eza" "install_eza_fallback"
    install_with_fallback "fastfetch" "install_fastfetch_fallback"
    install_with_fallback "ripgrep" "install_ripgrep_fallback"
    install_with_fallback "fd-find" "install_fd_fallback"
    
    # Install ucaresystem-core from GitHub (always latest version)
    install_ucaresystem_core
    
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
