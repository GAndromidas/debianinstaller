#!/bin/bash

# Programs installation — reads package lists from configs/programs.yaml

# Source config.sh for YAML parsing (if not already loaded via install.sh)
if ! declare -f has_yq >/dev/null 2>&1; then
    source "$SCRIPT_DIR/lib/config.sh"
fi

# Ensure distribution is detected and variables are available
if [ -z "$DISTRO_NAME" ]; then
    detect_distribution
fi

PROGRAMS_YAML="$CONFIGS_DIR/programs.yaml"

# ===== Globals =====
apt_packages=()           # Base apt packages (all modes)
essential_packages=()     # Combined final apt package list
distro_packages=()        # Distribution-specific packages
fallback_packages=()      # Packages needing GitHub fallback
de_install_packages=()    # DE-specific installs
flatpak_packages=()       # Flatpak applications

# ===== YAML Loading =====
load_package_lists_from_yaml() {
    if [[ ! -f "$PROGRAMS_YAML" ]]; then
        log_error "Programs configuration file not found: $PROGRAMS_YAML"
        return 1
    fi

    local temp_desc=()
    read_yaml_packages_with_desc "$PROGRAMS_YAML" ".apt.packages" apt_packages temp_desc
    read_yaml_packages_with_desc "$PROGRAMS_YAML" ".essential.desktop.packages" essential_desktop_packages temp_desc
    read_yaml_packages_with_desc "$PROGRAMS_YAML" ".essential.server.packages" essential_server_packages temp_desc
    read_yaml_packages_with_desc "$PROGRAMS_YAML" ".fallback.packages" fallback_packages temp_desc
    read_yaml_packages_with_desc "$PROGRAMS_YAML" ".flatpak.packages" flatpak_packages temp_desc

    # Distribution-specific
    local distro_key=""
    if [ "$IS_UBUNTU" = true ]; then distro_key="ubuntu"
    elif [ "$IS_MINT" = true ]; then distro_key="linuxmint"
    elif [ "$IS_ZORIN" = true ]; then distro_key="zorin"
    elif [ "$IS_DEBIAN" = true ]; then distro_key="debian"
    elif [ "$IS_POP_OS" = true ]; then distro_key="pop"
    fi

    if [ -n "$distro_key" ]; then
        read_yaml_packages_with_desc "$PROGRAMS_YAML" ".distributions.$distro_key.packages" distro_packages temp_desc
    fi

    # DE-specific from desktop_environments section. XDG_CURRENT_DESKTOP is
    # colon-composed on hybrids ("ubuntu:GNOME", "zorin:gnome") — take the
    # LAST component and lowercase it to match the bare YAML keys ("gnome").
    local de_raw="${XDG_CURRENT_DESKTOP:-}" de=""
    de="${de_raw##*:}"
    de="${de,,}"
    if [ -n "$de" ]; then
        read_yaml_packages "$PROGRAMS_YAML" ".desktop_environments.$de.install" de_install_packages
    fi
}

# ===== Package List Determination =====
determine_package_lists() {
    ui_info "Determining package lists for '$INSTALL_MODE' mode..."

    case "$INSTALL_MODE" in
    "desktop")
        essential_packages=("${apt_packages[@]}")
        essential_packages+=("${essential_desktop_packages[@]}")
        ;;
    "server")
        essential_packages=("${essential_server_packages[@]}")
        ;;
    *)
        log_error "Unknown installation mode: $INSTALL_MODE"
        return 1
        ;;
    esac

    # Add distribution-specific packages
    essential_packages+=("${distro_packages[@]}")

    # Add DE-specific packages
    if [[ "$INSTALL_MODE" != "server" ]]; then
        essential_packages+=("${de_install_packages[@]}")
    fi
}

# ===== Fallback Installation Functions =====

