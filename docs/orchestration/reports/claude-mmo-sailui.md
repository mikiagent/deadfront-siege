# SAILUI: the Durango Sail chart replaces the harbour's text list

Branch `claude/mmo-sailui`, cut from `claude/mmo-overhaul` at `de73f92f` and synced with it at `5b38e14e`
(merge of W2-SKILLS and the spec 19 docs; no conflicts, no hook file touched by the base). Owner (spec 15,
second section): "Menu scrolls rightward and has many islands". Comparison plan: `docs/orchestration/mmo/islandmap-check.md`,
package 1. No Meshy, Tripo or other art credits spent; everything is drawn in code.

Commits: `b3248bd4` chart, lab, test, hooks patch; `11b7866b` clouds on their own layer, far-right cards,
one-line card title; `b4ed68d9` open at the island you stand on, cloud sizes, ASSUMPTION marks; `5b38e14e` base sync;
`1042d899` report; fix round 1: `d9c8e0a6` base sync to `ddaab662` (WATER and docs; no hook file touched, merge clean),
`4b3387c0` the fixes in this package's files, then the report and hooks patch commit.

## Fix round 1 (review findings)

| Finding | Fix | Check (fails on the old code) |
|---|---|---|
| **Blocker**: in the real web build a 400 px touch drag scrolled about 800 px (Godot web sends each finger `pointermove` as a device-0 `InputEventMouseMotion` with the left mask, which the emulation guard let through) | `SailScreen._on_view_input` keeps the fingers that are down (`_touches`, by index, set on `ScreenTouch` press, erased on release, cleared on rebuild) and ignores every mouse event while one is down; `ScreenDrag` alone moves the sea | `t_sailui`: a web-style 400 px touch drag (each `ScreenDrag` sent with a device -1 copy **and** a device-0 mouse motion, button mask LEFT) must scroll 400 +/- 10 px, at both sizes. With the guard removed it printed `400 px web touch drag scrolls 800.0 px` at 1600x900 and 844x390. **In Chrome** (fresh WebSoak export of this tree, CDP touch events only: 1 start, 20 moves of 20 px, 1 end) the soak now prints `[soak] sail dragged 400.0 px` at 844x390 and at 1600x900; a Chrome mouse drag prints 400.0 too |
| **Major**: the hook deleted `MapScreen.island_name`, which W3-EXCHANGE's `market_screen.gd:125` (`MapScreen.island_name(str(World.island_id))`, checked on `claude/mmo-exchange`) still calls | `map_screen.gd` keeps a one-line delegate, `static func island_name(id: String) -> String: return World.island_name(StringName(id))`; the rule still lives only in `World.island_name`, and the atlas's own two call sites use it | `t_sailui` calls `MapScreen.island_name("temperate_25")` and compares it with `World.island_name`. The patch's `map_screen.gd` hunk also applies cleanly (`git apply --check`) to `claude/mmo-exchange`'s `map_screen.gd` |
| Minor: a second card was renamed `@PanelContainer@NNNN`, so `sail_lab.audit` lost it and reported false "covers node" problems | `close_card` calls `remove_child(_card)` before `queue_free()`, so the next card is named `Card` again | `t_sailui` opens two cards in a row at both sizes and asserts `find_child("Card")` is the open card and the audit is clean. With the old `close_card`: `the second card is the node named Card (<Object#null>)` and `button "Needs Survival 15" covers node tundra_30` (1600x900) / `tropical_25` (844x390) |
| Minor: a vertical two-finger trackpad swipe (`InputEventPanGesture.delta.y`) did nothing; one web wheel notch (factor about 3) jumped 456 px | The pan uses `delta.x + delta.y`; the wheel factor is capped at 1.5, so a notch moves at most 3/4 of a band (228 px at 1600x900, 120 px at 844x390) | `t_sailui`: a factor-3 wheel notch scrolls at most 3/4 band (old code: `456 px` and `240 px`), and a pan with delta (0, 2) scrolls (old code: no scroll) |
| Minor (cosmetic): the desktop card was full height with about 380 px of empty panel above Sail | The card starts at height 0 and grows to its content (no spacer); Sail sits right under the Fare line, at both sizes | `t_sailui`: card height equals its content's minimum height (old: 772 vs 420 at 1600x900, 302 vs 290 at 844x390) and the card stays inside the sea view (also a new `sail_lab.audit` rule). Shot `r1_card_1600x900_forward_plus.png`: the Lv. 35 Temperate island under the card is now in sight |
| Minor (cosmetic): at 844x390 the Lv. 25 heading touches the Unstable Temperate ripple and a cloud | Not changed | Two islands share that band and fill the phone's view height, so the top one cannot move down without crowding the lower one. Left for the art pass; the heading keeps its dark outline and is readable in `r1_left_844x390_gl_compatibility.png` |

