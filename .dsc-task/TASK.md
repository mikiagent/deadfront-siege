# Task: MATLOOK — material appearance data (spec 35 package 1 of 4)

Read docs/design/durango-prompts/35_natural_material_color.md (the owner's spec) fully, then
docs/current/inventory-bags.md, docs/current/items-traits.md, docs/current/world-biomes.md.

This package is ONLY the data model and its flow from tree to bag. Crafted-item tinting, building inheritance and the
inspect UI are later packages; do not build them.

Do:
1. game/data/materials/wood_species.json: wood species, each with a stable id, display name, base colour (sRGB hex),
   a colour family label (e.g. "reddish-brown"), a grain/texture tag, and a per-log variation range (small hue/value
   jitter). Use the spec's table (mahogany, almond, oak, palm, maple, pine, walnut, ebony) as illustrative palettes;
   add species only where our trees exist. Map OUR tree kinds (game/data/nature_manifest.json roles "tree": birch,
   pine, acacia, palm, willow, common, ...) and climates to species — a tree kind yields one species (maybe two by
   climate); mark every mapping `# ASSUMPTION` in an "_about" field. Do not rename or remove any existing item.
2. Appearance is a SEPARATE dimension from level and traits (spec §3): an item instance (ItemStack) gains an optional
   `look` dictionary {species, color (hex), family, grain} — never derived from rarity, level or traits, and never
   affecting them. Logs (and wood products the existing gather path yields from trees: check harvest_yield.gd /
   gather/ for what a tree drops) get `look` at gather time from the node's species with seeded per-log variation.
   Grouping in the bag must keep different species distinguishable (instances already are; check the grouped view
   does not merge across species if it groups by def_id — if it does, group by def_id+species).
3. Saves and server: `look` is additive and optional; old saves load unchanged (items without `look` stay valid and get
   none, or a default species for wood items — choose and justify); save round-trip keeps it; srvdom/econ validators
   accept it (whitelist in their limits so traded logs keep their look) and refuse malformed values. Fixture test.
   FLAG IN THE REPORT: this is an item-instance save field (owner gate before merge).
4. docs/current/inventory-bags.md + items-traits.md: short facts about `look`.

Milestones (.dsc/PLAN.md; milestone_done each):
M1 game/tests/t_matlook.gd (t_domain.gd structure, "[t_matlook] PASS"): species table valid (hex colours, families,
   every tree kind mapped); a log gathered from a mapped tree carries that species' look, two logs differ slightly
   (variation) but stay inside the species range; look never changes level/traits/value and traits never change
   look; old save without look loads; save round-trip keeps look; econ/srvdom accept a valid look and refuse a forged
   one. Fails on base. Stage 1.
M2 data + ItemStack field + gather hook. M3 save/server/econ + grouping. M4 docs + report
docs/orchestration/reports/dsc-matlook.md + full verify. Headless only (owner reserved the machine).
Do not touch balance numbers. Another worker is changing foods (foodcat) and islands (islands2): keep items.json edits
to wood items only, and do not edit island shape code.

## How to run Godot (exactly)
- Headless test: `/private/tmp/claude-501/-Users-milankinzy-Documents-deadfront-siege/1899b1df-f06b-4b94-91be-9e3f3c22081d/scratchpad/gslot.sh perl -e 'alarm 400; exec @ARGV' /Applications/Godot_mono.app/Contents/MacOS/Godot --headless --path game --script res://tests/<t>.gd > /tmp/matlook_t.log 2>&1` (bash timeout_ms 460000).
- After adding a class_name file or an asset: `... perl -e 'alarm 900; exec @ARGV' /Applications/Godot_mono.app/Contents/MacOS/Godot --headless --path game --import > /tmp/matlook_import.log 2>&1`.
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
- Scratch files go in $TMPDIR/matlook, never /tmp or docs/. Never `rm -r` a path that has tracked files.
- Key any per-item data by a stable id (file name, src_rect), never by list order.
- Write big files in parts (write_file, then edit_file); never python `s.replace()` without checking it matched.
## Gates
- Verify: `bash /private/tmp/claude-501/-Users-milankinzy-Documents-deadfront-gate/a2917b6d-2049-454d-9c63-314953df33d7/scratchpad/dsc/verify_job.sh matlook [1|2]` (no argument = the full gate). Read it and
  `/private/tmp/claude-501/-Users-milankinzy-Documents-deadfront-gate/a2917b6d-2049-454d-9c63-314953df33d7/scratchpad/dsc/job_matlook.conf` (TEST, LAB, LAB_ASSERT, RELATED, SCOPE) before you start.
- The lab gets `--shot-dir=<dir>`: save every PNG there. It must print exactly one line `[matlook] RESULT k=v k=v ...` with every
  key LAB_ASSERT reads, MEASURED from the live scene (never constants), then quit.
- Milestones: write them to .dsc/PLAN.md and call milestone_done after each (milestones before MS_STAGE2 run stage 1, later
  ones stage 2). Anything visual: open the PNG, and write the path and a one-line verdict in .dsc/NOTES.md before ticking.
## Constraints
- Your files are the SCOPE regex in the conf; touch nothing else. Edit shared files, do not rewrite them; keep existing asserts.
- Keep game/override.cfg. Never touch other worktrees, ~/Documents/deadfront, the owner's save, or the main checkout. Do not
  merge branches, push or deploy. No new dependencies.
- Do not tune balance numbers (HP, damage, XP, fatigue or energy rates). Owner: "game balancing like tuning hp and damage wont
  make sense until crafting building and skills is done and tuned". Mark every number the docs do not give `# ASSUMPTION`.
- Report docs/orchestration/reports/dsc-matlook.md: what shipped, before/after numbers, the shots you looked at, assumptions,
  what the integrator needs.