install_fastfetch_fallback() {
    ui_info "Installing fastfetch via GitHub release (fallback method)..."
    if command -v fastfetch >/dev/null 2>&1; then
        ui_success "fastfetch is already installed"
        return 0
    fi
    if [ "$DRY_RUN" = true ]; then
        ui_info "[DRY-RUN] Would install fastfetch via GitHub release"
        return 0
    fi

    local latest_version
    latest_version=$(curl -s "https://api.github.com/repos/fastfetch-cli/fastfetch/releases/latest" | grep -Po '"tag_name": "\K.*?(?=")' || echo "2.12.2")
    [ -z "$latest_version" ] && latest_version="2.12.2"

    local arch
    arch=$(uname -m)
    case "$arch" in
        x86_64) arch="x86_64" ;;
        aarch64) arch="aarch64" ;;
        *) ui_warn "Unsupported architecture for fastfetch: $arch"; return 1 ;;
    esac

    local download_url="https://github.com/fastfetch-cli/fastfetch/releases/download/${latest_version}/fastfetch-linux-${arch}.tar.gz"
    local temp_dir="/tmp/fastfetch_install"
    mkdir -p "$temp_dir"

    if ! curl -sL "$download_url" -o "$temp_dir/fastfetch.tar.gz" 2>/dev/null; then
        ui_error "Failed to download fastfetch"; rm -rf "$temp_dir"; return 1
    fi

    local fastfetch_bin
    fastfetch_bin=$(tar -tzf "$temp_dir/fastfetch.tar.gz" | grep -m1 '/fastfetch$' || true)
    if [ -z "$fastfetch_bin" ]; then
        ui_error "Could not find fastfetch binary in archive"; rm -rf "$temp_dir"; return 1
    fi

    if tar -xzf "$temp_dir/fastfetch.tar.gz" -C "$temp_dir" && \
       sudo mv "$temp_dir/$fastfetch_bin" /usr/local/bin/fastfetch && \
       sudo chmod +x /usr/local/bin/fastfetch; then
        ui_success "fastfetch installed successfully via GitHub release"
        INSTALLED_PACKAGES+=("fastfetch")
    else
        ui_error "Failed to install fastfetch via GitHub release"
        ERRORS+=("fastfetch fallback install")
        rm -rf "$temp_dir"
        return 1
    fi
    rm -rf "$temp_dir"
}

install_ucaresystem_core() {
    ui_info "Installing ucaresystem-core from GitHub..."
    if [ "$DRY_RUN" = true ]; then
        ui_info "[DRY-RUN] Would install ucaresystem-core from GitHub."; return 0
    fi

    local latest_release
    latest_release=$(curl -s "https://api.github.com/repos/Utappia/uCareSystem/releases/latest" | grep -o '"tag_name": "[^"]*' | cut -d'"' -f4)
    if [ -z "$latest_release" ]; then
        ui_error "Failed to fetch latest ucaresystem-core release."; return 1
    fi

    local version_number="${latest_release#v}"
    local download_url="https://github.com/Utappia/uCareSystem/releases/download/${latest_release}/ucaresystem-core_${version_number}_all.deb"
    local temp_deb="/tmp/ucaresystem-core_${version_number}_all.deb"

    if curl -sL "$download_url" -o "$temp_deb" 2>/dev/null && \
       [ -f "$temp_deb" ] && \
       sudo dpkg -i "$temp_deb" 2>/dev/null; then
        ui_success "ucaresystem-core installed successfully."
        rm -f "$temp_deb"
        # ucaresystem-core's postinst adds a Utappia PPA pinned to jammy
        # (see debianinstaller.log: ".../utappia/stable/ubuntu jammy main").
        # On resolute/noble that foreign-codename repo can break apt, so warn.
        if [[ "${DISTRO_CODENAME:-}" != "jammy" ]] && grep -rq "utappia.*jammy" /etc/apt/sources.list.d/ 2>/dev/null; then
            ui_warn "ucaresystem-core added a 'jammy' Utappia repo on $DISTRO_NAME $DISTRO_VERSION ($DISTRO_CODENAME) — verify 'apt update' works; you may need to update /etc/apt/sources.list.d/utappia.list."
        fi
        return 0
    else
        ui_error "Failed to install ucaresystem-core."
        rm -f "$temp_deb"; return 1
    fi
}

install_with_fallback() {
    local package_name="$1"
    local fallback_function="$2"
    if is_package_available "$package_name"; then
        apt_install "$package_name"
        return 0
    else
        ui_warn "Package '$package_name' not available in repositories, trying fallback method..."
        $fallback_function
        return $?
    fi
}

# ===== Special Installation Functions =====

