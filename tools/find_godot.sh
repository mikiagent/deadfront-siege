#!/usr/bin/env bash
set -euo pipefail
if [[ -n "${GODOT_PATH:-}" && -x "${GODOT_PATH}" ]]; then printf '%s\n' "$GODOT_PATH"; exit 0; fi
for candidate in godot4 godot Godot /Applications/Godot.app/Contents/MacOS/Godot /Applications/Godot_mono.app/Contents/MacOS/Godot; do
  if [[ "$candidate" == /* && -x "$candidate" ]]; then printf '%s\n' "$candidate"; exit 0; fi
  if command -v "$candidate" >/dev/null 2>&1; then command -v "$candidate"; exit 0; fi
done
echo 'Godot executable not found. Set GODOT_PATH or add godot4/godot to PATH.' >&2
exit 127
