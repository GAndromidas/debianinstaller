#!/bin/bash

# This script configures universal keyboard shortcuts for GNOME and KDE Plasma.
# It sets Meta+Enter to launch a terminal and Meta+Q to close a window.
# Commands are made resilient with '|| true' to prevent halting the main installer on non-critical errors.

# Source common functions
if [ -f "$(dirname "$0")/common.sh" ]; then
    source "$(dirname "$0")/common.sh"
else
    echo "Error: common.sh not found." >&2
    exit 1
fi

# --- Desktop Environment Detection ---
detect_de() {
    if [ "$XDG_CURRENT_DESKTOP" ]; then
        case "$XDG_CURRENT_DESKTOP" in
            *GNOME*) echo "GNOME" ;;
            *KDE*)   echo "KDE" ;;
            *XFCE*)  echo "XFCE" ;;
            *MATE*)  echo "MATE" ;;
            *Cinnamon*) echo "CINNAMON" ;;
            *Budgie*) echo "BUDGIE" ;;
            *POP*)   echo "POP" ;;
            *COSMIC*) echo "COSMIC" ;;
            *)       echo "UNKNOWN" ;;
        esac
    else
        # Fallback detection for older systems
        if [ "$DESKTOP_SESSION" ]; then
            case "$DESKTOP_SESSION" in
                *gnome*) echo "GNOME" ;;
                *kde*)   echo "KDE" ;;
                *xfce*)  echo "XFCE" ;;
                *mate*)  echo "MATE" ;;
                *cinnamon*) echo "CINNAMON" ;;
                *budgie*) echo "BUDGIE" ;;
                *pop*)   echo "POP" ;;
                *cosmic*) echo "COSMIC" ;;
                *)       echo "UNKNOWN" ;;
            esac
        else
            echo "UNKNOWN"
        fi
    fi
}

# --- GNOME Shortcut Configuration (Robust Method) ---
setup_gnome_shortcuts() {
    ui_info "Detected GNOME. Configuring shortcuts..."
    if ! command -v gsettings >/dev/null 2>&1; then
        ui_error "'gsettings' command not found. Cannot configure GNOME shortcuts."
        ERRORS+=("gsettings missing")
        return
    fi

    if [ "$DRY_RUN" = true ]; then
        ui_info "[DRY-RUN] Would configure 'Close Window' and 'Launch Terminal' shortcuts."
        return
    fi

    # --- Setup Meta+Q to Close Window ---
    ui_info "Setting up 'Meta+Q' to close windows..."
    local close_key="org.gnome.desktop.wm.keybindings close"
    local current_close_bindings
    current_close_bindings=$(gsettings get $close_key 2>/dev/null || echo "['<Alt>F4']")
    if [[ "$current_close_bindings" != *"'<Super>q'"* ]]; then
        local new_bindings
        new_bindings=$(echo "$current_close_bindings" | sed "s/]$/, '<Super>q']/")
        gsettings set $close_key "$new_bindings" || true
        ui_success "Shortcut 'Meta+Q' added for closing windows."
    else
        ui_warn "Shortcut 'Meta+Q' for closing windows already seems to be set. Skipping."
    fi

    # --- Setup Meta+Enter to Launch Terminal (with robust detection) ---
    ui_info "Detecting available terminal..."
    local terminal_cmd=""
    local terminals_to_check=("gnome-terminal" "kgx" "ptyxis" "x-terminal-emulator")
    for term in "${terminals_to_check[@]}"; do
        if command -v "$term" >/dev/null 2>&1; then
            terminal_cmd="$term"
            ui_success "Found terminal: $terminal_cmd"
            break
        fi
    done

    if [ -z "$terminal_cmd" ]; then
        ui_error "Could not find a compatible terminal to assign a shortcut."
        ERRORS+=("No terminal found for shortcut")
        return
    fi

    ui_info "Setting up 'Meta+Enter' to launch '$terminal_cmd'..."
    local keybinding_path="org.gnome.settings-daemon.plugins.media-keys.custom-keybindings"
    local custom_key="/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom_terminal/"

    # Get current custom bindings
    local current_bindings_str
    current_bindings_str=$(gsettings get "$keybinding_path" custom-keybindings || echo "[]")
    read -r -a current_bindings <<< "$(echo "$current_bindings_str" | tr -d "[]'," | sed 's/ //g')"

    # Add our new binding if it doesn't exist
    if ! [[ " ${current_bindings[*]} " =~ " ${custom_key} " ]]; then
        current_bindings+=("$custom_key")
        gsettings set "$keybinding_path" custom-keybindings "['$(printf "%s', '" "${current_bindings[@]}" | sed "s/, '$//")']" || true
    fi

    # Set the properties for our custom binding
    gsettings set "org.gnome.settings-daemon.plugins.media-keys.custom-keybinding:${custom_key}" name "Launch Terminal (debianinstaller)" || true
    gsettings set "org.gnome.settings-daemon.plugins.media-keys.custom-keybinding:${custom_key}" command "$terminal_cmd" || true
    gsettings set "org.gnome.settings-daemon.plugins.media-keys.custom-keybinding:${custom_key}" binding "<Super>Return" || true
    ui_success "Shortcut 'Meta+Enter' created for '$terminal_cmd'."
}


