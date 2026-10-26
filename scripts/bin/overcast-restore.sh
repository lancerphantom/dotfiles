#!/usr/bin/env bash
# overcast-restore.sh — install Overcast on this machine from its project
# checkout, then re-apply the per-folder and per-launcher icon settings that
# ~/dotfiles/overcast/ records.
#
# Run BEFORE kde-restore.sh: the restored panel/icon/style configs point at
# things this script builds. Safe to re-run; every step is idempotent.
#
#   overcast-restore.sh             everything
#   overcast-restore.sh --no-build  skip the builds (icons, style, dock widget);
#                                   only install units/env and re-apply icons
#
# Steps, in the order that matters:
#   1. build dependencies present
#   2. Overcast checkout at $OVERCAST_DIR (cloned from $OVERCAST_REPO if missing)
#   3. "Nothing" Plasma style present (source of Nothing-Floating)
#   4. generate Nothing-Floating, build the icon theme, build the dock widget
#   5. plasma-workspace env script (QT_PLUGIN_PATH) so Plasma finds the widget
#   6. systemd user units installed and enabled
#   7. folder (.directory), launcher (.desktop) and Places icons
#   8. kbuildsycoca6
set -euo pipefail

DOTFILES="${DOTFILES:-$HOME/dotfiles}"
CONF_DIR="$DOTFILES/overcast"
DEFAULT_UNIT_DIR='%h/projects/claudeCode/kdeCons'
XDG_DATA_HOME="${XDG_DATA_HOME:-$HOME/.local/share}"
XDG_CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"
UNITS=(overcast-refresh.path overcast-refresh.service overcast-tasks-check.service)
DEPS=(python python-pillow python-lxml librsvg cmake extra-cmake-modules git gcc make
      plasma-desktop plasma-workspace libplasma plasma-activities plasma-activities-stats libksysguard)

build=1
for arg in "$@"; do
    case "$arg" in
        --no-build) build=0 ;;
        -h|--help) sed -n '2,22p' "$0"; exit 0 ;;
        *) echo "unknown option: $arg" >&2; exit 2 ;;
    esac
done

# shellcheck source=/dev/null
source "$CONF_DIR/overcast.conf"
: "${OVERCAST_DIR:?OVERCAST_DIR not set in $CONF_DIR/overcast.conf}"

step() { echo; echo "==> $*"; }
die()  { echo "error: $*" >&2; exit 1; }
note() { echo "    $*"; }

# --------------------------------------------------------------------------
step "1/8 dependencies"
if command -v pacman > /dev/null; then
    if missing=$(pacman -T "${DEPS[@]}"); then
        note "all present"
    else
        die "missing packages: $(echo "$missing" | tr '\n' ' ')
       install with: sudo pacman -S --needed $(echo "$missing" | tr '\n' ' ')"
    fi
else
    note "pacman not found; skipping the check"
fi

# --------------------------------------------------------------------------
step "2/8 Overcast checkout: $OVERCAST_DIR"
if [[ ! -d "$OVERCAST_DIR" ]]; then
    [[ -n "${OVERCAST_REPO:-}" ]] || die "$OVERCAST_DIR does not exist and OVERCAST_REPO is empty in overcast.conf"
    git clone "$OVERCAST_REPO" "$OVERCAST_DIR"
    if [[ -n "${OVERCAST_REF:-}" ]]; then
        git -C "$OVERCAST_DIR" checkout --quiet "$OVERCAST_REF"
        note "checked out $OVERCAST_REF"
    fi
elif [[ -d "$OVERCAST_DIR/.git" && -n "${OVERCAST_REF:-}" ]]; then
    head=$(git -C "$OVERCAST_DIR" rev-parse HEAD)
    [[ "$head" == "$OVERCAST_REF"* ]] || note "note: checkout is at ${head:0:12}, dotfiles were saved against ${OVERCAST_REF:0:12}"
fi
for f in build.py refresh.py plasma-style/make_floating_style.py overcast-tasks/build.sh \
         plasma-workspace/env/overcast-tasks.sh; do
    [[ -e "$OVERCAST_DIR/$f" ]] || die "$OVERCAST_DIR/$f missing — is this the Overcast project?"
done

# --------------------------------------------------------------------------
step "3/8 Nothing Plasma style"
nothing_ok() {
    [[ -e "$XDG_DATA_HOME/plasma/desktoptheme/Nothing/metadata.json" ||
       -e "$XDG_DATA_HOME/plasma/desktoptheme/Nothing/metadata.desktop" ]]
}
if nothing_ok; then
    note "installed"
