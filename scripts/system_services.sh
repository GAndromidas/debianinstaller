#!/bin/bash

# This script enables and configures essential system services like the firewall and SSH.

# Source common functions
if [ -f "$(dirname "$0")/common.sh" ]; then
    source "$(dirname "$0")/common.sh"
else
    echo "Error: common.sh not found." >&2
    exit 1
fi

# --- Function to Configure UFW (Uncomplicated Firewall) ---
configure_ufw() {
    if ! command -v ufw >/dev/null 2>&1; then
        ui_warn "UFW is not installed. Skipping firewall configuration."
        return
    fi

    ui_info "Configuring and enabling the firewall (UFW)..."

    if [ "$DRY_RUN" = true ]; then
        ui_info "[DRY-RUN] Would configure UFW to deny incoming, allow outgoing, and allow SSH."
        return 0
    fi

    # Reset to a known-clean state
    sudo ufw --force reset >/dev/null
    # Set sane defaults
    sudo ufw default deny incoming >/dev/null
    sudo ufw default allow outgoing >/dev/null
    # Allow SSH connections
    sudo ufw allow ssh >/dev/null

    # Enable the firewall
    if sudo ufw --force enable; then
        ui_success "Firewall (UFW) is configured and active."
    else
        ui_error "Failed to enable UFW."
        ERRORS+=("UFW enable failed")
    fi
}

# --- Function to Enable Core System Services ---
enable_system_services() {
    # Services to be enabled. fstrim.timer is for SSD health.
    local services_to_enable=(
        "fstrim.timer"
        "sshd.service"
    )

    ui_info "Enabling essential system services..."

    if [ "$DRY_RUN" = true ]; then
        ui_info "[DRY-RUN] Would enable the following services: ${services_to_enable[*]}"
        return 0
    fi

    for service in "${services_to_enable[@]}"; do
        # Check if the service unit file exists before trying to enable it
        if systemctl list-unit-files | grep -q "^${service}"; then
            if sudo systemctl enable --now "$service" &>/dev/null; then
                ui_success "Service '$service' enabled and started."
            else
                ui_warn "Failed to enable service '$service'."
                ERRORS+=("Service enable failed: $service")
            fi
        else
            ui_warn "Service unit '$service' not found. Skipping."
        fi
    done
}

# --- Main Execution ---
configure_ufw
enable_system_services
