# Task: INVSLOTS: the bag is a scrolling grid of slots, one item per slot, with upgradable capacity

Owner, verbatim: "the inventory system doesn't match what I asked for in the docs. Have deepseek work on inventory such that
its a scroll view with slots, 1 item per slot and we can upgrade slots".
DEADFRONT is a Godot 4.7.1 typed-GDScript survival game (project `game/`), web build, mobile-first (phone 844x390 landscape,
tap targets >= 64 px, all input through InputMap actions and the touch layer).

## What the docs say (read both files first)
- docs/design/durango-prompts/05_inventory_stacking_storage.md: gathered and crafted items do NOT stack; each is an instance
  (line 3, 6: "Five Large Leg Bones ... consume five physical spaces"); base player inventory 100 spaces, equipment adds
  storage slots, Pocket attribute +6 spaces per level, bonuses added once and removed on unequip, never shrink below occupied
  slots and never delete rare items (line 11); optional visual grouping must expand to one selectable slot per instance (line
  23); virtualized lists where necessary (line 26).
- docs/design/durango-prompts/13_inventory_equipment_ui.md: a dense grid of compartments (lines 107-124), empty slots visible,
  capacity from real data that updates when equipment changes and warns when full (lines 87-104), selected-slot yellow
  brackets, level label, rare green mark (lines 139-181, 294-297), scrollable with smooth scrolling (lines 495, 506), the same
  slot design for storage and dinosaur cargo (lines 451-462).
## Today (measure it yourself in M1)
- Model: game/scripts/items/inventory.gd, inventory_equipment.gd (W2-INV made materials and food single instances with uids,
  100-slot bag). UI: game/scripts/ui/inventory_ui.gd draws a GROUPED bag with count pills and level ranges: this is what the
  owner rejects. Lab: game/scripts/dev/inventory_lab.gd (+ game/scenes/dev/inventory_lab.tscn).
- An unmerged branch claude/mmo-invui (spec 13 bag and gear screens) may already have pieces you can reuse. Read it with
  `git show claude/mmo-invui:<path>` and `git diff claude/mmo-overhaul...claude/mmo-invui -- game/scripts/ui`; copy what fits.
  Do not merge it.
## What to build
1. The bag is a scroll view (ScrollContainer or equivalent; drag on touch, wheel on desktop) holding a grid with exactly
   `capacity` slots: one item instance per slot, empty slots drawn, no count pills, no grouped stacks (remove grouping; an
   optional "group" toggle is allowed only if it expands to one slot per instance, off by default). Level label, selected
   brackets and the rare mark per spec 13. Slots >= 64 px at 844x390. A capacity indicator "used / capacity" from the data,
   warning colour when full. Smooth with capacity 300 (virtualize rows if needed).
2. Upgradable capacity per spec 05: base 100; equipment that adds storage slots and the Pocket attribute (+6 per level) raise
   it on equip and lower it on unequip; an unequip that would leave fewer slots than items is refused with a notice and
   nothing is ever deleted; the grid grows and shrinks live. Find what exists in game/data/items.json and
   inventory_equipment.gd. If no item adds slots today, add ONE data-only bag item from the docs (values `# ASSUMPTION`) so it
   can be tested. If capacity bonuses need a save-format change, STOP there and write "owner decision needed" in the report.
3. If storage/basket and pet cargo use inventory_ui.gd, give them the same slot grid; otherwise list them in the report.
## Milestones
- M1 Read the docs and code, open the current bag in inventory_lab at 1600x900 and 844x390, write what you saw in
  NOTES.md; write game/tests/t_invslots.gd: N identical items take N slots; capacity = base + bonuses and changes on
  equip/unequip; an overflowing unequip is refused with 0 items lost; save then load keeps every instance and the capacity.
  The model side passes: stage 1.
- M2 The slot grid UI (scroll, one per slot, empty slots, no pills, capacity indicator). Stage 1.
- M3 game/scripts/dev/invslots_lab.gd + game/scenes/dev/invslots_lab.tscn: open the bag with some items, print
  `[invslots] RESULT capacity= grid_slots= items= filled= empty_visible= pills= min_slot_px= scroll_range= frame_ms_p95_300=
  cap_upgraded= cap_after_unequip= items_lost=` (frame_ms_p95_300 = 95th percentile frame ms while scrolling a 300-slot bag;
  pills = count badges visible), save shots of the bag (and the 300-slot bag) into --shot-dir. Stage 2.
