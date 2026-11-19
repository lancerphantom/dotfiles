# ===== Startup: Overcast greeting =====
# A greeting in spaced capitals with the time and date, system info (memory and disk bars,
# pending updates, what's playing) and today's painting's name, in the wallpaper's glow —
# written by Overcast's terminal.py as greeting.zsh (plain zsh, opens at once). Skipped in
# VS Code and in the F12 drop-down terminal (OVERCAST_QUICK). The old painting + fastfetch
# greeting is still there by hand: fastfetch -c ~/.local/share/overcast/terminal/fastfetch.jsonc
_ov=~/.local/share/overcast/terminal
# Pending updates: re-counted in the background at most once an hour, and at once after
# packages were installed (pacman's database is newer than the count; the old number is
# dropped so the greeting says "checking…" instead of showing it).
_upd=~/.cache/overcast/updates
[[ -f $_upd && /var/lib/pacman/local -nt $_upd ]] && rm -f $_upd
if [[ ! -f $_upd || -n $(find $_upd -mmin +60 2>/dev/null) ]] && (( $+commands[checkupdates] )); then
  mkdir -p ${_upd:h}
  ( n=$(checkupdates 2>/dev/null | wc -l) && print $n > $_upd.tmp && mv $_upd.tmp $_upd ) &!
fi
if [[ "$TERM_PROGRAM" != "vscode" && -z "$OVERCAST_QUICK" && -r $_ov/greeting.zsh ]]; then
  source $_ov/greeting.zsh && overcast_greeting
fi

export WLR_PRIMARY_SELECTION=1

# ===== Oh My Zsh =====
export ZSH="$HOME/.oh-my-zsh"
ZSH_THEME="robbyrussell"
plugins=(
    git
    z
    copypath
    copyfile
    docker
    npm
    python
    sudo
    history
    dirhistory
    zsh-autosuggestions
    zsh-syntax-highlighting
)
source $ZSH/oh-my-zsh.sh

# ===== Prompt: Overcast starship (folder, git, errors, slow commands) =====
# Falls back to robbyrussell above until starship is installed.
if (( $+commands[starship] )) && [[ -r $_ov/starship.toml ]]; then
  export STARSHIP_CONFIG=$_ov/starship.toml
  eval "$(starship init zsh)"
fi

# ===== History =====
HISTFILE=~/.zsh_history
HISTSIZE=100000
SAVEHIST=100000
setopt HIST_EXPIRE_DUPS_FIRST
setopt HIST_IGNORE_SPACE
setopt HIST_REDUCE_BLANKS
setopt INC_APPEND_HISTORY
setopt SHARE_HISTORY
unsetopt HIST_IGNORE_DUPS
unsetopt HIST_IGNORE_ALL_DUPS

# ===== PATH =====
export PATH="$HOME/bin:$HOME/.local/bin:$HOME/.npm-global/bin:$BUN_INSTALL/bin:$PATH"

# ===== Aliases =====
alias ll='ls -lah'
# Nicer ls / cat once eza and bat are installed (icons, git status, colours).
if (( $+commands[eza] )); then
  alias ls='eza --icons=auto --group-directories-first'
  alias ll='eza -lah --icons=auto --group-directories-first --git'
  alias tree='eza --tree --icons=auto'
fi
(( $+commands[bat] )) && alias cat='bat --paging=never --style=plain'
alias update='yay -Syu --noconfirm'
alias zshconfig='nano ~/.zshrc'
alias mood='~/.config/hypr/scripts/random-wall.sh'
alias hyprlogout='hyprctl dispatch exit'
alias idle='python -m idlelib.idle'
alias fx='fix'
# --- Printer Shortcuts ---
alias canon-q="lpstat -o" #View active print queue
alias canon-s="lpstat -p" #Check printer status (idle, disabled, etc.)
alias canon-c="cancel -a -x" #Clear all jobs and flush the queue completely
alias canon-w="sudo cupsenable Canon_G3770 && sudo cupsaccept Canon_G3770" #Force wake/enable printer
alias canon-r="sudo systemctl restart cups.service" #Restart print spooler


#------ ChessLens Servers -------
export CL=/home/rdio/projects/claudeCode/chesslens
alias cl-run='cd "$CL" && ./run.sh'
cl-branch() {
    local name="antigravity/${1:?usage: cl-branch <task-name>}"
    cd "$CL" && (git checkout -b "$name" 2>/dev/null || git checkout
"$name")
}

# ===== Command Fixer (Gemini API) =====
fix() {
  local n=1
  local mode="short"
  for arg in "$@"; do
    if [[ $arg == "-e" ]]; then
      mode="explain"
    elif [[ $arg == -* ]]; then
      n=${arg#-}
    fi
  done
  local cmds=$(fc -ln -100 | grep -vE '^\s*(fx|fix|source|nano|cat|curl|grep|fixcmd)' | tail -$n)
  fixcmd "$mode" "$cmds"
}

# ===== Conda =====
__conda_setup="$('/home/rdio/anaconda3/bin/conda' 'shell.zsh' 'hook' 2> /dev/null)"
if [ $? -eq 0 ]; then
    eval "$__conda_setup"
else
    if [ -f "/home/rdio/anaconda3/etc/profile.d/conda.sh" ]; then
        . "/home/rdio/anaconda3/etc/profile.d/conda.sh"
    else
        export PATH="/home/rdio/anaconda3/bin:$PATH"
    fi
fi
unset __conda_setup

# ===== NVM =====
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"

# ===== Bun =====
export BUN_INSTALL="$HOME/.bun"
[ -s "/home/rdio/.bun/_bun" ] && source "/home/rdio/.bun/_bun"

# ===== FZF =====
export FZF_ALT_C_COMMAND="fd --type d --hidden --exclude .git"
# Ctrl+R: search history, Ctrl+T: pick a file, Alt+C: jump to a folder
(( $+commands[fzf] )) && source <(fzf --zsh)
export LC_ALL=en_US.UTF-8


# Added by Antigravity CLI installer
export PATH="/home/rdio/.local/bin:$PATH"
alias bootwin='systemctl reboot --boot-loader-entry=auto-windows'
export PATH="$HOME/Android/Sdk/platform-tools:$PATH"

export EDITOR=nano
export VISUAL=nano


# RGB lighting — separate repo ~/projects/claudeCode/rgb-lights (aliases, flash hook, completion)
[[ -r ~/projects/claudeCode/rgb-lights/shell/rgb.zsh ]] && source ~/projects/claudeCode/rgb-lights/shell/rgb.zsh

# ===== Zoxide (must stay last, or zoxide warns about its setup) =====
eval "$(zoxide init --cmd cd zsh)"
