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
FAILED_PACKAGES=()
REMOVED_PACKAGES=()
START_TIME=$(date +%s)
TOTAL_STEPS=8 # Default, can be overridden

# --- Installation Mode Variables ---
VERBOSE_MODE=false
QUIET_MODE=false
DRY_RUN=false

# --- Distribution Detection Variables ---
DISTRO_ID=""
DISTRO_NAME=""
DISTRO_VERSION=""
DISTRO_CODENAME=""
IS_DEBIAN=false
IS_UBUNTU=false
IS_MINT=false
IS_ZORIN=false
IS_POP_OS=false

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

# --- Distribution Detection Function ---
detect_distribution() {
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        DISTRO_ID="$ID"
        DISTRO_NAME="$NAME"
        DISTRO_VERSION="$VERSION_ID"
        DISTRO_CODENAME="${VERSION_CODENAME:-}"
        
        # Export variables for child processes
        export DISTRO_ID DISTRO_NAME DISTRO_VERSION DISTRO_CODENAME
        
        # Set distribution flags
        case "$ID" in
            debian)
                IS_DEBIAN=true
                export IS_DEBIAN
                ;;
            ubuntu)
                IS_UBUNTU=true
                export IS_UBUNTU
                ;;
            linuxmint)
                IS_MINT=true
                export IS_MINT
                ;;
            zorin)
                IS_ZORIN=true
                export IS_ZORIN
                ;;
            pop)
                IS_POP_OS=true
                export IS_POP_OS
                ;;
        esac
        
        # Handle Linux Mint which is Ubuntu-based
        if [ "$IS_MINT" = true ] && [ -f /etc/upstream-release/lsb-release ]; then
            . /etc/upstream-release/lsb-release
            DISTRO_CODENAME="$DISTRIB_CODENAME"
        fi
        
        ui_info "Detected: $DISTRO_NAME $DISTRO_VERSION (codename: $DISTRO_CODENAME)"
    else
        ui_error "Cannot detect distribution. /etc/os-release not found."
        return 1
    fi
}

# --- Package Availability Check Function ---
is_package_available() {
    local package="$1"
    if apt-cache show "$package" >/dev/null 2>&1; then
        return 0
    else
        return 1
    fi
}

# --- Distribution-Specific Package Installer ---
install_package_smart() {
    local packages=("$@")
    local available_packages=()
    local alternative_packages=()
    
    for pkg in "${packages[@]}"; do
        if is_package_available "$pkg"; then
            available_packages+=("$pkg")
        else
            # Check for distribution-specific alternatives
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
        # Log alternatives for user reference
        for alt in "${alternative_packages[@]}"; do
            local original="${alt%%:*}"
            local replacement="${alt##*:}"
            log_both "Package alternative used: $original → $replacement"
        done
    else
        ui_warn "No packages from the list are available on this distribution"
    fi
}

# Function to get distribution-specific package alternatives
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

# Suppress Python warnings during package installation
suppress_python_warnings() {
    export PYTHONWARNINGS="ignore"
    export PYTHONPATH=""
    # Also suppress warnings in stderr for any Python processes
    exec 3>&2 2> >(grep -v "SyntaxWarning\|invalid escape sequence" >&3)
}

# Restore stderr
restore_stderr() {
    exec 2>&3 3>&-
}

# Suppress verbose apt output for cleaner installation
suppress_apt_output() {
    export APT_OPTIONS="-qq -o=Dpkg::Use-Pty=0 -o=APT::Color=0"
}

# Function to restore environment after installation
cleanup_install_environment() {
    unset PYTHONWARNINGS
    unset APT_OPTIONS
}

