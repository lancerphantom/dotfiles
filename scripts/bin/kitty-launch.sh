#!/bin/bash
# Meta+` (net.local.bash.desktop) and the dock's kitty launcher start this.
# Colours, fastfetch and the prompt now come from Overcast (terminal.py), so
# this just opens a kitty window; the old random-picture + pywal step is gone.
exec kitty "$@"
