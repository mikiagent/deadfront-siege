#!/usr/bin/env bash
# Read-only gate for the dsc hunt_hud split (TASK.md). It is the spec: the listed functions live in
# HudLayout / HudPills as static functions, hunt_hud.gd is at or under its base size (1376 lines),
# nothing was deleted or squeezed to get there, and the real HUD lays out exactly as before (control
# positions in a windowed lab run at 844x390 and 1600x900 equal a baseline taken before the move).
# Run from the worktree root: ./verify_w1ui_dsc2.sh
set -u
ROOT="$(cd "$(dirname "$0")" && pwd)"
cd "$ROOT"
SP=/private/tmp/claude-501/-Users-milankinzy-Documents-deadfront-siege/1899b1df-f06b-4b94-91be-9e3f3c22081d/scratchpad
GS=$SP/gslot.sh
GODOT=/Applications/Godot_mono.app/Contents/MacOS/Godot
TOK=$SP/w1ui-r11/dsc2/hud_tokens.py
BASELINE=$SP/w1ui-r11/dsc2/baseline
BASE=9783807c   # the branch point: stubs in place, nothing moved yet
HH=game/scripts/ui/hunt_hud.gd
HL=game/scripts/ui/hud_layout.gd
HP=game/scripts/ui/hud_pills.gd
GR=game/scripts/ui/gather_radial.gd
LOGD="$ROOT/.dsc/verify"
mkdir -p "$LOGD"
fail() { echo "VERIFY FAIL: $*"; exit 1; }

# ---- static: the shape of the split
n=$(wc -l < "$HH" | tr -d ' ')
(( n <= 1376 )) || fail "$HH has $n lines; it must be at or under its base size, 1376"
[[ "$(head -1 "$HL")" == "class_name HudLayout" ]] || fail "$HL must start with 'class_name HudLayout'"
[[ "$(head -1 "$HP")" == "class_name HudPills" ]] || fail "$HP must start with 'class_name HudPills'"
(( $(wc -l < "$HL") <= 260 )) || fail "$HL is over 260 lines: it should hold only the layout geometry"
(( $(wc -l < "$HP") <= 230 )) || fail "$HP is over 230 lines: it should hold only the pills"
grep -nE '^(var |@onready|@export|static var )' "$HL" "$HP" && fail "the helpers keep no state (no member var)"
grep -nE '^func ' "$HL" "$HP" && fail "every function in the helpers is a static func"
for f in landscape_phone vitals_rect centre_band place_landscape_phone place_portrait place_desktop fit_sheet taken_rects figure_rect nameplate_rect draw_levelup_banner; do
  grep -qE "^static func $f\(" "$HL" || fail "HudLayout lacks static func $f("
done
for f in gather_radial_node tools_for_node draw; do
  grep -qE "^static func $f\(" "$HP" || fail "HudPills lacks static func $f("
done
grep -q '^const TOOL_ICON_ITEM' "$HP" || fail "HudPills lacks const TOOL_ICON_ITEM"
for gone in 'func _layout_landscape_phone' 'func _layout_portrait' 'func _landscape_phone' 'func _vitals_rect' 'func _centre_band' 'func _fit_sheet' 'func nameplate_rect' 'func _draw_levelup_banner' 'func _draw_pills' 'func _tools_for_node' 'func _gather_radial_node' 'TOOL_ICON_ITEM :='; do
  grep -q "$gone" "$HH" && fail "hunt_hud.gd still defines '$gone' (move it)"
done
if grep -rnE '(^|[^A-Za-z0-9_.])(_landscape_phone|_vitals_rect|_centre_band|_fit_sheet|_layout_landscape_phone|_layout_portrait|_draw_levelup_banner|_draw_pills|_tools_for_node|_gather_radial_node)\(' game/scripts game/tests; then
  fail "old private names are still called (above)"
fi
grep -rn 'HuntHud\.nameplate_rect' game/scripts game/tests && fail "HuntHud.nameplate_rect is gone: call HudLayout.nameplate_rect"
grep -q 'HudLayout\.nameplate_rect(' "$GR" || fail "gather_radial.gd must call HudLayout.nameplate_rect("
grep -q 'HudPills\.draw(self, ' "$HH" || fail "hunt_hud.gd must draw the pills with HudPills.draw(self, ...)"
for f in place_landscape_phone place_portrait place_desktop fit_sheet; do
  grep -q "HudLayout\.$f(self, " "$HH" || fail "hunt_hud.gd _layout() must call HudLayout.$f(self, ...)"
done
python3 -I - "$HH" <<'PY' || fail "taken_rects / figure_rect must stay on HuntHud as one-line delegations"
import sys
lines = open(sys.argv[1]).read().split("\n")
want = {
  "func taken_rects(skip: PackedStringArray = []) -> Array[Rect2]:": "\treturn HudLayout.taken_rects(self, skip)",
  "func figure_rect() -> Rect2:": "\treturn HudLayout.figure_rect(self)",
}
for sig, body in want.items():
  if sig not in lines:
    print("missing: " + sig); sys.exit(1)
  i = lines.index(sig)
  if lines[i + 1] != body:
    print("%s must be followed by %r, got %r" % (sig, body, lines[i + 1])); sys.exit(1)
  nxt = lines[i + 2] if i + 2 < len(lines) else ""
  if nxt.startswith("\t") and nxt.strip() != "":
    print("%s has more than one line of body" % sig); sys.exit(1)
