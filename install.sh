#!/bin/bash
set -uo pipefail

# Installation log and progress tracking live in /var/tmp so they survive
# reboots and resume works. Legacy $HOME locations migrate automatically.
INSTALL_LOG="${INSTALL_LOG:-/var/tmp/debianinstaller.log}"
STATE_FILE="${STATE_FILE:-/var/tmp/debianinstaller.state}"
AUTO_MODE=false
UNATTENDED=false
AUTO_CONFIRM=false
CHECK_MODE=false

# Function to show help
show_help() {
  cat << 'EOF'
Debian Installer - Debian-based Distro Post-Installation Automation

USAGE:
    ./install.sh [OPTIONS]

OPTIONS:
    -h, --help      Show this help message and exit
    -V, --version   Show version information and exit
    -v, --verbose   Enable verbose output (show all package installation details)
    -q, --quiet     Quiet mode (minimal output)
    -d, --dry-run   Preview what will be installed without making changes
    -a, --auto      Automatically select the recommended installation mode
    -y, --yes       Non-interactive mode: accept safe/default prompts automatically
    -c, --check     Read-only health check (runs scripts/verify.sh, changes nothing)

DESCRIPTION:
    Debian Installer transforms a fresh Debian, Ubuntu, Zorin OS, Pop!_OS, or
    Linux Mint installation into a fully configured, optimized system with
    intelligent hardware detection and tailored optimizations.

INSTALLATION MODES:
    Desktop         Complete setup with all recommended packages for a desktop environment.
    Server          Essential tools and services for a headless server installation.

    Gaming mode is offered as an optional step during Desktop installations.

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
    ./install.sh --auto         Automatically choose the recommended mode
    ./install.sh --yes          Run unattended with safe/default choices
    ./install.sh --help         Show this help message

LOG FILES:
    Installation log: /var/tmp/debianinstaller.log
    Progress tracking: /var/tmp/debianinstaller.state

EOF
  exit 0
}

# Get the directory where this script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPTS_DIR="$SCRIPT_DIR/scripts"
MODULES_DIR="$SCRIPTS_DIR/modules"
CONFIGS_DIR="$SCRIPT_DIR/configs"

# Parse flags before any package installation or other system side effects.
VERBOSE=false
DRY_RUN=false
for arg in "$@"; do
  case "$arg" in
    -h|--help) show_help ;;
    -V|--version) echo "DebianInstaller $(git -C "$SCRIPT_DIR" describe --tags --always --dirty 2>/dev/null || echo dev)"; exit 0 ;;
    --verbose|-v) VERBOSE=true; VERBOSE_MODE=true; QUIET_MODE=false ;;
    --quiet|-q) VERBOSE=false; VERBOSE_MODE=false; QUIET_MODE=true ;;
    --dry-run|-d) DRY_RUN=true; VERBOSE=true; VERBOSE_MODE=true; QUIET_MODE=false ;;
    --auto|-a) AUTO_MODE=true ;;
    --yes|-y) AUTO_MODE=true; UNATTENDED=true; AUTO_CONFIRM=true ;;
    --check|-c) CHECK_MODE=true ;;
    *) echo "Unknown option: $arg"; echo "Use --help for usage information"; exit 1 ;;
  esac
done

# Read-only health check: runs the post-install verifier without changing
# anything. Handled before any sourcing, sudo use, or state writes.
if [[ "$CHECK_MODE" == true ]]; then
  if [[ "$VERBOSE" == true ]]; then
    exec bash "$SCRIPT_DIR/scripts/verify.sh" --verbose
  else
    exec bash "$SCRIPT_DIR/scripts/verify.sh"
  fi
fi

# Migrate legacy $HOME log/state so resume keeps working after the move to
# /var/tmp (which persists across reboots; $HOME dotfiles remain as fallback).
if [[ ! -s "$STATE_FILE" && -s "$HOME/.debianinstaller.state" ]]; then
  cp -a "$HOME/.debianinstaller.state" "$STATE_FILE" 2>/dev/null || true
fi
if [[ ! -s "$INSTALL_LOG" && -s "$HOME/.debianinstaller.log" ]]; then
  cp -a "$HOME/.debianinstaller.log" "$INSTALL_LOG" 2>/dev/null || true
fi

