# Task: BIOMEZONES: biome-painted ground and map colours like the concept art

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
in a hooks patch docs/orchestration/reports/dsc-biomezones-hooks.patch.

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
Mark every number the docs do not give `# ASSUMPTION:`. Report docs/orchestration/reports/dsc-biomezones.md (what shipped, numbers
before/after, shots you looked at, assumptions, what the integrator needs).

Your files: new game/scripts/world/biome_zones.gd, game/data/world/biomes.json, terrain_tiles.gdshader, climate_palette.gd, world/climates.json palettes, the tile-type/biome part of island_terrain.gd (_build_tile_types and the tile image), hunt_hud.gd map texture.

## Requirements
1. Start from the prototype's biome part (biome id per tile in the tile map's G channel, an 8x2 palette texture, soft painted
   edges from two noise-displaced samples, map colours by biome).
2. Biomes (data in biomes.json, each with ground tints, texture mix, density multipliers for resource and prop families):
   meadow, forest floor, golden savanna, red-earth canyon (sandstone), black basalt/volcanic ash, wetland/riverbank (green,
   muddy), beach, rocky highland. Assign per tile from elevation, slope, distance to river and coast, and a moisture noise, with
   per-climate weights so each island has 3-5 zones (the starter: meadow + forest + riverbank + rocky highland + beach;
   savannah/desert islands: golden savanna + canyon; volcanic: basalt + wetland). Expose BiomeZones.biome_at(rt, x, z) and
   rt.biome_types for the props and scatter jobs.
3. Palettes for every climate in climates.json (7 lack one today); ground must clearly read as the concept art's colours
   (red earth, golden grass, black basalt, green riverbanks) in gl_compatibility.
4. Map/minimap colour each tile by its biome (the atlas follows).
5. Keep the tile map square; do not change heights or shapes (ISLANDGEN does) - read them through the existing API.
## Milestones
M1 biome table + per-tile assignment + rt.biome_types. M2 shader painting and climate palettes; shots of the starter and 3 other
climates at 1600x900 next to the concept art - look at them. M3 map colours. M4 tests + report. Lab
game/scripts/dev/biome_lab.gd (windowed) prints `[biome] id=<id> zones=<n> share=<biome:pct,...>` per island and saves ground
and map shots with --shot-dir. Test game/tests/t_biomes.gd: every island has >= 3 zones, the starter has meadow, forest,
riverbank, rocky and beach, every climate has a palette, the tile image G channel matches rt.biome_types.

## Authoritative plan (read it; it wins where it differs from this task)
First run `git merge claude/mmo-overhaul` in your work tree (it brings docs/design/islands-and-loop-plan.md, committed ab12e0fb,
and today's fixes). The plan sets the sizes, zones, budgets and package order; follow it.
- Plan P2 BIOMEBASE + P4 BIOMES: first `git merge claude/mmo-w1-biome` (W1-BIOME, unmerged: 10 Blender-baked ground texture sets
  and BiomeMaterial) and hook BiomeMaterial.apply_terrain into the terrain material as the plan says; then paint the plan's zones
  (home: camp meadow, meadow, birch-oak forest, riverbank, rocky hills, dry upland, beach; every climate its own zone table) with
  W1-BIOME's own textures, not by tinting a green photo. The texture sets add ~28 MB to a pack already over its ceiling: ship
  only the climates in use, or 512 px versions, until WEBPACK lands.

Verify command: `bash /private/tmp/claude-501/-Users-milankinzy-Documents-deadfront-siege/72cebc8b-d241-430b-9ea6-94d65339bfef/scratchpad/dsc/verify_biomezones.sh` (read it; it must exit 0).