PY
# The resize fix in _layout() stays.
grep -q $'^\t_ctx_ids = \\[\\]$' "$HH" && grep -q $'^\t_ctx_timer = 0.0$' "$HH" || fail "_layout() must keep '_ctx_ids = []' and '_ctx_timer = 0.0'"
# No new classes, no other files.
cls=$(grep -rhE '^class_name ' game/scripts | sort | uniq -c | awk '$1 > 1')
[[ -z "$cls" ]] || fail "duplicate class_name: $cls"
new_cls=$(git diff "$BASE" -- game | grep -E '^\+class_name ' || true)
[[ -z "$new_cls" ]] || fail "no new class_name lines allowed: $new_cls"
changed=$( { git diff --name-only "$BASE" -- . ; git ls-files --others --exclude-standard; } | sort -u \
  | grep -v -E '^(game/scripts/ui/(hunt_hud|hud_layout|hud_pills|gather_radial)\.gd|DSC_NOTES\.md|TASK\.md|verify_w1ui_dsc2\.sh|\.dsc\.json)$' \
  | grep -v -E '\.import$|\.uid$|_Image_[0-9]+\.(jpg|png)$|^\.dsc/|^game/assets/nature/generated/' )
[[ -z "$changed" ]] || fail "files outside the task changed: $changed"
# Nothing deleted or squeezed: code and comment lines across the three files hold, no new ';' joins,
# no longer lines than before.
python3 -I - "$BASE" "$HH" "$HL" "$HP" <<'PY' || fail "the move lost or squeezed code (see above)"
import subprocess, sys
base, files = sys.argv[1], sys.argv[2:]
def stats(texts):
  code = comm = semi = 0
  longest = 0
  for t in texts:
    for l in t.split("\n"):
      s = l.strip()
      longest = max(longest, len(l.expandtabs(4)))
      if not s:
        continue
      if s.startswith("#"):
        comm += 1
      else:
        code += 1
        if ";" in s.split("#")[0] and s.count('"') == 0:
          semi += 1
  return code, comm, semi, longest
old = stats([subprocess.run(["git", "show", "%s:%s" % (base, f)], capture_output=True, text=True).stdout for f in files])
new = stats([open(f).read() for f in files])
print("code/comment/semicolon/longest before %s after %s" % (old, new))
ok = True
if new[0] < old[0] - 6: print("code lines fell from %d to %d" % (old[0], new[0])); ok = False
if new[1] < old[1] - 6: print("comment lines fell from %d to %d" % (old[1], new[1])); ok = False
if new[2] > old[2]: print("lines joined with ';' rose from %d to %d" % (old[2], new[2])); ok = False
if new[3] > old[3] + 12: print("longest line grew from %d to %d" % (old[3], new[3])); ok = False
sys.exit(0 if ok else 1)
PY

# ---- dynamic: t_ui, boot, and the real HUD at two sizes
"$GS" perl -e 'alarm 300; exec @ARGV' "$GODOT" --headless --path game --script res://tests/t_ui.gd > "$LOGD/t_ui.log" 2>&1
code=$?
grep -q '^\[t_ui\] PASS$' "$LOGD/t_ui.log" && [[ $code == 0 ]] || { tail -30 "$LOGD/t_ui.log"; fail "t_ui did not pass (exit $code)"; }
grep -nE 'SCRIPT ERROR|Parse Error' "$LOGD/t_ui.log" && fail "t_ui logged script errors"
"$GS" perl -e 'alarm 600; exec @ARGV' tools/smoke.sh --no-import > "$LOGD/smoke.log" 2>&1
grep -q '^SMOKE PASS$' "$LOGD/smoke.log" || { tail -20 "$LOGD/smoke.log"; fail "smoke did not pass"; }
for res in 844x390 1600x900; do
  log="$LOGD/lab_${res}.log"
  rm -rf "$LOGD/shots_$res"
  "$GS" perl -e 'alarm 1200; exec @ARGV' "$GODOT" --path game --resolution "$res" --rendering-method gl_compatibility -- --lab=ui_real_capture_lab --shot-dir="$LOGD/shots_$res" > "$log" 2>&1
  code=$?
  grep -q '^\[uireal\] PASS ' "$log" && [[ $code == 0 ]] || { grep -E '^\[uireal\] FAIL' "$log" | head -20; tail -5 "$log"; fail "ui_real_capture_lab $res did not pass (exit $code)"; }
  if grep -qE 'SCRIPT ERROR|Parse Error' "$log"; then grep -nE 'SCRIPT ERROR|Parse Error' "$log" | head -5; fail "lab $res logged script errors"; fi
  python3 -I "$TOK" "$log" > "$LOGD/tok_$res.txt"
  if ! diff "$BASELINE/${res}_glc.tok" "$LOGD/tok_$res.txt" > "$LOGD/tok_$res.diff"; then
    head -30 "$LOGD/tok_$res.diff"
    fail "the HUD lays out differently at $res than before the move (< before, > after)"
  fi
  echo "lab $res: PASS, $(wc -l < "$LOGD/tok_$res.txt" | tr -d ' ') HUD positions equal the baseline"
done
echo "VERIFY PASS"
