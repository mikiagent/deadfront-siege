# UICHROME: one shared sheet chrome (Claude, 2026-10-28)

Branch `claude/mmo-uichrome` (from `claude/mmo-overhaul` 5f9bb36c). Spec: `docs/design/ui-redesign-spec.md` §8.

## What shipped

Three packages had each built full-screen sheet chrome, and Craft and the Island Market each had a
fourth and fifth copy. There is now one helper, `game/scripts/ui/sheet_chrome.gd` (`SheetChrome`):

- **Header:** 88 px band on desktop and 64 px on a phone, plus the top safe inset. HEADER fill with the
  torn edge hanging below the rect. A thin stroke ‹ and ✕ (`SheetChrome.Glyph`, 64 px targets, GOLD
  on hover/focus; the Market's stroke look, closest to the canvas). Title in Roboto Condensed 500 at
  40 / 26 px. Tabs with a GOLD 3 px underline (`tab_style`, reapplied on layout). A counter Label and
  a `right` HBox (SP pill, gear presets, wallet pill, Build, rich counter); both grow leftwards. A
  hairline sits before ✕.
- **Parts:** `backdrop()` (blurred world + SCREEN_DIM), `panel_style(fill, pad)` / `panel()`,
  `parchment_style(pad_x, pad_y)`, `action_button(text, kind, trim)` / `gold_button` /
  `ghost_button` / `style_action(b, kind)`, `box()`, `Brackets`, `Dot`, `Card`, `label()` / `text()`,
  `chip()`, `thin_bar()`, `icon_rect()`, `flat_button()`.
- **Ways in:**
  - a `SheetChrome` instance: Animals, Harbour, Market, Craft;
  - `SheetChrome.build(host, title)` + `fit(parts, view, safe)` (the old `uichar_chrome.gd` dictionary
    API): Character, Skills, Orders;
  - `UiWorldSheet`, now a thin base class (lifecycle, signals, `body`, `_build`/`_layout_body`,
    `set_counter`, `min_target_px`) whose header is a `SheetChrome` named "Header": Domain,
    Communication, Radio University, Taming Pen.
- **Deleted:** `uichar_chrome.gd`, `market/market_glyph_button.gd`, the Craft `_Header` / `_Brackets`
  classes, `CraftUI._icon_btn`, and `UiWorldSheet`'s static helpers (callers now call `SheetChrome.*`).
- **Converged:** Craft's GOLD and ghost buttons and parchment, the Market's buttons, panels and
  parchment, and the World Atlas ✕ all now come from `SheetChrome`. Craft's ‹ now uses
  `SheetChrome.back_to_menu` (`open_menu`) like the other sheets.
- **New test:** `game/tests/t_uichrome.gd`. It checks that all three paths yield the same header at
  1600x900 and 844x390 (band height, glyph targets on screen, title, counter and right slot do not
  collide) and that no other `scripts/ui` file draws a torn header.
- **Lab:** `ui_screens_lab.gd` now also captures `market`.
- Public open functions and the node names tests use are unchanged: Header, Back, Close, Title,
  Counter, CraftHeader / CraftBack / CraftClose / CraftTitle / CraftHint / BuildRow, CharacterClose,
  Dim, Brackets. One test line changed: `t_uichar` now checks for `SheetChrome.Brackets`.

Pixel changes that follow from converging the screens:
- Every sheet now uses the same thin ‹ / ✕. Before, Skills used a text "‹" / "×", Animals and Domain
  used the arrow/X icons, and the Market used strokes.
- Every sheet's backdrop is the blurred world. Domain, Comms, Craft, Market and UICHAR had
  near-opaque washes before.
- Disabled GOLD buttons read grey everywhere, for example "Feed · no food it eats" on Animals.
- Ghost buttons have 12 px side margins, Craft "Craft ×5" is now a ghost, and Market titles are
  40 px.

## Gates

- UI tests, all `PASS`: t_ui, t_uiicons, t_uinav, t_uichar, t_uianimals, t_uicraft, t_uimarket,
  t_uiworld, t_invscreens, t_w2_skills, t_skillfeel, t_mapui, t_natures, t_petradial, t_domain,
  t_islandpick, t_econ, t_fieldhud, t_uitokens, and the new t_uichrome.
- `t_uinav` prints one SCRIPT ERROR (nav freed at t_uinav.gd:132). The base `claude/mmo-overhaul`
  prints the same error, so it was already there.
- run_all: `[tests] PASS`. smoke: `SMOKE PASS`.

## Shots

`docs/orchestration/reports/uichrome/{skills,animals,domain,market}_{1600x900,844x390}.png`, captured
from the running build with `--lab=ui_screens_lab`. The before shots are not committed because they
are over 300 KB. I compared them side by side: the header now matches across the four screens and
the C3/E1 mockups.

## Assumptions

- ASSUMPTION: the ‹ / ✕ are the thin strokes from the canvas mockups, not the ui_icons back arrow and
  bold X. The icon ids stay in the manifest.
- ASSUMPTION: a disabled primary button is grey (UICHAR's "No SP to spend" look) on every sheet.
- Body margins and panel layouts stay per screen. Only the chrome converged.

## Not done / risks

- The build drawer (`build_ui.gd`) is a drawer, not a full-screen sheet, so it keeps its own head row.
- Some custom-drawn controls (market rows and rail tabs, craft category cells, craft_place) still
  call `UiTokens.draw_brackets` directly with arms sized to the cell. The primitive is the same; only
  the arm length scales.
- Craft and Market used to be opaque. The HUD under them now shows blurred and dimmed, as it already
  did on Animals and Skills.
- `hunt_hud.gd` was not touched.
