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

# ===== Zoxide =====
eval "$(zoxide init --cmd cd zsh)"

# ===== FZF =====
export FZF_ALT_C_COMMAND="fd --type d --hidden --exclude .git"
export LC_ALL=en_US.UTF-8

# Restore pywal colors on shell start
(cat ~/.cache/wal/sequences &) 2>/dev/null
[[ -f ~/.cache/wal/colors.sh ]] && source ~/.cache/wal/colors.sh


# Added by Antigravity CLI installer
export PATH="/home/rdio/.local/bin:$PATH"
alias bootwin='systemctl reboot --boot-loader-entry=auto-windows'
export PATH="$HOME/Android/Sdk/platform-tools:$PATH"

# ===== Live subtitle server =====
export SUBTITLE_DIR="$HOME/AndroidStudioProjects/subtitletest"

# Foreground, Ctrl+C to stop. Runs in a subshell so your cwd is untouched.
# Output stays in this window's scrollback — no file, gone when you close it.
# --quiet-text: timings only, never the transcript. Drop it to see the text.
subs() {
  ( cd "$SUBTITLE_DIR" && .venv-onnx/bin/python server/subtitled.py --quiet-text "$@" )
}

# Same, but detached: no terminal to keep open, no window, nothing printed
# anywhere. setsid puts it in its own session so closing the shell cannot take
# it down, and output goes to /dev/null — not a file, so nothing is retained.
subs-bg() {
  if [[ -n "$(_subs_pids)" ]]; then
    print "subtitle server: already running"
    subs-status
    return 1
  fi
  ( cd "$SUBTITLE_DIR" &&
    setsid .venv-onnx/bin/python server/subtitled.py --quiet-text "$@" \
      </dev/null >/dev/null 2>&1 & )
  # Model load takes a few seconds; wait for the port rather than lying.
  local i
  for i in {1..40}; do
    sleep 1
    if ss -ltn 2>/dev/null | grep -q ':43007 '; then
      print "subtitle server: listening on :43007"
      return 0
    fi
  done
  print "subtitle server: started but :43007 never opened — run 'subs' to see why"
  return 1
}

# Only real python processes. A plain `pgrep -f subtitled.py` also matches any
# shell whose command line happens to contain the pattern — killing your own
# terminal, which has happened twice on this project.
_subs_pids() {
  local p
  for p in ${(f)"$(pgrep -f 'server/subtitled\.py' 2>/dev/null)"}; do
    [[ -n $p ]] || continue
    [[ "$(ps -o comm= -p $p 2>/dev/null)" == python* ]] && print -r -- $p
  done
}

subs-status() {
  local -a pids=( ${(f)"$(_subs_pids)"} )
  if (( ${#pids} == 0 )); then
    print "subtitle server: not running"
    return 1
  fi
  ps -o pid,etime,cmd -p ${(j:,:)pids}
}

subs-stop() {
  local -a pids=( ${(f)"$(_subs_pids)"} )
  if (( ${#pids} == 0 )); then
    print "subtitle server: not running"
    return 1
  fi
  kill $pids && print "stopped: $pids"
}

# Wipes this terminal's scrollback — the only place subtitles land when the
# server runs in the FOREGROUND (`subs`). Nothing is on disk to delete: with
# `subs-bg` the server's stdout/stderr go to /dev/null. \033[3J is the erase-
# saved-lines sequence; without it `clear` only scrolls the view.
subs-clear() {
  printf '\033[H\033[2J\033[3J'
}
