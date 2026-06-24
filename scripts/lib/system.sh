#!/bin/bash

# Distribution Detection Variables
DISTRO_ID=""
DISTRO_NAME=""
DISTRO_VERSION=""
DISTRO_CODENAME=""
IS_DEBIAN=false
IS_UBUNTU=false
IS_MINT=false
IS_ZORIN=false
IS_POP_OS=false

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

        if [ "$ID" = "ubuntu" ]; then
            local de="${XDG_CURRENT_DESKTOP:-}"
            case "$de" in
                *KDE*)    DISTRO_NAME="Kubuntu" ;;
                *XFCE*)   DISTRO_NAME="Xubuntu" ;;
                *LXQt*)   DISTRO_NAME="Lubuntu" ;;
                *Budgie*) DISTRO_NAME="Ubuntu Budgie" ;;
                *MATE*)   DISTRO_NAME="Ubuntu MATE" ;;
                *Cinnamon*) DISTRO_NAME="Ubuntu Cinnamon" ;;
                *Unity*)  DISTRO_NAME="Ubuntu Unity" ;;
                *GNOME*)  DISTRO_NAME="Ubuntu" ;;
            esac
        fi

        ui_info "Detected: $DISTRO_NAME $DISTRO_VERSION (codename: $DISTRO_CODENAME)"
    else
        ui_error "Cannot detect distribution. /etc/os-release not found."
        return 1
    fi
}

is_package_available() {
    local package="$1"
    if apt-cache show "$package" >/dev/null 2>&1; then
        return 0
    else
        return 1
    fi
}