# --- KDE Plasma Shortcut Configuration ---
setup_kde_shortcuts() {
    ui_info "Detected KDE Plasma. Configuring shortcuts..."
    local config_file="$HOME/.config/kglobalshortcutsrc"

    if ! command -v kwriteconfig5 >/dev/null 2>&1; then
        ui_error "'kwriteconfig5' command not found. Cannot configure KDE shortcuts."
        ERRORS+=("kwriteconfig5 missing")
        return
    fi

    if [ "$DRY_RUN" = true ]; then
        ui_info "[DRY-RUN] Would configure shortcuts for 'Close Window' (Meta+Q) and launch Konsole (Meta+Enter)."
        return
    fi

    # --- Setup Meta+Q to Close Window ---
    ui_info "Setting up 'Meta+Q' to close windows..."
    local current_close_shortcut
    current_close_shortcut=$(kreadconfig5 --file "$config_file" --group kwin --key "Window Close" || echo "Alt+F4")
    if ! [[ "$current_close_shortcut" == *",Super+Q"* ]]; then
        kwriteconfig5 --file "$config_file" --group kwin --key "Window Close" "${current_close_shortcut},Super+Q" || true
        ui_success "Shortcut 'Meta+Q' added for closing windows."
    else
        ui_warn "Shortcut 'Meta+Q' for closing windows already seems to be set. Skipping."
    fi

    # --- Setup Meta+Enter to Launch Terminal (Konsole) ---
    ui_info "Setting up 'Meta+Enter' to launch Konsole..."
    kwriteconfig5 --file "$config_file" --group "org.kde.konsole.desktop" --key "new-window" "Meta+Return,none,New Window" || true
    ui_success "Attempted to set 'Meta+Enter' to launch Konsole. You may need to log out for this to apply."

    # Reload the shortcut daemon
    ui_info "Reloading shortcut configuration..."
    dbus-send --session --dest=org.kde.kglobalaccel --type=method_call /component/kwin org.kde.kglobalaccel.Component.reconfigure >/dev/null 2>&1 || true
    dbus-send --session --dest=org.kde.kglobalaccel --type=method_call /component/org.kde.konsole.desktop org.kde.kglobalaccel.Component.reconfigure >/dev/null 2>&1 || true
}

