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

## B2: Character -> Gear, presets, Detailed Stats, Equipment / My Info (2026-10-20, spec 13 sections 13-15, phase 3)

Base sync: W2-INV is still not merged into claude/mmo-overhaul, so `claude/mmo-w2-inv` (c7e1b323, its review round 1)
was merged. Its hooks patch changed since "Apply W2-INV hooks (INVUI base)" in two non-UI files, re-applied and committed
(ef45166f): the item tip names traits instead of printing the attribute dict (item_stack.gd); the server splits stacked
characters after the journal replay and hashes data/inventory.json (character_store.gd). Its new inventory_ui.gd hunks are
superseded by INVUI; their intents are kept: a refused unequip says "Bag is full." (Character screen note and HUD notice)
and `_can_store_selected` no longer looks for worn gear in the bag. INVUI's hooks were rebuilt on the new base (W2-INV
renamed `_mint` / `_place_span` to `mint` / `place_span`).

Shipped (dffebd6d, c25b855c and the B2 report commit; all under `game/`):
- `scripts/ui/inv_stats.gd` (InvStats): Attack = Hunt's own `_swing_damage` with the worn weapon x the Melee bonus;
  Defense = (base 20 + worn armour) x status mult, the number a creature bite reads; Accuracy; crit; max health (vitals
  max + worn health bonus); energy; bag capacity; held tool power; heat / cold resistance; the three powers. Every number
  is computed from what is worn now, so nothing adds twice. `with_candidate` runs Inventory's own `equip_at` on a copy of
  the bag, so the preview is the outcome by construction; `diff` lists what changes.
- `scripts/items/gear_presets.gd` (GearPresets): numbered loadouts by uid (7 equipment slots + the held tool) on
  `Inventory.presets`; unlock levels from data (1 / 10 / 30 / 50); `switch` keeps the current gear in the active preset,
  then puts the chosen one on through PlayerActions; refused whole when the bag cannot take what comes off; `sanitize`
  for saves. Compiles without the hooks (untyped access, like InvActions).
- `scripts/ui/equipment_slot.gd` (EquipmentSlot): one dark gear cell; empty = faded silhouette (the slot's item art
  through HexButton's white material; a ring glyph for accessories); worn = real art, grey "Lv. N", wear bar; yellow
  brackets when selected; `grid()` / `layout()` build the data 3x3, cells filling their panel (taller on Equipment, as in
  reference 3).
- `scripts/ui/gear_preset_selector.gd` (GearPresetSelector): "1 2 [lock] [lock]", the active one bracketed.
- `scripts/ui/gear_screen.gd` (GearScreen): what both screens share: the header, the nine cells, the right column on the
  shared InventoryGrid filtered to the cell (`slot:<cell>`, the worn piece pinned first with a green worn mark), the
  targeted piece's properties ("Forager Vest Lv. 12 / Armor 207 · Durability 470 / 470", traits too), one yellow action
  (Unequip / Equip / Hold) and the reasons in grey ("There are no items available to equip.", "Locked: unlock it in the
  Bag to wear it.", "Bag is full.", "Preset 4 unlocks at Lv. 50.").
- `scripts/ui/character_screen.gd` (CharacterScreen): portrait (one-shot SubViewport render of the survivor model), name,
  occupation, green XP bar "Lv. 13 (222 / 400)" with the XP yellow, Combat / Crafting / Gathering Power rows (white icon,
  yellow value, ">" opens Detailed Stats at that group), Detailed Stats; the yellow Gear tab, the preset row, the title
  strip (desktop), the 3x3; candidates over Unequip. Picking a bag candidate opens Equipment to compare.
- `scripts/ui/detailed_stats_panel.gd` (DetailedStatsPanel): Combat / Crafting / Gathering / Survival groups (data): the
  InvStats rows, the group's power, its skill levels; "<" back to Character, Esc too.
- `scripts/ui/equipment_screen.gd` (EquipmentScreen): 3x3 on the left; the tan My Info band over Attack / Defense /
  Accuracy (dark icons on khaki, black label bands, big numbers, as reference 3); the tactic hexes (tackle, kick, roll; a
  tap shows the line with stamina and cooldown from combat_tuning.json); candidates over Equip. A picked candidate shows
  the new number large, gold for a gain and grey for a loss, "321 → 1102 +781" under it (the sign carries the meaning),
  then "Replaces: Forager Vest Lv. 12" and every other change ("Max health 100 → 156").
- Shared parts: `inventory_ui.gd` gains `open_character(slot)`, `open_equipment(slot, uid)`, a back stack (Bag ->
  Equipment -> "<" Bag; Character -> Equipment -> "<" Character), Esc closes Detailed Stats first, `layout_blocks()` for
  the gear screens. `bag_screen.gd`: Equip on gear opens Equipment with that instance picked (Hold on a work tool still
  acts at once). `inv_actions.gd`: the equipment context (worn -> Unequip; candidate -> Equip / Hold; locked -> none),
  the cell passed through as the slot, "Bag is full." on a refused (un)equip and `last_refusal` for the screens.
  `inv_view.gd`: the `slot:<cell>` filter and `fits_slot`. `inventory_grid.gd`: `pinned`, `worn_uid`, `min_rows`.
  `inventory_slot.gd` / `inv_paint.gd`: the worn mark. `inv_glyphs.gd`: ring, target, chevron. `inv_header.gd`:
  `show_stones` (no T-stone chip on Character / Equipment, as in the references). `data/inv_ui.json`: `detailed_stats`
  groups, `hex_tactics`.
- Tests and lab: t_invui 13 (Character lists the three bag instances that fit; picking the Lv. 30 vest opens Equipment
  with it picked; Equip wears that uid, not the first; "<" returns to Character; Unequip; the held-tool cell's Hold and
  Unequip), 14 (Defense rises by the armour once; a second refresh changes nothing; a swap counts only the new cuirass;
  unequip restores every number; max health equals the vitals'; Attack equals Hunt's swing number with the worn knife;
  the preview predicts without equipping), 15 (unlock counts; capture / apply put the same uid back; switch copies, keeps
  a bare head per preset, refuses preset 3 until Lv. 30; the selector shows 2 earned and says "Lv. 50" for preset 4), 19
  (presets round-trip; a bag that never used presets saves none; a forged presets row is cleaned), 20 (Character,
  Equipment in the compare state and Detailed Stats at 1600x900, 844x390 and 804x452: 44 px targets, 56 px actions, no
  clipped or off-screen text). bag_ui_lab: `open_character` / `open_equipment` are contract now; `--screen=equipment
  --select=<role>` opens that item's cell with it picked, `--slot=<cell>`, `--stats=<group>`; the seed reads Lv. 13;
  `_check_gear` runs Equip from Character's pick, a second Equip (a swap) and the vest back on, comparing every number
  with the start and with the preview.

Acceptance lines (B2 code + the hooks patch applied in the work tree; logs in the scratchpad `invui/b2/gates2/`):
- t_invui: exit 1 with only the B3 items, "[t_invui] FAIL 16 rare bone: not built yet (item_picker.gd)", "[t_invui]
  FAIL 17 berry cook: not built yet (item_picker.gd)", "[t_invui] 2 failures", 0 SCRIPT ERROR. Items 1-15, 18, 19 and 20
  pass (13-15 and 19 newly, 20 now also on Character, Equipment and Detailed Stats). Rerun after the last edit
  (an unused hook removed from gear_screen.gd): same two lines, 0 SCRIPT ERROR.
- G1-G3 / S1: t_invui 13-15, 19 as above; bag_ui_lab "[bagui] gear stats defense start=321 cuirass=1102 shirt=156
  back=321" (the cuirass preview equals the result; the shirt swap counts only the shirt; the vest back restores every
  number), "[bagui] open times bag=1169us, inspect=1797us, character=6931us, equipment=4835us, storage=5540us,
  cargo=2746us", "[bagui] PASS bag=91/100 new=10 locked=2", 0 SCRIPT ERROR.
- Every t_*.gd: t_ai, t_build, t_canim, t_combat, t_harbour ("PASS islands=15"), t_iconart, t_inventory, t_items,
  t_light, t_lighting ("[t_light] PASS"), t_occlude, t_player, t_save (5 deliberate SCRIPT ERRORs, "[t_save] PASS"),
  t_server_domain, t_srvdom, t_structart, t_tame, t_ui ("engine errors/warnings during the checks: 0", "[t_ui] PASS"),
  t_uiicons ("[t_uiicons] PASS ids=169 files=114 ..."), t_web all exit 0 with PASS; t_invui as above.
- run_all "[tests] PASS"; tools/smoke.sh --no-import "SMOKE PASS".
- Labs, 0 SCRIPT ERROR each: inventory_lab "[invlab] PASS slots=100 cells=100 stones=16 equip_l30=true
  full_unequip_notice=true" (W2-INV's full-bag check now through the Character screen); ui_family_lab "[uifamily]
  inventory=true animals=true ..."; ui_screenshot_lab "[uishot] PASS ..."; ui_real_capture_lab 844x390 and 1600x900
  gl_compatibility "[uireal] PASS screens=...,bag,character,charcreate,..." with "[uireal] character blocks: header=0,0
  844x44 gear=329,146 285x234 list=621,50 215x260" and "header=0,0 1600x80 gear=627,328 534x555 list=1177,96 407x668".
- Crash reports: 34 Godot-*.ips before this step and 34 after.
- One engine line to know about: the headless bag_ui_lab prints `ERROR: Parameter "material" is null.` from
  `material_get_instance_shader_parameters` (servers/rendering/dummy). Bisected to the lab's gear check (gone when it
  does not equip); most likely the worn-armour mesh swap PlayerEquipment does on a real equip under the dummy renderer.
  Not a SCRIPT ERROR; not seen in t_invui, inventory_lab or the windowed runs.

