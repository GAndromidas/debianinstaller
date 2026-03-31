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
    
    # Add distribution-specific services
    if [ "$IS_UBUNTU" = true ] || [ "$IS_MINT" = true ] || [ "$IS_ZORIN" = true ]; then
        # Ubuntu-based systems benefit from these services
        services_to_enable+=("apt-daily.timer" "apt-daily-upgrade.timer")
    fi
    
    if [ "$IS_DEBIAN" = true ]; then
        # Debian-specific services
        services_to_enable+=("cron.service")
    fi
    
    if [ "$IS_POP_OS" = true ]; then
        # Pop!_OS specific services
        services_to_enable+=("system76-power.service")
    fi

    ui_info "Enabling essential system services for $DISTRO_NAME..."

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

# --- Distribution-Specific Optimizations ---
apply_distribution_optimizations() {
    ui_info "Applying distribution-specific optimizations..."
    
    if [ "$DRY_RUN" = true ]; then
        ui_info "[DRY-RUN] Would apply distribution-specific optimizations."
        return 0
    fi
    
    # Ubuntu-based optimizations
    if [ "$IS_UBUNTU" = true ] || [ "$IS_MINT" = true ] || [ "$IS_ZORIN" = true ]; then
        # Disable unnecessary services for better performance
        ui_info "Optimizing Ubuntu-based system services..."
        sudo systemctl disable snapd.seeded.service 2>/dev/null || true
        
        # Ubuntu 26.04+ specific optimizations
        if [[ "$DISTRO_VERSION" =~ ^(26\.04|26\.10|27\.04) ]]; then
            ui_info "Applying Ubuntu 26.04+ specific optimizations..."
            
            # Check if snap is present and handle PipeWire snap transition
            if command -v snap >/dev/null 2>&1; then
                ui_info "Snap detected - Ubuntu 26.04+ may have PipeWire as snap"
                # Note: In Ubuntu 26.04, removing snapd may break audio if PipeWire is snap-based
                # We'll keep snapd but optimize its services
                sudo systemctl disable snapd.autoimport.service 2>/dev/null || true
                sudo systemctl disable snapd.refresh.timer 2>/dev/null || true
            fi
            
            # Ubuntu 26.04 uses cgroup v2 only, ensure proper configuration
            if [ -f /sys/fs/cgroup/cgroup.controllers ]; then
                ui_info "cgroup v2 detected - Ubuntu 26.04 compatible"
            else
                ui_warn "cgroup v1 detected - Ubuntu 26.04 requires cgroup v2"
            fi
        fi
    fi
    
    # Debian optimizations
    if [ "$IS_DEBIAN" = true ]; then
        ui_info "Optimizing Debian system settings..."
        # Ensure proper permissions for system directories
        sudo chmod 755 /usr/local/bin 2>/dev/null || true
    fi
    
    # Pop!_OS optimizations
    if [ "$IS_POP_OS" = true ]; then
        ui_info "Optimizing Pop!_OS settings..."
        # Ensure Pop!_OS power management is properly configured
        if command -v system76-power >/dev/null 2>&1; then
            sudo system76-power daemon 2>/dev/null || true
        fi
        
        # For Pop!_OS Cosmic, add Cosmic-specific optimizations
        if [ "$XDG_CURRENT_DESKTOP" = "COSMIC" ]; then
            ui_info "Applying Pop!_OS Cosmic optimizations..."
            # Cosmic-specific services if available
            if systemctl list-unit-files | grep -q "cosmic-session.service"; then
                ui_info "Cosmic session service found"
            fi
        fi
    fi
    
    ui_success "Distribution-specific optimizations applied."
}

# --- Main Execution ---
configure_ufw
enable_system_services
apply_distribution_optimizations
