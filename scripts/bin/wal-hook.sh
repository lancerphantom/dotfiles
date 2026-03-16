#!/usr/bin/env bash
# Reload Kitty when kde-material-you-colors changes colors
if pgrep -x kitty > /dev/null 2>&1; then
    pkill -USR1 kitty
fi
