#!/bin/bash
set -uo pipefail

# ============================================================================
# Debian Installer — UI/Theming Library
# Provides unified UI functions using gum with fallback to traditional prompts
# ============================================================================

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

# --- Color Codes (kept for backward compatibility) ---
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

# --- Global Variables ---
ERRORS=()
INSTALLED_PACKAGES=()
FAILED_PACKAGES=()
REMOVED_PACKAGES=()
START_TIME=$(date +%s)
TOTAL_STEPS=9

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

# Check if gum is available
supports_gum() {
    command -v gum &>/dev/null
}

# Unified menu function with arrow navigation
ui_menu() {
    local title="$1"
    local description="${2:-}"
    shift 2
    local options=("$@")

    if supports_gum; then
        if [ -n "$description" ]; then
            gum style --foreground "$GUM_WARN" --margin "1 0" "$description"
            echo ""
        fi
        gum choose --header="$title" --cursor.foreground "$GUM_PRIMARY" --selected.foreground "$GUM_PRIMARY" "${options[@]}"
    else
        echo ""
        echo -e "${THEME_HEADER}$title${RESET}"
        if [ -n "$description" ]; then
            echo -e "${THEME_MUTED}$description${RESET}"
        fi
        echo ""
        local i=1
        for opt in "${options[@]}"; do
            echo -e "  ${THEME_SECONDARY}$i)${RESET} $opt"
            ((i++))
        done
        echo ""
        local selection
        while true; do
            read -r -p "$(echo -e "${THEME_SECONDARY}Select option [1-$((i-1))]: ${RESET}")" selection
            if [[ "$selection" =~ ^[0-9]+$ ]] && [ "$selection" -ge 1 ] && [ "$selection" -le "$((i-1))" ]; then
                echo "${options[$((selection-1))]}"
                return 0
            fi
            echo -e "${THEME_ERROR}Invalid selection. Try again.${RESET}"
        done
    fi
}

# Multi-select menu for custom packages
ui_multiselect() {
    local title="$1"
    shift
    local options=("$@")

    if supports_gum; then
        gum choose --header="$title" --no-limit --cursor.foreground "$GUM_PRIMARY" --selected.foreground "$GUM_PRIMARY" "${options[@]}"
    else
        echo ""
        echo -e "${THEME_HEADER}$title${RESET}"
        echo -e "${THEME_MUTED}(Enter numbers space-separated)${RESET}"
        echo ""
        local i=1
        for opt in "${options[@]}"; do
            echo -e "  [ ] $i) $opt"
            ((i++))
        done
        echo ""
        local selection
        read -r -p "$(echo -e "${THEME_SECONDARY}Enter numbers (space-separated): ${RESET}")" selection
        for num in $selection; do
            if [[ "$num" =~ ^[0-9]+$ ]] && [ "$num" -ge 1 ] && [ "$num" -le "$((i-1))" ]; then
                echo "${options[$((num-1))]}"
            fi
        done
    fi
}

# Confirmation dialog
ui_confirm() {
    local question="$1"
    local description="${2:-}"

    if supports_gum; then
        if [ -n "$description" ]; then
            gum style --foreground "$GUM_WARN" "$description"
        fi
        if gum confirm --default=true --prompt.foreground "$GUM_PRIMARY" --selected.background "$GUM_PRIMARY" "$question"; then
            return 0
        else
            return 1
        fi
    else
        echo ""
        if [ -n "$description" ]; then
            echo -e "${THEME_WARN}${description}${RESET}"
        fi
        local response
        while true; do
            read -r -p "$(echo -e "${THEME_SECONDARY}${question} [Y/n]: ${RESET}")" response
            response=${response,,}
            case "$response" in
                ""|y|yes) return 0 ;;
                n|no) return 1 ;;
                *) echo -e "\n${THEME_ERROR}Please answer Y (yes) or N (no).${RESET}\n" ;;
            esac
        done
    fi
}

# Progress spinner for long operations
ui_spinner() {
    local message="$1"
    shift
    local command=("$@")

    if supports_gum; then
        gum spin --spinner dot --title="$message" -- "${command[@]}"
    else
        echo -e "${THEME_TEXT}$message...${RESET}"
        "${command[@]}"
    fi
}

