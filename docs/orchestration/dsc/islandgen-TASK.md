# Task: ISLANDGEN: larger islands with peninsulas, cliffs and a real river

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
in a hooks patch docs/orchestration/reports/dsc-islandgen-hooks.patch.

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
Mark every number the docs do not give `# ASSUMPTION:`. Report docs/orchestration/reports/dsc-islandgen.md (what shipped, numbers
before/after, shots you looked at, assumptions, what the integrator needs).

Your files: game/scripts/world/island_terrain.gd (height/shape part), island_runtime.gd, harbour_site.gd, tile_path.gd region, island_spawns.gd, world/islands.json and data/islands/*.json sizes and seeds, rules.json sizes.

## Requirements
1. Start from the prototype's shape code (effective radius, precomputed rt._rad with bilinear rad_at; never call noise in is_dry).
   Make shapes a real landmass: 2-4 PENINSULAS/headlands per island with bays and inlets between them (strong low-frequency
   angular lobes plus domain warp, not a crinkled disc), aspect 0.6-0.85, a different seed per island from data (seed in
   islands.json; keep seed 17 for home's legacy core).
2. Sizes: home land about 380 x 310 m (bounding square ~420 m); unstable islands 400-520 m by tier (ASSUMPTION per tier).
3. Elevation that reads as terrain: highlands with CLIFFS - steep steps/escarpments where the terrain rises (2-6 m faces),
   a mesa or plateau on most islands, a valley; mark cliff cells with a new tile type CLIFF (impassable in TilePath and
   spawn_ok) so props/resources jobs can place cliff rocks there; keep shores walkable.
4. One REAL RIVER per island (most islands): a path from a highland source to the sea, computed once and read by both the
   height loop and the tile-type loop (today duplicated); keep the depth profile t_water expects; a waterfall where it drops
   over a cliff is a plus (a marker the props job can use).
5. Old saves: guarantee the legacy dry flat core (~50-60 m around the origin, old height function blended in) so existing home
   buildings/baskets/claims survive; a load rescue that moves a player saved off dry land to the camp; drop stale bare_tiles.
6. Fix the circle assumptions the scout lists (TilePath region from the dry bounding box, scatter windows, spawn clamp,
   ring distance from the landing point) and the build-time hot spots (precompute slope, packed arrays) so a home build
   stays under 2.5 s native.
## Milestones
M1 shape + sizes + seeds (shots of all 15 islands top-down; distinct heightmaps). M2 cliffs + river. M3 old-save core + rescue
+ circle fixes. M4 all tests pass + report. Write the measuring lab game/scripts/dev/islandgen_lab.gd (windowed): prints per
island `[islandgen] id=<id> land=<m2> bbox=<w>x<h> aspect=<a> peninsulas=<n> coast_ratio=<P/sqrtA> cliff_cells=<n>
river_to_sea=<true/false> build_ms=<ms>` and saves a top-down shot per island with --shot-dir=<dir>; count a peninsula as a land
lobe whose width is under 45 % of its length that sticks out past the convex-hull deficiency of its neighbours (document the
measure). Test game/tests/t_islandgen.gd asserts the same numbers for home and 3 other islands.

## Authoritative plan (read it; it wins where it differs from this task)
First run `git merge claude/mmo-overhaul` in your work tree (it brings docs/design/islands-and-loop-plan.md, committed ab12e0fb,
and today's fixes). The plan sets the sizes, zones, budgets and package order; follow it.
- Sizes (plan section 2): home land 375 x 300 m on a 416 m square; unstable islands 330x265, 375x300 or 415x335 m by tier;
  heightmap resolution 161. Every island also gets a harbour cove, a pond and a crater (plan); rings are measured from the landing,
  and unstable camps sit within 40 m of the dock. New harvest node ids carry a layout tag so old harvest records match nothing.
- Budgets (plan): island build <= 2.5 s native; 450-750 harvest nodes and <= 6k scene nodes per island.

Verify command: `bash /private/tmp/claude-501/-Users-milankinzy-Documents-deadfront-siege/72cebc8b-d241-430b-9ea6-94d65339bfef/scratchpad/dsc/verify_islandgen.sh` (read it; it must exit 0).
