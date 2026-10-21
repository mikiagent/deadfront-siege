# ICONS2 final report (Claude, 2026-10-20; branch claude/mmo-icons2)

Per-id builders, what changed per flagged id and the earlier decisions are in
`docs/orchestration/reports/dsc-icons2.md`. This file is the close-out.

## What shipped
- 32 missing item renders and 33 redone flagged renders (`game/assets/icons/render/`), every item in
  `items.json` has art, `manifest.json` "missing" is empty. 19 "replace" marks cleared, 14 kept because
  `t_iconart.gd` pins them (their text says the art was redone).
- captured_animal: lashed wooden cage, slatted, a small generic green theropod inside. tamed_animal: the
  same cage with the door open, a hide collar on the animal and a spare collar and lead on the door.
- The 100 other renders are byte-identical to `tools/dsc/icons2_base.json`; the rig is unchanged.

## This run
- Merged `claude/mmo-overhaul` three times (45, 10 and 3 commits; docs and specs only, all clean).
  The branch is 0 commits behind at the head named below.
- **armor_scute re-renders byte-identically now.** Cause: Blender's Bevel modifier on its 12-gon
  prisms put out the same faces in a different order on each run and moved two vertices by ~1e-9
  (base meshes were identical; only the evaluated meshes differed). Cycles then flipped 1-3 pixels by
  1 LSB. Not seeds, dict order or time-based noise. Fix in `resources.py armor_scute`: no bevel on its
  prisms, the rim moved 0.01 in off the bone's back plane (no coplanar faces), and the `dome` deform
  removed (it never moved a vertex: the prism has only outline vertices). Three solo renders gave
  one sha (`a5451fa4...`); before the fix, five renders gave four different shas. It looks the same
  apart from harder plate edges.
- The 7 ids the earlier `--verify` never reached, and the other 58, were re-checked by the full
  gate's `--verify` of all 65 in one Blender process (lines below).
- **field_large_kit and field_small_kit differ now.** The contact sheet at slot size showed them as
  the same bundle (the renderer normalises size away). `_field_kit` takes the stake count and the
  pouch positions: large has a fan of 7 stakes and two pouches, small has 3 stakes and one pouch;
  the pouches rest on the planks (the small kit's pouch used to float beside the bundle). Both
  re-rendered, `--verify field_small_kit,field_large_kit` gave `REPRO PASS n=2`.
- Contact sheet `work/sheets/all.png` rebuilt: the 65 ids then 7 untouched neighbours (stone, bone,
  raptor_talon, flint, copper_ingot, rope, hide_strap). Looked at in six full-size crops (256 px per
  tile) and whole at 64 px (HUD slot) and 40 px: same light and palette as the neighbours, nothing
  clipped, no blank or black renders, every id reads at 64 px. Weakest left: the three arm pieces
  (forager_wraps, hide_bone_bracers, travel_sleeves, GLB renders of the armour kits) are thin
  diagonal slivers at 40-64 px, travel_sleeves dark on the dark slot; they are one arm each now, as
  their flag asked, and keep their replace mark (t_iconart pins them).

## The t_iconart.gd change (orchestrator grant)
One check in `_test_fallback`: "some unrendered item has a symbol to test the fallback with" cannot
hold once every item is rendered, which is this package's goal. It now prints
`[t_iconart] every item is rendered: symbol fallback has no subject, skipped` when no such item
exists and still runs the check when one does. The junk-id fallback checks above it still cover
the fallback path. 4 lines changed, nothing else in the test.

## Gates (lines seen)
GATES_PLACEHOLDER

## Squash merge: in-scope paths
- `game/assets/icons/render/` : the 65 PNGs, their 32 new `.png.import` files (base commits one per
  PNG) and `manifest.json`
- `tools/blender/items/camp.py`, `food.py`, `gear.py`, `resources.py`
- `tools/render_icons.py`
- `game/tests/t_iconart.gd` (granted)
- `docs/orchestration/reports/dsc-icons2.md`, `docs/orchestration/reports/claude-mmo-icons2.md`
- Optional, like `tools/dsc/verify_camp.sh` on base: `tools/dsc/verify_icons2.sh`, `tools/dsc/icons2_base.json`
- Leave out: `TASK.md` (repo root) and `work/` (contact sheets; the gate needs them on the branch only).

## Assumptions
None new in this run.
