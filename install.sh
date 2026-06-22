#!/bin/bash
set -uo pipefail

# Installation log file
INSTALL_LOG="$HOME/.debianinstaller.log"

# Function to show help
show_help() {
  cat << 'EOF'
Debian Installer - Debian-based Distro Post-Installation Automation

USAGE:
    ./install.sh [OPTIONS]

OPTIONS:
    -h, --help      Show this help message and exit
    -v, --verbose   Enable verbose output (show all package installation details)
    -q, --quiet     Quiet mode (minimal output)
    -d, --dry-run   Preview what will be installed without making changes

DESCRIPTION:
    Debian Installer transforms a fresh Debian, Ubuntu, Zorin OS, Pop!_OS, or
    Linux Mint installation into a fully configured, optimized system with
    intelligent hardware detection and tailored optimizations.

INSTALLATION MODES:
    Desktop         Complete setup with all recommended packages for a desktop environment.
    Server          Essential tools and services for a headless server installation.

FEATURES:
    - Hardware-aware distribution detection (Debian/Ubuntu/Mint/Zorin/Pop!_OS)
    - Automatic GPU driver detection and installation
    - Desktop environment detection and optimization
    - Security hardening (UFW + Fail2ban with SSH protection)
    - Performance tuning and system optimization
    - Zsh shell with Oh-My-Zsh and Starship prompt
    - Resume functionality for interrupted installations

REQUIREMENTS:
    - Fresh Debian-based installation (Debian, Ubuntu, Mint, etc.)
    - Active internet connection
    - Regular user account with sudo privileges
    - Minimum 2GB free disk space

EXAMPLES:
    ./install.sh                Run installer with interactive prompts
    ./install.sh --verbose      Run with detailed package installation output
    ./install.sh --dry-run      Preview changes without making them
    ./install.sh --help         Show this help message

LOG FILES:
    Installation log: ~/.debianinstaller.log
    Progress tracking: ~/.debianinstaller.state

EOF
  exit 0
}

# Clear terminal for clean interface
clear

# Get the directory where this script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPTS_DIR="$SCRIPT_DIR/scripts"
CONFIGS_DIR="$SCRIPT_DIR/configs"

# State tracking for error recovery
STATE_FILE="$HOME/.debianinstaller.state"
mkdir -p "$(dirname "$STATE_FILE")"

# Cache state file in memory to avoid repeated grep calls
# Keys: step_name => status ("completed" | "failed" | "")
declare -A COMPLETED_STEPS
load_state_cache() {
  COMPLETED_STEPS=()
  if [ -f "$STATE_FILE" ]; then
    while IFS= read -r line; do
      if [[ "$line" =~ ^(COMPLETED|FAILED):\ (.+) ]]; then
        local status="${BASH_REMATCH[1],,}"
        local step="${BASH_REMATCH[2]}"
        COMPLETED_STEPS["$step"]="$status"
      else
        COMPLETED_STEPS["$line"]="completed"
      fi
    done < "$STATE_FILE"
  fi
}
load_state_cache

# Initialize log file
{
  echo "=========================================="
  echo "Debian Installer Log"
  echo "Started: $(date)"
  echo "=========================================="
  echo ""
} > "$INSTALL_LOG"

# Source modular library files (order matters — each may depend on previous)
source "$SCRIPTS_DIR/lib/core.sh"
source "$SCRIPTS_DIR/lib/ui.sh"
source "$SCRIPTS_DIR/lib/system.sh"
source "$SCRIPTS_DIR/lib/package.sh"
source "$SCRIPTS_DIR/lib/config.sh"
source "$SCRIPTS_DIR/lib/dashboard.sh"
DEBIAN_INSTALLER_LIBS_LOADED=1

# Source legacy compatibility layer (defines show_menu, prompt_reboot, etc.)
source "$SCRIPTS_DIR/common.sh"

