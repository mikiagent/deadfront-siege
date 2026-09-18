# Cursor milestone M8c — the Durango HUD: everything is a tap

Reference: `docs/reference/durango-look-reference.webp`. In words: **top-left** two thin
bars with icons (red health 309/322, blue energy 92/108); **top-right** a square minimap
with the island outline, the player marker and a "Survivable for 33 min" line above it,
a small climate/temperature readout (`+2.8`) and X/Y coordinates under it, a day-clock
strip; **bottom-left** a row of round menu buttons (menu with a notification badge,
emote, chat, keyboard, mic) — ours: MENU (bag+craft+map inside, badge for new items),
PETS, BUILD, SKILLS; **bottom-right** a small search/inspect button; **bottom edge**
a thin level/XP bar (`Lv. 4 78.9%`); the character's name floats under the survivor.
No joystick, no action cluster: you tap the world to move, gather, fight, talk, build.

Do this after M5c. Keep everything in `scripts/ui/` + `scenes/ui/`; the existing
`TouchControls` contexts (M8a) stay as the input layer but its visible buttons become
the ones below. No autoloads, no `project.godot`, no `game/shell/`.

## Tasks

1. **Top-left vitals.** Replace the text HUD line with two 220×14 px bars: HP (red,
   heart glyph, `hp/max` text right-aligned inside) and Energy (blue, bolt glyph).
   A third thin fatigue strip (grey) below; status icons (bleed, wet, cold…) in a row
   under the bars with countdowns. Tapping a bar opens the FAT/inspector panel that
   exists today.

2. **Top-right minimap.** 180×180 px panel: island outline from `IslandRuntime`
   (`tile_types`/height → a `Image` rendered once per island into an `ImageTexture`,
   sand/grass/water colours), player arrow, camp, harbour, crater (once discovered) and
   pets as dots, north up, 1 px = 1.5 m, centred on the player. Above it: `Survivable
   for N min` on unstable islands (`World.remaining_lifetime`), `Home` at home. Below
   it: `X 451 Y 356` tile coords and the clock `08:29 day`. Tapping the minimap opens
   the full map (existing `WorldUI.show_map`).

3. **Bottom-left menu row.** Four 64 px round buttons: MENU (opens a sheet with Bag,
   Craft, Map, Save; badge with the count of new item kinds since last opened), PETS
   (bonded list, summon/dismiss), BUILD (list of placeable kits in the bag → placer),
   SKILLS (the skill debug panel becomes the skills sheet). Sheets slide up from the
   bottom, one at a time, tap-outside closes. Hunt tactics (tackle, kick, net, roll)
   move into a small contextual strip that appears above the menu row **only during a
   hunt**; AID appears there while bleeding; USE while mounted.

4. **Bottom-right inspect.** One 56 px button that toggles "inspect mode": the next tap
   on a node, creature, body or building shows its info card (level, yields, hp,
   footprint) instead of acting. Also where the debug overlay toggle lives (long-press).

5. **Bottom XP bar.** 100 % width, 6 px, `Lv. 4  78.9%` label from the Pioneer level
   and progress (`World.pioneer_level`; add a `pioneer_progress()` 0..1 if missing).

6. **Name under the survivor.** A `Label3D`-style screen label with the character name
   (`Uptodown` in the reference; ours from `survivor.json` `display_name`, default
   `Survivor`) 0.3 m under the feet, fading at distance.

7. **Everything by tap.** Audit `Player._tap_world` so every interactable reacts to a
   single tap (harvest, body/loot, creature hunt or pet menu, pen, bonfire, harbour,
   cargo warp, buildings) and shows a short floating hint (`Chop`, `Loot`, `Hunt`,
   `Feed`…) at the tap point for 0.6 s. Keyboard stays for desktop.

## Acceptance
- Screenshot `docs/orchestration/reports/m8c-hud.png` on `--touch` at 1600×900 matching
  the layout above; `m8c-hud-hunt.png` with the hunt strip visible; `m8c-menu.png` with
  the MENU sheet open.
- All targets ≥ 56 px, inside the safe area, no hover-only info.
- Headless `--lab=island_lab` still passes; `tools/smoke.sh` → `SMOKE PASS`.
- Report `docs/orchestration/reports/cursor-M8c-durango-hud.md`; commit as
  `M8c: Durango HUD`.

## Addendum (owner) — combat HUD, from `docs/reference/durango-combat-reference.jpg`

In words: during a hunt the screen gets a thin **red frame** (top and bottom edges,
6 px, 70 % alpha). **Top-centre target plate**: species portrait icon (right), the name
and level `Centrosaurus Lv. 38` (level in red), a wide red health bar with `2464 / 5439`
centred, and under it the target's status icons (bleed, venom…) as small rounded squares.
**Right-middle**: a red `End Combat` button with an ✕ (stops the hunt, clears the target).
**Bottom-right**: a cluster of **hexagonal** skill buttons (net, slash, kick, roll) in a
honeycomb, with a yellow `Auto` hexagon (auto-attack toggle, on by default) and an
`Attack Stance` reticle indicator under it (tap to cycle stance: attack / defend / evade
if the PRD has them, else attack / hold). **Bottom-left**: `Chase` toggle (hex with a
running figure; replaces the HOLD button: on = follow the target, off = stand). The
emote/chat/mic buttons of the reference are out of scope; keep MENU/PETS/BUILD/SKILLS.
**In world**: the current target gets a **red outline** (a back-face outline pass or a
`next_pass` fresnel material on its meshes) and a red ground ring on its tile; above it a
compact plate: eye icon, level in a dark circle, name in red, a small red health bar
(M9a's nameplate is the base; the target variant is this red style). Hits flash a bright
burst sprite at the impact point and pop a damage number.

Tasks to add to this milestone:
8. `HuntHUD` (rework `scripts/ui/hunt_hud.gd`): red frame, target plate, target status
   row, End Combat, hex skill cluster (`tactic_1..4`, roll), Auto toggle (drives the
   existing auto-attack), Attack Stance indicator, Chase toggle. Visible only while
   `Hunt.target` exists; slides in/out over 0.2 s.
9. Target outline + ground ring + red plate variant on the targeted creature; hit burst
   sprite (a 6-frame radial flash, procedural `Image` is fine) and floating damage
   numbers (white; red for bleed ticks; yellow for heavy hits).
10. Hex button drawing: one `HexButton` Control (`_draw()` hexagon, icon glyph from
    `icons_manifest.json` or a unicode fallback, pressed/disabled/cooldown sweep states),
    reused for the skill cluster and the Chase toggle. Targets ≥ 64 px across.

Acceptance additions: `m8c-hud-hunt.png` must show the red frame, the target plate with
level and health, the hex cluster with Auto on, Chase bottom-left, and the outlined
target with its red plate and ground ring; a `[hud] target centrosaurus lv=38 hp=2464/5439`
style print when a target is set (use whatever species is in the lab).

Gathering radial, context hexes, land claim and label pills are milestone M8d (`cursor-M8d-gather-and-base.md`), which runs after this one.
