# INVUI design: Durango Bag, Character -> Gear, Equipment / My Info (spec 13)

Branch `claude/mmo-invui`, work tree `.claude/worktrees/mmo-invui`, stacked on `claude/mmo-w2-inv` (5ff239a6) with W2-INV's
hooks applied in commit 3ecb02ca "Apply W2-INV hooks (INVUI base)". Design truth, newest first: spec 13
(`docs/design/durango-prompts/13_inventory_equipment_ui.md`) and its three references
(`docs/reference/durango-{bag-instances,character-gear,equipment-myinfo}.webp`), then specs 04/05/06/08, GAUNTLET.md's UI
rules and STATUS owner decisions. Durango's look wins over the older DEADFRONT UI tokens (teal, 12 px radius, 5x4 bag) inside
this screen family.

Pinned by: `game/tests/t_invui.gd` (one test per spec 13 section 23 item; 20 FAIL on this design commit by construction)
and the lab `game/scripts/dev/bag_ui_lab.gd` (`scenes/dev/bag_ui_lab.tscn`; headless FAIL until the contract exists).
Section 4 is the API contract those two call; builders may add to it, never rename without editing both.

## 1. What the references measure (scout px, 1600x900 equivalents)

| Thing | Bag ref | Character ref | Equipment ref | Our target at 1600x900 |
|---|---|---|---|---|
| Header | black #080809, 10.5 % H, torn lower edge | same, "< Character", X | "Equipment", X | 80 px (8.9 %) |
| Main area | grid panel 69.5 % W, inspect 27 % W | 36 / 33 / 26 % W columns | 35 / 33 / 25 % W | grid 69 %, inspect 28 % |
| Toolbar | 10.9 % H under the grid only | - | - | 96 px (10.7 %) |
| Cells | 8.7 % W square, 8 cols, ~4.7 rows visible | 3x3 dark cells ~18 % H | 3x3 | 7 cols, ~158 px (17.5 % H), 4.5 rows |
| Labels | NEW top-left blue, Lv top-right grey | Lv top-right in candidates | - | same |
| Selection | four yellow L brackets, arm ~13 %, stroke ~3 % | same on gear and preset 1 | - | arm 14 %, stroke max(3 px, 3.5 %) |
| Primary button | yellow #F7BE33, 9.7 % H | yellow Unequip 9 % H | dim yellow Equip | 88 px desktop, 56 px phone |

Spec 13 says "approximately seven columns"; the bag reference shows eight. We ship 7 (gate: 7-8 desktop, 6-8 phone).
Spec 13 section 6 says labels sit "near the bottom"; the reference (which spec 13 calls primary) has them at the top of the
cell: we follow the reference.

## 2. Component tree and files

All new UI files are flat in `game/scripts/ui/` (t_uiicons and t_ui scan that folder non-recursively), typed, one
`class_name` per file. Presentation only: no component mutates an Inventory except through `InvActions`, which calls
`PlayerActions` verbs (section 6).

