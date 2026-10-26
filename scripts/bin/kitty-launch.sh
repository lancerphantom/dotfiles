#!/bin/bash
images=(/home/rdio/Pictures/fastfetch/*)
_img="${images[RANDOM % ${#images[@]}]}"
name=$(basename "$_img")
cached=~/.cache/wal/image-colors/"$name".conf

# generate colors if not cached yet
if [[ ! -f "$cached" ]]; then
  wal -n -i "$_img" -q 2>/dev/null
  mkdir -p ~/.cache/wal/image-colors
  cp ~/.cache/wal/colors-kitty.conf "$cached"
fi

# create temp config with correct colors baked in
_tmp_conf=$(mktemp /tmp/kitty-XXXX.conf)
echo "include /home/rdio/.config/kitty/kitty.conf" > "$_tmp_conf"
echo "include $cached" >> "$_tmp_conf"

FASTFETCH_IMAGE="$_img" kitty --config "$_tmp_conf"
