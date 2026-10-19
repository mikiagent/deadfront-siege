#!/usr/bin/env bash
# Online smoke: one headless server process and two headless client processes over localhost.
# Each client runs the normal game with --online=ws://127.0.0.1:<port> --net-probe, walks,
# chats once it sees the other, and prints [netprobe] lines. Exit 0 + "NET SMOKE PASS" only
# if both clients saw each other's presence and heard each other's chat.
# Usage: tools/net_smoke.sh            (assumes the project is imported)
set -u
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
G="$($ROOT/tools/find_godot.sh)"
WORK="$(mktemp -d "${TMPDIR:-/tmp}/net_smoke.XXXXXX")"
SERVER_PID=""
cleanup() {
  [[ -n "$SERVER_PID" ]] && kill "$SERVER_PID" 2>/dev/null
  wait 2>/dev/null
  rm -rf "$WORK"
}
trap cleanup EXIT

# --port=0: the server binds a free port and logs it, so parallel runs never collide.
perl -e 'alarm 120; exec @ARGV' "$G" --headless --path "$ROOT/game" -- --server --port=0 --data="$WORK/data" >"$WORK/server.log" 2>&1 &
SERVER_PID=$!
PORT=""
for _ in $(seq 1 120); do
  PORT="$(grep -o '"ev":"listen"[^}]*' "$WORK/server.log" 2>/dev/null | grep -o '"port":[0-9]*' | head -1 | cut -d: -f2)"
  [[ -n "$PORT" ]] && break
  kill -0 "$SERVER_PID" 2>/dev/null || break
  sleep 0.5
done
if [[ -z "$PORT" ]]; then
  echo "server did not start:"; tail -20 "$WORK/server.log"
  echo "NET SMOKE FAIL"; exit 1
fi
echo "[server] listening on $PORT"

URL="ws://127.0.0.1:$PORT"
for who in a b; do
  perl -e 'alarm 90; exec @ARGV' "$G" --headless --path "$ROOT/game" -- --online="$URL" --net-probe >"$WORK/client_$who.log" 2>&1 &
  eval "PID_$who=\$!"
done
wait "$PID_a"; CODE_A=$?
wait "$PID_b"; CODE_B=$?

for who in a b; do
  grep -E '^\[netprobe\]|^\[net\] (online|connection)|SCRIPT ERROR|Parse Error' "$WORK/client_$who.log" | sed "s/^/[$who] /"
done
grep -E '"ev":"(hello|close|drop)"' "$WORK/server.log" | sed 's/^/[server] /'
grep -E 'SCRIPT ERROR|Parse Error' "$WORK/server.log" | sed 's/^/[server] /'

# Contract §1: the server never builds the playfield (no main scene, no survivor).
if grep -qE '^\[boot\] main scene ready|^\[player\]' "$WORK/server.log"; then
  echo "[server] built the playfield:"; grep -E '^\[boot\] main scene ready|^\[player\]' "$WORK/server.log" | head -3
  echo "NET SMOKE FAIL"; exit 1
fi

if [[ $CODE_A -eq 0 && $CODE_B -eq 0 ]] && grep -q '^\[netprobe\] PASS' "$WORK/client_a.log" && grep -q '^\[netprobe\] PASS' "$WORK/client_b.log"; then
  echo "NET SMOKE PASS"; exit 0
fi
echo "NET SMOKE FAIL (client exits $CODE_A/$CODE_B)"; exit 1
