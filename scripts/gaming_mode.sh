#!/bin/bash

# This script sets up the system for gaming by installing essential tools
# and applications like Steam, Lutris, and performance enhancement utilities.

# Source common functions
if [ -f "$(dirname "$0")/common.sh" ]; then
    source "$(dirname "$0")/common.sh"
else
    echo "Error: common.sh not found." >&2
    exit 1
fi

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
    local config_source="$(dirname "$0")/../configs/MangoHud.conf"
    local config_dest_dir="$HOME/.config/MangoHud"

    if [ ! -f "$config_source" ]; then
        ui_warn "MangoHud.conf not found in configs directory. Skipping."
        return
    fi

    if [ -f "$config_dest_dir/MangoHud.conf" ]; then
        ui_warn "Existing 'MangoHud.conf' found. Skipping to preserve your settings."
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

# Prompt the user to install gaming tools using a standard text prompt
echo ""
ui_info "Optional: Install Gaming Mode?"
read -rp "This will install Steam, Lutris, Discord, and other related tools. [Y/n]: " response
if [[ -n "$response" && ! "$response" =~ ^[Yy]$ ]]; then
    ui_warn "Gaming Mode setup skipped by user."
    exit 0
fi


ui_info "This will include Steam, Lutris, GameMode, MangoHud, and more."

# Define the list of essential gaming packages
# Including both 'steam' and 'steam-installer' makes it robust across different distro repos.
gaming_packages=(
    "steam"
    "steam-installer"
    "lutris"
    "gamemode"
    "mangohud"
    "obs-studio"
    "wine"
    "winetricks"
    "vulkan-tools"
)

# Install the packages using the common function
apt_install "${gaming_packages[@]}"

# Install Discord separately as it's often not in repos
install_discord

# Install ProtonPlus from Flatpak
install_protonplus

# Configure MangoHud
configure_mangohud

ui_success "Gaming Mode setup completed."