Shots looked at (scratchpad `invui/b2/`, not in the repo; each opened next to its reference):
- `character_1600x900_glc.png` and `_fwd.png`, `character_844x390_glc.png` next to durango-character-gear.webp: black
  header "< Character" and X; left card with the portrait square, name, grey status, green XP bar "Lv. 13 (222 / 400)"
  with the yellow XP, three power rows with white icons, yellow values and ">" over dashed separators, outlined Detailed
  Stats; yellow Gear tab, "1 2 [lock] [lock]" with brackets on 1, the title strip, 3x3 with faded silhouettes and the
  worn hood, vest and pick, brackets on the torso; right column with the worn vest marked green top-left, the two other
  torso pieces, their numbers and the yellow Unequip. Fixed after looking: the panel grain covered the card's own
  drawing (name, XP bar, Gear tab were invisible), a strip of panel under the 3x3, the status line touching the name.
- `equipment_1600x900_glc.png` and `_fwd.png`, `equipment_844x390_glc.png` (cuirass picked) and
  `equip_empty_1600x900_glc.png` / `_844x390_glc.png` (accessory cell) next to durango-equipment-myinfo.webp: tall 3x3
  cells, tan My Info band, dark Attack / Defense / Accuracy icons on khaki over black label bands and big numbers, the
  hex row, "There are no items available to equip." centred in the empty column. Fixed after looking: the compare line
  "321 → 1102 +781" ran into "Replaces: ..."; the properties note overflowed into Equip at 844x390 (now sized to its
  wrapped lines).
- `stats_1600x900_glc.png`, `stats_844x390_glc.png`: Detailed Stats grouped; fixed after looking: every value was
  hidden (clipped labels shrink to zero width) and the group scroll landed one group early.
- `uireal844/character_844x390.png` (real scene, a fresh survivor: all silhouettes, empty column note) and
  `uireal844/sheet_menu_844x390.png` (the HUD Menu sheet with Bag and Character).
Differences left: the reference portrait is a painted face, ours is a render of the base survivor model (no worn
armour on it); reference hexes are flat-topped and one is a red locked tactic, ours are the HUD's pointy hexes and none is
locked (nothing gates a tactic); reference 3 has no "<"; the Gear tab has no Decorative Gear neighbour; the panels are
less blotchy than the reference (B4).

Assumptions added in B2 (design section 9 has 1-22, B1 23-30):
31. A bag candidate picked on Character opens Equipment with it picked (compare before wearing); the worn piece is listed
    first with a green top-left mark, and the action applies to it while nothing else is picked.
32. The held-tool cell lists the bag's work tools; Hold holds that exact one, Unequip lets go (gathering picks the best
    tool again). Offline through a new `PlayerActions.unequip(&"tool")` branch; online the server's existing
    `act.equip {slot: "tool", clear: true}`.
33. Presets: switching first keeps the current gear in the active preset; an unsaved preset starts as a copy of the
    current gear; applying takes off worn gear the preset does not name; a preset item no longer in the bag is skipped;
    the switch is refused whole when what comes off has no free bag slots; a locked preset says "Preset N unlocks at
    Lv. X." in the column note. Unlock levels 1 / 10 / 30 / 50 stay in data (owner question unchanged).
34. The reference's "No Title ▶" selector is the held title as plain text (no title choice exists); on phones the title
    joins the status line.
35. The portrait is a one-shot SubViewport render of survivor.glb (base model, not the worn armour); headless shows the
    survival icon instead.
36. My Info icons are dark on a lighter khaki panel (#5A5846) as in the reference; Accuracy uses a drawn target (no icon
    in the set).
37. The hex row is tackle, kick, roll (data `hex_tactics`); a tap shows one line with stamina and cooldown from
    combat_tuning.json; none is locked. Tapping does not fire the tactic (the screen is a modal; the HUD fires them).
38. Compare: the new number large, gold for a gain and grey for a loss, "old → new ±d" under it; other changes listed
    under "Replaces: <current item>"; a locked candidate gets no Equip and "Locked: unlock it in the Bag to wear it."
    (equipping a locked item is refused by the existing rule).
39. Detailed Stats is an overlay of Character (groups in data); "<" or Esc returns to Character.
40. Attack is Hunt's swing damage with the worn weapon (or, like Hunt, the first weapon in the bag) x the Melee bonus,
    before the target's defence and crits; Defense is what a creature bite reads; Accuracy before the target's dodge.
41. No T-stone chip on Character / Equipment (references); Equipment keeps "<" because it goes back to where it was
    opened from.
42. The worn / candidate piece's properties (damage, armour, max health, tool power, durability, traits) show over the
    action (spec 13 s14 "provide its properties and an Unequip action").

Hooks (`docs/orchestration/reports/claude-mmo-invui-hooks.patch`, regenerated on c25b855c, 11 files; `git apply --cached
--check` passes on HEAD and it is applied uncommitted in the work tree). New or changed in B2:
- `items/inventory.gd`: `var presets: Dictionary`; `extras_to_dict` writes `"presets"` only when non-empty;
  `extras_from_dict` reads it through `GearPresets.sanitize`; B1's span-path uid uses W2-INV's renamed `mint` /
  `place_span`.
- `core/save_sanitizer.gd`: `inventory_extras.presets` in SHAPE (a non-Dictionary is dropped).
- `player/player_actions.gd`: `unequip(&"tool")` lets go of the held tool offline.
- `ui/hunt_hud.gd`: the Menu sheet's "Character" entry -> `player.ui.open_character()`.
- `tests/t_ui.gd`: the 7 B2 ui files join OWNED (type floor, no emoji, consts first, levels via LevelDisplay).
- `dev/ui_real_capture_lab.gd`: Character screen blocks inside the view, its `profile_lines()` carry
  `LevelDisplay.player_label()` and the held title (the old bag profile asserts moved here), a `character` shot.
- `dev/inventory_lab.gd`: the Bag's Equip opens Equipment, Equip there wears the L30 helm; W2-INV's new checks kept
  through INVUI: a full bag refuses Unequip on Character with "Bag is full" in the HUD notice and the screen note, and
  the inspect panel shows no raw attribute dict.
- Unchanged from B1: save_game.gd rebaseline, crafting.gd lock refusal, ui_family_lab / ui_screenshot_lab.

