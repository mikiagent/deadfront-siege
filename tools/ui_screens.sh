#!/usr/bin/env bash
# Screenshots every UI screen the build has (game/scripts/dev/ui_screens_lab.gd) in the landscape
# phone layout, drawn at SCALE x for sharp pixels. Full PNGs land flat in OUT_DIR (the art review
# folder); WebP copies replace docs/current/screens/ for the docs wiki (docs/current/ui-screens.md).
# Needs a window (not --headless) and cwebp. Rerun after any UI change.
# Usage: tools/ui_screens.sh [OUT_DIR=~/Documents/deadfront-ui-screens] [CANVAS=844x390] [SCALE=2]
set -euo pipefail
cd "$(dirname "$0")/.."
out="${1:-$HOME/Documents/deadfront-ui-screens}"
canvas="${2:-844x390}"
scale="${3:-2}"
w=${canvas%x*}
h=${canvas#*x}
godot=$(tools/find_godot.sh)
mkdir -p "$out"
rm -f "$out"/*.png
log=$(mktemp)
perl -e 'alarm 600; exec @ARGV' "$godot" --audio-driver Dummy --path game --resolution "$((w * scale))x$((h * scale))" \
  -- --lab=ui_screens_lab --shot-dir="$out" --canvas="$canvas" > "$log" 2>&1 || true
grep '^\[uiscreens\]' "$log" || true
if ! grep -q '^\[uiscreens\] DONE' "$log"; then
  echo "ui_screens: the lab did not finish; full log in $log" >&2
  exit 1
fi
for f in "$out"/*_[0-9]*x[0-9]*.png; do if [ -e "$f" ]; then mv "$f" "${f%_*}.png"; fi; done  # plate_zoom_1688x780 -> plate_zoom
wiki=docs/current/screens
rm -rf "$wiki"
mkdir -p "$wiki"
for f in "$out"/*.png; do
  cwebp -quiet -q 85 "$f" -o "$wiki/$(basename "${f%.png}").webp"
done
echo "ui_screens: $(ls "$out"/*.png | wc -l | tr -d ' ') PNGs in $out, WebP copies in $wiki"
