#!/usr/bin/env bash
# Build the self-contained desktop launcher without overwriting an existing app.
set -euo pipefail
TOOLS_DIR="$(cd "$(dirname "$0")" && pwd)"
DEST="${1:-$HOME/Desktop/Godot Updater.app}"
if [[ -e "$DEST" || -L "$DEST" ]]; then
  echo "Destination already exists: $DEST" >&2
  exit 1
fi
/usr/bin/osacompile -o "$DEST" "$TOOLS_DIR/godot_updater.applescript"
/usr/libexec/PlistBuddy -c "Add :CFBundleIdentifier string local.deadfront.godot-updater" "$DEST/Contents/Info.plist"
cp "$TOOLS_DIR/update_godot.py" "$DEST/Contents/Resources/update_godot.py"
if [[ -f /Applications/Godot_mono.app/Contents/Resources/GodotLG.icns ]]; then
  cp /Applications/Godot_mono.app/Contents/Resources/GodotLG.icns "$DEST/Contents/Resources/applet.icns"
fi
/usr/bin/codesign --force --deep --sign - "$DEST" >/dev/null
echo "Created $DEST"
