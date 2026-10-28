# HUD & vitals UI — the Durango hunt HUD

Owner: `game/scripts/ui/hunt_hud.gd` (drawing, input, state). Split out of it: per-canvas geometry in
`game/scripts/ui/hud_layout.gd`, exhaustion-belt math in `game/scripts/ui/exhaust_treadmill.gd`, the
breakdown panel in `game/scripts/ui/fatigue_panel.gd`, the 24 h dial in
`game/scripts/ui/day_night_dial.gd`, toast/notice state in `game/scripts/ui/hud_event_state.gd`, the
hex control in `game/scripts/ui/hex_button.gd`, the death card in `hunt_hud.gd` itself.
Screens (Map, Animals, Domain, Skills sheet, claim confirm) live on canvas layer 96, the death
screen on 100. Everything is a tap: `_ready` sets `TouchControls.hud_mode = true`.

## Fixed layout (per canvas, `HudLayout`)
- Vitals panel top-left: desktop 300 px wide with 16 px bars and body-size numerals; phone compact
  (min 148 px, the room left of the minimap). An 18 px level disc sits left of the two bars (health
  red, stamina blue). Below: the exhaustion face + tier word, then the treadmill belt. While Well
  Rested the belt pauses (`ExhaustTreadmill.paused_rate`: the drift eases to 0 in ~0.2 s and holds)
  unless exhaustion is falling right then (a rest or a meal still runs it left); the status row shows
  the Well Rested chip (sun over a pillow, `well_rested.svg`) with its countdown.
- Status chips row under the vitals (30 px pitch, a countdown under 3600 s; longer = "until treated").
  A status that lowers max HP adds its own note line ("Infected Wound: max HP −20%").
  While she rests or sleeps a Resting chip (rest icon) comes first, and a rounded ink pill right under
  the row (under the max-HP note when it shows) reads what she nets at body size: "Resting by the fire
  / +2.8 HP/s / -15 fatigue/min" (`HudRestBox.draw`, lines from `RestState.hud_lines`; Health red when
  a status takes more than the rest gives). Each second that gives a whole point, "+N HP" (green) and
  "-N fatigue" (teal) floats rise over her (`HudRestBox.tick` → `HudEventState.add_float`).
- The name under the survivor hangs from `HudLayout.nameplate_anchor`: the capsule centre, lowered with
  the visual while she sits or lies, so it stays under her instead of across the torso.
- Minimap top-right: a round 154 px window (`MAP_PX`), drawn camera-up (rotated by camera yaw),
  0.95 m per pixel (`MAP_SCALE`), with fog-of-war, the foot trail, camp flame, harbour anchor,
  crater, creature dots (pets green, wild red, only inside revealed fog) and the player arrow.
  Above it "Home" / "Survivable N min" / "Lab"; below it the X/Y tile readout. A tap opens MapScreen.
- DayNightDial docked at the minimap's bottom-left edge: a 24 h face, noon at the top, the sun riding
  a white arc by day; a crescent moon opposite it at night; the face tinted by phase. A 60 px disc;
  tap opens a label to the left — phase, clock, time to the next phase — closing after 4 s. It reads
  `Game.time_of_day` / `day_length_seconds` and never writes them.
