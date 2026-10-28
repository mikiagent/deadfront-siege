# NATURECHIP: the nature tag no longer hides under the HP bar

Owner: "the animal's nature in the wild is being hidden by the healthbar. Move it so you can clearly see the nature".

## Cause
- `NatureChip` sized its label to 14 px, but a Label never shrinks below its line box (25 px at 12 px type once
  the symbol fallback fonts are installed). The label grew downward from the chip's top, so "Timid" was drawn
  about 5 px below its gold box, into y 30-35 of the plate.
- The HP bar (`BarBg`) started at exactly the chip's bottom (y 30) with no gap and is a later sibling, so it drew
  over the text. Nothing else (z-index, pill) was involved.
- The chip also sat at y 16, inside the 14 px name's 20 px Latin line box, so it clipped the name's descenders.
- Pet XP still used the old y 36 (inside the bar).
- The target plate (HuntHud) drew no nature at all.

## Fix
- `nature_chip.gd`: the label's line box is centred on the chip. New `NatureChip.draw_at()` draws the same tag on
  a CanvasItem (for drawn HUDs).
- `creature_plates.gd`: rows are name 0-20, tag 20-34, 4 px gap (`CHIP_GAP`, ASSUMPTION), HP bar 38-52, pet XP
  52-56, statuses 56-82, tame 82-102; `FULL_H` 94 -> 102. Every row below the name hangs off the bar's y
  (`bar_top()`), which `_fit_pill` and `_tick_xp` read too. No nature: no tag and no gap, so the bar sits right
  under the name (y 22).
- `hunt_hud.gd` (`_draw_target_plate` only): the tag is drawn 1 px under the name's Latin line box, and the bar,
  statuses and Tyrant line drop to stay 4 px clear. With no nature the plate is unchanged. `target_rows` holds the
  name/tag/bar rects for tests.
- `t_targetui` `_test_nature_rows`: at 1600x900 and 844x390, on the world plate and the target plate, the tag is
  under the name, 4 px or more above the bar and does not overlap it, and its text is centred. A nature-less
  animal draws no tag.
- `scenes/dev/naturechip_lab.tscn`: a Timid wild deinonychus at the game camera, with its world plate and then the
  fight's target plate.

## Gates
t_natures, t_targetui, t_uigather, t_ui, t_fieldhud, t_tame PASS; run_all `[tests] PASS`; `tools/smoke.sh --no-import` SMOKE PASS.

## Captures (naturechip/)
- `world_plate_before_1600x900_x2.png`: before the fix. The bar covers the bottom half of "Timid".
- `world_plate_844x390.png`: after, on a phone: name, tag, gap, bar.
- `target_plate_1600x900.png`: after: the target plate with its Timid tag above the bar.

Credits spent: 0.