# Source modular libraries once. common.sh remains a compatibility facade for
# older modules and third-party callers.
source "$SCRIPTS_DIR/lib/core.sh"
source "$SCRIPTS_DIR/lib/ui.sh"
source "$SCRIPTS_DIR/lib/system.sh"
source "$SCRIPTS_DIR/lib/package.sh"
source "$SCRIPTS_DIR/lib/config.sh"
source "$SCRIPTS_DIR/lib/state.sh"
source "$SCRIPTS_DIR/common.sh"
source "$SCRIPTS_DIR/lib/dashboard.sh"

export VERBOSE DRY_RUN INSTALL_LOG AUTO_MODE UNATTENDED AUTO_CONFIRM
export VERBOSE_MODE QUIET_MODE STATE_FILE
export SCRIPT_DIR SCRIPTS_DIR MODULES_DIR CONFIGS_DIR

# Sudo keep-alive: long runs (apt upgrades + batch installs) outlive the
# default sudo timestamp. Refresh in the background so a hidden password
# prompt never hangs a step whose stdout is redirected to the log.
# Started once after the first authenticated sudo use; killed on exit via
# save_log_on_exit / cleanup_on_error.
start_sudo_keepalive() {
  [[ "${DRY_RUN:-false}" == true ]] && return 0
  if [[ -n "${SUDO_KEEPALIVE_PID:-}" ]] && kill -0 "$SUDO_KEEPALIVE_PID" 2>/dev/null; then
    return 0
  fi
  if ! sudo -n true 2>/dev/null; then
    return 1
  fi
  ( while true; do sudo -n true 2>/dev/null; sleep 50; kill -0 $$ 2>/dev/null || exit 0; done ) &
  SUDO_KEEPALIVE_PID=$!
  export SUDO_KEEPALIVE_PID
}

stop_sudo_keepalive() {
  if [[ -n "${SUDO_KEEPALIVE_PID:-}" ]]; then
    kill "$SUDO_KEEPALIVE_PID" 2>/dev/null || true
    unset SUDO_KEEPALIVE_PID
  fi
}

# Install gum only when we are actually going to modify the system. Dry-run is
# guaranteed not to install helpers or alter the target machine.
if [[ "$DRY_RUN" != true ]] && ! command -v gum >/dev/null 2>&1; then
  # log_to_file needs INSTALL_LOG set; core.sh leaves that to the caller.
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] Installing gum for enhanced UI experience..." >> "$INSTALL_LOG" 2>/dev/null || true
  if sudo apt-get install -y -qq gum >>"$INSTALL_LOG" 2>&1; then
    echo "Gum installed successfully" >> "$INSTALL_LOG" 2>/dev/null || true
  else
    echo "Gum not in repos, trying GitHub release..." >> "$INSTALL_LOG" 2>/dev/null || true
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
    if [ -f /tmp/gum.deb ] && sudo dpkg -i /tmp/gum.deb >>"$INSTALL_LOG" 2>&1; then
      echo "Gum installed from GitHub release" >> "$INSTALL_LOG" 2>/dev/null || true
    else
      echo "Failed to install gum, falling back to basic UI" >> "$INSTALL_LOG" 2>/dev/null || true
    fi
    rm -f /tmp/gum.deb
  fi
fi

# Authenticate once up front so keep-alive can run non-interactively after.
if [[ "$DRY_RUN" != true ]]; then
  ui_info "Please enter your sudo password to begin the installation:"
  sudo -v || { ui_error "Sudo required. Exiting."; exit 1; }
  start_sudo_keepalive || true
else
  ui_info "Dry-run mode: Skipping sudo authentication"
fi

init_core
START_TIME_SEC=$SECONDS
START_TIME=$(date +%s)
export START_TIME_SEC START_TIME

