# INVSCREENS: Durango Bag, item card, Character/Gear and storage tabs on canon's bag (spec 13)

Branch `claude/mmo-invscreens` (from `claude/mmo-overhaul` 7d537d51). Not pushed, not merged.

## Slices done
1. **Bag + item card.** `BagGrid` draws `Lv. N` (grey, top right), blue NEW tags, a green corner for
   rare traits and a lock pip. Auto Sort (bag order / type / level / name) and the filter (all,
   materials, food, gear, tools, building, rare, locked) change only the draw order. The bottom
   toolbar has Auto Sort, Filter, Select, Lock and Destroy. The new `ItemInspectPanel` floats left of
   the docked bag (addendum 2) and shows facts, traits in gold/grey/green, and only the valid
   actions (`InventoryUI.valid_actions`). `look_row` / `show_look()` is an empty hook for spec 35's swatch.
2. **Character / Gear / My Info.** Full-view Character page: portrait, name, title, level,
   occupation, XP bar, Combat/Crafting/Gathering Power, Attack/Defense/Accuracy, Detailed Stats,
   Gear | Decorative tabs, presets 1-4 gated by level, ten slots with faded silhouettes, and the
   selected worn piece with Unequip.
3. **Storage + cargo.** A box, basket, loot or a pet's cargo opens on its own tab beside Bag. A tap
   selects. "Transfer to Bag" / "Transfer to <box>" moves that exact instance.
4. **Hold/drag multi-select (coordinator, owner 2026-10-27).** A long press (0.45 s) or a Shift-press
   enters Select mode. Dragging paints cells in, and dragging back along the path un-paints them.
   A tap toggles one cell. The grid auto-scrolls near its edges. The toolbar shows "N selected" and
   batch Lock / Drop / Destroy / Store on the bag tab, and Transfer to Bag on a container tab.
   Locked items can be marked, but every moving or destructive action skips them.

Not done: **the craft/cook ingredient picker** (spec 13 s19). The recipe card still uses
`Crafting.default_picks` (the least valuable instance, locked ones never). The next step is a
`BagGrid` filtered to `Crafting.stacks_for_slot` candidates, with an explicit pick passed to the
craft. Market "Sell" is also not wired, because no Sell screen takes an instance yet.

## INVUI pieces (claude/mmo-invui): port / rewrite / skip
| INVUI piece | Verdict |
|---|---|
| inv_attributes.gd | **Ported** (the rare list now comes from rules.json, so there is one list) |
| inv_stats.gd | **Ported** (snapshot/power/fmt; with_candidate and diff skipped, since there is no compare view) |
| gear_presets.gd | **Ported** (uses Inventory equip directly; canon has no PlayerActions.equip_at) |
| data/inv_ui.json | **Ported, trimmed** to attribute_classes, presets and powers |
| item_inspect_panel.gd + inv_card_facts.gd | **Rewritten** (~200 lines, rows_for/kind_text; family chips, flavour, Create section skipped) |
| inventory_grid.gd / inventory_slot.gd / inv_paint.gd / inv_view.gd | **Rewritten into canon's bag_grid.gd** (view_order, matches, cell drawing) |
| inv_new_tracker.gd | **Rewritten** inline in InventoryUI (_track_new) |
| bag_screen / character_screen / gear_screen / equipment_screen / storage_screen | **Rewritten** as pages of canon's inventory_ui.gd |
| bag_toolbar / inv_header / inv_tab / capacity_indicator / gear_preset_selector / equipment_slot / detailed_stats_panel | **Rewritten** as plain buttons and labels in inventory_ui.gd |
| filter_rail.gd | **Skipped** (Filter is one cycling toolbar button) |
| inv_theme.gd, inv_grain.gdshader, inv_glyphs.gd, inv_motion.gd | **Skipped** (palette constants only; no textures, glyphs or motion) |
| item_picker.gd, ingredient_choice.gd | **Skipped / not done** (see above) |
| equipment compare (with_candidate/diff) | **Skipped** |
| bag_ui_lab, inv_carrier_art, captured_animal.png | **Skipped** |
| t_invui.gd | **Skipped**; the new t_invscreens.gd covers this package |

## Save changes (flagged)
- `player.inventory_extras.presets` = `{active, sets:[{slot: uid}]}`. It is additive and written only
  once a preset is used, so a save that never used presets stays byte-identical. On load,
  `GearPresets.sanitize` cleans it (known slots, `^[il][0-9a-f]+$` uids, at most 4 sets, active
  clamped). `save_sanitizer.gd` SHAPE now lists `presets: {}`. Fixture cases in t_invscreens: an old
  save without the key loads as {} and re-saves without it, presets survive a save, and a forged
  row is cleaned.
- NEW flags are not saved (a load shows nothing as NEW).

## Other behaviour changes
- A tap on a container cell now selects it. It used to take the item at once; the card's Transfer to
  Bag takes it now. `_take_storage(i)` and `_take_all_storage()` are unchanged.
- A container you can deposit into stays open when emptied. Take-only loot still closes.
- The bag page no longer shows profile or equipment columns: they are on the Character page.
  Tapping a worn slot selects it, and Unequip takes it off (before, a tap unequipped at once).
- Batch Drop's gate is now `World.runtime != null`. It no longer also requires a bound player, and
  the loot bag lands at the survivor when there is one.
- `BagGrid`'s inner grid has min width 0. Its old `size.x` min plus the scrollbar pushed the grid
  past its panel.

## Gates (worktree head)
- import: 0 ERROR lines
- `[t_invscreens] PASS` (actions per kind, trait classes, sort/filter, presets and old saves, NEW,
  transfers and cargo conserve instances, hold/drag paint 10 / un-paint / tap toggle, batch drop
  8 of 10 with 2 locked skipped and no loss, batch Store / Transfer to Bag, every button >= 64 px
  and no overflow at 844x390 and 1600x900 on bag, box tab, select mode, character, detailed stats and decorative)
- `[t_bags] PASS`, `[t_inventory] PASS`, `[t_ui] PASS`, `[t_uiicons] PASS ids=191 ...`, `[t_items] PASS`,
  `[t_save] PASS` (the 5 deliberate SCRIPT ERRORs), `[t_econ] PASS`, `[t_controls] PASS`,
  `[t_invslots] PASS`, `[t_player] PASS`
- `bash tools/smoke.sh --no-import`: `SMOKE PASS`
- run_all: `[tests] PASS`. It logs 6 SCRIPT ERROR lines: the 3 known TouchControls compile-order
  lines and 3 from economy_tests' fault test, which marks them "deliberate".

## What must be looked at on screen (headless only here: no screenshots were taken)
- The item card floats over the world left of the bag at 844x390 (238 px wide). It may cover HUD
  pieces on that side (minimap, rails).
- The Character page at 844x390 is dense (29 px lines, because the symbol fallback fonts make lines tall).
- Faded silhouettes use real item art at 35 % alpha, not true silhouettes.
- No weathered textures or torn header edge yet: it is flat Durango colours only.
- Hold/drag feel on a real phone: the long-press time (0.45 s), the edge auto-scroll speed, and
  whether emulated touch delivers the motion events as in the test. Two-finger scroll in Select
  mode is not implemented (in Select mode, use the scrollbar, the wheel or edge auto-scroll).

## Assumptions
- 4 presets at shown levels 1/10/30/50 (from INVUI). Worn gear a preset does not name comes off.
- Power = the highest skill level in each group (from INVUI).
- The game has no decorative gear, so the Decorative tab says so.
- `pocket` and `capacity` bag attributes show as gold (positive) traits.
