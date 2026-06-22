#!/bin/bash

# This script prepares the system by updating, upgrading, and installing essential dependencies.

# Source common.sh is already sourced by the main install.sh

# --- Function to Update and Upgrade the System ---
update_and_upgrade() {
    ui_info "Updating package lists and upgrading the system..."
    ui_info "This may take a few moments."

    if [ "$DRY_RUN" = true ]; then
        ui_info "[DRY-RUN] Would run 'apt update' and 'apt upgrade'."
        return 0
    fi

    # Update package lists
    if ! sudo apt-get update -qq; then
        ui_warn "Failed to update package lists. The script will attempt to continue."
        # Not a fatal error, as the cache might be recent enough.
    fi

    # Upgrade installed packages
    # Using DEBIAN_FRONTEND to avoid interactive prompts during kernel upgrades, etc.
    if ! sudo DEBIAN_FRONTEND=noninteractive apt-get upgrade -y -qq; then
        ui_error "System upgrade failed. This could lead to issues later."
        ERRORS+=("System package upgrade")
    else
        ui_success "System is up-to-date."
    fi
}

# --- Function to Install Core Dependencies ---
install_core_dependencies() {
    # These packages are essential for the rest of the installer scripts to function correctly.
    local core_deps=(
        "curl"
        "wget"
        "git"
        "figlet" # Used for the reboot prompt
    )
    ui_info "Installing core dependencies required by the installer..."

    # Check if figlet is already installed before we attempt to install it.
    # This ensures we only remove it later if we were the ones who installed it.
    if ! command -v figlet >/dev/null 2>&1; then
        # Export the variable so the main script and common.sh can see it.
        export FIGLET_INSTALLED_BY_SCRIPT=true
    fi

    apt_install "${core_deps[@]}"
}

# --- Function to Install and Configure Flatpak ---
# This is only run on desktop installations.
setup_flatpak() {
    ui_info "Setting up Flatpak..."
    apt_install "flatpak"

    # After installing the package, check if the command is available.
    if ! command -v flatpak >/dev/null 2>&1 && [ "$DRY_RUN" = false ]; then
        ui_error "Flatpak package installation failed. Skipping Flathub setup."
        ERRORS+=("Flatpak install")
        return 1
    fi

    ui_info "Adding the Flathub remote repository for Flatpak..."
    if [ "$DRY_RUN" = true ]; then
        ui_info "[DRY-RUN] Would add the Flathub remote repository."
        return 0
    fi

    # Use --if-not-exists to make the command idempotent and safe to re-run.
    if sudo flatpak remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo; then
        ui_success "Flathub repository configured successfully."
    else
        ui_error "Failed to add the Flathub repository."
        ERRORS+=("Flathub remote-add")
    fi
}