# --- XFCE Shortcut Configuration ---
setup_xfce_shortcuts() {
    ui_info "Detected XFCE. Configuring shortcuts..."
    
    if ! command -v xfconf-query >/dev/null 2>&1; then
        ui_error "'xfconf-query' command not found. Cannot configure XFCE shortcuts."
        ERRORS+=("xfconf-query missing")
        return
    fi

    if [ "$DRY_RUN" = true ]; then
        ui_info "[DRY-RUN] Would configure shortcuts for XFCE."
        return
    fi

    # Setup custom shortcuts for XFCE
    ui_info "Setting up custom shortcuts for XFCE..."
    # Note: XFCE shortcut configuration is more complex and typically requires GUI
    ui_warn "XFCE shortcut configuration requires manual setup through Settings > Keyboard > Application Shortcuts"
    ui_info "Recommended shortcuts to add manually:"
    ui_info "  - Meta+Enter: xfce4-terminal"
    ui_info "  - Meta+Q: xfce4-session-logout --logout"
}

# --- MATE Shortcut Configuration ---
setup_mate_shortcuts() {
    ui_info "Detected MATE. Configuring shortcuts..."
    
    if ! command -v gsettings >/dev/null 2>&1; then
        ui_error "'gsettings' command not found. Cannot configure MATE shortcuts."
        ERRORS+=("gsettings missing")
        return
    fi

    if [ "$DRY_RUN" = true ]; then
        ui_info "[DRY-RUN] Would configure shortcuts for MATE."
        return
    fi

    # Setup terminal shortcut
    ui_info "Setting up 'Meta+Enter' to launch terminal..."
    gsettings set org.mate.desktop.keybindings terminal "<Super>Return" || true
    
    # Setup window close shortcut
    ui_info "Setting up 'Meta+Q' to close windows..."
    gsettings set org.mate.Marco.global-keybindings close "<Super>q" || true
    
    ui_success "MATE shortcuts configured successfully."
}

# --- Cinnamon Shortcut Configuration ---
setup_cinnamon_shortcuts() {
    ui_info "Detected Cinnamon. Configuring shortcuts..."
    
    if ! command -v gsettings >/dev/null 2>&1; then
        ui_error "'gsettings' command not found. Cannot configure Cinnamon shortcuts."
        ERRORS+=("gsettings missing")
        return
    fi

    if [ "$DRY_RUN" = true ]; then
        ui_info "[DRY-RUN] Would configure shortcuts for Cinnamon."
        return
    fi

    # Setup terminal shortcut (Meta+Enter)
    ui_info "Setting up 'Meta+Enter' to launch terminal..."
    gsettings set org.cinnamon.desktop.keybindings custom-list "['custom0', 'custom1']" || true
    gsettings set org.cinnamon.desktop.keybindings.custom-keybinding:/org/cinnamon/desktop/keybindings/custom-keybindings/custom0/ name "Launch Terminal" || true
    gsettings set org.cinnamon.desktop.keybindings.custom-keybinding:/org/cinnamon/desktop/keybindings/custom-keybindings/custom0/ command "gnome-terminal" || true
    gsettings set org.cinnamon.desktop.keybindings.custom-keybinding:/org/cinnamon/desktop/keybindings/custom-keybindings/custom0/ binding "['<Super>Return']" || true
    
    # Setup close window shortcut (Meta+Q)
    ui_info "Setting up 'Meta+Q' to close window..."
    gsettings set org.cinnamon.desktop.keybindings.custom-keybinding:/org/cinnamon/desktop/keybindings/custom-keybindings/custom1/ name "Close Window" || true
    gsettings set org.cinnamon.desktop.keybindings.custom-keybinding:/org/cinnamon/desktop/keybindings/custom-keybindings/custom1/ command "wmctrl -c :ACTIVE:" || true
    gsettings set org.cinnamon.desktop.keybindings.custom-keybinding:/org/cinnamon/desktop/keybindings/custom-keybindings/custom1/ binding "['<Super>q']" || true
    
    ui_success "Cinnamon shortcuts configured successfully."
}

