# UINAV: B3 nav menu and B4 toasts, radials, dialogs

Branch `claude/mmo-uinav` (cut from canon `claude/mmo-overhaul` at a8a41cbf). Spec:
`docs/design/ui-redesign-spec.md` §7 B3 and B4, §11; `docs/design/durango-prompts/33_ingame_hamburger_menu.md`.
Mockups: `docs/design/ui-redesign/b3-nav-menu.webp`, `b4-toasts-radials-dialogs.webp`.

## What shipped

### B3 nav menu: new `game/scripts/ui/nav_menu.gd` (`NavMenu`)
- MENU opens two columns over the live world. Left: Character, Skills, Craft, Build, Bag, Animals
  (icon, then label). Right: World Atlas, Domain, Orders, Communication, Friends, Save (label, then
  icon). Above them is a header band with a settings gear on the left and the T-stone balance pill
  on the right. A CLOSE hex sits exactly where MENU sits.
- The menu draws on its own canvas layer (90) and sets the HUD's modulate to 0 while it is open, so
  only the world and the menu are visible, as in the mockup. The simulation keeps running.
- Badges (§11): each entry draws the count of `HudField.notices` for its own kind in a filled
  circle. The circle is GOLD, or LIFE when the notice is urgent. Opening an entry clears its kind.
  The MENU hex badge is unchanged.
- The menu closes on CLOSE, on Esc (`ui_cancel`), or on a tap on the world.
- Layout: at 1600x900 each side is one column of six rows, 84 px apart (76 px tall, 330 px wide).
  On compact canvases (844x390) each side folds into two columns of three rows, 72 px apart
  (64 px tall).
- Hooked into `hunt_hud.gd` in `_toggle_sheet`: `&"menu"` builds a `NavMenu` and keeps it as
  `_sheet`, so `sheet_open()`, `_close_sheet()`, HANDS hiding and plate hiding all work unchanged.
  The old `&"menu"` row list is removed and `_sheet` is now typed `Control`.

### B4
- **Notices** (`hud_event_state.gd`): `add_notice(text, ok := false)` stores the look, and the new
  static `draw_notice` draws it.
  - Warning: dark red, a LIFE left edge and a drawn warning triangle.
  - Ok: HUD fill, an OK_GREEN edge and a check. The menu's Save uses it ("Game saved · HH:MM").
  - The glyph is drawn on desktop only. On 844x390 the 22 px it adds left no free spot for a second
    notice in the gate lab's "busy" scene, so compact canvases keep the red box and edge without it.
  - `hunt_hud._draw` now calls `draw_notice` (3 lines changed). Tinted rare notices (W2-GATHER)
    are untouched.
- **Station radial** (`station_menu.gd`): the first action of a station (COOK, CRAFT, SLEEP) gets a
  GOLD rim, 4 px; the other actions get a HUD_RIM rim. Hexes are 96 px on desktop and 64 px on
  compact canvases (`StationMenu.hex_px`). The station name comes from the existing HudPills world
  label: an extra pill of my own duplicated it on the phone, so I removed it.
- **Recipe radial** (`station_radial.gd`): the same hex sizes. Its title is now the shared
  "● Name" pill (`StationMenu.draw_pill`) in the ring's centre, and the ring keeps clear of it.
