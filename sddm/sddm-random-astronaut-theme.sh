#!/bin/bash

THEME_DIR="/usr/share/sddm/themes/sddm-astronaut-theme"
METADATA="$THEME_DIR/metadata.desktop"
CONFIG_DIR="$THEME_DIR/Themes"

# Get a list of all .conf files in Themes/
mapfile -t configs < <(find "$CONFIG_DIR" -type f -name "*.conf")

# Choose one at random
RANDOM_CONFIG=$(shuf -n 1 -e "${configs[@]}")

# Convert to relative path from $THEME_DIR
RELATIVE_CONFIG_PATH="${RANDOM_CONFIG#$THEME_DIR/}"

# Update the metadata.desktop file with the new config
sudo sed -i "s|^ConfigFile=.*|ConfigFile=$RELATIVE_CONFIG_PATH|" "$METADATA"

echo "Switched to SDDM astronaut config: $RELATIVE_CONFIG_PATH"
