# A bot survivor that plays the game, and what it found

Date: 2026-09-22. Agent: Claude Code. Classification: FABLE-CRITICAL (changes the gameplay loop).
North star: Durango: Wild Lands.

## The bot

`game/scripts/dev/bot_survivor.gd`, run with `--bot [--bot-minutes=N] [--bot-shots=DIR]` on the
real main scene (not a lab), from a fresh save.

It drives the same entry points a human drives: tap a harvest node, pick a hex on the gather
radial, craft through `StationCraft`, hunt through `Hunt`, run a context action. It never calls
a gameplay rule directly, so anything it cannot do is something a player cannot do either.

Given a recipe it resolves its own shopping list: it walks the recipe's category slots, picks a
concrete item per category, finds the nearest node that offers it, and if nothing on the island
carries that category it looks for a recipe whose output does and crafts that first. That is how
it discovers that lashing is not gathered but twisted from fibre into twine.

It pursues a ten-rung ladder (knife, club, axe, pick, fire, hunt, cook, net, tame, travel) and
reports each rung as OK or BLOCKED **with the reason**, plus a survey of what the island offers,
time by activity, a vitals timeline, distance walked, deaths and lowest HP. That report is the
debug output. With `--bot-shots` it writes a frame every 10 s so the run can be watched.

## What it found, and what changed

### 1. The game could not be finished from a clean save (fixed)

Every first tool needs a `blade_mat`. The only blade_mat on the home island is `stone`. Stone
required a **pick**. The pick recipe requires a blade_mat. A fresh survivor could never craft
anything. The bot hit this on its first tick: `nothing on this island yields blade_mat`.

Fixed in `harvest_node.gd`: loose stone is hand-pickable, like Durango's pebbles. A pick still
pays off through `ProgressionScaling.tool_power` (faster passes, richer yields) and still gates
ore and clay. After the fix the bot reaches a stone knife in **19 s** and a club in 33 s.

### 2. The starting island killed a new player in three seconds (fixed)

`data/islands/home_grassland.json` hand-placed a Utahraptor, Deinonychus, Velociraptor,
Stegosaurus and Coelophysis 34-40 m from camp, and four Compsognathus roamed the middle. Compy
attack was 18; four of them took an unarmed level-0 survivor from 100 HP to 0 in about three
seconds, and their bites cancelled every gather in progress.

Fixed: the private island keeps starter fauna only (Compsognathus, Protoceratops, Gallimimus,
plus the Zebraceratops herd). The apex species already spawn on the unstable islands' tables.
Compy attack 18 to 7, and the home spawn drops from three to two. After the fix: **0 deaths,
lowest HP 95** across a seven-minute run, and the hunt rung completes in 21 s instead of never.

### 3. There was no goal of any kind (fixed)

The HUD's "NOW" card drew two hardcoded strings, `"Settle and gather"` and
`"Survive, then return"`. It tracked nothing and completed never. `data/world/missions.json`
holds 19 mission templates and is never loaded by any script.

Added standing orders: `data/world/objectives.json` (12 ordered steps from "Gather 3 branches"
to "Sail for the unstable savannah") read by `scripts/core/objectives.gd`. Every condition is
evaluated against state the player can already see, so nothing else in the game has to report
progress. `World` ticks it twice a second, pays out pioneer XP and T-stones, and the HUD card now
shows `ORDERS 3/12`, the order, its hint, a `1 / 3` counter and a teal fill along the card edge.
Orders track a high-water mark, because materials get spent on the very craft the order asks for.

### 4. One object drew three labels (fixed)

A bonfire is in `placed_building`, `craft_station` and `bonfire`, and the HUD labelled every
group, so the camp showed three stacked "Bonfire" chips and two "Workbench". Labels are now
deduped by node, and at most two of any one kind are drawn, so a grove stops rendering a wall of
identical "Common Tree" chips. The focused node always wins.

## Still broken, not fixed here

- **Gathering intermittently soft-locks the survivor.** After picking a hex, the player gets a
  nav route (`nav_active` true), never moves, and the gather never starts: `dist=8.70` for
  fifteen straight samples. It reproduces on `tools/smoke.sh`'s sibling `--gather-test` at
  **HEAD without any of my changes**, so it is pre-existing and intermittent, probably the
  navigation mesh not being ready when the route is requested. This is the single biggest
  remaining loop bug and it is what the bot's "walked 6 m to a Bush and got none" lines are.
  It needs a stuck-route detector that falls back to direct steering.
- **Net capture is unreachable.** `skills/trees.json` uses `capture_technique_1`, the bridge in
  `SkillState` mirrors into `Data.survival_unlocked`, but `skills/survival.json` uses
  `capture_technique_I`. Zero id overlap, so `Data.has_capture_technique()` is permanently false
  and `CaptureSystem.attempt` always bails. Field taming (knockdown plus feeding) is the only
  working path. The same dead bridge means `Data.butchering_level()` is always 0, so every
  `"skill": 1` rare drop never drops.
- **No skill unlock does anything.** `SkillState.is_unlocked()` is called only from inside
  `skill_state.gd`. Recipes, buildings and island access check none of it. You can spend SP and
  nothing changes.
- **Knockdown is hard to reach.** The bot could not knock a Protoceratops down in 60 s of
  auto-attack, so the tame rung never completes. Taming needs a readable path from "fighting" to
  "knocked down".
- **The material ladder stops at bone.** Flint, obsidian, copper, bronze, iron and steel have
  items and a power table but no world source and no recipe.
- **The island reads empty.** Compared to the Durango references it is a flat green field with
  sparse props. That is art, not layout.

## Gates

`tools/test.sh` `[tests] PASS`; `tools/smoke.sh` `SMOKE PASS`; `ai_validation_lab` `[aival] PASS`;
`ui_family_lab` passes. `--gather-test` is intermittently red on this machine at HEAD as well as
with these changes, per the soft-lock above. Bot runs inspected headless and windowed, with
frames read at 1600x900.