Owner gates: none new. Presets is an optional save field old saves load without (written only once used, so the t_save
goldens are unchanged); no money or authority change (online gear changes use the server's existing act.equip).

Limits: exact-instance craft / cook picker and full storage are B3 (t_invui 16-17 fail by design; done in B3 below). No accessory or
cosmetic gear exists, so the accessory cells only ever show the empty state and the Decorative Gear tab is not shown.
Presets are local: online, applying sends one act.equip per slot from the client's mirror and the server keeps no preset
record. The portrait does not show worn armour. Keyboard shortcuts beyond I / Esc, panel motion and the condensed font
pass are B4. Owner questions: design section 12 (unchanged).

## B3: storage, dinosaur cargo, craft / cook ingredient picker, market hook (2026-10-20, spec 13 sections 17-19, phase 4)

Base sync: W2-INV is still not merged into claude/mmo-overhaul, so `claude/mmo-w2-inv` (a2e9756b, its review round 2) was
merged. Its hooks patch changed since the last re-apply (c7e1b323) in six non-UI files; the delta (its new patch on a fresh
a2e9756b against its old patch, built in a scratch tree) was applied and committed (9d31fc95): duplicate uids reminted
across containers on load (save_game.gd), Butchering XP once per drop kind (corpse.gd, player_actions.gd), default picks
ordered by spend_key with the lead's def only as a tie-break and `plan_spends_traits` (crafting.gd), `output_fits` asks
`can_accept`, the server split skips uid-less rows (character_state.gd), a failed replay after a data change says what to do
(character_store.gd), and their tests (t_player, t_save). Its inventory_ui.gd hunks (empty bag slots, "L / U" pips on a
group, the "16 ..." group badge) are superseded by INVUI; their intents are kept: empty compartments up to capacity and the
lock pip on each cell (B1), and the unstable state as an inspect row ("Unstable  cargo warp it home", new here). INVUI's
hooks were rebuilt on the new base: crafting.gd's lock refusal moved into W2-INV's reordered `_plan`; inventory_lab.gd was
re-made over W2-INV's new checks (`--bag-fill`, empty compartments, the ×45 stack, the lock pip), one cell per instance.

Shipped (40b410b7, a4b452c7, 4694b105 and this report commit; all under `game/`):
- `scripts/ui/storage_screen.gd` (StorageScreen, rewritten): the Bag grid and the container grid side by side, each with a
  "Bag [bag] 91 / 100" strip and its own Auto Sort / Filter toolbar (BagToolbar with only the Filter square); the
  ItemInspectPanel runs down the right like the Bag's and shows the instance tapped last on either side (a tap on one side
  clears the other). Its yellow primary is the move: Store for a bag item; Take, with Take All beside it when the opener
  allows, for a container item; Take All alone with nothing selected. A grey line says why not (take only, locked, held
  tool, quick food) and the read-only reason ("Needs knife") hides Take. 5 columns at 1600x900, 3 on a 844x390 phone. No
  T-stone chip. Storage boxes, baskets and home cargo (basket path), corpse loot and dinosaur cargo all keep calling
  `show_storage` / `show_pet_bag`; InventoryUI keeps the transfer rules (`_store_selected`, `_take_storage`,
  `_take_all_storage`, `_can_store_selected`) unchanged.
