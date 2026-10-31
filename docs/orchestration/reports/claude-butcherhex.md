# BUTCHERHEX: animal-part icons and the carcass part fan

Branch `claude/mmo-butcherhex`, cut from `origin/claude/mmo-overhaul` (019a98b2). This branch is not merged to canon.
Credits spent: 0.

The owner's reference was a Durango "Tarbosaurus Corpse Lv. 54". Six flat-top hexes sit around the corpse, one per part. Each hex has a white icon, the seconds on top, the count below, and a label giving the part's name and level. Parts the player cannot cut yet carry a red wrench and no-entry badge.

## What shipped

1. **17 part icons and one badge icon.** They are drawn in a new module, `game/assets/icons/ui/_src/icons_t.py`, which is registered in `build.py`.
   - Style: line drawings, 5-unit bands with round ends. Like `icons_g..s`, they are built as solid polygons and `geo2.place` centres each one optically. They import with the set's settings (`svg/scale=2.0`, mipmaps, lossless).
   - Icons: `part_skull`, `part_large_skull`, `part_tendon`, `part_intestines`, `part_meat`, `part_bone`, `part_large_leg_bone`, `part_hide`, `part_armor` (three keeled scutes), `part_fat`, `part_claw`, `part_horn`, `part_frill`, `part_dorsal_plate`, `part_tail_club`, `part_tail_spike`, `part_venom_gland`.
   - Badge: `tool_needed`, a wrench inside a no-entry ring.
2. **Wiring.** `data/ui_icons.json` gets the new ids plus a `"parts"` map from item id to part icon, covering every yield in `butchering.json` (22 item ids).
   - `UiIcons.for_part(item_id)` returns the part icon, or null if the item has none.
   - Bag and shop art stays the colour item art from `icons_manifest.json`. Only the butcher fan uses the white part icons.
3. **The carcass fan** (`GatherRadial`, the fan that `Corpse.open_picker` already opens). The cut logic did not change.
   - Each hex shows its white part icon at full white, the cut seconds on top and the units left at the bottom. These come from the existing `radial_options`.
   - Labels read "Raw Meat Lv. 54" on desktop. The level is the carcass level, which is the level `LootRoller.roll_part` gives the cut.
   - Locked parts still show "Name · reason" in red, and the reason is kept.
   - **Tool badge.** `GatherRadial.tool_gate(reason)` decides whether a lock is lifted by a tool or a skill. That covers "needs knife", "needs Butchering N", "Needs <node>" from `SkillRules.butcher_block`, and "your X is broken" from `Inventory.tool_block_reason`. Those hexes draw `tool_needed` in the red badge, using a new `HexButton.badge_icon`. The badge sits on the hex's upper-right edge, clear of the seconds.
   - Other locks ("already cut", "no cuts left", "nothing left", "meat spoiled") keep the plain ⊘ badge. `badge` is still "⊘" on every locked hex, so existing tests and callers are unaffected.
   - Harvest nodes get the same tool badge when the player lacks an axe or pick.
4. **Contested badge: skipped.** Carcasses have no contested or guarded state. The only `contested` flag in the game is on island landmark sites (`island_landmarks.gd`). Per the brief, I did not invent one.
5. **Lab:** `scenes/dev/butcherhex_lab.tscn` with `scripts/dev/butcherhex_lab.gd`. It kills a Lv. 54 tarbosaurus and takes three shots of its fan: with no knife, with a stone knife, and with a cut running. With `--sheet` it shoots the contact sheet instead.

## Shots

All shots are in `docs/orchestration/reports/butcherhex/`. They came from windowed runs at `--position 6000,3000` that quit on their own, using `-- --skip-charcreate`.

- `carcass_1600x900.png`, `carcass_844x390.png`: stone knife at Butchering 0. Meat, leg bone and hide are open. Dense Bone and Skull Plate wear the wrench badge ("Needs Bone II" and "Needs Scutes").
- `carcass_noknife_*`: every part wears the badge and reads "Needs knife".
- `carcass_cutting_*`: the meat hex pie-fills while the other hexes lock.
- `icons_sheet.png`: every icon on a desktop fan hex, plus the badge.
- `icons_160_and_24px.png`: each icon at 160 px and 24 px.

Run it with:

```
Godot --path game --resolution 1600x900 --position 6000,3000 -- --skip-charcreate --lab=butcherhex_lab --shot-dir=DIR [--sheet]
```

**Fixed after looking at the shots:**
- The badge covered the "1.6s" text, so it moved to the hex edge.
- The first drawings of the claw, tendon, tail club, tail spike, dorsal plate, large skull and fat read wrong, so I redrew them.
- The wrench in the badge lay along the no-entry bar and could not be seen, so it now crosses the bar.
- The skull plate showed the same icon as the dense bone, so it now uses `part_large_skull`, and dense bone uses `part_bone`.

## Assumptions

- `# ASSUMPTION:` On a phone (64 px hexes), part labels drop the "Lv. 54", because the fan's title already shows the carcass level for every part. At 844x390, six "Name Lv. 54" labels around a big carcass pushed one label onto the vitals bars. Desktop keeps the level on each label.
- Locked labels drop the level so the reason has room. The phone's existing 148 px cap still cuts "Skull Plate · Needs Scutes" to "Needs S…". The badge now carries the meaning.
- Item-to-icon mapping:

  | Items | Icon |
  |---|---|
  | `bone`, `raptor_bone`, `hollow_bone`, `dense_bone` | bone |
  | `large_leg_bone`, `stout_leg_bone` | large leg bone |
  | `skull_plate` (tarbosaurus and tyrannosaurus) | large skull |
  | `raptor_talon`, `alpha_fang` | claw |
  | `alpha_hide` | hide |

- `part_skull`, `part_intestines` and `part_fat` were requested but no butcher yield uses them yet.

## Gates

| Gate | Result |
|---|---|
| `t_uiicons` | PASS: ids=229, files=156, weight 0.60..1.49, worst IoU 0.80 (loot/store), `build.py --check` PASS |
| `t_butcher` | PASS |
| `t_lootradial` | PASS. New checks: the skill-locked part wears `tool_needed`, the meat hex draws the white `part_meat`, only tool and skill locks count as tool gates, and every `butchering.json` yield has a part icon |
| `t_gather` | PASS |
| `t_uigather` | PASS |
| `run_all.gd` | [tests] PASS |
| `tools/smoke.sh --no-import` | SMOKE PASS |

## What the next agent needs

- The tarbosaurus in the lab is a red box. Either the mesh is not on this branch or the lab spawn does not load it; I did not look into it.
- At 844x390 on a big carcass, the Raw Hide hex sits close to the LOOT button. This comes from the existing ring solver; I did not change the layout.
- Running the Godot editor import rewrote `game/project.godot`, dropping the touch emulation and web renderer lines. I restored it and did not commit that change. Watch for this in other worktrees.
- `pet_radial.gd` and the taming files were not touched.