| Component (spec 13 s22 name) | File | class_name | Role |
|---|---|---|---|
| Theme resource (palette, type scale, metrics, styleboxes) | `scripts/ui/inv_theme.gd` | InvTheme | One source of colours, font sizes and per-viewport metrics; builds one `Theme` set on the family root (never on the global theme) |
| Weathered texture | `scripts/ui/inv_grain.gdshader` | - | canvas_item hash-noise grain + sparse scratches + vignette, gl_compatibility safe |
| Item icon, Level label, NEW tag, Selection brackets, Rare marker, lock pip, durability bar, count | `scripts/ui/inv_paint.gd` | InvPaint | Static `draw_*` helpers on a CanvasItem; every slot-like control paints with them so all screens match |
| White procedural glyphs the icon set lacks | `scripts/ui/inv_glyphs.gd` | InvGlyphs | filter funnel, checkbox, dropdown chevron, accuracy target, ring silhouette, chevron ">" (all white polylines) |
| Inventory slot | `scripts/ui/inventory_slot.gd` | InventorySlot | One cell: `uid`, `stack`, `selected`, `level_text()`, `shows_new()`, `shows_rare()`, `shows_lock()`; custom `_draw` |
| Inventory grid (shared: bag, storage, cargo, picker) | `scripts/ui/inventory_grid.gd` | InventoryGrid | Binds one Inventory; continuous textured panel, fine separators, empty cells to capacity, 2x2 / 2x1 packing for span items, selection by uid, multi-select, scroll |
| View model (sort, filter) | `scripts/ui/inv_view.gd` | InvView | `order(inv, key, filter) -> Array[int]` lead slot indices; never mutates |
| Attribute classes | `scripts/ui/inv_attributes.gd` | InvAttributes | Classifies `ItemStack.attributes` with `data/inv_ui.json`; hides technical keys |
| Valid actions + execution | `scripts/ui/inv_actions.gd` | InvActions | `valid(stack, ctx)`, `run(action, player, index, ctx)`; `static var sell_handler`, `drop_handler` hook points |
| Stats reader | `scripts/ui/inv_stats.gd` | InvStats | Attack, Defense, Accuracy, crit, health, energy, capacity, gather power, climate, powers; `with_candidate` what-if |
| NEW tracker | `scripts/ui/inv_new_tracker.gd` | InvNewTracker | Flags uid'd instances entering the player bag; clears on acknowledge; never on a load |
| Capacity indicator | `scripts/ui/capacity_indicator.gd` | CapacityIndicator | Yellow bag icon + "used / cap" from `used_slots()` / `slot_count`; DANGER when full |
| Header bar | `scripts/ui/inv_header.gd` | InvHeader | Black torn-edge bar: back, title, capacity slot, T-stone chip, close |
| Bottom toolbar | `scripts/ui/bag_toolbar.gd` | BagToolbar | Wide Auto Sort + dropdown, Select, Filter, Lock (Trash only when `drop_handler` is set) |
| Item inspection panel | `scripts/ui/item_inspect_panel.gd` | ItemInspectPanel | Tan title band, icon + Lv, compact rows, attribute sections, valid actions |
| Equipment slot | `scripts/ui/equipment_slot.gd` | EquipmentSlot | Dark cell, faded silhouette when empty, real art + Lv + durability when worn, brackets |
| Gear preset selector | `scripts/ui/gear_preset_selector.gd` | GearPresetSelector | 4 numbered compact cells, active one bracketed, locked ones with a lock glyph |
| Gear presets model | `scripts/items/gear_presets.gd` | GearPresets | Unlock rule, capture / apply via commands, save sanitizer (lives in items/ so inventory.gd can call it without a UI dependency) |
| Bag screen | `scripts/ui/bag_screen.gd` | BagScreen | Header + grid + toolbar + inspect (ref 1) |
| Character -> Gear | `scripts/ui/character_screen.gd` | CharacterScreen | Portrait, name, XP bar, powers, Detailed Stats; Gear tab, presets, 3x3, candidates + Unequip (ref 2) |
| Detailed Stats panel | `scripts/ui/detailed_stats_panel.gd` | DetailedStatsPanel | Real stats only, grouped (combat / crafting / gathering / survival) |
| Equipment / My Info | `scripts/ui/equipment_screen.gd` | EquipmentScreen | 3x3, My Info Attack / Defense / Accuracy, hex row, candidates + compare + Equip (ref 3) |
| Storage / cargo split | `scripts/ui/storage_screen.gd` | StorageScreen | Bag grid beside a container grid, per-side capacity, filters, Store / Take / Take all |
| Craft / cook ingredient picker | `scripts/ui/item_picker.gd` | ItemPicker | Filtered grid of a recipe slot's candidates, exact instances, least valuable preselected, warning |
| Family host / router | `scripts/ui/inventory_ui.gd` + `scenes/ui/inventory.tscn` | InventoryUI | Keeps its public API (section 4) and hosts the screens as its own children; shrinks from 810 lines |
| Data | `data/inv_ui.json` | - | Sort keys, filter groups, attribute classes, 3x3 layout + silhouettes, preset unlock levels, power groups, picker warn level |
| Lab | `scripts/dev/bag_ui_lab.gd`, `scenes/dev/bag_ui_lab.tscn` | - | Deterministic 91/100 survivor; `--screen=` shots; headless contract check and open times |
| Tests | `tests/t_invui.gd` | - | Spec 13 s23 items 1-20 |

`InventoryUI` stays the only node main.gd / lab_kit.gd instance (so main.gd needs no hook). It owns one `InvNewTracker`,
the current screen and a back stack. `ui.visible` still toggles the whole family (player_input.gd, hunt_hud.gd).

## 3. Theme: palette, type scale, metrics, textures

### Palette (`InvTheme` consts; spec 13 s2 values, refined by the reference pixels)

| Token | Hex | Use |
|---|---|---|
| BG | #101714 | Screen backdrop behind panels (full-rect, 96 % alpha over the world) |
| HEADER | #080809 | Header bar |
| PANEL | #39392F | Grid panel surface (grain shader on top), reference #3A2F2C warmer: tint toward it |
| PANEL_2 | #26322C | Inspect / secondary panels |
| CELL_DARK | #0E120F | Equipment cells, preset row |
| SEPARATOR | #56534A at 50 % | 1-2 px dashed grid lines |
| SELECT | #E6BE54 | Brackets, selected preset, bag icon |
| PRIMARY | #F2C84C | Primary button fill (dark text #1B1A14) |
| PRIMARY_DIM | #8C7A3A | Disabled primary (ref 3 dim Equip): only shown with a reason line, never as a dead control |
| TAN | #CAAD69 | Inspect title band, My Info band (dark text) |
| TEXT | #ECEBE4 | Main text |
| TEXT_2 | #A6A69B | Secondary text, Lv labels, negative attributes |
| TEXT_OFF | #77786F | Disabled text, locked preset / hex |
| NEW_BG | #176897 | NEW tag (white bold text) |
| POSITIVE | #D9B65A | Positive attributes (muted gold), stat gains |
| RARE | #67B84E | Rare attributes, rare marker |
| XP | #235D23 / track #0C0F0C | Character XP bar |
| DANGER | UiTokens.DANGER | Full bag count, broken durability (red only for danger) |

White stays for action glyphs (GAUNTLET: colour = things, white = actions); item art keeps its own colours.

### Type scale and metrics (`InvTheme.metrics(view: Vector2) -> Dictionary`)

The project has no UI font (only Noto symbol/emoji fallbacks in assets/fonts), so text uses the Godot default through
Game's FontVariation. B4 may add a FontVariation with `variation_transform` x-scale ~0.9 for Durango's condensed look
(built in, no download). Floor: 12 logical px everywhere (UiTokens.TYPE_MIN, enforced by t_ui and ui_real_capture_lab).

