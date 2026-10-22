# Task: PROPS: non-resource scenery (collide or not, destroyable) and biome-weighted scatter

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
in a hooks patch docs/orchestration/reports/dsc-props-hooks.patch.

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
Mark every number the docs do not give `# ASSUMPTION:`. Report docs/orchestration/reports/dsc-props.md (what shipped, numbers
before/after, shots you looked at, assumptions, what the integrator needs).

Your files: new game/scripts/world/island_props.gd, game/data/world/props.json, island_scatter.gd (biome-weighted resource placement and chunked ground cover), veg_batch.gd if needed.

## Requirements
1. A scenery layer separate from resources: props are NOT in the "harvest" group, have NO tap zone or gather UI, never show a
   radial or label. Each prop kind in props.json has: models (existing game/assets/nature GLBs now; the BIOMEASSETS job adds
   game/assets/nature/biome/*.glb - use them when the files exist, skip missing ones), biomes it appears in (with weights),
   scale range, `collide` (true for big things: boulders, cliff rocks, termite mounds, fallen logs, rock spires - a static
   collider and a TilePath blocker; false for small things: reeds, plume grass, ferns, flowers, lily pads, pebbles) and
   `destroyable` (owner: "most props can be destroyed except for like really big cliffs": every prop except cliff/mesa
   formations can be cleared - e.g. by an attack or a build placement that needs the space; clearing removes it for that
   save, saved by tile; ASSUMPTION: clearing gives nothing).
2. Place props per biome zone (BiomeZones.biome_at when present - BIOMEZONES job; until it lands use a fallback from height,
   slope and tile type) and on ISLANDGEN's CLIFF tiles (cliff rocks there, indestructible), with densities from props.json so
   islands look full like the concept art; draw them batched (MultiMesh per cell, VegBatch-style) so a dense island stays
   within the camp budget the scout gives (visible primitives under 900k and draws ~160 in gl_compatibility at the camp).
3. Fix ground cover vanishing far from the origin: chunk the grass/flower MultiMesh into cells like VegBatch.
4. Make resource placement (island_scatter.gd _plant_family) weighted by biome zone (trees in forest, reeds/flax by water,
   ore/crystal nodes in rocky/canyon/basalt zones), keeping 400-600 HarvestNodes per island.
## Milestones
M1 props.json + IslandProps placement with collide/no-collide + no tap UI. M2 destroyable (clear + save by tile) with cliffs
indestructible. M3 chunked ground cover + biome-weighted resources. M4 tests + report. Lab game/scripts/dev/props_lab.gd
(windowed) prints `[props] id=<id> props=<n> colliding=<n> passable=<n> destroyable=<n> resources=<n> draws=<n>
prims_visible=<n>` and saves shots. Test game/tests/t_props.gd: props have no tap zone and are not in "harvest"; collide
props block TilePath and small ones do not; a destroyable prop clears and stays cleared after save/load; a cliff prop refuses.

## Authoritative plan (read it; it wins where it differs from this task)
First run `git merge claude/mmo-overhaul` in your work tree (it brings docs/design/islands-and-loop-plan.md, committed ab12e0fb,
and today's fixes). The plan sets the sizes, zones, budgets and package order; follow it.
- Plan look items: fix the 48 m ground-cover cut-off, forest groves and clearings, camp clutter; keep within the plan's budgets
  (camp under 900k visible and 3.0M shadow primitives). 2D cards (CARD2D) come later as plan P5: keep the prop layer able to
  swap a 3D model for a card per kind.

Verify command: `bash /private/tmp/claude-501/-Users-milankinzy-Documents-deadfront-siege/72cebc8b-d241-430b-9ea6-94d65339bfef/scratchpad/dsc/verify_props.sh` (read it; it must exit 0).
