# Claude M8d Part A — gathering radial (Durango reference)

Reference: `docs/reference/durango-gather-reference.webp`, `durango-tree-options-reference.webp`.

## What shipped
- `scripts/ui/hex_button.gd` (`HexButton`): Durango hex button — dark hex with light rim, icon or glyph, time on top, count below, red no-entry badge when blocked; touch and mouse; ≥ 64 px. Reused by the HUD skill cluster next.
- `scripts/ui/gather_radial.gd` (`GatherRadial`): tapping a node with several yields draws a hexagonal selection outline on its tile with the node name and `Lv. N` (green), and fans hex option buttons to the right (icon from `icons_manifest.json` with alias/category fallback, seconds, count range, `Item Lv. N` label; blocked options dimmed with the badge and `needs <tool>`). Tap a hex → gather with that option; tap anywhere else dismisses and the tap still acts.
- `HarvestNode.options()` / `select_option(i)`: one option per manifest `harvest` entry (trees: Branch 1.8 s bare-handed, Log 3.0 s axe, Bark Strip 3.0 s knife; rocks: Stone pick…). `# ASSUMPTION` tool map: wood_log→axe, stone/ore_chunk/clay→pick, bark_strip/hide→knife, others bare-handed. Single-yield nodes start at once (M8a flow unchanged).
- Player: radial layer (CanvasLayer 55), `_on_gather_option_picked` prints `[item] option <id> xA-B Ts` then begins the M8a auto-gather with that yield; `debug_open_radial` for labs.
- `island_lab`: headless probe picks option 1 on the nearest tree and gathers two units; `--shot=…radial…` captures the radial.

## Evidence
- `docs/orchestration/reports/m8d-gather-radial.png`
- Headless island_lab: `[item] option wood_log x1-2 3.0s (of 3 options)`, `[item] auto-equip work_axe axe`, two `[item] +N wood_log … (pool …)` lines, `[item] option gather done units=2`
- `tools/smoke.sh` → `SMOKE PASS`

## Still to do in M8d
- Context hexes (water: drink/wash/fill; bonfire: cauterise/cook; corpse: loot) and the corpse radial (Part C), pickup toasts, level-up overlay, land claim boundary, label pills, placement hexes (Part B).

## Batch 2 (Claude) — corpse radial, pickup toasts, context hexes, placement hexes
- **Corpse radial** (Part C task 17): tapping a body opens the same radial with one hex per loot stack (`Corpse.loot_options`, knife-gated), title `<Species> Corpse`, `Lv. N`; picking walks over, plays the gather clip for 1.6 s and takes that stack (`Corpse.take_slot`), `[item] +N id (loot species)`, +2 XP, toast. The M9a loot panel is no longer opened by a tap (still used by the old USE path).
- **Pickup toasts** (task 18): `HuntHud.toast(id, n)` prints `[ui] toast id +n` and floats `+N Name` near the top-centre, rising and fading, stacking repeats; fired by gathers and loot.
- **Context hexes** (Part A task 13): `Player.context_actions()` → bottom-right hexes: Drink / Wash by water (energy +5, fatigue −2 `# ASSUMPTION`), Cook / Cauterise at a bonfire, Loot at a body, Harbour, Cargo warp, Pen, Dismount. `TouchControls` buttons are fully hidden now.
- **Placement hexes** (Part B task 16 + reference): rotate / green confirm / red cancel hexes under the ghost; blocked tiles in the 9×9 span show as red diamonds.
- Evidence: `m8d-corpse-radial.png`, `m8d-context-hexes.png`, `m8d-placing.png`; headless hunt_lab: `[item] corpse options=3`, `[item] +2 raptor_meat (loot velociraptor)`, `[ui] toast raptor_meat +2`.

## Batch 3 (Claude) — land claim, label pills, level-up overlay
- **Land claim** (Part B task 14): `IslandRuntime.claims` (14×14 camp plot on every island at build; saved plots from `World.home_claims`, schema unchanged: `home.claims` + `pioneer_xp` added to the payload). `BuildGrid.can_place` returns `unclaimed` outside a claim (`[build] rejected unclaimed` in build_lab). Dotted light-blue boundary along the plot edges (`ClaimBoundary` ImmediateMesh). Context hex **Claim** appears when standing outside a claim: home free; unstable first plot free, later plots consume a `claim_stake` (new item) — `[world] claimed 14x14 at (x,z)`.
- **Label pills** (task 15): every building, station, pen and node within 30 m gets a dark pill with a glyph, a status dot (green usable / grey depleted / red needs tool) and its name; regrowing nodes show a `⏱ Nm Ss` pill; far pills show the distance; pills fade with distance and skip the node whose radial is open.
- **Level-up overlay** (Part C task 19): on `World.pioneer_changed` a gold stack at the top-left for 6 s: `Lv. N`, XP, T-stones, Available Skill Points, `Title … acquired.` from `data/skills/titles.json`, and the eight stat gains from `data/skills/pioneer_levels.json` (+5 max health, +3 max energy applied). `--shot=…levelup…` forces one; `[world] pioneer level N [title="…"]`.
- Evidence: `m8d-base.png` (pills, Claim hex), `m8d-levelup.png`; build_lab prints `[build] rejected unclaimed` and `[build] restored 6`.
