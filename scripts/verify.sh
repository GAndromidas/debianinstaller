#!/bin/bash
# Post-install verification for debianinstaller.
#
# Run this AFTER rebooting into the freshly configured system — it checks
# live, booted state (loaded drivers, active services, firewall status) that
# the install log genuinely cannot: the log only shows what happened during
# install, under installer-specific conditions (high load, no real boot
# cycle yet). This is what actually confirms the setup worked, not just
# that commands were issued.
#
# Entirely read-only: no writes, no package installs, no service restarts.
# Safe to run any time, repeatedly.
#
# Usage: bash verify.sh [--verbose]

set -uo pipefail

VERBOSE=false
[[ "${1:-}" == "--verbose" || "${1:-}" == "-v" ]] && VERBOSE=true

if [ -t 1 ]; then
  RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
  BLUE='\033[1;34m'; MUTED='\033[0;2m'; BOLD='\033[1m'; RESET='\033[0m'
else
  RED=''; GREEN=''; YELLOW=''; BLUE=''; MUTED=''; BOLD=''; RESET=''
fi

PASS=0
WARN=0
FAIL=0

ok()   { printf "  ${GREEN}✓${RESET} %s\n" "$1"; PASS=$((PASS+1)); }
warn() { printf "  ${YELLOW}⚠${RESET} %s\n" "$1"; WARN=$((WARN+1)); }
bad()  { printf "  ${RED}✗${RESET} %s\n" "$1"; FAIL=$((FAIL+1)); }
info() { [[ "$VERBOSE" == true ]] && printf "  ${MUTED}·${RESET} %s\n" "$1"; }
section() { printf "\n${BOLD}${BLUE}── %s ──${RESET}\n" "$1"; }

section "Boot"

if [ -d /sys/firmware/efi ]; then
  ok "Booted via UEFI"
else
  warn "Booted via BIOS/legacy — expected on some systems, just noting it"
fi

cmdline=$(cat /proc/cmdline 2>/dev/null || echo "")
if [[ -n "$cmdline" ]]; then
  ok "Kernel command line is populated"
  info "cmdline: $cmdline"
else
  bad "Could not read /proc/cmdline"
fi

section "Distribution"

if [[ -f /etc/os-release ]]; then
  # shellcheck disable=SC1091
  . /etc/os-release
  ok "Distribution: ${NAME:-unknown} ${VERSION_ID:-unknown}"
  if [[ -f /etc/debian_version ]]; then
    ok "Debian base confirmed (debian_version: $(cat /etc/debian_version 2>/dev/null))"
  else
    warn "/etc/debian_version missing — unusual for a Debian-based system"
  fi
else
  bad "Cannot read /etc/os-release"
fi

section "CPU & GPU drivers"

cpu_vendor="unknown"
grep -qi "GenuineIntel" /proc/cpuinfo 2>/dev/null && cpu_vendor="intel"
grep -qi "AuthenticAMD" /proc/cpuinfo 2>/dev/null && cpu_vendor="amd"
ok "CPU vendor: ${cpu_vendor}"

if command -v lspci &>/dev/null; then
  gpu_lines=$(lspci -k 2>/dev/null | grep -A3 -iE 'vga|3d controller|display controller')
  if echo "$gpu_lines" | grep -qi "kernel driver in use"; then
    while IFS= read -r drv; do
      ok "GPU kernel driver in use: $drv"
    done < <(echo "$gpu_lines" | grep -i "kernel driver in use" | sed 's/.*: //' | sort -u)
  else
    warn "No GPU kernel driver reported by lspci -k — may still be fine (e.g. simple framebuffer on some setups)"
  fi
else
  info "lspci not available, skipping GPU driver check"
fi

section "Storage"

if command -v lsblk &>/dev/null; then
  while IFS= read -r dev; do
    [[ -z "$dev" ]] && continue
    sched_file="/sys/block/$dev/queue/scheduler"
    if [[ -r "$sched_file" ]]; then
      active=$(grep -oE '\[[a-z-]+\]' "$sched_file" 2>/dev/null | tr -d '[]')
      ok "/dev/$dev I/O scheduler: ${active:-unknown}"
    fi
  done < <(lsblk -dn -o NAME 2>/dev/null | grep -vE '^(loop|sr|zram)')
fi

section "Security"

if command -v ufw &>/dev/null; then
  if sudo ufw status 2>/dev/null | grep -q "^Status: active"; then
    ok "UFW is active"
  else
    bad "UFW is installed but not active"
  fi
