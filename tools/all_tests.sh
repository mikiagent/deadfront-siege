#!/usr/bin/env bash
# Run every game/tests/t_*.gd headless; print one PASS/FAIL line per test and a total. Exit 0 only when all pass.
# A test passes when it exits 0 and prints a "PASS" line (the tag can differ from the filename).
# Env: GODOT_PATH (else find_godot.sh), WRAP (command prefix, e.g. a Godot slot wrapper), JOBS (parallel, default 4),
#      TEST_TIMEOUT (seconds per test, default 600), LOGS (log dir, default a temp dir).
# Args: optional test names (t_items t_econ ...) to run a subset.
# Everything runs headless. The one windowed check, t_waves_render, is not standalone: t_waves starts it in
# a small window per renderer at --position 6000,3000 (off the visible displays; the owner plays on this Mac).
set -uo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
G="${GODOT_PATH:-$("$ROOT/tools/find_godot.sh")}" || exit 127
LOGS="${LOGS:-$(mktemp -d)}"; mkdir -p "$LOGS"
JOBS="${JOBS:-4}"; TEST_TIMEOUT="${TEST_TIMEOUT:-600}"
export G ROOT LOGS TEST_TIMEOUT WRAP="${WRAP:-}"

if [[ $# -gt 0 ]]; then names=("$@"); else
  names=(); for f in "$ROOT"/game/tests/t_*.gd; do
    n="$(basename "$f" .gd)"; [[ "$n" == t_waves_render ]] || names+=("$n")
  done
fi

run_one() {
  local t="$1" log="$LOGS/$1.log" start=$SECONDS rc
  # shellcheck disable=SC2086
  $WRAP perl -e "alarm $TEST_TIMEOUT; exec @ARGV" "$G" --headless --path "$ROOT/game" --script "res://tests/$t.gd" >"$log" 2>&1
  rc=$?
  if [[ $rc -eq 0 ]] && grep -q 'PASS' "$log"; then echo "PASS $t ($((SECONDS - start))s)"
  else echo "FAIL $t rc=$rc ($((SECONDS - start))s) $(grep -m1 -E 'FAIL|ERROR|SCRIPT ERROR' "$log" | cut -c1-160)"; fi
}
export -f run_one

$WRAP "$G" --headless --path "$ROOT/game" --import >"$LOGS/_import.log" 2>&1
printf '%s\n' "${names[@]}" | xargs -P "$JOBS" -I{} bash -c 'run_one {}' | tee "$LOGS/_summary.txt"
pass=$(grep -c '^PASS' "$LOGS/_summary.txt"); fail=$(grep -c '^FAIL' "$LOGS/_summary.txt")
echo "TOTAL ${#names[@]} pass=$pass fail=$fail logs=$LOGS"
[[ $fail -eq 0 ]]
