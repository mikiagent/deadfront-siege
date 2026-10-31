# RETIREPROTO — protoceratops removed (claude/mmo-retireproto)

Owner, 2026-10-31: "protoceratops needs to be removed, the animations suck and the model is unappealing".

## Removed

- `game/assets/creatures/protoceratops/` (model, 16 clips, saddle, textures, rig manifest, mount.json). Git history keeps them.
- `game/assets/creatures/zebraceratops/work/audit_protoceratops.py` and its output JSON (they read the deleted model).
- Spawn rows: the `gathering` rows of `temperate_35` and `temperate_45` (`world/islands.json`). Their fallback put
  4 deinonychus / 4 stegosaurus at the landing; those two gathering rings are now empty.
- Wiki: the protoceratops sheet card (`boards.js`) and its `redo-animations` model-mark seed (`docs_wiki.py`).
- `creature_view.gd`'s protoceratops fallback colour.

## Kept

- `game/data/creatures/protoceratops.json`, marked `"retired"` with `"retired_to": "zebraceratops"`. Butchering,
  ragdoll, anim events, the skill text "capture tier I species (Coelophysis, Protoceratops)", the task CSVs and old
  saves still name it. With no GLB, `CreatureDef.has_model` is false, so NOBOXES never spawns it.
- The other spawn rows fall through (`CreatureDef.eligible`): home_grassland fixed spot -> gallimimus,
  savannah_15 / tropical_25 working -> coelophysis, temperate_20 (gathering, crater) and temperate_25 gathering -> compsognathus.
  The tutorial never named it.
- `butchering.json` / data sheets rows, `t_butcher` and `t_boneparts` (data-level checks, still valid).

## Old saves

`CreatureDef.retired_to` (new, from the JSON). `PetRecord.from_dict` loads a saved protoceratops as a zebraceratops
(same pack_mule archetype, bag + mount, capture tier I, small saddle); uid, level, genetics, nature, bag and saddle
carry over, the variant is cleared, stats follow the zebraceratops. `PetRecord.from_def` does the same, so a pen
occupant or captured protoceratops tames as a zebraceratops. `SaveGame` shows a notice: "A species was removed from
the game: Protoceratops is now a Zebraceratops (bag and saddle kept)". New check `t_save._test_retired_species`.

## Tests and labs

Tests that used the protoceratops as a handy species now use the zebraceratops (t_creaturechips, t_movepriority,
t_natures, t_petradial, t_player, t_playerturn, t_targetui, t_colors); t_canim drops it from strides and
KNOWN_GLIDERS. Dev labs: zebraceratops, except ai_validation_lab (home spot -> gallimimus), wild_ai_sweep_lab
(temperate_25 gathering -> compsognathus), ragdoll_lab (dropped). `maps/sample.map.json` and map_lab spawn marker -> gallimimus.

## Docs

fight-lab.md verdict "removed by owner 2026-10-31"; species-art.md note; biome-spawns.md regenerated with
`gen_spawns` only (status column now says "retired: spawns fall through to X"; the page was also stale on other
species); Open Questions RP1-RP3.

## Credits

None.

## Next agent

- t_colors fails on canon too (unchanged by this package): it expects the stegosaurus to draw placeholder boxes, which NOBOXES forbids.
- A herbivore herd for the temperate_35 / temperate_45 gathering rings, and the skill node text naming
  Protoceratops, are design calls (RP1, RP3).
