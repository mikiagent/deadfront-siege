# Cursor milestone M9b — tame a downed dinosaur with its preferred food

The owner wants taming to happen in the field: knock a dinosaur down, feed it what it
likes, and it becomes yours. The M3 pen remains for big animals; this is the direct path.
Do this after M9a (plates, loot bodies, AI).

## Read first
- `game/scripts/creatures/creature.gd` (knockdown, `is_capturable`, `pet_record`), `pets/*`, `combat/status_effects.gd` (`knockdown`), `world/taming_pen.gd`, `player.gd::_pet_interact`, `bond_from_inventory`, `summon_pet`
- `docs/prd/durango-wild-lands-systems-prd.md` §11 (taming, grades), `game/data/creatures/*.json`, `game/data/items.json` (food items; M7 may not exist yet — use raw meat, fish, berry, herb_leaf, fibre_stalk that exist)
- Rules: no new autoloads, no `project.godot` or `game/shell/` edits.

## Tasks

1. **Preferred food per species.** Add `taming` to every creature JSON:
   `{"preferred_food": ["berry", "herb_leaf"], "accepted_food": ["fibre_stalk"], "feeds_needed": 3, "window_seconds": 45}`.
   Defaults when absent (`# ASSUMPTION:`): herbivores prefer `berry` and `herb_leaf`,
   carnivores prefer `raw_meat` (fish accepted); big animals (`real_length_m` > 5) need
   6 feeds and can only be tamed in a pen (existing flow). Document it in
   `game/data/creatures/SCHEMA.md`.

2. **Downed = tameable.** While a creature is in `knockdown` (existing status) and
   `def.tameable`, its plate (M9a) shows a **Tame** hint with the food icon and
   `1/3` progress. Tapping the creature with a preferred or accepted food in the bag
   walks the player next to it and feeds one unit (`gather` clip, 1.2 s, a ring like
   M8a's above the animal): preferred = +1 feed, accepted = +0.5, each feed extends the
   knockdown timer by 6 s. When feeds reach `feeds_needed` the animal is tamed:
   a `PetRecord` is made (grade from the existing capture roll), it stands up, plays
   `alert`, becomes `is_pet`, follows the player (`PetBrain`), and prints
   `[tame] compsognathus tamed grade=B feeds=3`. Without the right food the plate says
   `needs berry` and the tap does nothing (print `[tame] refused: needs berry`).
   Failing to finish inside the window: the animal gets up hostile with +20 % speed for
   20 s (`enraged`) and cannot be tamed again for 60 s.

3. **Bonded cap and pen hand-off.** Respect `Data.bonded_cap()`; when full, the tamed
   animal is put in the bag as `tamed_animal` (existing item) instead of following.
   Animals that need the pen show `Tame in pen` on the plate; tapping them with food
   still feeds (buys knockdown time) but does not tame.

4. **Corpses despawn.** Confirm M9a task 6: bodies and loot markers fade after 90 s
   (`# ASSUMPTION:`), sooner (20 s) once looted empty; nothing about corpses is saved.
   Print `[world] corpse despawned <species>`.

5. **Lab.** `capture_lab` headless: knock a compsognathus down with the lab key, feed it
   three berries, print the `[tame] … tamed` line, then a second one with no food
   prints the refusal, then a corpse despawn line. Windowed `--shot=` shows the Tame
   hint on a downed animal.

## Acceptance
- Screenshot `docs/orchestration/reports/m9b-tame-downed.png`.
- Headless `--lab=capture_lab` prints the tame, refusal and despawn lines; smoke passes.
- Report `docs/orchestration/reports/cursor-M9b-tame-downed.md`; commit as `M9b: tame downed dinosaurs with preferred food`.
- Do not edit `game/project.godot`, `game/shell/`, `tools/`, or anything under `game/assets/`.