- Menu rail bottom-left: MENU ≡, ANIMALS, BUILD, SKILLS hexes (64 px, captions under). Two
  quick-food hexes above the rail (the bag's quick slots, ×count); CHASE takes that row's third
  slot. The SKILLS hex breathes a gold halo (1.6 s cycle, recomputed every 0.25 s) while SP affords
  a node.
- Sprint + Combat toggles hold the bottom-right above the rail (portrait lifts them one row). The
  DEBUG hex shows only while `Game.debug_overlay` (phone: lower-right; desktop: under the dial).
- XP bar 4 px along the bottom edge with the "Lv x, y%" text beside it; the survivor's name draws
  under her feet (15 px, projected from the camera).
- Quest card: desktop a 240 px card left of the minimap; phones across the centre band — "ORDERS
  i/n", the step title, hint, progress and a teal fill; when no objectives run: "NOW / island /
  Survive, then return".

## The centre band (`HudLayout.centre_band`)
- Landscape phones: the strip between the vitals and the minimap carries the quest card; the target
  plate and the level-up banner take it over while they show. Portrait: a strip under the map text.
- HUD-owned rects (`drawn_blocks`: vitals, map text, status row, plate, name, toasts…) plus every
  visible hex (with captions), other HUD controls, HANDS and the survivor figure form
  `taken_rects`; moving text picks a free spot via `UiTokens.free_spot` and is skipped when none.

## Combat layer (active while `player.hunt.target` lives)
- 6 px red bands across top and bottom; End Combat button (desktop right at ~42% height; phones
  under the map text / at the whistle row's right).
- Four 72 px skill hexes in a row, ROLL rightmost: NET / TACKLE / KICK / ROLL. With a ranged weapon
  equipped NET becomes FIRE n (ammo count, disabled when out); near a catapult both swap to the
  siege hexes (SIEGE n stone_shot / TOXIN n). Cooldowns and reloads disable their hex.
- AUTO toggles the hunt's auto-attacks; an "Attack Stance ◎" label sits beside the row; CHASE⇄HOLD
  joins the quick-food row; FEED appears on tameable targets (`FieldTame.can_attempt`).
- Whistle row SIC / HEEL / GUARD while a pet is out, selected state mirroring the pet's brain mode:
  desktop a column above the right thumb; landscape phone a row under the vitals; portrait a
  mid-screen row with End Combat at its right.
- Target plate top-centre (≤520 px): creature name + "Lv. n" (pets show their tier), an HP bar, a
  species-letter tile, the target's status chips and a Tyrant's opening label. It lingers on the
  last creature attacked (within 40 m) until it dies or a new one is hit.
- Context hexes (70 px, rescanned every 0.3 s from `player.context_actions()`) offer Sleep, Haul,
  claim, etc. and hide in combat; the CLAIM hex lives by the minimap. Claiming while already
  holding land here opens the ClaimPanel confirm; it cancels on walking away, moving placement, or
  a second tap. Ground-placing anchors a ROTATE / PLACE / CANCEL hex row near the ghost via a
  scored clear-spot sweep (`HudLayout.placer_anchor`); layout mode shows DONE + a hint bar.

## Exhaustion gauge & breakdown
- The face is drawn (smile → deep frown across four tiers, green → red by strain). Under it, a
  16 px treadmill belt (`BELT_H`): chevrons scroll right while exhaustion rises, left while it
  eases; belt speed = 350 px per pt/s of drift, clamped 3–150 px/s, holding still under 0.004 pt/s
  (`RATE_DEAD`).
- Drift is an EMA over fatigue deltas (2.5 s window, `EMA_TAU`). A jump ≥ 8 pts (`STEP_AFTER`)
  counts as a one-off step (sleep, meal), applied instantly, with a faster forgetting window
  (0.8 s `FORGET_TAU` held 2 s) so the belt eases out of the sweep.
- Tapping the face or belt opens FatiguePanel (300 px, refreshing every 0.5 s): up to 4 causes at
  ≥3% share of recent fatigue (each row a name, % and a remedy line), plus a context line with the
  level-gap sentence, the climate shortfall and the live drift ("Exhaustion is falling slowly
  (+x/min)"). Vitals owns the rows; the decay window is `fatigue.breakdown_window_s` (180 s).

## Notices, toasts, hits, level-up
- Pickup toasts ("+n Item"), skill XP lines (16 px) and tree level-ups (22 px, gold, ▲) rise near
  the top-centre (phones: under the vitals), each taking a free spot off `taken_rects`; notices
  (refusals) render under them on dark red. Nothing covers the fixed blocks.
- A creature's hit on the survivor covers her chest with Pokémon-style jaws and red damage numbers;
  heavy hits flash the screen red.
- Level-up (`World.pioneer_changed`): a gold stack at the top-left for ~6 s — level, title line,
  XP, T-stones, SP, per-stat gains; landscape phones show a one-line banner in the centre band
  instead. Gains land via `Vitals.grant_level_bonus` (saved).
- HUD pills (`game/scripts/ui/hud_pills.gd`) label buildings and nodes within 8 m; the domain
  banner (`domain_banner.gd`) announces "<owner>'s Domain" entering claimed land. All of it yields
  to toasts, plates and the open sheets.
- Death: full-screen layer — "YOU DIED", the downer ("Downed by <who>."), the note "Engaged
  dinosaurs retreat past their aggro ring. Your bag comes with you." and "Respawn at camp".
- Sheets (MENU / ANIMALS / BUILD / structure cards) stand on the rail and grow upward, wading into
  scrolling when short; landscape phones lay them out as a two-column grid. HANDS and the creature
  plates hide while one is open.

## Screens (phone landscape, [all screens](ui-screens.md))

**Idle HUD**

![hud](screens/hud.webp)

**Pet out**

![pet_out](screens/pet_out.webp)

**Combat layer**

![combat](screens/combat.webp)

**Fatigue panel**

![fatigue](screens/fatigue.webp)

**MENU sheet**

![sheet_menu](screens/sheet_menu.webp)
