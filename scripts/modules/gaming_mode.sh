#!/bin/bash

# Gaming Mode — reads package lists from configs/gaming_mode.yaml

# Source config.sh for YAML parsing (if not already loaded via install.sh)
if ! declare -f has_yq >/dev/null 2>&1; then
    source "$SCRIPT_DIR/lib/config.sh"
fi

GAMING_YAML="$CONFIGS_DIR/gaming_mode.yaml"

# ===== Globals =====
GAMING_ERRORS=()
GAMING_INSTALLED=()
apt_gaming_packages=()
flatpak_gaming_packages=()

# ===== YAML Loading =====
load_package_lists() {
    if [[ ! -f "$GAMING_YAML" ]]; then
        log_error "Gaming mode configuration file not found: $GAMING_YAML"
        return 1
    fi

    local temp_desc=()
    read_yaml_packages_with_desc "$GAMING_YAML" ".apt.packages" apt_gaming_packages temp_desc
    read_yaml_packages_with_desc "$GAMING_YAML" ".flatpak.apps" flatpak_gaming_packages temp_desc
    return 0
}

# ===== Installation Functions =====

install_apt_packages() {
    if [[ ${#apt_gaming_packages[@]} -eq 0 ]]; then
        ui_info "No apt packages for gaming mode to install."
        return
    fi
    ui_info "Installing ${#apt_gaming_packages[@]} apt packages for gaming..."

    local available=()
    for pkg in "${apt_gaming_packages[@]}"; do
        if is_package_available "$pkg"; then
            available+=("$pkg")
        else
            ui_warn "Package '$pkg' not available in repositories (skipping)"
        fi
    done

    if [[ ${#available[@]} -gt 0 ]]; then
        install_package_smart "${available[@]}"
    fi
}

install_flatpak_packages() {
    if ! command -v flatpak >/dev/null 2>&1; then
        ui_warn "flatpak is not installed. Skipping gaming Flatpaks."
        return
    fi

    if ! sudo flatpak remote-list 2>/dev/null | grep -q flathub; then
        if [ "$DRY_RUN" = true ]; then
            ui_info "[DRY-RUN] Would add the Flathub remote."
        else
            step "Adding Flathub remote"
            sudo flatpak remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo
        fi
    fi

    if [[ ${#flatpak_gaming_packages[@]} -eq 0 ]]; then
        ui_info "No Flatpak applications for gaming mode to install."
        return
    fi
    ui_info "Installing ${#flatpak_gaming_packages[@]} Flatpak applications for gaming..."

    local g_install=()
    for pkg in "${flatpak_gaming_packages[@]}"; do
        if [ "$DRY_RUN" = true ]; then
            ui_info "[DRY-RUN] Would install Flatpak: $pkg"
            continue
        fi
        # Avoid Discord double-install: install_discord() already installs
        # the native .deb — skip the Flatpak if a Discord binary exists.
        if [[ "$pkg" == "com.discordapp.Discord" ]] && command -v discord >/dev/null 2>&1; then
            ui_info "Discord already installed via .deb — skipping Flatpak duplicate."
            continue
        fi
        g_install+=("$pkg")
    done
    if [ ${#g_install[@]} -gt 0 ]; then
        local _g_out="" _ok_pkgs=()
        if _g_out=$(sudo flatpak install -y flathub "${g_install[@]}" 2>&1); then
            for pkg in "${g_install[@]}"; do GAMING_INSTALLED+=("$pkg (Flatpak)"); done
            ui_success "Gaming Flatpaks installed successfully (batch)."
            return
        fi
        printf '\n[BATCH FAILURE] flatpak install (gaming)\n%s\n' "$_g_out" >> "$INSTALL_LOG" 2>/dev/null || true
        ui_warn "Batch Flatpak install failed - falling back per-app"
        for pkg in "${g_install[@]}"; do
            # The batch may have partially succeeded; probe per app.
            if sudo flatpak list --app 2>/dev/null | grep -qx "$pkg/none" || \
               sudo flatpak install -y flathub "$pkg" >/dev/null 2>&1; then
                ui_success "Flatpak $pkg installed successfully."
                GAMING_INSTALLED+=("$pkg (Flatpak)")
            else
                ui_error "Failed to install Flatpak: $pkg"
                GAMING_ERRORS+=("$pkg (Flatpak)")
            fi
        done
    fi
}

install_discord() {
    if command -v discord >/dev/null 2>&1; then
        ui_success "Discord is already installed."; return 0
    fi

    ui_info "Attempting to install Discord..."
    if [ "$DRY_RUN" = true ]; then
        ui_info "[DRY-RUN] Would download and install Discord .deb package."; return 0
    fi

    local arch
    case "$(uname -m)" in
        "x86_64") arch="amd64" ;;
        "aarch64") arch="arm64" ;;
        *) ui_warn "Discord does not provide official builds for $(uname -m). Skipping."; return 1 ;;
    esac

    local discord_deb="/tmp/discord.deb"
    local discord_url="https://discord.com/api/download?platform=linux&format=deb"

    ui_info "Downloading Discord for ${arch}..."
    if ! wget -q -O "$discord_deb" "$discord_url"; then
        ui_error "Failed to download Discord .deb package."
        GAMING_ERRORS+=("Discord download")
        return 1
    fi

    # Validate the artifact BEFORE installing: a 5xx/HTML error page saved
    # as .deb previously dpkg-failed silently, then `apt-get -f` succeeded
    # (nothing broken) and the file counted as installed.
    if ! dpkg-deb -I "$discord_deb" >/dev/null 2>&1; then
        ui_error "Downloaded Discord artifact is not a valid .deb package (skipped)."
        GAMING_ERRORS+=("Discord download invalid")
        rm -f "$discord_deb"
        return 1
    fi
    ui_info "Installing Discord package..."
    sudo dpkg -i "$discord_deb" &>/dev/null || true
    if sudo env NEEDRESTART_MODE=a DEBIAN_FRONTEND=noninteractive apt-get install -f -y -qq >/dev/null 2>&1; then
        if dpkg-query -W -f='${Status}' "discord" 2>/dev/null | grep -q "ok installed"; then
            ui_success "Discord installed successfully."
            GAMING_INSTALLED+=("discord")
        else
            ui_error "apt-get -f succeeded but Discord is not installed - check the manual download."
            GAMING_ERRORS+=("Discord .deb install")
        fi
    else
        ui_error "Failed to install Discord from .deb package."
        GAMING_ERRORS+=("Discord .deb install")
    fi
    rm -f "$discord_deb"
}

# ===== Configuration Functions =====

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
        GAMING_ERRORS+=("MangoHud config copy")
    fi
}

# ===== Main Execution =====

step "Gaming Mode Setup"
simple_banner "Gaming Mode"

ui_info "Installing gaming packages and optimizations (Discord, Steam, GameMode, MangoHud, Heroic Games Launcher)..."

if ! load_package_lists; then
    return 1
fi

install_apt_packages

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

# Install Discord separately (not in repos)
install_discord

install_flatpak_packages
configure_mangohud

ui_success "Gaming Mode setup completed."
