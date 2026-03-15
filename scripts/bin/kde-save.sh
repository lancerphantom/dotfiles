#!/bin/bash
# kde-save.sh — copy live KDE configs INTO the dotfiles repo
# Run this on sandbox after making theme changes you want to keep

DOTFILES_KDE="$HOME/dotfiles/kde/.config"
mkdir -p "$DOTFILES_KDE"

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
    breezerc
)

for conf in "${KDE_CONFIGS[@]}"; do
    src="$HOME/.config/$conf"
    [[ -f "$src" ]] || continue
    cp -f "$src" "$DOTFILES_KDE/$conf"
    echo "saved: $conf"
done

echo "Done. Review changes with: git -C ~/dotfiles diff"
