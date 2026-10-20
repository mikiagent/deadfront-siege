#!/usr/bin/env bash
# Read-only gate for the dsc t_buildsys task. It is the spec: the test must pass on the real code AND
# fail on each of twelve deliberate breakages of the building system (a test that passes everything
# proves nothing). Run from the worktree root: ./verify_buildsys.sh
set -u
ROOT="$(cd "$(dirname "$0")" && pwd)"
cd "$ROOT"
GS=/private/tmp/claude-501/-Users-milankinzy-Documents-deadfront-siege/1899b1df-f06b-4b94-91be-9e3f3c22081d/scratchpad/gslot.sh
GODOT=/Applications/Godot_mono.app/Contents/MacOS/Godot
T=game/tests/t_buildsys.gd
W=game/scripts/world
LOGD="$ROOT/.dsc/verify"
mkdir -p "$LOGD"
fail() { echo "VERIFY FAIL: $*"; exit 1; }

[[ -f "$T" ]] || fail "$T missing"
head -1 "$T" | grep -q '^extends SceneTree' || fail "$T must start with 'extends SceneTree'"
grep -q '^## ' "$T" || fail "$T needs a ## header comment saying what it checks and how to run it"
# Game classes are load()ed inside functions, never named at parse time (run_all/--script rule).
if grep -nE '\b(StructurePiece|StructureGrid|StructureHealth|StructureMesh|StructurePlacer|BuildPlacer|BuildGrid|TilePath|SaveMigrations|SaveGame|CreatureAttack|LabKit|ItemStack|Spawner|FieldCatapult)\.' "$T"; then
  fail "$T names a game class directly; load() the script inside a function instead"
fi
if grep -nE ':\s*(StructurePiece|StructureGrid|StructureHealth|BuildGrid|TilePath|Player|Creature)\b|as (StructurePiece|StructureGrid|StructureHealth|BuildGrid|TilePath|Player|Creature)\b' "$T"; then
  fail "$T uses a game class as a static type; use Node / Object / Variant and load()ed scripts"
fi
CASES="_test_data_rows _test_costs _test_reasons _test_snap _test_collapse _test_damage_tiers _test_kits_and_camp _test_repair_upgrade _test_paths _test_rows_round_trip _test_bad_rows _test_migrations"
for f in $CASES; do
  grep -q "^func $f(" "$T" || fail "missing case func $f"
done
lines=$(wc -l < "$T")
[[ "$lines" -le 700 ]] || fail "$T is $lines lines; keep it under 700"

# Only the test may change; the building system is owned by the reviewer.
BASE=a55432e
changed=$( { git diff --name-only "$BASE" -- . ; git ls-files --others --exclude-standard; } | sort -u \
  | grep -v -E '^(game/tests/t_buildsys\.gd(\.uid)?|DSC_NOTES\.md|TASK\.md|verify_buildsys\.sh)$' \
  | grep -v -E '\.import$|_Image_[0-9]+\.(jpg|png)$' )
[[ -z "$changed" ]] || fail "files outside the task changed: $changed"

run_test() {  # $1 = log file; prints the exit code
  "$GS" perl -e 'alarm 300; exec @ARGV' "$GODOT" --headless --path game --script "res://tests/t_buildsys.gd" > "$1" 2>&1
  echo $?
}

code=$(run_test "$LOGD/clean.log")
grep -q '^\[t_buildsys\] PASS$' "$LOGD/clean.log" || { grep -E '^\[t_buildsys\]|SCRIPT ERROR' "$LOGD/clean.log" | tail -40; fail "clean run did not print [t_buildsys] PASS"; }
[[ "$code" == 0 ]] || fail "clean run exit $code"
if grep -E 'SCRIPT ERROR|Parse Error|Invalid call|Invalid access|Cannot call' "$LOGD/clean.log"; then
  fail "clean run logged script errors"