# Install gum silently for enhanced UI experience
if ! command -v gum >/dev/null 2>&1; then
  log_to_file "Installing gum for enhanced UI experience..."
  if sudo apt-get install -y -qq gum >/dev/null 2>&1; then
    log_to_file "Gum installed successfully"
  else
    log_to_file "Gum not in repos, trying GitHub release..."
    GUM_VERSION="0.14.5"
    case "$(uname -m)" in
      x86_64) gum_arch="amd64" ;;
      aarch64) gum_arch="arm64" ;;
      *) gum_arch="amd64" ;;
    esac
    if command -v curl >/dev/null 2>&1; then
      curl -L -o /tmp/gum.deb "https://github.com/charmbracelet/gum/releases/download/v${GUM_VERSION}/gum_${GUM_VERSION}_${gum_arch}.deb" 2>/dev/null
    elif command -v wget >/dev/null 2>&1; then
      wget -q -O /tmp/gum.deb "https://github.com/charmbracelet/gum/releases/download/v${GUM_VERSION}/gum_${GUM_VERSION}_${gum_arch}.deb"
    fi
    if [ -f /tmp/gum.deb ] && sudo dpkg -i /tmp/gum.deb >/dev/null 2>&1; then
      log_to_file "Gum installed from GitHub release"
    else
      log_to_file "Failed to install gum, falling back to basic UI"
    fi
    rm -f /tmp/gum.deb
  fi
fi

START_TIME=$(date +%s)

# Parse flags
VERBOSE=false
DRY_RUN=false
for arg in "$@"; do
  case "$arg" in
    -h|--help)
      show_help
      ;;
    --verbose|-v)
      VERBOSE=true
      VERBOSE_MODE=true
      QUIET_MODE=false
      ;;
    --quiet|-q)
      VERBOSE=false
      VERBOSE_MODE=false
      QUIET_MODE=true
      ;;
    --dry-run|-d)
      DRY_RUN=true
      VERBOSE=true
      VERBOSE_MODE=true
      QUIET_MODE=false
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
export START_TIME

# Display Debian ASCII banner
debian_ascii

# Enhanced system requirements checking
check_system_requirements() {
  local requirements_failed=false

  # Check if running as root (should not be)
  if [[ $EUID -eq 0 ]]; then
    ui_error "This script should NOT be run as root!"
    requirements_failed=true
  fi

  # Check if on Debian-based system
  if [[ ! -f /etc/debian_version ]]; then
    ui_error "This script is designed for Debian-based systems only!"
    requirements_failed=true
  fi

  # Check internet connection
  if ! ping -c 1 -W 5 debian.org &>/dev/null; then
    ui_error "No internet connection detected!"
    requirements_failed=true
  fi

  # Check disk space
  local available_space
  available_space=$(df / | awk 'NR==2 {print $4}')
  if [[ $available_space -lt 2097152 ]]; then
    ui_error "Insufficient disk space! At least 2GB free space is required."
    requirements_failed=true
  fi

  if [ "$requirements_failed" = true ]; then
    ui_error "System requirements check failed!"
    ui_info "Please address the issues listed above before continuing."
    exit 1
  fi

  log_to_file "System requirements checks passed"
}

check_system_requirements

# Source common functions and detect distribution
detect_distribution

