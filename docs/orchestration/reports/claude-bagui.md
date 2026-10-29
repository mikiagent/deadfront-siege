# claude-bagui — bag panel, perk tiers, currency bar, market Sell grid, chest tabs, item tags

Branch `claude/mmo-bagui` (from `origin/claude/mmo-overhaul`). Not pushed, not merged.

## Owner direction during the task (all verbatim from Milan via the coordinator)
1. First: remove craftable/worn backpacks, rummage-bag UI, premium capacity upgrades.
2. Reversed: "you can craft and equip backpacks". The backpack package (items, recipes, worn mesh,
   slot bonus) is untouched; no save migration was kept.
3. "no premium currency upgrade for item slots, that was a bad idea": removed entirely. Backpacks
   (and clothing Pocket) are the only capacity source. The currency widget stays.
4. Market Sell: equipped items red and not selectable; going-rate default price.
5. Chest: the bag panel with a tab per container, Deposit / Withdraw by selection.
6. Item tags: tendon is Strap / Tendon / Edible / Meat, edible, twists into a bowstring.
7. Selected items get a clear check badge top-left.
8. T-stones are shown as "Gold"; Harbour sailing costs Warp Gems.
9. Multi-select foods → "Eat (n)" eats them in queue; badges show the order.

## What shipped
- **Bag panel** (`game/scripts/ui/inventory_ui.gd`): right-docked sheet (52 % of the view, 520-900
  px) with `SheetChrome` header: ‹, tabs Bag | container | Character, `used / capacity` counter
  (counts the worn backpack: e.g. 113 / 334), `CurrencyBar`, ✕. Filter rail (64 px icon+label tabs:
  All, Materials, Food, Gear, Tools, Building, Rare, Locked). Bottom bar: Sort by dropdown (Bag
  order, Level, Rarity, Type, Newest, Name), Select, Lock, Trash (two-tap confirm). Locked items are
  never trashed/dropped/deposited (existing gates). Roboto Condensed via `SheetChrome.ui_theme()`.
  While Select is on the header counter reads "<n> Select".
- **Grid cells** (`bag_grid.gd`, the shared cell is **`BagGrid.Cell`**, badge in
  `BagGrid.Cell._check_badge`): Lv., quality dots (one per rarity step), NEW, rare corner, lock, a
  `blocked` red tint (market Sell grid), and on any selected / marked item a GOLD badge top-left: a
  check for the single selection, the mark's order number (1, 2, 3…, renumbered on unmark) in
  Select mode. Items never stack (unchanged rule).
- **Eat queue**: marking foods in Select mode shows "Eat (n)" in the batch bar (hidden while a chest is
  open: Deposit there). It closes the bag and `EatSession.begin_queue` eats the exact instances in
  mark order, each through the normal begin_eat (its own time / animation). A move, a hit (Health
  drop) or Full stops the queue with a notice ("Too full to eat more." etc.); the rest stay.
- **Item card** (`item_inspect_panel.gd`): quality line, tag chips (ItemTags), facts incl. food
  energy/raw/poison, Traits, Perks with tiers ("Black Sheen IV"), Info (flat-top hex swatches of the
  tint + light/dark tone + hex code), Maintenance ("Repair: Not Possible": no item repair exists in
  code), Craft into (recipes taking the item), big GOLD Use (eat > equip > place; with a chest open
  it is "Transfer to <chest>").
- **Rummage hook**: `PlayerAnim.start_rummage()` / `stop_rummage()`; the bag's `visibility_changed`
  calls them (bag and containers). Plays clip `rummage` if `assets/characters/survivor/anim/rummage.glb`
  exists (added to `RiggedModel.LOOPING`), else holds idle; not when mounted/swimming/asleep/busy.
  Any movement (stick/keys/tap-to-walk) closes the bag.
- **Chest**: a container opens on the same panel; tabs "Bag 112 / 334" and "<Chest> 60 / 105";
  Select mode → Deposit (bag tab) / Withdraw (chest tab); what does not fit stays; locked items and
  the held tool are skipped. No separate chest UI existed to replace (structure sheet already opened
  the bag panel). The arrow buttons beside the tabs were not added (tabs are tappable).