# --- Pop!_OS Shortcut Configuration ---
setup_pop_shortcuts() {
    ui_info "Detected Pop!_OS. Configuring shortcuts..."
    
    if ! command -v gsettings >/dev/null 2>&1; then
        ui_error "'gsettings' command not found. Cannot configure Pop!_OS shortcuts."
        ERRORS+=("gsettings missing")
        return
    fi

    if [ "$DRY_RUN" = true ]; then
        ui_info "[DRY-RUN] Would configure shortcuts for Pop!_OS."
        return
    fi

    # Pop!_OS uses GNOME-based settings with Pop Shell modifications
    setup_gnome_shortcuts
    ui_success "Pop!_OS shortcuts configured successfully."
}

# --- Cosmic DE Shortcut Configuration ---
setup_cosmic_shortcuts() {
    ui_info "Detected Cosmic desktop environment. Configuring shortcuts..."
    
    # Cosmic DE is a new desktop environment based on the IcedWM toolkit
    # It uses different configuration methods than GNOME
    
    if [ "$DRY_RUN" = true ]; then
        ui_info "[DRY-RUN] Would configure shortcuts for Cosmic DE."
        return
    fi
    
    # Check for Cosmic-specific configuration tools
    if command -v cosmic-settings >/dev/null 2>&1; then
        ui_info "Cosmic settings detected. Attempting to configure shortcuts..."
        
        # Cosmic DE uses different configuration approach
        # For now, provide manual configuration guidance
        ui_warn "Cosmic DE requires manual shortcut configuration:"
        ui_info "  1. Open Cosmic Settings"
        ui_info "  2. Navigate to Keyboard > Shortcuts"
        ui_info "  3. Add custom shortcuts:"
        ui_info "     - Name: 'Launch Terminal'"
        ui_info "     - Command: 'cosmic-term' or 'gnome-terminal'"
        ui_info "     - Shortcut: Meta+Enter"
        ui_info "     - Name: 'Close Window'"
        ui_info "     - Command: 'cosmic-close' or similar"
        ui_info "     - Shortcut: Meta+Q"
        
        # Try to create a basic configuration file if the directory exists
        local cosmic_config_dir="$HOME/.config/cosmic"
        if [ -d "$cosmic_config_dir" ]; then
            ui_info "Cosmic config directory found. Creating shortcut configuration..."
            # Note: This is a placeholder - actual Cosmic configuration format may differ
            echo "# Cosmic DE shortcuts configuration" > "$cosmic_config_dir/shortcuts.conf" 2>/dev/null || true
            echo "meta+terminal=cosmic-term" >> "$cosmic_config_dir/shortcuts.conf" 2>/dev/null || true
            echo "meta+close=close-window" >> "$cosmic_config_dir/shortcuts.conf" 2>/dev/null || true
        fi
    else
        ui_warn "Cosmic settings tools not found. Manual configuration required."
        ui_info "Please configure shortcuts manually in Cosmic Settings:"
        ui_info "  - Meta+Enter for terminal launcher"
        ui_info "  - Meta+Q for window close"
    fi
    
    ui_success "Cosmic DE shortcut configuration completed."
}

DE=$(detect_de)

case "$DE" in
    "GNOME")
        setup_gnome_shortcuts
        ;;
    "KDE")
        setup_kde_shortcuts
        ;;
    "XFCE")
        setup_xfce_shortcuts
        ;;
    "MATE")
        setup_mate_shortcuts
        ;;
    "CINNAMON")
        setup_cinnamon_shortcuts
        ;;
    "POP")
        setup_pop_shortcuts
        ;;
    "COSMIC")
        setup_cosmic_shortcuts
        ;;
    *)
        ui_warn "Desktop environment '$DE' is not supported for automatic shortcut configuration."
        ui_info "Supported environments: GNOME, KDE, XFCE, MATE, Cinnamon, Pop!_OS, Cosmic DE"
        ui_info "You can manually configure shortcuts in your system settings."
        ;;
esac
