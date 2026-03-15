# ===== Startup =====
if [[ "$TERM_PROGRAM" != "vscode" ]]; then
  _img="${FASTFETCH_IMAGE:-${(f)$(ls /home/rdio/Pictures/fastfetch/* | shuf -n1)}}"
  _tmp=$(mktemp /tmp/fastfetch-XXXX.jsonc)
  sed "s|\"source\":.*|\"source\": \"$_img\",|" ~/.config/fastfetch/config.jsonc > "$_tmp"
  fastfetch --config "$_tmp"
  rm -f "$_tmp"
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
alias update='yay'
alias zshconfig='nano ~/.zshrc'
alias mood='~/.config/hypr/scripts/random-wall.sh'
alias hyprlogout='hyprctl dispatch exit'
alias idle='python -m idlelib.idle'
alias fx='fix'

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

# ===== Zoxide =====
eval "$(zoxide init --cmd cd zsh)"

# ===== FZF =====
export FZF_ALT_C_COMMAND="fd --type d --hidden --exclude .git"
export LC_ALL=en_US.UTF-8
