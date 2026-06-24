#!/bin/bash

# This script enables and configures essential system services like the firewall and SSH.

# Source common.sh is already sourced by the main install.sh

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

# --- Function to Set GRUB Timeout ---
configure_grub_timeout() {
    ui_info "Setting GRUB timeout to 3 seconds..."

    if [ "$DRY_RUN" = true ]; then
        ui_info "[DRY-RUN] Would set GRUB_TIMEOUT=3 in /etc/default/grub and run update-grub."
        return 0
    fi

    if [ ! -f /etc/default/grub ]; then
        ui_warn "/etc/default/grub not found. Skipping GRUB configuration."
        return
    fi

    sudo cp /etc/default/grub "/etc/default/grub.bak.$(date +%s)" 2>/dev/null || true

    if grep -q "^GRUB_TIMEOUT=" /etc/default/grub; then
        sudo sed -i 's/^GRUB_TIMEOUT=.*/GRUB_TIMEOUT=3/' /etc/default/grub
    else
        echo 'GRUB_TIMEOUT=3' | sudo tee -a /etc/default/grub >/dev/null
    fi

    if command -v update-grub >/dev/null 2>&1; then
        if sudo update-grub >/dev/null 2>&1; then
            ui_success "GRUB timeout set to 3 seconds."
        else
            ui_warn "update-grub failed. GRUB config file updated but bootloader may not reflect changes."
            ERRORS+=("update-grub failed")
        fi
    elif command -v grub-mkconfig >/dev/null 2>&1; then
        if sudo grub-mkconfig -o /boot/grub/grub.cfg >/dev/null 2>&1; then
            ui_success "GRUB timeout set to 3 seconds."
        else
            ui_warn "grub-mkconfig failed. GRUB config file updated but bootloader may not reflect changes."
            ERRORS+=("grub-mkconfig failed")
        fi
    else
        ui_warn "Neither update-grub nor grub-mkconfig found. GRUB config file updated manually."
    fi
}

# --- Wake-on-LAN Configuration ---
is_laptop() {
    [ -d /sys/class/power_supply/BAT0 ] || [ -d /sys/class/power_supply/BAT1 ]
}

get_ethernet_interfaces() {
    for iface in /sys/class/net/*; do
        iface=$(basename "$iface")
        [[ "$iface" == "lo" ]] && continue
        if [[ "$iface" =~ ^(enp|eth|ens|eno) ]]; then
            echo "$iface"
        fi
    done
}

supports_wol() {
    local iface="$1"
    if ! command -v ethtool &>/dev/null; then
        return 1
    fi
    local wol_support
    wol_support=$(sudo ethtool "$iface" 2>/dev/null | awk '/Supports Wake-on:/ {print $4}')
    [[ -n "$wol_support" && "$wol_support" == *"g"* ]]
}

enable_wol_interface() {
    local iface="$1"
    log_to_file "Enabling Wake-on-LAN on interface: $iface"
    if sudo ethtool -s "$iface" wol g; then
        local service_file="/etc/systemd/system/wol-${iface}.service"
        sudo tee "$service_file" > /dev/null <<EOF
[Unit]
Description=Enable Wake-on-LAN for $iface
After=network.target

[Service]
Type=oneshot
ExecStart=/sbin/ethtool -s $iface wol g
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
EOF
        sudo systemctl daemon-reload
        if sudo systemctl enable "wol-${iface}.service"; then
            ui_success "Wake-on-LAN enabled persistently on $iface"
        fi
        return 0
    fi
    return 1
}

configure_wakeonlan() {
    if is_laptop; then
        ui_info "Laptop detected — Wake-on-LAN skipped."
        return 0
    fi

    if ! command -v ethtool &>/dev/null; then
        apt_install ethtool
    fi

    local interfaces
    interfaces=($(get_ethernet_interfaces))
    if [ ${#interfaces[@]} -eq 0 ]; then
        ui_info "No ethernet interfaces found — Wake-on-LAN skipped."
        return 0
    fi

    ui_info "Found ${#interfaces[@]} ethernet interface(s)"
    local enabled=0
    for iface in "${interfaces[@]}"; do
        if supports_wol "$iface"; then
            if enable_wol_interface "$iface"; then
                ((enabled++))
            fi
        else
            ui_warn "Interface $iface does not support Wake-on-LAN"
        fi
    done

    if [ "$enabled" -gt 0 ]; then
        ui_success "Wake-on-LAN enabled on $enabled interface(s)"
    else
        ui_info "No interfaces could be configured for Wake-on-LAN."
    fi
}

# --- Main Execution ---
configure_ufw
enable_system_services
apply_distribution_optimizations
configure_grub_timeout
configure_wakeonlan
