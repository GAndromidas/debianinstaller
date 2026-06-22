#!/bin/bash
# ============================================================================
# Legacy Compatibility Layer
# Sources the modular lib/*.sh files with guarded redefinitions.
# Kept for backward compatibility with existing step scripts.
# ============================================================================

# Source the modular library files (only if not already loaded by install.sh)
if [ -z "${DEBIAN_INSTALLER_LIBS_LOADED:-}" ]; then
    SCRIPT_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib"

    if [ ! -d "$SCRIPT_LIB_DIR" ]; then
        echo "ERROR: Library directory not found: $SCRIPT_LIB_DIR"
        exit 1
    fi

    source "$SCRIPT_LIB_DIR/core.sh"
    source "$SCRIPT_LIB_DIR/ui.sh"
    source "$SCRIPT_LIB_DIR/system.sh"
    source "$SCRIPT_LIB_DIR/package.sh"
    source "$SCRIPT_LIB_DIR/config.sh"
    source "$SCRIPT_LIB_DIR/dashboard.sh"
fi

# ============================================================================
# Show Menu with gum support (legacy compat, duplicates lib/ui.sh for safety)
# ============================================================================
if ! declare -f show_menu >/dev/null 2>&1; then
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
fi

if ! declare -f show_gum_menu >/dev/null 2>&1; then
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
fi

if ! declare -f show_traditional_menu >/dev/null 2>&1; then
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
fi

# ============================================================================
# Reboot Prompt (legacy compat)
# ============================================================================
if ! declare -f prompt_reboot >/dev/null 2>&1; then
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
    echo "" >&2
    gum style --foreground "$GUM_WARN" "Ready to reboot your system?" >&2 2>/dev/null || true
    echo "" >&2
    if gum confirm --default=true --prompt.foreground "$GUM_PRIMARY" --selected.background "$GUM_PRIMARY" "Reboot now?" >/dev/tty </dev/tty 2>/dev/null; then
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
fi

