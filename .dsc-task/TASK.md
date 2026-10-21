# Task: SPRITES2D: cut the owner's green-screen art sheets into game sprites

Context: DEADFRONT, a Godot 4.7.1 typed-GDScript dinosaur survival game (project `game/`), web build. The owner painted
sheets of jungle and beach art on a pure green background "for isolation", in one shared art style:
`docs/reference/2d-assets/sheet-*.webp`. Read docs/design/durango-prompts/27_2d_asset_sheets_glowing_eyes.md and
28_jungle_cliffs_and_trees.md first: they list what is on each sheet and what each kind of item is for. Resources and props
become 2D cards in the game ("resources 2D but realistic and kind of look 3D"; buildings stay 3D). Another job (CARD2D) puts
cards in the world; YOUR job is only the cut-outs and their data. No GDScript, no scenes.
`docs/reference/concept-*.webp` files are targets to look at, NOT cut sources (their background is not a key colour).
More sheets may arrive while you work: everything you build must run over every `sheet-*.webp` in the folder, so a new
sheet needs only a re-run plus naming its items.

## Tools (all present; add nothing)
- Python with numpy: `/Applications/Blender.app/Contents/Resources/5.2/python/bin/python3.13 -I tools/sprites2d/cut.py ...`
  (no PIL, no scipy, no OpenCV). Decode with `dwebp -quiet <sheet>.webp -pam -o <tmp>.pam` (PAM = text header up to
  `ENDHDR\n`, then raw RGB/RGBA bytes); encode with ffmpeg from raw RGBA:
  `ffmpeg -v error -y -f rawvideo -pix_fmt rgba -s WxH -i <tmp>.rgba <out>.png`. Temp files go in /tmp/sprites2d/.
- Godot (only for the import check at the end), exactly:
  `/private/tmp/claude-501/-Users-milankinzy-Documents-deadfront-siege/1899b1df-f06b-4b94-91be-9e3f3c22081d/scratchpad/gslot.sh perl -e 'alarm 900; exec @ARGV' /Applications/Godot_mono.app/Contents/MacOS/Godot --headless --path game --import > /tmp/sprites2d_import.log 2>&1`
  with bash timeout_ms 960000. Never pipe Godot into tail/head/grep; read the log file afterwards.

## Measured facts (orchestrator, on the four sheets)
- Sheets are 1254x1254. The key colour is (5, 250, 4) with a spread of about 2 per channel; 35-48 % of each sheet is key.
- Foliage is green too (jungle-plants is 31 % foliage-green): key on DISTANCE to (5,250,4), never on "G is largest". Plant
  greens sit 95+ RGB units from the key; antialiased edges sit in between.

