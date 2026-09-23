#!/usr/bin/env bash
# Build, install and launch the game on the booted iPhone simulator, then screenshot it.
# Usage: tools/sim_run.sh [--no-export] [screenshot.png]
# Needs the arm64 simulator library (see docs/release/simulator.md) and a booted simulator
# (xcrun simctl boot "iPhone 17 Pro").
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"; OUT="$ROOT/game/export/ios"
WORK="${SIM_WORK:-$HOME/Library/Caches/durango-sim}"; mkdir -p "$WORK"
SHOT="${2:-$WORK/sim_shot.png}"
[[ "${1:-}" == "--no-export" ]] || "$ROOT/tools/export_ios.sh"
UDID=$(xcrun simctl list devices booted | grep -oE '[0-9A-F-]{36}' | head -1)
[[ -n "$UDID" ]] || { echo "no booted simulator; run: xcrun simctl boot \"iPhone 17 Pro\""; exit 1; }
if ! xcodebuild -project "$OUT/durango.xcodeproj" -scheme durango -configuration Debug \
  -destination "platform=iOS Simulator,id=$UDID" -derivedDataPath "$WORK/dd" CODE_SIGNING_ALLOWED=NO build > "$WORK/build.log" 2>&1; then
  rg 'error:|BUILD (SUCCEEDED|FAILED)' "$WORK/build.log" | tail -30 || tail -30 "$WORK/build.log"
  exit 1
fi
rg 'BUILD SUCCEEDED' "$WORK/build.log" | tail -1 || true
APP="$WORK/dd/Build/Products/Debug-iphonesimulator/durango.app"; [[ -d "$APP" ]] || { echo "build failed"; exit 1; }
BUNDLE_ID=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$APP/Info.plist")
xcrun simctl install "$UDID" "$APP"
xcrun simctl terminate "$UDID" "$BUNDLE_ID" 2>/dev/null || true
# Godot reads NSProcessInfo arguments, so engine flags can be passed here (e.g. --rendering-driver vulkan).
# shellcheck disable=SC2086
xcrun simctl launch "$UDID" "$BUNDLE_ID" ${LAUNCH_ARGS:-}
sleep "${SIM_WAIT:-15}"
xcrun simctl io "$UDID" screenshot --type=png "$SHOT" >/dev/null && echo "screenshot: $SHOT"
