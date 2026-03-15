#!/usr/bin/env bash
set -euo pipefail

WALLPAPER="${1:?Usage: wal-reload.sh /path/to/wallpaper.jpg}"
COLOR_SCHEMES_DIR="$HOME/.local/share/color-schemes"
WAL_CACHE="$HOME/.cache/wal"

echo "[1/5] Generating colors with pywal16..."
wal --cols16 -n -s -t -e -i "$WALLPAPER"

echo "[2/5] Deploying KDE color scheme..."
mkdir -p "$COLOR_SCHEMES_DIR"

# Alternate between two scheme names so plasma-apply-colorscheme always sees a "new" scheme
CURRENT=$(kreadconfig6 --file kdeglobals --group General --key ColorScheme)
if [ "$CURRENT" = "Pywal" ]; then
    SCHEME_NAME="Pywal2"
else
    SCHEME_NAME="Pywal"
fi

# Update the scheme name inside the generated file
sed -i "s/^ColorScheme=.*/ColorScheme=${SCHEME_NAME}/" "$WAL_CACHE/colors-kde.colors"
sed -i "s/^Name=.*/Name=${SCHEME_NAME}/" "$WAL_CACHE/colors-kde.colors"
cp "$WAL_CACHE/colors-kde.colors" "$COLOR_SCHEMES_DIR/${SCHEME_NAME}.colors"

echo "[3/5] Applying KDE color scheme ($SCHEME_NAME)..."
plasma-apply-colorscheme "$SCHEME_NAME"

echo "[4/5] Syncing accent color..."
if command -v jq &> /dev/null && [ -f "$WAL_CACHE/colors.json" ]; then
    ACCENT_HEX=$(jq -r '.colors.color4' "$WAL_CACHE/colors.json")
    ACCENT_R=$((16#${ACCENT_HEX:1:2}))
    ACCENT_G=$((16#${ACCENT_HEX:3:2}))
    ACCENT_B=$((16#${ACCENT_HEX:5:2}))
    ACCENT_RGB="${ACCENT_R},${ACCENT_G},${ACCENT_B}"
    kwriteconfig6 --file kdeglobals --group General --key AccentColor "$ACCENT_RGB"
    kwriteconfig6 --file kdeglobals --group General --key LastUsedCustomAccentColor "$ACCENT_RGB"
    echo "  Accent: $ACCENT_RGB ($ACCENT_HEX)"
else
    echo "  jq missing or no colors.json, skipping accent."
fi

echo "[5/5] Reloading Kitty..."
if pgrep -x kitty > /dev/null 2>&1; then
    pkill -USR1 kitty
    echo "  Kitty reloaded."
else
    echo "  Kitty not running, skipped."
fi

echo "Done! Desktop recolored from: $WALLPAPER"
