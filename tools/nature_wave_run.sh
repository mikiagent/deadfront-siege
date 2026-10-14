#!/usr/bin/env bash
# Normalize + inspect one downloaded Meshy GLB.  Usage: nature_wave_run.sh <work_dir> <name> <height_m>
# Reads <work_dir>/raw/<name>.glb, writes <work_dir>/fin/<name>.glb and <work_dir>/sheets/<name>.png.
set -euo pipefail
W="$1"; N="$2"; H="$3"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
B="${BLENDER:-/Applications/Blender.app/Contents/MacOS/Blender}"
mkdir -p "$W/fin" "$W/sheets" "$W/tiles"
"$B" --background --python "$ROOT/tools/nature_wave_finish.py" -- finish "$W/raw/$N.glb" "$W/fin/$N.glb" "$H" 2>&1 | grep -E "^REPORT|Error|Traceback" | tee "$W/fin/$N.report.txt"
"$B" --background --python "$ROOT/tools/nature_wave_finish.py" -- inspect "$W/fin/$N.glb" "$W/tiles/$N" 2>&1 | grep -E "Error|Traceback" || true
uv run --with pillow python "$ROOT/tools/nature_wave_sheet.py" "$N (${H} m)" "$W/sheets/$N.png" \
  front="$W/tiles/${N}_front.png" side="$W/tiles/${N}_side.png" 3/4="$W/tiles/${N}_three-quarter.png" \
  "game-15m=$W/tiles/${N}_game15.png" "game-17m=$W/tiles/${N}_game17.png" >/dev/null
echo "$W/sheets/$N.png"