The web soak hook now holds the open chart 3 s (was 1.5 s) and prints `[soak] sail dragged N px`, so a harness that drags at
the "harbour-open" checkpoint gets the in-game number instead of measuring screenshots; a harness that does not drag sees 0.

## What shipped

New files (this package owns them):

| File | What |
|---|---|
| `game/scripts/ui/sail_screen.gd` (`SailScreen`) | Full-screen Control: black header (back arrow, "Sail", Survival N, T-stones, close X; off the home island also "Return to camp" and the yellow "Free return home"), the clipped sea view and the island card. 1:1 scrolling by mouse drag, touch drag, wheel and trackpad pan; no vertical scroll, no inertia. Emits `chosen(id)` / `closed`; it never travels by itself. `route_button(id)` gives probes and the bot the control that departs for an island. |
| `game/scripts/ui/sail_chart.gd` (`SailChart`) | The sea: Home's band (Lv. 10) then one band per level 15..60, lightest left, darkest right, each headed "Lv. N"; dashed sea lanes between neighbouring levels, wave strokes, a compass rose, Home's ragged island shape, drifting clouds along the top and bottom edges and a still cloud bank past Lv. 60. Places the nodes: x strictly grows with the level; the two islands of one level share a band, one above the other. |
| `game/scripts/ui/sail_node.gd` (`SailNode`) | One island: round disc in the climate's colour with ripple rings and drawn climate art (umbrella tree, broadleaf tree, palm, snowy pine, cactus, reeds, volcano, house for Home), name, Lv., a badge (green check = sailed there, "?" = never), a lock badge plus "Survival N" while Survival is too low, a red pin on the island you stand on, a gold ring when selected or focused. |
| `game/scripts/dev/sail_lab.gd`, `game/scenes/dev/sail_lab.tscn` | Opens the chart the way the dock does. `--island --survival --stones --visited --scroll=right --card --view`. Prints the numbers and `[sail] lab PASS/FAIL` from `audit()`: every tap target at least 64x64 and inside the safe area, no two overlapping, sea at least 2x the view, no vertical scrolling, node x by level, nodes in view. |
| `game/tests/t_sailui.gd` | The acceptance test (below). Fails on the old code. |