# Clear the terminal only after options are parsed.
if [[ -t 1 ]] && [[ "${TERM:-dumb}" != dumb ]]; then clear; fi

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

  # Report EVERY GPU (not just head -1): hybrids (integrated + discrete)
  # are common and head -1 would hide the second vendor.
  if command -v lspci >/dev/null 2>&1 && lspci | grep -qiE 'vga|3d controller|display controller'; then
    local gpu_lines
    gpu_lines=$(lspci | grep -iE 'vga|3d controller|display controller' || true)
    log_to_file "GPU(s) detected:"
    while IFS= read -r gpu_info; do
      [[ -z "$gpu_info" ]] && continue
      case "$gpu_info" in
        *NVIDIA*)         log_to_file "  NVIDIA GPU: $gpu_info - proprietary drivers will be configured" ;;
        *"AMD"*|*Radeon*|*ATI*) log_to_file "  AMD GPU: $gpu_info - open-source drivers will be configured" ;;
        *Intel*)          log_to_file "  Intel GPU: $gpu_info - mesa drivers will be configured" ;;
        *)                log_to_file "  Unknown GPU: $gpu_info - generic drivers will be used" ;;
      esac
    done <<< "$gpu_lines"
  else
    log_to_file "No discrete GPU detected - this may be a headless or integrated-graphics system"
  fi

  log_to_file "System requirements checks passed"
}

# Run system checks — stdout goes to log, interactive prompts use /dev/tty
check_system_requirements >> "$INSTALL_LOG" 2>&1

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

if [[ "$AUTO_MODE" == true ]]; then
  if is_headless_system; then
    INSTALL_MODE="server"
  else
    INSTALL_MODE="desktop"
  fi
  ui_info "Automatic mode: selected $INSTALL_MODE installation."
else
  show_menu
fi

# Check if INSTALL_MODE was set (user might have exited menu)
if [ -z "${INSTALL_MODE:-}" ]; then
  echo "Installation cancelled."
  exit 0
fi

export INSTALL_MODE

# Default GAMING_ENABLED if not set by menu (e.g. headless system)
GAMING_ENABLED="${GAMING_ENABLED:-false}"
export GAMING_ENABLED

# State-file validation and step bookkeeping live in lib/state.sh.
validate_state_file || true

# Dry-run mode banner
if [ "$DRY_RUN" = true ]; then
  ui_header "DRY-RUN MODE ENABLED"
  ui_info "Preview mode: No changes will be made"
  ui_info "Package installations will be simulated"
  ui_info "System configurations will be previewed"
  echo ""
  sleep 2
fi

# Enhanced error handling and rollback functions
cleanup_on_error() {
  local exit_code="${1:-$?}"
  local context="${2:-}"

  if [ "$exit_code" -ne 0 ]; then
    if [ -n "$context" ]; then
      log_error "Installation ended: $context (exit code $exit_code)"
    else
      log_error "Installation failed with exit code $exit_code"
    fi
    log_error "Check the log file for details: $INSTALL_LOG"

    # Kill sudo keep-alive if running
    stop_sudo_keepalive || true

    # Check if steps actually failed — if all steps completed, don't mark as failure
    # Use state file as source of truth (more reliable than ERRORS array which runs in subshells)
    if [ -f "$STATE_FILE" ] && ! grep -q "^FAILED:" "$STATE_FILE" 2>/dev/null; then
      log_warning "All installation steps completed successfully despite external signal (exit code $exit_code)"
      return 0
    fi

    # Mark installation as failed
    INSTALLATION_SUCCESS=false

    # Offer recovery options
    echo ""
    ui_error "Installation encountered an error!"
    ui_header "Recovery Options"
    ui_info "1. Run the script again to resume from where it left off"
    ui_info "2. Check the log file: $INSTALL_LOG"
    ui_info "3. Start fresh installation: rm -f $STATE_FILE"

    # Save error state (no bogus line number — step-level FAILED lines are precise)
    echo "FAILED: Installation ended (exit code: $exit_code)${context:+ — $context}" >> "$STATE_FILE"
  fi
}

# Global installation success tracking
INSTALLATION_SUCCESS=true
INSTALLER_EXITING=false

save_log_on_exit() {
  stop_sudo_keepalive || true

  {
    echo ""
    echo "=========================================="
    echo "Installation ended: $(date)"
    echo "=========================================="

    # Determine actual installation status from state file (more reliable than
    # INSTALLATION_SUCCESS, which can be false due to external signals like
    # SIGTERM after all steps completed)
    if [ -f "$STATE_FILE" ] && grep -q "^FAILED:" "$STATE_FILE" 2>/dev/null; then
      echo "Installation completed with errors!"
      echo "Check the log above for details."
    else
      echo "Installation completed successfully!"
      local elapsed=$(( SECONDS - START_TIME_SEC ))
      (( elapsed < 0 )) && elapsed=0
      echo "Total installation time: $(format_time "$elapsed")"
    fi
  } >> "$INSTALL_LOG"
}

