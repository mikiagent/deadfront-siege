#!/usr/bin/env bash
# End-to-end test of the downloader shell on this Mac: build packs into a temp dir, serve
# them on localhost, run the shell headless with --shell-auto twice (fresh download, then
# up-to-date launch) and check the [shell] lines. Cleans the desktop user:// build cache after.
set -uo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
G="${GODOT_PATH:-/Applications/Godot_mono.app/Contents/MacOS/Godot}"
DIR="${TMPDIR:-/tmp}/durango_pack_srv"; PORT=8765
USERDIR="$HOME/Library/Application Support/Godot/app_userdata/Durango-like (working title)"
rm -rf "$DIR"; mkdir -p "$DIR"
"$ROOT/tools/publish_pck.sh" --local "$DIR" "$PORT" || exit 1
VER="$(cat "$ROOT/game/shell/build_version.txt")"
rm -rf "$USERDIR/builds" "$USERDIR/shell.cfg"
python3 -m http.server "$PORT" --directory "$DIR" >/dev/null 2>&1 &
SRV=$!
sleep 1
run() { perl -e 'alarm 240; exec @ARGV' "$G" --headless --path "$ROOT/game" --quit-after 400 -- --shell --shell-auto --host="http://127.0.0.1:$PORT" --code=dev 2>&1 | grep -E '^\[(shell|boot|world|smoke)\]|SCRIPT ERROR|ERROR' | grep -v 'get_viewport' ; }
echo "== run 1 (fresh download)"; out1="$(run)"; echo "$out1"
echo "== run 2 (already installed)"; out2="$(run)"; echo "$out2"
kill $SRV 2>/dev/null; wait $SRV 2>/dev/null
rm -rf "$USERDIR/builds" "$USERDIR/shell.cfg"
git -C "$ROOT" checkout -q game/shell/build_version.txt 2>/dev/null || echo dev > "$ROOT/game/shell/build_version.txt"
ok=1
echo "$out1" | grep -q "downloaded core-" || { echo "MISSING: core download"; ok=0; }
echo "$out1" | grep -q "Build $VER ready" || { echo "MISSING: apply"; ok=0; }
echo "$out1" | grep -q "main scene ready" || { echo "MISSING: game start after apply"; ok=0; }
echo "$out2" | grep -q "pack core loaded ($VER)" || { echo "MISSING: pack applied at launch"; ok=0; }
echo "$out2" | grep -q "main scene ready" || { echo "MISSING: game start run 2"; ok=0; }
[[ $ok == 1 ]] && echo "SHELL TEST PASS" || { echo "SHELL TEST FAIL"; exit 1; }
