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
    )
    
    # SSH service name: both Debian and Ubuntu families provide ssh.service
    # (sshd.service is at most an alias). Probe which unit actually exists
    # instead of guessing by distro — Kubuntu 26.04 only has ssh.service,
    # so hardcoding sshd.service breaks it (see debianinstaller.log:
    # "Service unit 'sshd.service' not found").
    # ONE list-unit-files dump filtered for both spellings (two full-table
    # re-walks before). ssh.service is Debian's canonical name; sshd.service
    # is the alias/spelling some derivatives ship.
    local ssh_service=""
    local _unit_dump
    _unit_dump=$(systemctl list-unit-files 2>/dev/null)
    if grep -q "^ssh\.service" <<<"$_unit_dump"; then
        ssh_service="ssh.service"
    elif grep -q "^sshd\.service" <<<"$_unit_dump"; then
        ssh_service="sshd.service"
    fi

    # Safe-by-default root SSH policy the moment the server exists.
    harden_sshd "$ssh_service"
    if [[ -n "$ssh_service" ]]; then
        services_to_enable+=("$ssh_service")
    else
        # openssh-server is only installed in server mode (see
        # configs/programs.yaml). On desktops this is expected, not an error.
        ui_info "No SSH server unit found (openssh-server not installed) — skipping SSH service enable."
    fi
    
    # Add distribution-specific services
    if [ "$IS_UBUNTU" = true ] || [ "$IS_MINT" = true ] || [ "$IS_ZORIN" = true ]; then
        services_to_enable+=("apt-daily.timer" "apt-daily-upgrade.timer")
    fi
    
    if [ "$IS_DEBIAN" = true ]; then
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
        # Targeted unit probe — the full-table dump per service re-read the
        # entire unit database N times.
        if systemctl list-unit-files "$service" --no-legend 2>/dev/null | grep -q .; then
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


# Safe-by-default SSH hardening (root password login off, key auth
# unaffected) via an sshd_config.d drop-in — Debian 12+/Ubuntu 22.04+ ship
# the sshd_config.d Include by default, but its presence and position are
# verified rather than assumed: directives ABOVE the Include win the
# first-obtained-value race and would silently neutralize the drop-in.
sshd_hardened_enough() {
    local v="${1,,}"
    [[ "$v" == "prohibit-password" || "$v" == "no" ]]
}

# File-level hardening gate — consulted when the sshd -T dump is
# inconclusive (field-experienced quirk: some builds exit 0 reporting
# rc=0 with a large dump but NO permitrootlogin line at all). Requires
# the drop-in present AND the Include effectively first.
_sshd_file_level_hardened() {
    local dropin="${1:-}"
    local main="${SSHD_MAIN_CONFIG:-/etc/ssh/sshd_config}"
    [[ -n "$dropin" && -s "$dropin" ]] || return 1
    sudo grep -qi '^[[:space:]]*PermitRootLogin[[:space:]]\+prohibit-password' "$dropin" 2>/dev/null || return 1
    [[ -s "$main" ]] || return 1
    local inc_line
    inc_line=$(sudo grep -nE '^[[:space:]]*Include[[:space:]].*sshd_config\.d' "$main" 2>/dev/null | head -1 | cut -d: -f1)
    [[ -n "$inc_line" ]] || return 1
    sudo awk -v n="$inc_line" '
        NR >= n { exit 0 }
        /^[[:space:]]*#/ { next }
        /^[[:space:]]*$/ { next }
        { k = tolower($1); if (k ~ /^(permitrootlogin|maxauthtries|logingracetime|maxstartups|clientaliveinterval|clientalivecountmax)$/) exit 1 }
      ' "$main" 2>/dev/null
}

