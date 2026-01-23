#!/bin/bash

# Check for pending updates using checkupdates
# checkupdates prints updates to stdout, errors to stderr
updates=$(checkupdates 2>/dev/null)

# Check if the updates string is non-empty
if [ -n "$updates" ]; then
    # Count the number of updates
    count=$(echo "$updates" | wc -l)
    # Get package names (optional, could make notification too long)
    # packages=$(echo "$updates" | awk '{print $1}' | paste -sd ', ')

    # Send notification
    notify-send -i software-update-available -u normal "Arch Linux Updates Available" "$count pending update(s). Run 'sudo pacman -Syu' to upgrade."
    # Uncomment the line below and comment the one above if you want package names:
    # notify-send -i software-update-available -u normal "Arch Linux Updates Available ($count)" "$packages"
else
    # No updates are available - send a notification anyway
    notify-send -i software-update-available -u low "Arch Linux" "System is up to date."
fi

exit 0
