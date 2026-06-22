#!/bin/bash

# This script sets up the system for gaming by installing essential tools
# and applications like Steam, Faugus Launcher, and performance enhancement utilities.

# Source common.sh is already sourced by the main install.sh

# --- Function to install Discord ---
install_discord() {
    if command -v discord >/dev/null 2>&1; then
        ui_success "Discord is already installed."
        return 0
    fi

    ui_info "Attempting to install Discord..."
    if [ "$DRY_RUN" = true ]; then
        ui_info "[DRY-RUN] Would download and install Discord .deb package."
        return 0
    fi

    local arch
    case "$(uname -m)" in
        "x86_64") arch="amd64" ;;
        "aarch64") arch="arm64" ;;
        *)
            ui_warn "Discord does not provide official builds for $(uname -m). Skipping."
            return 1
            ;;
    esac

    local discord_deb="/tmp/discord.deb"
    local discord_url="https://discord.com/api/download?platform=linux&format=deb"

    ui_info "Downloading Discord for ${arch}..."
    if ! wget -q -O "$discord_deb" "$discord_url"; then
        ui_error "Failed to download Discord .deb package."
        ERRORS+=("Discord download")
        return 1
    fi

    ui_info "Installing Discord package..."
    # The initial dpkg command is expected to fail on dependencies.
    sudo dpkg -i "$discord_deb" &>/dev/null || true
    # `apt-get -f install` fixes the broken dependencies.
    if sudo apt-get install -f -y -qq; then
        ui_success "Discord installed successfully."
        INSTALLED_PACKAGES+=("discord")
    else
        ui_error "Failed to install Discord from .deb package."
        ERRORS+=("Discord .deb install")
    fi

    rm -f "$discord_deb"
}

# --- Function to configure MangoHud ---
configure_mangohud() {
    ui_info "Configuring MangoHud..."
    local config_source="$SCRIPT_DIR/configs/MangoHud.conf"
    local config_dest_dir="$HOME/.config/MangoHud"

    if [ ! -f "$config_source" ]; then
        ui_warn "MangoHud.conf not found in configs directory. Skipping."
        return
    fi

    if [ "$DRY_RUN" = true ]; then
        ui_info "[DRY-RUN] Would copy MangoHud config to $config_dest_dir."
        return
    fi

    mkdir -p "$config_dest_dir"
    if cp "$config_source" "$config_dest_dir/MangoHud.conf"; then
        ui_success "MangoHud configuration copied."
    else
        ui_error "Failed to copy MangoHud configuration."
        ERRORS+=("MangoHud config copy")
    fi
}

# --- Function to install Faugus Launcher from Flatpak ---
install_faugus_launcher() {
    if flatpak list | grep -q "io.github.Faugus.faugus-launcher"; then
        ui_success "Faugus Launcher is already installed."
        return 0
    fi

    ui_info "Installing Faugus Launcher from Flatpak..."
    if [ "$DRY_RUN" = true ]; then
        ui_info "[DRY-RUN] Would install Faugus Launcher from Flatpak."
        return 0
    fi

    # Add Flathub if not already added
    if ! flatpak remotes | grep -q "flathub"; then
        ui_info "Adding Flathub remote..."
        flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo
    fi

    # Install Faugus Launcher
    if flatpak install -y flathub io.github.Faugus.faugus-launcher; then
        ui_success "Faugus Launcher installed successfully."
        INSTALLED_PACKAGES+=("Faugus Launcher")
    else
        ui_error "Failed to install Faugus Launcher."
        ERRORS+=("Faugus Launcher installation")
        return 1
    fi
}

# --- Function to install ProtonPlus from Flatpak ---
install_protonplus() {
    if ! command -v flatpak >/dev/null 2>&1; then
        ui_warn "Flatpak command not found. Skipping ProtonPlus installation."
        return
    fi

    ui_info "Installing ProtonPlus (Proton-GE manager) from Flatpak..."
    if [ "$DRY_RUN" = true ]; then
        ui_info "[DRY-RUN] Would install 'com.vysp3r.ProtonPlus' from Flathub."
        return
    fi

    if sudo flatpak install -y flathub com.vysp3r.ProtonPlus; then
        ui_success "ProtonPlus installed successfully."
    else
        ui_error "Failed to install ProtonPlus from Flatpak."
        ERRORS+=("Flatpak ProtonPlus install")
    fi
}


# --- Main Execution ---

step "Gaming Mode Setup"
simple_banner "Gaming Mode"

description="This includes popular tools like Steam, Discord, Wine, GameMode, MangoHud, Faugus Launcher, and more."

if ! gum_confirm "Enable Gaming Mode?" "$description"; then
    ui_info "Gaming Mode skipped."
    return 0
fi


ui_info "This will include Steam, Faugus Launcher, GameMode, MangoHud, and more."

# Define the list of essential gaming packages
# Try 'steam' first, fall back to 'steam-installer' for cross-distro compatibility
gaming_packages=(
    "gamemode"
    "mangohud"
    "wine"
    "vulkan-tools"
)

# Install the packages using the common function
apt_install "${gaming_packages[@]}"

# Install steam with cross-distro fallback
if ! dpkg -l steam 2>/dev/null | grep -q "^ii"; then
    if is_package_available "steam"; then
        apt_install steam
    elif is_package_available "steam-installer"; then
        apt_install steam-installer
    else
        ui_warn "Steam not available in repositories. You can install it manually from https://store.steampowered.com"
    fi
fi

# Install Discord separately as it's often not in repos
install_discord

# Install Faugus Launcher from Flatpak
install_faugus_launcher

# Install ProtonPlus from Flatpak
install_protonplus

# Configure MangoHud
configure_mangohud

ui_success "Gaming Mode setup completed."
