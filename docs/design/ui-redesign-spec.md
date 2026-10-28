# UI redesign spec — Durango-style hex HUD and screens

> **Status: proposal for build.** Source: the owner-reviewed design canvas
> "Deadfront Wildlands UI" (claude.ai artifact `PGomnk99fvQNYLGUG6XEnz`, 19 artboards, 2026-10-28).
> Owner direction given while reviewing it is marked **[owner]**; everything else is the canvas's
> proposal and may be changed in review. The canvas's sample numbers (perk names, ranks, recipe times)
> are placeholders, not tuning. Current behavior lives in [`../current/hud.md`](../current/hud.md) and
> [`../current/ui-screens.md`](../current/ui-screens.md); this page describes the target only.
>
> Owner screenshots that drove this were pasted in chat and not saved to disk (durango-prompts
> convention): the owner's current build (hex rail, treadmill, Animals/Craft/Domain/Comms panels) and
> Durango references (hex gather fan, material slots, skill grid, construction placement, Domain tabs,
> Communication list).

## 0. Target screenshots

Rendered from the canvas artboards at 1600×900 (desktop gate size) on 2026-10-28 with headless
Chrome, files in [`ui-redesign/`](ui-redesign/). **Status: owner-reviewed proposal, not current
build.** The world backdrop and item icons are placeholder SVG art drawn for the canvas — match the
UI, not the art. "Variant" shots show an interactive state the default view hides.

| | |
|---|---|
| **A1 Create your survivor**<br>![A1](ui-redesign/a1-create-survivor.webp) | **A2 Pick your tamed island**<br>![A2](ui-redesign/a2-island-pick.webp) |
| **B1 Field HUD** (idle: harvestable name pills)<br>![B1](ui-redesign/b1-field-hud.webp) | **B1 variant — gathering** (camera panned to Rock, Stone hex 62% pie-filled, yield card with trait chips)<br>![B1 gathering](ui-redesign/b1-field-hud-gathering.webp) |
| **B2 Combat HUD**<br>![B2](ui-redesign/b2-combat-hud.webp) | **B2 variant — net ready** (target ≤30% and groggy, NET hex gold)<br>![B2 net](ui-redesign/b2-combat-hud-net-ready.webp) |
| **B3 Nav menu**<br>![B3](ui-redesign/b3-nav-menu.webp) | **B4 Toasts, radials & dialogs**<br>![B4](ui-redesign/b4-toasts-radials-dialogs.webp) |
| **C1 Character**<br>![C1](ui-redesign/c1-character.webp) | **C2 Bag** (one item per cell, colour variants)<br>![C2](ui-redesign/c2-bag.webp) |
| **C3 Skills**<br>![C3](ui-redesign/c3-skills.webp) | **C4 Orders**<br>![C4](ui-redesign/c4-orders.webp) |
| **D1 Craft (stations)**<br>![D1](ui-redesign/d1-craft-stations.webp) | **D2 Build mode** (hex blueprint tiles, ROTATE / SAVE / CANCEL)<br>![D2](ui-redesign/d2-build-mode.webp) |
| **D3 Craft — place materials**<br>![D3](ui-redesign/d3-craft-place-materials.webp) | **E1 Animals & pack**<br>![E1](ui-redesign/e1-animals.webp) |
| **E2 Taming pen**<br>![E2](ui-redesign/e2-taming-pen.webp) | **E2 variant — taming started**<br>![E2 started](ui-redesign/e2-taming-pen-started.webp) |
| **F1 Domain — declare**<br>![F1](ui-redesign/f1-domain-declare.webp) | **F1 variant — declared, plot grid**<br>![F1 plots](ui-redesign/f1-domain-plots.webp) |
| **F2 World atlas**<br>![F2](ui-redesign/f2-world-atlas.webp) | **F3 Communication**<br>![F3](ui-redesign/f3-communication.webp) |

## 1. Owner direction captured in review