- `scripts/ui/item_picker.gd` (ItemPicker, new): the Bag layout over one recipe slot: header "< Choose Fruit 1 / 1", the grid
  filtered to the slot's candidates (`Crafting.stacks_for_slot`; locked never listed; slots the recipe's other slots use left
  out), the least valuable instances preselected (`Inventory.spend_key`, W2-INV's order), multi-select when the slot takes
  several (a pick past the count replaces the earliest), the inspect panel on the instance tapped last with a red line for a
  rare trait ("Uses up a rare trait: Vivid Inspiration.", always) or a Lv. 40+ instance chosen over the least valuable,
  "Choose N more" until the slot is covered, "N locked, not listed: unlock in the Bag to use.", and the yellow Use that
  hands back the exact bag slots. Auto Sort works in it.
- `scripts/ui/inventory_ui.gd`: `open_picker(rid, slot_index, on_pick, taken := [], on_close := Callable())` (on_close runs
  once when the picker closes, picked or not, so the craft menu comes back), `current_screen() == &"picker"`, the picker's
  and both storage toolbars' menus in Esc's menu-first rule, `layout_blocks()` for storage (bag, container, both toolbars,
  inspect) and the picker, `_store_refusal()` for the storage panel's reason.
- Shared parts: `item_inspect_panel.gd` takes screen-owned `ctx.actions` / `ctx.notes` (wrapped, read in full) / `ctx.title`
  and shows the unstable state; `inventory_grid.gd` `only` (the picker's candidate set); `bag_toolbar.gd` `squares` (which
  right-hand squares show) and an Auto Sort width that fits its label; `inv_actions.gd` labels for Store / Take / Take All /
  Use, and Sell on Market closes the bag family first (the market opens on its own layer).
- Tests and lab: t_invui 12 (Store moves the exact bone through the panel's button; Food on the storage side hides it there
  and leaves the bag side on All; the box side offers Take and Take All; read-only loot shows "Needs knife" and no Take; a
  locked berry stays and says why; a raptor's cargo opens in the same view and Take moves that berry), 16 (the plain Lv. 45
  bone preselected with no warning, the Black Sheen bone warns, Use returns its slot, crafting consumes exactly it; then the
  real path `player.craft_recipe(&"slingshot", 1, picks)` -> PlayerActions -> StationCraft spends the chosen Lv. 60 bone and
  keeps the Lv. 45), 17 (berries pickable, Lv. 12 preselected, the Lv. 25 returned and cooked; then the craft menu: the twine
  detail's fibre button opens the picker over the hidden menu, two plain fibres preselected, a third pick replaces the
  earliest and warns at Lv. 40, Use brings the menu back, Craft spends exactly the chosen two; with only trait fibre left,
  Craft opens the picker instead of spending), 20 (storage in the cargo state and the picker in the warning state at
  1600x900, 844x390 and 804x452: 44 px targets, 56 px moves, no clipped or off-screen text). The new 16 / 17 test code fixed
  a skeleton bug: test 16 took default picks before the handle and lashing were in the bag, so its plan could never be
  valid. bag_ui_lab: `open_picker` joins the contract, `_check_b3` (store / take the Lv. 42 berry with its trait, take from the
  raptor's cargo, picker preselect / warning / exact return), roles `box_bone` and `cargo_berry`, `--recipe=` /
  `--recipe-slot=` for the picker and a shot-only `--screen=craft` (camp stew with the Lv. 25 berry chosen).

Acceptance lines (B3 code + the hooks patch applied in the work tree; logs in the scratchpad `invui/b3/`):
- t_invui on 4694b105: exit 0, "[t_invui] PASS", 0 SCRIPT ERROR (all 20 items; 12, 16, 17 and 20 newly cover B3).
- H1 / H2 / F1: t_invui 16, 17, 12 as above; bag_ui_lab "[bagui] b3 storage=store,take cargo=take picker=berry42
  bag=92/100", "[bagui] open times bag=1881us, inspect=3262us, character=13109us, equipment=8614us, storage=10547us,
  cargo=6126us, picker=5259us", "[bagui] PASS bag=92/100 new=11 locked=2", 0 SCRIPT ERROR. H3 (Sell): t_invui 18 unchanged
  (hidden with no market, the exact uid with one, never for a locked item).
- Every t_*.gd (run on 40b410b7 + hooks; the later commits touch only item_picker.gd and item_inspect_panel.gd, and t_invui,
  t_ui, t_uiicons, bag_ui_lab and inventory_lab were rerun after them): t_ai, t_build, t_canim, t_combat, t_harbour ("PASS
  islands=15"), t_iconart, t_inventory, t_invui, t_items, t_light, t_lighting ("[t_light] PASS"), t_occlude, t_player (W2-INV's
  new corpse take XP test through INVUI's `_take_storage` / `_take_all_storage`), t_save (5 deliberate SCRIPT ERRORs,
  "[t_save] PASS"), t_server_domain, t_srvdom, t_structart, t_tame, t_ui ("engine errors/warnings during the checks: 0",
  "[t_ui] PASS"), t_uiicons ("[t_uiicons] PASS ids=169 files=114 ..."), t_web all exit 0 with PASS.
- run_all "[tests] PASS" (exit 0, 0 SCRIPT ERROR); tools/smoke.sh --no-import "SMOKE PASS".
- Labs, 0 SCRIPT ERROR each: bag_ui_lab as above; inventory_lab "[invlab] PASS empty_cells=100/97 slots=100 cells=100
  stones=16 stack45=true lock_pip=true equip_l30=true full_unequip_notice=true"; ui_family_lab exit 0; ui_screenshot_lab
  "[uishot] PASS ..."; ui_real_capture_lab 844x390 and 1600x900 gl_compatibility "[uireal] PASS screens=...,bag,character,...".
- Crash reports: 34 Godot-*.ips before this step and 34 after.

Shots looked at (scratchpad `invui/b3/shots/`, not in the repo; each opened next to durango-bag-instances.webp, whose look
storage, cargo and the picker reuse):
- `storage_1600x900_glc.png` / `_fwd.png` (bag berry and box bone selected) and `storage_844x390_glc.png`: black torn header
  "< Storage Box" and X, two dense textured grids with faint dashed compartments, blue NEW and grey "Lv. N" on every cell,
  yellow L brackets on the selected cell only, a dark Auto Sort with its caret and a Filter square under each grid, the
  inspect panel with the tan title band, card and black Info bar, gold / green trait lines, and the yellow Store / Take level
  with the toolbars like the reference's Form Bond. Fixed after looking: NEW ran into "Lv. 12" in 72 px phone cells (now 3
  columns of ~97 px); "91 / 100" ran into "Storage Box" (the counts now follow their labels, "Bag [bag] 91 / 100").
- `cargo_1600x900_glc.png` / `_fwd.png`, `cargo_844x390_glc.png`: "< Velociraptor Cargo", the pet bag's 10 compartments, its
  berry selected with Take (no Take All for cargo).
- `picker_1600x900_glc.png` / `_fwd.png`, `picker_844x390_glc.png` (Lv. 42 berry chosen), `pickbone_1600x900_glc.png`
  (slingshot bone slot: only the Lv. 45 bone; "1 locked, not listed") and `picktwine_844x390_glc.png` (two fibres bracketed,
  "2 / 2"): the berries as three cells in a full compartment panel, brackets on the chosen one, the red rare-trait line over
  its rows, yellow Use. Fixed after looking: "1 / 1" sat below the title line; the warning was cut to "Vivid I..." on the
  phone (notes now wrap) and the wrapped lines then read as two rows (line spacing tightened).
- `stewmenu_1600x900_glc.png` / `_fwd.png`, `stewmenu_844x390_glc.png` (the W1-UI craft menu, not a Durango screen): camp
  stew's ingredients "Raw Meat 1/1", "Mushroom 1/1" and the chosen "Berry Lv. 25" in gold; on the phone the ingredients sit
  below the fold of the detail scroll (W1-UI's layout, unchanged).
Differences left: storage and the picker have no Durango reference of their own (spec 13 s17 asks for the Bag's
foundation); the craft menu around the picker keeps the W1-UI look; panel grain and torn edges are B4.

Assumptions added in B3 (design section 9 has 1-22, B1 23-30, B2 31-42):
43. Storage shows the inspect panel beside the two grids all the time (one-tap inspection, spec 13 s21) instead of the
    design's Inspect overlay button; its primary is the move that applies (design section 7 updated).
44. Each storage side has Auto Sort and Filter only; Select and Lock stay on the Bag. Columns keep NEW beside "Lv. NN":
    5 of ~108 px at 1600x900, 3 of ~97 px at 844x390.
45. A bag item that cannot be stored says why in grey: "Take only: nothing goes in.", "Locked: unlock it in the Bag to
    store it.", "Held tool: let go of it first.", "Quick food stays in the bag."
46. No T-stone chip on storage, cargo or the picker (long titles; the chip belongs to the Bag header).
47. Picker "least valuable" is W2-INV's `Inventory.spend_key` (plain before traits, lower level, older), the order default
    picks spend in; locked instances are never listed and their count is said.
48. Picker warning: a rare trait always (even when every candidate has one); Lv. >= data `picker.warn_level` (40) only for an
    instance chosen over the preselected least valuable ones (a plain Lv. 45 bone that is the least valuable does not warn).
49. A slot that takes several is multi-select; a pick past the count replaces the earliest; Use needs every chosen instance
    to be needed (no surplus).
50. The craft menu's detail ingredients are 44 px buttons that open the picker; the choice is kept by uid for that recipe,
    shown in selection gold ("Berry Lv. 25"), dropped when one of its instances leaves the bag or another recipe is chosen.
51. Craft opens the picker instead of crafting when the default plan would spend an instance with traits in a slot the
    player did not choose (W2-INV's `plan_spends_traits` intent; traits, not level, as W2-INV ruled).
52. A batch (Craft ×5) spends the chosen instances in its first job and the default (least valuable first) after; the station
    radial crafts with the default and does not ask.
53. Online, Craft sends `act.craft {picks}` with one lead slot per recipe slot (the server's existing contract); the server
    spends a multi-unit slot's other units least valuable first, so online exactness holds for single-unit slots.
54. Sell on Market closes the bag family before the handler runs (the market screen is its own full-screen layer).

Hooks (`docs/orchestration/reports/claude-mmo-invui-hooks.patch`, regenerated on 4694b105, 14 files; `git apply --cached
--check` passes on HEAD and it is applied uncommitted in the work tree). New or changed in B3:
- `items/crafting.gd`: a pick is an int (the lead, as before) or an Array of exact bag slots (each spent, nothing else; a
  chosen slot the recipe does not need refuses the plan); picks parameters typed `Array`; `lead_of(pick)`; public
  `plan(inv, rec, picks)`; the B1 lock refusal now sits in W2-INV's reordered `_plan` and covers every chosen slot.
- `items/station_craft.gd`: `begin(rid, count, picks := [])` refuses picks that cannot make it, keeps the chosen instances by
  uid ("#slot" for a stack) so other slots changing while the survivor walks do not matter, spends exactly them in the first
  job (`_job_picks`) and clears them after; the radial clears them; a chosen instance that left the bag stops the craft.
- `player/player.gd`: `craft_recipe(rid, count, picks := [])`. `player/player_actions.gd`: `craft(rid, count, picks := [])`
  (offline StationCraft; online `act.craft` with `Crafting.lead_of` per slot).
- `ui/craft_ui.gd` (W1-UI): pickable ingredient buttons in the detail pane, `_pick_ingredient` (hides the menu, opens the
  picker with the other slots' choices as `taken`, reopens on this recipe when it closes), `_set_chosen` / `_chosen_slots` /
  `_picks_for`, `_trait_slot`, `_start` asks or crafts with the picks.
- `tests/t_ui.gd`: item_picker.gd joins OWNED.
- `dev/inventory_lab.gd` (W2-INV): re-made on W2-INV review 2 (see the base sync above).
- Unchanged from B1 / B2: save_game.gd rebaseline, save_sanitizer presets, inventory.gd (presets, lock skips, span uid),
  player_actions equip / unequip / hold / lock / eat, hunt_hud Character entry, the W1-UI labs.

Market (spec 13 s18): no market screen exists on this base, so Sell on Market stays hidden (`InvActions.sell_handler` unset;
t_invui 18 checks both states and that a locked item is never sellable). W3-EXCHANGE's `MarketScreen.open(player, &"sell",
uid)` (claude/mmo-exchange) already takes the instance; once both are merged the integrator adds one line in hunt_hud.gd
beside W3-EXCHANGE's `_open_market()`:
`InvActions.sell_handler = func(uid: String) -> void: _open_market(); _market_screen.open(player, &"sell", uid)`
(the bag family closes itself first; Sell then lists that uid with the market's own icon, level and attributes).

Owner gates: none. No save field changes in B3 (picks and the craft session are not saved); no money; online crafting uses
the server's existing `act.craft {picks}` validation (the client starts sending the lead slots it chose).

Limits: process stations (W2-PROCESS's ProcessStation, not on this base) do not open the picker yet; it already takes picks,
so its owner can call `player.ui.open_picker` the same way. The station radial and the later jobs of a batch use the default
plan. Online, multi-unit slots are exact only for the lead (the server picks the rest; an exact list there is a server
change). NEW tags are cleared only on the Bag, not on the storage screen. Drop stays hidden (no drop owner on this base).
Keyboard shortcuts beyond I / Esc, panel motion, transfer feedback and the grain pass are B4. Owner questions: design
section 12 (unchanged).

## B3 redo: the owner's storage-transfer reference (2026-10-20, spec 13 s17-19 + addendum, phase 4)

The owner added a second inventory example after B3 ("Another example of the inventory menu",
`docs/reference/durango-storage-transfer.webp`, read in the addendum at the end of spec 13). It shows the storage view
as tabs, not the split B3 built, so this run rebuilt the storage / cargo view to it and moved the shared inspect panel
and cells to what both references show.

Base sync: W2-INV is still not merged into claude/mmo-overhaul, so `claude/mmo-w2-inv` (9fafad06, which had merged
overhaul ac33159f) was merged (adca6cc8). Its hooks patch changed since the last re-apply in one crafting.gd hunk (79a24337:
inside equal keys the lead's own def goes first); that delta (old patch vs new patch on the same crafting.gd, built in the
scratchpad) was applied and committed (0139d7c1); INVUI's crafting.gd hook merged over it with only a comment conflict.
A cut run had left uncommitted owned-file work in the tree (dark irregular panel frames `InvPaint.frame`, a khaki backdrop
between panels, olive / brown grain, a torn header fringe, the header inside the safe area via `insets`,
`InvTheme.forced_insets`); it was kept and committed with this step after the shots below, and its unused motion
constants (B4 work, nothing read them) were dropped.

Shipped (f74885c8, e618ad30 and this report commit; all under `game/` unless named):
- `scripts/ui/storage_screen.gd` (StorageScreen, rewritten to the reference): header "< Storage Box" (pet: "Velociraptor
  Cargo"; corpse: "Loot · Raptor") with the T-stone chip and X, "N Select" with N in gold in multi-select; tabs "Bag
  91 / 100" and "<container> 47 / 80" from the left edge (grey, the active one near-black with gold text and a gold
  underline); it opens on the container's tab. One grid per side, the active one shown, 10 columns of ~104 px at
  1600x900 and 6 of ~90 px at 844x390 (data `storage.cell`). One toolbar under rail and grid: Auto Sort with its caret,
  Select All, Select, Search (a field opens beside Auto Sort) and Lock on the Bag tab; Drop only with `drop_handler`. The
  rail, sort and search apply to both tabs. The inspect panel runs from the tab row down: "Transfer to Bag" (and Take
  All when the opener allows) on the container's tab, "Transfer to Storage Box" / "Transfer to Cargo" on the Bag's, or the
  grey reason. A take-only container's `readonly_reason` sits in a dark notice over the top of the grid (the reference's
  "this box belongs to someone else - cannot take").
- `scripts/ui/filter_rail.gd` (FilterRail, new): the left column, one square per data filter with its white icon
  (`filters[].icon` in data/inv_ui.json; All is a procedural four-square glyph), the active one dark with a gold icon and
  edge; 56 px squares (44 on a phone), scrolls when short.
- `scripts/ui/inventory_ui.gd`: `_store_indices` / `_take_indices` move every picked instance with the old per-item rules
  and stop at the first full side ("Storage is full." / "Your bag is full."); `select_uid` and the legacy `_select` go
  through `StorageScreen.select_key` (switches to the side that holds it); `layout_blocks()` for storage = header, tabs,
  rail, the shown grid, toolbar, inspect; Esc closes the one toolbar's menu. An emptied container closes only when it is
  take-only (loot); a box the player can fill stays open.
- Shared parts: `inventory_grid.gd` `set_query`, `select_all`, `selected_indices`, `has_key`, multi-select keeps the
  single selection and a selected cell shows the gold check; `inventory_slot.gd` trait pips under the art and the check;
  `inv_paint.gd` `pips` (gold positive, grey negative, green rare, up to six; replaces the green corner triangle) and
  `check`; `inv_glyphs.gd` `select_all`, `grid`; `bag_toolbar.gd` squares `select_all` / `search`, `set_select`,
  `set_search(on, text)`; `inv_header.gd` `set_title(text, lead)`; `inv_actions.gd` `all_locked` / `toggle_locks` (the
  Bag's lock logic, shared); `bag_screen.gd` uses them.
- `scripts/ui/item_inspect_panel.gd` (both references): the tan card now carries art, name and "Lv. N" over a line with
  "Durability 80 / 80" and the hammer "×3" (process count); then the item's families as chips (its categories, with the
  crafting menu's representative art, labels from data `category_labels`), its traits as chips (gold / grey / green), and
  the black Info bar with a caret that folds the rows under it. Notes (picker warning, store reasons) read first. Screens
  pass `ctx.labels` for button text; `button_for(action)`.
- Lab `bag_ui_lab`: a storage box seeded like the reference (47 / 80: a hide, sticks, ore with Firm / Heavy pips, a
  processed iron ingot Firm Lv. 4 / Heavy Lv. 2 / ×3, leaves, logs), shot-only `--screen=storage_select` (1 Select) and
  `storage_notice` (someone else's box), `--query=` (Search open) and `--insets=l,r,b[,t]` (a phone notch through
  `InvTheme.forced_insets`); `_check_b3` adds: two picked on the box tab read "2 Select" and one Transfer to Bag moves
  exactly them, one Transfer to Storage Box puts both back, someone else's box shows the notice and no Transfer.
- Tests: t_invui 12 rewritten for the reference (opens on the container's tab; Transfer to Storage Box moves the exact
  bone; the rail's Food shows two berries in the Bag and hides the bone in the box; Transfer to Bag and Take All on the
  box tab; Select All checks all three and the header reads "3 Select"; one Transfer moves all three with their uids; two
  picked berries come back and the bone stays; Search "bone"; read-only loot's notice and no Transfer; the locked berry's
  reason; the legacy `_select` + `_store_selected` entry; cargo on its tab), 20 also checks the reference state (container
  tab, the notice, Search open, all picked) at 1600x900, 844x390 and 804x452. On the old split view test 12 fails at
  "the storage view has Bag / container tabs, a filter rail and Transfer" and 20 stops on `select_key`.

Acceptance lines (HEAD e618ad30 + the hooks patch applied in the work tree; logs in the scratchpad `invui/b3r/gates2/`):
- t_invui: exit 0, "[t_invui] PASS", 0 SCRIPT ERROR (all 20; 12 and 20 rewritten / extended here). The new test 12
  fails on the old split view by construction (it asks for `StorageScreen.select_key` and `rail` first and FAILs "the
  storage view has Bag / container tabs, a filter rail and Transfer"); not re-run on the old code.
- Every t_*.gd exit 0 with its PASS line and 0 SCRIPT ERROR except t_save's 5 deliberate ones ("[t_save] PASS"): t_ai,
  t_build, t_canim, t_combat, t_harbour ("[t_harbour] PASS islands=15"), t_iconart, t_inventory, t_invui, t_items,
  t_light, t_lighting, t_occlude, t_player, t_save, t_server_domain, t_srvdom, t_structart, t_tame, t_ui ("[t_ui] PASS"),
  t_uiicons ("[t_uiicons] PASS ids=169 files=114 ..."), t_web.
- run_all "[tests] PASS" (exit 0, 0 SCRIPT ERROR); tools/smoke.sh --no-import "SMOKE PASS".
- Labs, 0 SCRIPT ERROR each: bag_ui_lab "[bagui] b3 storage=store,take,multi2,notice cargo=take picker=berry42
  bag=92/100 box=47/80", "[bagui] open times bag=1711us, inspect=3076us, character=12233us, equipment=7524us,
  storage=17993us, cargo=6555us, picker=4540us", "[bagui] PASS bag=92/100 new=11 locked=2"; inventory_lab "[invlab]
  PASS empty_cells=100/97 slots=100 cells=100 stones=16 stack45=true lock_pip=true equip_l30=true
  full_unequip_notice=true"; ui_family_lab (headless) "[uifamily] inventory=true animals=true unlimited=true
  active_cap=3"; ui_screenshot_lab "[uishot] PASS screens=hud,inventory,animals,craft,atlas,death,radial";
  ui_real_capture_lab 844x390 and 1600x900 gl_compatibility "[uireal] PASS screens=hud,craft,...,bag,...". Every shot
  run below also logged 0 SCRIPT ERROR.
- Crash reports: 34 Godot-*.ips before this run and 34 after.

Shots looked at (scratchpad `invui/b3r/shots/`, not in the repo; each opened next to durango-storage-transfer.webp, the
Bag ones next to durango-bag-instances.webp):
- `storage_select_1600_glc.png` / `_fwd.png` against the reference: "< 1 Select" with the gold 1, T-stone chip and X;
  "Bag 91 / 100" grey and "Storage Box 47 / 80" gold with its underline; the rail with All gold; ten dense columns with
  grey "Lv. 60" top-right and gold / grey pips under ore, plank and logs; the iron ingot's lighter cell with the gold
  check; the panel's tan band "Iron Ingot", tan card with the art, "Lv. 60" and the hammer "×3", chips "Metal" and
  "Blade Material", trait chips "Firm Lv. 4" gold and "Heavy Lv. 2" grey; toolbar Auto Sort + caret, Select All, Select
  (gold edge, on), Search; yellow "Transfer to Bag". Forward+ matches gl_compatibility.
- `storage_notice_1600_glc.png` and `storage_notice_844_glc.png` (notch insets 47 / 47 / 21): "Small Box 47 / 80", the
  dark notice "This box belongs to someone else: cannot take." over the top row, no Transfer; on the phone the header's
  black runs under the notch while its controls, the tabs, rail, grid and toolbar sit inside the safe area.
- `storage_1600_glc.png` / `_fwd.png`, `storage_844_glc.png`: the single selection keeps the yellow brackets; on the phone
  6 columns, 5 rail squares (it scrolls) and the grid scrolled to the selected ingot.
- `search_1600_glc.png`: the field beside Auto Sort reads "log", the grid shows the nine logs, the panel the two counts.
- `cargo_1600_glc.png`, `cargo_844_glc.png`: "Velociraptor Cargo 3 / 10" gold, the berry bracketed, chips Food / Herb /
  Fruit, Info "Energy +6", "Transfer to Bag".
- `bag_1600_glc.png`, `inspect_1600_glc.png`, `bag_844_glc.png`, `inspect_844_glc.png` (shared cells and panel):
  pips under the Lv. 42 berry and both bones like the Bag reference's small yellow squares; the Lv. 60 bone's panel
  shows Bone / Blade Material / Handle, Firm Lv. 8 gold, Low Density Lv. 3 grey, Black Sheen green, Info "Locked". On the
  phone the wide "Blade Material" chip pushes "Handle" to a second row and the trait chips stack; the panel scrolls.
- `picker_1600_glc.png`, `picker_844_glc.png`: the red rare-trait line over the chips, yellow Use.
- `character_1600_glc.png`, `equipment_1600_glc.png`: unchanged layouts with the kept frames and backdrop.
Fixed after looking: 9 columns (cells 115 px) became 10 (`storage.cell` 100); the rail cut its last square at 1600x900
(squares 60 -> 56); the ×3 was row-sized (now a size up, as the reference); the phone's family chips wrapped two a row
(width now leaves the chip row's margin and the scrollbar); the phone grid did not scroll to the selection (deferred
`ensure_control_visible`); the berry art touched NEW on 84 px phone cells (art centre back to 0.55).
Differences left: our families come from item categories, so chips read "Metal / Blade Material" where Durango shows
"Chunk / Iron / Ore / Rock"; durability has no glyph (the icon set has none); the reference's Info section shows its own
content (a hex) that has no counterpart here; the grain and frames are B4's to finish.

Assumptions added (design section 9 has 1-22, B1 23-30, B2 31-42, B3 43-54):
55. Tabs replace B3's split (spec 13 s17 allows "split or switchable"; the owner's reference is switchable); the view
    opens on the container's tab, and tapping an item on either side by uid switches to that tab.
56. One rail, one sort and one search for both tabs (the reference has one of each); filter icons are white ui_icons
    ids kept in data, All a procedural four-square glyph.
57. Multi-select shows the gold check wherever it is on (Bag Select, storage, a picker slot that takes several); one
    selection keeps the brackets. Turning Select on keeps the current selection as the first pick.
58. Select All turns Select on and picks every item shown; Search matches the item name, case-insensitive, view only.
59. Lock shows on the Bag tab only (nothing locked can be stored, so a container never holds a locked item).
60. Transfer moves every picked instance by the per-item rules, skips the ones that may not go (locked, held tool, quick
    food), and stops at the first full side; the panel gives the reason for the item it shows.
61. The notice over the grid is the container's `readonly_reason`; a box that belongs to someone else is its opener
    passing "This box belongs to someone else: cannot take." (box ownership does not exist on this base; W2-BUILDSYS'
    chests can pass it).
62. Inspect panel: family chips are the item's categories (crafting's representative art, else the item's own), trait
    chips replace the Positive / Negative / Rare sections, durability and the processing count sit on the tan card, the
    "Type" row is dropped (the first chip says it), and Info folds.
63. Every cell shows trait pips under the art, at most six, and the green corner triangle is gone (the pips carry rare).
64. Storage and cargo show the T-stone chip (the reference's header has its currencies); supersedes 46.
65. An emptied container the player can put things into stays open; emptied take-only loot still closes (before, any
    emptied container closed).
66. Storage cells aim at ~100 px (data `storage.cell`; 84 on a phone): denser than the Bag's 7 columns, like the
    reference's 13, and still wide enough for NEW beside "Lv. NN".

Hooks (`docs/orchestration/reports/claude-mmo-invui-hooks.patch`, regenerated on e618ad30, 14 files; `git apply --cached
--check` passes on that HEAD and it is applied uncommitted in the work tree). New in this run: `tests/t_ui.gd` adds
`filter_rail.gd` to OWNED. Unchanged otherwise from B3 (crafting exact picks and lock refusal over W2-INV's newest
`_plan_ordered`, station_craft / player / player_actions craft picks, craft_ui's picker buttons, save_game rebaseline,
save_sanitizer presets, inventory.gd presets / lock skips / span uid, player_actions equip / unequip / hold / lock / eat,
hunt_hud's Character entry, the W1-UI labs, inventory_lab). Entry points: the Bag and Character from the HUD menu (hook),
storage from boxes and baskets (`player_actions.gd`), loot from corpses (`corpse.gd`), cargo from pets
(`player_pets.gd`), the picker from the craft menu (hook); all already call `show_storage` / `show_pet_bag` /
`open_picker`, so none needed a new hook. Market: unchanged from B3 (Sell hidden while no market screen exists on this
base; the one integrator line for W3-EXCHANGE is in the B3 section above).

Owner gates: none. No save field changes; no money; transfers keep the offline rules (`transfer_to`, remove + add with
put-back) and online play still has no storage intent (as before INVUI).

Limits: Transfer runs offline rules only (storage has no server intent on this base, as before); Lock and Drop act on
the Bag tab only; Search needs a keyboard (on a phone the field opens the system keyboard on tap); the rail scrolls by
drag with no bar on a phone; panel motion, transfer feedback and the grain pass stay B4. Machine note: the disk filled to
0 bytes during this run (the two orchestrator scratchpads hold ~121 GB each); one gate run lost its ui_family_lab line to
it and was redone.

## B4: polish (2026-10-20, spec 13 sections 2, 16, 20, 21; phase 5)

Base sync (twice; W2-INV is still not merged into claude/mmo-overhaul, whose tip e5f3ec8a has no W2-INV merge):
- Start of the step: `claude/mmo-w2-inv` at 2583c2d3 (W2-INV with overhaul 29ffa292: W2-DATA and W2-SKILLS, and its hooks
  patch regenerated) merged as 4c9fd820. Conflicts were W2-INV hook lines committed here against W2-SKILLS' base changes:
  t_items (resolved to W2-INV's new hunk: the bronze pick checked with `equipped_gather_tool()`) and t_save (the stacked
  goldens' split check kept beside W2-SKILLS' rev-2 skills check). The INVUI hooks patch applied cleanly on the merge;
  t_save, t_items and t_invui PASS there.
- Mid-step W2-INV moved to bc05b421 (docs-only overhaul e5f3ec8a merged; a7b49780 regenerated its instance goldens with
  W2-SKILLS' rev-2 skills_v2). Merged as 9343857b; the delta of its hooks patch is only the two instance-golden fixtures,
  re-applied together with W2-INV's own t_save hunk (1e64e008), so t_save and both instance goldens here are now exactly
  W2-INV's base + hooks (my first t_save resolution, which kept the instance goldens rev-1, is gone).
- Not merged in this step: W2-INV ecf6ccf0 (review 4: def rarity as a spend key after traits; inventory.gd,
  data/inventory.json, t_inventory), committed after this step's gates had started. The next step's sync takes it; it
  touches inventory.gd, where INVUI's hook adds presets, lock skips and the span uid: checked against ecf6ccf0's
  inventory.gd, the lock-skip hunk's context (the `spend_key` body just above `find_by_category`) no longer matches, so a
  plain `git apply` refuses it there; the change itself does not overlap: `git apply --cached --3way` of this hooks
  patch onto HEAD with ecf6ccf0's inventory.gd in a scratch index "Applied patch to 'game/scripts/items/inventory.gd'
  cleanly".

Shipped (c1b5c231, abba023e, be5f123f, a8613495 and this report; all under `game/` unless named):
- `scripts/ui/inv_motion.gd` (InvMotion, new): restrained motion (spec 13 s20). Screens fade in over 110 ms when they
  open (`InventoryUI._show`; a screen already showing does not re-fade), the Detailed Stats panel and the toolbar's
  dropdowns too; a storage tab switch fades its grid in over 70 ms; the yellow brackets settle onto a newly selected cell
  from 4 px outside it in 80 ms (only when the selection changes, so refreshes and sorts never re-play it); items arriving
  light up the storage tab that received them (Transfer either way) and an Equip lights up the gear cell it filled, 0.3 s
  each. Motion only touches modulate and draw-time values, never a rect, so tap-target and layout checks read the final
  layout at once. No bounce, no particles.
- Desktop (spec 13 s21): arrows move the selection on the Bag, storage, cargo and picker grids (left / right in reading
  order, up / down to the nearest item in the next row; `InventoryGrid.move_selection`) and between the gear cells on
  Character / Equipment (`GearScreen.move_slot`, the blank corner skipped); Enter runs the panel's yellow action
  (`ItemInspectPanel.press_primary`, `GearScreen.press_primary`; never on key repeat, so a held Enter cannot repeat a
  transfer); Tab switches a container's tabs; Esc and I as before. Key events only: the pad's d-pad and A keep their game
  bindings (bandage, hunt-chase, interact). The mouse wheel scrolls every grid smoothly (half a compartment a notch over
  90 ms; touch drag and trackpad pans stay the container's own). Hovering a cell shows its name, level, every trait with
  its class in words, NEW and Locked (`InventorySlot.describe`); every toolbar square, rail filter and gear cell already
  had a tooltip. Everything a tooltip says is one tap away in the inspect panel.
- Accessibility (rarity and trait class never by colour alone): the pips under each cell have a shape per class (filled
  gold square positive, hollow grey square negative, green diamond rare; `InvPaint.PIP_SHAPES` / `pip`) and the inspect
  panel's trait chips carry the same shape before their text with "Positive trait: Firm Lv. 8" / "Rare trait: Black Sheen"
  as their tooltip (`ItemInspectPanel.TraitChip`). NEW is a word, locked a lock glyph, worn a triangle, the selection
  brackets, compare gains a sign, as before.
- Textures and the unified look (spec 13 s2, s16), measured against the four references on the 1600x900
  gl_compatibility shots (luma; B3 in brackets; references after the slash): the khaki backdrop between the panels
  #5A5741 renders 78 (41) / 80-93; the grid panel #3B3830 47-58 (37) / 52-56; the Character card 54.5 (50) / 53.5; gear
  cells #141810 29 (23) / 32; the inspect panel #33342A olive-grey (spec 13's #26322C read teal beside the Bag's dark
  brown #31271B and storage's olive #4D4C3A bodies). The grain's vignette dropped from 28 % to 14 % (the references darken
  only at the very edge) and its blotches rose to +-26 %. The same header, backdrop, grain, dark irregular frames, bracket
  language, yellow primary and condensed font run through Bag, storage, cargo, picker, Character, Detailed Stats and
  Equipment.
- Responsive (spec 13 s21): the Bag keeps 7 columns while a compartment still holds NEW beside "Lv. 60" at the type floor
  (`InvTheme.label_room(12)` = 84 px), else 6: a notched 844x390 phone (47 / 47 / 21 insets) had 74 px cells where NEW ran
  into "Lv. 12" (seen in a shot; now 6 columns of 87 px), and the 804x452 canvas (an iPhone SE at 667x375) gets 6 columns
  of 93 px. My Info grows to its compare lines on a short screen (a notched phone cut "Max health 100 → 156" in half;
  tighter line pitch, never a half-cut line). The gear column's properties read one fact a line (joined, they wrapped with
  a "·" hanging at the line's end at every size).
- Performance (spec 13 s20; design gate P1): `bag_ui_lab --perf` pads the bag to 142 / 142 instances (traits and NEW on
  some), closes the family and times `open_bag()` twice, cold (the run's first open) and warm, with the wait to the first
  drawn frame beside a frame of the world with the family closed; headless it times the build. t_invui 21 times the same
  142-slot open headless and fails over 50 ms.
- Tests and lab: t_invui 21 (motion lengths, the Bag's fade, arrows / Enter / Tab on Bag, storage and Character, Transfer
  by Enter and the receiving tab lighting up, three pip shapes, the chips' class words, the cell tip, tap targets / text /
  safe area at 1920x1080, 844x390 with a notch and 804x452, a Bag compartment holding NEW beside "Lv. 60", the 142-slot
  open); bag_ui_lab `--perf` and the 142-slot check in its headless run.

Acceptance lines (HEAD 1e64e008 + the hooks patch applied in the work tree; logs in the scratchpad `invui/b4r/`):
- Every t_*.gd (gate run g1, started on abba023e + be5f123f's code + the hooks; the later commits change only t_invui's
  notch view, docs, t_save and its two fixtures, and those two tests were rerun on 1e64e008 in g2): t_ai, t_build,
  t_canim, t_combat, t_data ("[t_data] PASS items=223 recipes=155"), t_harbour ("[t_harbour] PASS islands=15"),
  t_iconart, t_inventory, t_items, t_light, t_lighting ("[t_light] PASS"), t_occlude, t_player, t_server_domain, t_srvdom,
  t_structart, t_tame, t_ui ("engine errors/warnings during the checks: 0", "[t_ui] PASS"), t_uiicons ("[t_uiicons] PASS
  ids=171 files=114 ..."), t_w2_skills, t_web all exit 0 with PASS and 0 SCRIPT ERROR. On 1e64e008 (g2): t_invui exit 0
  "[t_invui] 21 open 142/142: 142 cells in 4421 us", "[t_invui] PASS", 0 SCRIPT ERROR; t_save exit 0 "[t_save] PASS" with
  its 5 deliberate SCRIPT ERRORs. In g1, t_invui failed once on the test's first cut ("FAIL 21: a Bag compartment holds
  NEW beside 'Lv. 60' at (804.0, 452.0) with a notch (cell 82 < 84)", fixed in a8613495) and t_save ran across the second
  base sync with my old resolution against W2-INV's new fixtures ("FAIL save_v3_inst_golden.json is still a rev-1 save");
  both pass on the final HEAD as above.
- run_all exit 0 "[tests] PASS"; tools/smoke.sh --no-import "SMOKE PASS".
- Labs, 0 SCRIPT ERROR each: bag_ui_lab "[bagui] perf142 cold bag=142/142 cells=139 build=4467us first_frame=headless",
  "[bagui] perf142 warm ... build=4596us", "[bagui] PASS bag=142/142 new=61 locked=2"; inventory_lab "[invlab] PASS
  empty_cells=100/97 slots=100 cells=100 stones=16 stack45=true lock_pip=true equip_l30=true full_unequip_notice=true";
  ui_family_lab "[uifamily] inventory=true animals=true unlimited=true active_cap=3 stego=stegosaurus"; ui_screenshot_lab
  "[uishot] PASS screens=hud,inventory,animals,craft,atlas,death,radial"; ui_real_capture_lab 844x390 and 1600x900
  gl_compatibility "[uireal] PASS screens=hud,craft,skills,...,bag,character,charcreate,..." (its real-scene bag at
  844x390 looked at: empty 0 / 100 bag, summary panel, all inside the view). Every shot run in this step logged 0 SCRIPT
  ERROR.
- Crash reports: one new Godot-*.ips during the gates (Godot-2026-10-20-232613.ips: launched 23:25:41, SIGABRT 23:25:51 in
  `recursive_mutex::lock` from a CoreFoundation notification on the main thread, B1's signature). Not one of my runs: the
  two of mine running then (t_lighting, t_items) printed PASS at 23:26:13 and 23:26:19 and exited 0, and none of mine ended
  at 23:25:51; the other workflow shares the machine and the responsible process.

Mutation (t_invui 21 against the code before B4, scratch tree at 4c9fd820 + the B3 hooks, the new t_invui copied in):
"[t_invui] FAIL 21: not built yet (inv_motion.gd)", "[t_invui] 1 failures"; with only inv_motion.gd copied in as well:
"FAIL 21: the Bag fades in as it opens (alpha 1.00 at once)", "FAIL 21: Right with nothing selected picks the first item",
"FAIL 21: Right steps to the next item, Down to the one below it", "FAIL 21: Left steps back in reading order", "FAIL 21:
Enter runs the yellow action on the selected item (Equip opens the compare)", "FAIL 21: Tab switches the storage view to
the Bag tab", "FAIL _t21_polish stopped on a SCRIPT ERROR", "[t_invui] 7 failures". The label-room check failed on this
step's own first cut ("cell 82 < 84" on a canvas no phone gets; the test now uses the notch on 844x390 only).

Performance, measured: headless build + layout of the full 142 / 142 bag 2.4 ms in bag_ui_lab ("[bagui] perf142 cold
bag=142/142 cells=139 build=2358us first_frame=headless"; the cage spans 4 slots, so 139 cells) and 3.1-3.5 ms in t_invui
("[t_invui] 21 open 142/142: 142 cells in 3113 us"). Windowed at 1600x900, under a machine running about 24 Godot
processes for the other workflow: Forward+ "perf142 cold ... build=2913us first_frame=55862us world_frame=11431us" and
"perf142 warm ... build=3036us first_frame=20171us world_frame=5860us"; gl_compatibility "perf142 cold ... build=4661us
first_frame=111816us world_frame=33770us" and "perf142 warm ... build=4444us first_frame=21294us world_frame=12790us". So
every open builds in under 5 ms and draws within about 21 ms once the family has been drawn once; the session's first open
pays about 45 ms (Forward+) to 80 ms (gl_compatibility) more for its first frame. Not split further; most likely the grain
shader's first compile and the glyph caches, which a pre-warm outside the family (the HUD's boot) could take.

Shots looked at (scratchpad `invui/b4r/`, not in the repo; s4 is the final set, s5 the My Info fix; each opened next to
its reference):
- Bag, `s4/bag_1600x900_glc.png`, `inspect_1600x900_glc.png` / `_fwd.png`, `bag_1920x1080_glc.png` next to
  durango-bag-instances.webp: black torn header "< Bag [bag] 91 / 100", T-stone chip, X; the lighter khaki now shows in the
  gaps and under the panels like the reference's blurred world; the grid panel blotchy brown-olive with faint dashed
  compartments; blue NEW top-left, grey "Lv. N" top-right; the pips read by shape (berry Lv. 42 gold square + green
  diamond, bone Lv. 45 gold + hollow, bone Lv. 60 all three); yellow brackets on the Lv. 60 bone; Auto Sort with its
  caret and the three squares; the inspect panel's tan band and card, family chips, trait chips with their shape marks
  ("Firm Lv. 8" gold, "Low Density Lv. 3" grey, "Black Sheen" green), black Info bar. 1920x1080 is the same layout scaled
  1.2 (DisplayMode keeps a 1600x900 canvas).
- `s4/bag_844x390_glc.png` (bone selected, notch insets 47 / 47 / 21) and `bag_667x375_glc.png`: 6 columns, NEW clear of
  "Lv. NN", the cage 2x2, the panel scrolls its chips; the header's black runs under the notch, its controls inside.
- Storage, `s4/storage_select_1600x900_glc.png` / `_fwd.png` next to durango-storage-transfer.webp: "< 1 Select" with the
  gold 1; "Bag 91 / 100" grey and "Storage Box 47 / 80" gold with its underline; the rail with All gold; ten dense
  columns, "Lv. 60" top-right, gold squares and hollow grey squares under the ore, plank and logs; the ingot's lighter
  cell with the gold check; the gold title band "Iron Ingot", card with "Lv. 60" and the hammer "×3"; chips Metal / Crude
  Ingot / Tier Iron; "Firm Lv. 4" gold and "Heavy Lv. 2" grey with their marks; Auto Sort + caret, Select All, Select (on),
  Search; yellow "Transfer to Bag". `s4/storage_notice_844x390_glc.png` (notch): "Small Box 47 / 80", the dark notice
  "This box belongs to someone else: cannot take." over the grid, no Transfer. `s4/storage_667x375_glc.png`: fits.
- Character, `s4/character_1600x900_glc.png` / `_fwd.png`, `character_667x375_glc.png` next to
  durango-character-gear.webp: the card, XP bar, power rows and Detailed Stats on the lighter olive-brown panel; yellow
  Gear tab, "1 2 [lock] [lock]", the 3x3 on olive near-black cells with faded silhouettes; the worn vest's facts now one a
  line over Unequip.
- Equipment, `s5/equipment_1600x900_glc.png`, `s5/equipment_844x390_glc.png` (notch), `s5/equipment_667x375_glc.png`,
  `s4/equipment_1600x900_fwd.png` next to durango-equipment-myinfo.webp: tan My Info band, dark icons on khaki over black
  label bands, "1102" gold with "321 → 1102 +781", "Replaces: Forager Vest Lv. 12" and "Max health 100 → 156" both whole
  on the notched phone (cut in half in `s4/equipment_844x390_glc.png` before be5f123f), the hex row, yellow Equip.
- Forward+ against gl_compatibility (same regions, 1600x900): grid / inspect / backdrop luma within 0.4 on Bag, storage,
  Character and Equipment (e.g. Bag 63.5 / 46.8 / 77.9 glc against 63.7 / 47.1 / 78.0 Forward+).
Fixed after looking: NEW ran into "Lv. 12" on the notched phone (six columns); "Max health 100 → 156" cut off on the
notched phone; the gear facts' hanging "·"; the inspect panel's teal. Differences left: the references' panels are
see-through over a blurred world, ours are opaque procedural surfaces (a world blur behind a modal is not built); the
Decorative Gear tab, the portrait's painted face, the red locked tactic hex, the storage panel's Info hex and a durability
glyph have no counterpart (as in B2 / B3).

Assumptions added in B4 (design section 9, 67-72): 67 screens fade (110 ms) without the 8 px slide, tabs 70 ms, an 80 ms
bracket settle, a 0.3 s light-up where items land; 68 desktop keys (arrows, Enter, Tab; key events only); 69 the
survivor does not walk while the bag family is open (the hook below); 70 trait class by shape as well as colour, and in
words on hover; 71 backdrop / panel / gear-cell tints measured against the references over spec 13 s2's approximate
values; 72 the gear column's facts one a line.

Hooks (`docs/orchestration/reports/claude-mmo-invui-hooks.patch`, regenerated on 1e64e008, 15 files; `git apply --cached
--check` passes on that HEAD and it is applied uncommitted in the work tree). New in B4:
- `scripts/player/player_sim.gd` (W2-PLAYER): `_walk` reads no walking input while `p.ui.visible` (the family is an opaque
  full-screen modal whose arrow keys are also the movement keys; the survivor no longer walks blind under it with WASD or
  the arrows either).
- `tests/t_ui.gd` (W1-UI): `inv_motion.gd` joins OWNED.
Unchanged from B3: crafting / station_craft / player / player_actions craft picks, craft_ui's picker buttons, save_game
rebaseline, save_sanitizer presets, inventory.gd (presets, lock skips, span uid), player_actions equip / unequip / hold /
lock / eat, hunt_hud's Character entry, the W1-UI labs, inventory_lab.

Owner gates: none. No save field, money or authority change in B4. One behaviour to know: with the bag family open the
survivor stands still (hook above).

Limits: the first open of a session pays 45-80 ms more for its first frame (above); gamepad navigation inside the family
is not added (the d-pad keeps its game bindings; Back still toggles the bag); Detailed Stats has no key navigation (Esc closes it); screen opening is a fade, not a slide; hover tips are
desktop only (the same facts are in the inspect panel); the panels are opaque, the references' see-through blur over the
world is not reproduced.
