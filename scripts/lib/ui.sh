#!/bin/bash

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
            gum style --foreground "$GUM_WARN" "$description" >&2 2>/dev/null || true
        fi
        if gum confirm --default=true --prompt.foreground "$GUM_PRIMARY" --selected.background "$GUM_PRIMARY" "$question" >/dev/tty; then
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
            gum style --foreground "$GUM_WARN" "$description" >&2 2>/dev/null || true
        fi
        if gum confirm --default=true --prompt.foreground "$GUM_PRIMARY" --selected.background "$GUM_PRIMARY" "$question" >/dev/tty; then
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

# Print Functions

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