else
  warn "UFW not found — firewall checks skipped"
fi

if systemctl is-active --quiet fail2ban 2>/dev/null; then
  jails=$(sudo fail2ban-client status 2>/dev/null | grep "Jail list" | sed 's/.*://;s/,/ /g; s/^[[:space:]]*//')
  if [[ -n "$jails" ]]; then
    ok "fail2ban active, jails: $jails"
    if echo "$jails" | grep -qw sshd; then
      ok "sshd jail is active"
    else
      bad "sshd jail is NOT in the active jail list — SSH is not protected"
    fi
  else
    bad "fail2ban is running but reports zero active jails — check 'sudo fail2ban-client status' and /etc/fail2ban/jail.local"
  fi
elif systemctl list-unit-files fail2ban.service &>/dev/null; then
  bad "fail2ban is installed but not running"
else
  info "fail2ban not installed — skipping"
fi

section "Networking"

if command -v ethtool &>/dev/null; then
  wol_checked=false
  for iface in /sys/class/net/*; do
    ifname=$(basename "$iface")
    [[ "$ifname" == "lo" ]] && continue
    [[ -d "$iface/wireless" ]] && continue
    if ethtool "$ifname" 2>/dev/null | grep -q "Supports Wake-on"; then
      wol_checked=true
      wol_now=$(ethtool "$ifname" 2>/dev/null | awk -F': ' '/Wake-on/{print $2; exit}')
      if [[ "$wol_now" == "g" ]]; then
        ok "Wake-on-LAN enabled on $ifname (Wake-on: g)"
      else
        warn "$ifname supports Wake-on-LAN but it is currently '$wol_now', not 'g'"
      fi
    fi
  done
  [[ "$wol_checked" == false ]] && info "No Wake-on-LAN-capable wired interface found — expected on laptops/Wi-Fi-only systems"
else
  info "ethtool not available, skipping Wake-on-LAN check"
fi

section "Maintenance timers"

if systemctl is-enabled --quiet apt-daily.timer 2>/dev/null || systemctl is-enabled --quiet apt-daily-upgrade.timer 2>/dev/null; then
  ok "APT daily timers enabled (automatic updates)"
else
  warn "APT daily timers not enabled — automatic update checks may not run"
fi
if systemctl is-enabled --quiet fstrim.timer 2>/dev/null; then
  ok "fstrim.timer enabled (periodic SSD TRIM)"
else
  info "fstrim.timer not enabled (expected on HDD-only systems)"
fi

section "Shell & tools"

current_shell=$(getent passwd "${USER:-$(whoami)}" 2>/dev/null | cut -d: -f7)
if [[ "$current_shell" == *zsh* ]]; then
  ok "Default shell is zsh"
else
  warn "Default shell is '$current_shell', not zsh — log out and back in if you just installed, or check 'chsh -l'"
fi
if command -v starship &>/dev/null; then ok "Starship prompt installed"; else warn "Starship not found"; fi

section "Gaming"

if dpkg -l steam 2>/dev/null | grep -q "^ii" || dpkg -l steam-installer 2>/dev/null | grep -q "^ii"; then
  ok "Steam installed"
else
  info "Steam not installed — expected unless gaming mode was selected"
fi
if dpkg -l gamemode 2>/dev/null | grep -q "^ii"; then
  if command -v gamemoded &>/dev/null; then ok "GameMode installed"; else warn "gamemode package present but gamemoded not found"; fi
else
  info "GameMode not installed — expected unless gaming mode was selected"
fi
if dpkg -l mangohud 2>/dev/null | grep -q "^ii"; then
  ok "MangoHud installed"
else
  info "MangoHud not installed — expected unless gaming mode was selected"
fi

echo ""
printf "${BOLD}── Summary: ${GREEN}%d passed${RESET}${BOLD}, ${YELLOW}%d warnings${RESET}${BOLD}, ${RED}%d failed${RESET}${BOLD} ──${RESET}\n" "$PASS" "$WARN" "$FAIL"
echo ""
if [[ "$FAIL" -gt 0 ]]; then
  echo "Some checks failed — worth investigating before considering this a clean install."
  exit 1
elif [[ "$WARN" -gt 0 ]]; then
  echo "No failures, but a few things worth a look above."
  exit 0
else
  echo "Everything checked out."
  exit 0
fi
