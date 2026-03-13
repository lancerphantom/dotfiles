#!/bin/bash
set -e
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "Installing SDDM config..."
sudo cp "$SCRIPT_DIR/sddm.conf" /etc/sddm.conf

echo "Installing theme randomizer script..."
sudo cp "$SCRIPT_DIR/sddm-random-astronaut-theme.sh" /usr/local/bin/sddm-random-astronaut-theme.sh
sudo chmod +x /usr/local/bin/sddm-random-astronaut-theme.sh

echo "Installing systemd service..."
sudo cp "$SCRIPT_DIR/sddm-theme-cycle.service" /etc/systemd/system/sddm-theme-cycle.service

# Clean up old duplicate script and service
if [[ -f /usr/local/bin/sddm-cycle-astronaut ]]; then
    echo "Removing old duplicate script: sddm-cycle-astronaut"
    sudo rm /usr/local/bin/sddm-cycle-astronaut
fi
if [[ -f /etc/systemd/system/sddm-random-theme.service ]]; then
    echo "Disabling and removing old duplicate service: sddm-random-theme.service"
    sudo systemctl disable sddm-random-theme.service 2>/dev/null || true
    sudo rm /etc/systemd/system/sddm-random-theme.service
fi

echo "Enabling service..."
sudo systemctl daemon-reload
sudo systemctl enable sddm-theme-cycle.service

echo "Done! SDDM theme will randomize on every shutdown/reboot."