elif [[ -d "$OVERCAST_DIR/plasma-style/vendor/Nothing" ]]; then
    mkdir -p "$XDG_DATA_HOME/plasma/desktoptheme"
    cp -a "$OVERCAST_DIR/plasma-style/vendor/Nothing" "$XDG_DATA_HOME/plasma/desktoptheme/"
    note "installed from the Overcast project's vendored copy"
else
    die "the 'Nothing' Plasma style is neither installed nor vendored in the Overcast
       checkout (plasma-style/vendor/Nothing/ — is the checkout older than 4fdf1f8?).
       Update the checkout, or install it from the KDE Store: System Settings →
       Colors & Themes → Plasma Style → Get New… → 'Nothing' (by jomada). Install the
       Plasma Style only, not the 'Nothing' Global Theme. Then re-run this script."
fi

# --------------------------------------------------------------------------
if (( build )); then
    step "4/8 build: Nothing-Floating, icons, Overcast Tasks"
    python3 "$OVERCAST_DIR/plasma-style/make_floating_style.py"
    # Default/pinned palette for now; overcast-refresh.service recolours from
    # the wallpaper at the next login (the POTD cache is empty on a new machine).
    if [[ -f "$OVERCAST_DIR/palettes/pinned.json" ]]; then
        python3 "$OVERCAST_DIR/build.py" --palette "$OVERCAST_DIR/palettes/pinned.json" --reload none
    else
        python3 "$OVERCAST_DIR/build.py" --reload none
    fi
    note "building the dock widget (clones plasma-desktop for this Plasma version; needs network)"
    "$OVERCAST_DIR/overcast-tasks/build.sh"
else
    step "4/8 build: skipped (--no-build)"
fi

# --------------------------------------------------------------------------
step "5/8 plasma-workspace env script"
env_dst="$XDG_CONFIG_HOME/plasma-workspace/env/overcast-tasks.sh"
env_src="$OVERCAST_DIR/plasma-workspace/env/overcast-tasks.sh"
[[ -f "$env_src" ]] || die "$env_src missing — update the Overcast checkout (it ships this file since 4fdf1f8)"
mkdir -p "$(dirname "$env_dst")"
install -m 644 "$env_src" "$env_dst"
note "installed from plasma-workspace/env/overcast-tasks.sh"

# --------------------------------------------------------------------------
step "6/8 systemd user units"
unit_dir="$XDG_CONFIG_HOME/systemd/user"
mkdir -p "$unit_dir"
if [[ "$OVERCAST_DIR" == "$HOME/"* ]]; then
    unit_path="%h/${OVERCAST_DIR#"$HOME/"}"
else
    unit_path="$OVERCAST_DIR"
fi
for u in "${UNITS[@]}"; do
    src="$OVERCAST_DIR/systemd/$u"
    [[ -f "$src" ]] || die "$src missing"
    sed "s|$DEFAULT_UNIT_DIR|$unit_path|g" "$src" > "$unit_dir/$u.new"
    mv -f "$unit_dir/$u.new" "$unit_dir/$u"
    chmod 644 "$unit_dir/$u"
done
[[ "$unit_path" == "$DEFAULT_UNIT_DIR" ]] || note "unit paths rewritten to $unit_path"
if systemctl --user daemon-reload 2> /dev/null; then
    systemctl --user enable "${UNITS[@]}"
    note "enabled (they start at the next Plasma login)"
else
    note "no user systemd manager reachable — after logging in, run:"
    note "  systemctl --user daemon-reload && systemctl --user enable ${UNITS[*]}"
fi

# --------------------------------------------------------------------------
step "7/8 folder, launcher and Places icons"

# set_icon FILE GROUP ICON — set Icon= in an ini-style file, keeping the rest.
# Prints "set", "same" or "created".
set_icon() {
    python3 - "$1" "$2" "$3" <<'PY'
import sys, os
path, group, icon = sys.argv[1:]
header = f"[{group}]"
lines = open(path, encoding="utf-8").read().splitlines() if os.path.exists(path) else []
state = "created" if not lines else "set"
out, in_group, done, seen_group = [], False, False, False
for line in lines:
    s = line.strip()
    if s.startswith("["):
        if in_group and not done:
            out.append(f"Icon={icon}"); done = True
        in_group = (s == header); seen_group |= in_group
    elif in_group and not done and s.split("=", 1)[0].strip() == "Icon":
        if s == f"Icon={icon}":
            state = "same"
        out.append(f"Icon={icon}"); done = True
        continue
    out.append(line)
if not done:
    if in_group:
        out.append(f"Icon={icon}")
    else:
        if out and out[-1].strip():
            out.append("")
        out += [header, f"Icon={icon}"]
if state != "same":
    tmp = path + ".overcast-tmp"
    with open(tmp, "w", encoding="utf-8") as f:
        f.write("\n".join(out) + "\n")
    os.replace(tmp, path)
print(state)
PY
}

