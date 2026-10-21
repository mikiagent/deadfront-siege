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

Limits: exact-instance craft / cook picker and full storage are B3 (t_invui 16-17 fail by design). No accessory or
cosmetic gear exists, so the accessory cells only ever show the empty state and the Decorative Gear tab is not shown.
Presets are local: online, applying sends one act.equip per slot from the client's mirror and the server keeps no preset
record. The portrait does not show worn armour. Keyboard shortcuts beyond I / Esc, panel motion and the condensed font
pass are B4. Owner questions: design section 12 (unchanged).
