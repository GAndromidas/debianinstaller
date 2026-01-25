#!/bin/bash

# This script handles the installation and basic configuration of Fail2ban.

# Source common functions
if [ -f "$(dirname "$0")/common.sh" ]; then
    source "$(dirname "$0")/common.sh"
else
    echo "Error: common.sh not found." >&2
    exit 1
fi

# --- Function to install Fail2ban ---
install_fail2ban() {
    ui_info "Installing Fail2ban..."
    apt_install fail2ban
    if ! command -v fail2ban-client >/dev/null 2>&1 && [ "$DRY_RUN" = false ]; then
        ui_error "Fail2ban installation seems to have failed."
        ERRORS+=("Fail2ban package installation")
        return 1
    fi
    ui_success "Fail2ban package installed."
}

# --- Function to configure Fail2ban ---
configure_fail2ban() {
    ui_info "Configuring Fail2ban for SSH protection..."

    local jail_local_file="/etc/fail2ban/jail.local"
    # Configuration with a slightly longer ban time for better security
    local jail_config="[DEFAULT]
ignoreip = 127.0.0.1/8 ::1
bantime  = 1h
findtime = 10m
maxretry = 5
backend  = systemd

[sshd]
enabled = true
"

    if [ "$DRY_RUN" = true ]; then
        ui_info "[DRY-RUN] Would create $jail_local_file and restart the service."
        if [ -f "$jail_local_file" ]; then
            ui_warn "[DRY-RUN] $jail_local_file already exists. It would be preserved."
        fi
        return 0
    fi

    if [ -f "$jail_local_file" ]; then
        ui_warn "$jail_local_file already exists. Skipping creation to preserve your settings."
    else
        ui_info "Creating default Fail2ban configuration..."
        if echo "$jail_config" | sudo tee "$jail_local_file" > /dev/null; then
            ui_success "Fail2ban configuration created."
        else
            ui_error "Failed to create $jail_local_file."
            ERRORS+=("Fail2ban config creation")
            return 1
        fi
    fi

    ui_info "Enabling and restarting Fail2ban service..."
    if sudo systemctl enable --now fail2ban &>/dev/null && sudo systemctl restart fail2ban &>/dev/null; then
        sleep 1 # Give the service a moment to start
        if systemctl is-active --quiet fail2ban; then
            ui_success "Fail2ban service is active and running."
        else
            ui_error "Fail2ban service failed to start."
            ERRORS+=("Fail2ban service start")
        fi
    else
        ui_error "Failed to enable or restart Fail2ban service."
        ERRORS+=("Fail2ban service enable")
    fi
}

# --- Main Execution ---
install_fail2ban

# Only attempt to configure if the package was installed successfully
if ! [[ " ${ERRORS[*]} " =~ " Fail2ban package installation " ]]; then
    configure_fail2ban
fi