handle_signal() {
  local sig="$1"
  log_warning "Received $sig; stopping DebianInstaller safely."
  INSTALLATION_SUCCESS=false
  exit 130
}
trap 'handle_signal INT' INT
trap 'handle_signal TERM' TERM

on_exit() {
  local rc=$?
  if [[ "$INSTALLER_EXITING" == true ]]; then return; fi
  INSTALLER_EXITING=true
  if (( rc != 0 )); then cleanup_on_error "$rc" || true; fi
  save_log_on_exit || true
}
trap on_exit EXIT

# Installation start — enter dashboard wizard mode
# Keep the order and failure policy of the original installer while using one
# runner for every normal step. This is intentionally data-driven so adding a
# future module does not require another large copy/paste block.
run_install_step() {
  local number="$1" id="$2" name="$3" script="$4" policy="${5:-continue}"
  dashboard_step "$name" "$number"

  if is_step_complete "$id"; then
    dashboard_skip
    return 0
  fi

  if dashboard_run "$script"; then
    mark_step_complete_with_progress "$id" completed
    dashboard_ok
    return 0
  fi

  mark_step_complete_with_progress "$id" failed
  dashboard_fail
  log_error "$name failed"

  case "$policy" in
    continue)
      ui_warn "$name failed but continuing installation"
      return 0
      ;;
    ask)
      if [[ "$AUTO_CONFIRM" == true ]] || ui_confirm "$name failed. Continue with installation?" "The installer will continue, but dependent features may not work correctly."; then
        ui_warn "Continuing despite $name failure"
        return 0
      fi
      ui_error "Installation stopped due to $name failure"
      return 1
      ;;
    stop)
      ui_error "Installation stopped due to $name failure"
      return 1
      ;;
  esac
}

# Draw the wizard frame once before the first step.
dashboard_init

run_install_step 1 system_preparation "System Preparation" "$MODULES_DIR/system_preparation.sh" ask || exit 1
run_install_step 2 shell_setup "Shell Setup" "$MODULES_DIR/shell_setup.sh"
run_install_step 3 programs_installation "Programs Installation" "$MODULES_DIR/programs.sh"

# Gaming mode is opt-in via the Desktop menu (GAMING_ENABLED) and never runs
# on servers. A decline/skip is not a failure.
dashboard_step "Gaming Mode" 4
if [[ "$INSTALL_MODE" == "server" || "$GAMING_ENABLED" == "false" ]]; then
  mark_step_complete_with_progress gaming_mode skipped
  dashboard_skip "Skipped"
elif is_step_done gaming_mode; then
  dashboard_skip
else
  if dashboard_run "$MODULES_DIR/gaming_mode.sh"; then
    mark_step_complete_with_progress gaming_mode completed
    dashboard_ok
  else
    mark_step_complete_with_progress gaming_mode failed
    dashboard_fail
    log_error "Gaming Mode failed"
    ui_warn "Gaming Mode failed but continuing installation (gaming optimizations not applied)"
  fi
fi

dashboard_step "Desktop Shortcuts" 5
if [[ "$INSTALL_MODE" == "server" ]]; then
  mark_step_complete_with_progress shortcuts skipped
  dashboard_skip "Skipped — server mode"
elif is_step_complete shortcuts; then
  dashboard_skip
else
  if dashboard_run "$MODULES_DIR/shortcuts.sh"; then
    mark_step_complete_with_progress shortcuts completed
    dashboard_ok
  else
    mark_step_complete_with_progress shortcuts failed
    dashboard_fail
    log_error "Desktop Shortcuts failed"
    ui_warn "Desktop Shortcuts failed but continuing installation"
  fi
fi
run_install_step 6 fail2ban_setup "Fail2ban Setup" "$MODULES_DIR/fail2ban.sh"
run_install_step 7 system_services "System Services" "$MODULES_DIR/system_services.sh"
run_install_step 8 maintenance "Maintenance" "$MODULES_DIR/maintenance.sh"

# Apply Custom Configurations always runs (it applies the latest dotfiles and
# tweaks, so it is intentionally not skipped on resume).
dashboard_step "Apply Custom Configurations" 9
if dashboard_run "$MODULES_DIR/apply_configs.sh"; then
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
  exit 0
fi

state_clear_failures || log_warning "Could not clear stale failure markers from state file"

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
