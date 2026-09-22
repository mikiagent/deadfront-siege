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
python3 - "$OUT" <<'PYENT'
import pathlib, re, sys
root = pathlib.Path(sys.argv[1])
for p in root.rglob("*.entitlements"):
    s = p.read_text()
    s2 = re.sub(r"\s*<key>aps-environment</key>\s*<string>[^<]*</string>", "", s)
    if s2 != s:
        p.write_text(s2)
        print("stripped aps-environment from", p)
remaining = [str(p) for p in root.rglob("*.entitlements") if "aps-environment" in p.read_text()]
if remaining:
    raise SystemExit("aps-environment remains after export: " + ", ".join(remaining))
PYENT
# Official templates ship Intel-only simulator slices. If the self-built arm64 simulator
# library exists (docs/release/simulator.md), fold it in so tools/sim_run.sh can build for
# Apple Silicon simulators. Device builds are unaffected (separate slice).
LIBDIR="$HOME/Library/Application Support/Godot/sim_arm64_4.7.1"
SIM="$OUT/durango.xcframework/ios-arm64_x86_64-simulator/libgodot.a"
if [[ -f "$LIBDIR/libgodot.ios.template_debug.arm64.simulator.a" && -f "$SIM" ]] && ! lipo -archs "$SIM" | grep -q arm64; then
  lipo -create "$SIM" "$LIBDIR/libgodot.ios.template_debug.arm64.simulator.a" -output "$SIM" && echo "simulator slice now: $(lipo -archs "$SIM")"
fi
echo "Export finished. Open game/export/ios/*.xcodeproj in Xcode."
