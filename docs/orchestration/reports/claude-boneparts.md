# Claude — BONEPARTS: species bone parts with their own names and icons

Owner, 2026-10-28: "improve the symbols for different bone types. The shrimp-like skeleton symbols have to go,
replace them with symbols of what it would actually look like."

Contact sheet (old symbol → new icon, names, species): `docs/orchestration/reports/boneparts/contact_sheet.png`.

## What shipped

**Parts per species** (bone-type rows in `game/data/butchering.json`; counts, skill rows and attributes unchanged):

| Part (id) | Name | Shape | Species |
|---|---|---|---|
| `raptor_talon` | Sickle Claw | hooked, blade-thin dark claw on a toe bone | velociraptor, deinonychus, utahraptor (rare) |
| `raptor_bone` | Raptor Leg Bone | slim bent leg bone | velociraptor, deinonychus, utahraptor |
| `hollow_bone` (new) | Hollow Bone | snapped thin shin bone, open hollow end | compsognathus, coelophysis, gallimimus, dilophosaurus |
| `bone` | Leg Bone | ivory limb bone | megaloceros, smilodon |
| `stout_leg_bone` (new) | Stout Leg Bone | short bone with flared ends | protoceratops, zebraceratops (base + the rare frill row) |
| `large_leg_bone` (new) | Large Leg Bone | massive pitted tan thighbone | stegosaurus, styracosaurus, triceratops, ankylosaurus, allosaurus, brachiosaurus, tarbosaurus, tyrannosaurus |
| `dense_bone` | Dense Bone | chunky knobbed bone | tyrannosaurus, tarbosaurus, brachiosaurus, protoceratops |
| `brow_horn` (new) | Brow Horn | curved keratin horn on a horn-core base | triceratops, styracosaurus, zebraceratops |
| `tail_spike` (new) | Tail Spike | thagomizer pair on a knobbed base | stegosaurus |
| `tail_club` (new) | Tail Club | two-lobed pitted club on vertebrae | ankylosaurus |
| `dorsal_plate` (new) | Dorsal Plate | tall thin plate, vessel grooves, rust rim | stegosaurus |
| `frill_plate` (new) | Frill Plate | frill fan with epoccipital knobs | triceratops, styracosaurus, protoceratops, zebraceratops |
| `skull_plate` (new) | Skull Plate | rugose skull slab with an eye socket | tyrannosaurus, tarbosaurus |
| `armor_scute` | Osteoderm | keeled bone scutes (unchanged render) | ankylosaurus, brachiosaurus |

**Old ids kept, no alias needed.** The five old ids still exist (renamed only), so saves, market rows and
recipes that hold them load unchanged; no save format change and no loader code. Each new part is a copy of the
generic id it replaces: same categories (so every bone / dense_bone / talon / scute / tier_bone recipe slot still
accepts it), stack, rarity, level, default attributes, same Butchering node gate (added to the same `trees.json`
effect lists), same deposit cap (`limits.json`, by the category rule). The skewer handle `allowed_ids` also take the
three new leg bones, as they took `bone`/`raptor_bone`.

**Icons.** Nine new Blender builders and a redone sickle claw in `tools/blender/items/resources.py`, rendered with
`tools/render_icons.py` (same rig, deterministic: `REPRO PASS n=4` on a sample), `.png.import` set to the project
settings. `game/data/icons_manifest.json` now points all 14 parts at their renders, so the butcher picker, corpse
bag sprite and top feed no longer show the skeleton glyph (`sym/raptor_bone.png`; `dense_bone`/`armor_scute`
aliased to it before). The sym PNGs are left on disk, unused by these items.

Docs: `docs/current/items-traits.md`, `world-biomes.md` and `game/data_sheets/items.csv`, `butchering.csv`
updated with only the generator's delta for this change (a full regeneration would have dropped hand-written
sections and re-added rows the recipes sheet does not have, so I applied the HEAD→new generator diff).

## Tests

New `game/tests/t_boneparts.gd` PASS (species → parts table, specific names, old ids load, every bone-category
recipe slot has a part, same categories and gate as the replaced id, every part has its render and no glyph).
`t_data`, `t_butcher`, `t_gather`, `t_craftfeel`, `t_iconart`, `t_save`, `t_invscreens` PASS; `run_all` `[tests] PASS`;
`tools/smoke.sh --no-import` SMOKE PASS. `t_butcher` / `t_gather` had their triceratops / protoceratops ids and the
"Raptor Talon" notice name updated to the new data (no logic change).

## Assumptions (PRDs are silent)

- `# ASSUMPTION:` part set and names are mine, built from spec 34's raw materials (Leg Bone, Large Leg Bone, Horn)
  and the owner's examples; parts are per family, not one per species.
- Brachiosaurus keeps Osteoderm and Dense Bone (real brachiosaurs had no osteoderms; kept so its drops did not change).
- Protoceratops keeps Dense Bone (no real horns); megaloceros/smilodon keep the generic Leg Bone (no antler/fang item
  was added: that would be a new drop).
- Allosaurus/T. rex get no talon: they never had a talon row and adding one would be a balance change.

## Not touched

Butcher UI and yield logic (claude/mmo-lootradial owns those). Credits spent: none (Blender only).
Merge note: lootradial edits `t_butcher.gd`; my edits there are id swaps in the protoceratops/triceratops checks.