- M4 Phone pass at 844x390 and the 300-slot smoothness. Stage 2.
- M5 Report and the full verify.

## How to run Godot (exactly)
- Headless test: `/private/tmp/claude-501/-Users-milankinzy-Documents-deadfront-siege/1899b1df-f06b-4b94-91be-9e3f3c22081d/scratchpad/gslot.sh perl -e 'alarm 400; exec @ARGV' /Applications/Godot_mono.app/Contents/MacOS/Godot --headless --path game --script res://tests/<t>.gd > /tmp/invslots_t.log 2>&1` (bash timeout_ms 460000).
- Labs and screenshots need a window, never --headless (frame_post_draw never fires headless):
  `... perl -e 'alarm 400; exec @ARGV' /Applications/Godot_mono.app/Contents/MacOS/Godot --path game --resolution 1600x900 --rendering-method gl_compatibility -- --lab=invslots_lab --shot-dir=/tmp/invslots_shots > /tmp/invslots_lab.log 2>&1`, and again with --resolution 844x390 (the phone, landscape).
- After adding a class_name file or an asset: `... perl -e 'alarm 900; exec @ARGV' /Applications/Godot_mono.app/Contents/MacOS/Godot --headless --path game --import > /tmp/invslots_import.log 2>&1`.
- Parse-check every new or edited .gd before a long run: `... --headless --path game --check-only --script res://<path>`.
- Never pipe Godot into tail/head/grep: read the log file afterwards. Never re-run a failed or hung command unchanged.
## Known traps
- `:=` cannot infer from max()/min()/ternaries/Variant returns: use maxf/maxi or an explicit type.
- Await coroutines. A `--script` test has no autoloads on its first frame: load() scripts on the first frame and add a 60 s
  quit watchdog, as game/tests/t_domain.gd does; print `[<test name>] PASS` or FAIL lines.
- game/tests/t_save.gd prints 5 deliberate SCRIPT ERRORs; that is normal.
- Write big files in parts (write_file, then edit_file); never python `s.replace()` without checking it matched.
## Gates
- Verify: `bash /private/tmp/claude-501/-Users-milankinzy-Documents-deadfront-siege/72cebc8b-d241-430b-9ea6-94d65339bfef/scratchpad/dsc/verify_job.sh invslots [1|2]` (no argument = the full gate). Read it and
  `/private/tmp/claude-501/-Users-milankinzy-Documents-deadfront-siege/72cebc8b-d241-430b-9ea6-94d65339bfef/scratchpad/dsc/job_invslots.conf` (TEST, LAB, LAB_ASSERT, RELATED, SCOPE) before you start.
- The lab gets `--shot-dir=<dir>`: save every PNG there. It must print exactly one line `[invslots] RESULT k=v k=v ...` with every
  key LAB_ASSERT reads, MEASURED from the live scene (never constants), then quit.
- Milestones: write them to .dsc/PLAN.md and call milestone_done after each (milestones before MS_STAGE2 run stage 1, later
  ones stage 2). Anything visual: open the PNG, and write the path and a one-line verdict in .dsc/NOTES.md before ticking.
## Constraints
- Your files are the SCOPE regex in the conf; touch nothing else. Edit shared files, do not rewrite them; keep existing asserts.
- Keep game/override.cfg. Never touch other worktrees, ~/Documents/deadfront, the owner's save, or the main checkout. Do not
  merge branches, push or deploy. No new dependencies.
- Do not tune balance numbers (HP, damage, XP, fatigue or energy rates). Owner: "game balancing like tuning hp and damage wont
  make sense until crafting building and skills is done and tuned". Mark every number the docs do not give `# ASSUMPTION`.
- Report docs/orchestration/reports/dsc-invslots.md: what shipped, before/after numbers, the shots you looked at, assumptions,
  what the integrator needs.
