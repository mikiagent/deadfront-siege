#!/usr/bin/env bash
# Export an unsigned iOS Xcode project. The owner opens it in Xcode, picks a
# Personal Team, and runs on a device. Do not codesign from this script.
set -euo pipefail
G="${GODOT_PATH:-/Applications/Godot_mono.app/Contents/MacOS/Godot}"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUT="$ROOT/game/export/ios"
mkdir -p "$OUT"
# Godot writes the Xcode project next to this path when export_project_only is on.
echo "Exporting iOS debug Xcode project → $OUT/durango.xcodeproj"
"$G" --headless --path "$ROOT/game" --export-debug "iOS" "export/ios/durango.xcodeproj"
# Godot writes an aps-environment entitlement even with push notifications off; a
# free/personal provisioning profile rejects it, so strip it after every export.
python3 - <<'PY'
import pathlib, re
for p in pathlib.Path("$OUT").rglob("*.entitlements"):
    s = p.read_text(); s2 = re.sub(r"\s*<key>aps-environment</key>\s*<string>[^<]*</string>", "", s)
    if s2 != s: p.write_text(s2); print("stripped aps-environment from", p)
PY
echo "Export finished. Open game/export/ios/*.xcodeproj in Xcode."
