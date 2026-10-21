# CAGEICON report (Claude, 2026-10-20; branch claude/mmo-cageicon, stacked on claude/mmo-icons2)

Owner: "the cage icon should look like there's a dino inside".

## What shipped
- `captured_animal` re-rendered: the shut, lashed wooden cage now holds the project's own
  deinonychus mesh (`game/assets/creatures/deinonychus/deinonychus.glb`), not the procedural green lump.
  - Pose: frame 5 of its own `attack_heavy` clip (the crouched wind-up before the leap: body and hips
    lowered, feet planted), then bone turns on top: chest raised (Torso, Shoulders), head levelled and
    scaled 1.75x so it reads at 48 px, tail curled round the right side with a smaller fan (the
    forked tail fan read as a fish tail or leaf at full size).
  - The head is pushed out between two front bars just under the top rail, eye toward the viewer.
    The front bars cross the chest and legs, and the tail tip comes out between the right side bars.
  - The skin texture's saturation is raised (x1.5) and its value (x1.25), so the lime animal stands
    off the wood in value, not just in hue.
  - The shut cage is lower (H 0.75 vs 0.92), with fewer and thicker bars (front 4 at r 0.055, no
    extra near bars; back 5, sides 3) and darker wood (#7a5232 family vs #9a6a3a). Seven thin front
    bars turned into stripe noise at 48 px and cut the animal into pieces.
  - It is turned lower than the other cages (`turn(-4, "X")` vs `turn(30, "X")`), so the face and the
    bars in front of the body fill the tile, not the open roof. Same rig, lights, camera rule and post.
- `tamed_animal`: not changed (byte-identical, sha `bcbc6bd6...`). The pair reads apart at 48 px:
  tame = light wood, door swung open as a ladder panel at the left, dark green animal with a collar
  above the cage; captured = shut darker box, lime raptor behind the bars.
- Code (`tools/blender/items/camp.py`): `_cage` takes `wood`, `H`, bar counts `n` and radii `r`. Its
  defaults are the old literals, so tamed renders the same bytes. The new helpers are `_import`
  (glTF import, drops the stray 2 m Icosphere the rigged GLBs carry), `_creature` (base mesh + one
  clip frame copied as plain pose values + bone turns/scales), `_bend` and `_vivid`.
- `manifest.json`: only the captured_animal entry changed (sha256, bytes 51398 -> 63604, rect
  [22,19,212,218]). The `.png.import` files did not change (the import step rewrote neither).

## Renders (looked at)
- Full size: `game/assets/icons/render/captured_animal.png` (63,604 bytes; budget 65,536).
- Contact sheet (256 / 64 / 48 px, plus 48 px at 4x nearest): old captured, new captured, tamed,
  makeshift_taming_pen, carnivore_feed, herbivore_feed, rope_snare:
  `/private/tmp/claude-501/-Users-milankinzy-Documents-deadfront-siege/72cebc8b-d241-430b-9ea6-94d65339bfef/scratchpad/cageicon/final/contact_sheet.png`
- 48 px: `.../cageicon/final/new_captured_animal_new_48.png`, `.../cageicon/final/old_captured_animal_old_48.png`
  (64 px beside them).
- What I saw: at 256 and 64 px it is clearly a raptor in a cage (snout, eye, pale throat, claws, tail).
  At 48 px the lime head wedge at top left and the body behind dark bars read as an animal in a cage.
  The eye is a 1 px dot at that size, so the dinosaur read comes from the head shape and the upright
  body. Same light and palette as the neighbours; nothing clipped.

## Gates (lines seen; run on the final camp.py, the report is the only later change)
- `Blender -b --factory-startup -P tools/render_icons.py -- --only captured_animal`: `ICON captured_animal 63604 46054d5cd94aa1cb`, `ICONS DONE n=1 over_64kb=0`
- `... -- --verify captured_animal,tamed_animal` (run twice, the second on the final code):
  `REPRO captured_animal identical`, `REPRO tamed_animal identical`, `REPRO PASS n=2`
- `... -- --selftest`: `SELFTEST PASS`
- Godot through gslot.sh: `--import` rc 0 (reimported captured_animal.png); `tests/t_iconart.gd`: `[t_iconart] PASS`;
  `tests/run_all.gd`: `[tests] PASS`; `tools/smoke.sh --no-import` under gslot: `SMOKE PASS`.

## Not done / for the next agent
- The tamed cage still holds the procedural dino. Beside the real deinonychus it looks cruder, but it
  reads and the task said to change it only if the pair did not read apart. `_creature` would do it
  in a few lines (e.g. the same mesh standing, collar as a kit cylinder at the Neck bone).
- The manifest stamps captured_animal `procedural_v1` because its builder is a procedural script;
  `render_icons.py` has no tier for a builder that composes a GLB. Unchanged.
- At 63.6 KB the PNG is close to the 64 KB cap (basket_kit is at 65.3 KB). A future change that adds
  texture detail could trip it; `render_one` then refuses to write the file and says so.
- No in-game screenshot: checked on the contact sheet only.
- The shared scratchpad's `trees/` (114 GB, other agents) had the disk at 100 % mid-run (one ENOSPC);
  I left it alone.

## Merge
Stacked on ICONS2: merge `claude/mmo-icons2` first, then this branch. In scope: `tools/blender/items/camp.py`,
`game/assets/icons/render/captured_animal.png`, `game/assets/icons/render/manifest.json`, this report.

## Credits
None (no Meshy, Tripo or generation calls; the mesh is already in the repo).

## Assumptions
- `# ASSUMPTION:` in `captured_animal`: the item names no species, so the deinonychus is drawn
  (green against the wood, a raptor head that reads as a dinosaur). The head is enlarged 1.75x as icon
  styling; no lore or mechanics added.
