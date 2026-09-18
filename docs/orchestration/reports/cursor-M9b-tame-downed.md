# Cursor M9b — tame downed dinosaurs with preferred food

## What shipped

- `taming` block on every species JSON + `SCHEMA.md` docs; `CreatureDef` loads
  preferred/accepted food, `feeds_needed`, `window_seconds`, `requires_pen`.
  Defaults (`# ASSUMPTION:`): herbivores berry/herb_leaf (+fibre accepted);
  carnivores raw_meat (+fish/raptor_meat); `real_length_m` > 5 → 6 feeds and
  pen-only completion. Compsognathus set tameable for the field-tame lab and
  prefers berries.
- `game/scripts/pets/field_tame.gd`: knockdown window field tame. Preferred +1,
  accepted +0.5, each feed extends knockdown 6 s. Finish → `PetRecord`, stand,
  `alert`, `PetBrain` follow; bonded-cap full → `tamed_animal` bag item.
  Fail window → `enraged` (+20% move, 20 s) and 60 s tame cooldown.
- Plate tame row: food icon + `Tame N/M`, or `needs berry`, or `Tame in pen`.
- Player tap on downed tameable animal walks up and feeds (gather clip + ring,
  1.2 s) when the right food is in the bag; otherwise prints refusal.
- Corpse: 90 s lifetime, 20 s after emptied; prints
  `[world] corpse despawned <species>`. Not saved.
- Items: `raw_meat`, `fish`. Status `enraged.move_mult` 1.2.
- `capture_lab`: compsognathus field-tame demo + refusal + corpse despawn;
  lab key `K` knocks nearest compsognathus down.

## Acceptance evidence

- Screenshot: `docs/orchestration/reports/m9b-tame-downed.png` — downed
  Compsognathus plates show `Tame 0/3` with food icon.
- Headless `--lab=capture_lab` prints:
  - `[tame] compsognathus tamed grade=A feeds=3`
  - `[tame] refused: needs berry`
  - `[world] corpse despawned compsognathus`
- `./tools/smoke.sh --no-import` → `SMOKE PASS`.

## Assumptions

- Compsognathus preferred field food is berry (lab acceptance).
- Herbivore diet from archetype list matching `ai.json`.
- Corpses expire in-world only; nothing about corpses is saved.
- Big animals (`real_length_m` > 5) can be fed in the field only to buy
  knockdown time; completion still needs the pen.

## Notes for other agents

- Did **not** edit `island_runtime.gd`, terrain shaders, `iso_camera.gd`,
  `touch_controls.gd`, `hunt_hud.gd`, or `build_placer.gd`.
- No new InputMap verb / touch button: field tame uses existing `tap` + bag food.
- Did not edit `game/project.godot`, `game/shell/`, `tools/`, or `game/assets/`.
- Meshy credits spent: 0.
- Next: M9 / other milestones can rely on plates + field tame; pen path unchanged.
