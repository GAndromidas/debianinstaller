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
            *)       echo "UNKNOWN" ;;
        esac
    else
        echo "UNKNOWN"
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

# --- Main Execution ---

DE=$(detect_de)

case "$DE" in
    "GNOME")
        setup_gnome_shortcuts
        ;;
    "KDE")
        setup_kde_shortcuts
        ;;
    *)
        ui_warn "No compatible desktop environment (GNOME or KDE) was detected."
        ui_info "Skipping universal shortcut configuration."
        ;;
esac
