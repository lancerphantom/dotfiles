# ===== Startup: Overcast fastfetch =====
# Today's painting (animated), a greeting, system info and pending updates, in the
# wallpaper's colours (written by Overcast's terminal.py). Skipped in VS Code
# and in the F12 drop-down terminal (OVERCAST_QUICK).
_ov=~/.local/share/overcast/terminal
# Pending updates: re-counted in the background at most once an hour.
_upd=~/.cache/overcast/updates
if [[ ! -f $_upd || -n $(find $_upd -mmin +60 2>/dev/null) ]] && (( $+commands[checkupdates] )); then
  mkdir -p ${_upd:h}
  ( n=$(checkupdates 2>/dev/null | wc -l) && print $n > $_upd.tmp && mv $_upd.tmp $_upd ) &!
fi
if [[ "$TERM_PROGRAM" != "vscode" && -z "$OVERCAST_QUICK" && -r $_ov/fastfetch.jsonc ]]; then
  # the "living painting": today's wallpaper as a slow seamless loop, stretched
  # across the full window width (the strip is 6:1; rows = its height in text rows)
  if [[ -n $KITTY_WINDOW_ID && -r $_ov/painting.gif ]]; then
    # kitty widens a new window ~0.1 s after the shell starts: wait (max 0.5 s)
    # until the size has held still for 0.15 s, so the strip gets the final width
    _sz=$(tput cols)x$(tput lines); _still=0
    for _i in {1..10}; do
      sleep 0.05
      if [[ $(tput cols)x$(tput lines) == $_sz ]]; then (( ++_still >= 3 )) && break
      else _sz=$(tput cols)x$(tput lines); _still=0; fi
    done
    COLUMNS=${_sz%x*}; LINES=${_sz#*x}
    _px=$(kitten icat --print-window-size 2>/dev/null)
    if [[ $_px == <->x<-> ]] && (( LINES > 0 )); then
      _rows=$(( (${_px%x*} * LINES + 6 * ${_px#*x} - 1) / (6 * ${_px#*x}) ))
      kitten icat --loop -1 --scale-up --place ${COLUMNS}x${_rows}@0x0 $_ov/painting.gif 2>/dev/null
      print -n ${(pl:_rows::\n:)}
    fi
    unset _px _rows _sz _still _i
  fi
  fastfetch -c $_ov/fastfetch.jsonc
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
export EDITOR=nano
export VISUAL=nano


# RGB flash when long commands finish (green ok / red fail)
zmodload zsh/datetime
autoload -Uz add-zsh-hook
_rgb_start() { _rgb_t=$EPOCHSECONDS }
_rgb_done() {
  local s=$?
  if [[ -n $_rgb_t ]] && (( EPOCHSECONDS - _rgb_t >= 15 )); then
    if (( s == 0 )); then rgb-flash 00FF00 2 &!; else rgb-flash FF0000 2 &!; fi
  fi
  unset _rgb_t
}
add-zsh-hook preexec _rgb_start
add-zsh-hook precmd _rgb_done

# RGB modes
alias rgbauto='rgbmode auto'
alias rgbwall='rgbmode wallpaper'
alias rgbs='rgbmode static'
alias rgboff='rgbmode off'
alias musicon='rgbmode music-on'
alias musicoff='rgbmode music-off'
alias rgbstat='rgbmode status'
alias rgbfx='rgbmode fx'
alias fxoff='rgbmode fx-off'
alias fxlist='rgbmode fx-list'

# RGB tab completion
_rgb_fx_list() {
  local f; reply=()
  for f in ~/.config/rgb-fx/[^_]*.py(N); do
    reply+=("${f:t:r}:$(grep -m1 '^DESCRIPTION' $f | cut -d'"' -f2)")
  done
}
_rgb_colours() { local -a c; c=(${(f)"$(rgb list | awk '{print $1":"$2}')"}); _describe 'colour' c; }
_rgbmode() {
  local -a modes fx
  modes=('auto:wallpaper + music + events' 'wallpaper:wallpaper colours, no music'
         'static:one fixed colour' 'off:everything dark' 'music-on:fans pulse to music'
         'music-off:stop music sync' 'fx:fan effect' 'fx-off:stop fan effect'
         'fx-list:list fan effects' 'status:show what is running')
  if (( CURRENT == 2 )); then _describe 'mode' modes
  elif (( CURRENT == 3 )); then
    case $words[2] in
      fx) _rgb_fx_list; fx=($reply); _describe 'effect' fx ;;
      static) _rgb_colours ;;
    esac
  fi
}
_rgb() { (( CURRENT == 2 )) && _rgb_colours; }
compdef _rgbmode rgbmode
compdef _rgb rgb
alias rgbm='rgbmenu'

# ===== Zoxide (must stay last, or zoxide warns about its setup) =====
eval "$(zoxide init --cmd cd zsh)"
