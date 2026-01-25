#!/bin/bash
# common.sh for debianinstaller: colors, UI, batch install, summary, reboot, error collection.
# This script uses a traditional text-based interface.

# --- Color Codes ---
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
CYAN='\033[0;36m'
RESET='\033[0m'

# --- Global Variables ---
ERRORS=()
INSTALLED_PACKAGES=()
REMOVED_PACKAGES=()
START_TIME=$(date +%s)
TOTAL_STEPS=8 # Default, can be overridden

# --- UI & Logging Functions ---

print_header() {
    local title="$1"
    local border="================================================================"
    echo -e "\n${CYAN}${border}${RESET}"
    echo -e "${CYAN}    ${title}${RESET}"
    # Robustly check if a second argument was passed to avoid unbound variable errors with 'set -u'
    if [ "$#" -gt 1 ]; then
        echo -e "${YELLOW}    $2${RESET}"
    fi
    echo -e "${CYAN}${border}${RESET}\n"
}

print_step_header() {
    local current_step="$1"
    local total_steps="$2"
    local title="$3"
    echo -e "\n${CYAN}--- [Step $current_step/$total_steps] $title ---${RESET}"
}

ui_info() {
    echo -e "${CYAN}INFO: $1${RESET}"
}

ui_success() {
    echo -e "${GREEN}SUCCESS: $1${RESET}"
}

ui_warn() {
    echo -e "${YELLOW}WARNING: $1${RESET}"
}

ui_error() {
    echo -e "${RED}ERROR: $1${RESET}"
}

# --- Core Logic ---

show_menu() {
    echo -e "${CYAN}=====================================================${RESET}"
    echo -e "${CYAN}          WELCOME TO DEBIAN INSTALLER                ${RESET}"
    echo -e "${CYAN}=====================================================${RESET}"
    echo -e "${YELLOW}This script will set up your Debian-based system with all the essentials!${RESET}"
    echo ""
    echo -e "${CYAN}Choose your installation mode:${RESET}"
    echo "  1) Desktop - Full desktop setup"
    echo "  2) Server  - Minimal server setup"
    echo "  3) Exit    - Cancel installation"
    echo ""
    while true; do
        read -rp "Enter your choice [1-3]: " menu_choice
        case "$menu_choice" in
            1)
                INSTALL_MODE="desktop"
                echo -e "${GREEN}✓ Selected: Desktop installation${RESET}"
                break
                ;;
            2)
                INSTALL_MODE="server"
                echo -e "${GREEN}✓ Selected: Server installation${RESET}"
                break
                ;;
            3)
                echo -e "${YELLOW}Installation cancelled.${RESET}"
                exit 0
                ;;
            *)
                echo -e "${RED}Invalid choice! Please enter a number from 1 to 3.${RESET}"
                ;;
        esac
    done
}

apt_install() {
    local pkgs=("$@")
    local to_install=()

    # Filter out already installed packages
    for pkg in "${pkgs[@]}"; do
        if ! dpkg-query -W -f='${Status}' "$pkg" 2>/dev/null | grep -q "ok installed"; then
            to_install+=("$pkg")
        fi
    done

    if [ "${#to_install[@]}" -eq 0 ]; then
        ui_info "All packages already installed."
        return 0
    fi

    ui_info "Installing ${#to_install[@]} packages via apt..."
    export DEBIAN_FRONTEND=noninteractive

    if [ "$DRY_RUN" = true ]; then
        ui_info "[DRY-RUN] Would install: ${to_install[*]}"
        return 0
    fi

    sudo apt-get update -qq || ui_warn "apt update failed, continuing anyway..."

    if sudo apt-get install -y -qq "${to_install[@]}"; then
        ui_success "All packages installed successfully"
        INSTALLED_PACKAGES+=("${to_install[@]}")
    else
        ui_warn "Batch install failed, trying individual installation..."
        for pkg in "${pkgs[@]}"; do
            if sudo apt-get install -y -qq "$pkg"; then
                ui_success "Installed $pkg"
                INSTALLED_PACKAGES+=("${pkg}")
            else
                ui_error "Failed to install $pkg"
                ERRORS+=("apt install $pkg")
            fi
        done
    fi
}


# --- Summary & Finalization ---

log_performance() {
    local description="$1"
    local end_time=$(date +%s)
    local duration=$((end_time - START_TIME))
    local minutes=$((duration / 60))
    local seconds=$((duration % 60))
    log_both "${description}: ${minutes}m ${seconds}s"
}

final_cleanup() {
    if [ "$DRY_RUN" = true ]; then
        ui_info "[DRY-RUN] Final cleanup would run here."
        return
    fi
    ui_info "Performing final cleanup..."

    # Remove figlet if it was installed by the script
    if [ "${FIGLET_INSTALLED_BY_SCRIPT:-false}" = true ]; then
        ui_info "Removing temporary package 'figlet'..."
        sudo apt-get remove --purge -y figlet -qq >/dev/null 2>&1
    fi

    # Automatically remove the installer directory
    ui_info "Removing installer directory..."
    rm -rf "$SCRIPT_DIR"
    ui_success "Installer directory removed."
}

print_summary() {
    echo ""
    echo -e "${CYAN}==================== Installation Summary ====================${RESET}"
    log_performance "Total execution time"

    if [ ${#INSTALLED_PACKAGES[@]} -gt 0 ]; then
        echo -e "${GREEN}Installed Packages:${RESET} ${INSTALLED_PACKAGES[*]}"
    fi
    if [ ${#REMOVED_PACKAGES[@]} -gt 0 ]; then
        echo -e "${YELLOW}Removed Packages:${RESET} ${REMOVED_PACKAGES[*]}"
    fi
    if [ ${#ERRORS[@]} -gt 0 ]; then
        echo -e "${RED}Errors Encountered:${RESET}"
        for error in "${ERRORS[@]}"; do
            echo "  - $error"
        done
    fi
     echo -e "${CYAN}============================================================${RESET}"
}

prompt_reboot() {
    echo ""
    if command -v figlet >/dev/null 2>&1; then
        figlet "Reboot System"
    else
        echo -e "${CYAN}==================== Reboot System ====================${RESET}"
    fi

    ui_info "It's strongly recommended to reboot now to apply all changes."
    if [ "$DRY_RUN" = true ]; then
        ui_info "[DRY-RUN] Reboot would be prompted and cleanup would run."
        return
    fi

    read -rp "Reboot now? [Y/n]: " response
    # Default to 'y' if the user presses Enter
    if [[ -z "$response" || "$response" =~ ^[Yy]$ ]]; then
        # CRITICAL FIX: Run cleanup *before* the reboot command.
        final_cleanup
        ui_info "Rebooting system..."
        sudo reboot
    else
        # CRITICAL FIX: Also run cleanup if the user chooses not to reboot.
        final_cleanup
        ui_warn "Reboot skipped. Please reboot manually when ready."
    fi
}
