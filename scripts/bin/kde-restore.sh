#!/usr/bin/env bash
# kde-restore.sh — copy KDE configs FROM the dotfiles repo to the live system.
#
# The file list is ~/dotfiles/kde/manifest.txt, shared with kde-save.sh.
#
# Run with Plasma NOT running (from a TTY, Ctrl+Alt+F3), or the session
# rewrites these files on logout. On a fresh machine, run overcast-restore.sh
# first: the panel files point at the Overcast icon theme, the Nothing-Floating
# style and the Overcast Tasks widget, and this script refuses to restore them
# until those exist.
#
#   kde-restore.sh             check, back up, restore
#   kde-restore.sh --check     only run the checks
#   kde-restore.sh --dry-run   show what would be copied
#   kde-restore.sh --force     skip the Plasma-running and dependency checks
#
# Live files that differ are backed up to ~/.local/state/kde-restore/<time>/.
set -euo pipefail

DOTFILES="${DOTFILES:-$HOME/dotfiles}"
MANIFEST="$DOTFILES/kde/manifest.txt"
SRC="$DOTFILES/kde"

# Credential locations are never copied, whatever the manifest says.
DENY='(^|/)\.config/(gh|secrets)(/|$)|(^|/)\.(ssh|gnupg)(/|$)|(^|/)\.local/share/keyrings(/|$)'
XDG_DATA_HOME="${XDG_DATA_HOME:-$HOME/.local/share}"
BACKUP="${XDG_STATE_HOME:-$HOME/.local/state}/kde-restore/$(date +%Y%m%d-%H%M%S)"

mode=restore force=0
for arg in "$@"; do
    case "$arg" in
        --check) mode=check ;;
        --dry-run) mode=dry ;;
        --force) force=1 ;;
        -h|--help) sed -n '2,17p' "$0"; exit 0 ;;
        *) echo "unknown option: $arg" >&2; exit 2 ;;
    esac
done

[[ -f "$MANIFEST" ]] || { echo "error: $MANIFEST not found" >&2; exit 1; }

