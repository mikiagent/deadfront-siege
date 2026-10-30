# Tutorial island — new survivors, tutorial orders, home grant

A new survivor lands on a shared tutorial island after character creation, follows the tutorial
orders, and the last order grants their own Tamed Island. Flow: `game/scripts/core/tutorial.gd`
(`Tutorial`); orders: `game/data/world/objectives.json` `"tutorial"`; island:
`game/data/islands/tutorial_isle.json`; test: `game/tests/t_tutorial.gd`.

## Flow
- `World.start_new` → character creation → `Tutorial.begin`: builds `tutorial_isle`, lands the
  survivor on the dock's arrival point, sets `World.tutorial = {"done": false, "did": {}}`,
  lifts `creation_pending` and saves. The island pick does not open at creation any more.
- The orders run on the Orders system: `Objectives._steps()` returns `Data.world_tutorial` while
  `Tutorial.active()`, so the HUD orders card/badge, the Orders sheet and `Objectives.settle`
  (XP + T-stone payouts) work unchanged. `World.objective` indexes the tutorial list meanwhile.
- The last order (`grant_home: true`, walk onto the dock) calls `Tutorial.grant_home`: the
  ISLANDPICK screen opens; SELECT AND MOVE runs `Tutorial.ferry` → fade → `World.complete_pick`
  (builds the home, lands at its harbour, saves, "YOU MADE IT").
- At the ferry: `tutorial.done = true`; `World.objective` = index of `tutorial_resume_at` ("net")
  in the standing orders; `harvested`, `away_domain`, `unstable_claims` cleared;
  `free_claim_used = false`. Bag, gear, skills, levels, T-stones and bonded animals carry over.
  Buildings placed on the tutorial island stay there.
- While the tutorial runs, `World.travel` refuses every departure from the tutorial island
  ("Finish the orders here first"), and `harbour_routes()` never lists a `kind: tutorial` island.

## The orders (objectives.json "tutorial", 19)
| # | id | Condition | Pointer (`point_at`) |
|---|---|---|---|
| 1 | tut_camp | within 6 m of the Adventurer's Guild | world:guild |
| 2 | tut_branches | hold 3 branch | harvest:branch |
| 3 | tut_stone | hold 2 stone | harvest:stone |
| 4 | tut_fibre | hold 4 fibre_stalk | harvest:fibre_stalk |
| 5 | tut_drink | status `quenched` (water search 260 m) | ctx:drink, else world:water |
| 6 | tut_eat | 1 committed meal (`did.eat`) | menu: BAG > Berries > Use while holding berries, else harvest:berries |
| 7 | tut_rest | resting or sleeping | ctx:rest |
| 8 | tut_twine | hold 1 twine | menu: MENU > Craft > Materials > Twine > Craft |
| 9 | tut_knife | hold 1 stone_knife_work (by hand; a knife is needed to cut meat) | menu: MENU > Craft > Tool > Stone Work Knife > Craft |
| 10 | tut_axe | hold 1 work_axe (workbench) | menu: bench > CRAFT > Tool > Work Axe > Craft |
| 11 | tut_logs | hold 2 wood_log | harvest:wood_log |
| 12 | tut_hunt | 1 kill by the survivor (`did.kill`) | world:creature:compsognathus |
| 13 | tut_butcher | hold raw_meat or raptor_meat | world:corpse |
| 14 | tut_fire | the stone fire pit burns (`Bonfire.burning()`; a fire without it counts as lit) | menu: pit > FUEL > Branch |
| 15 | tut_cook | hold 1 herb_buff_meal (`roled_herb_roast`: meat main + herb topping + branch support, station bonfire) | herb node, then menu: pit > COOK > Cooking > Herbed Meal > Craft |
| 16 | tut_meal | ate a herb_buff_meal (`did.eat:herb_buff_meal`) | menu: BAG > Herbed Meal > Use |
| 17 | tut_skill | 1 skill node with an SP cost learned (`did.skill`) | menu: MENU > Skills > a skill with a dot > Learn |
| 18 | tut_build | 1 placement (`did.build`); hint: straw_roll_kit | menu: MENU > Craft > Building Components > Straw Roll > Craft, then MENU > Craft > Build (bottom) > Straw Roll |
| 19 | tut_ferry | within 7 m of the dock arrival; `grant_home` | world:harbour |
Rewards per order: 15-60 XP and 0-3 T-stones (the json). No taming order.

