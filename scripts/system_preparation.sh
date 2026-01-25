#!/bin/bash

# This script prepares the system by updating, upgrading, and installing essential dependencies.

# Source common functions
if [ -f "$(dirname "$0")/common.sh" ]; then
    source "$(dirname "$0")/common.sh"
else
    # This is a critical error, as nothing else can run without common.sh
    echo "FATAL: common.sh not found. The installer cannot continue." >&2
    exit 1
fi

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

# --- Main Execution ---
update_and_upgrade
install_core_dependencies

# Flatpak is a desktop-specific feature, so we only run it in that mode.
if [ "$INSTALL_MODE" = "desktop" ]; then
    setup_flatpak
fi