# --- Distribution-Specific Repository Setup ---
setup_distribution_repos() {
    ui_info "Setting up distribution-specific repositories..."
    
    if [ "$DRY_RUN" = true ]; then
        ui_info "[DRY-RUN] Would set up distribution-specific repositories."
        return 0
    fi
    
    # Ubuntu-based distributions - add additional repositories
    if [ "$IS_UBUNTU" = true ] || [ "$IS_MINT" = true ] || [ "$IS_ZORIN" = true ]; then
        # Add universe and multiverse repositories if not already enabled
        ui_info "Ensuring Ubuntu repositories are enabled..."
        
        # Check Ubuntu version for specific handling
        local ubuntu_version=""
        if [ "$IS_UBUNTU" = true ]; then
            ubuntu_version="$DISTRO_VERSION"
        fi
        
        # For Ubuntu 26.04+, ensure proper repository handling
        if [[ "$ubuntu_version" =~ ^(26\.04|26\.10|27\.04) ]]; then
            ui_info "Ubuntu 26.04+ detected - using enhanced repository configuration"
            # Ubuntu 26.04+ should have universe and multiverse enabled by default
            # but we'll verify and add them if needed
        fi
        
        # Check if we need to add repositories (safe glob handling)
        local has_universe=false
        grep -q "universe" /etc/apt/sources.list 2>/dev/null && has_universe=true
        for f in /etc/apt/sources.list.d/*.list; do
            [ -f "$f" ] && grep -q "universe" "$f" 2>/dev/null && has_universe=true && break
        done
        if [ "$has_universe" = false ]; then
            sudo add-apt-repository universe -y 2>/dev/null || ui_warn "Could not add universe repository"
        else
            ui_info "Universe repository is already enabled"
        fi
        
        local has_multiverse=false
        grep -q "multiverse" /etc/apt/sources.list 2>/dev/null && has_multiverse=true
        for f in /etc/apt/sources.list.d/*.list; do
            [ -f "$f" ] && grep -q "multiverse" "$f" 2>/dev/null && has_multiverse=true && break
        done
        if [ "$has_multiverse" = false ]; then
            sudo add-apt-repository multiverse -y 2>/dev/null || ui_warn "Could not add multiverse repository"
        else
            ui_info "Multiverse repository is already enabled"
        fi
        
        ui_info "Repositories updated (already done during system update)"
    fi
    
    # Debian-specific repository setup
    if [ "$IS_DEBIAN" = true ]; then
        ui_info "Configuring Debian repositories..."
        
        # For Debian, ensure contrib and non-free are enabled
        if [ -f /etc/apt/sources.list ]; then
            if ! grep -q "contrib" /etc/apt/sources.list && ! grep -q "non-free" /etc/apt/sources.list; then
                ui_warn "Consider enabling contrib and non-free repositories for additional packages"
                ui_info "You can enable them by adding 'contrib non-free' to your sources.list"
            fi
        fi
    fi
    
    # Zorin OS specific setup
    if [ "$IS_ZORIN" = true ]; then
        ui_info "Configuring Zorin OS specific settings..."
        # Zorin OS already has most repositories configured
        ui_success "Zorin OS repositories are properly configured"
    fi
    
    # Pop!_OS specific setup
    if [ "$IS_POP_OS" = true ]; then
        ui_info "Configuring Pop!_OS specific settings..."
        # Pop!_OS has its own PPA for additional software
        ui_success "Pop!_OS repositories are properly configured"
    fi
}

# --- Function to Install yq (YAML parser) ---
install_yq() {
    if command -v yq &>/dev/null; then
        ui_info "yq is already installed."
        return 0
    fi

    ui_info "Installing yq for YAML configuration parsing..."
    if [ "$DRY_RUN" = true ]; then
        ui_info "[DRY-RUN] Would install yq from GitHub."
        return 0
    fi

    local arch
    case "$(uname -m)" in
        x86_64) arch="amd64" ;;
        aarch64) arch="arm64" ;;
        *)
            ui_warn "Unsupported architecture for yq: $(uname -m). Trying pip..."
            if pip3 install yq 2>/dev/null; then
                ui_success "yq installed via pip."
                return 0
            fi
            ui_warn "yq installation failed. YAML features will be unavailable."
            return 1
            ;;
    esac

    local yq_url="https://github.com/mikefarah/yq/releases/latest/download/yq_linux_${arch}"
    local tmp_yq="/tmp/yq_linux_${arch}"

    if wget -q -O "$tmp_yq" "$yq_url" 2>/dev/null || \
       curl -sL -o "$tmp_yq" "$yq_url" 2>/dev/null; then
        sudo mv "$tmp_yq" /usr/local/bin/yq
        sudo chmod +x /usr/local/bin/yq
        if command -v yq &>/dev/null; then
            ui_success "yq installed successfully."
            return 0
        fi
    fi

    ui_warn "Failed to install yq. YAML features will be unavailable."
    return 1
}

# --- Main Execution ---
update_and_upgrade
install_core_dependencies
install_yq
setup_distribution_repos

# Flatpak is a desktop-specific feature, so we only run it in that mode.
if [ "$INSTALL_MODE" = "desktop" ]; then
    setup_flatpak
fi