1. **[owner]** In-game buttons are hexagons, not circles. Building UI is hex. Resource gathering is the
   radial hex menu.
2. **[owner]** A gather hex shows the resource symbol greyed out, and the hex fills like a pie chart
   while gathering. One item per gather.
3. **[owner]** The yield notification appears above the resource (not in a side feed): thumbnail,
   name, level, and trait chips under it.
4. **[owner]** Trait chip colours: **grey = negative, yellow = positive, green = rare special.**
5. **[owner]** Unselected harvestables show a small name box; selecting one opens the radial and moves
   the camera toward it.
6. **[owner]** The side feed shows **skill XP gains**, not item pickups (same screen spot).
7. **[owner]** Keep the exhaustion treadmill with its face indicator.
8. **[owner]** Collapse ANIMALS, BUILD, SKILLS into the bottom-left MENU. CLAIM sits by the minimap,
   small and unobtrusive.
9. **[owner]** Build placement: rotate is icon-only (no key letter), confirm is **SAVE** with a green
   check, the cancel hex says **CANCEL**.
10. **[owner]** Party frames: a leader crown on the party leader (multiplayer reference).
11. **[owner]** Items never stack — no counts on quick slots, food slots or bag cells
    (matches spec 05 and `bag_grid.gd`).
12. **[owner]** The same resource varies in colour in the bag (wood species → wood colours). Colour is
    natural appearance, never rarity — see spec 35
    ([`durango-prompts/35_natural_material_color.md`](durango-prompts/35_natural_material_color.md)).
13. **[owner]** Communication (factions, trust, missions) is its own screen, separate from Domain.
14. **[owner]** Domain screen rebuilt to the Durango layout (left icon tabs, declare panel).

## 2. Theme tokens — additions to `game/scripts/ui/ui_tokens.gd`

Keep every existing constant (other screens use them). Add the hex-HUD palette below. **Selection
moves from TEAL to GOLD** on restyled screens; TEAL stays for progress fills (XP, trust).

```gdscript
# Hex HUD palette (docs/design/ui-redesign-spec.md §2)
const HUD_FILL := Color(0.039, 0.047, 0.047, 0.92)    # hex interior, HUD panels
const HUD_RIM := Color(0.933, 0.945, 0.949, 0.85)     # light hex rim
const HEADER := Color(0.027, 0.031, 0.035, 1.0)       # full-screen header bar with torn bottom edge
const SCREEN_DIM := Color(0.063, 0.165, 0.243, 0.55)  # wash over the blurred world behind sheets
const PANEL := Color(0.055, 0.118, 0.173, 0.82)       # sheet panel
const GOLD := Color(0.957, 0.769, 0.188, 1.0)         # selection brackets, CTA, active state
const GOLD_DIM := Color(0.957, 0.769, 0.188, 0.12)    # selected row wash
const CTA_INK := Color(0.078, 0.071, 0.047, 1.0)      # text on GOLD buttons
const PARCHMENT_TOP := Color(0.804, 0.722, 0.541, 1.0)
const PARCHMENT_BOTTOM := Color(0.706, 0.620, 0.424, 1.0)
const PARCHMENT_INK := Color(0.102, 0.090, 0.063, 1.0)
const OK_GREEN := Color(0.373, 0.827, 0.416, 1.0)     # build SAVE check, filled material chevrons
const LIFE := Color(0.847, 0.314, 0.227, 1.0)
const ENERGY := Color(0.373, 0.659, 0.816, 1.0)
const XP := Color(0.561, 0.816, 0.910, 1.0)
const MUTED := Color(0.604, 0.651, 0.678, 1.0)        # secondary labels

# Trait chips (owner rule §1.4). bg / fg pairs; never reuse for item colour (spec 35).
const TRAIT_NEG_BG := Color(0.243, 0.263, 0.275, 1.0)
const TRAIT_NEG_FG := Color(0.765, 0.796, 0.816, 1.0)
const TRAIT_POS_BG := Color(0.957, 0.769, 0.188, 0.18)
const TRAIT_POS_FG := GOLD
const TRAIT_RARE_BG := Color(0.471, 0.824, 0.431, 0.20)
const TRAIT_RARE_FG := Color(0.561, 0.863, 0.518, 1.0)

# Exhaustion tiers (face + belt tint), indexed by the existing four tiers in Vitals.
const MOOD := [Color(0.561, 0.863, 0.518), Color(0.957, 0.769, 0.188),
		Color(0.910, 0.588, 0.165), Color(0.878, 0.412, 0.310)]
```

