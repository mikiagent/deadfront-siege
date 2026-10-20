#!/usr/bin/env bash
# Read-only gate for the dsc t_ui moving-text task. It is the spec: t_ui must pass on the real code AND
# fail on each of six deliberate breakages of the code it guards (a test that passes everything proves
# nothing). Run from the worktree root: ./verify_ui.sh
set -u
ROOT="$(cd "$(dirname "$0")" && pwd)"
cd "$ROOT"
GS=/private/tmp/claude-501/-Users-milankinzy-Documents-deadfront-siege/1899b1df-f06b-4b94-91be-9e3f3c22081d/scratchpad/gslot.sh
GODOT=/Applications/Godot_mono.app/Contents/MacOS/Godot
T=game/tests/t_ui.gd
UTF=game/scripts/ui/ui_tokens.gd
LDF=game/scripts/ui/level_display.gd
DMF=game/scripts/core/display_mode.gd
LOGD="$ROOT/.dsc/verify"
mkdir -p "$LOGD"
fail() { echo "VERIFY FAIL: $*"; exit 1; }

[[ -f "$T" ]] || fail "$T missing"
for f in _test_free_spot _test_layout_avoid _test_current_title _test_desktop_short_window; do
  grep -q "^func $f() -> void:" "$T" || fail "missing case func $f() -> void"
  grep -qE "^[[:space:]]+$f\(\)$" "$T" || fail "$f is never called"
done
# The four cases are tables / literal expectations, not re-derivations of the code under test.
grep -q 'Rect2(10, *168, *50, *20)' "$T" || fail "free_spot table lacks the chain-down row's expected Rect2(10,168,50,20)"
grep -q 'Rect2(10, *76, *50, *20)' "$T" || fail "free_spot table lacks the nearer-upward row's expected Rect2(10,76,50,20)"
grep -q '"Wild Lands Veteran"' "$T" || fail "current_title table lacks level 19 -> Wild Lands Veteran"
grep -q 'pioneer_level' "$T" || fail "current_title must check a new survivor through World.pioneer_level"
if grep -nE '\b(UiTokens|LevelDisplay)\.' "$T" | grep -v '^[0-9]*:\s*#' | grep -vE '^[0-9]*:\s*##'; then
  echo "(note) t_ui names UiTokens/LevelDisplay above; the new cases must use UT./LD."
fi

# Only the test may change.
BASE=$(git merge-base HEAD claude/mmo-w1-ui)
changed=$( { git diff --name-only "$BASE" -- . ; git ls-files --others --exclude-standard; } | sort -u \
  | grep -v -E '^(game/tests/t_ui\.gd|DSC_NOTES\.md|TASK\.md|verify_ui\.sh|\.dsc\.json)$' \
  | grep -v -E '\.import$|\.uid$|_Image_[0-9]+\.(jpg|png)$|^\.dsc/' )
[[ -z "$changed" ]] || fail "files outside the task changed: $changed"

run_test() {  # $1 = log file; prints the exit code
  "$GS" perl -e 'alarm 240; exec @ARGV' "$GODOT" --headless --path game --script "res://tests/t_ui.gd" > "$1" 2>&1
  echo $?
}

code=$(run_test "$LOGD/clean.log")
grep -q '^\[t_ui\] PASS$' "$LOGD/clean.log" || { tail -30 "$LOGD/clean.log"; fail "clean run did not print [t_ui] PASS"; }
[[ "$code" == 0 ]] || fail "clean run exit $code"
if grep -E 'SCRIPT ERROR|Parse Error|Invalid call|Invalid access|Cannot call' "$LOGD/clean.log"; then
  fail "clean run logged script errors"
fi
for n in free_spot layout_avoid current_title desktop_short_window; do
  grep -qE "^\[t_ui\] ok $n( |$)" "$LOGD/clean.log" || fail "clean run lacks the '[t_ui] ok $n' line"
done
grep -q '^\[t_ui\] scanned 23 owned files' "$LOGD/clean.log" || fail "the existing cases no longer run (no 'scanned 23 owned files' line)"

# Mutations: each breaks one promise; t_ui must exit non-zero with a FAIL line.
BK="$LOGD/backup"
mkdir -p "$BK"
cp "$UTF" "$BK/ui_tokens.gd"; cp "$LDF" "$BK/level_display.gd"; cp "$DMF" "$BK/display_mode.gd"
restore() { cp "$BK/ui_tokens.gd" "$UTF"; cp "$BK/level_display.gd" "$LDF"; cp "$BK/display_mode.gd" "$DMF"; }
trap restore EXIT INT TERM
mutate() {  # $1 name, $2 file, $3 perl substitution, $4 what it breaks
  restore
  perl -0pi -e "$3" "$2"
  if cmp -s "$2" "$BK/$(basename "$2")"; then fail "mutation $1 did not apply (verify script bug)"; fi
  local c
  c=$(run_test "$LOGD/m_$1.log")
  if [[ "$c" == 0 ]] || ! grep -q '^\[t_ui\] FAIL' "$LOGD/m_$1.log"; then
    restore
    fail "mutation $1 survived: t_ui still passes when $4"
  fi
  echo "mutation $1 caught"
}
mutate spot_noop "$UTF" 's/(static func free_spot\(box: Rect2, taken: Array\[Rect2\], view: Vector2\) -> Rect2:\n)/$1\treturn box\n/' "free_spot leaves a toast on the quest card"
mutate spot_no_floor "$UTF" 's/if box\.end\.y > view\.y - 8\.0 or box\.position\.y < 8\.0:/if box.position.y < 8.0:/' "a toast slides off the bottom of the screen"
mutate avoid_ignored "$UTF" 's/var placed: Array\[Rect2\] = avoid\.duplicate\(\)/var placed: Array[Rect2] = []/' "camp labels ignore the HUD blocks"
mutate covered_kept "$UTF" 's/ or _covers\(avoid, anchor\)//' "a label whose object the HUD hides is still drawn"
mutate title_exact "$LDF" 's/int\(key\) <= level and/int(key) == level and/' "a level between two title keys shows no title"
mutate desktop_phone "$DMF" 's/if handheld and is_phone_landscape\(pts\):/if is_phone_landscape(pts):/' "a short desktop browser window gets the phone layout"
restore
echo "VERIFY PASS"
