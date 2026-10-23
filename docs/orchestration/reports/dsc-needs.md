# NEEDS: eat, drink, wash, fill, sleep, dry off, feed a pet — end to end, desktop and phone

Branch `mmo-needs` (worktree `.claude/worktrees/mmo-needs`). Credits spent: 0.
Owner's ask: "we need to be able to eat, sleep, clean, drink, etc" — prove each action works for a player,
fix what does not. No balance numbers touched.

## What shipped

- **`game/tests/t_needs.gd` (new).** Every verb is called through the entry point the HUD or pet radial
  calls, from a state the game really reaches, and the effect is measured. 47 checks, `[t_needs] PASS`.
- **`game/scripts/dev/needs_lab.gd` + `game/scenes/dev/needs_lab.tscn` (new).** Drives each action by
  tapping its control on the live HUD, saves one screenshot per action, prints
  `[needs] RESULT eat_ok=… ui_min_px=…` from the effects, quits.
- **`Bonfire.dry_off()` + the `dry` context hex** (`world/bonfire.gd`, `player/player_input.gd`). PRD :285
  ("Bonfire: clears Wet") had **no code path at all**: nothing anywhere cleared Wet outside of its 120 s
  timer. The hex only appears at a fire while Wet; the verb re-checks 3.2 m.
- **`FoodInspector.show_stack` keeps the card on the canvas** (`ui/food_inspector.gd`). On 844x390 the card
  ran past the bottom edge and half of Close — the way out — was off-screen.
- **Bag action buttons 44 -> 64 px** (`ui/inventory_ui.gd::_action`, the Eat / Inspect / Feed row over the
  bag). Marked `# ASSUMPTION`: the PRD gives no height; 64 px is the project's floor.

## Before / after

| Action | How a player starts it (desktop = phone) | Before | After |
|---|---|---|---|
| Eat | Bag > tap food > Inspect > **Eat** (card); the bag row's **Eat** also works | worked; card off-canvas on the phone | Energy 20 -> 43 (skewer) / 20 -> 33 (raw meat), Full applied, card fully on screen |
| Raw risk | same; the card says RAW / POISONED | worked (seeded roll) | seed-verified: raw meat applies Stomachache, then Full |
| Drink | context hex **Drink** at fresh water | worked | Thirsty -> Quenched; no hex and no effect away from water |
| Wash | context hex **Wash** at fresh water | worked | Dirty and Very dirty -> Clean |
| Fill | context hex **Fill** with an empty bucket | worked | empty bucket -> water bucket, level kept (3) |
| Sleep | tap the tent -> **SLEEP** hex over it (context **Sleep** hex / E also work) | worked | fatigue 80 -> 0, tent 6 -> 5 sleeps |
| Dry off | context hex **Dry off** at a bonfire while Wet | **no control, no method** | Wet cleared, hex offered only while Wet |
| Feed pet | tap the pet -> **FEED** hex (bag's Feed button too) | worked | hunger 20 -> 100, meat consumed; a refused feed keeps the food |
| Persist | autosave / quit | — | statuses and pet hunger round-trip; Quenched keeps its 42 s |

Phone tap targets measured from the controls actually tapped: bag slot 64, card **Eat** 292x64,
context hexes 70, station and pet menu hexes 64 -> `ui_min_px=64` (gate needs >= 64 at 844x390).

## Verified

- `godot --headless --path game --script res://tests/t_needs.gd` -> `[t_needs] PASS`, no SCRIPT ERROR.
  Needs `--headless --import` once in a fresh worktree, else the global class cache is stale and
  `IslandRuntime.build` fails (island loads with 0 nodes).
- `needs_lab` at 1600x900 and 844x390, both:
  `[needs] RESULT eat_ok=1 drink_ok=1 wash_ok=1 fill_ok=1 sleep_ok=1 fire_dry_ok=1 feed_pet_ok=1 persist_ok=1 unreachable=0 ui_min_px=64`,
  11 PNGs each.
- Full gate `verify_job.sh needs` -> `VERIFY PASS` (t_needs, both lab resolutions, related tests, smoke,
  scope check).

## Shots looked at

`/tmp/needs_shots_phone/water_hexes` (FILL/WASH/DRINK hexes at the river), `sleep_tent_hex` (SLEEP hex over
the tent + a 6-use context hex), `pet_feed_hex` (RIDE/BAG/FEED over the raptor), `eat_food_card` (before:
Close clipped; after: fully on canvas), `fire_dry_hex` (DRY OFF + COOK at the fire), `eat_after` (Energy
100/100, skewer gone). Notes and verdicts in `.dsc/NOTES.md`; copies under `/tmp/needs_verify/shots_*`.

## Assumptions

- Bag action button height 64 px (PRD silent).
- `Bonfire.dry_off` reach 3.2 m — the same "in reach" the other station prompts use.
- The lab reads `InventoryUI._grid`/`_cells` and `HuntHud._ctx_hexes` to find the button it then taps; it
  taps the real Button, the shortcut is only for measuring its rect. Lab-only.
- No new meters; nothing renamed; no rate or number tuned.

## What the integrator needs

- The gate itself had a bug: `verify_job.sh`'s `LAB_ASSERT` was evaluated so a gerund-style
  `all(v[k]==1 for k in (...))` raised `NameError: name 'v'` (generator scopes cannot see eval globals), so
  **any** job using that assert failed stage 2 regardless of its numbers. I rewrote the assert in
  `scratchpad/dsc/job_needs.conf` as the equivalent conjunction of `v['x']==1` terms (original kept at
  `/tmp/job_needs.conf.orig`). The shared script should be fixed for the other jobs.
- `dry` is a new context-action id: the touch layer and any HUD layout that enumerates ids should know it.
  It sits in the bottom-right context row with Cook/Cauterise, so it inherits that layout at both
  resolutions (verified in the shots, no overlap).
- `FoodInspector` now sizes itself to the canvas; other panels placed with a fixed `maxi(80, …)` offset
  (most of them) may clip the same way on a 390 px-tall canvas — worth a sweep, out of this task's scope.
