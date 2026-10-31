# claude-uiworld: F1 Domain, F3 Communication + Radio University, E2 Taming Pen, A2 Island pick

Branch `claude/mmo-uiworld` (from `claude/mmo-overhaul`). No credits spent.

## What shipped

- **Shared chrome** `game/scripts/ui/uiworld_sheet.gd` (`UiWorldSheet`): full-screen sheet per spec §8
  (dark wash, HEADER with torn edge, back icon + title, GOLD-numbered counter, ✕), static helpers for
  the GOLD button, ghost button, panel, parchment header and GOLD corner `Brackets`. A one-frame
  re-layout (`_settle`) fixes autowrap labels inflating containers on first open.
- **F1 Domain** `domain_screen.gd` rebuilt on it: icon tab column, declare panel, plot grid view,
  Expand / Build here / Release, Communications Center link (still opens `CommCenterUI`, unchanged),
  ground preview as a narrow Confirm / Cancel card. Public API and field names the labs read
  (`open`, `close`, `is_open`, `select_tab`, `is_previewing`, `preview`, `center_ui`, `_note`,
  `_stats`, `_tab_buttons`, `min_target_px`) are kept.
- **F3** `comms_ui.gd` (`CommsUI`) and `radio_university_ui.gd` (`RadioUniversityUI`), data from
  `data/world/factions.json`.
- **E2** `taming_pen_ui.gd` (`TamingPenUI`), wired: `PlayerActions.pen_interact` opens it when a HUD
  (group `hud`) is up; HUD-less labs/tests keep the old direct insert/feed path.
  `TamingPen.try_insert(player, slot := -1)` takes the picked bag slot (default unchanged).
- **A2** `island_pick.gd` restyle (test contract kept: 5 cards + Select and move, warning contains "final").
- Lab `game/scripts/dev/uiworld_lab.gd` (+ `scenes/dev/uiworld_lab.tscn`), test `game/tests/t_uiworld.gd`.

## Open functions for the nav menu (B3)

On `HuntHud`: `open_domain() -> DomainScreen`, `open_comms() -> CommsUI`,
`open_radio_university() -> RadioUniversityUI`, `open_taming_pen(pen: TamingPen = null) -> TamingPenUI`.
Each screen also has `open(player[, pen])` / `close()` / `is_open()` and emits `back_pressed` /
`close_pressed` (Back currently closes; B3 can connect `back_pressed` to reopen its menu).
`nav_menu.gd` in the uinav worktree calls `h._open_domain()` (a toggle) and routes Communication to the
Domain screen: switch those to `open_domain()` and `open_comms()`.

## Gates

t_uiworld PASS, t_ui PASS, t_uiicons PASS, t_fieldhud PASS, t_islandpick PASS, t_domain PASS,
t_domaind PASS, t_claims2 PASS, t_build PASS, t_w2_skills PASS, t_natures PASS, t_uitokens PASS,
run_all `[tests] PASS`, smoke `SMOKE PASS`.

Shots (1600x900 and 844x390) in `docs/orchestration/reports/uiworld/`: domain_declare, domain_plots,
comms, radio, pen, pen_started, island_pick. Four were posterized to 5 bits a channel to stay under
300 KB.

## Assumptions (`# ASSUMPTION:` in code)

1. Domain: Civilized / Clan / Outpost tabs are later phases and say so; Outpost is drawn locked.
2. Domain footer states the real growth rule (edge-adjacent, no hop), not the canvas's "only buildings
   inside your Domain can be used" (no such rule in code). The quote line is the canvas's flavour text.
3. Domain plots view: "Center camera" is replaced by Expand (the real action); Build here opens the Build
   sheet; Release kept (it existed before).
4. Comms: no faction / trust / mission logic exists. Trust is rank 0 everywhere, offers are the first
   three `mission_pool` ids shown as a preview, Accept / Reroll / Track are disabled with the reason.
   4 active and 3 free rerolls come from PRD §15.1. Lock = `unlock_level` vs character level. Rank
   titles ("Field Contact") are not in data, so not shown.
5. Radio University guide progress is not tracked; every guide reads "Not started".
6. Taming pen: no mood system - the slider is read-only (nature pen-time knob before taming, elapsed
   share while running). The pen holds one animal, so Pen space is n / 1; Store = keep it caged in the
   bag (no store-in-pen). Spec 02's size-based pen area needs a size field in creature data.
7. A2: no Back button (character creation has no way back from the pick); third card line is the
   terrain's top three scatter kinds, not resources.

## Not done / risks

- `claim_panel.gd` and `domain_banner.gd` untouched: uinav is restyling the claim confirm (B4) right now,
  and the banner is an in-world HUD element with no mockup row.
- `comm_center_ui.gd` (spec-29 contribution panel) works as before but keeps its old card look.
- Three packages each made their own sheet chrome (`SheetChrome` in uianimals, `uichar_chrome.gd`,
  this `UiWorldSheet`): worth merging into one at integration.
- Edits outside my screens: `hunt_hud.gd` (one block of entry points after `domain_screen()`),
  `player_actions.gd` (pen_interact opens the screen when a HUD exists), `taming_pen.gd` (optional slot
  arg). No pets/*.gd edits. No save-format change.
- The quote's italic (FontVariation skew) does not show; cosmetic.
