#!/bin/bash

# Include guard — safe to source multiple times via install.sh + common.sh.
if [[ -n "${_DEBIANINSTALLER_PACKAGE_SH_LOADED:-}" ]]; then
  return 0 2>/dev/null || exit 0
fi
_DEBIANINSTALLER_PACKAGE_SH_LOADED=1

# Once-per-run `apt-get update` flag — previously reset per failing package,
# so a batch of N missing packages triggered N full index refreshes.
_APT_UPDATE_DONE=false

install_package_smart() {
    local packages=("$@")
    local available_packages=()
    local alternative_packages=()

    # ONE apt-cache pass for the entire candidate list, then one more for
    # the alternatives actually needed (a per-package fork loop used to pay
    # ~2 full index walks per install step). apt-cache show prints a block
    # only for resolvable names, so stdout membership == available.
    declare -A _apt_avail=()
    local _line _name
    if [ ${#packages[@]} -gt 0 ]; then
        while IFS= read -r _line; do
            [[ "$_line" == Package:\ * ]] || continue
            _name="${_line#Package: }"
            [[ -n "${_apt_avail[$_name]:-}" ]] || _apt_avail["$_name"]=1
        done < <(apt-cache -q show "${packages[@]}" 2>/dev/null)
    fi

    local _alts_probe=()
    for pkg in "${packages[@]}"; do
        if [[ -n "${_apt_avail[$pkg]:-}" ]]; then
            available_packages+=("$pkg")
        else
            local alternative
            alternative=$(get_package_alternative "$pkg")
            [ -n "$alternative" ] && _alts_probe+=("$alternative")
        fi
    done
    if [ ${#_alts_probe[@]} -gt 0 ]; then
        while IFS= read -r _line; do
            [[ "$_line" == Package:\ * ]] || continue
            _name="${_line#Package: }"
            [[ -n "${_apt_avail[$_name]:-}" ]] || _apt_avail["$_name"]=1
        done < <(apt-cache -q show "${_alts_probe[@]}" 2>/dev/null)
    fi

    for pkg in "${packages[@]}"; do
        if [[ -n "${_apt_avail[$pkg]:-}" ]]; then
            available_packages+=("$pkg")
        else
            local alternative
            alternative=$(get_package_alternative "$pkg")
            if [ -n "$alternative" ] && [[ -n "${_apt_avail[$alternative]:-}" ]]; then
                ui_warn "'$pkg' not available, using alternative '$alternative' on $DISTRO_NAME"
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
            ui_info "'$original' installed as '$replacement' on $DISTRO_NAME"
        done
    else
        ui_error "No packages from the requested list are available: ${packages[*]}"
        return 1
    fi
}

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

suppress_python_warnings() {
    # The fd-2 reroute previously ran on every apt_install call: each pass
    # replaced fd2 with a NEW grep process-substitution without restoring or
    # closing the previous one, leaking one grep per batch. Do it once per
    # shell lifetime; the filter stays for the run (desirable — python's
    # SyntaxWarning spam belongs nowhere).
    if [[ -n "${_PY_WARN_SUPPRESSED:-}" ]]; then
        return 0
    fi
    _PY_WARN_SUPPRESSED=1
    export PYTHONWARNINGS="ignore"
    export PYTHONPATH=""
    exec 3>&2 2> >(grep -v "SyntaxWarning\|invalid escape sequence" >&3)
}

cleanup_install_environment() {
    unset PYTHONWARNINGS
    unset PYTHONPATH
    unset APT_OPTIONS
}

apt_install_single() {
    local pkg="$1"
    local verbose="${2:-false}"
    local max_retries=3
    local retry_count=0

    if [[ "$verbose" = true || "$VERBOSE_MODE" = true ]]; then
        if [[ -t 1 ]]; then
            printf "${CYAN}Installing APT package:${RESET} %-30s" "$pkg"
        else
            printf 'Installing APT package: %s\n' "$pkg"
        fi
    fi

    if dpkg-query -W -f='${Status}' "$pkg" 2>/dev/null | grep -q "ok installed"; then
        [[ "$verbose" = true || "$VERBOSE_MODE" = true ]] && {
            if [[ -t 1 ]]; then
                printf "${YELLOW}\u2713 Already installed${RESET}\n"
            else
                printf '\u2713 Already installed\n'
            fi
        }
        return 0
    fi
    while [ $retry_count -lt $max_retries ]; do
        local output
        if output=$(sudo env NEEDRESTART_MODE=a DEBIAN_FRONTEND=noninteractive apt-get install -y "$pkg" 2>&1); then
            [[ "$verbose" = true || "$VERBOSE_MODE" = true ]] && {
                if [[ -t 1 ]]; then
                    printf "${GREEN}\u2713 Success${RESET}\n"
                else
                    printf '\u2713 Success\n'
                fi
            }
            INSTALLED_PACKAGES+=("$pkg")
            return 0
        else
            retry_count=$((retry_count + 1))
            if [ $retry_count -lt $max_retries ]; then
                [[ "$verbose" = true || "$VERBOSE_MODE" = true ]] &&                     printf '\u21bb Retrying (%s/%s)...\n' "$retry_count" "$max_retries"
                sleep 3
                if [ "${_APT_UPDATE_DONE:-false}" = false ]; then
                    sudo apt-get update -qq >/dev/null 2>&1 || true
                    _APT_UPDATE_DONE=true
                fi
            else
                if [[ -t 1 ]]; then
                    printf "${RED}\u2717 Failed after %s attempts${RESET}\n" "$max_retries"
                else
                    printf '\u2717 Failed after %s attempts\n' "$max_retries"
                fi
                # Diagnosable fallback failures: apt's stderr must reach the
                # install log, not just the terminal.
                printf '\n[BATCH-SINGLE FAILURE] apt-get install %s\n%s\n' "$pkg" "$output" >> "$INSTALL_LOG" 2>/dev/null || true
                if [[ "$output" == *"E:"* || "$output" == *"Error:"* ]]; then
                    echo "$output" | sed 's/^/    /' >&2
                fi
                FAILED_PACKAGES+=("$pkg")
                return 1
            fi
        fi
    done
}

apt_install() {
    local pkgs=("$@")
    declare -A _dpkg_installed=()
    local to_install=()

    # ONE dpkg-query call for the whole list — a per-package fork used to
    # dominate batch prep on large lists. Not-found names simply do not
    # appear in the output (found ones print ii-status lines).
    if [ ${#pkgs[@]} -gt 0 ]; then
        local _dline _dname _dabbrev
        while IFS=$'\t' read -r _dabbrev _dname; do
            [[ -z "$_dname" ]] && continue
            _dname="${_dname%%:*}"
            case "$_dabbrev" in
                ii*) _dpkg_installed["$_dname"]=1 ;;
            esac
        done < <(dpkg-query -W -f='${db:Status-Abbrev}\t${binary:Package}\n' "${pkgs[@]}" 2>/dev/null)
    fi

    for pkg in "${pkgs[@]}"; do
        [[ -z "${_dpkg_installed[$pkg]:-}" ]] && to_install+=("$pkg")
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
        if [[ -t 1 ]]; then
            printf "${CYAN}Attempting batch installation...${RESET}\n"
        else
            printf 'Attempting batch installation...\n'
        fi
    fi

    suppress_python_warnings

    local _batch_out=""
    if _batch_out=$(sudo env NEEDRESTART_MODE=a DEBIAN_FRONTEND=noninteractive apt-get install -y -qq "${to_install[@]}" 2>&1); then
        if [ "$VERBOSE_MODE" = false ] && [ "$QUIET_MODE" = false ]; then
            [[ -t 1 ]] && printf "${GREEN}\u2713 Batch installation successful${RESET}\n" || printf '\u2713 Batch installation successful\n'
        fi
        INSTALLED_PACKAGES+=("${to_install[@]}")
        cleanup_install_environment
        return 0
    fi

    # Batch failures must be diagnosable — never swallow apt's output.
    {
        echo ""
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] BATCH FAILURE (apt-get install) — falling back per-package"
        echo "$_batch_out"
    } >> "$INSTALL_LOG" 2>/dev/null || true

    if [ "$QUIET_MODE" = false ]; then
        ui_warn "Batch installation failed. Falling back to individual installation..."
    fi

    for package in "${to_install[@]}"; do
        apt_install_single "$package" "$VERBOSE_MODE"
    done

    cleanup_install_environment
}