- **Perk tiers**: rare trait value = tier 1-5 (old `true` reads I). `LootRoller.roll_tier(rng,
  tool_tier, skill)`; gather and alpha parts roll it; craft keeps the primary's tier, a craft's own
  rare roll rolls one (`outcome.rare_tier`). Data: `loot_tables.json rare_trait.tier_*`.
- **Currency**: `World.warp_gems` (premium Warp Gems, teal flat-top hex gem icon `warp_gem`, drawn
  in `assets/icons/ui/_src/icons_s.py`). T-stones are shown to players as **Gold** (gold coin) in every
  player-facing string; code names and the save key `t_stones` are unchanged. `CurrencyBar`
  (`game/scripts/ui/currency_bar.gd`) in the nav menu header, bag header, market header (gems only
  beside the market's own wallet pill). "+" shows a placeholder note; no purchase flow.
- **Harbour sailing costs Warp Gems**: `World.pay_sail(cost)` inside `World.travel` (the existing
  per-island `sail_cost`, 5 by default, 0 home); refusal notice "Needs N Warp Gems to sail (you have
  M)."; route cards and the map read "N Warp Gems".
- **Market Sell** (`market_sell.gd`): server bag in a `BagGrid`; equipped and locked items red,
  a tap only explains; picking fills the price with the going rate = median of that item id's open
  fixed listings (`MarketSell.median`), else the category base price from `data/world/market.json`;
  "Going rate N" label; − / + step 5 %. Offline card unchanged. `MarketHarness` now equips the knife.
- **Item tags** (`game/scripts/items/item_tags.gd`): **stable API for claude/mmo-craftradial:
  `ItemTags.tags(id) -> Array[StringName]`, `ItemTags.has_tag(id, tag) -> bool`,
  `ItemTags.label(tag) -> String`.** Tags are the def's `categories` (no duplicate list): recipe slots
  already match by category. `predator_tendon` gains strap, meat, food, edible + food values; new item
  `bowstring` and recipe `bowstring` (slot category `strap`, by hand).

## Save changes (owner's gate)
Additive only, no schema bump: top-level `warp_gems` (int, sanitizer clamps 0-100000; a save without
it loads with the new-game grant, 25). The Gold rename is display-only: the save key stays `t_stones`. Perk tier reuses the existing rare-trait value (true → I), so old saves read unchanged.
Nothing else in the save format changed.

## Proposed prices (money is the owner's gate; all # ASSUMPTION)
- Sailing: the existing `sail_cost` per island, now Warp Gems: 5 per trip, home 0.
- Starting Warp Gems 25 (five trips); the first standing order (Knap a stone knife) grants +10.
- The premium capacity upgrade was dropped by the owner; none.
- Going-rate fallback: the existing market.json base prices.

## Assumptions (# ASSUMPTION in code)
- Warp Gems is the premium currency (name from docs/design/skills.md); grants and trip cost above.
- Perk tier roll: step 0.35 (+0.03 per tool tier, +0.002 per skill level, cap 0.6) → II 35 %, III 12 %,
  IV 4 %, V 1.5 %. Gathering passes skill 0 (spec 12:42 keeps level off rare odds).
- Info swatches: tint plus a light and dark tone (items carry one colour).
- Tendon food: energy 6, raw, poison 25 %, tastes bad 40 %; tagging it `meat` also means a spoiled
  carcass (no_meat) no longer yields tendons, and pets/autofeed may eat it.
- Bowstring: plain component, no bow uses it yet; recipe by hand, construction tree.
- Going rate matches by item id only (the market groups by id); median rounds down between the middle two.
- Sheet width 52 % (520-900 px) to leave room for the item card.
- Phone bag header drops the Character tab and the gem "+" (and the Gold pill with a chest open) to fit
  844 px; both remain in the nav menu.
- Eat queue stops on any Health drop as "a real hit".
- MarketHarness: the viewer now earns 30 (was 25) before the Buy check, because the new items shift
  the Settlers' order rotation and left it 1 Gold short of the cheapest listing; it also wears the knife.

