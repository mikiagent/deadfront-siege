# PERKCAP: at most 2 perks per gathered item, grey 35%, the feed shows one item

Branch `claude/mmo-perkcap` (from `origin/claude/mmo-overhaul`). Owner, 2026-10-28: "way too many perks ... it should really be 1-2 perks on each gathered item max". His screenshot showed a "Branch +21" row with 2 green perks and 9 grey ones (Soft, Heavy and Low Density, each at Lv. 1, 2 and 3).

## Root causes

1. **The 9 stacked traits came from the feed, not the item.** `TopFeed._add` collapses every gain of the same item into the row that is still showing, and each new gain resets that row's life timer. It also merged the new gain's chips into the row, deduplicated by text. "Soft Lv. 1" and "Soft Lv. 2" are different strings, so 21 different branches piled into one row with the same trait family at three levels. `push_gain` likewise took the union of chips across every fresh instance.
2. **The "+21" is a running total, not extra yield.** That same collapse summed the count. Every pass still lands exactly one item (t_onegather checks this). The count is kept, but the row now reads "+21 total" once two or more gains have collapsed into it.
3. **Too many perks per item.** HARVESTROLL rolled grey at 96% and gold at 7%, and the green trait could stack on top for up to 3. Nothing stopped a trait and its opposite (Soft with Firm) landing on the same lot.

## Fix

- `TopFeed`: a collapsed row keeps the running total, but its chips, art and tier are the latest item's own. `push_gain` takes chips from one item.
- `loot_tables.json lot`: `negative_chance` is now 0.35 (ASSUMPTION; Milan said 96% was "too harsh"). New fields `max_perks: 2` and `opposites`. `roll_lot` drops a gold roll that is the opposite of the grey one already rolled.
- `GatherService.stamp_traits` (shared by client and server): when a green trait lands on an item that already has 2 perks, the item's grey trait gives way. With no grey trait to drop, the green trait is skipped.
- `docs/vision/WildLandsMMO_Open_Questions.md`: HR2 updated, HR4 added.

## Tests

`t_harvestroll`:
- 200 passes with a steel tool at Gathering 60, through the real yield and green-trait stamp. The most perks on any item was 2, no item carried a trait with its opposite, and grey landed on 67 of 200 (green on 13).
- Three gains collapse into one "+3 total" row that shows only the latest item's chips.

Gates: t_harvestroll, t_gather, t_econ, t_uimarket, t_onegather, t_uigather, t_levelfx and t_lootradial pass. t_server_domain also passes, run_all prints `[tests] PASS`, and smoke prints SMOKE PASS. The full all_tests.sh suite was not re-run.

Credits spent: 0.
