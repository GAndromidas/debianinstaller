#!/bin/bash

# This script handles the setup of ZSH, Oh My Zsh, Starship, and Fastfetch.

# Source common.sh is already sourced by the main install.sh

# --- ZSH and Oh My Zsh ---
install_zsh_package() {
    ui_info "Installing ZSH package..."
    apt_install zsh
    if ! command -v zsh >/dev/null 2>&1 && [ "$DRY_RUN" = false ]; then
        ui_error "ZSH package installation failed."
        ERRORS+=("ZSH package install")
        return 1
    fi
    ui_success "ZSH package installed."
}

install_oh_my_zsh() {
    if [ -d "$HOME/.oh-my-zsh" ]; then
        ui_success "Oh My Zsh is already installed."
        return 0
    fi
    ui_info "Installing Oh My Zsh..."
    if [ "$DRY_RUN" = true ]; then
        ui_info "[DRY-RUN] Would install Oh My Zsh."
        return 0
    fi
    if sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended --keep-zshrc >/dev/null 2>&1; then
        ui_success "Oh My Zsh installed successfully."
    else
        ui_error "Failed to install Oh My Zsh."
        ERRORS+=("Oh My Zsh installation")
    fi
}

install_zsh_plugins() {
    ui_info "Installing ZSH plugins (autosuggestions, syntax-highlighting)..."
    
    # First try to install from distribution repositories
    local plugins_installed=false
    
    # Try installing zsh-autosuggestions from apt
    if is_package_available "zsh-autosuggestions"; then
        ui_info "Installing zsh-autosuggestions from repository..."
        apt_install zsh-autosuggestions
        plugins_installed=true
    else
        ui_warn "zsh-autosuggestions not available in repositories, using GitHub fallback..."
    fi
    
    # Try installing zsh-syntax-highlighting from apt
    if is_package_available "zsh-syntax-highlighting"; then
        ui_info "Installing zsh-syntax-highlighting from repository..."
        apt_install zsh-syntax-highlighting
        plugins_installed=true
    else
        ui_warn "zsh-syntax-highlighting not available in repositories, using GitHub fallback..."
    fi
    
    # If plugins weren't installed from apt, use GitHub fallback
    if [ "$plugins_installed" = false ]; then
        install_zsh_plugins_github_fallback
    else
        ui_success "ZSH plugins installed from repositories."
    fi
}

install_zsh_plugins_github_fallback() {
    ui_info "Installing ZSH plugins from GitHub (fallback method)..."
    local plugins_dir="$HOME/.oh-my-zsh/custom/plugins"
    
    if [ "$DRY_RUN" = true ]; then
        ui_info "[DRY-RUN] Would clone ZSH plugins from GitHub."
        return 0
    fi
    
    mkdir -p "$plugins_dir"
    
    # Install zsh-autosuggestions
    if [ ! -d "${plugins_dir}/zsh-autosuggestions" ]; then
        ui_info "Cloning zsh-autosuggestions from GitHub..."
        if git clone -q https://github.com/zsh-users/zsh-autosuggestions "${plugins_dir}/zsh-autosuggestions"; then
            ui_success "zsh-autosuggestions cloned successfully."
        else
            ui_error "Failed to clone zsh-autosuggestions."
            ERRORS+=("zsh-autosuggestions clone")
        fi
    else
        ui_info "zsh-autosuggestions already exists, updating..."
        (cd "${plugins_dir}/zsh-autosuggestions" && git pull -q) || ui_warn "Failed to update zsh-autosuggestions"
    fi
    
    # Install zsh-syntax-highlighting
    if [ ! -d "${plugins_dir}/zsh-syntax-highlighting" ]; then
        ui_info "Cloning zsh-syntax-highlighting from GitHub..."
        if git clone -q https://github.com/zsh-users/zsh-syntax-highlighting.git "${plugins_dir}/zsh-syntax-highlighting"; then
            ui_success "zsh-syntax-highlighting cloned successfully."
        else
            ui_error "Failed to clone zsh-syntax-highlighting."
            ERRORS+=("zsh-syntax-highlighting clone")
        fi
    else
        ui_info "zsh-syntax-highlighting already exists, updating..."
        (cd "${plugins_dir}/zsh-syntax-highlighting" && git pull -q) || ui_warn "Failed to update zsh-syntax-highlighting"
    fi
    
    ui_success "ZSH plugins installation completed."
}

# --- Starship Prompt ---
install_starship() {
    if command -v starship >/dev/null 2>&1; then
        ui_success "Starship prompt is already installed."
        return 0
    fi
    ui_info "Installing Starship prompt..."
    if [ "$DRY_RUN" = true ]; then
        ui_info "[DRY-RUN] Would install Starship."
        return 0
    fi
    if curl -sS https://starship.rs/install.sh | sh -s -- -y >/dev/null 2>&1; then
        ui_success "Starship installed successfully."
    else
        ui_error "Failed to install Starship."
        ERRORS+=("Starship installation")
    fi
}

# --- Fastfetch (install early for config to reference) ---
install_fastfetch() {
    if command -v fastfetch >/dev/null 2>&1; then
        return 0
    fi
    if [ "$DRY_RUN" = true ]; then
        return 0
    fi
    if apt_install fastfetch; then
        command -v fastfetch >/dev/null 2>&1 && return 0
    fi
    # GitHub fallback
    local arch
    case "$(uname -m)" in
        x86_64) arch="amd64" ;;
        aarch64) arch="aarch64" ;;
        *) ui_warn "Unsupported arch for fastfetch GitHub install"; return 1 ;;
    esac
    local ver
    ver=$(curl -s "https://api.github.com/repos/fastfetch-cli/fastfetch/releases/latest" | grep -Po '"tag_name": "\K.*?(?=")' || echo "2.12.2")
    local url="https://github.com/fastfetch-cli/fastfetch/releases/download/${ver}/fastfetch-linux-${arch}.deb"
    local tmp="/tmp/fastfetch.deb"
    if wget -q -O "$tmp" "$url"; then
        sudo dpkg -i "$tmp" &>/dev/null || sudo apt-get install -f -y -qq
        rm -f "$tmp"
    fi
}
# --- Set Default Shell ---
change_default_shell() {
    local zsh_path
    zsh_path=$(which zsh)
    if [ -z "$zsh_path" ]; then
        ui_error "Could not find zsh path. Cannot change shell."
        ERRORS+=("ZSH path not found")
        return 1
    fi
    if [[ "$SHELL" == *"/zsh" ]]; then
        ui_success "Default shell is already ZSH."
        return 0
    fi
    ui_info "Changing default shell to ZSH for the current user..."
    if [ "$DRY_RUN" = true ]; then
        ui_info "[DRY-RUN] Would change default shell to $zsh_path."
        return 0
    fi
    if sudo chsh -s "$zsh_path" "$USER"; then
        ui_success "Default shell changed to ZSH."
        ui_info "You will need to log out and log back in for the change to take effect."
    else
        ui_error "Failed to change default shell."
        ERRORS+=("chsh command failed")
    fi
}


# --- Main Execution ---
install_zsh_package
install_oh_my_zsh
install_zsh_plugins
install_starship
install_fastfetch
change_default_shell
