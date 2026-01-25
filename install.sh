#!/bin/bash
set -euo pipefail

# Installation log file
INSTALL_LOG="$HOME/.debianinstaller.log"

# Function to show help
show_help() {
  cat << EOF
Debianinstaller - Comprehensive Debian-based Distro Post-Installation Script

USAGE:
    ./install.sh [OPTIONS]

OPTIONS:
    -v, --verbose   Enable verbose output (show all package installation details)
    -q, --quiet     Quiet mode (minimal output)
    -d, --dry-run   Preview what will be installed without making changes
    -h, --help      Show this help message and exit

DESCRIPTION:
    Debianinstaller transforms a fresh Debian, Ubuntu, Zorin OS, Pop!_OS, or
    Linux Mint installation into a fully configured, optimized system. It
    installs essential packages, configures the desktop environment, sets up
    security features, and applies performance optimizations.

INSTALLATION MODES:
    Desktop         Complete setup with all recommended packages for a desktop environment.
    Server          Essential tools and services for a headless server installation.

REQUIREMENTS:
    - Fresh Debian-based installation (Debian, Ubuntu, Mint, etc.)
    - Active internet connection
    - Regular user account with sudo privileges
    - Minimum 2GB free disk space

EXAMPLES:
    ./install.sh                Run installer with interactive prompts
    ./install.sh --verbose      Run with detailed package installation output
    ./install.sh --help         Show this help message

LOG FILE:
    Installation log saved to: ~/.debianinstaller.log

EOF
  exit 0
}

# Clear terminal for clean interface
clear

# Get the directory where this script is located
export SCRIPT_DIR
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPTS_DIR="$SCRIPT_DIR/scripts"
CONFIGS_DIR="$SCRIPT_DIR/configs"

# Sourcing common.sh here requires a correct path from the root.
# All other scripts will be called from within the scripts/ directory.
source "$SCRIPTS_DIR/common.sh"

# Initialize log file
{
  echo "=========================================="
  echo "Debianinstaller Installation Log"
  echo "Started: $(date)"
  echo "=========================================="
  echo ""
} > "$INSTALL_LOG"

# Function to log to both console and file
log_both() {
  echo "$1" | tee -a "$INSTALL_LOG"
}

START_TIME=$(date +%s)

# Parse flags
VERBOSE=false
DRY_RUN=false
for arg in "$@"; do
  case "$arg" in
    -v|--verbose)
      VERBOSE=true
      ;;
    -q|--quiet)
      VERBOSE=false
      ;;
    -d|--dry-run)
      DRY_RUN=true
      VERBOSE=true
      ;;
    -h|--help)
      show_help
      ;;
    *)
      echo "Unknown option: $arg"
      echo "Use --help for usage information"
      exit 1
      ;;
  esac
done
export VERBOSE
export DRY_RUN
export INSTALL_LOG

# --- System Validation ---
check_system_requirements() {
  if [[ $EUID -eq 0 ]]; then
    echo -e "\033[0;31mError: This script should NOT be run as root!\033[0m"
    exit 1
  fi
  if [[ ! -f /etc/debian_version ]]; then
    echo -e "\033[0;31mError: This script is designed for Debian-based systems only!\033[0m"
    exit 1
  fi
  if ! ping -c 1 debian.org &>/dev/null; then
    echo -e "\033[0;31mError: No internet connection detected!\033[0m"
    exit 1
  fi
  local available_space
  available_space=$(df / | awk 'NR==2 {print $4}')
  if [[ $available_space -lt 2097152 ]]; then
    echo -e "\033[0;31mError: Insufficient disk space! At least 2GB free space is required.\033[0m"
    exit 1
  fi
}
check_system_requirements

# Prompt for sudo password now, so we can run subsequent commands
if [ "$DRY_RUN" = false ]; then
  sudo -v || { echo -e "\033[0;31mSudo privileges are required to continue.\033[0m"; exit 1; }
fi