# read_map FILE — emit "key<TAB>value" lines, skipping comments and blanks.
read_map() { [[ -f "$1" ]] && grep -v -e '^[[:space:]]*#' -e '^[[:space:]]*$' "$1" || true; }

while IFS=$'\t' read -r dir icon; do
    [[ -n "$dir" && -n "$icon" ]] || continue
    if [[ ! -d "$HOME/$dir" ]]; then note "folder not here, skipped: ~/$dir"; continue; fi
    r=$(set_icon "$HOME/$dir/.directory" "Desktop Entry" "$icon")
    [[ "$r" == same ]] || note "folder ~/$dir → $icon ($r)"
done < <(read_map "$CONF_DIR/folder-icons.tsv")

apps="$XDG_DATA_HOME/applications"
while IFS=$'\t' read -r desktop icon; do
    [[ -n "$desktop" && -n "$icon" ]] || continue
    if [[ ! -f "$apps/$desktop" ]]; then
        note "launcher not installed yet, skipped: $desktop (install the app, then re-run)"
        continue
    fi
    r=$(set_icon "$apps/$desktop" "Desktop Entry" "$icon")
    [[ "$r" == same ]] || note "launcher $desktop → $icon ($r)"
done < <(read_map "$CONF_DIR/launcher-icons.tsv")

places="$XDG_DATA_HOME/user-places.xbel"
if [[ -f "$places" ]]; then
    python3 - "$places" "$HOME" <(read_map "$CONF_DIR/places-icons.tsv") <<'PY'
import re, sys, os, shutil, time
from urllib.parse import quote
path, home, mapfile = sys.argv[1:]
text = open(path, encoding="utf-8").read()
orig = text
for line in open(mapfile, encoding="utf-8"):
    rel, icon = line.rstrip("\n").split("\t", 1)
    rel = rel.strip("/")
    # KDE may store a folder bookmark with or without a trailing slash.
    href = "file://" + quote(os.path.join(home, rel))
    m = re.search(r'<bookmark href="%s/?">.*?</bookmark>' % re.escape(href), text, re.S)
    if not m:
        print(f"    Places: no bookmark for ~/{rel}, skipped"); continue
    block = m.group(0)
    if re.search(r'<bookmark:icon name="%s"\s*/>' % re.escape(icon), block):
        continue
    if "<bookmark:icon " in block:
        new = re.sub(r'<bookmark:icon name="[^"]*"\s*/>', f'<bookmark:icon name="{icon}"/>', block, count=1)
    elif '<metadata owner="http://freedesktop.org">' in block:
        new = block.replace('<metadata owner="http://freedesktop.org">',
                            f'<metadata owner="http://freedesktop.org">\n    <bookmark:icon name="{icon}"/>', 1)
    else:
        print(f"    Places: bookmark for ~/{rel} has no freedesktop metadata, skipped"); continue
    text = text[:m.start()] + new + text[m.end():]
    print(f"    Places ~/{rel} → {icon}")
if text != orig:
    bak = os.path.join(os.environ.get("XDG_STATE_HOME", os.path.join(home, ".local/state")), "overcast-restore", time.strftime("%Y%m%d-%H%M%S"))
    os.makedirs(bak, exist_ok=True)
    shutil.copy2(path, os.path.join(bak, "user-places.xbel"))
    tmp = path + ".overcast-tmp"
    open(tmp, "w", encoding="utf-8").write(text)
    os.replace(tmp, path)
PY
else
    note "no user-places.xbel yet (log into Plasma once, then re-run to set Places icons)"
fi

# --------------------------------------------------------------------------
step "8/8 kbuildsycoca6"
if command -v kbuildsycoca6 > /dev/null; then
    kbuildsycoca6 > /dev/null 2>&1 && note "menu cache rebuilt" || note "kbuildsycoca6 failed (harmless; runs again at login)"
else
    note "kbuildsycoca6 not found"
fi

echo
if pgrep -u "$(id -u)" -x plasmashell > /dev/null 2>&1; then
    echo "Done. Plasma is running: log out and back in so it picks up the env script and widget."
else
    echo "Done. Next: kde-restore.sh (still with Plasma stopped), then log in."
fi