fi
for f in $CASES; do
  c=${f#_test_}
  grep -q "^\[t_buildsys\] ok $c\b" "$LOGD/clean.log" || fail "no '[t_buildsys] ok $c' line (each case prints one when it passes)"
done
rows=$(grep -E '^\[t_buildsys\] ok reasons cases=[0-9]+' "$LOGD/clean.log" | grep -oE 'cases=[0-9]+' | cut -d= -f2)
[[ -n "$rows" && "$rows" -ge 12 ]] || fail "_test_reasons must print 'ok reasons cases=N' with N >= 12 table rows (saw '${rows:-none}')"
bad=$(grep -E '^\[t_buildsys\] ok bad_rows cases=[0-9]+' "$LOGD/clean.log" | grep -oE 'cases=[0-9]+' | cut -d= -f2)
[[ -n "$bad" && "$bad" -ge 8 ]] || fail "_test_bad_rows must print 'ok bad_rows cases=N' with N >= 8 malformed rows (saw '${bad:-none}')"

# Mutations: each breaks one promise; the test must exit non-zero with a FAIL line.
FILES="structure_piece.gd structure_grid.gd structure_health.gd structure_placer.gd tile_path.gd"
BK="$LOGD/backup"
mkdir -p "$BK"
for f in $FILES; do cp "$W/$f" "$BK/$f"; done
cp game/scripts/core/save_migrations.gd "$BK/save_migrations.gd"
restore() { for f in $FILES; do cp "$BK/$f" "$W/$f"; done; cp "$BK/save_migrations.gd" game/scripts/core/save_migrations.gd; }
trap restore EXIT INT TERM
mutate() {  # $1 name, $2 file, $3 perl substitution, $4 what breaks
  restore
  perl -0pi -e "$3" "$2"
  if cmp -s "$2" "$BK/$(basename "$2")"; then fail "mutation $1 did not apply (verify script bug)"; fi
  local c
  c=$(run_test "$LOGD/m_$1.log")
  if [[ "$c" == 0 ]] || ! grep -q '^\[t_buildsys\] FAIL' "$LOGD/m_$1.log"; then
    restore
    fail "mutation $1 survived: the test still passes when $4"
  fi
  echo "mutation $1 caught"
}
mutate cost_half "$W/structure_piece.gd" 's/maxi\(0, int\(s\.get\("quantity", 0\)\)\)/maxi(0, int(s.get("quantity", 0)) \/ 2)/' "pieces cost half their blueprint"
mutate no_collapse "$W/structure_grid.gd" 's/(func collapse_unsupported\(\) -> Array\[StructurePiece\]:\n)/$1\tvar none: Array[StructurePiece] = []\n\treturn none\n/' "nothing ever collapses"
mutate tier_mult_ignored "$W/structure_health.gd" 's/amount \* damage_mult \*/amount */' "every tier takes the same creature damage"
mutate owner_path_ignored "$W/tile_path.gd" 's/\tif not for_owner:\n\t\treturn _path/\tif true:\n\t\treturn _path/' "the owner is blocked by its own walls"
mutate walls_dont_block "$W/structure_grid.gd" 's/(func enemy_cells\(p: StructurePiece\) -> Array\[Vector2i\]:\n\tvar out: Array\[Vector2i\] = \[\]\n)\tif p\.slot\.z != 0:/$1\tif true:/' "walls do not block creature paths"
mutate resource_ok "$W/structure_grid.gd" 's/\t\tif build_grid\.harvest_at\(c\):\n\t\t\treturn "resource"/\t\tif false:\n\t\t\treturn "resource"/' "foundations go on top of trees and rocks"
mutate code_unchecked "$W/structure_piece.gd" 's/if code < CELL or code > ON_FLOOR:/if false:/' "a saved row with a bad slot code loads"
mutate schema_stuck "game/scripts/core/save_migrations.gd" 's/const CURRENT_SCHEMA := 4/const CURRENT_SCHEMA := 3/' "saves never reach schema 4"
mutate repair_free "$W/structure_placer.gd" 's/\tif not pay\(player\.get\("inventory"\), cost\):\n\t\treturn "missing_materials"\n\th\.heal_full\(\)/\th.heal_full()/' "repair takes no materials"
mutate downgrade_ok "$W/structure_placer.gd" 's/if StructurePiece\.tier_rank\(tier\) <= StructurePiece\.tier_rank\(p\.tier\):/if false:/' "an upgrade to a lower tier is accepted"
mutate camp_damageable "$W/structure_health.gd" 's/return node\.get\("persist_building"\) != false and node\.get\("is_cargo"\) != true/return true/' "camp pieces and cargo can be worn down"
mutate snap_any_distance "$W/structure_placer.gd" 's/if ok and d <= radius and/if ok and/' "the ghost snaps to sockets any distance away"
restore
trap - EXIT INT TERM
for f in $FILES; do git diff --quiet "$BASE" -- "$W/$f" || fail "$f differs from base after restore"; done
git diff --quiet "$BASE" -- game/scripts/core/save_migrations.gd || fail "save_migrations.gd differs from base after restore"
echo "VERIFY PASS (reason rows=$rows, bad rows=$bad, 12/12 mutations caught)"