# Check distribution compatibility
check_distribution_compatibility() {
  ui_info "Checking distribution compatibility..."

  local supported=false
  local warning_msg=""

  if [ "$IS_DEBIAN" = true ]; then
    if [[ "$DISTRO_VERSION" =~ ^(12|13|14|15)$ ]] || [[ "$DISTRO_VERSION" =~ ^[1-9][0-9]$ ]]; then
      supported=true
    else
      warning_msg="Debian $DISTRO_VERSION may not be fully supported"
    fi
  elif [ "$IS_UBUNTU" = true ]; then
    if [[ "$DISTRO_VERSION" =~ ^(22\.04|24\.04|24\.10|25\.04|25\.10|26\.04|26\.10|27\.04|27\.10|28\.04)$ ]] || \
       [[ "$DISTRO_VERSION" =~ ^[2-9][0-9]\.04$ ]] || \
       [[ "$DISTRO_VERSION" =~ ^[2-9][0-9]\.10$ ]]; then
      supported=true
    else
      warning_msg="Ubuntu $DISTRO_VERSION may not be fully supported"
    fi
  elif [ "$IS_MINT" = true ]; then
    if [[ "$DISTRO_VERSION" =~ ^(21\.x|22\.x|23\.x|24\.x)$ ]] || \
       [[ "$DISTRO_VERSION" =~ ^[2-9][0-9]\.x$ ]]; then
      supported=true
    else
      warning_msg="Linux Mint $DISTRO_VERSION may not be fully supported"
    fi
  elif [ "$IS_ZORIN" = true ]; then
    if [[ "$DISTRO_VERSION" =~ ^(16|17|18|19|20)$ ]] || \
       [[ "$DISTRO_VERSION" =~ ^[1-9][0-9]$ ]]; then
      supported=true
    else
      warning_msg="Zorin OS $DISTRO_VERSION may not be fully supported"
    fi
  elif [ "$IS_POP_OS" = true ]; then
    if [[ "$DISTRO_VERSION" =~ ^(22\.04|24\.04|24\.10|25\.04|25\.10|26\.04|26\.10|27\.04)$ ]] || \
       [[ "$DISTRO_VERSION" =~ ^[2-9][0-9]\.04$ ]] || \
       [[ "$DISTRO_VERSION" =~ ^[2-9][0-9]\.10$ ]]; then
      supported=true
    else
      warning_msg="Pop!_OS $DISTRO_VERSION may not be fully supported"
    fi
  fi

  if [ "$supported" = true ]; then
    ui_success "Distribution $DISTRO_NAME $DISTRO_VERSION is fully supported"
  else
    if [ -n "$warning_msg" ]; then
      ui_warn "$warning_msg - proceeding with caution"
    else
      ui_warn "Distribution $DISTRO_NAME $DISTRO_VERSION is not officially supported"
      ui_warn "The script will attempt to continue but may encounter issues"
    fi

    if ! ui_confirm "Continue anyway?" "Some features may not work optimally."; then
      ui_info "Installation cancelled by user"
      exit 0
    fi
  fi
}

check_distribution_compatibility

show_menu

# Check if INSTALL_MODE was set (user might have exited menu)
if [ -z "${INSTALL_MODE:-}" ]; then
  echo "Installation cancelled."
  exit 0
fi

export INSTALL_MODE

# Function to validate state file integrity
validate_state_file() {
  if [ ! -f "$STATE_FILE" ]; then
    return 0
  fi

  if [ ! -r "$STATE_FILE" ] || [ ! -s "$STATE_FILE" ]; then
    log_warning "State file is corrupted or empty. Starting fresh installation."
    rm -f "$STATE_FILE" 2>/dev/null || true
    load_state_cache
    return 1
  fi

  return 0
}

