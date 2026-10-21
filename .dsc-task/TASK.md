# Task: BAGS: bag types, bag levels, material-inherited storage, Pocket, inspect/compare/craft preview (owner's spec 31)

The owner's spec: docs/design/durango-prompts/31_bag_levels_quality_and_capacity.md - READ IT ALL FIRST and implement it.
Also docs/design/durango-prompts/05 (capacity line 11) and 04 (material processing/crafting inheritance).
DEADFRONT is a Godot 4.7.1 typed-GDScript survival game (project `game/`), web build, mobile-first (844x390 landscape).
## What this tree holds
- claude/mmo-overhaul plus the INVSLOTS job's branch (the bag is a scrolling slot grid, one item per slot; capacity 100;
  a data-only `woven_bag` (+20) item as a stand-in). INVSLOTS is still fixing its grid layout in its own tree: do NOT
  restyle the grid, the panel layout or the action row; add your inspect/compare panel as its own control
  (game/scripts/ui/bag_inspect.gd or similar) hooked from inventory_ui.gd with a few lines.
- The capacity model already exists and is central (keep it central, spec 31 §13):
  game/scripts/items/inventory_equipment.gd:54-66 `capacity(inv)`: base + each worn item's def.bag_slots +
  attributes.pocket x rules pocket_slots_per_level (6) capped at max_pocket_level; game/scripts/items/inventory.gd:72
  `capacity()`. Unequip that would overflow is already refused (keep that behaviour and its test).
- Crafting with exact instances and level/attribute inheritance: game/scripts/items/crafting.gd (W2-DATA/W2-SKILLS gates,
  W2-INV instances). Another job (BUILDFLOW) edits crafting.gd for construction components: keep your crafting.gd edits
  small and inside bag-specific functions.
## Build (spec 31; every number in data, marked historical (Pocket +6/level, base 100) or # ASSUMPTION (curves, recipes))
1. Bag definitions in data: at least Basic Bag, Small Pouch, Large Pouch, Advanced Backpack, Specialized Storage Bag, each
   with its own capacity-for-level curve (table), recipe (materials with tags/min levels), min crafting level, equip slot
   and which storage attributes it can inherit. Replace the `woven_bag` stand-in with these (migrate any saved woven_bag
   to a Basic Bag of the same level; old saves must load).
2. Crafted bags are instances with a level from the existing material-based level rule and inherited attributes from the
   chosen materials (primary-material inheritance); Pocket comes ONLY from compatible inherited attributes or gear
   properties, never automatically from level.
3. One capacity function: total = base + equipped bag (curve(level) + pocket*6 + other storage mods) + clothing Pocket +
   other valid mods; deterministic; no double application; cargo dinosaurs and boxes stay separate inventories.
