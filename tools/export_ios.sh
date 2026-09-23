#!/usr/bin/env bash
# Export an unsigned iOS Xcode project. Debug is for the simulator or a
# development-signed device; --release is required for the TestFlight archive.
set -euo pipefail
G="${GODOT_PATH:-/Applications/Godot_mono.app/Contents/MacOS/Godot}"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUT="$ROOT/game/export/ios"
mkdir -p "$OUT"
rm -f "$OUT/.godot-export-mode"
case "${1:---debug}" in
  --debug) MODE=debug; EXPORT_FLAG=--export-debug ;;
  --release) MODE=release; EXPORT_FLAG=--export-release ;;
  *) echo "usage: tools/export_ios.sh [--debug|--release]" >&2; exit 2 ;;
esac
# Godot writes the Xcode project next to this path when export_project_only is on.
echo "Exporting iOS $MODE Xcode project → $OUT/durango.xcodeproj"
if ! "$G" --headless --path "$ROOT/game" "$EXPORT_FLAG" "iOS" "export/ios/durango.xcodeproj" > "$OUT/godot-export.log" 2>&1; then
  tail -80 "$OUT/godot-export.log" >&2
  exit 1
fi
echo "Godot export complete (log: $OUT/godot-export.log)"
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
if [[ "$MODE" == debug && -f "$LIBDIR/libgodot.ios.template_debug.arm64.simulator.a" && -f "$SIM" ]] && ! lipo -archs "$SIM" | grep -q arm64; then
  lipo -create "$SIM" "$LIBDIR/libgodot.ios.template_debug.arm64.simulator.a" -output "$SIM" && echo "simulator slice now: $(lipo -archs "$SIM")"
fi
printf '%s\n' "$MODE" > "$OUT/.godot-export-mode"
echo "Export finished. Open game/export/ios/*.xcodeproj in Xcode."
