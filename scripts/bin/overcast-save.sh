#!/usr/bin/env bash
# overcast-save.sh — record this machine's Overcast settings in ~/dotfiles/overcast/.
#
# Writes:
#   folder-icons.tsv    Icon= of every ~/<folder>/.directory (one level deep)
#   launcher-icons.tsv  current Icon= of each launcher already listed there
#   places-icons.tsv    current icon of each Places bookmark already listed there
#   overcast.conf       OVERCAST_REF = the Overcast checkout's current commit
#
# Checks (warns, changes nothing):
#   - the installed systemd units and env script match the Overcast project's copies
#   - the Overcast checkout has no uncommitted changes (the pin wouldn't cover them)
#   - other local launchers that use an Overcast icon but aren't listed
#
# The Overcast project is the source of truth for its units and env script;
# they are not copied into dotfiles. Review with: git -C ~/dotfiles diff -- overcast
set -euo pipefail

DOTFILES="${DOTFILES:-$HOME/dotfiles}"
CONF_DIR="$DOTFILES/overcast"
DEFAULT_UNIT_DIR='%h/projects/claudeCode/kdeCons'
XDG_DATA_HOME="${XDG_DATA_HOME:-$HOME/.local/share}"
XDG_CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"
UNITS=(overcast-refresh.path overcast-refresh.service overcast-tasks-check.service)

# shellcheck source=/dev/null
source "$CONF_DIR/overcast.conf"

note() { echo "    $*"; }
warn() { echo "    warn: $*"; }

# get_icon FILE — print Icon= from the [Desktop Entry] group, or nothing.
get_icon() {
    awk '/^\[/ { g = ($0 == "[Desktop Entry]"); next }
         g && /^Icon=/ { print substr($0, 6); exit }' "$1" 2>/dev/null
}
read_map() { [[ -f "$1" ]] && grep -v -e '^[[:space:]]*#' -e '^[[:space:]]*$' "$1" || true; }

