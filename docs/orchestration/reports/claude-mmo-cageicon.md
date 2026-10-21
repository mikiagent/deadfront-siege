# CAGEICON report (Claude, 2026-10-20; branch claude/mmo-cageicon, stacked on claude/mmo-icons2)

Owner: "the cage icon should look like there's a dino inside".

## What shipped (round 1; the art is superseded by "Fix round 1" below)
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

## Renders (round 1)
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

## Gates (round 1)
- `Blender -b --factory-startup -P tools/render_icons.py -- --only captured_animal`: `ICON captured_animal 63604 46054d5cd94aa1cb`, `ICONS DONE n=1 over_64kb=0`
- `... -- --verify captured_animal,tamed_animal` (run twice, the second on the final code):
  `REPRO captured_animal identical`, `REPRO tamed_animal identical`, `REPRO PASS n=2`
- `... -- --selftest`: `SELFTEST PASS`
- Godot through gslot.sh: `--import` rc 0 (reimported captured_animal.png); `tests/t_iconart.gd`: `[t_iconart] PASS`;
  `tests/run_all.gd`: `[tests] PASS`; `tools/smoke.sh --no-import` under gslot: `SMOKE PASS`.

## Not done / for the next agent
- (Round 1; fixed in fix round 1) The tamed cage still held the procedural dino. Beside the real deinonychus it looks cruder, but it
  reads and the task said to change it only if the pair did not read apart. `_creature` would do it
  in a few lines (e.g. the same mesh standing, collar as a kit cylinder at the Neck bone).
- The manifest stamps captured_animal `procedural_v1` because its builder is a procedural script;
  `render_icons.py` has no tier for a builder that composes a GLB. Unchanged.
- At 63.6 KB the PNG is close to the 64 KB cap (basket_kit is at 65.3 KB). A future change that adds
  texture detail could trip it; `render_one` then refuses to write the file and says so.
- No in-game screenshot: checked on the contact sheet only.
- The shared scratchpad's `trees/` (114 GB, other agents) had the disk at 100 % mid-run (one ENOSPC);
  I left it alone.

## Fix round 1 (blind judges on round 1)
Judges on round 1 at 48 px: captured was "a cage with something green inside, a plant or leafy food".
They found no dinosaur outline. Tamed read as "an open crate with a box of greens". Its walls looked
solid and its door read as a ladder.

What changed (commit 7e2d747b):
- `captured_animal`: the deinonychus is now side on (facing left), reared up behind the shut cage's
  front bars (its own `attack_heavy` crouch frame with the chest and neck raised). Its head is enlarged
  (1.8 x 2.4 x 1.8, longer in the snout) and has a big amber eye with a black pupil (`_eyes`, on the
  Head bone). The head sits over the top rail, so the snout breaks the cage outline at the top left.
  The tail runs out through the right side bars with its forked fan shrunk. The cage has 4 thin front
  bars (r 0.035, was 0.055) and a dark plank back wall (`_cage(back=...)`). The lime animal stands
  off a dark backdrop, and the face has no bars across it. The camera is turned so the front bars face
  the viewer.
- `tamed_animal`: the procedural lump is gone (`_small_dino` deleted). The same deinonychus stands
  outside its empty light-wood cage. The door is swung in against the side wall, so no ladder-like
  panel shows. It wears a red hide collar on the Neck bone (`_collar`) with a bone tag, and a slack
  hide lead with a hand loop lies on the ground. The cage keeps bars on the sides and back, so it
  reads as a cage and not a crate.
- At 48 px the pair is told apart by layout, not colour: captured = dino behind bars, head over a
  closed box; tamed = whole dino in front of an open box, red collar dot, light wood.
- `_creature` takes a per-axis bone scale `(x, y, z)`. `_vivid` is unchanged.

