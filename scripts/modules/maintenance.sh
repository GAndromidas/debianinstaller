#!/bin/bash

# This script handles final system cleanup tasks like clearing package caches.

# Source common.sh is already sourced by the main install.sh

# --- Function to Clean Up APT Cache and Unused Packages ---
cleanup_apt() {
    ui_info "Performing final package cleanup..."

    if [ "$DRY_RUN" = true ]; then
        ui_info "[DRY-RUN] Would run 'apt autoremove' and 'apt clean'."
        return 0
    fi

    ui_info "Removing unused packages (autoremove --purge)..."
    local _ar_out=""
    if _ar_out=$(sudo env NEEDRESTART_MODE=a DEBIAN_FRONTEND=noninteractive apt-get autoremove --purge -y -qq 2>&1); then
        ui_success "Unused packages removed."
    else
        printf '\n[CLEANUP FAILURE] apt-get autoremove\n%s\n' "$_ar_out" >> "$INSTALL_LOG" 2>/dev/null || true
        ui_warn "apt autoremove command failed (output logged)."
        # Not adding to ERRORS as this is a non-critical cleanup step.
    fi

    ui_info "Clearing APT package cache (clean)..."
    if sudo apt-get clean -qq >/dev/null 2>&1; then
        ui_success "APT cache cleared."
    else
        ui_warn "apt clean command failed."
    fi
}


# --- Main Execution ---
cleanup_apt
