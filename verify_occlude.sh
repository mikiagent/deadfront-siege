#!/usr/bin/env bash
# Read-only gate for the dsc t_occlude task. It is the spec: the test must pass on the real code AND
# fail on each of eight deliberate breakages of the occlusion system (a test that passes everything
# proves nothing). Run from the worktree root: ./verify_occlude.sh
set -u
ROOT="$(cd "$(dirname "$0")" && pwd)"
cd "$ROOT"
GS=/private/tmp/claude-501/-Users-milankinzy-Documents-deadfront-siege/1899b1df-f06b-4b94-91be-9e3f3c22081d/scratchpad/gslot.sh
GODOT=/Applications/Godot_mono.app/Contents/MacOS/Godot
T=game/tests/t_occlude.gd
OCC=game/scripts/world/occlusion.gd
MAT=game/scripts/world/occlusion_material.gd
LOGD="$ROOT/.dsc/verify"
mkdir -p "$LOGD"
fail() { echo "VERIFY FAIL: $*"; exit 1; }

[[ -f "$T" ]] || fail "$T missing"
head -1 "$T" | grep -q '^extends SceneTree' || fail "$T must start with 'extends SceneTree'"
grep -q '^## ' "$T" || fail "$T needs a ## header comment saying what it checks and how to run it"
# Game classes are load()ed inside functions, never named at parse time (run_all/--script rule).
if grep -nE '\b(Occlusion|OcclusionMaterial|VegBatch|IslandScatter)\.' "$T"; then
  fail "$T names a game class directly; load() the script inside a function instead"
fi
for f in _test_between_mesh _test_override_paths _test_release_restores _test_mode_switch _test_disabled \
         _test_non_base_material _test_multimesh_single _test_multimesh_multi_surface _test_late_child \
         _test_inside_fade _test_parity _test_shared_cache_and_leak _test_nature_sweep; do
  grep -q "^func $f(" "$T" || fail "missing case func $f"
done
grep -q 'nature_families' "$T" || fail "_test_nature_sweep must walk Data.nature_families"

# Only the test may change; the occlusion system, run_all and the shaders are owned by the reviewer.
BASE=$(git merge-base HEAD claude/mmo-w2-occlude)
changed=$( { git diff --name-only "$BASE" -- . ; git ls-files --others --exclude-standard; } | sort -u \
  | grep -v -E '^(game/tests/t_occlude\.gd(\.uid)?|DSC_NOTES\.md|TASK\.md|verify_occlude\.sh)$' \
  | grep -v -E '\.import$|_Image_[0-9]+\.(jpg|png)$' )
[[ -z "$changed" ]] || fail "files outside the task changed: $changed"

run_test() {  # $1 = log file; prints the exit code
  "$GS" perl -e 'alarm 240; exec @ARGV' "$GODOT" --headless --path game --script "res://tests/t_occlude.gd" > "$1" 2>&1
  echo $?
}

code=$(run_test "$LOGD/clean.log")
grep -q '^\[t_occlude\] PASS$' "$LOGD/clean.log" || { tail -30 "$LOGD/clean.log"; fail "clean run did not print [t_occlude] PASS"; }
[[ "$code" == 0 ]] || fail "clean run exit $code"
if grep -E 'SCRIPT ERROR|Parse Error|Invalid call|Invalid access|Cannot call' "$LOGD/clean.log"; then
  fail "clean run logged script errors"
fi
cases=$(grep -c '^\[t_occlude\] ok ' "$LOGD/clean.log")
[[ "$cases" -ge 13 ]] || fail "expected one '[t_occlude] ok <case>' line per case (13+), saw $cases"
sweep=$(grep -E '^\[t_occlude\] ok nature_sweep models=[0-9]+' "$LOGD/clean.log" | grep -oE 'models=[0-9]+' | cut -d= -f2)
[[ -n "$sweep" && "$sweep" -ge 20 ]] || fail "nature sweep must report models=N with N >= 20 tree/rock models (saw '${sweep:-none}')"

# Mutations: each one breaks one promise of the API; the test must exit non-zero with a FAIL line.
BK="$LOGD/backup"
mkdir -p "$BK"
cp "$OCC" "$BK/occlusion.gd"; cp "$MAT" "$BK/occlusion_material.gd"
restore() { cp "$BK/occlusion.gd" "$OCC"; cp "$BK/occlusion_material.gd" "$MAT"; }
trap restore EXIT INT TERM
mutate() {  # $1 name, $2 file, $3 perl substitution
  restore
  perl -0pi -e "$3" "$2"
  if cmp -s "$2" "$BK/$(basename "$2")"; then fail "mutation $1 did not apply (verify script bug)"; fi
  local c
  c=$(run_test "$LOGD/m_$1.log")
  if [[ "$c" == 0 ]] || ! grep -q '^\[t_occlude\] FAIL' "$LOGD/m_$1.log"; then
    restore
    fail "mutation $1 survived: the test still passes when $4"
  fi
  echo "mutation $1 caught"
}
mutate restore_noop "$OCC" 's/(static func _restore\(gi: GeometryInstance3D\) -> void:\n)/$1\treturn\n/' "release() leaves the faded materials on"
mutate under_never "$OCC" 's/(static func _under\(geoms: Array, p: Vector3\) -> bool:\n)/$1\treturn false\n/' "a roof never notices the survivor under it"
mutate no_albedo "$MAT" 's/\tm\.set_shader_parameter\("albedo", b\.albedo_color\)\n//' "the derived material drops the albedo colour"
mutate ignores_enabled "$OCC" 's/if not enabled or node == null/if node == null/' "--no-occlusion is ignored"
mutate adopt_noop "$OCC" 's/(func _adopt\(child: Node, owner_node: Node\) -> void:\n)/$1\treturn\n/' "meshes added later stay solid"
mutate twin_null "$OCC" 's/(static func _twin\(mesh: Mesh, mode: String\) -> Mesh:\n)/$1\treturn null\n/' "multi-surface MultiMeshes stay solid"
mutate cull_wrong "$MAT" 's/const CULL := \["cull_back", "cull_front", "cull_disabled"\]/const CULL := ["cull_back", "cull_back", "cull_back"]/' "double-sided leaves become back-face culled"
mutate fade_not_written "$OCC" 's/\t\t\t\t\(gi as GeometryInstance3D\)\.set_instance_shader_parameter\(&"occl_fade", f\)\n/\t\t\t\tpass\n/' "the roof fade never reaches the mesh"
restore
trap - EXIT INT TERM
git diff --quiet "$BASE" -- "$OCC" "$MAT" || fail "occlusion sources differ from base after restore"
echo "VERIFY PASS (cases=$cases, nature models=$sweep, 8/8 mutations caught)"