# Progress bar for batch operations
ui_progress() {
    local total="$1"
    local current="$2"
    local message="$3"

    if supports_gum; then
        local percent=$((current * 100 / total))
        gum format --template "progress" \
            --field "value:$percent" \
            --field "message:$message" \
            <<< "$message"
    else
        local bar_width=40
        local filled=$((current * bar_width / total))
        local empty=$((bar_width - filled))
        printf "\r${THEME_SECONDARY}%s${RESET} [%s%s] %d/%d" \
            "$message" \
            "$(printf '#%.0s' $(seq 1 $filled))" \
            "$(printf ' %.0s' $(seq 1 $empty))" \
            "$current" "$total"
    fi
}

# Styled header with bordered box
ui_header() {
    local title="$1"

    echo ""
    if supports_gum; then
        gum style --border normal --margin "1 2" --padding "1 2" --align center --foreground "$GUM_HEADER" "$title"
    else
        __print_top_border
        __print_border_line "${THEME_HEADER}${title}${RESET}"
        __print_bottom_border
    fi
    echo ""
}

# Info message (white)
ui_info() {
    local message="$1"
    if supports_gum; then
        gum style --foreground "$GUM_TEXT" "$message"
    else
        echo -e "${THEME_TEXT}$message${RESET}"
    fi
}

# Success message (green)
ui_success() {
    local message="$1"
    if supports_gum; then
        gum style --foreground "$GUM_SUCCESS" "✓ $message"
    else
        echo -e "${THEME_SUCCESS}✓ $message${RESET}"
    fi
}

# Warning message (yellow)
ui_warn() {
    local message="$1"
    if supports_gum; then
        gum style --foreground "$GUM_WARN" "⚠ $message"
    else
        echo -e "${THEME_WARN}⚠ $message${RESET}"
    fi
}

# Error message (red)
ui_error() {
    local message="$1"
    if supports_gum; then
        gum style --foreground "$GUM_ERROR" "✗ $message"
    else
        echo -e "${THEME_ERROR}✗ $message${RESET}"
    fi
}

# Input prompt
ui_input() {
    local prompt="$1"
    local default="${2:-}"

    if supports_gum; then
        gum input --prompt="$prompt" --prompt.foreground "$GUM_PRIMARY" --value="$default"
    else
        local response
        read -r -p "$(echo -e "${THEME_SECONDARY}${prompt}${RESET}")" response
        echo "${response:-$default}"
    fi
}

# Password input
ui_password() {
    local prompt="$1"

    if supports_gum; then
        gum input --password --prompt="$prompt" --prompt.foreground "$GUM_PRIMARY"
    else
        local response
        read -r -s -p "$(echo -e "${THEME_SECONDARY}${prompt}${RESET}")" response
        echo ""
        echo "$response"
    fi
}

# Simple banner with double-line box
simple_banner() {
    local title="$1"

    echo ""
    if supports_gum; then
        gum style --border double --align center --padding "1 2" --foreground "$GUM_HEADER" "$title"
    else
        __print_thick_top_border
        __print_thick_border_line "${THEME_HEADER}  ${title}${RESET}"
        __print_thick_bottom_border
    fi
    echo ""
}

# Step indicator
step() {
    local message="$1"
    if supports_gum; then
        gum style --foreground "$GUM_PRIMARY" "▶ $message"
    else
        echo -e "${THEME_SECONDARY}▶ $message${RESET}"
    fi
    log_to_file "STEP: $message"
}

# gum_confirm: user confirmation with gum (or fallback)
gum_confirm() {
    local question="$1"
    local description="${2:-}"

    if supports_gum; then
        if [ -n "$description" ]; then
            gum style --foreground "$GUM_WARN" "$description" >/dev/tty 2>/dev/null || true
        fi
        if gum confirm --default=true --prompt.foreground "$GUM_PRIMARY" --selected.background "$GUM_PRIMARY" "$question"; then
            return 0
        else
            return 1
        fi
    else
        echo ""
        if [ -n "$description" ]; then
            echo -e "${THEME_WARN}${description}${RESET}"
        fi
        local response
        while true; do
            read -r -p "$(echo -e "${THEME_SECONDARY}${question} [Y/n]: ${RESET}")" response
            response=${response,,}
            case "$response" in
                ""|y|yes) return 0 ;;
                n|no) return 1 ;;
                *) echo -e "\n${THEME_ERROR}Please answer Y (yes) or N (no).${RESET}\n" ;;
            esac
        done
    fi
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

# ============================================================================
# Dashboard Module — Professional wizard-style installation display
# ============================================================================