# --- UI and Menu ---
debian_header() {
    echo -e "${RESET}"
cat << "EOF"
 _____       _     _             _____           _        _ _
|  __ \     | |   (_)           |_   _|         | |      | | |
| |  | | ___| |__  _  __ _ _ __   | |  _ __  ___| |_ __ _| | | ___ _ __
| |  | |/ _ \ '_ \| |/ _` | '_ \  | | | '_ \/ __| __/ _` | | |/ _ \ '__|
| |__| |  __/ |_) | | (_| | | | |_| |_| | | \__ \ || (_| | | |  __/ |
|_____/ \___|_.__/|_|\__,_|_| |_|_____|_| |_|___/\__\__,_|_|_|\___|_|

EOF
    echo -e "${RESET}"
}
debian_header

show_menu
export INSTALL_MODE

# Dry-run mode banner
if [ "$DRY_RUN" = true ]; then
  print_header "DRY-RUN MODE ENABLED" "No changes will be made to your system."
  sleep 2
fi

# Keep sudo alive
if [ "$DRY_RUN" = false ]; then
  while true; do sudo -n true; sleep 60; kill -0 "$$" || exit; done 2>/dev/null &
  SUDO_KEEPALIVE_PID=$!
  trap 'kill $SUDO_KEEPALIVE_PID 2>/dev/null; save_log_on_exit' EXIT INT TERM
else
  trap 'save_log_on_exit' EXIT INT TERM
fi

# --- State Management ---
STATE_FILE="$HOME/.debianinstaller.state"
mkdir -p "$(dirname "$STATE_FILE")"

mark_step_complete() {
  echo "$1" >> "$STATE_FILE"
}

is_step_complete() {
  [ -f "$STATE_FILE" ] && grep -q "^$1$" "$STATE_FILE"
}

save_log_on_exit() {
  {
    echo ""
    echo "=========================================="
    echo "Installation ended: $(date)"
    echo "=========================================="
  } >> "$INSTALL_LOG"
}

# --- Main Installation Steps ---
TOTAL_STEPS=9
print_header "Starting Debian System Installation" \
  "This process may take 10-20 minutes depending on your internet speed."

# Step 1: System Preparation
if ! is_step_complete "system_preparation"; then
  print_step_header 1 "$TOTAL_STEPS" "System Preparation"
  (cd "$SCRIPTS_DIR" && source "./system_preparation.sh")
  mark_step_complete "system_preparation"
else
  ui_info "Step 1 (System Preparation) already completed - skipping"
fi

# Step 2: Shell Setup
if ! is_step_complete "shell_setup"; then
  print_step_header 2 "$TOTAL_STEPS" "Shell Setup"
  (cd "$SCRIPTS_DIR" && source "./shell_setup.sh")
  mark_step_complete "shell_setup"
else
  ui_info "Step 2 (Shell Setup) already completed - skipping"
fi

# Step 3: Programs Installation
if ! is_step_complete "programs_installation"; then
  print_step_header 3 "$TOTAL_STEPS" "Programs Installation"
  (cd "$SCRIPTS_DIR" && source "./programs.sh")
  mark_step_complete "programs_installation"
else
  ui_info "Step 3 (Program Installation) already completed - skipping"
fi

# Step 4: Gaming Mode (only for Desktop)
if [ "$INSTALL_MODE" = "desktop" ]; then
    if ! is_step_complete "gaming_mode"; then
      print_step_header 4 "$TOTAL_STEPS" "Gaming Mode"
      (cd "$SCRIPTS_DIR" && source "./gaming_mode.sh")
      mark_step_complete "gaming_mode"
    else
      ui_info "Step 4 (Gaming Mode) already completed - skipping"
    fi
else
    mark_step_complete "gaming_mode"
fi

# Step 5: Desktop Shortcuts (only for Desktop)
if [ "$INSTALL_MODE" = "desktop" ]; then
    if ! is_step_complete "shortcuts"; then
      print_step_header 5 "$TOTAL_STEPS" "Desktop Shortcuts"
      (cd "$SCRIPTS_DIR" && source "./shortcuts.sh")
      mark_step_complete "shortcuts"
    else
      ui_info "Step 5 (Desktop Shortcuts) already completed - skipping"
    fi
else
    mark_step_complete "shortcuts"
fi

# Step 6: Fail2ban Setup
if ! is_step_complete "fail2ban_setup"; then
  print_step_header 6 "$TOTAL_STEPS" "Fail2ban Setup"
  (cd "$SCRIPTS_DIR" && source "./fail2ban.sh")
  mark_step_complete "fail2ban_setup"
else
  ui_info "Step 6 (Fail2ban Setup) already completed - skipping"
fi

# Step 7: System Services
if ! is_step_complete "system_services"; then
  print_step_header 7 "$TOTAL_STEPS" "System Services"
  (cd "$SCRIPTS_DIR" && source "./system_services.sh")
  mark_step_complete "system_services"
else
  ui_info "Step 7 (System Services) already completed - skipping"
fi

# Step 8: Maintenance
if ! is_step_complete "maintenance"; then
  print_step_header 8 "$TOTAL_STEPS" "Maintenance"
  (cd "$SCRIPTS_DIR" && source "./maintenance.sh")
  mark_step_complete "maintenance"
else
  ui_info "Step 8 (Maintenance) already completed - skipping"
fi

# Step 9: Apply Custom Configurations (ALWAYS RUNS)
print_step_header 9 "$TOTAL_STEPS" "Applying Custom Configurations"
(cd "$SCRIPTS_DIR" && source "./apply_configs.sh")

# --- Finalization ---
if [ "$DRY_RUN" = true ]; then
  print_header "Dry-Run Preview Completed" "No changes were made."
else
  print_header "Installation Completed"
fi

echo ""
echo -e "\033[0;33mWhat's been set up for you:\033[0m"
echo -e "  - An enhanced ZSH shell with Starship and auto-completion"
echo -e "  - Security features (UFW firewall & Fail2ban SSH protection)"
echo -e "  - System services enabled for performance (like fstrim for SSDs)"

if [ "$INSTALL_MODE" = "desktop" ]; then
    echo -e "  - A fully configured Desktop environment"
    echo -e "  - Essential applications and media codecs (VLC, ffmpeg)"
    echo -e "  - Nerd Fonts for a better terminal experience"
    if is_step_complete "shortcuts"; then
        echo -e "  - Universal shortcuts (Meta+Enter for terminal, Meta+Q to close window)"
    fi
    if is_step_complete "gaming_mode" && dpkg-query -W -f='${Status}' "steam-installer" 2>/dev/null | grep -q "ok installed"; then
        echo -e "  - Gaming tools installed (Steam, Lutris, Discord, etc.)"
    fi
fi

if [ "$INSTALL_MODE" = "server" ]; then
    echo -e "  - A fully configured Server environment"
    echo -e "  - Core server utilities (OpenSSH, Samba)"
    if dpkg-query -W -f='${Status}' "docker.io" 2>/dev/null | grep -q "ok installed"; then
        echo -e "  - Docker Engine for containerization"
        if [ "$DRY_RUN" = false ] && sudo docker ps -a --format '{{.Names}}' | grep -q "portainer"; then
            echo -e "  - Portainer for Docker management"
        fi
    fi
fi

echo -e "\n\033[1;33mIMPORTANT:\033[0m To see your new shell prompt and use the new aliases,"
echo -e "you must \033[1;32mlog out and log back in\033[0m or start a new terminal session."
echo ""

print_summary
log_performance "Total installation time"

# Handle installation results
if [ ${#ERRORS[@]} -eq 0 ]; then
  ui_success "All steps completed successfully"
  ui_info "Installation log saved to: $INSTALL_LOG"
else
  ui_warn "Some non-critical errors occurred during installation:"
  for error in "${ERRORS[@]}"; do
      ui_error "  - $error"
  done
  ui_info "Please check the log file for more details: $INSTALL_LOG"
  ui_info "You can run the installer again to resume from the last successful step."
fi

prompt_reboot
