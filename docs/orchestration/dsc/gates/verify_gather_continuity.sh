#!/usr/bin/env bash
# Strict headless gate for the multi-resource gather radial continuation.
set -euo pipefail

root=$(git rev-parse --show-toplevel)
cd "$root"
gslot=/private/tmp/claude-501/-Users-milankinzy-Documents-deadfront-siege/1899b1df-f06b-4b94-91be-9e3f3c22081d/scratchpad/gslot.sh
godot=/Applications/Godot_mono.app/Contents/MacOS/Godot
out=/tmp/deadfront-gather-continuity-verify
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

run_test t_player '[t_player] PASS'
run_test t_gatherglide '[t_gatherglide] PASS'

smoke_log="$out/smoke.log"
"$gslot" perl -e 'alarm 300; exec @ARGV' bash tools/smoke.sh --no-import >"$smoke_log" 2>&1 || fail "smoke exited non-zero (see $smoke_log)"
grep -Fq 'SMOKE PASS' "$smoke_log" || fail "smoke printed no PASS marker (see $smoke_log)"
! grep -q '^SCRIPT ERROR:' "$smoke_log" || fail "smoke printed SCRIPT ERROR (see $smoke_log)"

[ -s docs/orchestration/reports/dsc-gather-continuity.md ] || fail 'report is missing'
base=$(git merge-base HEAD claude/mmo-overhaul)
scope='^(game/scripts/(player/(player_actions|player_input)|ui/gather_radial|world/harvest_node)\.gd|game/tests/t_player\.gd|docs/orchestration/dsc/(gather-continuity-TASK|gates/verify_gather_continuity)\.sh?|docs/orchestration/reports/dsc-gather-continuity\.md)$'
bad=$( { git diff --name-only "$base"; git ls-files --others --exclude-standard; } | sort -u | grep -vE '\.(uid|import)$|_Image_[0-9]+\.jpg$' | grep -vE "$scope" || true)
[ -z "$bad" ] || fail "files outside scope changed: $(echo "$bad" | head -c 400)"
echo 'VERIFY PASS'
