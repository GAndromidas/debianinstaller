#!/bin/bash
set -uo pipefail

# Color Codes (kept for backward compatibility)
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
CYAN='\033[0;36m'
RESET='\033[0m'

# Theme colors — single source of truth for all UI output
readonly THEME_PRIMARY='\033[0;34m'
readonly THEME_SECONDARY='\033[1;34m'
readonly THEME_TEXT='\033[0;37m'
readonly THEME_TEXT_BOLD='\033[1;37m'
readonly THEME_SUCCESS='\033[0;32m'
readonly THEME_WARN='\033[0;33m'
readonly THEME_ERROR='\033[0;31m'
readonly THEME_MUTED='\033[0;2m'
readonly THEME_BORDER='\033[1;34m'
readonly THEME_HEADER='\033[1;37m'

# Gum color mappings for blue/white theme
readonly GUM_PRIMARY="33"
readonly GUM_SECONDARY="39"
readonly GUM_TEXT="15"
readonly GUM_SUCCESS="46"
readonly GUM_WARN="226"
readonly GUM_ERROR="196"
readonly GUM_MUTED="8"
readonly GUM_HEADER="33"
readonly GUM_BORDER="33"

# Global Variables
ERRORS=()
INSTALLED_PACKAGES=()
FAILED_PACKAGES=()
REMOVED_PACKAGES=()
TOTAL_STEPS=9

VERBOSE_MODE=false
QUIET_MODE=false
DRY_RUN=false

# Terminal helpers
__term_width() {
    tput cols 2>/dev/null || echo 80
}

__print_top_border() {
    local w=$(__term_width)
    echo -e "${THEME_BORDER}+$(printf '%*s' $((w - 2)) '' | tr ' ' '-')+${RESET}"
}

__print_bottom_border() {
    local w=$(__term_width)
    echo -e "${THEME_BORDER}+$(printf '%*s' $((w - 2)) '' | tr ' ' '-')+${RESET}"
}

__print_border_line() {
    local content="$1"
    local w=$(__term_width)
    local pad=$((w - ${#content} - 4))
    (( pad < 1 )) && pad=1
    echo -e "${THEME_BORDER}|${RESET} ${content}$(printf '%*s' $pad '') ${THEME_BORDER}|${RESET}"
}

__print_thick_top_border() {
    local w=$(__term_width)
    echo -e "${THEME_BORDER}#$(printf '%*s' $((w - 2)) '' | tr ' ' '=')#${RESET}"
}

__print_thick_bottom_border() {
    local w=$(__term_width)
    echo -e "${THEME_BORDER}#$(printf '%*s' $((w - 2)) '' | tr ' ' '=')#${RESET}"
}

__print_thick_border_line() {
    local content="$1"
    local w=$(__term_width)
    local pad=$((w - ${#content} - 4))
    (( pad < 1 )) && pad=1
    echo -e "${THEME_BORDER}#${RESET} ${content}$(printf '%*s' $pad '') ${THEME_BORDER}#${RESET}"
}

# Format time display helper
format_time() {
  local seconds=$1
  if [ $seconds -lt 60 ]; then
    echo "${seconds}s"
  elif [ $seconds -lt 3600 ]; then
    local minutes=$((seconds / 60))
    local remaining_seconds=$((seconds % 60))
    echo "${minutes}m ${remaining_seconds}s"
  else
    local hours=$((seconds / 3600))
    local minutes=$(((seconds % 3600) / 60))
    echo "${hours}h ${minutes}m"
  fi
}

# Logging Functions

log_to_file() {
  echo "$1" >> "$INSTALL_LOG" 2>/dev/null || true
}

log_info() {
  local message="$1"
  local detail="${2:-}"
  log_to_file "INFO: $message"
  if [ -n "$detail" ]; then
    log_to_file "  DETAIL: $detail"
  fi
}

log_warning() {
  local message="$1"
  local detail="${2:-}"
  log_to_file "WARNING: $message"
  if [ -n "$detail" ]; then
    log_to_file "  DETAIL: $detail"
  fi
}

log_error() {
  local message="$1"
  local detail="${2:-}"
  log_to_file "ERROR: $message"
  if [ -n "$detail" ]; then
    log_to_file "  DETAIL: $detail"
  fi
  ERRORS+=("$message")
}

log_both() {
  echo "$1" | tee -a "$INSTALL_LOG"
}

log_performance() {
    local step_name="$1"
    local current_time=$(date +%s)
    local elapsed=$((current_time - START_TIME))
    local minutes=$((elapsed / 60))
    local seconds=$((elapsed % 60))
    echo -e "${THEME_TEXT}$step_name completed in ${minutes}m ${seconds}s (${elapsed}s)${RESET}"
    log_to_file "$step_name completed in ${minutes}m ${seconds}s (${elapsed}s)"
}
