# UIANIMALS: E1 Animals, F2 World Atlas, Harbour

Branch `claude/mmo-uianimals`, cut from canon `claude/mmo-overhaul` at a8a41cbf.
Spec: `docs/design/ui-redesign-spec.md` §7 E1 / F2, §8 chrome, §11 owner rules. Targets:
`docs/design/ui-redesign/e1-animals.webp`, `f2-world-atlas.webp`.

## What shipped

- **Shared sheet chrome**, `game/scripts/ui/sheet_chrome.gd` (`SheetChrome`): blurred world under
  SCREEN_DIM (one canvas shader, mip LOD blur), HEADER bar with the torn edge, back icon (‹ to the MENU)
  and ✕ (to the HUD) as 64 px icon buttons (`ui_icons` back/close), header tabs with a GOLD underline,
  a right-hand counter; GOLD CTA / ghost / danger buttons, PANEL style, section bands, trait-chip
  labels, `SheetChrome.Card` (selectable card: GOLD_DIM wash + four GOLD brackets), Roboto Condensed
  as the sheet theme's default face.
- **E1 Animals**, `animal_screen.gd` rebuilt (owner's stretched-sheet list): see the doc entry in
  `docs/current/ui-screens.md`. Pack slots 3 of 7 with the locked range, cards with name + NatureChip
  directly under it (§11), live 3D portrait of the pet in its own colours (`animal_stage.gd`), growth
  XP, grade, stats with genetics tier, needs, Feed / Ride / Summon-Dismiss / Release. Values refresh
  every 0.5 s while open (hunger, health, down timer, button states).
- **F2 World Atlas**, `map_screen.gd` rebuilt to the canvas layout: island column left (every catalogue
  island, current first, GOLD brackets), map centre on its own sea colour, compass + ✕ and legend panel
  right, Harbour routes + zoom − / + bottom right, GOLD "Back to camp" on an unstable island. Drawing,
  fog, footsteps, symbols and tap-to-walk are unchanged.
- **Harbour**, `world_ui.gd show_harbour()` rebuilt (owner named it): sheet chrome + a grid of route
  cards (4 columns desktop, 3 phone), each with its own Sail button; the reason a route is shut is on
  the card. Esc closes it, back returns to the atlas.
- Tests: new `game/tests/t_uianimals.gd` (both sizes: opens, 64 px targets, on screen, no panel
  overlap, 3/7 slots + locked range, chip directly under the name, waiting-to-bond list, card tap
  selects, atlas zoom, legend/map/column clear of each other, harbour grid with locked Sail buttons,
  no full-width rows). Updated to the new structure: `t_natures.gd` (row chip via the pack card),
  `t_petradial.gd` (long name keeps the out status), `t_w2_skills.gd` (header counter `_bonded`).
- Shot lab: `game/scripts/dev/uianimals_lab.gd` (+ scene). Shots in
  `docs/orchestration/reports/uianimals/` (1600x900 and 844x390 drawn at 2x).

## Public open functions (for the B3 nav menu)

- Animals: `HuntHud.open_animals(rec: PetRecord = null)` (existing; calls `AnimalScreen.open(player, rec)`).
- World Atlas: `HuntHud.open_atlas()` (new, opens) — `HuntHud.open_map()` still toggles.
- Harbour: `(load("res://scripts/ui/world_ui.gd") as GDScript).ensure().show_harbour()` (existing).
- Sheet back (‹) calls `hud.open_menu()` if the HUD has it, else today's `_toggle_sheet(&"menu")`.
  **B3 owner: add `open_menu()` to HuntHud** and every sheet's back lands on the new menu.

## Gates

`t_uianimals` PASS, `t_ui` PASS, `t_uiicons` PASS, `t_fieldhud` PASS, `t_mapui` PASS, `t_natures` PASS,
`t_petradial` PASS, `t_w2_skills` PASS, `run_all` `[tests] PASS`, `tools/smoke.sh --no-import` SMOKE PASS.

## Assumptions (`# ASSUMPTION:` in code)

1. Roster rule (§9 Q4): the roster is `player.bonded` capped by `Data.bonded_cap()` (spec 09: 3 + Animal
   Handling I-IV = 7); `MAX_PETS_OUT` (3) is how many are summoned. "The rest of the roster" = spec 09
   §2 unbonded animals: captured / tamed animal items in the bag and occupied taming pens, listed
   read-only under "Waiting to bond". **No save format change.**
2. Release: no release / bond-breaking exists in code (spec 09 §4 mentions a special item). The button
   is shown, disabled, "Release · locked". No pet can be deleted from this screen.
3. Taming Pen tab is shown disabled: E2 has no screen yet.
4. Row portraits are a colour swatch (species tint shifted by the pet's coloration) with the white
   animals glyph; the centre portrait is the live model. No painted creature portraits exist.
5. Atlas foot rows: no landmark counter exists, so the rows are "Island time" and "Islands visited"
   instead of the canvas's fatigue / landmarks.
6. Stats panel shows Life / Attack / Defense / Speed / Carry (bag slots); the canvas's "Bond Lv." and
   "Mood" have no data, so needs are Fullness and Health.
7. Summon / Dismiss is kept as a fourth button (the canvas has none, but it is the only way to call a
   pet out from this screen).

## Risks / for the next agent

- `sheet_chrome.gd` (`class_name SheetChrome`) is new and generic. If another UI package adds its own
  sheet chrome class, merge them into one at integration (name clash only if they pick the same name).
- `hunt_hud.gd`: one 4-line entry point added (`open_atlas`), nothing else.
- `bot_survivor.gd` now finds harbour buttons by their `route_id` meta instead of the old upper-case
  "SAIL ..." text. `progression_probe.gd` already used the meta and needs no change.
- The wiki screenshot set (`docs/current/screens/*.webp`, from `tools/ui_screens.sh`) was not
  regenerated; the old `animals` / `atlas` WebPs there predate this rebuild.
- `ui_real_capture_lab.gd` (windowed UI gate lab, not part of run_all) reads atlas internals; the names
  it reads (`_close`, `_btn_row`, `ZoomRow`, `_cards`, `_card_scroll`, `_map_rect`, `_layout`,
  `legend_slot`, `legend_col_w`, `_legend_kinds`) all still exist. It was not run.
- Paid generation: none. Credits: 0.