# Enhanced resume functionality
show_resume_menu() {
  if ! validate_state_file; then
    return 0
  fi

  if [ -f "$STATE_FILE" ] && [ -s "$STATE_FILE" ]; then
    echo ""
    ui_info "Previous installation detected. Checking installation status..."

    local completed_steps=()
    local step_status=()
    local has_failures=false
    local last_completed_step=""

    while IFS= read -r step; do
      completed_steps+=("$step")
      if [[ "$step" =~ ^COMPLETED: ]]; then
        step_status+=("completed")
        last_completed_step="${step#*: }"
      elif [[ "$step" =~ ^FAILED: ]]; then
        step_status+=("failed")
        has_failures=true
      else
        step_status+=("completed")
        last_completed_step="$step"
      fi
    done < "$STATE_FILE"

    if [ ${#completed_steps[@]} -eq 0 ]; then
      ui_info "No completed steps found in state file"
      return 0
    fi

    echo ""
    if supports_gum; then
      gum style --foreground "$GUM_HEADER" "Installation Progress Summary"
      echo ""
      for i in "${!completed_steps[@]}"; do
        local step="${completed_steps[$i]}"
        local status="${step_status[$i]}"
        local display_step="${step#*: }"

        case "$status" in
          "completed")
            gum style --foreground "$GUM_SUCCESS" "  [COMPLETED] $display_step" >/dev/null
            ;;
          "failed")
            gum style --foreground "$GUM_ERROR" "  [FAILED] $display_step" >/dev/null
            ;;
        esac
      done
      echo ""

      if [ "$has_failures" = true ]; then
        if gum confirm --default=true "Found failed steps. Retry failed steps first?"; then
          ui_info "Will retry failed steps during installation"
          return 0
        elif gum confirm --default=false "Resume from last completed step?"; then
          ui_success "Resuming installation from last completed step..."
          return 0
        else
          if gum confirm --default=false "Start fresh installation (this will clear previous progress)?"; then
            rm -f "$STATE_FILE" 2>/dev/null || true
            load_state_cache
            ui_info "Starting fresh installation..."
            return 0
          else
            ui_info "Installation cancelled by user"
            exit 0
          fi
        fi
      else
        if gum confirm --default=true "Resume installation from where you left off?"; then
          ui_success "Resuming installation..."
          return 0
        else
          if gum confirm --default=false "Start fresh installation (this will clear previous progress)?"; then
            rm -f "$STATE_FILE" 2>/dev/null || true
            ui_info "Starting fresh installation..."
            return 0
          else
            ui_info "Installation cancelled by user"
            exit 0
          fi
        fi
      fi
    else
      echo ""
      for i in "${!completed_steps[@]}"; do
        local step="${completed_steps[$i]}"
        local status="${step_status[$i]}"
        local display_step="${step#*: }"

        case "$status" in
          "completed")
            echo -e "${THEME_SUCCESS}[COMPLETED]${RESET} $display_step"
            ;;
          "failed")
            echo -e "${THEME_ERROR}[FAILED]${RESET} $display_step"
            ;;
        esac
      done
      echo ""

      if [ "$has_failures" = true ]; then
        echo "Found failed steps. Options:"
        echo "1. Retry failed steps first"
        echo "2. Resume from last completed step"
        echo "3. Start fresh installation"
        echo "4. Cancel"
        echo ""
        read -p "Choose an option (1-4): " choice

        case "$choice" in
          1) ui_info "Will retry failed steps during installation"; return 0 ;;
          2) ui_success "Resuming installation from last completed step..."; return 0 ;;
          3) rm -f "$STATE_FILE" 2>/dev/null || true; load_state_cache; ui_info "Starting fresh installation..."; return 0 ;;
          4) ui_info "Installation cancelled by user"; exit 0 ;;
          *) ui_warn "Invalid option. Resuming installation..."; return 0 ;;
        esac
      else
        echo "Resume installation from where you left off? (y/n)"
        read -r response
        if [[ "$response" =~ ^[Yy]$ ]]; then
          ui_success "Resuming installation..."
          return 0
        else
          echo "Start fresh installation? (y/n)"
          read -r fresh_response
          if [[ "$fresh_response" =~ ^[Yy]$ ]]; then
            rm -f "$STATE_FILE" 2>/dev/null || true
            load_state_cache
            ui_info "Starting fresh installation..."
            return 0
          else
            ui_info "Installation cancelled by user"
            exit 0
          fi
        fi
      fi
    fi
  fi
}

# Show resume menu if previous installation detected
if [ -f "$STATE_FILE" ] && [ -s "$STATE_FILE" ]; then
  show_resume_menu
fi

# Dry-run mode banner
if [ "$DRY_RUN" = true ]; then
  ui_header "DRY-RUN MODE ENABLED"
  ui_info "Preview mode: No changes will be made"
  ui_info "Package installations will be simulated"
  ui_info "System configurations will be previewed"
  echo ""
  sleep 2
fi

# Prompt for sudo
if [ "$DRY_RUN" = false ]; then
  ui_info "Please enter your sudo password to begin the installation:"
  sudo -v || { ui_error "Sudo required. Exiting."; exit 1; }
else
  ui_info "Dry-run mode: Skipping sudo authentication"
fi

# Keep sudo alive
if [ "$DRY_RUN" = false ]; then
  while true; do sudo -n true; sleep 60; kill -0 "$$" || exit; done 2>/dev/null &
  SUDO_KEEPALIVE_PID=$!
  trap 'cleanup_on_error $LINENO; save_log_on_exit' EXIT INT TERM ERR
