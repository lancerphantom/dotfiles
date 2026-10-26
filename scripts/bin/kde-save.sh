#!/usr/bin/env bash
# kde-save.sh — copy live KDE configs INTO the dotfiles repo.
#
# The file list is ~/dotfiles/kde/manifest.txt, shared with kde-restore.sh.
# Run after a theme or panel change you want to keep, then review with
#   git -C ~/dotfiles diff --stat
#
# Safe to run inside a live Plasma session (it only reads ~/.config). For a
# consistent snapshot of the panel files, change panels first, wait a few
# seconds for plasmashell to write them, then save.
set -euo pipefail

DOTFILES="${DOTFILES:-$HOME/dotfiles}"
MANIFEST="$DOTFILES/kde/manifest.txt"
DEST="$DOTFILES/kde"

# Credential locations are never copied, whatever the manifest says.
DENY='(^|/)\.config/(gh|secrets)(/|$)|(^|/)\.(ssh|gnupg)(/|$)|(^|/)\.local/share/keyrings(/|$)'

[[ -f "$MANIFEST" ]] || { echo "error: $MANIFEST not found" >&2; exit 1; }

saved=0 missing=0
while IFS= read -r rel; do
    rel="${rel%%#*}"; rel="${rel%"${rel##*[![:space:]]}"}"   # strip comments, trailing space
    [[ -n "$rel" ]] || continue
    if [[ "$rel" =~ $DENY ]]; then echo "REFUSED (credentials): $rel"; continue; fi
    src="$HOME/$rel" dst="$DEST/$rel"

    if [[ "$rel" == */ ]]; then
        if [[ ! -d "$src" ]]; then
            echo "missing: $rel"; missing=$((missing + 1)); continue
        fi
        mkdir -p "$dst"
        cp -a "$src." "$dst"
        # Report (don't delete) files the repo has but the live dir no longer does.
        while IFS= read -r -d '' g; do
            g="${g#./}"
            [[ -e "$src$g" ]] || echo "stale in repo (gone from live): $rel$g"
        done < <(cd "$dst" && find . -type f -print0)
    else
        if [[ ! -f "$src" ]]; then
            echo "missing: $rel"; missing=$((missing + 1)); continue
        fi
        mkdir -p "$(dirname "$dst")"
        cp -f "$src" "$dst"
    fi
    echo "saved: $rel"
    saved=$((saved + 1))
done < "$MANIFEST"

echo
echo "$saved saved, $missing missing."
echo "Review: git -C \"$DOTFILES\" diff --stat -- kde"
