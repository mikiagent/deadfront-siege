# UICRAFT: craft stations (D1), place materials (D3), build mode (D2)

Branch `claude/mmo-uicraft`, cut from canon `claude/mmo-overhaul` at `a8a41cbf`. Spec:
`docs/design/ui-redesign-spec.md` §7 D1 / D2 / D3, §8 chrome, §11 owner rules. No paid generation,
no push, no merge.

## What shipped

- **D1 Craft stations** (`game/scripts/ui/craft_ui.gd`, rewritten). Full-screen sheet with the §8 HEADER
  bar and torn edge: Back (white `back` icon), "Craft / Build", station hint (desktop), Build, ✕.
  Left: station chooser (By hand / Workbench n m / Bonfire n m / … all 12, scrolls sideways; the
  chosen one gold-rimmed) over a 2-column category grid with gold brackets. Middle: search plus the
  recipe list grouped by output (tool class, else the output's first category), two cells a row,
  gold brackets on the selection. Right: parchment header, Max Level / Related Skill / Station /
  Time · Success · Flawless, skill lock line, Materials bar with ✓ / ✕ have / need rows, CRAFTFEEL
  stake lines, bag preview, and Craft (GOLD CTA) / Craft ×5 pinned under the scroll. Roboto Condensed
  through a Theme on the sheet. Old node names the tests and labs use are kept (CraftOne, CraftFive,
  CraftFooter, RecipeMeta, DetailTitle, DetailChance, DetailLock, DetailBagPreview, CraftHint, BuildRow).
- **D3 Place materials** (new `game/scripts/ui/craft_place.gd`, a sub-view of CraftUI, opened from the
  detail's "Materials · Place materials" bar). Crafting complete %, one chevron per slot (OK_GREEN
  once placed, gold outline on the active slot), the slot header (name n / need, Accepts: …), the
  candidate grid (icon, Lv., 3 quality pips, gold order badges for the instances the slot will use,
  gold brackets on the focus), the parchment focus card with trait chips (InvAttributes classes), the
  expected result (Crafting.preview: traits from slot 1 only), a 1-10 stepper, the success rate, and
  Place material → Craft. A placed instance is an explicit pick checked with `Crafting.picks_valid`
  (refused with a notice when the recipe would run short). Craft hands one uid per slot to
  `StationCraft.begin(rid, count, uids)`, which leads each slot with them (the plan fills the rest).
- **D2 Build mode** (`game/scripts/ui/build_ui.gd`, rebuilt per the owner's stretched-sheet rule).
  An opaque drawer down the left edge: Build, Move buildings, ✕; tier tabs from `structures.json`
  (Thatch Lv. 1 / Wood Constr. 5 / Stone Constr. 20 / Metal Constr. 35, gold underline, red level when
  locked); flat-top hex tiles in Parts (the tier's modular pieces with their cost), Stations (kits in the
  bag) and Blueprints (construction sites via BuildFlow); the tier's materials and Construction level
  along the bottom. A tile starts the ghost and the drawer stays open: "Pick a building spot" banner,
  a cost bar at the bottom (in the drawer's bottom line on a phone). The construction-site sheet opens
  in the same drawer. The BUILD rail hex now opens this drawer.
- **Placement row** (`hunt_hud.gd`, small): ROTATE icon only, SAVE green check on an OK_GREEN rim,
  CANCEL red cross, words inside the hex, no key letters; 88 px on desktop, 64 on a phone; the row's
  offsets scale with the hex; it keeps off the drawer (`BuildUI.taken_rects()` added to
  `_placer_taken`). Red ghost when partly outside the Domain was already the rule (BuildGrid /
  StructureGrid return `unclaimed` for any cell outside the claim, the ghost turns `_mat_invalid` red);
  unchanged.
- **craft_card.gd** (the in-world card over a station): flat-top hex slots with a pie fill instead of
  circles, HUD_FILL panel, Roboto Condensed title, GOLD odds.

## Files outside the three screens (all small)

- `hex_button.gd`: two vars, `glyph_color` (tint of a white glyph, default white) and `bottom_scale`
  (bottom_text size, default 0.40 = shipped). Defaults keep every other hex unchanged.
- `hunt_hud.gd`: `_build_place_hexes` restyle, `_refresh_place_hexes` per-canvas size, `_placer_rel`
  (no caption → hex rect), `_placer_taken` (build drawer rects; also dropped a `_place_hexes.has(ctl)`
  on a non-hex Control that printed a TypedArray error every frame while placing), BUILD hex →
  `BuildUI.toggle()`, `open_structure` hides the drawer (the card opens where the drawer sits).
  `hud_layout.gd` untouched.
- `player.gd`, `player_actions.gd`, `station_craft.gd`: an optional `uids` argument through
  `craft_recipe` → `craft` → `StationCraft.begin` (D3 picks). No crafting rule changed.
- `game/scripts/dev/snap_touch.gd`: its BUILD step drives the drawer (snap_build_lab --snap-touch PASS).
- `game/tests/t_w2_skills.gd`: finds the materials header by node name (the "INGREDIENTS" label is now
  the Materials bar).

## Gates

- `game/tests/t_uicraft.gd` (new): D1 / D3 / D2 at 1600x900 and 844x390 — tap targets ≥ 64 px, panes
  inside the view and apart, Craft starts the recipe, D3 order badges / 67 % / OK_GREEN chevron /
  slot-1 trait inheritance / Craft with the placed uid leading, drawer tiers and flat-top tiles, ghost
  with the drawer open, ROTATE / SAVE / CANCEL looks, row off the drawer. **PASS**
- t_ui, t_uiicons, t_fieldhud, t_claimfix, t_buildflow, t_build, t_buildsys, t_process, t_craftfeel,
  t_w2_skills, t_invscreens: **PASS**. run_all `[tests] PASS`. `tools/smoke.sh --no-import` → `SMOKE PASS`.
  snap_build_lab --snap-touch: PASS.
- Shots (running build, `game/scripts/dev/uicraft_lab.gd`): `docs/orchestration/reports/uicraft/`
  `d1_craft_*`, `d3_place_*`, `d2_build_*` at 1600x900 and 844x390, each ≤ 211 KB.

## Assumptions (`# ASSUMPTION:` in code)

1. Category grid = All + recipes.json `skill` values (Material Processing, Cooking, Clothing,
   Weapons & Tools, Structures, Farming). The canvas's Rest / Shelter and Taming tiles have no recipe
   data behind them, so they are not shown.
2. Recipe list groups = the output's tool class (Axe, Knife, Pick, Hoe), else its first item category.
3. D3 stepper runs 1-10 crafts.
4. D3 quality pips = the instance's rarity tier (the bag's art_slot cue), three pips.
5. Online crafts send no picks yet (server intent is recipe_id + count); the server uses default picks.
6. D3 completion counts a slot's units once it is placed (the plan fills a placed slot in full).
7. Build tile icon for a modular piece = its tier's first cost material (no piece icons in data).

## Not done / risks

- The canvas's description line ("A one-handed knife made in a hurry"), the "Material" tag and
  "Energy to craft" in D3 have no data source; the detail shows the item's stat line instead.
- The docs gallery (`docs/current/screens/*.webp`, `tools/ui_screens.sh`) was not regenerated; the
  text in `docs/current/ui-screens.md` describes the new screens and the PNGs are in the report folder.
- The old HUD BUILD bottom sheet (`_toggle_sheet(&"build")`) still exists (web_soak uses it) but no
  control opens it.
- The drawer is fixed 494 px (desktop) / 312 px (phone); portrait phones get the same drawer, untested.
- Merge risk: `hunt_hud.gd` and `hex_button.gd` are shared with other UI packages (small hunks).
- No save format change.