- **Eating** (`eat_progress.gd`): a flat-top hex that fills like a pie, with the food's icon and
  "1.2s left" (from `EatSession.eat_seconds`) inside it. Under it: "Grilled Meat · +N energy" (the
  bundle's `latent_energy`), then "moving cancels".
- **Claim confirm** (`claim_panel.gd`): a parchment header with "Claim this land?" in
  PARCHMENT_INK, the body on the HUD fill, an outlined 64 px Cancel and a GOLD 64 px Expand button.
  Expand is greyed when the plot would not expand. `describe()` text and node names are unchanged.
- **Fatigue panel** (`fatigue_panel.gd`): a "FATIGUE" kicker, the title "What's tiring you", GOLD
  share bars and percentages, and a 64 px ✕ in the header instead of the bottom Close button.
- **Respawn ring** (`respawn_ring.gd`): a dark red disc and a LIFE arc. On a big ring the whole
  seconds sit in the middle with "seconds" under them; a small ring shows "4s".
- **Death card** (`hunt_hud._build_death`, about 10 lines of style changes): HUD fill, a LIFE top
  edge, the title in LIFE bold, and a GOLD "Respawn at camp" button with CTA ink.
- `context_radial.gd` is layout only; nothing visual to change, so it is untouched.

### Tests and tools
- New `game/tests/t_uinav.gd` covers:
  - entry order and the disabled entries;
  - at 844x390 and 1600x900: every entry, CLOSE and the gear inside the view, at least 64 px, with
    no overlaps;
  - badges and clearing, Skills and World Atlas open, a disabled entry does nothing, Save gives the
    ok notice, and CLOSE, Esc and a world tap all close the menu;
  - B4: the notice glyph room, the ok flag, the COOK gold rim, the station hex sizes, eating
    seconds and name, the claim confirm inside the view at both sizes with a parchment header and
    GOLD 64 px buttons, the fatigue close at 64 px, and the GOLD death button.
- `t_fieldhud.gd`: one assertion changed. The old sheet read "Skills (2)"; the test now checks
  `NavMenu.badge_text(&"skills") == "2"`.
- `ui_real_capture_lab.gd`: the "menu" sheet check now runs `_check_nav` (in view, tap size, no
  overlap) instead of the row-sheet checks.
- New capture lab `game/scripts/dev/uinav_lab.gd` (+ `scenes/dev/uinav_lab.tscn`), run windowed:
  `--resolution WxH -- --lab=uinav_lab --shot-dir=DIR --canvas=WxH`.

## Captures (`docs/orchestration/reports/uinav/`)
| Screen | 1600x900 | 844x390 |
|---|---|---|
| B3 nav menu | b3_nav_menu_1600x900.png | b3_nav_menu_844x390.png |
| B4 notices, station radial, eating, respawn ring | b4_toasts_radials_1600x900.png | b4_toasts_radials_844x390.png |
| B4 claim confirm | b4_claim_1600x900.png | b4_claim_844x390.png |
| B4 fatigue panel | b4_fatigue_1600x900.png | b4_fatigue_844x390.png |
| B4 death card | b4_death_1600x900.png | b4_death_844x390.png |

All are at most 300 KB. They are palette-quantized PNGs. Most of the 1600x900 shots are downscaled
to 960x540, because the grass does not compress under 300 KB at full size; the death card is full
size.

## Assumptions (`# ASSUMPTION:` in code)
1. Orders (no `orders_sheet.gd`) and Friends (no party or friend system) show greyed and do nothing.
2. Character opens the bag's Character page (`inventory_ui._show_page("character")`) until C1 ships.
3. Communication opens today's Communications Center (spec 29), on top of the Domain screen, until
   `comms_ui.gd` exists.
4. The header's settings gear holds the debug-info toggle, which was the old menu's last row.
5. The header shows the one currency the game has (World.t_stones). From the Durango reference I
   left out the lock, mail, news and premium-currency utilities, the promo banners and the camera
   button: none of them has a system.
6. The notice kinds an entry badges are its own ids (`&"skills"`, `&"animals"`, ...). A
   `&"market"` notice still counts on the MENU hex, but no menu entry shows it (no Market entry in
   B3).
7. The player's death has no countdown in code, so the B4 "4 seconds" ring is the pet respawn ring
   (`RespawnRing`), restyled. The death card keeps its button.

## Not done / risks
- The level-up banner in the B4 mockup lives in `hud_layout.gd` / `hunt_hud` (B1 field HUD
  territory). I did not touch it. The world labels and the pickup row in the mockup are also B1.
- The eating hex is not in `taken_rects`, so a notice can land under it when both happen at once.
  This is visible in the desktop B4 shot. The old ring had the same issue.
- On 844x390 the claim confirm body wraps to five lines. The panel grows upward over the vitals and
  quest card, as it did before; `fit()` is unchanged.
- `hunt_hud.gd` edits are kept small: the `_sheet` type, the `&"menu"` branch (and the old menu rows
  removed), the notice draw call, and the death card styles. This may conflict with the field HUD
  package if it also edited those lines.
- `hud.modulate` is set to 0 while the nav menu is open and restored on close. If anything else
  drives `HuntHud.modulate`, the two would fight. Nothing does today.

## Gates
- PASS: t_ui, t_uiicons, t_fieldhud, t_uinav, t_targetui, t_claimfix, run_all (`[tests] PASS`),
  `tools/smoke.sh --no-import` (`SMOKE PASS`).
- `ui_real_capture_lab` (windowed): the nav-menu check and the "busy" notices pass at both sizes. It
  still FAILs on screens this package did not touch: phone plate / plate_front, the combat AUTO hex
  against the nameplate at 844x390, the gather radial hex0 against the nameplate at 1600x900, the
  BUILD sheet against the vitals at 1600x900, and five bag-profile checks. I did not run the lab on
  the base commit, so I have not confirmed these failures were already there.