## Eat bug on canon (root cause, fixed in the shared flow)
"I can't select eat again the second time": every finished meal applies the **Full** status
(`full_seconds`, 10 s default) and `Food.can_eat` refused any eat while Full lasted, so the second
berry's Eat silently did nothing. Now `Food.can_eat` refuses only when the stomach is overfull
(`Digestion.fullness() > OVERFULL_ABOVE`); Full stays a status for its other effects. The bag's Eat
also says why when an eat is refused (no silent no-op). Test `t_eatqueue`: three berries through
the bag's Use (Eat) one after another all eat. Side effect to know: auto-feed is no longer held off
by Full (it keeps its own 12 s cooldown).

## Open questions
- Should Warp Gems have any source/sink now (skill refunds per skills.md)?
- Rummage clip timing: kneel-in/out transitions if the clip has them.

## Verification
- `bash tools/all_tests.sh` (WRAP = the Godot slot wrapper, machine load ~7.5 with other agents):
  TOTAL 128, 121 pass, 7 fail on the first pass: t_buildspeed, t_eyetrails, t_perfgates (perf budgets
  under load), t_save (`.corrupt-*` collision in the shared user:// dir), t_tribe, t_levelfx, t_uigather
  (frame timing). All 7 PASS when rerun (r15/r16). t_levelfx and t_uigather also PASS on a clean
  worktree of the base commit 0fea2471, and pass on this branch when rerun. So fail=0 after reruns,
  not in one single pass.
- `bash tools/smoke.sh --no-import`: SMOKE PASS (final code).
- New tests: `game/tests/t_bagui.gd` (rail filter, sort level/rarity/newest, lock blocks trash single
  and batch, header counts the worn backpack, currency bar, chest deposit / withdraw by selection with
  a 2-slot chest and a locked item, perk tier roll + inheritance + roman labels, card tags / craft into /
  swatches, tendon tags + eat + bowstring recipe, Warp Gem sailing spend + refusal), `game/tests/
  t_eatqueue.gd` (badges 1-2-3 and renumbering, Eat (3) in order, overfull stops the queue with a
  notice, three single eats in a row). Changed tests: t_invscreens, t_rareattr, t_alphas, t_gather,
  t_controls (Trash label / tier values), uimarket_checks (equipped red + not pickable, median even /
  odd / empty, going-rate prefill, + step).
- PNGs (`--lab=bagui_lab`, windowed at `--position 6000,3000`), looked at and iterated:
  `docs/orchestration/reports/bagui/bag_detail_{1600x900,844x390}.png`,
  `chest_bag_tab_*.png` (numbered badges, "4 Select", Deposit), `chest_tab_*.png`,
  `market_sell_*.png` (equipped knife and locked stone red, going rate).
- Lab note: `[baguilab] rummage=idle`: this branch has no `rummage.glb`, so the hook held idle as
  designed. Canon has since merged rummage, rummage_in and rummage_out clips; the hook plays
  `rummage` only (in/out transitions not wired).

## Merge with origin/claude/mmo-overhaul (a67768b3+, 2026-10-29; Milan approved landing)
- Conflicts resolved: `objectives.json` (canon's tutorial list kept; the +10 Warp Gem grant moved to
  its `tut_knife` step as well as the old `knife` step), `rigged_model.gd` (canon's LOOPING list),
  `market_harness.gd` (canon's earn 40 kept; my 30 dropped; equip_first kept, env hack removed).
- `Food.can_eat`: canon's EATFIX and mine merged as one version.
- `Crafting.recipes_accepting` (CRAFTRADIAL) now checks slots through `ItemTags.has_tag`.
- Rummage: the bag hook now plays canon's `play_rummage`: rummage_in -> rummage loop -> rummage_out.
- Found by run_all after the merge: tagging the tendon `meat` made a poisoned carcass drop it. The
  spoiled-carcass filter (`LootRoller` x2, `CarcassParts`) now drops `raw_meat` only (every carcass
  meat carries it), so tendons stay a counter material.
- Reran: t_bagui, t_eatqueue, t_invscreens, t_rareattr, t_alphas, t_gather, t_uimarket, t_controls,
  t_craftradial, t_stationstate, t_outputs, t_invslots, t_bags, t_backpacks, t_uiicons, t_butcher,
  t_boneparts, run_all: all PASS. `tools/smoke.sh --no-import`: SMOKE PASS.
