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

## The orders (objectives.json "tutorial", 18)
| # | id | Condition | Pointer (`point_at`) |
|---|---|---|---|
| 1 | tut_camp | within 7 m of the camp | world:camp |
| 2 | tut_branches | hold 3 branch | harvest:branch |
| 3 | tut_stone | hold 2 stone | harvest:stone |
| 4 | tut_fibre | hold 4 fibre_stalk | harvest:fibre_stalk |
| 5 | tut_drink | status `quenched` | ctx:drink, else world:water |
| 6 | tut_eat | 1 committed meal (`did.eat`) | bag while holding berries, else harvest:berries |
| 7 | tut_rest | resting or sleeping | ctx:rest |
| 8 | tut_twine | hold 1 twine | ui:MenuHex |
| 9 | tut_axe | hold 1 work_axe (workbench) | world:bench |
| 10 | tut_logs | hold 2 wood_log | harvest:wood_log |
| 11 | tut_hunt | 1 kill by the survivor (`did.kill`) | world:creature |
| 12 | tut_butcher | hold raw_meat or raptor_meat | world:corpse |
| 13 | tut_fire | the stone fire pit burns (`Bonfire.burning()`; a fire without it counts as lit) | world:firepit |
| 14 | tut_cook | hold 1 herb_buff_meal (`roled_herb_roast`: meat main + herb topping + branch support, station bonfire) | herb node, then the pit |
| 15 | tut_meal | ate a herb_buff_meal (`did.eat:herb_buff_meal`) | ui:BagHex |
| 16 | tut_skill | 1 skill node with an SP cost learned (`did.skill`) | ui:MenuHex |
| 17 | tut_build | 1 placement (`did.build`); hint: straw_roll_kit | ui:BuildHex / MenuHex |
| 18 | tut_ferry | within 7 m of the dock arrival; `grant_home` | world:harbour |
Rewards per order: 15-60 XP and 0-3 T-stones (the json). No taming order.

`did` counts come from hooks that call `Tutorial.note` only while the tutorial runs:
`EatSession._finish` (eat, eat:<item>), `World.record_raid_kill` (kill, source is the Player),
`World.note_building` (build), `SkillState.unlock` with cost > 0 (skill).

## The island (`tutorial_isle.json`)
- kind `tutorial`, permanent, grassland, tier 15 (330 x 265 m landmass band), `level_override` 1,
  seed 9091, `size_m` 368; harbour hint (27, 79), camp hint (12, 44).
- Generated like any island (camp fire, workbench, shed, cargo chest, harbour). `Tutorial.dress`
  adds a stone fire pit 2 m W / 4.5 m S of the camp (`persist_building = false`), 3 HerbPlant
  (herb_leaf) and 3 BerrySprig (berries) 6-9 m from the camp.
- Creatures: 3 fixed compsognathus rows + gathering ring 2 compsognathus, 1 zebraceratops.
- HUD map title reads "Tutorial Island"; the atlas lists island time as "Permanent".

## Onboarding pointer (`game/scripts/ui/tutorial_pointer.gd`)
- Added over the HUD by `main.gd`. 5 Hz `Tutorial.pointer_target`; draws a pulsing gold ring
  and arrow on a HUD Control (`ui:<node name>`, `ctx:<id>` → the `Ctx_<id>` context hex or
  INTERACT when it carries that action) or an arrow over a world point (edge arrow off screen).
- Hidden while the bag, craft screen, a HUD sheet or character creation/pick is up.

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
