#!/usr/bin/env bash
# Export a single-thread Compatibility HTML5 build into export/web (repo root,
# outside the Godot project so the editor does not import the WASM/PCK files).
# Must use the *standard* (non-Mono) editor: Godot 4 refuses Web export from
# C#/.NET editor builds even for GDScript-only projects.
# Vercel cannot run Godot; this folder is the static site you deploy.
set -euo pipefail
G="${GODOT_WEB_PATH:-$HOME/Applications/Godot-4.7.1.app/Contents/MacOS/Godot}"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUT="$ROOT/export/web"
TEMPLATES="${GODOT_TEMPLATES_DIR:-$HOME/Library/Application Support/Godot/export_templates/4.7.1.stable}"
NEED="$TEMPLATES/web_nothreads_release.zip"
if [[ ! -x "$G" ]]; then
  echo "Missing standard Godot at $G"
  echo "Run: tools/install_web_templates.sh"
  exit 1
fi
if [[ ! -f "$NEED" ]]; then
  echo "Missing $NEED"
  echo "Run: tools/install_web_templates.sh"
  exit 1
fi
mkdir -p "$OUT"
# Godot refuses to overwrite a dirty HTML export dir in some versions.
find "$OUT" -mindepth 1 -maxdepth 1 ! -name '.vercel' -exec rm -rf {} +
echo "Exporting Web release with $($G --version) → $OUT/index.html"
"$G" --headless --path "$ROOT/game" --export-release "Web" "../export/web/index.html"
cp "$ROOT/hosting/web/vercel.json" "$OUT/vercel.json"
python3 "$ROOT/tools/web_pack_for_vercel.py" "$OUT"
python3 "$ROOT/tools/brand_web_splash.py" "$OUT"
echo "Web export:"
ls -lh "$OUT"