4. UI: the Bag header "Bag: used / capacity" refreshes at once on equip/unequip; an inspect panel shows level, storage
   capacity with its breakdown (base, Pocket Lv n, others), quality, durability; a compare line vs the worn bag ("Capacity
   change: +30", green up / warning down) before equipping; the crafting preview shows expected level, base capacity,
   inherited storage attributes, Pocket bonus, final capacity (success/flawless only if crafting already supports them),
   computed by the SAME function the crafted result uses.
## Milestones
- M1 game/tests/t_bags.gd: spec 31 §14 items 1-17 as asserts (copy t_domain.gd's --script pattern). Stage 1 fails until M2;
  that is expected for M1 only.
- M2 Data + capacity function + instances/inheritance + save/migration. Stage 1.
- M3 Crafting preview == result. Stage 1.
- M4 Inspect/compare panel + header refresh. Stage 1.
- M5 game/scripts/dev/bags_lab.gd + scene: craft two same-level bags from different materials, equip/unequip 10x, overflow
  attempt, open a cargo dino; print `[bags] RESULT base_cap= bag_types= same_level_diff= pocket1= pocket5= multi_mod_ok=
  reequip_stable= overflow_blocked= items_lost= preview_matches= save_roundtrip= header_ok= cargo_separate= compare_shown=
  ui_min_px=` and save shots: crafting preview, inspect panel, compare line, header before/after. Stage 2.
- M6 Look at every shot (path + verdict in NOTES.md); report docs/orchestration/reports/dsc-bags.md (historical vs assumed
  values, the migration, what the owner should tune later); full verify.

## How to run Godot (exactly)
- Headless test: `/private/tmp/claude-501/-Users-milankinzy-Documents-deadfront-siege/1899b1df-f06b-4b94-91be-9e3f3c22081d/scratchpad/gslot.sh perl -e 'alarm 400; exec @ARGV' /Applications/Godot_mono.app/Contents/MacOS/Godot --headless --path game --script res://tests/<t>.gd > /tmp/bags_t.log 2>&1` (bash timeout_ms 460000).
- Labs and screenshots need a window, never --headless (frame_post_draw never fires headless); bash timeout_ms 1020000, and the lab quits itself within 120 s:
  `... perl -e 'alarm 900; exec @ARGV' /Applications/Godot_mono.app/Contents/MacOS/Godot --path game --resolution 1600x900 --rendering-method gl_compatibility -- --lab=bags_lab --shot-dir=/tmp/bags_shots > /tmp/bags_lab.log 2>&1`, and again with --resolution 844x390 (the phone, landscape).
- After adding a class_name file or an asset: `... perl -e 'alarm 900; exec @ARGV' /Applications/Godot_mono.app/Contents/MacOS/Godot --headless --path game --import > /tmp/bags_import.log 2>&1`.
- Parse-check every new or edited .gd before a long run: `... --headless --path game --check-only --script res://<path>`.
  `--check-only` ALWAYS prints "Identifier not found: Data / World / Game / TouchControls" (autoloads do not exist in that
  mode): ignore those lines; only `Parse Error` lines are real. Real tests run with `--script res://tests/<t>.gd`, where the
  autoloads DO exist once the first frame runs: the test must load() every game script on its first frame instead of
  naming classes at compile time (copy game/tests/t_domain.gd's structure exactly).
- Never pipe Godot into tail/head/grep: read the log file afterwards. Never re-run a failed or hung command unchanged.
## Known traps
- `:=` cannot infer from max()/min()/ternaries/Variant returns: use maxf/maxi or an explicit type.
- Await coroutines. A `--script` test has no autoloads on its first frame: load() scripts on the first frame and add a 60 s
  quit watchdog, as game/tests/t_domain.gd does; print `[<test name>] PASS` or FAIL lines.
- game/tests/t_save.gd prints 5 deliberate SCRIPT ERRORs; that is normal.
- A lab log with `SHADER ERROR` or `Unknown character` means the shader did not compile and every card draws grey: the
  gate fails on it. GDScript `##` comments are not shader syntax; shaders use `//`.
- Scratch files go in $TMPDIR/bags, never /tmp or docs/. Never `rm -r` a path that has tracked files.
- Key any per-item data by a stable id (file name, src_rect), never by list order.
- Write big files in parts (write_file, then edit_file); never python `s.replace()` without checking it matched.
## Gates
- Verify: `bash /private/tmp/claude-501/-Users-milankinzy-Documents-deadfront-siege/72cebc8b-d241-430b-9ea6-94d65339bfef/scratchpad/dsc/verify_job.sh bags [1|2]` (no argument = the full gate). Read it and
  `/private/tmp/claude-501/-Users-milankinzy-Documents-deadfront-siege/72cebc8b-d241-430b-9ea6-94d65339bfef/scratchpad/dsc/job_bags.conf` (TEST, LAB, LAB_ASSERT, RELATED, SCOPE) before you start.
- The lab gets `--shot-dir=<dir>`: save every PNG there. It must print exactly one line `[bags] RESULT k=v k=v ...` with every
  key LAB_ASSERT reads, MEASURED from the live scene (never constants), then quit.
- Milestones: write them to .dsc/PLAN.md and call milestone_done after each (milestones before MS_STAGE2 run stage 1, later
  ones stage 2). Anything visual: open the PNG, and write the path and a one-line verdict in .dsc/NOTES.md before ticking.
## Constraints
- Your files are the SCOPE regex in the conf; touch nothing else. Edit shared files, do not rewrite them; keep existing asserts.
- Keep game/override.cfg. Never touch other worktrees, ~/Documents/deadfront, the owner's save, or the main checkout. Do not
  merge branches, push or deploy. No new dependencies.
- Do not tune balance numbers (HP, damage, XP, fatigue or energy rates). Owner: "game balancing like tuning hp and damage wont
  make sense until crafting building and skills is done and tuned". Mark every number the docs do not give `# ASSUMPTION`.
- Report docs/orchestration/reports/dsc-bags.md: what shipped, before/after numbers, the shots you looked at, assumptions,
  what the integrator needs.
