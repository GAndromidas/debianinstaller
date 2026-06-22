#!/bin/bash

install_package_smart() {
    local packages=("$@")
    local available_packages=()
    local alternative_packages=()

    for pkg in "${packages[@]}"; do
        if is_package_available "$pkg"; then
            available_packages+=("$pkg")
        else
            local alternative
            alternative=$(get_package_alternative "$pkg")
            if [ -n "$alternative" ] && is_package_available "$alternative"; then
                ui_info "Package '$pkg' not available, using alternative '$alternative' on $DISTRO_NAME"
                available_packages+=("$alternative")
                alternative_packages+=("$pkg:$alternative")
            else
                ui_warn "Package '$pkg' not available on $DISTRO_NAME $DISTRO_VERSION - skipping"
            fi
        fi
    done

    if [ ${#available_packages[@]} -gt 0 ]; then
        apt_install "${available_packages[@]}"
        for alt in "${alternative_packages[@]}"; do
            local original="${alt%%:*}"
            local replacement="${alt##*:}"
            log_both "Package alternative used: $original → $replacement"
        done
    else
        ui_warn "No packages from the list are available on this distribution"
    fi
}

get_package_alternative() {
    local package="$1"

    case "$package" in
        "ubuntu-restricted-extras")
            if [ "$IS_MINT" = true ]; then
                echo "mint-meta-codecs"
            elif [ "$IS_ZORIN" = true ]; then
                echo "zorin-os-restricted-extras"
            elif [ "$IS_POP_OS" = true ]; then
                echo "pop-codecs"
            else
                echo ""
            fi
            ;;
        "firmware-linux")
            if [ "$IS_UBUNTU" = true ]; then
                echo "linux-firmware"
            elif [ "$IS_MINT" = true ]; then
                echo "linux-firmware"
            else
                echo ""
            fi
            ;;
        "android-tools-adb")
            if ! is_package_available "$package" && is_package_available "adb"; then
                echo "adb"
            else
                echo ""
            fi
            ;;
        "android-tools-fastboot")
            if ! is_package_available "$package" && is_package_available "fastboot"; then
                echo "fastboot"
            else
                echo ""
            fi
            ;;
        *)
            echo ""
            ;;
    esac
}

suppress_python_warnings() {
    export PYTHONWARNINGS="ignore"
    export PYTHONPATH=""
    exec 3>&2 2> >(grep -v "SyntaxWarning\|invalid escape sequence" >&3)
}

cleanup_install_environment() {
    unset PYTHONWARNINGS
    unset APT_OPTIONS
}

apt_install_single() {
    local pkg="$1"
    local verbose="${2:-false}"
    local max_retries=3
    local retry_count=0

    if [ "$verbose" = true ] || [ "$VERBOSE_MODE" = true ]; then
        printf "${CYAN}Installing APT package:${RESET} %-30s" "$pkg"
    fi

    if dpkg-query -W -f='${Status}' "$pkg" 2>/dev/null | grep -q "ok installed"; then
        [ "$verbose" = true ] || [ "$VERBOSE_MODE" = true ] && printf "${YELLOW} ✓ Already installed${RESET}\n"
        return 0
    fi

    local update_done=false
    while [ $retry_count -lt $max_retries ]; do
        local output
        if output=$(sudo NEEDRESTART_MODE=a DEBIAN_FRONTEND=noninteractive apt-get install -y "$pkg" 2>&1); then
            [ "$verbose" = true ] || [ "$VERBOSE_MODE" = true ] && printf "${GREEN} ✓ Success${RESET}\n"
            INSTALLED_PACKAGES+=("$pkg")
            return 0
        else
            retry_count=$((retry_count + 1))
            if [ $retry_count -lt $max_retries ]; then
                [ "$verbose" = true ] || [ "$VERBOSE_MODE" = true ] && printf "${YELLOW} ! Retrying ($retry_count/$max_retries)...${RESET}\n"
                sleep 3
                if [ "$update_done" = false ]; then
                    sudo apt-get update -qq >/dev/null 2>&1 || true
                    update_done=true
                fi
            else
                [ "$verbose" = true ] || [ "$VERBOSE_MODE" = true ] && printf "${RED} ✗ Failed after $max_retries attempts${RESET}\n"
                if [ "$verbose" = true ] || [ "$VERBOSE_MODE" = true ] || [[ "$output" == *"E:"* ]] || [[ "$output" == *"Error:"* ]]; then
                    echo "$output" | sed 's/^/    /'
                fi
                FAILED_PACKAGES+=("$pkg")
                return 1
            fi
        fi
    done
}

apt_install() {
    local pkgs=("$@")
    local to_install=()

    for pkg in "${pkgs[@]}"; do
        if ! dpkg-query -W -f='${Status}' "$pkg" 2>/dev/null | grep -q "ok installed"; then
            to_install+=("$pkg")
        fi
    done

    if [ "$DRY_RUN" = true ]; then
        if [ "$VERBOSE_MODE" = true ] || [ ${#to_install[@]} -gt 0 ]; then
            ui_info "[DRY-RUN] Would install ${#to_install[@]} packages via apt: ${to_install[*]}"
        fi
        return 0
    fi

    if [ ${#to_install[@]} -eq 0 ]; then
        [ "$VERBOSE_MODE" = true ] && ui_info "All packages already installed."
        return 0
    fi

    if [ "$QUIET_MODE" = false ]; then
        ui_info "Installing ${#to_install[@]} packages via apt..."
    fi

    if [ "$VERBOSE_MODE" = false ] && [ "$QUIET_MODE" = false ]; then
        printf "${CYAN}Attempting batch installation...${RESET}\n"
    fi

    suppress_python_warnings

    if sudo NEEDRESTART_MODE=a DEBIAN_FRONTEND=noninteractive apt-get install -y -qq "${to_install[@]}" >/dev/null 2>&1; then
        if [ "$VERBOSE_MODE" = false ] && [ "$QUIET_MODE" = false ]; then
            printf "${GREEN} ✓ Batch installation successful${RESET}\n"
        fi
        INSTALLED_PACKAGES+=("${to_install[@]}")
        cleanup_install_environment
        return 0
    fi

    if [ "$QUIET_MODE" = false ]; then
        printf "${YELLOW} ! Batch installation failed. Falling back to individual installation...${RESET}\n"
    fi

    for package in "${to_install[@]}"; do
        apt_install_single "$package" "$VERBOSE_MODE"
    done

    cleanup_install_environment
}
