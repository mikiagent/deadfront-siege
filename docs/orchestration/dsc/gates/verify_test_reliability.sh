#!/usr/bin/env bash
# Strict, headless-only gate for the two existing false-green test runners.
set -euo pipefail

root=$(git rev-parse --show-toplevel)
cd "$root"
gslot=/private/tmp/claude-501/-Users-milankinzy-Documents-deadfront-siege/1899b1df-f06b-4b94-91be-9e3f3c22081d/scratchpad/gslot.sh
godot=/Applications/Godot_mono.app/Contents/MacOS/Godot
out=/tmp/deadfront-test-reliability-verify
mkdir -p "$out"

fail() {
  echo "VERIFY FAIL: $*"
  exit 1
}

run_test() {
  local name=$1
  local marker=$2
  local log="$out/$name.log"
  "$gslot" perl -e 'alarm 300; exec @ARGV' "$godot" --headless --path game --script "res://tests/$name.gd" >"$log" 2>&1 || fail "$name exited non-zero (see $log)"
  grep -Fq "$marker" "$log" || fail "$name printed no PASS marker (see $log)"
  ! grep -q '^SCRIPT ERROR:' "$log" || fail "$name printed SCRIPT ERROR (see $log)"
}

run_test t_bags '[t_bags] PASS'
run_test run_all '[tests] PASS'

smoke_log="$out/smoke.log"
"$gslot" perl -e 'alarm 300; exec @ARGV' bash tools/smoke.sh --no-import >"$smoke_log" 2>&1 || fail "smoke exited non-zero (see $smoke_log)"
grep -Fq 'SMOKE PASS' "$smoke_log" || fail "smoke printed no PASS marker (see $smoke_log)"
! grep -q '^SCRIPT ERROR:' "$smoke_log" || fail "smoke printed SCRIPT ERROR (see $smoke_log)"

[ -s docs/orchestration/reports/dsc-test-reliability.md ] || fail 'report is missing'
base=$(git merge-base HEAD claude/mmo-overhaul)
scope='^(game/tests/(t_bags|run_all|process_checks)\.gd|game/scripts/(skills/skill_state|ui/level_display)\.gd|docs/orchestration/reports/dsc-test-reliability\.md)$'
bad=$( { git diff --name-only "$base"; git ls-files --others --exclude-standard; } | sort -u | grep -vE '\.(uid|import)$|_Image_[0-9]+\.jpg$' | grep -vE "$scope" || true)
[ -z "$bad" ] || fail "files outside scope changed: $(echo "$bad" | head -c 400)"
echo 'VERIFY PASS'