else
  trap 'cleanup_on_error $LINENO; save_log_on_exit' EXIT INT TERM ERR
fi

# Function to mark step as completed
is_step_complete() {
  local val="${COMPLETED_STEPS["$1"]:-}"
  [ "$val" = "completed" ]
}

# Step completion with flock-protected write and cache update
mark_step_complete_with_progress() {
  local step_name="$1"
  local status="${2:-completed}"

  if [ -z "$step_name" ]; then
    log_error "mark_step_complete_with_progress: step_name cannot be empty"
    return 1
  fi

  local entry
  if [ "$status" = "completed" ]; then
    entry="COMPLETED: $step_name"
  else
    entry="FAILED: $step_name"
  fi

  (
    flock -x 200
    echo "$entry" >> "$STATE_FILE"
  ) 200>>"$STATE_FILE" 2>/dev/null || {
    echo "$entry" >> "$STATE_FILE"
  }
  COMPLETED_STEPS["$step_name"]="$status"
}

# Enhanced error handling and rollback functions
cleanup_on_error() {
  local error_line=${1:-$LINENO}
  local exit_code=${2:-$?}

  if [ $exit_code -ne 0 ]; then
    INSTALLATION_SUCCESS=false

    log_error "Installation failed with exit code $exit_code at line $error_line"
    log_error "Check the log file for details: $INSTALL_LOG"

    if [ -n "${SUDO_KEEPALIVE_PID+x}" ]; then
      kill $SUDO_KEEPALIVE_PID 2>/dev/null || true
    fi

    echo ""
    ui_error "Installation encountered an error!"
    ui_header "Recovery Options"
    ui_info "1. Run the script again to resume from where it left off"
    ui_info "2. Check the log file: $INSTALL_LOG"
    ui_info "3. Start fresh installation: rm -f $STATE_FILE"

    echo "FAILED: Installation failed at line $error_line (exit code: $exit_code)" >> "$STATE_FILE"
  fi
}

# Global installation success tracking
INSTALLATION_SUCCESS=true

# Function to save log on exit
save_log_on_exit() {
  if [ -n "${SUDO_KEEPALIVE_PID+x}" ]; then
    kill $SUDO_KEEPALIVE_PID 2>/dev/null || true
  fi

  {
    echo ""
    echo "=========================================="
    echo "Installation ended: $(date)"
    echo "=========================================="

    if [ "$INSTALLATION_SUCCESS" = "true" ]; then
      echo "Installation completed successfully!"
      echo "Total installation time: $(($(date +%s) - START_TIME)) seconds"
    else
      echo "Installation completed with errors!"
      echo "Check the log above for details."
    fi
  } >> "$INSTALL_LOG"
}

# Installation start — enter dashboard wizard mode
dashboard_init

# Step 1: System Preparation
dashboard_step "System Preparation" 1
if is_step_complete "system_preparation"; then
  dashboard_skip
else
  if dashboard_run "$SCRIPTS_DIR/system_preparation.sh"; then
    mark_step_complete_with_progress "system_preparation" "completed"
    dashboard_ok
  else
    mark_step_complete_with_progress "system_preparation" "failed"
    dashboard_fail
    log_error "System preparation failed"
    if gum_confirm "System preparation failed. Continue with installation?" "This may cause issues with subsequent steps."; then
      ui_warn "Continuing installation despite system preparation failure"
    else
      ui_error "Installation stopped due to system preparation failure"
      exit 1
    fi
  fi
fi

# Step 2: Shell Setup
dashboard_step "Shell Setup" 2
if is_step_complete "shell_setup"; then
  dashboard_skip
else
  if dashboard_run "$SCRIPTS_DIR/shell_setup.sh"; then
    mark_step_complete_with_progress "shell_setup" "completed"
    dashboard_ok
  else
    mark_step_complete_with_progress "shell_setup" "failed"
    dashboard_fail
    log_error "Shell setup failed"
    ui_warn "Shell setup failed but continuing installation"
  fi