New helpers in the same file:

- `static func hex_points(center: Vector2, r: float, flat_top: bool) -> PackedVector2Array` — one
  geometry source for HexButton, chevrons and pie fills.
- `static func trait_chip_style(polarity: StringName) -> StyleBoxFlat` — `&"negative" | &"positive" |
  &"rare"`, 0 radius, 3×8 px padding.
- `static func draw_brackets(ci: CanvasItem, rect: Rect2, color := GOLD, arm := 18.0, w := 3.0)` — the
  four gold corner brackets used for every selection (grid cells, tabs, skill cells, slots).
- `static func header_style() -> StyleBoxFlat` and a `TornEdge` draw (zig-zag 0–12 px under the header).

Type: the canvas uses **Roboto Condensed** (Apache-2.0). It is not in `game/assets/fonts` today
(only Noto emoji/symbol fallbacks). Adding it is a separate, licence-noted asset change; until then
keep the current font and apply sizes only.

Sizes at 1600×900 (scale with `is_phone`): MENU hex 100×87, combat hex 150×130, sprint 100×86,
HANDS/bag 100×88, quick slot 80×70, pet whistle 66×58, CLAIM 52×46, gather hex 124×108. All meet
`TARGET_MIN` (44) on phone after scaling.

## 3. Hex button — `game/scripts/ui/hex_button.gd`

Today: pointy-top hex, light rim, icon/glyph, top/bottom text, caption, badge, cooldown sweep,
selected state. Changes:

| Field | Change |
|---|---|
| `flat_top: bool` | **New.** The canvas draws flat-top hexes (Durango reference shots); the current build is pointy-top. **OPEN for owner:** pick one orientation globally. Default stays pointy-top until decided. `_hex()` calls `UiTokens.hex_points`. |
| `rim_color`, `rim_width` | **New.** Default `HUD_RIM`, 4 px (3 px under 70 px). Selected → `GOLD`. CLAIM uses a GOLD rim at 80% alpha. |
| `fill_ratio: float` | **New, 0..1.** Pie fill (§4). Separate from `cooldown` (cooldown keeps its sweep). |
| `icon_grey: bool` | **New.** Draw the icon desaturated (modulate luminance) — gather hexes. |
| `key_hint: String` | **New.** Small boxed key label at the hex's top-right on desktop (`Esc`, `F`, `⇧`); hidden when `is_phone`. |
| `caption` | Unchanged (MENU, SPRINT, COMBAT). |
| `bottom_text` | Unchanged; shows the node's **remaining count** on gather hexes only, never an item stack count. |

Draw order: rim hex → fill hex (inset `rim_width`) → pie sector → icon → texts → brackets/badge.

## 4. Gather radial with pie fill — `gather_radial.gd`, `radial_hold.gd`, `hud_pills.gd`, `gather_ring.gd`

Flow (owner §1.1–1.6):

1. **Idle:** `hud_pills.gd` already labels nodes within 8 m. Restyle the pill as a small dark box with a
   grey resource glyph + name. A pill is clickable (and the node itself stays clickable).
2. **Select:** open the radial and pan the camera toward the node. Canvas value: move 45% of the
   screen-space offset from centre, 0.6 s ease. `radial_hold.gd` keeps the fan glued to the node while
   the camera moves. Clicking empty ground (or Esc) closes it unless a gather is running. Node title +
   level sit under the node.
