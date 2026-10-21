# INVUI report (spec 13: Durango Bag, Character -> Gear, Equipment / My Info)

Branch `claude/mmo-invui` (work tree `.claude/worktrees/mmo-invui`), stacked on `claude/mmo-w2-inv`. Design:
`docs/orchestration/mmo/invui-spec.md`. Hooks: `docs/orchestration/reports/claude-mmo-invui-hooks.patch` (created by B1 with
the first hooked change; the design step changes no file outside INVUI's own).

## Design step (2026-10-20)

Shipped:
- Base sync: W2-INV is not merged into claude/mmo-overhaul, so `claude/mmo-w2-inv` (5ff239a6) was merged; its hooks patch
  is unchanged since "Apply W2-INV hooks (INVUI base)" (3ecb02ca), so nothing was re-applied.
- `docs/orchestration/mmo/invui-spec.md`: component tree with files, palette / type scale / metrics, procedural texture
  plan, API contract, data each element reads, commands and the exact hook list, screen layouts, optional save fields,
  22 assumptions with doc checks, the measurable acceptance checklist and the B1-B4 phase plan.
- `game/data/inv_ui.json`: sort keys, filter groups, spec 04 attribute classes, 3x3 equipment layout and silhouettes,
  preset unlock levels, power groups, picker warn level.
- `game/scripts/dev/bag_ui_lab.gd` + `game/scenes/dev/bag_ui_lab.tscn`: deterministic survivor, bag 91 / 100 (berries
  Lv. 12/25/42 with a rare trait, raptor bones Lv. 45/60 with Firm / Low Density / Black Sheen, herb leaves, a 4-slot
  caged zebraceratops, workbench kit, knife, club, slingshot, pick, axe, shirt, cuirass, helm, forager set), 10 NEW,
  2 locked, hood + vest worn, pick held, a bonded raptor with 3 cargo items, a 60-slot storage box; `--screen=bag | inspect
  | character | equipment | storage | cargo | picker`; headless contract check and per-screen open times.
- `game/tests/t_invui.gd`: spec 13 section 23 items 1-20 against the section 4 contract.

Checks run on this commit:
- t_invui: exit 1, "[t_invui] 20 failures" (expected skeleton: every item fails, e.g. "FAIL 3 individual: not built yet
  (inventory_grid.gd, inventory_slot.gd)", "FAIL 12: a container opens the shared Bag | Storage split view"), 0 SCRIPT ERROR.
- bag_ui_lab headless: exit 1, "[bagui] seed bag 91/100 worn=2 new=10 locked=2" then "FAIL InventoryUI.open_bag exists"
  etc. (expected skeleton).
- Base shot (old grouped bag, for the A/B "before"): 1600x900 gl_compatibility, opened and looked at: 5-column grouped
  grid with symbol icons and "×N" captions, CHARACTER header, inert GEAR 1/2/3 row.
- Base shot at 844x390 gl_compatibility, looked at: the old bag scrolls, profile column crowds the grid.
- Gates on 8f3d8a3d (merged W2-INV + design files): t_ai, t_build, t_canim, t_combat, t_harbour, t_iconart, t_inventory,
  t_items, t_lighting ("[t_light] PASS"), t_occlude, t_player, t_save (5 deliberate SCRIPT ERRORs), t_server_domain,
  t_srvdom, t_structart, t_tame, t_ui, t_web all PASS; run_all "[tests] PASS"; tools/smoke.sh --no-import "SMOKE PASS";
  no new Godot-*.ips (25 before and after). t_uiicons FAILED on the inherited W2-INV hook line
  "inventory_ui.gd:444 symbol ‹ (U+2039) has no icon mapping"; fixed here ("< All"; the grouped view goes in B1) and
  rerun: "[t_uiicons] PASS ids=169 files=114 ...".

Assumptions: spec section 9 (1-22). Owner questions (non-blocking): spec section 12.

Next (B1): build the Bag and inspection per spec section 11, create the hooks patch, turn t_invui 1-11/18/20 green.

## B1: Bag and item inspection (2026-10-20, spec 13 sections 4-12, phases 1-2)

Base sync: W2-INV is still not merged into claude/mmo-overhaul, so `claude/mmo-w2-inv` (80b335c1) was merged (1e857f46).
Its hooks patch had one new non-UI hunk since "Apply W2-INV hooks (INVUI base)": crafting default picks sorted by
`Inventory.spend_key`; re-applied and committed (619aad93). Its inventory_ui.gd hunks are superseded by this rewrite and
were not re-applied (design section 6).

Shipped (commit 410c38df, all under `game/`):
- `scripts/ui/inv_theme.gd` (InvTheme): spec 13 palette (#101714 backdrop, #080809 header, grid panel #3A3530, #26322C
  inspect, #E6BE54 brackets, #F2C84C primary, #176897 NEW, gold / grey / green traits), `metrics(view)` per canvas,
  a condensed FontVariation of the project font (no download), button boxes, the shared grain material.
- `scripts/ui/inv_grain.gdshader`: hash-noise mottling, fine grain, sparse scratches, vignette (FRAGCOORD, no
  NoiseTexture2D); Forward+ and gl_compatibility shots match.
- `inv_paint.gd` (InvPaint) and `inv_glyphs.gd` (InvGlyphs): art fitted to its opaque rect, grey "Lv. N" top-right, blue
  NEW top-left, four yellow L brackets sized from one compartment (a 2x2 cage keeps single-cell weight) and drawn last,
  green rare corner, white lock pip, wear bar, "×N" for fungible stacks; white select / funnel / caret glyphs.
- `inventory_slot.gd` + `inventory_grid.gd` (InventorySlot, InventoryGrid): one textured panel, dashed compartment lines,
  one cell per instance, empty compartments exactly up to capacity, cage 2x2 and span-2 items 2x1 by first-fit packing,
  selection by uid (or "#slot" for an ammo stack) that survives refreshes, sorts and filters and clears when the item
  leaves, multi-select, ScrollContainer (wheel and drag), deferred refresh, nothing rebuilt while hidden.
- `inv_view.gd` (InvView): view-only order for Acquired / Name / Type / Level / Rarity / Attributes / Durability and the
  data filter groups. `inv_attributes.gd` (InvAttributes): spec 04 classes from `data/inv_ui.json`, technical keys hidden.
- `inv_actions.gd` (InvActions): valid actions per item and context (berry: Eat, Quick Food 1/2, Feed Pet with a pet out;
  weapon / armour: Equip; work tool: Hold; kits: Place; locked: nothing but Unlock); every one runs a PlayerActions
  verb; `sell_handler` / `drop_handler` hook points (unset: Sell on Market and Drop are not shown).
- `inv_new_tracker.gd` (InvNewTracker): NEW on uid'd instances entering the bag in play, never on fungible stacks, never on
  a load (`rebaseline`, hooked into save_game).
- `capacity_indicator.gd`, `inv_header.gd`, `bag_toolbar.gd`, `item_inspect_panel.gd`, `bag_screen.gd`: the reference
  layout (header 80 / toolbar 96 at 1600x900, 7 columns of 157 px, 4.4 rows visible, inspect 451 px; 44 / 48 / 84 px and
  3.4 rows at 844x390). Toolbar: Auto Sort (applies the caret's key, Type by default), caret menu of sort keys, Select
  (multi), Filter (menu of groups), Lock (locks the selection, shows Unlock when it is all locked). Inspect: tan title
  band, card (art, type, Lv), black Info bar, key/value rows (type, count, processed, durability cur / max, damage,
  armour, max health, tool power, energy, raw, poisoned, buffs, held tool, locked), Positive / Negative / Rare sections,
  first valid action as the yellow primary along the bottom (aligned with the toolbar), the rest dark two a row.
- `storage_screen.gd` (StorageScreen, minimal until B3): Bag grid beside the container grid with per-side capacity,
  yellow Store / Take, Take All, read-only reason in grey.
- `inventory_ui.gd` (InventoryUI) rewritten as the host (810 -> 254 lines): same public API (bind idempotent, show_storage,
  show_pet_bag, hide_ui, rebuild, visible, inventory, pet_bag, _selected, _storage_opts, _select, _can_store_selected,
  _store_selected, _take_storage, _take_all_storage) plus open_bag, select_uid, current_screen, layout_blocks. Setting
  `visible` (I key, HUD Bag entry) opens the Bag; "<" and X and Esc close it.
- `tests/t_invui.gd`: harness fix (its `_process` returned true, which quit the tree on the second frame before any test
  that awaits finished; "exit 0" with no verdict line), size check skips scrolled content, test 7 reads the club's real
  name and durability. `scripts/dev/bag_ui_lab.gd`: B1 contract (B2/B3 screens print SKIP), seed is not a pickup, B1
  checks (cells, inspect, refresh time), `--select=<role>`.

Acceptance lines (this commit + hooks applied in the work tree):
- t_invui exit 1 with only the B2/B3 items: "[t_invui] FAIL 14 stats: not built yet (inv_stats.gd)", "FAIL 15 presets",
  "FAIL 16 rare bone", "FAIL 17 berry cook", "FAIL 19 save/load", "[t_invui] 5 failures", 0 SCRIPT ERROR. Items 1-13, 18
  and 20 pass (20 at 1600x900, 844x390 and 804x452: 44 px targets, 56 px contextual, no clipped or off-screen label).
- bag_ui_lab headless: "[bagui] open times bag=1078us, inspect=2046us, ..., storage=5882us, cargo=3236us",
  "[bagui] grid refresh 100=975us 142=1222us", "[bagui] PASS bag=91/100 new=10 locked=2", 0 SCRIPT ERROR.
- inventory_lab "[invlab] PASS slots=100 cells=100 stones=16 equip_l30=true"; ui_family_lab "[uifamily] inventory=true
  animals=true ..."; ui_screenshot_lab "[uishot] PASS ..."; ui_real_capture_lab 844x390 glc and 1600x900 glc
  "[uireal] PASS screens=...bag,..." with "[uireal] bag blocks: header=0,0 844x44 grid=8,50 590x280 toolbar=8,334 590x48
  inspect=604,50 232x332".
- Gates, final run on 410c38df + the hooks patch applied: t_ai, t_build, t_canim, t_combat, t_harbour ("PASS islands=15"),
  t_iconart, t_inventory, t_items, t_light, t_lighting ("[t_light] PASS"), t_occlude, t_player, t_save (5 deliberate
  SCRIPT ERRORs, "[t_save] PASS"), t_server_domain, t_srvdom, t_structart, t_tame, t_ui, t_uiicons ("[t_uiicons] PASS
  ids=169 files=114 ..."), t_web all PASS with exit 0; t_invui as above (B2/B3 items only); run_all "[tests] PASS";
  tools/smoke.sh --no-import "SMOKE PASS". Labs: bag_ui_lab, inventory_lab, ui_family_lab, ui_screenshot_lab ("[uishot]
  PASS ..."), ui_real_capture_lab 844x390 and 1600x900 glc ("[uireal] PASS ...bag...") all 0 SCRIPT ERROR.
- Crash reports: 7 new Godot-*.ips appeared between 20:10 and 20:20 (27 before this step, 34 after), all SIGABRT from a
  `recursive_mutex::lock` throw on the main thread. None lines up with a run of mine: every Godot run in this step
  returned 0 or 1 with its verdict line, and an abort returns 134; the other workflow shares the machine's Godot slots
  and the same responsible process, so the reports cannot be attributed from their contents. Not proven either way.

Shots looked at (each opened next to `durango-bag-instances.webp`; scratchpad `invui/b1f/`, not in the repo):
bag (cage selected) and inspect (Lv. 60 bone selected) at 1600x900 gl_compatibility and Forward+ and 844x390 glc; Bag
with the Lv. 25 berry selected at 1600x900 and 844x390 and with the knife at 844x390 (action layouts); storage and
cargo at 1600x900 glc / Forward+ and 844x390 glc; the real-scene bag from ui_real_capture_lab at 844x390. Matches:
black header "< Bag [yellow bag] 91 / 100" with a grey slash and a T-stone chip and X, dense 7-column textured grid with
faint dashed compartments, NEW blue top-left and grey "Lv. N" top-right on every cell, yellow L brackets on the selected
cell only (the selected cage keeps its NEW like the reference), 2x2 cage, wide dark Auto Sort with its caret, three
bottom-right squares, inspect panel with a tan title band, card and black Info bar, yellow primary level with the
toolbar. Fixed after looking: values hidden behind a zero-width label, NEW tag under the bracket corner, rare corner
and lock pip under the brackets, cage brackets twice as heavy as a cell's, the HUD rail showing through a 96 %
backdrop (now opaque), the scrollbar over the value column, an ellipsized empty-bag summary at 844x390, the HUD's
arrow as the back glyph (now Durango's thin "<"). Differences left for B4: the reference's panels are blotchier and
warmer (blurred world behind), its torn edge is a lighter ragged strip; the captured animal has no rendered art yet
(white symbol fallback; ICONS2).

Assumptions added in B1 (design section 9 has 1-22):
23. NEW clears when the selection moves on or the bag closes, not on the tap itself (the reference shows the selected
    cage still NEW); refines 3.
24. `InvActions.run(&"lock")` toggles; the toolbar square locks a mixed selection and unlocks an all-locked one; Lock
    is not repeated in the inspect panel (the toolbar is Durango's place for it).
25. The bag family's backdrop is opaque #101714 (at 96 % the HUD rail read through the storage screen).
26. A caged animal is titled by its species ("Zebraceratops", as the reference titles the cage) with "Captured Animal"
    as its kind and a grey "Bond it at a taming pen" row; no bag action (bonding happens at a pen; no inert Form Bond).
27. Grid panel #3A3530: spec 13's #39392F warmed toward the reference brown.
28. The Auto Sort button applies the caret's key (Type until another is picked); the view starts in bag order
    (Acquired). Sort and filter are session state on the open family, never saved.
29. A caged animal (slot_span 4) now gets a uid on add like every other instance (W2-INV minted none on the span path,
    so it could not be selected or sold by uid).
30. Storage and cargo are a minimal shared-grid split in B1 (Store / Take / Take All); B3 adds per-side sort and filter
    and the inspect overlay.

Hooks (`docs/orchestration/reports/claude-mmo-invui-hooks.patch`, 9 files, applied uncommitted in the work tree, made
against 619aad93):
- `player/player_actions.gd`: `equip_at(index, slot)`, `unequip(slot)` (both refresh equipment vitals offline),
  `hold_tool(index)`, `set_locked(index, on)`; online `act.eat` body is `{bag_slot}` (the server's contract), equip /
  unequip / hold send `act.equip {bag_slot}` / `{slot, clear: true}`; lock queues `act.lock` (no server op yet: W3).
- `items/inventory.gd`: `find_first` / `find_by_category` / `consume` / `consume_by_category` skip locked instances;
  `_mint` on the span path of `add`.
- `items/crafting.gd`: a locked lead is refused in `_plan` (so `picks_valid` / `consume_for_craft` refuse it).
- `core/save_game.gd`: `InvNewTracker.rebaseline(player.inventory)` before `load_array`.
- W2-INV `dev/inventory_lab.gd`: grouped-view asserts replaced with one cell per instance (100 cells, 16 stones, the L30
  helm equipped through the inspect panel).
- W1-UI `dev/ui_screenshot_lab.gd`, `dev/ui_family_lab.gd`, `dev/ui_real_capture_lab.gd`: the bag is read through
  `current_screen()` / `layout_blocks()` (grid, toolbar, inspect inside the view, no overlap, inspect beside the grid);
  the profile level / title asserts move to the Character screen in B2.
- `tests/t_ui.gd`: the 16 INVUI ui files join OWNED (type floor, no emoji, consts first, levels via LevelDisplay).

Limits: Character, Equipment, presets, stats (B2), exact-instance craft / cook picker and full storage (B3) are not built;
Bag "Equip" wears the item directly until B2's compare screen exists. Sell on Market / Drop stay hidden until
W3-EXCHANGE / the drop owner set the handlers. Keyboard shortcuts beyond I / Esc and the panel motion are B4. Online,
Lock is only queued (no server op). Owner questions: design section 12 (unchanged).
