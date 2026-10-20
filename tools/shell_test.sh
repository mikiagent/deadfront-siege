#!/usr/bin/env bash
# End-to-end test of the downloader shell on this Mac: build packs into a temp dir, serve
# them on localhost, run the shell headless with --shell-auto twice (fresh download, then
# up-to-date launch) and check the [shell] lines. The game runs with HOME pointed at a temp dir
# (Godot on macOS ignores XDG_DATA_HOME), so its user:// downloads and saves never touch a real save.
set -uo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
G="$($ROOT/tools/find_godot.sh)"
DIR="${TMPDIR:-/tmp}/durango_pack_srv"; PORT=8765
TMPHOME="$(mktemp -d "${TMPDIR:-/tmp}/durango_shell_home.XXXXXX")"
rm -rf "$DIR"; mkdir -p "$DIR"
"$ROOT/tools/publish_pck.sh" --local "$DIR" "$PORT" || exit 1
VER="$(cat "$ROOT/game/shell/build_version.txt")"
python3 -m http.server "$PORT" --directory "$DIR" >/dev/null 2>&1 &
SRV=$!
sleep 1
run() { HOME="$TMPHOME" perl -e 'alarm 240; exec @ARGV' "$G" --headless --path "$ROOT/game" --quit-after 400 -- --shell --shell-auto --host="http://127.0.0.1:$PORT" --code=dev 2>&1 | grep -E '^\[(shell|boot|world|smoke)\]|SCRIPT ERROR|ERROR' | grep -v 'get_viewport' ; }
echo "== run 1 (fresh download)"; out1="$(run)"; echo "$out1"
echo "== run 2 (already installed)"; out2="$(run)"; echo "$out2"
kill $SRV 2>/dev/null; wait $SRV 2>/dev/null
rm -rf "$TMPHOME"
git -C "$ROOT" checkout -q game/shell/build_version.txt 2>/dev/null || echo dev > "$ROOT/game/shell/build_version.txt"
ok=1
echo "$out1" | grep -q "downloaded core-" || { echo "MISSING: core download"; ok=0; }
echo "$out1" | grep -q "Build $VER ready" || { echo "MISSING: apply"; ok=0; }
echo "$out1" | grep -q "main scene ready" || { echo "MISSING: game start after apply"; ok=0; }
echo "$out2" | grep -q "pack core loaded ($VER)" || { echo "MISSING: pack applied at launch"; ok=0; }
echo "$out2" | grep -q "main scene ready" || { echo "MISSING: game start run 2"; ok=0; }
[[ $ok == 1 ]] && echo "SHELL TEST PASS" || { echo "SHELL TEST FAIL"; exit 1; }