## What to build
1. `tools/sprites2d/cut.py` (one script, re-runnable, deterministic): for each sheet
   - soft alpha from the distance to the key colour (fully clear near the key, fully opaque beyond a second threshold,
     linear between); un-mix the edge pixels (remove the key's share of the colour, then clamp G to at most
     max(R,B) + the item's own typical green excess) so no green halo is left on shells, rocks or trunks;
   - split items: threshold the alpha, close small gaps (a few px) so one palm's fronds stay one item, label connected
     components (a numpy/pure-Python flood fill at 1/2 or 1/4 scale is fine), drop specks under ~400 px of area; items that
     touch on the sheet can be split or grouped by hand rectangles in `tools/sprites2d/overrides.json` (per sheet:
     `split` boxes, `merge` lists, `drop` lists), applied by the script;
   - trim each item to its alpha box (2 px padding at most) and write an 8-bit RGBA PNG to
     `game/assets/nature/sprites2d/<sheet>/<sheet-short>_<nn>_<slug>.png` (e.g. `sheet-palms/palms_03_leaning_palm.png`);
   - write `game/data/world/sprites2d.json`: `{"sprites": [ ... ]}`, one row per sprite:
     `id`, `sheet` (file name without .webp), `file` (res:// path), `src_rect` [x,y,w,h] on the sheet, `px` [w,h],
     `pivot` [x,y] in px of the trimmed image, `name`, `kind`, `height_m`, `blocks`, `destroyable`.
     The script keeps names/kinds/heights you set (read them from `tools/sprites2d/labels.json` keyed by sheet + src_rect,
     or by id) so a re-run never loses your mapping.
2. Map every sprite (labels.json), by LOOKING at the crops (open the PNGs or your contact sheet):
   - `kind`: a resource family id from `game/data/nature_manifest.json` "families" when it is that resource (PalmTree,
     Plant, VinePlant, ReedPlant, Rock, Rock_Moss, GraniteBoulder, WoodLog_Moss, BranchPile, MangoBush, BushBerries, ...),
     `prop:<name>` for scenery that is not harvested (prop:cliff_big, prop:cliff_block, prop:arch, prop:pillar,
     prop:waterfall, prop:vine_hanging, prop:root_curtain, prop:boulder, prop:slab, prop:fern, prop:bromeliad,
     prop:driftwood, prop:shells, ...), `icon:<item>` for loose items that suit a bag icon later (fruit, coconut, bones,
     tooth, single shells), or `unused` for fragments (single leaves, fronds) - at least 60 % must be mapped;
   - `height_m`: the item's real height in metres judged from the art (palm 8-14, canopy tree 14-22, big cliff 8-15,
     boulder 0.8-2, fern 0.6-1.2, shell 0.1-0.3) - every one is `# ASSUMPTION` in your report;
   - `blocks`: true for trees and anything taller than 1.25 m (the game's step-over rule), false for hanging vines/roots,
     icons and anything lower; `destroyable`: false ONLY for big cliffs, arches, pillars and waterfalls of 4 m or more
     (owner: "most props can be destroyed except for like really big cliffs"), true for everything else;
   - `pivot`: the ground contact point (bottom centre of the trunk or base); for hanging vines/roots the top attach point.
3. A contact sheet `docs/orchestration/reports/dsc-sprites2d-sheet.png`: every sprite on a mid-grey background with its id
   under it, grouped by sheet (ffmpeg can tile, or compose it in numpy). LOOK at it: halos, cut-off fronds, two items glued
   together, a shell split in two - fix them via overrides and re-run.
4. Report `docs/orchestration/reports/dsc-sprites2d.md`: sprites per sheet, total MB, thresholds you chose and why, what you
   could not split cleanly, every assumption, and what CARD2D needs to use them (sizes, pivots, which kinds have art now).

## Milestones (write them to .dsc/PLAN.md; call milestone_done after each; verify one stage at a time)
- M1 cut.py keys, splits, trims and writes PNGs + a bare manifest for all sheets: `bash <verify> 1` passes.
- M2 overrides fix glued/split items; contact sheet made and looked at.
- M3 labels.json maps every sprite: `bash <verify> 2` passes.
- M4 Godot import check, report, full verify.

Verify: `bash /private/tmp/claude-501/-Users-milankinzy-Documents-deadfront-siege/72cebc8b-d241-430b-9ea6-94d65339bfef/scratchpad/dsc/verify_sprites2d.sh [1|2]` (no argument = full gate). It runs
`/private/tmp/claude-501/-Users-milankinzy-Documents-deadfront-siege/72cebc8b-d241-430b-9ea6-94d65339bfef/scratchpad/dsc/check_sprites2d.py`: read both before you start. Baseline today: "FAIL tools/sprites2d/cut.py is missing".
Its numeric limits: opaque pixels within 90 RGB units of the key <= 0.3 % per sprite, edge pixels <= 3 %, edge green excess
no more than 25 above the sprite's inside, sprites at least 24x24 px, at least 10 per sheet, all PNGs <= 24 MB in total.

## Constraints
- Your files only: tools/sprites2d/, game/assets/nature/sprites2d/, game/data/world/sprites2d.json,
  docs/orchestration/reports/dsc-sprites2d*. Never edit docs/reference/ (the owner's art), other jobs' files, game/scripts,
  game/tests. Keep game/override.cfg. Do not push, merge or deploy. No new dependencies.
- Known traps: never run a long command without a timeout; write big files with write_file, not heredocs; after editing
  cut.py run it on ONE sheet first (`--sheet sheet-palms`) before all of them.

## Round 2 (orchestrator, 2026-10-21 15:15): three new sheets
The owner resent three green sheets, now in docs/reference/2d-assets/: `sheet-jungle-trees.webp` (giant buttress-root canopy
trees, palms, banana plants, understorey), `sheet-tall-grasses.webp` (grass clumps, reeds/cattails, strips, iso ground tiles,
three large ground patches) and `sheet-jungle-cliffs.webp` (a big tiered cliff with waterfalls, arches, pillars, cliff blocks,
waterfall chunks, boulders, vine and root curtains, palms, ferns, shells, driftwood). Read spec 28
(docs/design/durango-prompts/28_jungle_cliffs_and_trees.md) for how each kind is used: big cliffs/arches/pillars/waterfalls are
props that block and cannot be destroyed; grass clumps and reeds are ground cover that never blocks (prop:grass_*,
prop:reed_* or the Grass/WildGrass/DryGrassTuft/FibreTuft/ReedPlant families); the iso ground tiles and the three large
patches are colour references: cut them and mark them `unused`.
- R1 Re-run cut.py over all sheets; add overrides for glued items (the big cliff is ONE sprite; touching grass clumps split);
  extend label.py/labels.json for every new sprite. Stage 1, then stage 2.
- R2 Size: the web download is close to its ceiling. Keep the whole set <= 24 MB (the gate checks it): downscale on export so
  a sprite's longest side is <= 512 px, or <= 768 px when height_m >= 8 (big trees and cliffs); write the scale used per
  sprite into the manifest (`scale`), so the game can size cards by height_m. Re-check the earlier sheets still pass.
- R3 Contact sheet regenerated and looked at (write what you saw in NOTES.md); report updated with per-sheet counts and MB.
