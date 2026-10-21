# FORGEART: Blender forge and anvil

Branch `claude/mmo-forgeart` (from `claude/mmo-overhaul` 18ef7091, which has W2-DATA).

W2-DATA added the `forge_kit` and `anvil_kit` items (`place_as` forge / anvil) but no `props_manifest.json`
rows. A placed forge or anvil fell back to `PropVisuals._fallback_mesh`, a flat-coloured box. The grid also
placed the forge as 1x1, because `BuildGrid.footprint` reads the manifest row and the kit says 2x2.

Both stations now have hand-built GLBs from the merged structure kit. Their manifest rows make the game
use them by data, with no code change and no hooks.

## What shipped

| path | what |
|---|---|
| `tools/blender/structures/structures.py` | `forge()` and `anvil()` builders, registered in `BUILDERS`. Small shared helpers next to them: `_loft` skins a stack of rings into a closed mesh (tapered hood, chimney, pleated bellows, anvil body), plus `_rect`, `_yz_rect` and `_paddle`. No existing builder or `lib.py` changed |
| `game/assets/props/blender/forge.glb` (+ `.import`) | 1528 tris, AABB 1.98 x 2.77 x 1.38 m (Godot x, y, z), one material `structures_atlas`, no image |
| `game/assets/props/blender/anvil.glb` (+ `.import`) | 476 tris, AABB 0.86 x 0.84 x 0.71 m |
| `tools/blender/structures/check_manifest.py` | `KIND_GLB` forge/anvil, `NEW_ROWS` footprints 2x2 / 1x1 (from items.json), notes |
| `game/data/props_manifest.json` | two new rows written by `check_manifest.py --write` (`glb`, `aabb_m`, `footprint`, `art_status` REVIEW, `upgrade`, `note`). Nothing else in the file changed (`git diff` shows +30 lines, all in these two rows) |
| `game/tests/t_forgeart.gd` | regression test (below) |

**Forge (2x2).**
- Hearth: a round fieldstone hearth (cobble drum, a footing of heavy stones, an uneven ring of rim
  stones) at 0.74 m working height.
- Ember bed: a broad disc with the `ember` tile on top, glowing coals and charcoal lumps around its edge,
  and an iron bar heating in it with its glowing end in the coals. The middle of the bed is left open to
  the iso camera.
- Hood and chimney: two cheek pillars and a back wall carry a tapered, smoke-dark stone hood. Its lower
  edge is at 1.38 m with a soot lip. A coursed chimney rises to 2.75 m with a slab cap.
- Bellows: on a two-trestle stand on the +X side, the side the camera sees. Two dark pear-shaped boards
  are hinged at the nozzle end, with pleated tan hide between them. An iron nozzle feeds the hearth, and
  a handle and a rocker lever on a post pull a rope.
- Fuel and tools: a charcoal heap and split logs behind, and tongs leaning on the hearth front.

**Anvil (1x1).**
- A London-pattern anvil (flared foot, waist, face with a hardy hole, horn towards +X, heel) on a bark
  stump with root flares and a scorched top ring.
- The face is at 0.79 m, about the survivor's knuckle height.
- A cross-peen hammer lies on the face with its handle out over the camera side. Tongs lean on the
  stump, and a quench bucket with water and iron hoops stands at the front left.

**Design line.** `docs/design/world-design.md:171` lists "Clay furnace / forge | clay 8 + stone 6 + wood 4 |
Smelts ores and makes metal parts; fuel is consumed." and `:172` "Anvil bench | metal 3 + wood 4". The
Durango reference (`docs/reference/durango-camp-workstations.webp`) shows a stacked-fieldstone furnace with
the fire glowing at the front. The forge is fieldstone with the fire on top of the hearth instead of inside a
dome, so the embers face the iso camera and are not shaded.

## Byte-identical check

Before building, I hashed the 43 existing GLBs, `structures_atlas.png` and `structures_atlas.tres`
(`shasum`, 44 files). After the final build and the re-import, `shasum -c` reported every file as `OK`. Nothing
under `game/assets/props/blender/` other than the four new files shows in `git status`. `build.py -- forge anvil`
builds only the two new pieces. It repaints the atlas, but the result has the same bytes as the committed atlas.

## Test that fails on the old behaviour

`game/tests/t_forgeart.gd` checks five things:
- every item with `place_as` resolves through `PropVisuals.model_path` to an existing model, so no placeable
  kit falls back to the box;
- `CraftStation.make(forge|anvil)` attaches `Prop`, the Blender GLB from the row, and no `FallbackMesh`;
- the footprint equals the kit's footprint;
- the height is in range for the 1.78 m survivor (`data/characters/survivor.json` `height_meters`): the forge
  between 1.2x and 1.8x her height, the anvil between 0.4x and 0.55x;
- the camera-projected area of `ember`-tile faces on the forge is at least 0.12 m².

With the base manifest (18ef7091) swapped in, the test fails:
```
[t_forgeart] FAIL forge_kit (place_as forge) resolves to no model and places as the fallback box
[t_forgeart] FAIL anvil_kit (place_as anvil) resolves to no model and places as the fallback box
[t_forgeart] FAIL forge placed without its model (FallbackMesh box)
[t_forgeart] FAIL forge footprint (1, 1), kit says (2, 2)
[t_forgeart] FAIL forge is 0.00 m tall, want 2.14-3.20 m next to the 1.78 m survivor
[t_forgeart] FAIL anvil placed without its model (FallbackMesh box)
```
On the branch:
```
[t_forgeart] 26 placeable kits checked
[t_forgeart] forge model forge.glb footprint (2, 2) height 2.77 m (survivor 1.78 m)
[t_forgeart] anvil model anvil.glb footprint (1, 1) height 0.84 m (survivor 1.78 m)
[t_forgeart] forge ember bed faces the camera: 0.22 m2 (min 0.12)
[t_forgeart] PASS
```