DASHBOARD_START_TIME=0
DASHBOARD_STEP_TIMES=()
DASHBOARD_STEP_NAMES=()
DASHBOARD_STEP_STATUSES=()
DASHBOARD_STEP_ROWS=()
DASHBOARD_INNER_W=60
DASHBOARD_CURRENT_STEP=0
DASHBOARD_STEP_START=0
DASHBOARD_FRAME_END=0
DASHBOARD_ROW_OFFSET=0

dashboard_init() {
    clear
    DASHBOARD_START_TIME=$(date +%s)
    DASHBOARD_STEP_TIMES=()
    DASHBOARD_STEP_NAMES=()
    DASHBOARD_STEP_STATUSES=()
    DASHBOARD_STEP_ROWS=()
    DASHBOARD_ROW_OFFSET=0

    local total=${TOTAL_STEPS:-9}
    local cols
    cols=$(tput cols 2>/dev/null || echo 80)
    local w=$((cols - 4))
    (( w < 50 )) && w=50
    (( w > 120 )) && w=120
    DASHBOARD_INNER_W=$w

    local row=0

    # Top border
    echo -e "${THEME_BORDER}  ┌$(printf '─%.0s' $(seq 1 $w))┐${RESET}"
    row=1

    # Title line
    local title="● Debian Installer"
    local step_info="Step 1/${total}"
    local title_pad=$((w - ${#title} - ${#step_info} - 3))
    (( title_pad < 1 )) && title_pad=1
    printf "${THEME_BORDER}  │${RESET} ${THEME_HEADER}%s${RESET}%*s ${THEME_MUTED}%s${RESET} ${THEME_BORDER}│${RESET}\n" \
        "$title" $title_pad "" "$step_info"
    row=2

    # Separator
    echo -e "${THEME_BORDER}  ├$(printf '─%.0s' $(seq 1 $w))┤${RESET}"

    # Progress bar line (cleared, will be updated by dashboard_step)
    echo -e "${THEME_BORDER}  │${RESET}$(printf '%*s' $w '')${THEME_BORDER}│${RESET}"
    row=4

    # Separator
    echo -e "${THEME_BORDER}  ├$(printf '─%.0s' $(seq 1 $w))┤${RESET}"
    row=5

    # Step lines
    local name_w=$((w - 10))
    for ((i = 1; i <= total; i++)); do
        DASHBOARD_STEP_ROWS[$i]=$row
        printf "${THEME_BORDER}  │${RESET}  %2d  ○ %-${name_w}s  ${THEME_BORDER}│${RESET}\n" \
            "$i" "Pending"
        ((row++))
    done

    # Bottom separator
    echo -e "${THEME_BORDER}  ├$(printf '─%.0s' $(seq 1 $w))┤${RESET}"
    ((row++))

    # Info line
    local log_info="Log: $INSTALL_LOG"
    local cancel_info="Ctrl+C to cancel"
    local info_pad=$((w - ${#log_info} - ${#cancel_info} - 3))
    (( info_pad < 1 )) && info_pad=1
    printf "${THEME_BORDER}  │${RESET} ${THEME_MUTED}%s${RESET}%*s ${THEME_MUTED}%s${RESET} ${THEME_BORDER}│${RESET}\n" \
        "$log_info" $info_pad "" "$cancel_info"
    ((row++))

    # Bottom border
    echo -e "${THEME_BORDER}  └$(printf '─%.0s' $(seq 1 $w))┘${RESET}"
    DASHBOARD_FRAME_END=$row

    tput cup $((DASHBOARD_ROW_OFFSET + DASHBOARD_FRAME_END + 1)) 0
}

dashboard_step() {
    local name=$1 num=$2
    local total=${TOTAL_STEPS:-9}
    local w=$DASHBOARD_INNER_W

    DASHBOARD_CURRENT_STEP=$num
    DASHBOARD_STEP_NAMES[$num]="$name"
    DASHBOARD_STEP_TIMES[$num]=0
    DASHBOARD_STEP_STATUSES[$num]="running"

    local pct=$(( (num - 1) * 100 / total ))

    local bar_w=$((w * 2 / 5))
    (( bar_w < 15 )) && bar_w=15
    (( bar_w > 50 )) && bar_w=50
    local filled=$(( pct * bar_w / 100 ))
    (( filled < 0 )) && filled=0
    (( filled > bar_w )) && filled=$bar_w

    local bar=""
    local i
    for ((i=0; i<filled; i++)); do bar+="█"; done
    for ((i=filled; i<bar_w; i++)); do bar+="░"; done

    local title="● Debian Installer"
    local step_info="Step ${num}/${total}"
    local title_pad=$((w - ${#title} - ${#step_info} - 3))
    (( title_pad < 1 )) && title_pad=1
    tput cup $((DASHBOARD_ROW_OFFSET + 1)) 0
    tput el
    printf "${THEME_BORDER}  │${RESET} ${THEME_HEADER}%s${RESET}%*s ${THEME_MUTED}%s${RESET} ${THEME_BORDER}│${RESET}" \
        "$title" $title_pad "" "$step_info"

    local name_w=$((w - 11 - bar_w))
    (( name_w < 1 )) && name_w=1
    local disp_name="$name"
    (( ${#disp_name} > name_w )) && disp_name="${disp_name:0:$((name_w-1))}…"
    tput cup $((DASHBOARD_ROW_OFFSET + 3)) 0
    tput el
    printf "${THEME_BORDER}  │${RESET}  ${THEME_SUCCESS}%s${RESET}  ${THEME_TEXT}%-*s${RESET} %3d%%${RESET}  ${THEME_BORDER}│${RESET}" \
        "$bar" $name_w "$disp_name" $pct

    local name_w2=$((w - 10))
    local step_row="${DASHBOARD_STEP_ROWS[$num]}"
    tput cup $((DASHBOARD_ROW_OFFSET + step_row)) 0
    tput el
    printf "${THEME_BORDER}  │${RESET}  %2d  ● %-${name_w2}s  ${THEME_BORDER}│${RESET}" \
        "$num" "Running..."

    tput cup $((DASHBOARD_ROW_OFFSET + DASHBOARD_FRAME_END + 1)) 0

    DASHBOARD_STEP_START=$(date +%s)
}

dashboard_run() {
    local script_path=$1

    source "$script_path" >> "$INSTALL_LOG"
    local ret=$?
    return $ret
}

dashboard_ok() {
    local elapsed=0
    [ "$DASHBOARD_STEP_START" -gt 0 ] && elapsed=$(($(date +%s) - DASHBOARD_STEP_START))
    local num=$DASHBOARD_CURRENT_STEP
    local w=$DASHBOARD_INNER_W
    DASHBOARD_STEP_STATUSES[$num]="ok"
    DASHBOARD_STEP_TIMES[$num]=$elapsed

    local time_str="$(format_time $elapsed)"
    local step_row="${DASHBOARD_STEP_ROWS[$num]}"
    local name="${DASHBOARD_STEP_NAMES[$num]}"

    local name_w=$((w - 17))
    tput cup $((DASHBOARD_ROW_OFFSET + step_row)) 0
    tput el
    printf "${THEME_BORDER}  │${RESET}  %2d  ${THEME_SUCCESS}✓${RESET} %-${name_w}s ${THEME_MUTED}%6s${RESET}  ${THEME_BORDER}│${RESET}" \
        "$num" "$name" "$time_str"

    tput cup $((DASHBOARD_ROW_OFFSET + DASHBOARD_FRAME_END + 1)) 0
}

dashboard_fail() {
    local elapsed=0
    [ "$DASHBOARD_STEP_START" -gt 0 ] && elapsed=$(($(date +%s) - DASHBOARD_STEP_START))
    local num=$DASHBOARD_CURRENT_STEP
    local w=$DASHBOARD_INNER_W
    DASHBOARD_STEP_STATUSES[$num]="fail"
    DASHBOARD_STEP_TIMES[$num]=$elapsed

    local time_str="$(format_time $elapsed)"
    local step_row="${DASHBOARD_STEP_ROWS[$num]}"
    local name="${DASHBOARD_STEP_NAMES[$num]}"

    local name_w=$((w - 17))
    tput cup $((DASHBOARD_ROW_OFFSET + step_row)) 0
    tput el
    printf "${THEME_BORDER}  │${RESET}  %2d  ${THEME_ERROR}✗${RESET} %-${name_w}s ${THEME_MUTED}%6s${RESET}  ${THEME_BORDER}│${RESET}" \
        "$num" "$name" "$time_str"

    tput cup $((DASHBOARD_ROW_OFFSET + DASHBOARD_FRAME_END + 1)) 0
}

dashboard_skip() {
    local msg="${1:-Already completed}"
    local num=$DASHBOARD_CURRENT_STEP
    local w=$DASHBOARD_INNER_W
    DASHBOARD_STEP_STATUSES[$num]="skip"
    DASHBOARD_STEP_TIMES[$num]=0

    local step_row="${DASHBOARD_STEP_ROWS[$num]}"

    local name_w=$((w - 10))
    local disp_msg="$msg"
    (( ${#disp_msg} > name_w )) && disp_msg="${disp_msg:0:$((name_w-1))}…"

    tput cup $((DASHBOARD_ROW_OFFSET + step_row)) 0
    tput el
    printf "${THEME_BORDER}  │${RESET}  %2d  ${THEME_MUTED}◇${RESET} %-${name_w}s  ${THEME_BORDER}│${RESET}" \
        "$num" "$disp_msg"

    tput cup $((DASHBOARD_ROW_OFFSET + DASHBOARD_FRAME_END + 1)) 0
}

dashboard_finish() {
    clear

    local total=${TOTAL_STEPS:-9}
    local success=0 fail=0 skip=0

    for ((i = 1; i <= total; i++)); do
        [[ -v DASHBOARD_STEP_STATUSES[$i] ]] || continue
        case "${DASHBOARD_STEP_STATUSES[$i]}" in
            ok)   ((success++)) ;;
            fail) ((fail++)) ;;
            skip) ((skip++)) ;;
        esac
    done

    local wall_time=$(( $(date +%s) - DASHBOARD_START_TIME ))
    local cols
    cols=$(tput cols 2>/dev/null || echo 80)
    local w=$((cols - 4))
    (( w < 50 )) && w=50
    (( w > 120 )) && w=120

    local title
    if [ "$fail" -gt 0 ]; then
        title="Installation Completed — ${fail} step(s) failed"
    else
        title="Installation Complete"
    fi

    echo -e "${THEME_BORDER}  ╔$(printf '═%.0s' $(seq 1 $w))╗${RESET}"
    local title_pad=$(( (w - ${#title}) / 2 ))
    (( title_pad < 1 )) && title_pad=1
    printf "${THEME_BORDER}  ║${RESET}%*s${THEME_HEADER}%s${RESET}%*s${THEME_BORDER}║${RESET}\n" \
        $title_pad '' "$title" $((w - title_pad - ${#title})) ''
    echo -e "${THEME_BORDER}  ╚$(printf '═%.0s' $(seq 1 $w))╝${RESET}"
    echo ""

    for ((i = 1; i <= total; i++)); do
        [[ -v DASHBOARD_STEP_STATUSES[$i] ]] || continue
        local name="${DASHBOARD_STEP_NAMES[$i]}"
        local st="${DASHBOARD_STEP_STATUSES[$i]}"
        local tm="${DASHBOARD_STEP_TIMES[$i]}"
        local icon color
        case "$st" in
            ok)   icon="✓"; color="$THEME_SUCCESS" ;;
            fail) icon="✗"; color="$THEME_ERROR" ;;
            skip) icon="◇"; color="$THEME_MUTED" ;;
            *)    icon="?"; color="$THEME_MUTED" ;;
        esac
        local time_str
        if [ "$st" = "skip" ]; then
            time_str="  --  "
        else
            time_str="$(format_time $tm)"
            time_str=$(printf "%6s" "$time_str")
        fi
        printf "${color}  %s  Step %2d: %-28s${THEME_MUTED} %s${RESET}\n" \
            "$icon" "$i" "$name" "$time_str"
    done

    echo ""
    echo -e "${THEME_MUTED}  $(printf '─%.0s' $(seq 1 $w))${RESET}"
    echo ""
    echo -e "${THEME_TEXT}    ${success} completed, ${fail} failed, ${skip} skipped  |  Total: $(format_time $wall_time)${RESET}"
    echo ""

    log_to_file "Installation finished. $success completed, $fail failed, $skip skipped in $(format_time $wall_time)"
}

# ============================================================================
# Debian ASCII Art Banner
# ============================================================================
debian_ascii() {
  echo -e "${THEME_PRIMARY}"
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

# ============================================================================
# Logging Functions
# ============================================================================

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

log_success() {
  local message="$1"
  local detail="${2:-}"
  log_to_file "SUCCESS: $message"
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

log_debug() {
  local message="$1"
  if [ "${VERBOSE:-false}" = true ]; then
    log_to_file "DEBUG: $message"
    echo -e "${THEME_MUTED}[DEBUG] $message${RESET}"
  fi
}

log_both() {
  echo "$1" | tee -a "$INSTALL_LOG"
}

# ============================================================================
# Print Functions
# ============================================================================

print_header() {
  local title="$1"; shift
  if supports_gum; then
    gum style --border double --margin "1 2" --padding "1 4" --foreground "$GUM_HEADER" --border-foreground "$GUM_BORDER" "$title"
    while (( "$#" )); do
      gum style --margin "1 0 0 0" --foreground "$GUM_WARN" "$1"
      shift
    done
  else
    echo -e "${THEME_HEADER}$title${RESET}"
    echo -e "${THEME_BORDER}----------------------------------------${RESET}"
    while (( "$#" )); do
      echo -e "${THEME_TEXT}$1${RESET}"
      shift
    done
  fi
}

print_step_header() {
  local step_num="$1"; local total="$2"; local title="$3"
  if supports_gum; then
    echo ""
    gum style --border normal --margin "1 0" --padding "0 2" --foreground "$GUM_HEADER" --border-foreground "$GUM_BORDER" "Step ${step_num}/${total}: ${title}"
  else
    echo -e "${THEME_BORDER}Step ${step_num}/${total}: ${title}${RESET}"
  fi
}

print_summary() {
    echo ""
    local w=$(__term_width)
    echo -e "${THEME_BORDER}  ╔$(printf '═%.0s' $(seq 1 $((w - 4))))╗${RESET}"
    local title="Installation Summary"
    local title_pad=$(( (w - 4 - ${#title}) / 2 ))
    (( title_pad < 1 )) && title_pad=1
    printf "${THEME_BORDER}  ║${RESET}%*s${THEME_HEADER}%s${RESET}%*s${THEME_BORDER}║${RESET}\n" \
        $title_pad '' "$title" $((w - 4 - title_pad - ${#title})) ''
    echo -e "${THEME_BORDER}  ╚$(printf '═%.0s' $(seq 1 $((w - 4))))╝${RESET}"
    echo ""

    log_performance "Total execution time"

    if [ ${#INSTALLED_PACKAGES[@]} -gt 0 ]; then
        echo -e "${THEME_SUCCESS}✓ Successfully Installed Packages (${#INSTALLED_PACKAGES[@]}):${RESET}"
        printf "  %s\n" "${INSTALLED_PACKAGES[@]}"
    fi

    if [ ${#FAILED_PACKAGES[@]} -gt 0 ]; then
        echo -e "${THEME_ERROR}✗ Failed Package Installations (${#FAILED_PACKAGES[@]}):${RESET}"
        printf "  %s\n" "${FAILED_PACKAGES[@]}"
    fi

    if [ ${#REMOVED_PACKAGES[@]} -gt 0 ]; then
        echo -e "${THEME_WARN}Removed Packages:${RESET} ${REMOVED_PACKAGES[*]}"
    fi

    if [ ${#ERRORS[@]} -gt 0 ]; then
        echo -e "${THEME_ERROR}Additional Errors Encountered:${RESET}"
        for error in "${ERRORS[@]}"; do
            echo "  - $error"
        done
    fi
    echo -e "${THEME_BORDER}  ╔$(printf '═%.0s' $(seq 1 $((w - 4))))╗${RESET}"
}

# ============================================================================
# Show Menu with gum support
# ============================================================================
show_menu() {
  if is_headless_system; then
    ui_warn "Headless system detected. Only Server mode is available."
    INSTALL_MODE="server"
    echo "Installation Mode: Server - Minimal server setup"
    return
  fi

  if command -v gum >/dev/null 2>&1; then
    show_gum_menu
  else
    show_traditional_menu
  fi
}

show_gum_menu() {
  gum style --margin "1 0" --foreground "$GUM_WARN" "Your OS is: $DISTRO_NAME $DISTRO_VERSION"
  echo ""

  gum style --margin "1 0" --foreground "$GUM_WARN" "This script will transform your fresh Debian-based installation into a"
  gum style --margin "0 0 1 0" --foreground "$GUM_WARN" "fully configured, optimized system with all the tools you need!"

  local choice=$(gum choose --cursor="-> " --selected.foreground "$GUM_PRIMARY" --cursor.foreground "$GUM_PRIMARY" \
    "Desktop - Full desktop setup (recommended)" \
    "Server  - Minimal server setup (Docker, SSH, etc.)" \
    "Exit - Cancel installation")

  case "$choice" in
    "Desktop"*)
      INSTALL_MODE="desktop"
      echo "Installation Mode: Desktop - Full desktop setup"
      ;;
    "Server"*)
      INSTALL_MODE="server"
      echo "Installation Mode: Server - Minimal server setup"
      ;;
    "Exit"*)
      gum style --foreground "$GUM_WARN" "Installation cancelled. You can run this script again anytime."
      exit 0
      ;;
  esac
}

show_traditional_menu() {
  echo ""
  echo -e "${THEME_HEADER}WELCOME TO DEBIAN INSTALLER${RESET}"
  echo -e "${THEME_BORDER}----------------------------------------${RESET}"
  echo -e "${THEME_TEXT}Your OS is: $DISTRO_NAME $DISTRO_VERSION${RESET}"
  echo ""
  echo -e "${THEME_TEXT}This script will set up your Debian-based system with all the essentials!${RESET}"
  echo ""
  echo -e "${THEME_HEADER}Choose your installation mode:${RESET}"
  echo ""
  printf "  1) Desktop%-14s - Full desktop setup (recommended)\n" ""
  printf "  2) Server%-15s - Minimal server setup (Docker, SSH, etc.)\n" ""
  printf "  3) Exit%-17s - Cancel installation\n" ""
  echo ""

  while true; do
    read -r -p "$(echo -e "${THEME_SECONDARY}Enter your choice [1-3]: ${RESET}")" menu_choice
    case "$menu_choice" in
      1)
        INSTALL_MODE="desktop"
        echo -e "${THEME_SUCCESS}✓ Selected: Desktop installation${RESET}"
        break
        ;;
      2)
        INSTALL_MODE="server"
        echo -e "${THEME_SUCCESS}✓ Selected: Server installation${RESET}"
        break
        ;;
      3)
        echo -e "${THEME_WARN}Installation cancelled.${RESET}"
        exit 0
        ;;
      *)
        echo -e "${THEME_ERROR}Invalid choice! Please enter a number from 1 to 3.${RESET}"
        ;;
    esac
  done
}

# ============================================================================
# Reboot Prompt
# ============================================================================
prompt_reboot() {
  simple_banner "Reboot System"
  echo -e "${THEME_TEXT}Congratulations! Your Debian-based system is now fully configured!${RESET}"
  echo ""
  echo -e "${THEME_TEXT}What happens after reboot:${RESET}"
  echo "  - Boot screen will appear (if Plymouth was installed)"
  echo "  - Performance optimizations will be enabled"
  echo "  - All configured services will be active"
  echo ""
  echo -e "${THEME_WARN}It is strongly recommended to reboot now to apply all changes.${RESET}"
  echo ""

  if command -v gum >/dev/null 2>&1; then
    echo "" >/dev/tty 2>/dev/null || echo ""
    gum style --foreground "$GUM_WARN" "Ready to reboot your system?" >/dev/tty 2>/dev/null || true
    echo "" >/dev/tty 2>/dev/null || echo ""
    if gum confirm --default=true --prompt.foreground "$GUM_PRIMARY" --selected.background "$GUM_PRIMARY" "Reboot now?"; then
      echo ""
      echo -e "${THEME_TEXT}Rebooting your system...${RESET}"
      echo -e "${THEME_HEADER}Thank you for using Debian Installer!${RESET}"
      echo ""
      sleep 2
      sudo reboot
    else
      echo ""
      echo -e "${THEME_TEXT}Reboot skipped. You can reboot manually at any time using:${RESET}"
      echo -e "${THEME_SECONDARY}   sudo reboot${RESET}"
      echo -e "${THEME_TEXT}   Or simply restart your computer.${RESET}"
    fi
  else
    while true; do
      read -r -p "$(echo -e "${THEME_WARN}Reboot now? [Y/n]: ${RESET}")" reboot_ans
      reboot_ans=${reboot_ans,,}
      case "$reboot_ans" in
        ""|y|yes)
          echo ""
          echo -e "${THEME_TEXT}Rebooting your system...${RESET}"
          echo -e "${THEME_WARN}Thank you for using Debian Installer!${RESET}"
          echo ""
          sleep 2
          sudo reboot
          break
          ;;
        n|no)
          echo ""
          echo -e "${THEME_TEXT}Reboot skipped. You can reboot manually at any time using:${RESET}"
          echo -e "${THEME_SECONDARY}   sudo reboot${RESET}"
          echo -e "${THEME_TEXT}   Or simply restart your computer.${RESET}"
          break
          ;;
      esac
    done
  fi

  echo ""
  if [ ${#ERRORS[@]} -eq 0 ]; then
    if gum_confirm "Do you want to clean up temporary logs?" "This will remove the installation log and state file."; then
      echo -e "${THEME_TEXT}Cleaning up temporary files...${RESET}"
      rm -f "$STATE_FILE" "$INSTALL_LOG" 2>/dev/null || true
      echo -e "${THEME_SUCCESS}✓ Temporary files cleaned up${RESET}"
    else
      echo -e "${THEME_TEXT}Skipping cleanup.${RESET}"
    fi
  fi
}

# ============================================================================
# Performance & Utility Functions
# ============================================================================

log_performance() {
    local step_name="$1"
    local current_time=$(date +%s)
    local elapsed=$((current_time - START_TIME))
    local minutes=$((elapsed / 60))
    local seconds=$((elapsed % 60))
    echo -e "${THEME_TEXT}$step_name completed in ${minutes}m ${seconds}s (${elapsed}s)${RESET}"
    log_to_file "$step_name completed in ${minutes}m ${seconds}s (${elapsed}s)"
}

is_headless_system() {
  if systemctl is-active --quiet gdm 2>/dev/null || \
     systemctl is-active --quiet sddm 2>/dev/null || \
     systemctl is-active --quiet lightdm 2>/dev/null || \
     systemctl is-active --quiet lxdm 2>/dev/null || \
     systemctl is-active --quiet slim 2>/dev/null; then
    return 1
  fi
  if pgrep -x X >/dev/null 2>&1 || pgrep -x Xorg >/dev/null 2>&1; then
    return 1
  fi
  if pgrep -x weston >/dev/null 2>&1 || pgrep -x gnome-shell >/dev/null 2>&1; then
    return 1
  fi
  if [[ -n "${XDG_CURRENT_DESKTOP:-}" ]]; then
    return 1
  fi
  return 0
}

# ============================================================================
# Distribution Detection Function (unchanged)
# ============================================================================
detect_distribution() {
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        DISTRO_ID="$ID"
        DISTRO_NAME="$NAME"
        DISTRO_VERSION="$VERSION_ID"
        DISTRO_CODENAME="${VERSION_CODENAME:-}"

        export DISTRO_ID DISTRO_NAME DISTRO_VERSION DISTRO_CODENAME

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

# ============================================================================
# Package Availability Check (unchanged)
# ============================================================================
is_package_available() {
    local package="$1"
    if apt-cache show "$package" >/dev/null 2>&1; then
        return 0
    else
        return 1
    fi
}

# ============================================================================
# Distribution-Specific Package Installer (unchanged)
# ============================================================================
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

# ============================================================================
# Package Alternative Lookup (unchanged)
# ============================================================================
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

# ============================================================================
# Suppress Python warnings during package installation (unchanged)
# ============================================================================
suppress_python_warnings() {
    export PYTHONWARNINGS="ignore"
    export PYTHONPATH=""
    exec 3>&2 2> >(grep -v "SyntaxWarning\|invalid escape sequence" >&3)
}

cleanup_install_environment() {
    unset PYTHONWARNINGS
    unset APT_OPTIONS
}

# ============================================================================
# APT Package Installation (unchanged)
# ============================================================================
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
                sudo apt-get update -qq >/dev/null 2>&1 || true
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

    if sudo apt-get install -y -qq "${to_install[@]}" >/dev/null 2>&1; then
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

# ============================================================================
# Summary & Finalization
# ============================================================================

final_cleanup() {
    if [ "$DRY_RUN" = true ]; then
        ui_info "[DRY-RUN] Final cleanup would run here."
        return
    fi
    ui_info "Performing final cleanup..."

    if [ "${FIGLET_INSTALLED_BY_SCRIPT:-false}" = true ]; then
        ui_info "Removing temporary package 'figlet'..."
        sudo apt-get remove --purge -y figlet -qq >/dev/null 2>&1
    fi

    ui_info "Removing installer directory..."
    rm -rf "$SCRIPT_DIR"
    ui_success "Installer directory removed."
}
