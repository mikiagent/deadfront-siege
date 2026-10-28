# UICHAR: Character (C1), Skills (C3), Orders (C4)

Branch `claude/mmo-uichar`, cut from `claude/mmo-overhaul` at a8a41cbf. Not pushed, not merged. No credits spent.

## Public entry points (for the B3 nav menu)

| Screen | Call from the HUD | Lower-level call |
|---|---|---|
| C1 Character | `HuntHud.open_character()` | `player.ui.open_character()` (`InventoryUI`) |
| C3 Skills | `HuntHud.open_skills(tree: String = "")` | `SkillsSheet.open(skills, tree)` |
| C4 Orders | `HuntHud.open_orders()` | `OrdersSheet.open(player)` |

Each `HuntHud.open_*` closes the HUD's open sheet first. On each screen, ‹ emits `back_requested`
(Character: `InventoryUI.menu_requested`), and the HUD connects that to `_back_to_menu()`, which opens
the MENU sheet. ✕ and Esc return to the HUD. Until B3 lands, the existing MENU sheet lists Character,
Skills and Orders. That is a three-line edit in the `&"menu"` block of `hunt_hud.gd`, and it will
conflict with B3's rewrite of that block. Keep B3's version and call the three functions above.

## What shipped
- **Shared chrome:** `game/scripts/ui/uichar_chrome.gd`. It has no `class_name` and is preloaded by
  path, so it cannot collide with another package. It provides §8: a dimmed world, the HEADER bar with
  "‹ Title" and a torn edge (`UiTokens.draw_torn_edge`), tabs, a right slot, ✕, PANEL boxes, a
  parchment gradient header, the GOLD button (grey when disabled), dark buttons, the Roboto Condensed
  theme, and gold `Brackets` (`UiTokens.draw_brackets`).
- **C3 Skills:** `skills_sheet.gd` is rebuilt as a full-screen sheet.
  - Left: a 4-column grid of the 12 skills. Each cell shows the name, a gold unread dot when a node is
    buyable now, the white symbol, a thin XP bar and the Lv. Banked XP at the cap shows as "FULL · n XP".
  - Right: the detail panel with a parchment name and Lv., Skill XP, SP spent here, and "Levels by …".
    The unlock list keeps every rule of the old tree view: Unlock or Refund, refund-blocked reasons, the
    auto-learned line, and the not-in-game rows. Under it is a GOLD "Spend n SP on <next node>".
  - The header shows "SP n free". The F7 `skill_debug.gd` is untouched.
