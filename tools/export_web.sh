#!/usr/bin/env bash
set -euo pipefail

# Export the game for the browser and make an itch.io-ready zip.
# Run from Git Bash on Windows:
#   bash tools/export_web.sh
# Or override the Godot binary:
#   GODOT="/c/Program Files/Godot/godot.exe" bash tools/export_web.sh

GODOT="${GODOT:-D:/Godot/Godot_v4.7.2-stable_win64_console.exe}"
PROJ="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OUT="$PROJ/build/web"
ZIP="$PROJ/build/NaturalDeduction-web.zip"

if [ ! -f "$GODOT" ]; then
  echo "Godot executable not found: $GODOT" >&2
  echo "Set GODOT=/path/to/Godot_v4.7.2-stable_win64_console.exe" >&2
  exit 1
fi

if command -v cygpath >/dev/null 2>&1; then
  APP_DATA_POSIX="$(cygpath -u "${APPDATA:-$HOME/AppData/Roaming}")"
else
  APP_DATA_POSIX="${APPDATA:-$HOME/AppData/Roaming}"
fi
TEMPLATES="$APP_DATA_POSIX/Godot/export_templates/4.7.2.stable"
if [ ! -f "$TEMPLATES/web_nothreads_release.zip" ]; then
  echo "Missing Godot 4.7.2 Web export templates." >&2
  echo "Open Godot -> Editor -> Manage Export Templates -> Download and Install." >&2
  echo "Expected: $TEMPLATES/web_nothreads_release.zip" >&2
  exit 1
fi

echo "Importing latest resources..."
"$GODOT" --headless --path "$PROJ" --import

echo "Exporting Web release..."
rm -rf "$OUT"
mkdir -p "$OUT"
"$GODOT" --headless --path "$PROJ" --export-release "Web" "$OUT/index.html"

# itch.io only serves the game; these files provide the required attribution.
mkdir -p "$OUT/licenses"
cp -r "$PROJ/audio/licenses/." "$OUT/licenses/"
cp "$PROJ/audio/sfx/CREDITS.md" "$OUT/licenses/SFX_CREDITS.md"
cp "$PROJ/audio/music/CREDITS.md" "$OUT/licenses/MUSIC_CREDITS.md"
cp "$PROJ"/ui/fonts/OFL-*.txt "$OUT/licenses/"

# Zip the CONTENTS of build/web, not the folder, so index.html is at zip root.
rm -f "$ZIP"
( cd "$OUT" && zip -q -r "$ZIP" . )

echo
echo "Wrote: $ZIP"
echo "Upload this zip to itch.io and tick:"
echo "  This file will be played in the browser"
echo "Then set the embed viewport to 1280 x 720."
