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
PACK_HASH="$(python3 - "$OUT/pack.manifest.json" <<'PY2'
import json
from pathlib import Path
import sys
part = json.loads(Path(sys.argv[1]).read_text())["parts"][0]
print(part.split(".")[1])
PY2
)"
COMMIT="$(git -C "$ROOT" rev-parse --short=9 HEAD)"
python3 - "$OUT/index.html" "$COMMIT" "$PACK_HASH" <<'PY2'
from pathlib import Path
import sys
p = Path(sys.argv[1])
s = p.read_text()
needle = 'const GODOT_CONFIG = '
pos = s.find(needle)
if pos < 0:
    raise SystemExit('Godot config marker missing')
line_end = s.find('\n', pos)
s = s[:line_end + 1] + f"GODOT_CONFIG.args.push('--', '--build={sys.argv[2]}/{sys.argv[3]}');\n" + s[line_end + 1:]
p.write_text(s)
PY2
python3 "$ROOT/tools/brand_web_splash.py" "$OUT"
echo "Web export:"
ls -lh "$OUT"