## Gates (package tree, after `--import`)

- `python3 tools/blender/structures/check_manifest.py`: `[check_manifest] PASS 43 kinds resolve to existing GLBs (43 Blender (4 of them stand-ins marked REPLACE), 0 Kenney marked REPLACE)`
- Every `game/tests/t_*.gd` (22) exits 0 with a PASS line. 0 SCRIPT ERROR, except t_save's 5 deliberate ones,
  as on the base. Among them: `[t_structart] PASS`, `[t_build] PASS`, `[t_forgeart] PASS`,
  `[t_data] PASS items=223 recipes=155`.
- `--script res://tests/run_all.gd`: `[tests] PASS`
- `tools/smoke.sh --no-import`: `SMOKE PASS`
- `--lab=build_lab` headless: `[build] PASS`, 0 SCRIPT ERROR
- 0 "couldn't resolve track" in any gate log. No new `~/Library/Logs/DiagnosticReports/Godot-*.ips`: the
  newest is still `Godot-2026-10-20-202004.ips`, from before this run.

## Shots (looked at)

Scratch script (not in the repo): `<scratchpad>/forge/forge_shot.gd`. It boots the real build_lab windowed,
gives the player a forge_kit and an anvil_kit, and places both through `BuildPlacer.confirm`. It does not
swap any visual: the rows alone pick the models. The survivor stands beside the anvil, and the shot is saved.
In every run the log shows `forge prop=true fallback=false` and `anvil prop=true fallback=false`, with 0 SCRIPT ERROR.

- `forward_plus_844_v2.png` and `gl_compatibility_844_v2.png` (844x390, camera size 6). In both renderers:
  - the forge reads as a stone forge, with the chimney well above the survivor's head;
  - the hearth top is at her hip;
  - the orange ember bed shows on top of the hearth, above the dirt disc;
  - the bellows sits on its trestle beside the forge;
  - the anvil on its stump, with the hammer and the blue quench water, stands at her side, its face below
    her waist.
- `compat_1600_z6_v2.png` and `compat_1600_z12_v2.png` (1600x900, gl_compatibility; z12 is near play zoom). The
  forge and the anvil both read at play distance. The ember bed reads as fire.

Things I saw that are not this package's: the HUD's world labels float about 1 m above their objects, so
"Anvil" sits by the bellows and "Bonfire" by the anvil. The orders panel covers the top of the 844x390 frame.

## Assumptions

- ASSUMPTION: the forge is a stone hearth with a hood, not the Durango clay dome. The task says "stone
  forge", and an open hearth keeps the ember bed in sun and in view.
- ASSUMPTION: the embers do not glow at night. The shared atlas material has no emission, and a forge light
  needs a code change in `CraftStation`, which is outside this data-only package. See next steps.
- ASSUMPTION: the forge's footprint changes from 1x1 (no row) to 2x2 (the kit). This is not a save-format
  change: the row is new data, saves store cell and rotation only, and forges have existed only since today's
  W2-DATA merge.

## Gotcha for whoever rebuilds

`godot_import_settings.py` rewrites the `.import` files with the atlas remap. But a GLB that Godot already
imported once, before that rewrite, is not re-imported by a later `--import`, so it keeps its embedded
`StandardMaterial3D`. t_structart caught this here:
`forge: materials [...StandardMaterial3D...], want only structures_atlas.tres`. I deleted
`.godot/imported/forge.glb-*` and `anvil.glb-*` and imported again. The committed `.import` files carry the
remap, so a fresh tree imports correctly the first time.

## Hooks, credits

- Hooks patch: none. No integrator-only file and no other package's file is touched.
- Credits: 0. No Meshy or Tripo, only Blender headless.

## Next

- Night glow: an OmniLight (warm, small range) on placed forges in `CraftStation._ready`. That is a code
  change in `game/scripts/world/craft_station.gd`, so it needs a hooks patch or W2-PROCESS (fuel state) to own it.
- Possible fuel states (unlit, lit) as `stages`, like the drying rack, if W2-PROCESS adds forge fuel.

## Sync 1 before integration (2026-10-20)

- Merged `claude/mmo-overhaul` e5f3ec8a (W2-SKILLS and spec 19-22 docs) as 2b381c11. No conflicts. The base
  touched no file under `game/assets/`, `tools/blender/` or `props_manifest.json`, so both GLBs, the atlas and
  every existing GLB are unchanged. Still no hooks patch.
- Gates in a scratch tree at 2b381c11, after `--import`: all 22 `t_*.gd` print PASS (`[t_forgeart] PASS`,
  `[t_structart] PASS`, `[t_w2_skills] PASS`, `[t_data] PASS items=223 recipes=155`). t_save has its 5
  deliberate SCRIPT ERRORs and no others. `run_all.gd` prints `[tests] PASS`, `tools/smoke.sh --no-import` prints `SMOKE PASS`,
  `--lab=build_lab` headless prints `[build] PASS` with 0 SCRIPT ERROR. `check_manifest.py` PASS, 43 kinds.
  0 "couldn't resolve track", and no new `Godot-*.ips`.