Renders (looked at): full size, and 64 / 48 px area-averaged on the slot ink colour next to the old
captured, round 1 captured, old tamed, makeshift_taming_pen, capture_net_i, herbivore_feed and rope_snare:
`/private/tmp/claude-501/-Users-milankinzy-Documents-deadfront-siege/72cebc8b-d241-430b-9ea6-94d65339bfef/scratchpad/cageicon/final2/contact_sheet.png`. The 48 px tiles at 6x nearest: `/private/tmp/claude-501/-Users-milankinzy-Documents-deadfront-siege/72cebc8b-d241-430b-9ea6-94d65339bfef/scratchpad/cageicon/final2/up48.png`.
- What I saw at 48 px: captured shows a green raptor head with a yellow eye over a dark-wood cage at
  the top left, the body behind the bars and the tail out to the right. Tamed shows a green raptor
  standing to the left of a light open cage, legs and tail visible, with a red collar dot and a dark
  lead line. At full size the tag and lead loop are visible. Both stay under the 64 KB cap.
- I did not run another blind judge myself; the reading above is mine.

Gates (fix round 1, final code):
- `Blender -b --factory-startup -P tools/render_icons.py -- --only captured_animal,tamed_animal`:
  `ICON captured_animal 58362 800bb7eb282c55a3`, `ICON tamed_animal 53464 1ef777c2faabc8b7`, `ICONS DONE n=2 over_64kb=0`
- `... -- --verify captured_animal,tamed_animal` (re-run after the last docstring edit): `REPRO captured_animal identical`,
  `REPRO tamed_animal identical`, `REPRO PASS n=2`; `... -- --selftest`: `SELFTEST PASS`
- Godot through gslot.sh: `--import` rc 0 (reimported both PNGs, `.png.import` files unchanged);
  `tests/t_iconart.gd`: `[t_iconart] PASS`; `tests/run_all.gd`: `[tests] PASS`; `tools/smoke.sh --no-import`: `SMOKE PASS`.
- `manifest.json`: only the captured_animal and tamed_animal entries changed (sha256, bytes, rect).

Assumptions added: `# ASSUMPTION:` in `tamed_animal`: the same species as captured, so the pair reads as one
animal before and after taming. The eye placement in `_eyes` is the deinonychus eye; another species needs its own point.

## Fix round 2 (orchestrator direction after round 2)
Direction: round 2's captured dino had its head and neck over the top rail and its tail out, so it read as
climbing out. Round 2's tamed dino stood outside its cage on a lead, which broke the owner's 2026-10-19 rule
that a traded or captured animal is shown in a cage. Both animals now sit inside. The two items differ by
cage, not by where the animal is.

What changed (`tools/blender/items/camp.py`):
- `captured_animal`: the deinonychus crouches side on, wholly inside the shut dark-wood cage. Its head
  (enlarged, amber eye) is below the rim and points at the left front bars. The tail curls inside the
  cage; only its thin tip shows past the right end. Three thin front bars (r 0.035) cross the body: one
  at the neck, one over the torso and thigh, one at the tail base. A dark plank back wall gives value
  contrast. The roof is open, with frame beams only. Wild: rope lashed corner to corner in an X across the
  right end, plus rope ties at the door's free end. `_cage` takes `W`/`D` and a flat back colour; the old
  hinged-door and roof-hatch code is gone.
- `tamed_animal`: the same deinonychus is inside a new `_carrier`, a pet carrier like Durango's. It has
  light planed boards with no bump, a solid roof with a leather carry handle, a closed door with two
  stout bars (r 0.05), iron hinges, a latch and a dark back board. It wears a thick red hide collar
  (`_collar(t=0.03)`), and a cream tag hangs on a red cord under the roof. The camera is tilted (`turn(-20, "X")`)
  and the item rolled back (`lean(5)`) so the posts stand upright. The lead and the open door are gone, because the
  binding direction replaces "door open, collar and lead".
- PNG budget: the 2-bar carrier came out at 65,887 bytes, over the 64 KB cap. `render_one` refuses to write
  a PNG over the cap. Dropping the board bump saved 40 bytes. Thicker bars (0.035 to 0.05) brought it to
  65,347 bytes. The cap is 65,536, so 189 bytes are left. A flat back board, softer `_vivid` or a smaller
  dino did not get under the cap, or cost more.