entries=()
while IFS= read -r rel; do
    rel="${rel%%#*}"; rel="${rel%"${rel##*[![:space:]]}"}"
    if [[ "$rel" =~ $DENY ]]; then echo "REFUSED (credentials): $rel"; continue; fi
    if [[ -n "$rel" ]]; then entries+=("$rel"); fi
done < "$MANIFEST"

# ini_get FILE GROUP KEY — read one value from a KDE-style ini file.
ini_get() {
    awk -v g="[$2]" -v k="$3" '
        /^\[/ { in_g = ($0 == g); next }
        in_g && index($0, k "=") == 1 { print substr($0, length(k) + 2); exit }
    ' "$1" 2>/dev/null
}

# first_existing PATH... — succeed if any path exists.
first_existing() { local p; for p in "$@"; do [[ -e "$p" ]] && return 0; done; return 1; }

errors=0 warnings=0
err()  { echo "  ERROR: $*"; errors=$((errors + 1)); }
warn() { echo "  warn:  $*"; warnings=$((warnings + 1)); }

echo "==> checks"

if pgrep -u "$(id -u)" -x plasmashell > /dev/null 2>&1; then
    err "plasmashell is running. Log out to a TTY (Ctrl+Alt+F3) and run this there,
         or the session overwrites the restored files on logout."
fi

if [[ -f "$SRC/.config/kdeglobals" ]]; then
    icons=$(ini_get "$SRC/.config/kdeglobals" Icons Theme)
    if [[ -n "$icons" ]] && ! first_existing "$XDG_DATA_HOME/icons/$icons/index.theme" \
                                             "$HOME/.icons/$icons/index.theme" \
                                             "/usr/share/icons/$icons/index.theme"; then
        if [[ "$icons" == Overcast ]]; then
            err "icon theme Overcast is not built yet — run overcast-restore.sh first"
        else
            err "icon theme '$icons' is not installed"
        fi
    fi
    laf=$(ini_get "$SRC/.config/kdeglobals" KDE LookAndFeelPackage)
    if [[ -n "$laf" ]] && ! first_existing "$XDG_DATA_HOME/plasma/look-and-feel/$laf" \
                                           "/usr/share/plasma/look-and-feel/$laf"; then
        warn "global theme '$laf' is not installed (cosmetic: System Settings shows none selected)"
    fi
fi

if [[ -f "$SRC/.config/plasmarc" ]]; then
    style=$(ini_get "$SRC/.config/plasmarc" Theme name)
    if [[ -n "$style" ]] && ! first_existing "$XDG_DATA_HOME/plasma/desktoptheme/$style/metadata.json" \
                                             "$XDG_DATA_HOME/plasma/desktoptheme/$style/metadata.desktop" \
                                             "/usr/share/plasma/desktoptheme/$style"; then
        if [[ "$style" == Nothing-Floating ]]; then
            err "Plasma style Nothing-Floating is not generated yet — run overcast-restore.sh first
         (otherwise Plasma falls back to Breeze with opaque panels)"
        else
            err "Plasma style '$style' is not installed"
        fi
    fi
fi

appletsrc="$SRC/.config/plasma-org.kde.plasma.desktop-appletsrc"
if [[ -f "$appletsrc" ]]; then
    while IFS= read -r id; do
        if first_existing "/usr/share/plasma/plasmoids/$id" \
                          "$XDG_DATA_HOME/plasma/plasmoids/$id" \
                          "/usr/lib/qt6/plugins/plasma/applets/$id.so" \
                          "$HOME/.local/lib/plugins/plasma/applets/$id.so"; then
            continue
        fi
        if [[ "$id" == org.kde.plasma.overcasttasks ]]; then
            err "Overcast Tasks widget is not built — run overcast-restore.sh first
         (otherwise the dock shows a 'widget not found' placeholder)"
        else
            warn "panel widget '$id' is not installed (its panel slot will show a placeholder)"
        fi
    done < <(sed -n 's/^plugin=//p' "$appletsrc" | sort -u)

    if grep -qx 'plugin=org.kde.plasma.overcasttasks' "$appletsrc" &&
       ! grep -qs QT_PLUGIN_PATH "$HOME/.config/plasma-workspace/env/"*.sh; then
        err "$HOME/.config/plasma-workspace/env/overcast-tasks.sh is missing — Plasma won't find
         the Overcast Tasks widget. Run overcast-restore.sh first."
    fi
fi

# Cursor: Plasma reads kcminputrc [Mouse] cursorTheme and exports XCURSOR_THEME
# to the session itself.
if [[ -f "$SRC/.config/kcminputrc" ]]; then
    cursor=$(ini_get "$SRC/.config/kcminputrc" Mouse cursorTheme)
    if [[ -n "$cursor" ]] && ! first_existing "$XDG_DATA_HOME/icons/$cursor/cursors" "$HOME/.icons/$cursor/cursors" \
                                              "/usr/share/icons/$cursor/cursors"; then
        warn "cursor theme '$cursor' (kcminputrc) is not installed — Plasma falls back to Breeze"
    fi
fi

# Window decoration: an Aurorae theme named in kwinrc must be installed.
if [[ -f "$SRC/.config/kwinrc" ]]; then
    deco=$(ini_get "$SRC/.config/kwinrc" org.kde.kdecoration2 theme)
    if [[ "$deco" == __aurorae__svg__* ]]; then
        name="${deco#__aurorae__svg__}"
        first_existing "$XDG_DATA_HOME/aurorae/themes/$name" "/usr/share/aurorae/themes/$name" ||
            warn "window decoration theme '$name' (Aurorae) is not installed"
    fi
fi

# Launchers: warn when the program a restored launcher starts isn't there
# (AppImages, installer-made apps and scripts in ~ aren't in this repo).
for rel in "${entries[@]}"; do
    [[ "$rel" == .local/share/applications/*.desktop && -f "$SRC/$rel" ]] || continue
    exec_line=$(ini_get "$SRC/$rel" "Desktop Entry" Exec)
    read -r -a argv <<< "${exec_line//\"/}"
    prog="${argv[0]:-}"
    if [[ "$prog" == bash || "$prog" == sh || "$prog" == env ]]; then prog="${argv[1]:-}"; fi
    [[ -n "$prog" ]] || continue
    if [[ "$prog" == /* ]]; then
        [[ -e "$prog" ]] || warn "${rel##*/} starts $prog, which doesn't exist yet"
    elif ! command -v "$prog" > /dev/null; then
        warn "${rel##*/} starts '$prog', which isn't installed"
    fi
done

echo "  $errors error(s), $warnings warning(s)"

[[ "$mode" == check ]] && exit $((errors > 0))
if (( errors > 0 && ! force )); then
    echo
    echo "Not restoring. Fix the errors above, or re-run with --force to restore anyway."
    exit 1
fi

echo
echo "==> restore"
restored=0
for rel in "${entries[@]}"; do
    src="$SRC/$rel" dst="$HOME/$rel"
    if [[ "$rel" == */ ]]; then
        [[ -d "$src" ]] || { echo "  not in repo: $rel"; continue; }
        if [[ "$mode" == dry ]]; then echo "  would restore dir: $rel"; continue; fi
        if [[ -d "$dst" ]] && ! diff -rq "$src" "$dst" > /dev/null 2>&1; then
            mkdir -p "$BACKUP/$rel"
            cp -a "$dst." "$BACKUP/$rel"
            echo "  backed up: $rel"
        fi
        mkdir -p "$dst"
        cp -a "$src." "$dst"
    else
        [[ -f "$src" ]] || { echo "  not in repo: $rel"; continue; }
        if [[ "$mode" == dry ]]; then echo "  would restore: $rel"; continue; fi
        if [[ -f "$dst" ]] && ! cmp -s "$src" "$dst"; then
            mkdir -p "$(dirname "$BACKUP/$rel")"
            cp -a "$dst" "$BACKUP/$rel"
            echo "  backed up: $rel"
        fi
        mkdir -p "$(dirname "$dst")"
        cp -f "$src" "$dst"
    fi
    echo "  restored: $rel"
    restored=$((restored + 1))
done

[[ "$mode" == dry ]] && exit 0
echo
echo "$restored restored."
[[ -d "$BACKUP" ]] && echo "Previous versions of changed files: $BACKUP"
echo "Log in (or reboot) for the changes to apply."