`did` counts come from hooks that call `Tutorial.note` only while the tutorial runs:
`EatSession._finish` (eat, eat:<item>), `World.record_raid_kill` (kill, source is the Player),
`World.note_building` (build), `SkillState.unlock` with cost > 0 (skill).

## The island (`tutorial_isle.json`)
- kind `tutorial`, permanent, grassland, `level_override` 1, seed 9091. Landmass `land_m`
  795 x 636 m (4.5x the home's 375 x 300; `IslandShape.make` `p_land`), `size_m` 880,
  `terrain_res` 241 (`IslandTerrain` takes the shape's res). `dock_rule` south (TUTTOWN 2026-10-29,
  owner "move it"): the dock is on the southern-most coast like every island (lands at about
  (-67, 317)); the camp (town centre) hint (-51, 271) is the flattest dry ground ~48 m inland of it,
  on the southern peninsula. The nearest fresh water (the river) is ~205 m north, through the gate.
- Never claimed: no CLAIM context hex (`player_input.gd`), `claim_confirmed` refuses with a notice.
  The camp's landing plot stays buildable (the bedroll order places there).
- Town (`Tutorial.dress`, around the camp): the camp's fire, workbench, shed and cargo chest, plus
  `TownBuilding`s — Adventurer's Guild (`log_shelter` model, role guild: tap opens the Orders
  sheet), Market stall (`fishing_stand`, role market: tap opens the Island Market), signpost,
  barrel, crates — a stone fire pit and a drying rack. All `persist_building = false`: never saved,
  `StructureHealth.is_structure` false (no damage), pack-up refused, grid cells occupied.
- 3 HerbPlant, 3 BerrySprig 14-16 m and 2 CommonTree 19 m from the town centre.
- Wild lands (`wild_zones`, `ZoneSpawner`): 11 groups at 100-360 m from the town, aimed north
  (inland). Owner 2026-10-29: ONLY compsognathus (the first hunt: singles at 100 m, packs of 2-3
  further out) and zebraceratops (the first tame: herds of 2-3 at 120-360 m); the town pens hold the
  same two. The hunt order's pointer (`world:creature:compsognathus`) names only a living
  compsognathus, else the nearest compsognathus zone. A zone spawns when the survivor is within 110 m,
  removes its living animals past 170 m (never her hunt target), respawns 240 s after a kill,
  checks at 2 Hz and stays inside `Game.max_creatures_per_island` (24).
- Safe town (`town_safe_m` 100): every zone is pushed out to at least 100 m from the town, so the
  single compsognathus sit at 100 m (200/265/330 degrees), the packs further out, and the early gather orders are not harassed. No alphas
  roll on this island (`no_alphas`). Open Questions TU9-TU10.
- Perf limits (island data): ground cover full within 120 m of the town and 6 % beyond
  (`cover_full_radius_m`, `cover_far_share`, `GroundCover.plan`), biome dressing 30 %
  (`dress_share`, `BiomeDress`). Measured headless (t_tutorial / probe): build 8.2-9.0 s, ~66k
  multimesh instances (52k cover), 609 harvest nodes, ~5.6k scene nodes, ~215 MB static heap
  added. Home on the same machine: build ~3.9 s.
- HUD map title reads "Tutorial Island"; the atlas lists island time as "Permanent"; town pills show
  the building's name (`hud_pills.gd`); the domain banner never shows on this island (`domain_banner.gd`).