# --------------------------------------------------------------------------
echo "==> folder icons"
tmp=$(mktemp)
{
    echo "# Folder icons: <folder relative to \$HOME><TAB><icon name>"
    echo "# Written by overcast-save.sh from \$HOME/*/.directory; applied by overcast-restore.sh."
    for d in "$HOME"/*/; do
        d="${d%/}"
        [[ -f "$d/.directory" ]] || continue
        icon=$(get_icon "$d/.directory")
        if [[ -n "$icon" ]]; then printf '%s\t%s\n' "${d#"$HOME/"}" "$icon"; fi
    done | LC_ALL=C sort
} > "$tmp"
mv -f "$tmp" "$CONF_DIR/folder-icons.tsv"
note "$(grep -vc '^#' "$CONF_DIR/folder-icons.tsv") folders recorded"

# --------------------------------------------------------------------------
echo "==> launcher icons"
apps="$XDG_DATA_HOME/applications"
tmp=$(mktemp)
grep '^#' "$CONF_DIR/launcher-icons.tsv" > "$tmp" 2>/dev/null || true
listed=()
while IFS=$'\t' read -r desktop icon; do
    [[ -n "$desktop" ]] || continue
    listed+=("$desktop")
    if [[ -f "$apps/$desktop" ]]; then
        live=$(get_icon "$apps/$desktop")
        if [[ -n "$live" && "$live" != "$icon" ]]; then
            note "$desktop: $icon → $live"
            icon="$live"
        fi
    else
        warn "$desktop is not installed here; keeping the recorded icon ($icon)"
    fi
    printf '%s\t%s\n' "$desktop" "$icon" >> "$tmp"
done < <(read_map "$CONF_DIR/launcher-icons.tsv")
mv -f "$tmp" "$CONF_DIR/launcher-icons.tsv"

# Unlisted launchers that use an icon Overcast draws.
if [[ -d "$OVERCAST_DIR/templates/apps" && -d "$apps" ]]; then
    for f in "$apps"/*.desktop; do
        [[ -f "$f" ]] || continue
        name="${f##*/}"
        printf '%s\n' "${listed[@]}" | grep -qxF "$name" && continue
        icon=$(get_icon "$f")
        [[ -n "$icon" && -f "$OVERCAST_DIR/templates/apps/$icon.svg" ]] || continue
        exec_line=$(awk -F= '/^Exec=/ { print $2; exit }' "$f")
        bin="${exec_line%% *}"; bin="${bin//\"/}"
        if [[ "$bin" == /* && ! -e "$bin" ]]; then
            warn "$name uses Overcast icon '$icon' but its Exec target is gone ($bin) — KDE hides it"
        else
            note "unlisted: $name uses Overcast icon '$icon' (add to launcher-icons.tsv to keep it)"
        fi
    done
fi

# --------------------------------------------------------------------------
echo "==> Places icons"
places="$XDG_DATA_HOME/user-places.xbel"
if [[ -f "$places" ]]; then
    tmp=$(mktemp)
    grep '^#' "$CONF_DIR/places-icons.tsv" > "$tmp" 2>/dev/null || true
    python3 - "$places" "$HOME" <(read_map "$CONF_DIR/places-icons.tsv") >> "$tmp" <<'PY'
import re, sys, os
from urllib.parse import quote
path, home, mapfile = sys.argv[1:]
text = open(path, encoding="utf-8").read()
for line in open(mapfile, encoding="utf-8"):
    rel, icon = line.rstrip("\n").split("\t", 1)
    rel = rel.strip("/")
    # KDE may store a folder bookmark with or without a trailing slash.
    href = "file://" + quote(os.path.join(home, rel))
    m = re.search(r'<bookmark href="%s/?">.*?</bookmark>' % re.escape(href), text, re.S)
    if m:
        i = re.search(r'<bookmark:icon name="([^"]*)"', m.group(0))
        if i and i.group(1) != icon:
            print(f"    ~/{rel}: {icon} → {i.group(1)}", file=sys.stderr)
            icon = i.group(1)
    else:
        print(f"    warn: no Places bookmark for ~/{rel}; keeping the recorded icon", file=sys.stderr)
    print(f"{rel}\t{icon}")
PY
    mv -f "$tmp" "$CONF_DIR/places-icons.tsv"
else
    warn "no $places; left places-icons.tsv as is"
fi

# --------------------------------------------------------------------------
echo "==> units and env script vs the Overcast project"
unit_dir="$XDG_CONFIG_HOME/systemd/user"
if [[ "$OVERCAST_DIR" == "$HOME/"* ]]; then unit_path="%h/${OVERCAST_DIR#"$HOME/"}"; else unit_path="$OVERCAST_DIR"; fi
for u in "${UNITS[@]}"; do
    src="$OVERCAST_DIR/systemd/$u"
    if [[ ! -f "$unit_dir/$u" ]]; then warn "$u is not installed"; continue; fi
    if [[ ! -f "$src" ]]; then warn "$src missing"; continue; fi
    if ! diff -q <(sed "s|$DEFAULT_UNIT_DIR|$unit_path|g" "$src") "$unit_dir/$u" > /dev/null; then
        warn "$u: installed copy differs from the Overcast project's — edit it there, then re-run overcast-restore.sh --no-build"
    fi
    if command -v systemctl > /dev/null && ! systemctl --user is-enabled --quiet "$u" 2>/dev/null; then
        warn "$u is installed but not enabled"
    fi
done
env_live="$XDG_CONFIG_HOME/plasma-workspace/env/overcast-tasks.sh"
env_src="$OVERCAST_DIR/plasma-workspace/env/overcast-tasks.sh"
if [[ ! -f "$env_live" ]]; then
    warn "$env_live is missing — the dock will be empty after the next login"
elif [[ ! -f "$env_src" ]]; then
    warn "$env_src missing — overcast-restore.sh needs it; update the Overcast checkout"
elif ! cmp -s "$env_src" "$env_live"; then
    warn "env script differs from the Overcast project's copy"
fi

# --------------------------------------------------------------------------
echo "==> Overcast revision"
if [[ -d "$OVERCAST_DIR/.git" ]]; then
    head=$(git -C "$OVERCAST_DIR" rev-parse HEAD)
    if [[ -n "$(git -C "$OVERCAST_DIR" status --porcelain)" ]]; then
        warn "the Overcast checkout has uncommitted changes; the pin only covers committed work"
    fi
    if ! git -C "$OVERCAST_DIR" branch -r --contains "$head" 2>/dev/null | grep -q .; then
        warn "${head:0:12} isn't on any remote branch yet — push Overcast, or a new machine can't fetch it"
    fi
    sed -i "s|^OVERCAST_REF=.*|OVERCAST_REF=\"$head\"|" "$CONF_DIR/overcast.conf"
    url=$(git -C "$OVERCAST_DIR" remote get-url origin 2>/dev/null || true)
    if [[ -n "$url" ]] && ! grep -q "^OVERCAST_REPO=\"..*\"" "$CONF_DIR/overcast.conf"; then
        sed -i "s|^OVERCAST_REPO=.*|OVERCAST_REPO=\"$url\"|" "$CONF_DIR/overcast.conf"
        note "OVERCAST_REPO set to $url"
    fi
    note "pinned ${head:0:12}"
else
    warn "$OVERCAST_DIR is not a git repo; nothing to pin (a new machine can't get it)"
fi

echo
echo "Review: git -C \"$DOTFILES\" diff -- overcast"