Renders (looked at full size, 3x, and 64 / 48 px area-averaged on the slot ink colour, next to the
neighbours). The sheet runs left to right: ICONS2 original captured, round 2 captured, new captured, new tamed,
round 2 tamed, ICONS2 original tamed, makeshift_taming_pen, capture_net_i, herbivore_feed, rope_snare.
- Contact sheet: `/private/tmp/claude-501/-Users-milankinzy-Documents-deadfront-siege/72cebc8b-d241-430b-9ea6-94d65339bfef/scratchpad/cageicon/final4/contact_sheet.png`
- The 48 px tiles at 6x nearest (new captured, new tamed, old, round 2, round 2 tamed, pen, net):
  `.../cageicon/final4/up48.png`; single 48 px files: `.../final4/new_captured_animal_new_48.png`,
  `.../final4/tamednew_tamed_animal_new_48.png`, `.../final4/old_captured_animal_old_48.png`.
- What I saw at 48 px:
  - Captured: a dark-brown open crate with a lime raptor inside it in profile. The long snout points
    left, a yellow eye dot shows, and the body and legs sit behind the vertical bars. The light X of rope
    is on the right end. Nothing breaks the top rim.
  - Tamed: a cream box with a brown handle on top. The green animal is behind two bars, with a red
    collar dot at its neck and a white tag top right. The dark hinges and latch show on the sides.
  - The pair is told apart at 48 px by value and silhouette: a dark open crate against a light handled carrier.
    Both read as a cage with the animal inside.
  - At 48 px the tamed animal's head is half behind the left door frame. The red collar marks it,
    but it reads less clearly as a dinosaur than the captured one. At 64 px and up it is clearly a raptor.
- I did not run a blind judge on this round; the reading above is mine.

Gates (final code, this round):
- `Blender -b --factory-startup -P tools/render_icons.py -- --only tamed_animal`: `ICON tamed_animal 65347 d0e67a5cb498f069`,
  `ICONS DONE n=1 over_64kb=0` (captured_animal was rendered earlier with `--only captured_animal,tamed_animal`:
  `ICON captured_animal 64469 00f86640dfef7aa6`, unchanged since).
- `... -- --verify captured_animal,tamed_animal`: `REPRO captured_animal identical`, `REPRO tamed_animal identical`,
  `REPRO PASS n=2` (the --only render plus this re-render make the two byte-identical renders; a third tamed render
  from a scratch copy of tools/ also gave sha d0e67a5c). `... -- --selftest`: `SELFTEST PASS`.
- Godot through gslot.sh, each with its own alarm: `--import` rc 0 (reimported both PNGs; their `.png.import` files
  did not change); `--script res://tests/t_iconart.gd`: `[t_iconart] PASS`; `--script res://tests/run_all.gd`:
  `[tests] PASS`; `tools/smoke.sh --no-import`: `SMOKE PASS`.
- `manifest.json`: only the captured_animal and tamed_animal entries changed (sha256, bytes, rect).

Risks: both PNGs are close to the 64 KB cap (64,469 and 65,347 of 65,536). Any change to the carrier, the
dino texture or the rig light can push tamed over the cap. `render_one` then refuses to write the file and says so.

## Merge
Stacked on ICONS2: merge `claude/mmo-icons2` first, then this branch. In scope: `tools/blender/items/camp.py`,
`game/assets/icons/render/captured_animal.png`, `game/assets/icons/render/tamed_animal.png`, `game/assets/icons/render/manifest.json`, this report.

## Credits
None (no Meshy, Tripo or generation calls; the mesh is already in the repo).

## Assumptions
- `# ASSUMPTION:` in `captured_animal`: the item names no species, so the deinonychus is drawn
  (green against the wood, a raptor head that reads as a dinosaur). The head is enlarged 1.75x as icon
  styling; no lore or mechanics added.
