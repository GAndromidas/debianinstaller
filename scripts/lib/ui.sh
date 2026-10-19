#!/bin/bash

# Include guard — safe to source multiple times via install.sh + common.sh.
if [[ -n "${_DEBIANINSTALLER_UI_SH_LOADED:-}" ]]; then
  return 0 2>/dev/null || exit 0
fi
_DEBIANINSTALLER_UI_SH_LOADED=1

# Check if gum is available
supports_gum() {
    command -v gum &>/dev/null
}

# Confirmation dialog — Yes is the default in both gum and fallback modes.
ui_confirm() {
    local question="$1"
    local description="${2:-}"

    if supports_gum; then
        if [ -n "$description" ]; then
            gum style --foreground "$GUM_WARN" "$description" </dev/tty >/dev/tty 2>/dev/tty || true
        fi
        if gum confirm --default --affirmative "Yes" --negative "No" --prompt.foreground "$GUM_PRIMARY" --selected.background "$GUM_PRIMARY" --selected.foreground "0" "$question" </dev/tty >/dev/tty 2>/dev/tty; then
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
            read -r -p "$(echo -e "${THEME_SECONDARY}${question} [Y/n]: ${RESET}")" response \
                || { echo -e "\n${THEME_WARN}Input stream closed — declining.${RESET}"; return 1; }
            response=${response,,}
            case "$response" in
                ""|y|yes) return 0 ;;
                n|no) return 1 ;;
                *) echo -e "\n${THEME_ERROR}Please answer Y (yes) or N (no).${RESET}\n" ;;
            esac
        done
    fi
}

# Styled header with bordered box
ui_header() {
    local title="$1"

    echo ""
    if [[ ! -t 1 ]]; then
        # stdout is redirected (dashboard_run: it IS the install log) — the
        # bordered box would be pure chatter in the log.
        printf '%s\n' "=== $title ==="
    elif supports_gum; then
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
    if [[ ! -t 1 ]]; then
        printf '%s\n' "$message"
    elif supports_gum; then
        gum style --foreground "$GUM_TEXT" "$message"
    else
        echo -e "${THEME_TEXT}${message}${RESET}"
    fi
}

# Success message (green)
ui_success() {
    local message="$1"
    if [[ ! -t 1 ]]; then
        printf '\u2713 %s\n' "$message"
    elif supports_gum; then
        gum style --foreground "$GUM_SUCCESS" "\u2713 $message"
    else
        echo -e "${THEME_SUCCESS}\u2713 $message${RESET}"
    fi
}

# Warning message (yellow)
ui_warn() {
    local message="$1"
    if [[ ! -t 1 ]]; then
        printf '\u26a0 %s\n' "$message"
    elif supports_gum; then
        gum style --foreground "$GUM_WARN" "\u26a0 $message"
    else
        echo -e "${THEME_WARN}\u26a0 $message${RESET}"
    fi
}

# Error message (red)
ui_error() {
    local message="$1"
    if [[ ! -t 1 ]]; then
        printf '\u2717 %s\n' "$message"
    elif supports_gum; then
        gum style --foreground "$GUM_ERROR" "\u2717 $message"
    else
        echo -e "${THEME_ERROR}\u2717 $message${RESET}"
    fi
}

# Simple banner with double-line box
simple_banner() {
    local title="$1"

    echo ""
    if [[ ! -t 1 ]]; then
        printf '%s\n' "=== $title ==="
    elif supports_gum; then
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
    if [[ ! -t 1 ]]; then
        printf '\u25b6 %s\n' "$message"
    elif supports_gum; then
        gum style --foreground "$GUM_PRIMARY" "\u25b6 $message"
    else
        echo -e "${THEME_SECONDARY}\u25b6 $message${RESET}"
    fi
    log_to_file "STEP: $message"
}

# gum_confirm: kept as an alias for compatibility with older module code —
# it was previously a byte-for-byte duplicate of ui_confirm (two sources of
# truth for the same dialog). Delegate to the single implementation.
gum_confirm() {
    ui_confirm "$@"
}

# Debian ASCII Art Banner
debian_ascii() {
  if [[ -t 1 ]]; then printf '%b' "${THEME_PRIMARY}"; fi
  cat << "EOF"
  _____       _     _             _____           _        _ _
 |  __ \     | |   (_)           |_   _|         | |      | | |
 | |  | | ___| |__  _  __ _ _ __   | |  _ __  ___| |_ __ _| | | ___ _ __
 | |  | |/ _ \ '_ \| |/ _` | '_ \  | | | '_ \/ __| __/ _` | | |/ _ \ '__|
 | |__| |  __/ |_) | | (_| | | | |_| |_| | | \__ \ || (_| | | |  __/ |
 |_____/ \___|_.__/|_|\__,_|_| |_|_____|_| |_|___/\__\__,_|_|_|\___|_|

EOF
  if [[ -t 1 ]]; then printf '%b' "${RESET}"; fi
}


