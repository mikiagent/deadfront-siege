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

## Addendum 2 (owner) — gathering UI, from `docs/reference/durango-gather-reference.webp`

In words: the player taps a boulder by the river. The boulder gets a thin **hexagonal
selection outline** on the ground with its name and level under it (`Boulder`, `Lv. 1`
in green). Next to it a small **radial of hexagonal option buttons** fans out, one per
thing that node can yield: each hex shows the yield's icon, the gather time at the top
(`3.0s`), the count it gives at the bottom (`3`), and a label to the right
(`Boulder Lv. 1`, `Pebble Lv. 1`). An option you cannot take (wrong tool, skill too
low) shows a red no-entry badge and a hint. Tapping a hex walks there and gathers with
the M8a ring. Bottom-right, standing by water, three **context hexes** appear (drink,
wash hands, fill container). A quest-hint card top-right (`Axe Materials · Find new
pebbles to use as a blade`) is out of scope for now.

Tasks to add:
11. **Node yield options.** `nature_manifest.json` families may list several `yields`
    (`[{"item": "stone", "count": 3, "seconds": 3.0, "tool": "pick"}, {"item": "pebble",
    "count": 2, "seconds": 3.0, "tool": "none"}]`); migrate the current single yield into
    that list (`# ASSUMPTION` second options: rocks → pebble, trees → branch without an
    axe, bushes → fibre + berry, mud → mud + clay). `HarvestNode` exposes `options()`.
12. **Tap a node → selection hex + radial.** One node selected at a time: hex outline
    (flat 1.4 m hexagon mesh, unshaded, 60 % alpha) on its tile, name + `Lv. N` label
    under it, and a `GatherRadial` Control (`scripts/ui/gather_radial.gd`) placed by
    unprojecting the node, with one `HexButton` per option (icon, seconds, count, label;
    red badge + `needs pick` when blocked). Single-option nodes skip the radial and start
    at once (keeps M8a's flow). Tapping a hex starts the M8a auto-gather with that
    option; tap-outside dismisses. Radial hexes ≥ 64 px.
13. **Context hexes.** Standing within 2 m of water (river trigger / shallow water
    tiles): a bottom-right cluster of hexes `Drink` (energy +5, `# ASSUMPTION`), `Wash`
    (clears `dirty` if the status exists, else fatigue −2), `Fill` (fills a bucket/bottle
    item if in the bag). Near a bonfire: `Cauterise`, `Cook` (opens craft filtered to
    the bonfire). Near a corpse: `Loot`. These replace the old USE button.

Acceptance additions: `m8c-gather-radial.png` showing a selected rock with the hex
outline, its label and two option hexes (one blocked with the red badge), and the water
context hexes; `[item] option pebble x2 3.0s` printed when an option is chosen in the
island lab hook.

## Addendum 3 (owner) — base building, from `docs/reference/durango-base-reference.jpg`

In words: the player's camp is a **claimed plot** drawn as a glowing dotted light-blue
boundary along the tile edges (an isometric diamond of about 14×14 tiles). Inside it,
every building has a **floating label pill**: dark rounded pill with the building's icon,
a small green status dot, and its name (`Basket`, `Makeshift Tent`, `Bonfire`,
`Makeshift Workbench`); a `Small Field` shows a second pill with a clock and the time
left (`19m 54s`). Resource nodes outside the plot have the same pills (`Boulder`,
`Pebble`). Bottom-right two hexes: a fence glyph (claim / expand land) and an anchor
(harbour routes). The quest card on the right stays out of scope.

Tasks to add:
14. **Land claim.** `LandClaim` data on the island runtime: a set of claimed tiles with
    an owner. Home island: the camp plot (14×14 tiles around the camp) is claimed at
    creation and can be **expanded** by 4 tiles a side per Pioneer level 5/10/15
    (`# ASSUMPTION`). Unstable islands: the first plot is free (14×14 where the player
    stands, tap the fence hex → tap a tile), later ones cost `claim_stake` items
    (add to `items.json`, craftable from 4 branches). Buildings may only be placed on
    claimed tiles (`BuildGrid.can_place` returns `unclaimed`); the camp props count as
    claimed. Draw the boundary as a dotted emissive line (ImmediateMesh or a ribbon of
    small quads) on the plot's outer tile edges, 0.03 m above ground, animated dash
    offset; hide it beyond 40 m. Saved in schema 2 (`claims: [{x, z, w, d}]`).
15. **Label pills.** A `WorldLabels` CanvasLayer draws a pill for every building,
    crafting station, pen, field and harvest node within 30 m (icon from
    `icons_manifest.json` or the item glyph, green dot = usable / grey = depleted /
    red = needs tool, name from the manifest). Fields, drying racks, taming pens and
    regrowing nodes get a second pill with a clock and `Nm Ns` remaining. Pills fade
    with distance and never overlap the target plate or the radial (skip when a
    radial is open for that node). Tapping a pill = tapping the object.
16. **Plot hexes.** Bottom-right cluster gets `Claim/Expand` (fence glyph) and
    `Harbour` (anchor glyph, opens the existing harbour routes when within 12 m of the
    dock). Placement (M8b) shows the claimed area tinted while placing.

Acceptance additions: `m8c-base.png` (home camp with the dotted boundary, pills on
tent/basket/bonfire/workbench, a timer pill on a regrowing node, the two plot hexes);
headless `build_lab` prints `[build] rejected unclaimed` for a tile outside the plot and
`[world] claimed 14x14 at (x,z)` on the unstable island.