install_nerd_fonts() {
    ui_info "Installing Hack Nerd Font for the terminal..."
    local font_name="Hack"
    local font_dir="$HOME/.local/share/fonts"
    local font_url="https://github.com/ryanoasis/nerd-fonts/releases/latest/download/${font_name}.zip"

    if [ "$DRY_RUN" = true ]; then
        ui_info "[DRY-RUN] Would install Hack Nerd Font."; return 0
    fi

    mkdir -p "$font_dir"
    if wget -q "$font_url" -O "/tmp/${font_name}.zip" 2>/dev/null; then
        if unzip -q "/tmp/${font_name}.zip" -d "$font_dir"; then
            find "$font_dir" -name "*Windows*" -delete
            fc-cache -fv >/dev/null 2>&1
            ui_success "Hack Nerd Font installed successfully."
        else
            ui_error "Failed to extract Hack Nerd Font."
            ERRORS+=("Nerd Font extraction")
        fi
        rm -f "/tmp/${font_name}.zip"
    else
        ui_error "Failed to download Hack Nerd Font."
        ERRORS+=("Nerd Font download")
    fi
}

add_repository_key() {
    local key_url="$1"
    local key_name="$2"
    local key_path="$3"

    if [ "$DRY_RUN" = true ]; then
        ui_info "[DRY-RUN] Would add GPG key: $key_name"; return 0
    fi

    ui_info "Adding GPG key for $key_name..."
    if curl -fsSL "$key_url" | sudo gpg --dearmor -o "$key_path" 2>/dev/null; then
        ui_success "GPG key added successfully for $key_name"
        return 0
    else
        ui_error "Failed to add GPG key for $key_name"
        ERRORS+=("GPG key addition failed: $key_name")
        return 1
    fi
}

get_docker_repository() {
    if [ "$IS_POP_OS" = true ]; then
        echo "https://download.docker.com/linux/pop-os"
    elif [ "$IS_UBUNTU" = true ] || [ "$IS_MINT" = true ] || [ "$IS_ZORIN" = true ]; then
        echo "https://download.docker.com/linux/ubuntu"
    elif [ "$IS_DEBIAN" = true ]; then
        echo "https://download.docker.com/linux/debian"
    else
        echo "https://download.docker.com/linux/debian"
    fi
}

get_distro_codename() {
    if [ "$IS_DEBIAN" = true ]; then
        local debian_version
        debian_version=$(cat /etc/debian_version 2>/dev/null | cut -d'.' -f1)
        case "$debian_version" in
            13) echo "trixie" ;;
            12) echo "bookworm" ;;
            11) echo "bullseye" ;;
            *) echo "bookworm" ;;
        esac
    else
        lsb_release -cs 2>/dev/null || echo "noble"
    fi
}

install_docker() {
    if command -v docker >/dev/null 2>&1; then
        ui_success "Docker is already installed."; return 0
    fi

    ui_info "Installing Docker..."
    if [ "$DRY_RUN" = true ]; then
        ui_info "[DRY-RUN] Would install Docker."; return 0
    fi

    local docker_repo
    docker_repo=$(get_docker_repository)
    local distro_codename
    distro_codename=$(get_distro_codename)
    local docker_key_url="${docker_repo}/gpg"
    local docker_key_path="/usr/share/keyrings/docker-archive-keyring.gpg"

    if ! add_repository_key "$docker_key_url" "Docker" "$docker_key_path"; then
        ui_error "Failed to add Docker GPG key."
        ERRORS+=("Docker GPG key")
        return 1
    fi

    if [ ! -f /etc/apt/sources.list.d/docker.list ]; then
        echo \
            "deb [arch=$(dpkg --print-architecture) signed-by=$docker_key_path] $docker_repo \
            $distro_codename stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
        sudo apt-get update -qq
    else
        ui_info "Docker repository already configured"
    fi

    apt_install docker-ce docker-ce-cli containerd.io

    if ! command -v docker >/dev/null 2>&1; then
        ui_warn "Docker CE not available for $DISTRO_NAME $DISTRO_VERSION. Installing docker.io from distro repos..."
        apt_install docker.io
        if ! command -v docker >/dev/null 2>&1; then
            ui_error "Failed to install Docker."
            ERRORS+=("Docker install failed")
            return 1
        fi
    fi

    if ! sudo systemctl enable --now docker; then
        ui_warn "Failed to enable docker service."
        ERRORS+=("docker service enable failed")
    fi
    # usermod the real invoking user (SUDO_USER survives sudo; $USER can be
    # unset in non-login contexts and a `set -u` aborts the whole module).
    local _docker_user="${SUDO_USER:-${USER:-}}"
    if [ -n "$_docker_user" ] && [ "$_docker_user" != "root" ]; then
        sudo usermod -aG docker "$_docker_user"
    else
        ui_warn "Could not determine invoking user - docker group membership not applied"
    fi
    ui_success "Docker installed and enabled successfully. Please log out and log back in to use Docker without sudo."

    local wait_attempts=0
    while [ ! -S /var/run/docker.sock ] && [ "$wait_attempts" -lt 10 ]; do
        sleep 1
        ((wait_attempts++))
    done
}