## The town (`game/scripts/world/town_dress.gd`, TUTTOWN 2026-10-29)
- `Tutorial.dress` ends with `TownDress.build(rt)`: the camp square (24 m) stays as above; around it
  five avenues (one to the dock) and two ring roads, paved inside the inner ring and dirt beyond, with
  footpaths from every front door; four rings of lots, then an infill pass that fills every free lot
  with a cottage, a fenced kitchen garden or a yard; fields / pens past the outer ring; a palisade at
  97 m with a gate (posts, lintel, lamps, signpost) wherever an avenue leaves; extra piers with boats,
  crates and fish racks beside the dock. Roofs: thatch, shingle, slate or tile, pitch 0.45-0.75. Districts by angle from the dock: harbour, market (striped stalls), homes,
  pens + hunters' tents (toward the wild lands), farms, workshops (open shelters; forges and grills
  always busy through `StationState`, racks of drying meat, kilns, looms). The Adventurer's Guild hall
  (two storeys, banner, torches) stands behind the guild pavilion. Lamp posts and signposts line the
  streets. Townsfolk (survivor body, random look) idle or loop a work clip at the stations; four walk
  the avenues; tamed animals stand in the pens.
- Measured headless (`scripts/dev/tuttown_map.gd`, which also writes the top-down footprint PNG):
  ~75 houses (50 on the rings + 25 infill), 13 stalls, 6 workshops, 8 fields, 13 gardens, 13 yards,
  4 pens, 2 extra piers, 79 palisade panels, 41 lamps, 13 townsfolk, 6 pen animals; ~1,960 instances
  in ~182 MultiMeshInstance3D; 235 collision boxes on one physics body; town build ~0.9 s; island
  scene ~6,540 nodes (TUTPERF budget 9,000), 666 ticking (budget 900).
- Scenery only: no node is saved or damaged; the footprints are occupied in the BuildGrid (nothing is
  built over them, the tile router walks the streets); cover, dressing, props and non-tutorial
  harvest nodes on footprints and roads are cleared. Every order target, the dock and every wild zone
  stay reachable from the camp.

## Menu guidance (`Tutorial.guide`, TUTTOWN 2026-10-29)
- An order done in a menu lists its taps under `menu` in objectives.json (alternatives, each optionally
  led by `have:<item>`). The pointer rings the deepest element on screen with a "Tap <name>" caption,
  so it walks MENU -> Craft -> the tab -> the entry -> Craft as the player taps. A tab that shows but is
  not the open one blocks the entry behind it (All open still asks for Materials first). An entry in a
  list is scrolled into view once; if the player scrolls it away, a "Scroll down / up" cue shows on the
  list instead of the ring. The hints spell the same route. Test: `game/tests/t_tutguide.gd`.
- Craft / Build tab order: Materials, Tool, Weapon, Cooking, Clothing, Building Components, Farming,
  All; Build is the bottom row of the list page.

## Onboarding pointer (`game/scripts/ui/tutorial_pointer.gd`)
- Added by `main.gd` on its own canvas layer (`TutorialLayer`, 97: over the HUD, the menus and the modals).
  It eases toward its goal every frame (exponential approach 12/s, at most 2,600 px/s), so a new
  target glides instead of jumping, and a world target that is a node (a creature, a carcass, a
  harvest node) is read every frame so the arrow follows it. 5 Hz `Tutorial.pointer_target`; draws a pulsing gold ring
  and arrow on a HUD Control (`ui:<node name>`, `ctx:<id>` → the `Ctx_<id>` context hex or
  INTERACT when it carries that action) or an arrow over a world point (edge arrow off screen).
- A plain pointer (and a menu path's first element) hides while the bag, craft screen, a HUD sheet or
  character creation/pick is up; inside a menu the guide's ring and caption show over it.

## Saves
- `"tutorial": {"done": bool, "did": {key: int}}` is written only while the tutorial runs. A
  save without it loads as done (every pre-tutorial save owns a home), so home saves keep their
  old shape. `Tutorial.from_save` keeps a bool and integer counts (0..1,000,000, keys ≤ 64 chars).
- After a load, `Tutorial.resume` re-opens the grant if every order is done.

## Dev
- `--skip-tutorial`: a new game goes straight to the pick (old flow); a mid-tutorial save jumps to
  the grant. `--tutorial-step=<n>`: a new game starts at order n (1-based).
- `--lab=tutorial`: the normal new-game flow in a fresh `user://runs/tutorial/` save folder.
- `--tutorial-bot [--tutorial-shots=<dir>]`: plays every order windowed and saves captures
  (`game/scripts/dev/tutorial_bot.gd`).
