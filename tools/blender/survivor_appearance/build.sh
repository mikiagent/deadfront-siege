#!/usr/bin/env bash
# Rebuilds every survivor hair option from the shipped head region (headless Blender, 0 credits) and renders the
# inspection sheet. Usage: tools/blender/survivor_appearance/build.sh [sheet.png]
# Source: body/body_helmet.glb as shipped at 29ffa292 (the head with its baked hair), read from git so a re-run
# never starts from a processed file.
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/../../.." && pwd)"
B="${BLENDER:-/Applications/Blender.app/Contents/MacOS/Blender}"
OUT="$ROOT/game/assets/characters/survivor/hair"
TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
git -C "$ROOT" show 29ffa292:game/assets/characters/survivor/body/body_helmet.glb > "$TMP/body_helmet.glb"
run() { "$B" -b --factory-startup -P "$HERE/$1" -- "${@:2}" 2>&1 | grep -E '^(SPLIT|PAINT|CROP|DIFF|SHEET|WORST)|Error|Traceback' || true; }
run split_hair.py "$TMP/body_helmet.glb" "$OUT"
run paint_scalp.py "$OUT"
run crop_hair.py "$OUT"
SHEET="${1:-$TMP/sheet.png}"
run render_options.py "$(dirname "$SHEET")/renders" "$SHEET" \
  base="$ROOT/game/assets/characters/survivor/body/body_helmet.glb" \
  current="$OUT/head.glb,$OUT/hair_current.glb" buzz="$OUT/head_buzz.glb" bald="$OUT/head_bald.glb" \
  crop="$OUT/head.glb,$OUT/hair_crop.glb"
run clip_penetration.py "$ROOT/game/assets/characters/survivor" "$OUT/clip_penetration.json" \
  current="$OUT/hair_current.glb" crop="$OUT/hair_crop.glb"