# Make sure the sshd_config.d Include is present and effectively first.
harden_sshd_restore_include() {
    local main="${SSHD_MAIN_CONFIG:-/etc/ssh/sshd_config}"
    local include_re='^[[:space:]]*Include[[:space:]].*sshd_config\.d'
    local first_include _offending=""
    first_include=$(sudo grep -nE "$include_re" "$main" 2>/dev/null | head -1 | cut -d: -f1 || echo "")
    if [[ -n "$first_include" ]]; then
        # awk exits 0 when the Include is effectively first (clean config).
        if sudo awk -v n="$first_include" '
            NR >= n { exit 0 }
            /^[[:space:]]*#/ { next }
            /^[[:space:]]*$/ { next }
            { k = tolower($1); if (k ~ /^(permitrootlogin|maxauthtries|logingracetime|maxstartups|clientaliveinterval|clientalivecountmax)$/) exit 1 }
          ' "$main" 2>/dev/null; then
            ui_info "Include for sshd_config.d already present and first in $main"
            return 0
        fi
        ui_warn "Managed SSH setting precedes Include in $main (first value wins) — moving Include to the top"
        _offending=$(sudo awk -v n="$first_include" '
            NR >= n { exit }
            /^[[:space:]]*#/ { next }
            /^[[:space:]]*$/ { next }
            { k = tolower($1); if (k ~ /^(permitrootlogin|maxauthtries|logingracetime|maxstartups|clientaliveinterval|clientalivecountmax)$/) print NR ": " $0 }
          ' "$main" 2>/dev/null || true)
        [[ -n "$_offending" ]] && log_to_file "Managed keys above Include (line $first_include): ${_offending//$'\n'/ ; }"
    else
        ui_warn "No Include for sshd_config.d in $main — adding it at the top"
    fi
    sudo cp "$main" "${main}.backup.$(date +%Y%m%d_%H%M%S)" 2>/dev/null || {
        ui_warn "Failed to back up $main — leaving sshd_config untouched"
        return 1
    }
    local tmp
    tmp=$(mktemp /tmp/sshd_config.XXXXXX) || return 1
    {
        echo "# Added by debianinstaller - enables sshd_config.d drop-ins (managed)"
        echo "Include /etc/ssh/sshd_config.d/*.conf"
        echo ""
        sudo grep -vE "$include_re" "$main" 2>/dev/null
    } > "$tmp" || { rm -f "$tmp"; return 1; }
    if ! sudo cp "$tmp" "$main" 2>/dev/null; then
        ui_warn "Failed to write $main — leaving sshd_config untouched"
        rm -f "$tmp"
        return 1
    fi
    rm -f "$tmp"
    if sudo sshd -t 2>/dev/null; then
        ui_success "Include in $main fixed — drop-in should now be active"
        return 0
    fi
    ui_warn "sshd config test failed after Include fix — rolling back"
    local latest_backup
    latest_backup=$(ls -t "${main}.backup."* 2>/dev/null | head -1 || true)
    [[ -n "$latest_backup" ]] && sudo cp "$latest_backup" "$main" 2>/dev/null || true
    return 1
}

harden_sshd() {
    local ssh_service="${1:-ssh.service}"
    # server-only path: without the ssh unit there is nothing to harden.
    if ! systemctl list-unit-files "$ssh_service" --no-legend 2>/dev/null | grep -q .; then
        log_to_file "SSH hardening skipped: no $ssh_service unit (openssh-server not installed)"
        return 0
    fi
    if [[ "${DRY_RUN:-false}" == true ]]; then
        ui_info "[DRY-RUN] Would write PermitRootLogin prohibit-password drop-in and reload $ssh_service"
        return 0
    fi

    local dropin_dir="/etc/ssh/sshd_config.d"
    local dropin="$dropin_dir/00-debianinstaller-hardening.conf"

    sudo mkdir -p "$dropin_dir"
    if [[ -f "$dropin" ]]; then
        sudo sed -i 's/^\(PermitRootLogin\).*/\1 prohibit-password/' "$dropin"
    else
        echo "# Managed by debianinstaller - safe-by-default root SSH policy" | sudo tee "$dropin" >/dev/null
        echo "PermitRootLogin prohibit-password" | sudo tee -a "$dropin" >/dev/null
    fi

    if ! sudo sshd -t 2>/dev/null; then
        ui_error "sshd -t failed after writing $dropin - not reloading"
        ERRORS+=("sshd -t failed after SSH hardening")
        return 1
    fi

    local effective
    effective=$(sudo sshd -T 2>/dev/null | awk '$1=="permitrootlogin" {print $2; exit}' || true)
    if sshd_hardened_enough "$effective"; then
        sudo systemctl reload "$ssh_service" 2>/dev/null || true
        ui_success "SSH hardening applied (root password login off, key auth unaffected)"
        return 0
    fi
    if ! harden_sshd_restore_include; then
        ui_warn "Include repair failed - SSH hardening may be inert until fixed"
        return 0
    fi
    effective=$(sudo sshd -T 2>/dev/null | awk '$1=="permitrootlogin" {print $2; exit}' || true)
    if ! sshd_hardened_enough "$effective"; then
        local _t_out="" _t_rc=0 _t_prl=""
        _t_out=$(sudo sshd -T 2>/dev/null) || _t_rc=$?
        _t_prl=$(awk '$1=="permitrootlogin" {print; exit}' <<< "$_t_out")
        log_to_file "sshd -T rc=$_t_rc; dump ${#_t_out} bytes; ${_t_prl:-no permitrootlogin line in output}"
        if _sshd_file_level_hardened "$dropin"; then
            ui_info "sshd -T dump lacks PermitRootLogin (probe inconclusive) - hardening verified at file level"
        else
            ui_warn "SSH hardening still not in effect (sshd -T reports PermitRootLogin '${effective:-<none>}') - leaving $dropin in place"
            return 0
        fi
    fi
    sudo systemctl reload "$ssh_service" 2>/dev/null || true
    ui_success "SSH hardening applied (root password login off, key auth unaffected)"
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
                # We'll keep snapd but optimize its services.
                # Do NOT disable snapd.refresh.timer — that would stop all
                # snap security updates. Only disable the one-shot import
                # helper which is safe to skip on a configured system.
                sudo systemctl disable snapd.autoimport.service 2>/dev/null || true
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

    sudo cp /etc/default/grub /etc/default/grub.installer.bak 2>/dev/null || true

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
    # Any battery of type "Battery" — BAT0/BAT1 only missed BAT2 and
    # vendor-specific names.
    local p
    for p in /sys/class/power_supply/*; do
        [[ -r "$p/type" ]] && [[ "$(cat "$p/type" 2>/dev/null || true)" == "Battery" ]] && return 0
    done
    return 1
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
    if [[ "${DRY_RUN:-false}" == true ]]; then
        ui_info "[DRY-RUN] Would enable Wake-on-LAN on $iface"
        return 0
    fi
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
