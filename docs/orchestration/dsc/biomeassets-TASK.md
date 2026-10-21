# Task: BIOMEASSETS: headless-Blender props from the concept art

Context: DEADFRONT, a Godot 4.7.1 typed-GDScript dinosaur survival game (project `game/`), web build (gl_compatibility),
fixed iso camera (a CAMERA package is changing it to Durango's angle). The owner wants LARGER islands that look like a real
landmass - "I want peninsulas and large cliff resources (or non resource props)" - with biome zones on every island including
the starter, like the concept art in docs/design/durango-prompts/26_biome_concept_art.md (look at the four images it names in
docs/reference/: canyon oasis with red sandstone cliffs and waterfalls, volcanic wetland with basalt, savanna river delta).
Owner rules: "Not every plant/rock/etc is a resource, the resources have the UI that is clickable and the props do not. Some
props cause collision and some dont." "most props can be destroyed except for like really big cliffs".
READ FIRST: the island tech scout report /private/tmp/claude-501/-Users-milankinzy-Documents-deadfront-siege/72cebc8b-d241-430b-9ea6-94d65339bfef/scratchpad/islands-plan/../scout-tech.md (how islands are built today, with file:line, budgets, risks,
save compatibility) and its working PROTOTYPE patch /private/tmp/claude-501/-Users-milankinzy-Documents-deadfront-siege/72cebc8b-d241-430b-9ea6-94d65339bfef/scratchpad/islands-plan/proto-shape-biome-timing.patch (ragged elongated shapes via an
effective radius, a 420 m home, biome ids painted into the tile map's G channel, a palette in the shader, map colours; it
passed every test and an old-save load). Its shots are in /private/tmp/claude-501/-Users-milankinzy-Documents-deadfront-siege/72cebc8b-d241-430b-9ea6-94d65339bfef/scratchpad/islands-plan/shots/ (PROTO2_home420_biomes_top.png, atlas_base_vs_proto.png).
Four DeepSeek jobs work in parallel on separate files; stay in yours (listed below) and put any change to another job's file
in a hooks patch docs/orchestration/reports/dsc-biomeassets-hooks.patch.

## How to run Godot (exactly)
- Through the slot limiter with an alarm, output to a file, never piped into tail/head/grep, bash timeout_ms = alarm*1000+60000:
  `/private/tmp/claude-501/-Users-milankinzy-Documents-deadfront-siege/1899b1df-f06b-4b94-91be-9e3f3c22081d/scratchpad/gslot.sh perl -e 'alarm 300; exec @ARGV' /Applications/Godot_mono.app/Contents/MacOS/Godot --headless --path game --script res://tests/<t>.gd > /tmp/<k>_t.log 2>&1`
- Labs and shots need a window: drop --headless, add `--resolution 1600x900 --rendering-method gl_compatibility`.
- After adding class_name files or assets: `... --headless --path game --import > /tmp/<k>_import.log 2>&1` (alarm 900).
- Parse-check before a long run: `... --headless --path game --check-only --script res://<path>`.
## Known traps
- `:=` cannot infer from max()/min()/ternaries/Variant returns (use maxi/maxf/explicit types); await coroutines;
  a `--script` test must load() scripts on its first frame (copy game/tests/t_domain.gd's pattern) and add a 60 s watchdog
  `get_tree().create_timer(60).timeout.connect(func(): quit(2))`; t_save prints 5 deliberate SCRIPT ERRORs (normal).
## Constraints
Keep game/override.cfg. Never touch other folders under .claude/worktrees/, the owner's save, or ~/Documents/deadfront. Do not
push, merge or deploy. No new dependencies. Write .dsc/PLAN.md with the milestones below and call milestone_done after each.
Mark every number the docs do not give `# ASSUMPTION:`. Report docs/orchestration/reports/dsc-biomeassets.md (what shipped, numbers
before/after, shots you looked at, assumptions, what the integrator needs).

Your files: game/assets/nature/biome/ (new GLBs + textures), tools/blender/biome_props/ (scripts), game/data/world/biome_assets.json.

## Requirements
Build in headless Blender (`/Applications/Blender.app/Contents/MacOS/Blender -b --factory-startup -P <script>`), every script
committed under tools/blender/biome_props/ so the GLBs are reproducible, realistic stylised look matching the concept art and
the existing nature assets (look at game/assets/nature/ renders in game), low-poly for the web (budgets below), PBR-ish
materials with baked colour (no external textures you cannot ship), origin at the ground centre, Y up, metres:
- termite mound x2 (2-3.5 m, red earth), fallen log x2 (4-7 m, mossy and dry), rock spire x2 (5-9 m sandstone), mesa/cliff
  chunk x3 (8-15 m wide, red sandstone and black basalt; these are the big indestructible cliffs), basalt column cluster,
  boulder pile x2 (granite), reed clump x2, white plume grass clump, lily pad cluster (flat), fern clump x2, aloe with red
  flowers, crystal clusters x3 (pale blue, black obsidian, yellow sulphur; these become ore-node visuals), steam vent rim,
  hot-spring terrace rim (cream travertine), small pebbles patch.
- Budgets: small vegetation <= 800 tris, mounds/logs/boulders <= 2.5k, spires/mesas/cliffs <= 6k.
- biome_assets.json: one row per asset (path, kind, size m, suggested collide, destroyable=false only for mesas/cliffs/spires,
  biomes).
## Milestones
M1 vegetation (reeds, plumes, ferns, lily pads, aloe). M2 rocks/cliffs/spires/mesas/basalt/boulders/mounds/logs. M3 crystals,
vent, terrace rim, pebbles. M4 a contact sheet render of everything (neutral light, next to a 1.8 m figure) at
docs/orchestration/reports/dsc-biomeassets-sheet.png - look at it and fix anything that looks wrong - and the report.
Godot only for the import check: `... --headless --path game --import` (alarm 900) must show 0 errors for the new files.

## Authoritative plan (read it; it wins where it differs from this task)
First run `git merge claude/mmo-overhaul` in your work tree (it brings docs/design/islands-and-loop-plan.md, committed ab12e0fb,
and today's fixes). The plan sets the sizes, zones, budgets and package order; follow it.
- The plan's zones and spec 26 decide which props matter first: cliffs/mesas/spires, reeds and plumes for riverbanks, termite
  mounds and aloes for savanna, basalt and crystals for rocky/volcanic zones.

Verify command: `bash /private/tmp/claude-501/-Users-milankinzy-Documents-deadfront-siege/72cebc8b-d241-430b-9ea6-94d65339bfef/scratchpad/dsc/verify_biomeassets.sh` (read it; it must exit 0).