install_flatpak_apps() {
    if ! command -v flatpak >/dev/null 2>&1; then
        ui_warn "Flatpak command not found. Skipping Flatpak app installations."
        return
    fi

    local f_install=()
    for pkg in "${flatpak_packages[@]}"; do
        if [ "$DRY_RUN" = true ]; then
            ui_info "[DRY-RUN] Would install Flatpak: $pkg"
            continue
        fi
        f_install+=("$pkg")
    done
    if [ ${#f_install[@]} -gt 0 ]; then
        ui_info "Installing ${#f_install[@]} Flatpak app(s) in one transaction..."
        local _f_out=""
        if _f_out=$(sudo flatpak install -y flathub "${f_install[@]}" 2>&1); then
            ui_success "Flatpak batch installed successfully."
            INSTALLED_PACKAGES+=("${f_install[@]} (Flatpak)")
        else
            printf '\n[BATCH FAILURE] flatpak install\n%s\n' "$_f_out" >> "$INSTALL_LOG" 2>/dev/null || true
            ui_warn "Batch Flatpak install failed - falling back per-app"
            for pkg in "${f_install[@]}"; do
                if sudo flatpak install -y flathub "$pkg" >/dev/null 2>&1; then
                    ui_success "Flatpak $pkg installed successfully."
                    INSTALLED_PACKAGES+=("$pkg (Flatpak)")
                else
                    ui_error "Failed to install Flatpak: $pkg"
                    ERRORS+=("Flatpak $pkg install")
                fi
            done
        fi
    fi

    # DE-specific Flatpak (e.g., GNOME Extensions Manager) — same last-
    # component lowercase normalization as the DE apt path above.
    local de_raw="${XDG_CURRENT_DESKTOP:-}" de="" de_flatpaks=()
    de="${de_raw##*:}"
    de="${de,,}"
    if yaml_key_exists "$PROGRAMS_YAML" ".desktop_environments.$de.flatpak"; then
        read_yaml_packages "$PROGRAMS_YAML" ".desktop_environments.$de.flatpak" de_flatpaks
        for pkg in "${de_flatpaks[@]}"; do
            if [ "$DRY_RUN" = true ]; then
                ui_info "[DRY-RUN] Would install DE Flatpak: $pkg"
                continue
            fi
            ui_info "Installing DE-specific Flatpak: $pkg..."
            if sudo flatpak install -y flathub "$pkg" >/dev/null 2>&1; then
                ui_success "Flatpak $pkg installed successfully."
                INSTALLED_PACKAGES+=("$pkg (Flatpak)")
            else
                ui_error "Failed to install Flatpak: $pkg"
                ERRORS+=("Flatpak $pkg install")
            fi
        done
    fi
}

# ===== Installation Functions =====

install_apt_packages() {
    if [[ ${#essential_packages[@]} -eq 0 ]]; then
        ui_info "No apt packages to install."
        return
    fi
    ui_info "Installing ${#essential_packages[@]} apt packages..."

    # Handle special EULA for MS Core Fonts
    if [[ " ${essential_packages[*]} " =~ " ttf-mscorefonts-installer " ]]; then
        if [ "$DRY_RUN" = false ]; then
            echo ttf-mscorefonts-installer msttcorefonts/accepted-mscorefonts-eula select true | sudo debconf-set-selections
        fi
    fi

    # install_package_smart probes availability itself (single apt-cache
    # pass) with the same "not available - skipping" diagnostics - the old
    # pre-filter duplicated the whole index walk.
    if [[ ${#essential_packages[@]} -gt 0 ]]; then
        install_package_smart "${essential_packages[@]}"
    fi
}

install_fallback_packages() {
    for pkg in "${fallback_packages[@]}"; do
        case "$pkg" in
            fastfetch) install_with_fallback "fastfetch" "install_fastfetch_fallback" ;;
        esac
    done
}

# ===== Main Execution =====

load_package_lists_from_yaml
determine_package_lists

install_apt_packages
install_fallback_packages
install_ucaresystem_core
install_nerd_fonts
if [[ "$INSTALL_MODE" != "server" ]]; then
    install_flatpak_apps
fi

if [[ "$INSTALL_MODE" == "server" ]]; then
    install_docker
fi