# Enhanced package installation functions (inspired by archinstaller)
apt_install_single() {
    local pkg="$1"
    local verbose="${2:-false}"
    local max_retries=3
    local retry_count=0
    
    if [ "$verbose" = true ] || [ "$VERBOSE_MODE" = true ]; then
        printf "${CYAN}Installing APT package:${RESET} %-30s" "$pkg"
    fi
    
    # Check if already installed
    if dpkg-query -W -f='${Status}' "$pkg" 2>/dev/null | grep -q "ok installed"; then
        [ "$verbose" = true ] || [ "$VERBOSE_MODE" = true ] && printf "${YELLOW} ✓ Already installed${RESET}\n"
        return 0
    fi
    
    while [ $retry_count -lt $max_retries ]; do
        local output
        if output=$(sudo apt-get install -y "$pkg" 2>&1); then
            [ "$verbose" = true ] || [ "$VERBOSE_MODE" = true ] && printf "${GREEN} ✓ Success${RESET}\n"
            INSTALLED_PACKAGES+=("$pkg")
            return 0
        else
            retry_count=$((retry_count + 1))
            if [ $retry_count -lt $max_retries ]; then
                [ "$verbose" = true ] || [ "$VERBOSE_MODE" = true ] && printf "${YELLOW} ! Retrying ($retry_count/$max_retries)...${RESET}\n"
                sleep 3
                # Update package lists before retry
                sudo apt-get update -qq >/dev/null 2>&1 || true
            else
                [ "$verbose" = true ] || [ "$VERBOSE_MODE" = true ] && printf "${RED} ✗ Failed after $max_retries attempts${RESET}\n"
                # Show output if verbose or if it's a critical error
                if [ "$verbose" = true ] || [ "$VERBOSE_MODE" = true ] || [[ "$output" == *"E:"* ]] || [[ "$output" == *"Error:"* ]]; then
                    echo "$output" | sed 's/^/    /'
                fi
                FAILED_PACKAGES+=("$pkg")
                return 1
            fi
        fi
    done
}

# Main apt_install function with batch installation and fallback
apt_install() {
    local pkgs=("$@")
    local to_install=()

    # Filter out already installed packages
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
    
    # Check if any packages to install
    if [ ${#to_install[@]} -eq 0 ]; then
        [ "$VERBOSE_MODE" = true ] && ui_info "All packages already installed."
        return 0
    fi
    
    if [ "$QUIET_MODE" = false ]; then
        ui_info "Installing ${#to_install[@]} packages via apt..."
    fi

    # Try batch install first for speed (like archinstaller)
    if [ "$VERBOSE_MODE" = false ] && [ "$QUIET_MODE" = false ]; then
        printf "${CYAN}Attempting batch installation...${RESET}\n"
    fi
    
    # Suppress Python warnings during package installation
    suppress_python_warnings
    
    if sudo apt-get install -y -qq "${to_install[@]}" >/dev/null 2>&1; then
        if [ "$VERBOSE_MODE" = false ] && [ "$QUIET_MODE" = false ]; then
            printf "${GREEN} ✓ Batch installation successful${RESET}\n"
        fi
        INSTALLED_PACKAGES+=("${to_install[@]}")
        cleanup_install_environment
        return 0
    fi

    # Batch failed, fall back to individual installation
    if [ "$QUIET_MODE" = false ]; then
        printf "${YELLOW} ! Batch installation failed. Falling back to individual installation...${RESET}\n"
    fi
    
    for package in "${to_install[@]}"; do
        apt_install_single "$package" "$VERBOSE_MODE"
    done
    
    # Restore environment
    cleanup_install_environment
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
        echo -e "${GREEN}✓ Successfully Installed Packages (${#INSTALLED_PACKAGES[@]}):${RESET}"
        printf "  %s\n" "${INSTALLED_PACKAGES[@]}"
    fi
    
    if [ ${#FAILED_PACKAGES[@]} -gt 0 ]; then
        echo -e "${RED}✗ Failed Package Installations (${#FAILED_PACKAGES[@]}):${RESET}"
        printf "  %s\n" "${FAILED_PACKAGES[@]}"
    fi
    
    if [ ${#REMOVED_PACKAGES[@]} -gt 0 ]; then
        echo -e "${YELLOW}Removed Packages:${RESET} ${REMOVED_PACKAGES[*]}"
    fi
    
    if [ ${#ERRORS[@]} -gt 0 ]; then
        echo -e "${RED}Additional Errors Encountered:${RESET}"
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
