#!/bin/bash
# kde-restore.sh — copy KDE configs FROM dotfiles repo to live system
# Run this after git pull on either machine, then log out/in

DOTFILES_KDE="$HOME/dotfiles/kde/.config"

KDE_CONFIGS=(
    kdeglobals
    kwinrc
    plasmarc
    plasmashellrc
    plasma-org.kde.plasma.desktop-appletsrc
    kglobalshortcutsrc
    kscreenlockerrc
    konsolerc
    dolphinrc
    kcminputrc
)

for conf in "${KDE_CONFIGS[@]}"; do
    src="$DOTFILES_KDE/$conf"
    [[ -f "$src" ]] || continue
    dst="$HOME/.config/$conf"
    # backup live file if it differs
    if [[ -f "$dst" ]] && ! diff -q "$src" "$dst" &>/dev/null; then
        cp "$dst" "${dst}.bak.$(date +%s)"
        echo "backed up: $conf"
    fi
    cp -f "$src" "$dst"
    echo "restored: $conf"
done

echo "Done. Log out and back in for changes to apply."
