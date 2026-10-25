# dsc — TEST-RELIABILITY report

Task: stop the two false-green Godot test entry points. Worktree cut from `claude/mmo-overhaul`.
Strict gate: `bash docs/orchestration/dsc/gates/verify_test_reliability.sh` (exit 0 required).

## Baseline (before the fix)

A fresh worktree has no `game/.godot/class cache`, so the very first engine run of either test dies
with a wall of `Could not find type "ItemDef"/"StatusDef"/...` parse errors before the autoloads exist
(`t_bags` reported `Data autoload never appeared`). One headless import fixed that, after which the
task's stated baseline reproduced exactly:

`t_bags` — exit 0, printed `[t_bags] PASS`, and:

```
SCRIPT ERROR: Invalid access of index '0' on a base object of type: 'Array[int]'.
          at: GDScript::reload ... (tests/t_bags.gd:276)
[t_bags] PASS
```

Cause: `_test_preview_matches_result` built its fixture with `raw_hide` / `fibre_stalk` / `twine` and
then did `inv.find_by_category(want)[0]` for every recipe slot. `basic_bag` needs `dried_hide`, `fibre`
and `lashing`; the `dried_hide` candidate list was empty, so `[0]` errored (the error line itself is
non-fatal in GDScript, which is why the runner still printed PASS).

`run_all` — exit 0, printed `[tests] PASS`, and:

```
SCRIPT ERROR: Compile Error: Identifier not found: World
          at: GDScript::reload (res://scripts/skills/skill_state.gd:44)
SCRIPT ERROR: Compile Error: Identifier not found: World
          at: GDScript::reload (res://scripts/ui/level_display.gd:12)
SCRIPT ERROR: Compile Error: Failed to compile depended scripts.   (hud_event_state.gd, run_all.gd)
ERROR: Failed to load script "res://tests/run_all.gd" with error "Compilation failed".
SCRIPT ERROR: Invalid call. Nonexistent function 'new' in base 'GDScript'.
          at: run (res://tests/process_checks.gd:107)   (SK.new(), the SkillState script never compiled)
[tests] PASS
```

Causal chain: `run_all.gd` called tests from `_init()`, which runs while `--script` is still
instantiating the entry point — before the engine creates autoloads and before script classes can be
compiled through an autoload identifier. `skill_state.gd` and `level_display.gd` referenced `World`
(and `Data`) as bare globals, so their compile failed in that phase; every dependent script failed with
"Failed to compile depended scripts", including `process_checks.gd`'s `load(... skill_state.gd)`.
`process_checks` then called `.new()` on the null/unusable GDScript and the run continued to a PASS:
the assertion (`collect pays ... Processing XP ... once`) was never executed.

`run_all` also reached for `HudEventState` statically, which pulled the same broken dependency chain
(SkillState → LevelDisplay) in during the pre-autoload compile.

## What changed

Files touched (all inside scope):

- `game/tests/t_bags.gd` — new `_picks_for(inv, rec)` helper picks the first instance of each recipe
  category and **fails the test** (`"recipe category '<cat>' has a pickable instance"`) when a
  category has no instance, then appends `-1` instead of indexing. Both test 11 and test 12 now use it;
  test 12's fixture uses `dried_hide` x2 (as `basic_bag`'s primary `dried_hide` slot needs), `fibre_stalk`
  x3 and `twine`, and asserts every slot was picked and `picks_valid` before previewing.
- `game/tests/run_all.gd` — `_init()` now does nothing but return; every test moved into the existing
  first-frame `_process` gate that waits for the `Data` autoload (same pattern as `t_domain.gd`). No
  assertion removed. `_test_hud_event_state` loads `hud_event_state.gd` dynamically (the file already
  documented "Dynamic load avoids compiling Crafting before autoload Data exists" for its other labs).
- `game/scripts/skills/skill_state.gd` — added `static func world()` / `static func data()` that resolve
  the autoloads through `Engine.get_main_loop().root.get_node_or_null(...)`; `_ready()`, `add_xp()`,
  `character_level()`, `character_progress()` and `_mirror_survival()` now use them. Behaviour is
  identical in gameplay (the nodes are the same autoloads); no constants, no error swallowing, no
  behaviour deleted.
- `game/scripts/ui/level_display.gd` — same `world()` / `data()` runtime lookup; `player_level()` reads
  `World.pioneer_level` from the resolved node and `nice_name()` reads `Data.item(...)` from the
  resolved node. Falls back to stored level 0 ("Lv. 1") / the raw id when the autoload is absent
  (pure data checks), which is what the previous `World`-must-exist code effectively required.

## Verification

All engine runs were headless through the mandated `gslot.sh` wrapper, output redirected to
`/tmp/test_reliability_*.log`.

- `--import` once (headless) to build `game/.godot` in the fresh worktree (not a source change; the
  directory is git-ignored).
- `--check-only --script res://tests/t_bags.gd` / `res://tests/t_bags.gd`-style parse checks for the
  edited files: only the pre-existing autoload-identifier errors show under `--check-only` (that mode
  never registers autoloads); no syntax errors.
- `t_bags.gd`: exit 0, `[t_bags] PASS`, **zero** `SCRIPT ERROR` lines
  (`/tmp/test_reliability_t_bags.log`).
- Negative control: replacing the three `fibre_stalk` fixture items with `stone` made the test exit 1
  with `11: the picked material instances satisfy the recipe` and `11: the recipe makes a basic bag`;
  the file was restored afterwards. The test can fail.
- `run_all.gd`: exit 0, `[tests] PASS`, **zero** `SCRIPT ERROR` lines
  (`/tmp/test_reliability_run_all.log`). The process-check chain now prints the rack load/finish/collect
  lines including the XP check's own rack (`loaded 2 x dry_meat` twice + empty collect), i.e. the
  `collect pays Processing XP per dried meat, once` assertion actually ran and passed.
- Strict gate: see the run recorded below.

## Remaining limitations

- `t_save` is out of scope as instructed and remains the one documented exception to the
  `SCRIPT ERROR` cleanliness rule; it is not part of `verify_test_reliability.sh`.
- `--script` entry points that statically reference autoload-dependent classes before the first frame
  will still report compile errors. The fix here only covers the two entry points in scope; other
  `tests/t_*.gd` files were not audited.
- A fresh worktree needs one `Godot --headless --path game --import` before `--script` tests can run
  at all (pre-existing repository condition, unchanged).
