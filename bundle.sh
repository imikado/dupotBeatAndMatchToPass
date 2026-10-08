#!/bin/bash
set -e

cd "$(dirname "$0")"

GODOT="${GODOT:-$HOME/Apps/Godot_v4.7-stable_linux.x86_64}"
PRESET="Linux/X11"
PCK_NAME="beatmatchtopass.pck"

rm -rf export/linux/bundle
rm -f export/linux/bundle.tar.gz
mkdir -p export/linux/bundle/icons

# Import resources then export the pck with the project's Godot version
"$GODOT" --headless --path . --import
"$GODOT" --headless --path . --export-pack "$PRESET" "export/linux/bundle/$PCK_NAME"

for size in 16x16 24x24 32x32 48x48 64x64 512x512; do
    cp export/linux/flatpak/$size.png export/linux/bundle/icons/
done
cp export/linux/flatpak/org.dupot.beatmatchtopass.appdata.xml export/linux/bundle/
cp export/linux/flatpak/org.dupot.beatmatchtopass.desktop export/linux/bundle/
tar -cvzf export/linux/bundle.tar.gz -C export/linux/bundle .
