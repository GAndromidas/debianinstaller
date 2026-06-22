#!/bin/bash

# This script's only job is to forcefully apply user configurations.
# It is designed to be run every time, ensuring the user's preferred settings are always active.

# Source common.sh is already sourced by the main install.sh

apply_configs() {
    ui_info "Applying user configurations (overwriting existing files)..."

    # Define source and destination paths
    local zshrc_source="$(dirname "$0")/../configs/.zshrc"
    local zshrc_dest="$HOME/.zshrc"
    local starship_source="$(dirname "$0")/../configs/starship.toml"
    local starship_dest="$HOME/.config/starship.toml"
    local fastfetch_source="$(dirname "$0")/../configs/config.jsonc"
    local fastfetch_dest="$HOME/.config/fastfetch/config.jsonc"

    if [ "$DRY_RUN" = true ]; then
        ui_info "[DRY-RUN] Would forcefully copy all config files."
        return 0
    fi

    # Overwrite .zshrc
    if [ -f "$zshrc_source" ]; then
        cp "$zshrc_source" "$zshrc_dest"
        ui_success ".zshrc configuration applied."
    else
        ui_warn "Source config file not found: '$zshrc_source'. Skipping."
    fi

    # Overwrite starship.toml
    if [ -f "$starship_source" ]; then
        mkdir -p "$(dirname "$starship_dest")"
        cp "$starship_source" "$starship_dest"
        ui_success "Starship configuration applied."
    else
        ui_warn "Source config file not found: '$starship_source'. Skipping."
    fi

    # Overwrite fastfetch config
    if [ -f "$fastfetch_source" ]; then
        mkdir -p "$(dirname "$fastfetch_dest")"
        cp "$fastfetch_source" "$fastfetch_dest"
        ui_success "Fastfetch configuration applied."
    else
        ui_warn "Source config file not found: '$fastfetch_source'. Skipping."
    fi
}

# --- Main Execution ---
apply_configs
