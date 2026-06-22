#!/bin/bash

# Check if gum is available
supports_gum() {
    command -v gum &>/dev/null
}

# Confirmation dialog
ui_confirm() {
    local question="$1"
    local description="${2:-}"

    if supports_gum; then
        if [ -n "$description" ]; then
            gum style --foreground "$GUM_WARN" "$description" >&2 2>/dev/null || true
        fi
        if gum confirm --default=true --prompt.foreground "$GUM_PRIMARY" --selected.background "$GUM_PRIMARY" "$question" >/dev/tty </dev/tty 2>/dev/null; then
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
            gum style --foreground "$GUM_WARN" "$description" >&2 2>/dev/null || true
        fi
        if gum confirm --default=true --prompt.foreground "$GUM_PRIMARY" --selected.background "$GUM_PRIMARY" "$question" >/dev/tty </dev/tty 2>/dev/null; then
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

# Debian ASCII Art Banner
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


