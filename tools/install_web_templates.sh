#!/usr/bin/env bash
# Install the standard (non-Mono) Godot 4.7.1 editor plus official web WASM
# templates. The Mono editor cannot export HTML5 (Godot 4 C# web is unsupported).
set -euo pipefail
STD_APP="${GODOT_WEB_APP:-$HOME/Applications/Godot-4.7.1.app}"
STD_TEMPLATES="${GODOT_TEMPLATES_DIR:-$HOME/Library/Application Support/Godot/export_templates/4.7.1.stable}"
MONO_TEMPLATES="$HOME/Library/Application Support/Godot/export_templates/4.7.1.stable.mono"
TPZ_DIR="${GODOT_TEMPLATES_TPZ_DIR:-/tmp/godot-tpz}"
STD_DIR="${GODOT_STD_DIR:-/tmp/godot-std}"
TPZ="$TPZ_DIR/Godot_v4.7.1-stable_export_templates.tpz"
MAC_ZIP="$STD_DIR/Godot_v4.7.1-stable_macos.universal.zip"

mkdir -p "$TPZ_DIR" "$STD_DIR" "$HOME/Applications" "$STD_TEMPLATES" "$MONO_TEMPLATES"

if [[ ! -x "$STD_APP/Contents/MacOS/Godot" ]]; then
  if [[ ! -f "$MAC_ZIP" ]]; then
    echo "Downloading Godot 4.7.1 standard macOS editor…"
    gh release download 4.7.1-stable --repo godotengine/godot \
      --pattern 'Godot_v4.7.1-stable_macos.universal.zip' --dir "$STD_DIR"
  fi
  echo "Installing $STD_APP"
  rm -rf /tmp/godot-std-app
  unzip -q -o "$MAC_ZIP" -d /tmp/godot-std-app
  rm -rf "$STD_APP"
  ditto /tmp/godot-std-app/Godot.app "$STD_APP"
  xattr -dr com.apple.quarantine "$STD_APP" 2>/dev/null || true
fi
echo "Standard Godot: $("$STD_APP/Contents/MacOS/Godot" --version)"

if [[ ! -f "$TPZ" ]]; then
  echo "Downloading Godot 4.7.1 standard export templates (~1.2 GB)…"
  gh release download 4.7.1-stable --repo godotengine/godot \
    --pattern 'Godot_v4.7.1-stable_export_templates.tpz' --dir "$TPZ_DIR"
fi

python3 - "$TPZ" "$STD_TEMPLATES" "$MONO_TEMPLATES" <<'PY'
import shutil, sys, zipfile
from pathlib import Path
tpz, std, mono = Path(sys.argv[1]), Path(sys.argv[2]), Path(sys.argv[3])
std.mkdir(parents=True, exist_ok=True)
mono.mkdir(parents=True, exist_ok=True)
(std / "version.txt").write_text("4.7.1.stable\n")
with zipfile.ZipFile(tpz) as z:
    names = [n for n in z.namelist() if n.startswith("templates/web") and n.endswith(".zip")]
    if not names:
        raise SystemExit("no web_*.zip inside " + str(tpz))
    for n in names:
        data = z.read(n)
        name = Path(n).name
        for dest in (std, mono):
            out = dest / name
            print("extract", name, "->", out)
            out.write_bytes(data)
PY
echo "Web templates in $STD_TEMPLATES:"
ls -lh "$STD_TEMPLATES"/web*.zip
