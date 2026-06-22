# If you come from bash you might have to change your $PATH.
# export PATH=$HOME/bin:/usr/local/bin:$PATH

# Path to your oh-my-zsh installation.
export ZSH="$HOME/.oh-my-zsh"

# Themes
ZSH_THEME="agnoster"
DEFAULT_USER=$USER

# Oh-My-ZSH Auto Update
zstyle ':omz:update' mode auto      # update automatically without asking

# Plugins
plugins=(git)

source $ZSH/oh-my-zsh.sh

# Manually source additional plugins
# Try to load from system packages first (apt installation)
if [ -f /usr/share/zsh-autosuggestions/zsh-autosuggestions.zsh ]; then
    source /usr/share/zsh-autosuggestions/zsh-autosuggestions.zsh
elif [ -f /usr/share/zsh/plugins/zsh-autosuggestions/zsh-autosuggestions.zsh ]; then
    source /usr/share/zsh/plugins/zsh-autosuggestions/zsh-autosuggestions.zsh
elif [ -f "$HOME/.oh-my-zsh/custom/plugins/zsh-autosuggestions/zsh-autosuggestions.zsh" ]; then
    # Fallback to GitHub installation in Oh My Zsh custom plugins
    source "$HOME/.oh-my-zsh/custom/plugins/zsh-autosuggestions/zsh-autosuggestions.zsh"
fi

if [ -f /usr/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh ]; then
    source /usr/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh
elif [ -f /usr/share/zsh/plugins/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh ]; then
    source /usr/share/zsh/plugins/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh
elif [ -f "$HOME/.oh-my-zsh/custom/plugins/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh" ]; then
    # Fallback to GitHub installation in Oh My Zsh custom plugins
    source "$HOME/.oh-my-zsh/custom/plugins/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh"
fi

# fzf key bindings and completion (system package)
if [ -f /usr/share/doc/fzf/examples/key-bindings.zsh ]; then
    source /usr/share/doc/fzf/examples/key-bindings.zsh
fi
if [ -f /usr/share/doc/fzf/examples/completion.zsh ]; then
    source /usr/share/doc/fzf/examples/completion.zsh
fi

# FZF Configuration - Compact list with colors

# Set FZF default options to inherit terminal colors
export FZF_DEFAULT_OPTS="
  --height 40%
  --layout=reverse
  --border
  --inline-info
  --color=fg:-1,bg:-1,hl:blue:bold
  --color=fg+:white,bg+:bright-black,hl+:blue:bold
  --color=info:magenta,prompt:blue,pointer:blue
  --color=marker:green,spinner:yellow,header:blue
  --color=border:bright-black
"

# FZF file search (Ctrl+T)
export FZF_CTRL_T_OPTS="
  --preview 'bat --color=always --style=numbers --line-range=:500 {}'
  --preview-window=right:50%:wrap
"

# FZF directory search (Alt+C)
export FZF_ALT_C_OPTS="
  --preview 'eza --tree --color=always --icons {} | head -200'
"

# FZF command history (Ctrl+R)
export FZF_CTRL_R_OPTS="
  --preview 'echo {}'
  --preview-window=down:3:wrap
"

# Clean System

clean() {
  echo "🧹 Starting System Deep Clean..."

  echo "→ Removing unnecessary dependencies..."
  sudo apt-get autoremove --purge -y

  echo "→ Clearing APT cache..."
  sudo apt-get autoclean -y
  sudo apt-get clean

  echo "→ Removing orphaned packages..."
  if command -v deborphan >/dev/null 2>&1; then
    local orphans=$(deborphan)
    if [[ -n "$orphans" ]]; then
      sudo apt-get purge -y $orphans
    fi
  fi

  echo "→ Vacuuming systemd journal (keep 3 days)..."
  sudo journalctl --vacuum-time=3d

  echo "→ Wiping thumbnail & browser caches..."
  rm -rf ~/.cache/thumbnails/* 2>/dev/null
  find ~/.cache/mozilla/firefox -name "cache2" -type d -exec rm -rf {} + 2>/dev/null

  echo "✅ System clean complete!"
}

# Aliases

# System maintenance aliases
alias sync='sudo apt update'
alias update='sudo apt update && sudo apt upgrade'
alias care='sudo ucaresystem-core'
alias microcode='grep . /sys/devices/system/cpu/vulnerabilities/*'
alias sr='sudo systemctl reboot'
alias ss='sudo systemctl poweroff'
alias jctl='journalctl -p 3 -xb'

# Replace ls with eza
alias ls='eza -al --color=always --group-directories-first --icons' # preferred listing
alias la='eza -a --color=always --group-directories-first --icons'  # all files and dirs
alias ll='eza -l --color=always --group-directories-first --icons'  # long format
alias lt='eza -aT --color=always --group-directories-first --icons' # tree listing
alias l.="eza -a | grep -e '^\.'"                                   # show only dotfiles

# Navigation
alias ..='cd ..'
alias ...='cd ../..'
alias ....='cd ../../..'
alias -- -='cd -'

# Networking
alias ip='ip addr'
alias ports='netstat -tulanp'
alias ping='ping -c 5'

# System Monitoring
alias top='btop'
alias hw='hwinfo --short'
alias cpu='lscpu'
alias mem="free -mt"
alias psf='ps auxf'

# Disk Usage
alias df='df -h'
alias du='du -h'
alias duh='du -h --max-depth=1'

# Tar and Zip Operations
alias tar='tar -acf '
alias untar='tar -zxvf '
alias zip='zip -r'
alias unzip='unzip'

# Miscellaneous aliases
alias zshconfig="nano ~/.zshrc"

# Load additional tools
fastfetch
eval "$(zoxide init zsh)"
eval "$(starship init zsh)"
