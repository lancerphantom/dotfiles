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

# --- Kvantum ---
mkdir -p "$DOTFILES_KDE/Kvantum/KvDarkMinimal"
cp -f "$HOME/.config/Kvantum/kvantum.kvconfig" \
  "$DOTFILES_KDE/Kvantum/kvantum.kvconfig" 2>/dev/null && echo "saved: Kvantum/kvantum.kvconfig"
cp -f "$HOME/.config/Kvantum/KvDarkMinimal/KvDarkMinimal.kvconfig" \
  "$DOTFILES_KDE/Kvantum/KvDarkMinimal/KvDarkMinimal.kvconfig" 2>/dev/null && echo "saved: Kvantum/KvDarkMinimal/KvDarkMinimal.kvconfig"
cp -f "$HOME/.config/Kvantum/KvDarkMinimal/KvDarkMinimal.svg" \
  "$DOTFILES_KDE/Kvantum/KvDarkMinimal/KvDarkMinimal.svg" 2>/dev/null && echo "saved: Kvantum/KvDarkMinimal/KvDarkMinimal.svg"

# --- environment.d (cursor vars) ---
mkdir -p "$DOTFILES_KDE/environment.d"
cp -f "$HOME/.config/environment.d/cursor.conf" \
  "$DOTFILES_KDE/environment.d/cursor.conf" 2>/dev/null && echo "saved: environment.d/cursor.conf"

# --- kde-material-you-colors ---
mkdir -p "$DOTFILES_KDE/kde-material-you-colors"
cp -f "$HOME/.config/kde-material-you-colors/config.conf" \
  "$DOTFILES_KDE/kde-material-you-colors/config.conf" 2>/dev/null && echo "saved: kde-material-you-colors/config.conf"

# --- systemd user service ---
mkdir -p "$DOTFILES_KDE/systemd/user"
cp -f "$HOME/.config/systemd/user/kde-material-you-colors.service" \
  "$DOTFILES_KDE/systemd/user/kde-material-you-colors.service" 2>/dev/null && echo "saved: systemd/user/kde-material-you-colors.service"

# --- Plasma desktop theme (DarkMinimal) ---
DOTFILES_THEME="$HOME/dotfiles/kde/.local/share/plasma/desktoptheme/DarkMinimal"
mkdir -p "$DOTFILES_THEME"
cp -rf "$HOME/.local/share/plasma/desktoptheme/DarkMinimal/"* \
  "$DOTFILES_THEME/" 2>/dev/null && echo "saved: DarkMinimal plasma theme"

echo ""
echo "Done. Review changes with: git -C ~/dotfiles diff --stat"