| Key | 1600x900 (and 1920x1080, same logical canvas) | 844x390 | 804x452 (667x375 scaled) |
|---|---|---|---|
| margin | 16 | 8 + safe insets | 8 + safe insets |
| header_h | 80 | 46 | 48 |
| toolbar_h | 96 | 52 | 52 |
| title font ("Bag") | 40 | 22 | 22 |
| capacity font | 34 | 20 | 20 |
| columns | 7 | 7 (6 if cell < 72) | 7 |
| cell | ~158 | >= 76 | >= 76 |
| inspect_w | 448 (28 %) | 232 (27.5 %) | 224 |
| lv_font / new_font | 20 / 15 | 12 / 12 | 12 / 12 |
| item name font | 34 | 18 | 18 |
| row font / pitch | 20 / 48 | 14 / 26 | 14 / 28 |
| primary action h | 88 | 56 | 56 |
| secondary action / toolbar square | 64 / 72 | 44 / 44 | 44 / 44 |

Cell geometry (InvPaint): icon centred at 55 % of the cell from `ItemArt.texture_for` + `content_rect` (fallback
ItemIcons symbol, never emoji; no rarity rim, glow, pips or overflow inside the grids); NEW tag top-left inset 3 px, height
`new_font + 6`, width `text + 10` and at most 35 % of the cell; "Lv. N" top-right inset 4 px in TEXT_2; rare marker = RARE
right triangle in the bottom-right corner, 12 % of the cell, 85 % alpha; lock pip = white `ui_icons lock` 18 % of the cell,
bottom-left; durability = 3 px bar along the bottom only when `max_durability > 0` and below max (DANGER when broken); "×N"
bottom-right only for fungible stacks (never rare, so no collision with the rare marker). Brackets: four L shapes in SELECT,
arm 14 % of the side, stroke `max(3, 3.5 %)`, with a 12 % SELECT tint behind; never a continuous rectangle.

### Procedural textures (no downloads)

- `inv_grain.gdshader` (canvas_item): two octaves of hash value noise (luma +-5 %), sparse 1 px scratch lines from a hashed
  angle field, soft vignette; uniforms `tint`, `strength`, `scale`, `seed`. Applied to ColorRects behind the grid, inspect and
  character panels. No NoiseTexture2D (asynchronous on web).
- Torn header edge: InvHeader draws its background as a polygon whose bottom edge is jittered by a deterministic hash
  (+-4 px, ~12 px period) plus two darker "nail" dots like the reference.
- Irregular dark panel borders: a 2 px polyline at 60 % black with +-1 px hashed jitter; corner radius 0-4 px.
- Gate: Forward+ and gl_compatibility shots look the same (B4 compares both).

## 4. API contract (pinned by t_invui and bag_ui_lab)

`InventoryUI` (kept for every existing caller; run_all.gd uses it outside the tree, so the kept members must work
without `_ready`): `bind(inv, player)` (idempotent: guard `is_connected`, raid_gear_probe binds twice), `show_storage(inv,
player, opts)` and `show_pet_bag(rec)` (same opts keys: title, take_all, allow_deposit, readonly_reason, on_take,
on_empty), `hide_ui()`, `rebuild()`, `visible`, `inventory`, `pet_bag`, `_selected`, `_storage_opts`, `_can_store_selected()`,
`_select(i)`, `_store_selected()`, `_take_storage(i)`. New: `open_bag()`, `open_character()`, `open_equipment(slot := &"")`,
`open_picker(rid: StringName, slot_index: int, on_pick: Callable)`, `select_uid(uid: String)`, `current_screen() ->
StringName` (&"bag", &"character", &"equipment", &"storage", &"cargo", &"picker"). The `shot_path contains "bag"`
auto-open in `_ready` goes (labs open screens explicitly).

| Class | Members the tests call |
|---|---|
| InvTheme | consts `DANGER`, palette; `static metrics(view) -> {header_h, toolbar_h, columns, cell, inspect_w, lv_font, new_font, ...}`; `static theme() -> Theme` |
| InvView | `static order(inv, key: StringName, filter: StringName) -> Array[int]`; keys from data `sort_keys`; filter ids from data `filters` |
| InvAttributes | `static sections(stack) -> {positive: [{key, label, level}], negative: [...], rare: [...]}`; `static has_rare(stack) -> bool` |
| InvActions | `static valid(stack, ctx) -> Array[StringName]`; `static run(action, player, index, ctx) -> bool`; `static var sell_handler: Callable`, `static var drop_handler: Callable`. ctx = `{where: &"bag" / &"storage" / &"cargo" / &"equipment" / &"picker", player, slot?, container?}` |
| InvStats | `static snapshot(player) -> Dictionary` (attack, defense, accuracy, crit, max_health, energy, capacity, gather_power, heat, cold, combat_power, crafting_power, gathering_power); `static with_candidate(player, index, slot) -> Dictionary` (no mutation) |
| InvNewTracker | `bind(inv)`, `acknowledge(stack)`, `static rebaseline(inv)` |
| InventoryGrid | `bind(inv)`, `set_view(key, filter)`, `auto_sort(key)`, `select_uid(uid)`, `selected_uid() -> String`, `selected_index() -> int`, `item_cells() -> Array`, `cells() -> Array`, `columns() -> int`, signal `selection_changed(uid)`; `multi` mode with `selected_uids()` |
| InventorySlot | props `uid`, `stack`, `selected`; `level_text()`, `shows_new()`, `shows_rare()`, `shows_lock()` |
| CapacityIndicator | `bind(inv)`, `label_text()`, `is_full()`, `count_color()` |
| ItemInspectPanel | `show_stack(stack, ctx)`, `title_text()`, `rows() -> PackedStringArray`, `section_color(cls)`, `actions() -> Array[StringName]`; contextual action buttons are in group `inv_contextual` (56 px gate) |
| GearPresets | `static unlocked_count(level) -> int`, `static capture(inv, k)`, `static apply(player, k) -> String` ("" = done, else the refusal), `static active(inv) -> int`, `static sanitize(raw) -> Dictionary` |
| ItemPicker | `open(inv, rec, slot_index, on_pick: Callable)` (on_pick gets `Array[int]` exact bag slots, length = slot count), `candidates()`, `preselected_index()`, `choose(index)`, `warning_text()`, `confirm()` |
| BagScreen | `bind(inv, player)`, `select_index(i)`; laid out from its own size (full-rect child) |