Hooks (merged packages' files): `docs/orchestration/reports/claude-mmo-sailui-hooks.patch`, applied to the work tree
for every gate below and not committed. `git apply --3way` of it onto a fresh `claude/mmo-sailui` tree works
(`mkscratch.sh sailui-hooks claude/mmo-sailui <patch>`, then `t_sailui` PASS there).

| Hook | Change |
|---|---|
| `scripts/ui/world_ui.gd` | `show_harbour()` builds a `SailScreen` on its own CanvasLayer 96 (full screen, above the creature plates and the touch layer, like the map) instead of `_fill`'s vertical sheet. Its `chosen` goes through the exact old match: `&"home"` -> `World.travel(&"home_grassland", &"harbour_home")`, `&"camp"` -> `World.recall_camp()`, an island -> `World.travel(id, &"sail")`. world_ui.gd shrinks by 7 lines. |
| `scripts/core/world.gd` | `World.island_name(id)`, the one shared name rule (moved from the atlas unchanged): data `display_name`, else "<Climate> Island". |
| `scripts/ui/map_screen.gd` | `MapScreen.island_name` becomes a one-line delegate to `World.island_name` (kept for the Island Market, W3-EXCHANGE); the atlas's two call sites use `World.island_name`. |
| `scripts/world/harbour.gd` | Doc comment only ("Opens the Sail chart"). |
| `scripts/dev/progression_probe.gd` | `button(ui, id)` asks the chart for `route_button(id)` (the card's Sail, or the header's Free return home) instead of searching for a `route_id` row. |
| `scripts/dev/bot_survivor.gd` | `_travel` picks the first island (level order) whose card has an enabled Sail; `_return_home` uses `route_button(&"home")`. |
| `scripts/dev/web_soak.gd` | The Chrome soak holds the chart 3 s at "harbour-open" and prints `[soak] sail dragged N px` (what a harness drag moved it), scrolls it to the far right, checkpoint "sail-right", holds 1.5 s, then closes it as before. Fails the soak if the harbour opens no chart. |

## Against spec 15's Sail description

| Durango (spec 15) | Here |
|---|---|
| Horizontal sea chart scrolling right, compass rose, drifting clouds | Yes. Sea 2.18x the view at both sizes; compass bottom-left under Home; clouds drift along the edges, a bank sits past Lv. 60 |
| Vertical bands, darker and higher-level to the right | 11 bands, Lv. 10 (Home) to Lv. 60, `#6E9EA6` to `#0F1F2E`, each headed "Lv. N" |
| Home (Moon City Lv. 10) drawn with its island shape, red pin, house icon | Home at the far left on a ragged sand-and-grass island shape, house art, red pin when you are there |
| Sea zones: round icon, ripple rings, climate art, name and level | One round node per island (14 + Home), ripples, climate art, name, Lv. |
| "?" for undiscovered, green check for discovered | From `World.visited_islands`: check / "?"; plus lock + "Survival N" for the gate |
| Header: "Sail", back arrow, coin counter, close X | Same, coins are T-stones; Survival shown beside them |
| Not built (ruled out or no equivalent) | Ancora, the Safe House, Moon City, seas that roll islands (orchestrator ruling: keep our 14 fixed islands); the "0 +" chart-item counter and the ship/clock round button (we have no such item or timer); the gold swirl badge |

## Gates

Fix round 1, run on `4b3387c0` + hooks (base `ddaab662`, after one `--import`), each Godot run through gslot.sh; logs in
`scratchpad/sailui/gates_r1/`. Plan gates 1-5 are asserted by `t_sailui` (with `sail_lab.audit`) and by `sail_lab` at both sizes.

| Gate | Result |
|---|---|
| 1. Sea >= 2x view, no vertical scrollbar, node x strictly grows with level (1600x900, 844x390) | `t_sailui`: content 3488 px (2.18x) and 1837 px (2.18x); no VScrollBar, no ScrollContainer, chart height = view height; level order `home_grassland, savannah_15, temperate_20, temperate_25, tropical_25, tundra_30, desert_35, temperate_35, tropical_40, savannah_45, temperate_45, desert_50, swamp_55, tundra_55, volcanic_60` |
| 2. Every node and button >= 64x64, no overlaps, inside the safe area | `sail_lab` PASS at 1600x900 (home) and 844x390 (on savannah_15, header's two buttons and a card open); `t_sailui` audits both sizes plain and with a second card open; every windowed shot run prints `[sail] lab PASS`. Safe-area insets are 0 on desktop, so only the zero-inset case ran |
| 3. In view without scrolling: >= 6 at 1600x900, >= 4 at 844x390 | 6 and 6 (Home, Lv. 15, 20, both 25s, 30); after scrolling right the Lv. 60 island is in view |
| 4. 400 px touch drag moves 400 +/- 10 px | Headless (`t_sailui`), both sizes: touch drag with the emulated copy, web-style touch drag with the device-0 motion, and mouse drag all within 400 +/- 10; a drag from a node opens no card, a tap does. **Chrome, web build:** CDP touch drag 400.0 px at 844x390 and at 1600x900, mouse drag 400.0 px at 1600x900 (the soak's own number). A desktop Chrome window of 844x390 without touch keeps the 1600x900 design canvas scaled by 0.433, so its 400 px mouse drag is 922.7 canvas px = 400 screen px |
| 5. Survival 0: 14 locks; after visiting savannah_15 a check, others "?" | 14 locks with each route's real gate; the locked card says "Needs Survival 15"; after a real Sail to savannah_15 its node has the check and the pin, the 13 never-visited show "?" |
| Choosing a node uses the same travel path | Disabled Sail goes nowhere and charges nothing; Sail lands on savannah_15 and charges 5 (20 -> 15, only `World.travel(id, &"sail")` charges); Return to camp puts the survivor on the camp point; Free return home lands home, still 15 |
| 6. t_harbour, camp_travel_probe, smoke; island_lab 378/24 | `[t_harbour] PASS islands=15`; `SMOKE PASS`; camp_travel_probe **FAIL failures3, identical on the base `ddaab662`** (below); island_lab prints `[world] mm=2 nodes=397 creatures=24`, **identical on the base** (below) |
| Every `game/tests/t_*.gd` | 22 files PASS: t_ai, t_build, t_canim, t_combat, t_data, t_harbour, t_iconart, t_items, t_light, t_lighting, t_occlude, t_player, t_sailui, t_save (its 5 announced deliberate SCRIPT ERRORs), t_server_domain, t_srvdom, t_structart, t_tame, t_ui, t_uiicons, t_w2_skills, t_water, t_web |
| run_all, harbour_lab, progression_probe | `[tests] PASS`; harbour_lab prints its `[harbour] lab` line, exit 0; progression_probe (drives the chart's buttons for all 14 routes) `failures=0` |
| 0 SCRIPT ERROR | 0 in every log except t_save's 5 deliberate ones |
| 7. Desktop Chrome web build at 1600x900 and 844x390 | Shots below, from a WebSoak export of `4b3387c0` + hooks; all four Chrome runs reached "harbour-open" and "sail-right" with no soak failure, page error or SCRIPT ERROR |
| Old code | `t_sailui` FAIL count=6 and `sail_lab` FAIL on the branch without the hooks (round 0); the round-1 checks fail on the round-0 `sail_screen.gd` (FAIL count=12, listed above) |

## Before / after

All PNGs are in `/private/tmp/claude-501/-Users-milankinzy-Documents-deadfront-siege/72cebc8b-d241-430b-9ea6-94d65339bfef/scratchpad/sailui/shots/` and I opened every one.

- Before (old list, gl_compatibility, `sail_lab` on the branch before the hooks): `before_home_1600x900_gl_compatibility.png`, `before_home_844x390_gl_compatibility.png`, `before_savannah_1600x900_gl_compatibility.png`, `before_savannah_844x390_gl_compatibility.png`. Grey text rows; 2.5 rows at 844x390.
- After, windowed: `after_left_1600x900_forward_plus.png`, `after_right_1600x900_forward_plus.png`, `after_left_1600x900_gl_compatibility.png`, `after_right_1600x900_gl_compatibility.png`, `after_left_844x390_gl_compatibility.png`, `after_right_844x390_gl_compatibility.png`, `after_unstable_844x390_gl_compatibility.png` (header with Return to camp / Free return home, pin and check on Savannah), `after_card_844x390_gl_compatibility.png`, `after_card_1600x900_forward_plus.png`; also `a4_cardv_1600x900_gl_compatibility.png` (Lv. 60 card, short of T-stones: the sea runs past its end so the island sits beside the card) and `a5_far_1600x900_gl_compatibility.png` (opened on volcanic_60: the chart opens with that island in view).
- After, desktop Chrome on a local WebSoak export of this tree (`tools/export_web.sh --soak`, served on 127.0.0.1, Playwright with the installed Chrome; the soak's "harbour-open" and "sail-right" checkpoints): `final/chrome_desktop_1600x900_left.png`, `final/chrome_desktop_1600x900_right.png`, `final/chrome_phone_844x390_left.png`, `final/chrome_phone_844x390_right.png` (touch emulation: DisplayMode gives the 844x390 phone canvas), `final/chrome_desktop_844x390_left.png`, `final/chrome_desktop_844x390_right.png` (a desktop window that small with no touchscreen keeps DisplayMode's 1600x900 design canvas scaled down, as every screen does there).

- Fix round 1, windowed (`scratchpad/sailui/shots/`): `r1_left_1600x900_forward_plus.png`, `r1_right_1600x900_forward_plus.png`, `r1_left_1600x900_gl_compatibility.png`, `r1_right_1600x900_gl_compatibility.png`, `r1_left_844x390_gl_compatibility.png`, `r1_right_844x390_gl_compatibility.png`, `r1_card_1600x900_forward_plus.png`, `r1_card_1600x900_gl_compatibility.png` (the card now ends under Sail), `r1_card_844x390_gl_compatibility.png`, `r1_cardhome_844x390_gl_compatibility.png` (locked Lv. 20 card from home), `r1_cardfar_1600x900_gl_compatibility.png` (Lv. 60 card, short of T-stones).
- Fix round 1, desktop Chrome on a local WebSoak export of this tree (`scratchpad/sailui/web/sail_drag.mjs`, 127.0.0.1): in `scratchpad/sailui/shots/r1web/`, for each of `phone_844x390` (touch), `touch_1600x900` (touch), `desktop_1600x900` (mouse), `desktop_844x390` (mouse): `chrome_<label>_left.png` (open), `chrome_<label>_dragged.png` (after the 400 px drag), `chrome_<label>_right.png` (far right). Phone: the Lv. 30 heading moves from x=745 to x=345; desktop: the Lv. 15 heading from x=503 to x=103, 400 px each.

What I saw: the sea reads as one chart that continues off the right edge; locked islands are dimmed with a lock and a red "Survival N"; Home and the island you stand on carry the pin and a check; the card's yellow Sail is the only bright button. At 844x390 "Unstable Temperate" steps its type down instead of being cut. Clouds are under the nodes and the band headings; the far-right bank stays off the Lv. 60 island's label.

## Assumptions (marked `# ASSUMPTION:` where they live in code)

- Home always reads as visited (every survivor starts there); `World.visited_islands` does not hold it until Home is loaded.
- The back arrow closes the chart like X: nothing sits under it to go back to.
- Names: one rule for chart and atlas, the atlas's existing one. temperate_25 keeps its data name "Unstable Temperate" because the standing order says "Sail for Unstable Temperate"; the other unstable islands read "<Climate> Island" with the level beside it, as Durango repeats "Tropical Sea" at Lv. 18 and Lv. 25.
- "11 tier bands 15..60" read as Home's Lv. 10 band plus the ten levels 15..60.
- Card lines come from existing data only: visited, the route's Survival gate, `lifetime_seconds` ("Survivable 6 h after landing", the HUD's word), `sail_cost`.

## Not done, failed, or found

- **camp_travel_probe fails, before and after this package, identically.** On the base (`claude/mmo-overhaul`, scratch tree `trees/sailui-base`) and on this branch it prints `FAIL exactly one basket after return0`, `FAIL camp cached before departure, no fixture pre-save`, `FAIL exactly one basket after return1`, `done failures3`. The probe calls `World.travel` directly, no UI; this package does not touch that path. Base checked at `e5f3ec8a` in round 0 and again at `ddaab662` in round 1 (scratch tree `trees/sailui-base`, fresh import): the same three FAIL lines and `done failures3`.
- **island_lab count:** the plan's "nodes=378 creatures=24" is older than the base. The base at `e5f3ec8a` and at `ddaab662` prints `[world] mm=2 nodes=397 creatures=24` and so does this branch, so the package leaves it unchanged (it touches no island code).
- **Web payload ceiling:** `tools/export_web.sh --soak` builds the export but its payload check fails (round 1: "pack is 275.6 MB, over the 220 MB ceiling") (biggest: survivor_v1 20.2 MB, props/meshy 16.4 MB, stegosaurus 15.9 MB). This package adds about 40 KB of scripts. The Chrome shots use that export (only the stamp and splash steps after the check did not run).
- The Lv. 25 heading still touches the Unstable Temperate ripple at 844x390 (finding 5, cosmetic; not changed, see the fix table).
- No fling/inertia after a drag (the gate wants 400 px for a 400 px drag). No live refresh while open (T-stones and Survival are read when it opens).
- The bot (`--bot`) change: a 30 s session compiled and ran, but its travel and return-home steps were not reached, so they ran only through the same `route_button` the probe and test use.

## For the reviewer

- Apply the hooks: `bash mkscratch.sh rev-sailui claude/mmo-sailui docs/orchestration/reports/claude-mmo-sailui-hooks.patch`.
- `t_sailui` without the hooks fails: on a tree at `11b7866b` without the patch it printed `[t_sailui] FAIL the harbour opened no Sail chart (the old route list?)` six times and `FAIL count=6`; `sail_lab` printed `[sail] lab FAIL no Sail chart`.
- Mutations, each on the hooked scratch tree and reverted after: dropping the `DEVICE_ID_EMULATION` guard made `t_sailui` fail with `400 px touch drag scrolls 800.0 px` (the phone's emulated mouse copy counted twice); dropping the drag-is-not-a-tap guard made it fail with `a drag from a node opens no card` at both sizes.
- Round-1 mutations, on this tree with the round-0 lines put back in `sail_screen.gd` and restored after: no mouse guard while a finger is down, no `remove_child` in `close_card`, uncapped wheel factor, `delta.x`-only pan, full-height card. `t_sailui` printed FAIL count=12: the web drag `800.0 px` at both sizes, the second card `<Object#null>` and `covers node` at both sizes, the card heights, the wheel `456 px` / `240 px`, and the trackpad pan at both sizes.
- Chrome drag check: `scratchpad/sailui/web/sail_drag.mjs <url?soak=1> <outdir> <label> <w> <h> <touch 0|1>` prints `dragged=<px>` from the soak's line.
- Shot commands: `scratchpad/sailui/shots.sh <tag> <tree>` with lines `<name> <WxH> <renderer> <lab args>`; Chrome: `scratchpad/sailui/web/sail_shots.mjs <url?soak=1> <outdir> <label> <w> <h> <touch 0|1>`.