3. **Fan:** one `HexButton` per option (existing option list): `top_text` = seconds ("2.8s"),
   `icon_grey = true`, `bottom_text` = remaining node count, `label_text` = resource name to the right.
   Locked options keep the existing blocked path, with the reason in the label in `DANGER`
   ("Log · Needs an axe").
4. **Gathering:** the pressed hex's `fill_ratio` rises 0→1 over the gather time. One harvest = one item.
   Other hexes stay disabled while one runs.

Pie sector inside a hex (no clipping shader needed). Polygon = centre + boundary points from −90°
clockwise to −90° + 360°·f, sampled every ≤6° and at every hex vertex the sweep passes:

```gdscript
# Distance from centre to the hex edge along angle a (radians), circumradius r.
static func hex_radius_at(a: float, r: float, flat_top: bool) -> float:
	var apothem := r * cos(PI / 6.0)
	var off := 0.0 if flat_top else PI / 6.0
	var local := fposmod(a - off, PI / 3.0) - PI / 6.0
	return apothem / cos(local)
```

Fill colour `HUD_RIM` at ~45% alpha over the dark interior; the icon brightens slightly with
progress (canvas: luminance 0.9 → 1.4).

5. **Yield card (replaces the item toast):** on completion, a 300 px card anchored above the node
   (place it with `UiTokens.free_spot` against `taken_rects`), visible ~3 s or until the next yield:
   - thumbnail tinted with the lot's **natural colour** (spec 35), 52 px;
   - name ("Red Clay Stone"), line "Stone · Lv. 1 · +1";
   - trait chips (§5), wrapped;
   - a 3 px top edge in the best chip's colour (rare > positive > negative).
6. **XP line:** the same completion adds a skill-XP line to the left feed (§6).

`gather_ring.gd` (pool ring + unit progress over the node) is **retired** once the pie fill ships —
the hex carries progress and the yield card carries the result. Keep its pool-fill idea only if the
owner wants node depletion shown; the hex's remaining count already shows it.

## 5. Trait chips

Owner rule (§1.4): **grey negative, yellow positive, green rare special.** This matches the existing
vocabulary (`docs/current/items-traits.md`: yellow pip = latent attribute) and the traits proposal
(`../vision/WildLandsMMO_Traits_Gathering_Processing_Math.md` — most lots flawed, positives rare).

- Text: `"<Trait> Lv. n"` (or bare name for flags such as "Flammable").
- Non-colour cue for colour-blind players: prefix `−` (negative), `+` (positive), `✦` (rare).
- Used in: yield card, bag inspector, food inspector, material crafting (focus card + expected result),
  creature loot plates.
- **Data gap:** chips need a polarity per attribute key. Item instances carry attribute keys today, but
  no `negative/positive/rare` field was found. Add it where trait definitions live (proposal:
  alongside `default_attributes` in the item data) — **OPEN** for whoever owns item data.

## 6. Field HUD layout — `hunt_hud.gd`, `hud_layout.gd`

| Element | Target | Current (hud.md) |
|---|---|---|
| Rail | **MENU only** + pet whistle row (SIC/HEEL/GUARD) beside it **[owner]** | MENU, ANIMALS, BUILD, SKILLS |
| Animals / Build / Skills | Entries in the MENU sheet **[owner]**; keep their hotkeys | rail hexes |
| CLAIM | 52 px gold-rim hex at the minimap's lower-left edge **[owner]** | context hex "by the minimap" — restyle/resize only |
| Left feed | Skill XP lines (hex skill glyph, "Gathering +8 XP", level, thin bar) **[owner]** | pickup toasts + XP lines top-centre |
| Party frames | Under vitals: portrait, crown on the leader, HP + energy bars **[owner]** | none — **no party system found in `game/scripts`**; frames wait on it |
| Quest card | Under the minimap: title, checklist with strike-through for done steps | left of the minimap |
| Quick slots | HANDS + 3 food/tool hexes + BAG (shows weight "84/100"), **no counts** **[owner]** | food hexes show ×count |
| Right thumb | COMBAT (large), SPRINT | same |
| XP bar | 22 px bottom strip: clock, "Lv. n", %, bar | 4 px bar + text |