## 5. Data each element reads

| Element | Reads |
|---|---|
| CapacityIndicator | `Inventory.used_slots()` (counts LOCK span rows: a cage is 4) and `slot_count` (a var: equipment/Pocket bonuses, when a package adds them, change it and the header follows on `changed`). No bonus source exists today (inventory.gd:9) |
| InventorySlot | `ItemStack.def_id/level/count/flags/attributes/durability/max_durability/uid`, `ItemDef.slot_span`, `ItemArt.texture_for/content_rect`, `ItemIcons` fallback |
| InvView | `ItemDef.categories`, `display_name`, `ItemArt.rarity`, `ItemStack.level/created_at/durability`, slot order (= acquisition order offline: created_at is 0 for gathered items) |
| InvAttributes | `ItemStack.attributes` keys listed in `data/inv_ui.json attribute_classes`; value = trait level (int) or true |
| ItemInspectPanel | name (`ItemDef.display_name` / LevelDisplay.nice_name), `LevelDisplay.label(level)`, categories (material type), attribute sections, `process_count` ("Processed N"; W2-PROCESS `Crafting.processing_left` when merged), `durability / max_durability`, `origin`/`creator` when set, `LevelDisplay.stat_lines(def)`, `Food.inspector_text` for food, locked state |
| CharacterScreen | `player.display_name()`, `World.occupation`, `LevelDisplay.player_label()/current_title()`, `World.pioneer_progress()` + `World.xp_for_level` for "(cur / next)", powers from `skills.level_of(tree)` grouped by data |
| DetailedStatsPanel / InvStats / EquipmentScreen | Attack = worn weapon `scaled_damage()` (x `work_tool_mult` for work tools, `unarmed_damage` 8 bare) x (1 + `damage_per_melee_level` x Melee) x `statuses.attack_mult` (hunt.gd:200-235); Defense = (`creature_melee.player_base_defense` + `equipped_armor()`) x `statuses.defense_mult()` (creature_attack.gd:78); Accuracy = `player_melee.base_accuracy` x `statuses.accuracy_mult()` shown as %; crit = `crit_base + crit_per_melee_level x Melee`; health `vitals.effective_max_health()` incl. `equipped_health_bonus()`; energy; capacity; held tool `gather_power()`; `player.climate_resistance()` heat / cold. Read with `CombatTuning.num/section`; a t_invui check compares Attack with Hunt's own number when B2 can reach it |
| EquipmentSlot | `Inventory.equipped_in(slot)`, `equipped_tool_index` for the tool cell, data `equipment_grid` (cells, silhouette ids, alpha) |
| GearPresetSelector / GearPresets | `LevelDisplay.player_level()`, data `presets.unlock_levels`, `Inventory.presets` (hook) |
| Hex ability row | Combat tactics with a real verb and icon: tackle, kick (combat_tuning.json sections) and roll (ui_icons tackle/kick/roll); locked only if a skill node gates it (B2 checks survival/trees data; none locked if nothing gates) |
| ItemPicker | `Crafting.stacks_for_slot(inv, slot)`, minus locked; value = (has_rare, level) ascending for the preselect; warn when rare or level >= data `picker.warn_level` (40) |

## 6. Commands, owned files and hooks

The UI never edits an Inventory directly. `InvActions.run` maps each action to a command:

| Action | Command | Exists? |
|---|---|---|
| eat | `PlayerActions.eat(index)` (online body must become `{"bag_slot": i}`: hook) | yes |
| equip | `PlayerActions.equip_at(index, slot)` -> offline `inventory.equip_at`, online `act.equip {bag_slot, slot}` (the server's existing contract, intent_handlers.gd:30) | hook |
| unequip | `PlayerActions.unequip(slot)` -> offline `inventory.unequip`, online `act.equip {slot, clear: true}` | hook |
| hold (tool) | `PlayerActions.hold_tool(index)` -> `set_equipped_tool_index` | hook |
| lock / unlock | `PlayerActions.set_locked(index, on)` -> offline `set_flag(&"locked")` + `changed`; online no server op yet (queued intent, W3) | hook |
| place | `player.placer.begin` (as today) | yes |
| quick food 1/2, feed pet | `inventory.set_quick_food`, `player.feed_summoned_pet_slot` (as today) | yes |
| store / take / take all | `Inventory.transfer_to` / remove_at + add with put-back (as today, unchanged semantics, kept in InventoryUI) | yes |
| sell | `InvActions.sell_handler.call(uid)` only when W3-EXCHANGE sets it (no market screen exists; owner: the market is an online feature) | hook point |
| drop | `InvActions.drop_handler.call(uid)` only when set (LootBag.drop is BUILDSYS-branch only) | hook point |
| craft / cook with picks | `PlayerActions.craft(rid, count, picks)` -> `StationCraft.begin(rid, count, picks)` | hook |

Sorting and filtering are view-only (InvView) and need no command. Auto Sort freezes a sorted uid order in the grid;
items acquired later append at the end until Auto Sort is pressed again; the order lives on the InventoryUI instance
(session), never in the save.

**Owned (commit on the branch):** every file in section 2, `data/inv_ui.json`, the lab, `tests/t_invui.gd`, this doc,
`docs/orchestration/reports/claude-mmo-invui.md`, the hooks patch. `inventory_ui.gd` and `scenes/ui/inventory.tscn` are
assigned to INVUI (rewrite in place; this replaces W2-INV's grouped-view hunks of its hooks patch, which spec 13 and STATUS
supersede: when re-applying W2-INV hooks after a base sync, skip the inventory_ui.gd hunks).

**Hooks (exact compiling changes in `docs/orchestration/reports/claude-mmo-invui-hooks.patch`, regenerated after every base
sync; applied uncommitted in the work tree for local testing, the way ECON does, and never committed):**

| File (owner) | Change | Step |
|---|---|---|
| `scripts/player/player_actions.gd` (W2-PLAYER) | `equip_at`, `unequip`, `hold_tool`, `set_locked`; `eat` online body `{bag_slot}`; `craft(rid, count, picks := [])` | B1/B2/B3 |
| `scripts/items/inventory.gd` (W2-INV) | `var presets: Dictionary`; `extras_to_dict` writes `"presets"` only when non-empty; `extras_from_dict` reads it through `GearPresets.sanitize`; `find_first` / `consume` / `consume_by_category` / `find_by_category` skip locked instances | B1/B2 |
| `scripts/items/crafting.gd` (W2-INV / W2-PROCESS) | picks entries may be `int` (lead, as today) or `Array[int]` (exact slots, count long); `Array` param types; locked instances never picked by `default_picks`/`_plan` and refused in `picks_valid`/`consume_for_craft` | B3 |
| `scripts/items/station_craft.gd` | `begin(rid, count, picks := [])`: the first job uses validated picks instead of `default_picks` (W2-PROCESS's ProcessStation already takes picks) | B3 |
| `scripts/player/player.gd` | `craft_recipe(rid, count, picks := [])` passes picks | B3 |
| `scripts/ui/craft_ui.gd` (W1-UI) | tapping an ingredient row opens `player.ui.open_picker(rid, slot, cb)`; the chosen picks travel to `craft_recipe` | B3 |
| `scripts/core/save_game.gd` | before `player.inventory.load_array(...)`: `InvNewTracker.rebaseline(player.inventory)` | B1 |
| `scripts/core/save_sanitizer.gd` | `inventory_extras.presets` in SHAPE (Dictionary) | B2 |
| `scripts/ui/hunt_hud.gd` (W1-UI) | one line in the Menu sheet: `_sheet_btn(box, "Character", ...)` -> `player.ui.open_character()`; the "Bag" entry calls `open_bag()` | B2 |
| `scripts/dev/ui_real_capture_lab.gd`, `ui_screenshot_lab.gd`, `ui_family_lab.gd` (W1-UI labs) | replace reads of `_profile_col/_bag_col/_equip_col/_close_btn/_grid.columns == 5/_profile` with INVUI's (`ui.layout_blocks()` rects; Character screen profile text keeps `LevelDisplay.player_label()` + title) | B1 |
| `scripts/dev/inventory_lab.gd` (W2-INV) | drop its grouping asserts (×16 cells, `_cells`, `_on_cell`); keep the 100-instance seed and assert one cell per instance | B1 |
| `tests/t_ui.gd` (W1-UI) | add the INVUI ui files to `OWNED` (type floor, const-before-func) and `character_screen.gd` to `LEVEL_SITES` | B1/B2 |

run_all.gd (it does not list t_ files; its InventoryUI private reads stay valid), main.gd, game.gd, world.gd, project.godot
and touch_controls.gd need no change (InventoryUI hosts the screens; `I` / joy
Back already toggle `ui.visible`).

## 7. Screens and layouts

**Bag (ref 1).** Header (back "<", "Bag", yellow bag icon, "91 / 100" with a grey slash; right: T-stone chip from
`World.t_stones` (display only, no "+"), close X). Left 69 %: one textured panel with the 7-column grid (empty cells to
capacity, scrolls by wheel and drag), toolbar under it: Auto Sort (dark, light text, 1 px border, radius <= 4, ~20 % W) with a
"▲" dropdown segment listing the sort keys; right-aligned squares Select, Filter, Lock (+ Trash only with `drop_handler`).
Right 28 %: ItemInspectPanel running from the header to the bottom edge, its primary button aligned with the toolbar like
the reference's Form Bond. Selecting a cell moves the brackets, clears NEW, updates the panel. Nothing selected: the panel
shows the bag summary (capacity, filter) and no actions.

**Character -> Gear (ref 2).** Header "< Character", X. Left 36 %: portrait square (13 % H; a SubViewport rendering of the
player's own survivor rig once, `UPDATE_ONCE`; fallback the occupation's white icon in the frame), name, status line =
occupation · title (no clan), green XP bar "Lv. 13 (222 / 345)" with the current XP in yellow, three power rows (white icon,
label, yellow value, ">" opening Detailed Stats at that group), dashed separators, outlined "Detailed Stats" button. Centre
33 %: one "Gear" tab (yellow, dark text), the preset row (1-4; active bracketed; locked with lock glyph; tap a locked one ->
"Unlocks at Lv. N"), 3x3 EquipmentSlots. Right 26 %: items for the selected slot (3 columns, Lv top-right, worn one with a
green corner marker); worn selected -> yellow Unequip; another selected -> opens Equipment (compare) with it preselected.

**Equipment / My Info (ref 3).** Header "< Equipment", X. Left 35 % 3x3; centre 33 %: tan "My Info" band, three columns
Attack / Defense / Accuracy (white glyph: ui_icons attack, defense; InvGlyphs target), label on a black band, big number
(6.5 % H, >= 24 px phone); with a candidate selected each number shows "58 -> 61 +3" (POSITIVE for gains, TEXT_2 with "−"
for losses; the sign carries the meaning, not only colour); requirements line only if the item has one. Below: hex row of
real combat tactics (HexButton). Right 25 %: candidates for the slot; none -> "There are no items available to equip." and
no button; a candidate selected -> yellow Equip.

**Storage / dinosaur cargo (spec 17).** Header "< Storage Box" (or "<pet name> Cargo", corpse title, loot bag title).
Two InventoryGrids side by side, each with its own capacity strip and Auto Sort / Filter; the bag side's contextual action
is "Store" (when `allow_deposit` and `_can_store_selected`), the container side's "Take" and "Take all" (when `take_all`);
`readonly_reason` shows as a grey line and hides Take. A small Inspect button opens ItemInspectPanel as an overlay. Every
transfer keeps uid, level and attributes; on_take / on_empty fire as today.

**Ingredient picker (spec 19).** Modal over CraftUI: header "< Choose <slot role>" with the slot's need ("1 of 1"); grid
filtered to `Crafting.stacks_for_slot` minus locked; least valuable preselected (no rare attribute, lowest level); the
inspect panel shows the chosen item's attributes and a warning line for rare or Lv. >= 40; primary "Use" enabled when
exactly `count` instances are chosen.

## 8. Save fields (optional, old saves load without them)

| Field | Where | Default for old saves | Notes |
|---|---|---|---|
| NEW | `ItemStack.flags` `"new"` (already serialized by `to_dict`, kept by the sanitizer `_stack`) | absent = not NEW | Only on uid'd (non-fungible) stacks: `can_merge_with` compares flags, so a flag on ammo would stop merging. Never set by a load or migration (`rebaseline`), so t_save goldens are unchanged |
| locked | `ItemStack.flags` `"locked"` (exists) | absent = unlocked | Unchanged format |
| presets | `player.inventory_extras.presets = {"active": int, "sets": [{slot: uid}, ...]}` | absent = no presets, active 0 | Written only when non-empty; sanitized (slots from EQUIP_SLOTS + "tool", uids by UID_RE, at most `presets.count` sets) |

Nothing else in the save changes. Auto Sort order and the filter are session state.

## 9. Assumptions (each checked against the docs; listed again in the report)

1. ASSUMPTION 7 columns (spec 13 "approximately seven"; the reference shows 8). Doc check: spec 13 s5, s25; ref measured 8.
2. ASSUMPTION NEW tag top-left and Lv top-right (reference) over s6 "near the bottom". Doc check: spec 13 s1 calls the screenshots primary.
3. ASSUMPTION NEW is set when a uid'd instance enters the player bag during play (pickup, loot, craft output, take from storage or cargo) and cleared when the player selects it. Doc check: spec 13 s7 defers to "the game's existing rules"; none exist (grep: no NEW in code).
4. ASSUMPTION lock keeps its existing meaning (refuses equip, store and auto-tool: inventory.gd:51, 246, 351; server intent_handlers.gd:272; run_all.gd:863) and adds spec 13's protection from craft / cook / process consumption and auto-consume (hooks in crafting.gd and inventory.gd). The UI hides Equip / Store on a locked item and says "Locked". Doc check: spec 13 s9; spec 05:23. Narrowing lock to allow equipping changes a server rule, so it is listed as an owner question, not done.
5. ASSUMPTION Auto Sort is view-only (InvView) with a frozen order per session; keys Acquired (slot order, then created_at), Name, Type (first category), Level (desc), Rarity (item_rarity.json order), Attributes (rare count, then sum of positive levels), Durability (fraction). Doc check: spec 13 s9 "reorganize the presentation"; spec 05:23.
6. ASSUMPTION filter groups in `data/inv_ui.json` (All, Materials, Food, Tools & Weapons, Gear, Building, Medicine, Animals, Rare traits, Locked) over the ~70 item categories. Doc check: spec 13 s9 "relevant item categories"; spec 05:23.
7. ASSUMPTION attribute classes from spec 04 lines 8-11 keyed in snake_case on `ItemStack.attributes`; technical keys never shown. No item rolls these yet (no trait system on any branch), so in play the sections stay empty until a data package rolls them; the lab stamps them. Doc check: spec 04, spec 08:20 (berry trait names illustrative).
8. ASSUMPTION rare marker = small green bottom-right triangle (spec 13 s11 optional improvement; the green top-left triangle in ref 2 is read as the "worn" marker in candidate lists).
9. ASSUMPTION no Sell on Market and no Trash/Drop button until a market screen (W3-EXCHANGE) or a drop command (BUILDSYS LootBag.drop) sets `InvActions.sell_handler` / `drop_handler`. Doc check: owner 2026-10-20 "the market is an online feature"; never inert UI.
10. ASSUMPTION Combat / Crafting / Gathering Power = the highest skill level in a data-listed group of SkillState trees (combat: melee, ranged, defense; crafting: processing, weapon_tools, tailoring, construction, cooking; gathering: gathering, butchering, farming). Doc check: spec 13 s13 names the rows with no formula; spec 03 forbids invented coefficients; skill levels are real numbers.
11. ASSUMPTION Detailed Stats lists only Attack, Defense, Accuracy, crit, max health (+ gear), energy, bag capacity, held tool power, heat / cold resistance and the 12 skill levels; no Str/Dex/Agi/End/Int (PRD 5.2 / spec 03 attributes do not exist in code). Doc check: spec 13 s13 "only statistics actually supported".
12. ASSUMPTION four presets unlocking at character Lv. 1 / 10 / 30 / 50 (data); a preset stores slot -> uid for the 7 EQUIP_SLOTS and the held tool; applying unequips, then equips stored uids still in the bag through the same commands, refused whole if the bag lacks room; the active preset follows gear changes. Doc check: spec 13 s14 "do not introduce unlocked loadouts that the player has not earned"; ref shows 2 open + 2 locked at Lv. 13.
13. ASSUMPTION only the Gear tab is shown: there is no cosmetic gear data (only blue_dye), so a Decorative Gear tab would be empty (inert). Doc check: spec 13 s14, s25 lists only "Yellow active Gear tab"; PRD treats cosmetics as cash-shop.
14. ASSUMPTION 3x3 mapping: accessory1 / head / accessory2, weapon / body / held tool, arms / legs / empty. Accessory cells show a ring silhouette and the empty-state text (ref 3 shows this state); no accessory items exist yet. Doc check: spec 13 s14 "support equipment types already present"; EQUIP_SLOTS.
15. ASSUMPTION silhouettes = the slot's representative rendered item whitened at 22 % alpha (HexButton.white_material approach), ids in data. Doc check: spec 13 s14 "faded silhouette icons"; no download.
16. ASSUMPTION Character status line = occupation · title; no clan, History, Flag or Title controls (none exist). Doc check: spec 13 s13 "if supported".
17. ASSUMPTION portrait = a one-shot SubViewport render of the player's survivor rig; fallback the occupation icon. Doc check: no portrait asset in the project.
18. ASSUMPTION hex ability row = combat tactics with real verbs (tackle, kick, roll); tap shows its description; none locked unless data gates one. Locked style grey + lock glyph, not the reference's red (red only for danger). Doc check: spec 13 s15 "where applicable"; UiTokens.
19. ASSUMPTION Bag "Equip" on gear opens the Equipment compare screen with that item preselected (spec 13 s15 asks for a comparison when selecting replacement gear); "Hold" for work tools acts directly.
20. ASSUMPTION ingredient picker: exact instances for every unit of the slot (`Array[int]` picks), least valuable preselected, warning at a rare attribute or Lv. >= 40 (data). Doc check: spec 13 s12, s19; spec 08:114-120.
21. ASSUMPTION header shows the T-stone chip (World.t_stones; display only). No second currency exists.
22. ASSUMPTION Bag and Character are reached from the HUD Menu sheet (Bag, Character) and `I` (Bag); inside the family "<" goes back one screen and X closes all.

## 10. Acceptance checklist (measurable; test or shot that proves it)

Viewports: 1600x900 gl_compatibility (judge), 1600x900 Forward+, 1920x1080, 844x390 and 804x452 (667x375) landscape.

| # | Gate | Proof |
|---|---|---|
| A1 | Header 72-90 px and toolbar 90-108 px at 1600x900 (8-10 % / 10-12 %); main 78-82 % | t_invui 20 + B1 shot measured |
| A2 | Phone: header >= 44, toolbar >= 48 holding 44 px buttons, cell >= 72, 6-8 columns, >= 3.3 rows visible | t_invui 20 |
| A3 | 7-8 columns at 1600x900; cells square (0.95-1.05) and 15-18 % H | t_invui 20 + shot |
| A4 | Every tap target >= 44 px at 844x390; contextual actions (group `inv_contextual`) >= 56 px | t_invui 20 `_check_targets` on BagScreen; B2-B3 extend to the other screens |
| A5 | Lv and NEW text >= 12 px at 844x390; Lv in TEXT_2 grey | t_invui 20; t_ui type floor |
| A6 | No clipped, overlapping or off-screen text at any listed viewport ("Lv. 60" beside NEW in a 72 px cell; long names ellipsized) | t_invui 20; ui_real_capture_lab-style `text_fits` / overlap scan in the lab (B4) |
| B1 | Capacity = `used_slots / slot_count`, cage counts 4, "/ 142" when slot_count is 142, DANGER when full, full bag refuses pickups | t_invui 2 |
| B2 | Open / close the Bag; `I` toggles; Esc / ui_cancel closes | t_invui 1 + B1 input check |
| C1 | One cell per instance (3 berries = 3 cells, 3 uids); empty cells to capacity; cage drawn 2x2 | t_invui 3 + shot |
| C2 | Lv. 45 / Lv. 60 distinct; no Lv on level-less items | t_invui 4 |
| C3 | NEW on picked-up instances only (never fungible stacks, never on load); cleared on select; survives save | t_invui 5, 19 |
| C4 | Brackets on exactly the selected cell; survive refresh and sort; cleared on removal | t_invui 6 |
| D1 | Inspect shows name, Lv, material type, durability "cur / max", processing, real attributes only | t_invui 7 |
| D2 | Positive gold, negative grey, rare green, each under its section label; technical keys hidden; rare marker only on rare items | t_invui 8 |
| D3 | Valid actions only (berry: no Equip; weapon: no Eat; locked: no Sell / Drop / Equip / Store) | t_invui 7, 11, 18 |
| E1 | Sorting (7 keys) and filtering never change uid, level, count, attributes, flags or slot order; every instance shown once | t_invui 9, 10 |
| E2 | Lock through the command layer, saved, refused by crafting even when forced | t_invui 11 |
| F1 | Storage / cargo split view; Store / Take keep uid, level, attributes | t_invui 12 + storage/cargo shots |
| G1 | Equip / unequip the exact instance through PlayerActions | t_invui 13 |
| G2 | Defense rises by exactly the armour once; unequip restores every stat; compare preview predicts without equipping | t_invui 14 |
| G3 | Presets: 2 unlocked at Lv. 13, locked ones refused, apply restores the same uids | t_invui 15 |
| H1 | Picker: rare bone never preselected, warns, crafting consumes exactly the chosen uid | t_invui 16 |
| H2 | Picker: each berry pickable, cooking consumes exactly the chosen one | t_invui 17 |
| H3 | Sell hidden without a market; with `sell_handler` set, it gets the exact uid; locked never sellable | t_invui 18 |
| S1 | NEW, locked and presets round-trip; an old save without presets loads; t_save goldens unchanged | t_invui 19 + t_save |
| P1 | bag_ui_lab open times: every screen < 150 ms, the 91-item bag < 50 ms, a 142-slot bag < 50 ms (headless build + layout, measured) | lab "[bagui] open times" line |
| V1 | Shots at 1600x900 glc of bag, inspect, character, equipment, storage, cargo, picker read side by side with the references: every s25 detail present (dark earthy background, dense grid, small grey Lv, blue NEW, yellow brackets, wide Auto Sort, bottom-right squares, capacity at top, dark character panel, yellow Gear tab, numbered presets, silhouette slots, Detailed Stats, consistent inspection) | builders open each PNG; reviewer + fidelity judge |
| R1 | All existing gates: every t_*.gd PASS (t_save's 5 deliberate SCRIPT ERRORs), run_all `[tests] PASS`, `tools/smoke.sh --no-import` SMOKE PASS, the INVUI lab 0 SCRIPT ERROR lines, no new Godot-*.ips | each builder |

## 11. Phase plan for the builders (spec 13 s24)

**B1 Bag + inspection (phases 1-2).** InvTheme, inv_grain.gdshader, InvPaint, InvGlyphs, InventorySlot, InventoryGrid,
InvView, InvAttributes, InvActions (bag context), InvNewTracker, CapacityIndicator, InvHeader, BagToolbar,
ItemInspectPanel, BagScreen; InventoryUI rewritten as the host with the contract of section 4 (storage still routed through
the old code path is acceptable until B3, but `current_screen()` must answer); hooks: player_actions (equip_at, hold_tool,
set_locked, eat body), inventory.gd lock-skip in consume/find, save_game rebaseline, W1-UI labs + inventory_lab + t_ui.
Acceptance: t_invui 1-11, 18 (no handler: hidden), 20 for the Bag; A1-A6, B1-B2, C1-C4, D1-D3, E1-E2, P1 (bag); bag and
inspect shots at 1600x900 glc + Forward+ and 844x390 read against the Bag reference.

**B2 Character, Gear, Equipment (phase 3).** InvStats, EquipmentSlot, GearPresets (+ inventory.gd presets and sanitizer
hooks), GearPresetSelector, CharacterScreen, DetailedStatsPanel, EquipmentScreen (My Info, hex row, compare); hunt_hud
Character entry; t_ui LEVEL_SITES. Acceptance: t_invui 13-15, 19; G1-G3, S1; the stat-once check also run in the lab
(equip, equip, unequip, diff); character and equipment shots against refs 2 and 3.

**B3 Integration (phase 4).** StorageScreen (show_storage / show_pet_bag through the shared grid for basket, home cargo,
pet cargo, corpse loot, BUILDSYS chest and loot bag opts), ItemPicker + crafting/station_craft/player/craft_ui hooks
(exact picks), `sell_handler` / `drop_handler` hook points documented for W3-EXCHANGE and BUILDSYS. Acceptance: t_invui 12,
16, 17, 18; F1, H1-H3; storage, cargo and picker shots; earned_training_probe and t_player pets bag still pass.

**B4 Polish (phase 5).** Grain and torn edges tuned until the panels read as weathered wood/canvas at 1600x900 glc without
hurting legibility; FontVariation condensed look if it reads closer; responsive check at 1600x900, 1920x1080, 844x390 and
804x452 with safe insets; restrained motion (panel open <= 120 ms fade/slide 8 px, tab switch <= 80 ms, no bounce or
particles, a brief flash on transfer); keyboard / mouse wheel / hover tooltips with the same content reachable by tap;
rarity and attribute class never by colour alone (shape marker + section labels); performance P1 for a 142-slot bag.
Acceptance: A1-A6 at every viewport, P1, V1 on all seven shots, Forward+ = gl_compatibility look.

## 12. Open questions for the owner (non-blocking; the assumptions above proceed)

- Lock: should a locked item still be equippable (spec 13's lock is about selling / dropping / consuming, the current lock
  also refuses equip and store; the server refuses equipping a locked item)? Changing it touches server authority.
- Decorative Gear tab: hidden until cosmetic gear exists (assumption 13).
- Preset unlock levels 1 / 10 / 30 / 50 (assumption 12).
- Power rows as skill-group levels (assumption 10).

Risk: the owner's main checkout (`~/Documents/deadfront-siege`) holds an uncommitted UI pass that modifies inventory_ui.gd,
hunt_hud.gd, item_icons.gd and animal_screen.gd (STATUS: do not overwrite it). INVUI's rewrite of inventory_ui.gd will
conflict with it whenever that pass is committed; the integrator resolves it.