fi

# Step 3: Programs Installation
dashboard_step "Programs Installation" 3
if is_step_complete "programs_installation"; then
  dashboard_skip
else
  if dashboard_run "$SCRIPTS_DIR/programs.sh"; then
    mark_step_complete_with_progress "programs_installation" "completed"
    dashboard_ok
  else
    mark_step_complete_with_progress "programs_installation" "failed"
    dashboard_fail
    log_error "Programs installation failed"
    ui_warn "Programs installation failed but continuing installation"
  fi
fi

# Step 4: Gaming Mode
dashboard_step "Gaming Mode" 4
if [[ "$INSTALL_MODE" == "server" ]]; then
  dashboard_skip "Skipped — server mode"
elif is_step_complete "gaming_mode"; then
  dashboard_skip
else
  if dashboard_run "$SCRIPTS_DIR/gaming_mode.sh"; then
    mark_step_complete_with_progress "gaming_mode" "completed"
    dashboard_ok
  else
    mark_step_complete_with_progress "gaming_mode" "failed"
    dashboard_fail
    log_error "Gaming Mode failed"
    ui_warn "Gaming Mode failed but continuing installation (gaming optimizations not applied)"
  fi
fi

# Step 5: Desktop Shortcuts
dashboard_step "Desktop Shortcuts" 5
if [[ "$INSTALL_MODE" == "server" ]]; then
  dashboard_skip "Skipped — server mode"
elif is_step_complete "shortcuts"; then
  dashboard_skip
else
  if dashboard_run "$SCRIPTS_DIR/shortcuts.sh"; then
    mark_step_complete_with_progress "shortcuts" "completed"
    dashboard_ok
  else
    mark_step_complete_with_progress "shortcuts" "failed"
    dashboard_fail
    log_error "Desktop Shortcuts failed"
    ui_warn "Desktop Shortcuts failed but continuing installation"
  fi
fi

# Step 6: Fail2ban Setup
dashboard_step "Fail2ban Setup" 6
if is_step_complete "fail2ban_setup"; then
  dashboard_skip
else
  if dashboard_run "$SCRIPTS_DIR/fail2ban.sh"; then
    mark_step_complete_with_progress "fail2ban_setup" "completed"
    dashboard_ok
  else
    mark_step_complete_with_progress "fail2ban_setup" "failed"
    dashboard_fail
    log_error "Fail2ban setup failed"
    ui_warn "Fail2ban setup failed but continuing installation (SSH security protection not applied)"
  fi
fi

# Step 7: System Services
dashboard_step "System Services" 7
if is_step_complete "system_services"; then
  dashboard_skip
else
  if dashboard_run "$SCRIPTS_DIR/system_services.sh"; then
    mark_step_complete_with_progress "system_services" "completed"
    dashboard_ok
  else
    mark_step_complete_with_progress "system_services" "failed"
    dashboard_fail
    log_error "System services failed"
    ui_warn "System services failed but continuing installation"
  fi
fi

# Step 8: Maintenance
dashboard_step "Maintenance" 8
if is_step_complete "maintenance"; then
  dashboard_skip
else
  if dashboard_run "$SCRIPTS_DIR/maintenance.sh"; then
    mark_step_complete_with_progress "maintenance" "completed"
    dashboard_ok
  else
    mark_step_complete_with_progress "maintenance" "failed"
    dashboard_fail
    log_error "Maintenance failed"
    ui_warn "Maintenance failed but installation completed"
  fi
fi

# Step 9: Apply Custom Configurations
dashboard_step "Apply Custom Configurations" 9
if dashboard_run "$SCRIPTS_DIR/apply_configs.sh"; then
  dashboard_ok
else
  dashboard_fail
  log_error "Apply custom configurations failed"
  ui_warn "Apply custom configurations failed but installation completed"
fi

dashboard_finish

if [ "$DRY_RUN" = true ]; then
  echo ""
  ui_info "This was a preview run. No changes were made to your system."
  ui_info "To perform the actual installation, run: ./install.sh"
  echo ""
fi

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