Exhaustion treadmill — keep `exhaust_treadmill.gd` math unchanged (EMA drift, belt speed, step
handling). Visual changes only in `hunt_hud.gd`:

- belt 16 px under the energy bar, chevrons as now;
- a fill from the left to the current exhaustion % tinted `MOOD[tier]` at ~20% alpha;
- the face **rides on the belt** at the current % (26 px disc, `MOOD[tier]`, drawn mouth by tier);
- a white tick at the "exhausted" tier boundary (use the Vitals tier threshold, not the canvas's 80);
- tap face or belt → `fatigue_panel.gd` (unchanged).

## 7. Screens → scripts

Artboard IDs match the screenshots in §0.

| Canvas artboard | Owning script(s) | Kind of change |
|---|---|---|
| A1 Create your survivor | `character_creation.gd` | Restyle: profession list left with gold brackets, preview centre, "Starts: <skill> Lv. 20", body toggle, name field, GOLD **Next**. |
| A2 Pick your tamed island | `island_pick.gd` | Restyle cards, gold brackets, "Terrain choice is final" warning. |
| B1 Field HUD | `hunt_hud.gd`, `hud_layout.gd`, `hud_pills.gd`, `gather_radial.gd`, `radial_hold.gd`, `hud_event_state.gd`, `exhaust_treadmill.gd`, `day_night_dial.gd`, `held_item_slot.gd`; retire `gather_ring.gd`; replace `pickup_toast.gd` with the yield card | §4, §6 |
| B2 Combat HUD | `hunt_hud.gd` combat layer, `creature_plates.gd`, `target_swords_hex.gd`, `hud_status_chip.gd` | Hex restyle; NET hex turns GOLD-filled when capture is allowed (stunned or ≤30% — [spec 09](durango-prompts/09_capture_threshold_and_bonded_pet_limits.md)); treadmill shown in combat. |
| B3 Nav menu | `hunt_hud.gd` MENU sheet | Two side columns over the world per spec 33 (`durango-prompts/33_ingame_hamburger_menu.md`): Character, Skills, Craft, Build, Bag, Animals / World Atlas, Domain, Orders, Communication, Friends, Save. |
| B4 Toasts, radials, dialogs | `hud_event_state.gd`, `station_menu.gd`, `station_radial.gd`, `context_radial.gd`, `eat_progress.gd`, `claim_panel.gd`, `fatigue_panel.gd`, `respawn_ring.gd`; death card in `hunt_hud.gd` | Hex station radial (COOK GOLD-rimmed); eating progress becomes a hex pie (§4); claim confirm with parchment header; warnings on dark red with a warning glyph. |
| C1 Character | `inventory_ui.gd` profile/armour column (split into a Character tab) | Equipment slots around the figure (Head, Body, Arms, Legs, Weapon, Tool, Ring, Bag, Food 1, Food 2), stats list, survival needs panel. |
| C2 Bag | `inventory_ui.gd`, `bag_grid.gd`, `bag_inspect.gd`, `food_inspector.gd`, `art_slot.gd` | 8-column grid, one item per cell (already), **drop the count label in `art_slot.gd` for non-stacking items**, tint by natural colour, NEW badge, gold brackets; inspector with trait chips and Eat / Feed pet / Drop / Destroy. |
| C3 Skills | `skills_sheet.gd` | 4-column skill grid (icon, Lv, thin XP bar, unread dot) + right detail (parchment header, XP, SP spent, description, unlocks, GOLD button). F7 `skill_debug.gd` unchanged. |
| C4 Orders | quest card in `hunt_hud.gd`; full list: **new `orders_sheet.gd`** | List of orders with steps and rewards, "Track on HUD". |
| D1 Craft (stations) | `craft_ui.gd`, `craft_card.gd` | Station chooser (By hand / Workbench n m / Bonfire n m), category grid, grouped recipe list, detail with time · success · flawless, Craft and Craft ×5. |
| D2 Build mode | `build_ui.gd`, placer hexes in `hunt_hud.gd` / `hud_layout.gd` (`placer_anchor`) | Blueprint drawer as hex tiles by tier; placement row: ROTATE (icon only), **SAVE (OK_GREEN check)**, **CANCEL** **[owner]**; red ghost when partly outside the Domain. |
| D3 Craft — place materials | `craft_ui.gd` slot assignment (has per-slot have/need today) | New sub-view: completion %, chevron per slot (OK_GREEN when filled), candidate grid with order badges and quality pips, focus card with trait chips, expected result inheriting **slot-1 traits only** (archive systems PRD §8.3 on `main`: `docs/prd/durango-wild-lands-systems-prd.md`), quantity stepper, success rate, "Place material" → "Craft". |
| E1 Animals | `animal_screen.gd` | Pack slots 3 of 7 with locked slots shown (owner 3→7 bonded rule, [spec 09](durango-prompts/09_capture_threshold_and_bonded_pet_limits.md)), portrait, growth XP, grade, stats, needs, Feed / Ride / Release. **Conflict:** the script header says "unlimited roster, three active companions" — reconcile with the 3→7 bonded rule before restyling. |
| E2 Taming pen | **no dedicated script found** | Tame-or-store dialog with mood slider and pen grid; likely a new screen. |
| F1 Domain | `domain_screen.gd`, `claim_panel.gd`, `domain_banner.gd` | Left icon tabs (Tamed / Civilized / Clan / Outpost-locked), declare panel with headline, body, quote, GOLD action and footer warning; plot grid after declaring **[owner]**. |
| F2 World Atlas | `map_screen.gd`, `map_fog.gd`, `map_icons.gd`, `world_ui.gd` (harbour routes) | Island list left, map centre, legend right, zoom ±, Harbour routes. |
| F3 Communication | `comm_center_ui.gd` (today: spec 29 contribution screen) + **new `comms_ui.gd`** for factions | Factions from `game/data/world/factions.json` (Company, Chlorophyll Forum, Pioneer Council, Committee, Radio University), trust bar per rank, 3 offers, accept/abandon, ≤4 active, rerolls, support-crate band; Radio University shows career guides, no crates (PRD §15.1) **[owner: separate screen]**. Domain rank-up links here. |

Unchanged: `touch_controls.gd`, `touch_gestures.gd`, `virtual_joystick.gd`, `item_icons.gd`,
`item_art.gd`, `ui_icons.gd`, `level_display.gd`, `pet_radial.gd` (hex restyle via HexButton only),
`pet_rename_dialog.gd`, `status_glyph.gd`, `player_portrait.gd`.

## 8. Shared screen chrome

Every full-screen sheet: blurred world + `SCREEN_DIM`, `HEADER` bar (88 px desktop) with "‹ Title",
currency pills right, ✕ close, torn bottom edge; panels in `PANEL` with 1 px light divider; detail
panels open with a parchment header; primary action is a full-width GOLD button with `CTA_INK` text;
selection is always GOLD corner brackets. Back (‹) returns to the MENU; ✕ returns to the HUD.

## 9. Open questions

1. ~~Hex orientation: flat-top or pointy-top?~~ **Decided 2026-10-28 [owner]: flat-top, globally.** (§3)
2. Where trait polarity lives in item data. (§5)
3. Party system: none in code; frames are layout-only until it exists. (§6)
4. Animals roster rule: "three active" (code) vs 3→7 bonded pack (owner pack rule). (§7 E1)
5. Taming pen screen owner script. (§7 E2)
6. Font: add Roboto Condensed (licence + size budget) or keep the current face. (§2)
7. Does the yield card replace node-depletion feedback entirely (retire `gather_ring.gd`)? (§4)

## 10. Acceptance per package

Desktop Chrome 1600×900 is the gate (`AGENTS.md`); phone landscape 844×390 stays supported. Each
package ships with: a screenshot of the restyled screen in the running build next to its §0
target image, `game/tests/t_ui.gd` still green, `tools/smoke.sh` → `SMOKE PASS`, and `../current/hud.md` /
`../current/ui-screens.md` updated for what actually shipped.

## 11. Owner rules added after the canvas review

- [owner 2026-10-28] Animal natures are shown as a **chip under the name**, never as a word in it:
  the plate, the Animals screen and the pet radial draw the name ("Alpha Velociraptor") with a small
  `NatureChip` directly below it ("Timid"). Gold/positive trait style (§5); natures carry no polarity,
  so no "−"/"+" prefix. See `../current/creatures-capture-taming.md` § Natures.
- [owner 2026-10-28] Hexes are **flat-top** everywhere (§3 open question closed).
- [owner 2026-10-28] Font: use Roboto Condensed (`game/assets/fonts/RobotoCondensed-Variable.ttf`, SIL OFL 1.1).
- [owner 2026-10-28] Any menu that renders as stretched full-width rows (e.g. the Harbour "Sail ..." list) is rebuilt to this spec, not patched. Known: Harbour / sail list (world_ui.gd), build list (build_ui.gd), skills_sheet.gd, animal_screen.gd.
- [owner 2026-10-28, supersedes the §6 rail and right-thumb rows] Field HUD controls:
  - Bottom-right: one large **INTERACT** hex, context-sensitive — gather the nearest resource by default; its icon and label change with what is nearby (open, talk, pick up, mount, ...).
  - Above it, smaller: **ATTACK NEAREST** (enters combat with the nearest hostile / selected target).
  - A **SPRINT toggle** (tap on/off, not hold).
  - Bottom-left rail: **MENU, BUILD, BAG**, in that order. Skills and Animals move into the nav menu (§7 B3).
  - The MENU hex carries a notification badge at its top-right for skills (unspent SP, level-ups), buy/sell (market events) and similar: a count in a small filled circle. ASSUMPTION (owner undecided on colour): GOLD for normal notices, LIFE red only for urgent ones.
  - The pet whistle row and quick slots stay as §6 says where they do not collide with the above.
- [owner 2026-10-28] In-combat tap retargets; swords only out of combat. Out of combat a tap on an enemy selects it and the red swords hex (or ATTACK NEAREST) starts combat; in combat a tap on another enemy switches the target to it immediately, no swords hex shows on enemies, and ATTACK NEAREST retargets to the nearest valid enemy.
- [owner 2026-10-28] **Click-to-move outranks combat.** A tap on the ground is a move order and is
  always honoured: while it is live the hunt neither auto-chases nor auto-swings, even with a target
  in reach. A tap on an enemy during the walk still selects (out of combat) or retargets (in combat)
  and does not cancel the move. **Real damage ends it**: a creature hit cancels the order after the
  hurt stun and she attacks the damage source if it is within `ATTACK_SEEK_RANGE` (28 m), else the
  nearest hostile. Bleed and other DoT ticks are not real damage and leave the walk alone. Keys and
  stick movement are direct input, not a move order, so ordinary auto-attack/auto-chase behaviour
  stays while steering that way. See `../current/controls.md` § Move orders and interacting.
- [owner 2026-10-28] A ground click **cancels any pending interact pathfind**: if she is walking to a
  tent to sleep and you click somewhere else, the sleep intent and its path both drop and she never
  sleeps; same for gather, loot, mount/tame and a queued station craft. A craft already started at
  the bench keeps running. Steering with the keys/stick cancels the same way. Owned by
  `PlayerSim.cancel_errand()`, `PlayerActions.cancel_work()` and `StationCraft.abandon_errand()`.