- **C1 Character:** `character_sheet.gd` (new) takes over the bag's old Character page. It is hosted by
  `InventoryUI`, so it shares the bag and player bindings.
  - Tabs: Equipment, Titles (every title, with the held one in gold) and Appearance (the "No decorative
    gear yet" note from INVSCREENS).
  - Left: the profile on parchment, then the stats list.
  - Centre: the figure, with Head, Body, Arms and Legs on the left, Weapon, Tool, Ring and Bag on the
    right, and Food 1 and Food 2 underneath. The selection bar has Unequip and Open bag ›.
  - Gear sets 1-4 sit in the header's right slot.
  - Right: the Survival panel.
  - The slot behaviour is moved from INVSCREENS unchanged: a tool slot cycles tools, a food slot eats,
    and Unequip refuses with "Bag is full."
  - `inventory_ui.gd` lost its character page (−300 lines). Its Character tab now opens the sheet. Bag,
    storage, cargo, the item card and multi-select are unchanged. `hide_ui()` resets the pages, so the
    next BAG open shows the bag.
- **C4 Orders:** `orders_sheet.gd` (new) lists all 28 standing orders (`data/world/objectives.json`).
  - Each row has a numbered ring (a green check when done, gold on the running order), the title and
    hint, and the progress (or "Done").
  - Detail: a parchment title, "Order i of n · running now / x so far", the how-to line (the hint),
    reward chips (+XP, +T-stones), and Track on HUD / Tracking on HUD / Done.
  - **HUD edit (small):** `_draw_quest` now reads `OrdersSheet.hud_step(player)` instead of
    `Objectives.current(player)`. That returns the running order, or a later one the player tracked.
    Only the running order completes and pays out.
- `hunt_hud.gd`: the three `open_*` functions and `_back_to_menu`, `sheet_open()` counting the Orders
  sheet, the MENU entries, and the quest-card line. No other HUD changes.
- `game/data/ui_icons.json`: `‹` and `›` are added to `typographic`, because t_uiicons scans string
  literals.
- **Tests and labs:**
  - New `game/tests/t_uichar.gd`. At both sizes it opens each screen through the HUD entry points.
    It checks that every visible control is on screen, the header and panels do not overlap, the ten
    slots do not overlap, and every button is at least 64 px. It also checks the primary actions:
    Unequip, Open bag, the bag's Character tab, Titles, Spend SP, cell select, Track on HUD driving
    the card, and ‹ opening the MENU.
  - New lab `scenes/dev/uichar_lab.tscn` takes the screenshots.
  - Updated for the new structure: t_invscreens (character block), t_w2_skills and t_skillfeel (the XP
    text is now in the detail panel as "x / y"), and t_ui (Skills is full-screen on desktop too).
  - Also updated: `ui_real_capture_lab.gd` (panel = the sheet, 4 columns), `skillfeel_lab.gd` and
    `inventory_lab.gd`.

## Screenshots (running build, home island, windowed lab)
`docs/orchestration/reports/uichar/`: `character_1600x900.png`, `character_844x390.png`,
`skills_1600x900.png`, `skills_844x390.png`, `orders_1600x900.png`, `orders_844x390.png`. Each is
under 300 KB; the desktop shots are quantized to 48 colours, so gradients band slightly. Each was
compared side by side with its §0 mockup. The layout, chrome, brackets, parchment and GOLD button
match. The differences are listed under assumptions.

## Gates (worktree head)
- import: 0 ERROR lines
- `[t_uichar] PASS`, `[t_ui] PASS`, `[t_uiicons] PASS ids=196 …`, `[t_fieldhud] PASS`, `[t_invscreens] PASS`,
  `[t_uitokens] PASS`, `[t_w2_skills] PASS`, `[t_skillfeel] PASS …`, `[t_skillbuy] PASS …`
- run_all: `[tests] PASS`. It logs 6 SCRIPT ERROR lines, which are the known ones: 3 TouchControls
  compile-order lines and 3 from the deliberate econ fault test.
- `bash tools/smoke.sh --no-import`: `SMOKE PASS`

## ASSUMPTIONs
1. **No blur pass exists.** The full-screen wash is a near-opaque (0.93) dark `SCREEN_DIM`, which keeps
   text readable over the world.
2. **The build has no fullness, thirst, time-awake or hygiene meters.** The Survival panel shows the
   Exhaustion meter (tier word, %, MOOD colour). Food, Thirst and Hygiene show as status states (Full
   or Can eat; Thirsty, Quenched or Fine; Very dirty, Dirty, Clean or Fine). The footer reads
   "Rested · all needs normal" or lists what is off.
3. **Both accessory slots take a ring or a bag** (`Inventory.slot_for`). Following the mockup, the
   first is labelled "Ring" and the second "Bag".
4. **The figure is the survivor's portrait** (`PlayerPortrait`, a headshot or the silhouette). There is
   no full-body render.
5. **Gear presets 1-4 (INVSCREENS) moved to the header's right slot.** The mockup has no place for them.
6. **Appearance tab:** the game has no decorative gear, so the tab shows a note. Titles lists
   `titles.json`.
7. **Skills GOLD button:** "Spend n SP on <first buyable node>". A tree has no SP sink of its own, so
   the button disabled reads "No SP to spend" or "Nothing to unlock in X yet". The unread dot means a
   node of that tree can be bought now.
8. **Skill description:** "Levels by <levels_by>." comes from trees.json. The mockup's
   "Rested · full XP gain" line is left out, because no such XP modifier exists.
9. **Orders:** objectives.json has no chapters, steps or item rewards. The list header is "Standing
   orders", the how-to is the hint, and rewards are XP and T-stones only. **There is no "Show on map"
   button,** because orders carry no place.
10. **The tracked order is session-only** (`OrdersSheet.tracked`, a static var). It is not saved, so
    the save format is unchanged, and a load follows the running order. Tracking a later order changes
    only what the card shows.
11. The skill cell's "FULL · n XP" label shows only when XP is banked (more than 0). A fresh Lv. 1
    survivor is capped in every tree, and the label was noise. The bar still reads full at the cap
    (spec 25 §7).

## Risks / for the next agent
- **Merge with B3 (uinav):** both edit the `&"menu"` block in `hunt_hud.gd`. Resolve to B3's layout
  with `open_character` / `open_skills` / `open_orders`.
- **Merge with other packages that touch `inventory_ui.gd`:** the character page code is gone from it
  and now lives in `character_sheet.gd`.
- `docs/current/screens/*.webp` are stale for skills and bag. Rerun `tools/ui_screens.sh` windowed.
- **Not checked by eye:**
  - portrait 390x844
  - the populated Skills tree after SP is spent
  - the Orders list once orders are done (check rings)
  - the empty-slot silhouettes INVSCREENS chose (the head one reads as a chest piece; that is
    existing art).
- The headless test's on-screen/overlap check skips controls inside ScrollContainers, the same as
  t_invscreens.
