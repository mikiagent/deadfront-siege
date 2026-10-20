# W1-UI report (claude, branch claude/mmo-w1-ui)

This pass's logs and screenshots are in the scratchpad, under
`/private/tmp/claude-501/-Users-milankinzy-Documents-deadfront-siege/1899b1df-f06b-4b94-91be-9e3f3c22081d/scratchpad/w1ui-r7/final/`.
Paths below are relative to that folder. Review 6's pass is under `../../w1ui-r6/`, earlier passes under `../../w1/ui/`.
The final code is commit 06830c3 (review 7: ee7d3a7, aeed9bb, 8fa0871, and 06830c3, which only adds `# ASSUMPTION:` comments).
This report is the only commit after it.

## Status: the gate is green on the branch

The orchestrator chose option (a) on 2026-10-20: for this package W1-UI owns `hunt_hud.gd` and `inventory_ui.gd`
and may land hook 1 in `main.gd`. **The hooks patch landed as real code in c4c84f9.** The patch file is deleted,
so nothing is left to apply. It contained:

- main.gd: `DisplayMode.install(get_tree().root)` and `DisplayMode.install_theme()` at the top of `_ready`.
- inventory_ui.gd: three equipment columns when four do not fit, and the profile level line through `LevelDisplay.player_label()`.
- hunt_hud.gd: on a portrait phone (`is_phone`) the context row starts at the left, one row up, and CLAIM goes under the quest card.

`ui_real_capture_lab` prints `[uireal] PASS` and exits 0 on the branch for all eight runs: 1600x900, 844x390, 667x375
and 390x844, each in Forward+ and gl_compatibility. `claude/mmo-overhaul` has not moved since the last merge (f630c58):
`git log HEAD..claude/mmo-overhaul` is empty, and `git merge-tree --write-tree --name-only HEAD claude/mmo-overhaul` exits 0
and prints only the tree id.

**Player level:** a new survivor reads `Lv. 1` on the HUD badge (`1`), the XP line (`Lv. 1  5.0%`), the atlas
(`Lv. 1`) and the bag (`Survivor · Lv. 1`). The stored `World.pioneer_level` still starts at 0, as saves expect.
`LevelDisplay.player_level()` adds 1, and every player-level display reads it there. Since review 7 that includes the
level-up banner's title, bonus stat, log line and toast. ui-level-01 is closed. Skill levels are a separate scale (see Open decisions).

## Review 7 findings and what changed

| # | Finding | What I did | Check that catches it |
|---|---|---|---|
| 1 | Major: the level-up banner shows the shown level, but the title key, bonus stat, `[world] pioneer level` log and toast use the stored one, so every title arrives one level late | `HuntHud._on_level_up` ignores the signal's stored level and reads `LevelDisplay.player_level()` once. The banner, title key, bonus-stat index, log line and `player.toast(&"level", …)` all use it | t_ui `_test_level_up_banner`: for every title key ≥ 2 it sets the stored level to key − 1, fires `_on_level_up`, and requires the banner `Lv. <key>` plus `Title <titles[key]> acquired.`. Passing: `[t_ui] level-up banner: 6 titled levels, banner level and title key agree`. On the review-6 hunt_hud it fails 6 times, e.g. `[t_ui] FAIL level-up to Lv. 5: banner "Lv. 5" with "Title Camp Builder acquired." (got "")` |
| 2 | Minor: the atlas shows only the current island's card on phones | The card column is a `ScrollContainer` (horizontal scroll off, the house pattern from craft_ui). It holds up to 4 charted islands at every size. At 844x390 one and a half cards show, with a scrollbar | Lab: `[uireal] atlas cards: 4 of 15 charted islands` at all 8 runs, gated to `mini(4, charted)`. Card rects are clipped to the column for the overlap check. Mutation (one card on compact): `[uireal] FAIL atlas lists 4 island cards at every size (got 1)`, exit 1 (`mut_atlas_one_card.log`) |
| 3 | Minor: skills read `Lv. 0` and the bag reads `Gathering 0` next to the player's `Lv. 1` | Not changed. This is a numbering decision, listed under Open decisions below. It touches skill-node required levels (`skills_sheet.gd:230,261,277`, `inventory_ui.gd:443`) | n/a |
| 4 | Minor: the gather title box covers the lower half of the bush and its selection hexagon at 844x390 | `GatherRadial.title_spot` puts the name + level box under the selection ring. Where the bottom edge (24 px), a HUD zone or the nameplate is in the way, it goes above the plant's top. It is placed in `_layout` before the hexes, which now avoid the plant (`source_rect()`) and the title. `ContextRadial.hex_positions` takes a `label_w` and also scores each hex's outward label slot. In crowded cases, `pick_label_rect` slides above/below labels along their hex to clear a blocker, and treats the plant as a soft blocker (a tenth the weight of text). `UiTokens.hud_reserved` gains the bottom-centre XP line (`xp_line_zone`) on landscape and desktop, after a label landed on it | Lab: the title, every label and every hex are checked against all HUD blocks, the nameplate and each other. The title must not touch the convex hull of the ring and the plant top (`GatherRadial.source_hull()`). Hexes and labels may graze it by at most 5 % of their own box. Passing: `... (most of a part on it 0.0%)` at 1600x900, 844x390 and 667x375, and `0.6%` at 390x844. Mutation (title back in the ring): `[uireal] FAIL radial: title [P: (442.5391, 311.0884), S: (106.0, 40.0)] stays off the plant and its ring ... (covers 39% of it)`, exit 1 (`mut_title_in_ring.log`). ui_screenshot_lab now gates its right-edge radial (title off every label and hex). It caught a regression on the way: `[uishot] FAIL edge radial title ... stays off [P: (1481.0, 636.6211), S: (111.0, 26.0)]`. t_ui: the landscape zones cover the XP line |
| 5 | Minor: hunt_hud (now owned) still uses colour emoji, but the report said ui-glyph-01 was closed | **ui-glyph-01 is closed only for the files W1-UI owned from the start** (the 23 in t_ui's `OWNED`). I did not swap hunt_hud's glyphs. The icon set has no fitting white symbol for animals, tackle, kick, guard, chase, hold, XP or debug (`tamed_animal.png` and `captured_animal.png` are a pen, `raptor_talon.png` is a claw). Inventing symbols is W1-ICONART/W2-HUD work. The 11 emoji lines in hunt_hud.gd: 209 `🦖` ANIMALS, 217 and 247 `🍖` quick-food fallback, 225 `🔍` DEBUG, 297 `🕸💥🦵` hunt skills, 316 `🦖🛡` SIC/GUARD, 345 and 352 `🏃` CHASE, 654 `👁` level-up XP line, 882 `💥`, 887 `🕸` | t_ui counts emoji lines in the late-owned files and caps them, so the number cannot grow: `[t_ui] hunt_hud.gd: 11 lines with emoji (cap 11, W2-HUD)` and `[t_ui] inventory_ui.gd: 0 lines with emoji (cap 0, W2-HUD)` |
| 6 | Minor: `min_font_px` printed floor(points); 667x375 printed 9 while the text is larger | The lab prints both units. `min_font_px` is the smallest font size on the logical canvas. `min_font_pt` is its on-screen size in points, the unit the phone floor is gated in. The `(smallest: …)` note now prints logical px too; before, it printed window px labelled "px". At 667x375 the smallest text is 12 logical px (9.96 pt), not 10 logical px: the old `10.0 px` was window px | `[uireal] phone=true min_font_px=12 min_font_pt=9.96 logical_width=804 window_pt=667x375 floor_pt=9.96 (smallest: RecipeMeta "Lv. — · 2.0s  ·  Missing" 12.0 px)`. Review 6 printed `min_font_px=9 ... min_pt=9.96 ... 10.0 px` for the same text (`../../w1ui-r6/667x375_glc.log`) |

## Review 6 findings (previous pass, unchanged)

| # | Finding | What I did | Check that catches it |
|---|---|---|---|
| 1 | Blocker: the lab is red on the branch; the fix sits in protected files | Landed the hooks patch under option (a) (c4c84f9) | Lab PASS at all 8 size/renderer runs (checklist below) |
| 2 | Radial: a huge finite anchor collapses the hexes | `ContextRadial.hex_positions` clamps the anchor to the view grown by one ring (radius + hex), next to the NaN guard | t_ui: `[t_ui] huge anchor (-1e9, 1e9): six hexes, min_dist=96.0`. Mutation (clamp removed): `[t_ui] FAIL anchor (-1e9, 1e9) keeps six hexes apart (min 0.0)`, exit 1 (`t_ui_mut_anchor.log`) |
| 3 | Gather radial label lands on the survivor's nameplate at 844x390 | `HuntHud.nameplate_rect()` is the one source for the nameplate rect. The HUD draws from it, and the gather radial adds it to the hexes' avoid list and the labels' blockers. **The first fix moved the label onto the HANDS caption.** I saw it in `old/844x390_fwd/radial_844x390.png` and the nameplate-only gate passed it. So: the landscape `UiTokens.hud_reserved` now includes HANDS (stacked above the rail), labels treat the HUD zones as blockers, and when no spot is clear `pick_label_rect` takes the least-covered one (the preferred side on a tie, so run_all's boxed-in case holds) | Lab: every radial label and hex is checked against all `hud_blocks` plus the nameplate: `[uireal] radial: 2 option labels and 2 hexes checked against 16 HUD blocks, nameplate [P: (387.5001, 197.0615), S: (70.0, 29.0)]`. On the code before the HANDS fix it failed: `[uireal] FAIL radial: label0 [P: (265.8696, 259.7754), S: (99.0, 26.0)] stays off HeldItemSlot [P: (238.0, 196.0), S: (64.0, 82.0)]`, exit 1 (`844x390_fwd_prefix.log`). t_ui: the landscape zones must cover the HANDS slot |
| 4 | map_screen: a dead `yaw` key and consts declared mid-file | Removed `yaw` and its rotation math: the draw uses a north-up transform and taps use `pos - centre`. Moved `PHONE_CARD_TOP`/`PHONE_MAP_TOP` up with the other consts | t_ui: the atlas `_layout()` keys must be `centre/fit/scale/size_m`. t_ui owned-source scan: no `const` after the first `func` in any owned file (only map_screen had them) |
| 5 | A new survivor reads `Lv. 0` | Orchestrator decision: `Lv. 1`. `LevelDisplay.player_level()` returns stored + 1. The HUD badge, XP line and level-up banner (hunt_hud) and world_ui's panel now read it | t_ui: `[t_ui] player level: new survivor reads Lv. 1; direct reads outside LevelDisplay=0`. The scan covers the owned files, hunt_hud, inventory_ui and the lab; writes and the `pioneer_changed` argument are allowed. Lab: the bag's profile must end with `LevelDisplay.player_label()` |
| 6 | Sync commit d2c8e8a copied docs instead of merging | This pass merges `claude/mmo-overhaul` with a real merge (f630c58). Its one conflict, `docs/orchestration/mmo/STATUS.md`, resolved to the base version, which W1-UI does not own. The branch's STATUS.md now equals the base's | `git diff claude/mmo-overhaul -- docs/orchestration/mmo/STATUS.md` is empty; merge-tree exits 0 |
| 7 | t_ui prints a WARNING and a backtrace (`grab_focus` on a FOCUS_NONE hex) | Dropped the `grab_focus` call. The test asserts `FOCUS_NONE` and still pushes the click. t_ui now installs a `Logger` (`OS.add_logger`) for the whole run and fails on any engine error or warning | `[t_ui] engine errors/warnings during the checks: 0`. Mutation (`grab_focus` back): `[t_ui] FAIL engine WARNING This control can't grab focus. Use set_focus_mode() and set_focus_behavior_recursive() to allow a control to get focus. (scene/gui/control.cpp:3006 grab_focus)`, exit 1 |

I also dropped the lab's `--no-fit` and `--no-theme` flags (826ab9e). main.gd installs both before any lab starts,
so the flags could no longer turn them off. The verdict on a missing fit is still unit-tested: t_ui `_test_gate_verdict`,
`[t_ui] gate: 844x390 without fit -> 2 failures`.

## Acceptance checklist (on the branch, nothing applied on top)

The eight lab runs, ui_family_lab and ui_screenshot_lab ran on 8fa0871. After the comment-only 06830c3 I reran t_ui, run_all,
smoke and the lab at 844x390 and 667x375 (gl_compatibility). Each printed its PASS line again and exited 0, and the logs were overwritten in place.

| Item | Output line (log) |
|---|---|
| 1600x900, web renderer (gl_compatibility) | `[uireal] phone=false min_font_px=13 min_font_pt=13.00 logical_width=1600 window_pt=1600x900 floor_pt=12.00 (smallest: CraftHint ... 13.0 px)` then `[uireal] PASS screens=hud,craft,skills,atlas,radial,plate,bag,charcreate shot_only=animals shots=.../w1ui-r7/final/1600x900_glc`, exit 0 (`1600x900_glc.log`) |
| 1600x900, Forward+ | Same two lines, `shots=.../final/1600x900_fwd`, exit 0 (`1600x900_fwd.log`) |
| 844x390, web renderer | `[uireal] phone=true min_font_px=12 min_font_pt=12.00 logical_width=844 window_pt=844x390 floor_pt=12.00 (smallest: RecipeMeta ... 12.0 px)` then `[uireal] PASS screens=hud,craft,skills,atlas,radial,plate,bag,charcreate shot_only=animals shots=.../final/844x390_glc`, exit 0 (`844x390_glc.log`) |
| 844x390, Forward+ | Same two lines, `shots=.../final/844x390_fwd`, exit 0 (`844x390_fwd.log`) |
| 667x375, both renderers | `[uireal] window=667x375 logical=804x452 content_scale=(804, 452)`, `[uireal] phone=true min_font_px=12 min_font_pt=9.96 logical_width=804 window_pt=667x375 floor_pt=9.96 (...)`, `[uireal] PASS ...`, exit 0 (`667x375_fwd.log`, `667x375_glc.log`) |
| 390x844, both renderers | `[uireal] phone=true min_font_px=12 min_font_pt=12.00 logical_width=390 window_pt=390x844 floor_pt=12.00 (...)` then `[uireal] PASS screens=hud,craft,craft_detail,skills,atlas,radial,plate,bag,charcreate shot_only=animals ...`, exit 0 (`390x844_fwd.log`, `390x844_glc.log`) |
| Radial, all 8 runs | `[uireal] radial: 2 option labels, 2 hexes and the title checked against 16 HUD blocks and the source [...] (most of a part on it 0.0%)` (0.6% at 390x844) |
| Atlas, all 8 runs | `[uireal] atlas cards: 4 of 15 charted islands` |
| t_ui (`t_ui.log`) | `[t_ui] scanned 23 owned files: emoji=0 small_font=0`, `[t_ui] hunt_hud.gd: 11 lines with emoji (cap 11, W2-HUD)`, `[t_ui] inventory_ui.gd: 0 lines with emoji (cap 0, W2-HUD)`, `[t_ui] draw_centered: 40 px at x=100 starts at 80.0`, `[t_ui] radial above view: centres 150.4 px apart (hex 64)`, `[t_ui] craft: 5 unmakeable hand recipes read 'Lv. —'`, `[t_ui] atlas legend: 8 kinds, min colour distance 0.35`, `[t_ui] player level: new survivor reads Lv. 1; direct reads outside LevelDisplay=0`, `[t_ui] level-up banner: 6 titled levels, banner level and title key agree`, `[t_ui] huge anchor (-1e9, 1e9): six hexes, min_dist=96.0`, `[t_ui] engine errors/warnings during the checks: 0`, then `[t_ui] PASS`, exit 0. The log has no `SCRIPT ERROR` or `WARNING` line |
| Existing suite (`run_all.log`) | `[tests] PASS`, exit 0. The exit-time `5 ObjectDB instances were leaked` / `1 resources still in use` lines are identical in review 6's log |
| ui_family_lab, headless (`ui_family.log`) | `[uifamily] inventory=true animals=true unlimited=true active_cap=3 stego=stegosaurus`, exit 0 |
| ui_screenshot_lab, windowed 1600x900 (`ui_screenshot.log`) | `[uishot] edge radial: title [P: (1459.25, 640.3619), S: (99.0, 42.0)], 3 labels, source [...]` then `[uishot] PASS screens=hud,inventory,animals,craft,atlas,death,radial sizes=1600x900,390x844 shots=/tmp/deadfront-ui-shots`, exit 0 |
| Smoke (`smoke.log`, `tools/smoke.sh --no-import` through gslot) | `[smoke] ok player_pos=(0.0, 0.900182, 0.0) phase=day` then `SMOKE PASS`, exit 0 |
| Merge with the base | `git log HEAD..claude/mmo-overhaul` is empty; `git merge-tree --write-tree --name-only HEAD claude/mmo-overhaul` exits 0 and prints only the tree id |

These lines hold at all eight runs: `[uireal] charcreate cards: rows=2 title_y_spread=0.0 start_y_spread=0.0` (rows=4 at
390x844). Skills rows fully visible: `10/12` at 844x390. Landscape Craft is pinned:
`[uireal] craft sheet: CraftOne [P: (460.0, 314.0), S: (180.0, 64.0)] in footer=true vscrolls=3` (844x390).
The spec writes `'Lv —'`; the screens print `Lv. —`, which is the one level format.

No `--import` this pass: review 7 added no class_name files and no assets.

## Screenshots inspected (Read tool), this pass

- `844x390_glc/radial_844x390.png`, `844x390_fwd/radial_844x390.png`: the bush and its selection hexagon are fully visible.
  `Bush Berries / Lv. 1` sits above the plant (under the ring would run off the bottom edge). `Berries Lv. 1` sits above its hex,
  a couple of px left of the title. `Fibre Stalk Lv. 1` sits above its hex, and `Survivor` and HANDS are clear. Before:
  the reviewer's `../../finish-review/ui/r1/pairs/after_radial_crop.png`, where the title covers the bush and the ring.
- `1600x900_glc/radial_1600x900.png`: title under the ring, both labels beside their hexes, nothing on the bush.
- `667x375_glc/radial_667x375.png`: crowded but clear. The title sits left of and above the bush. The lower hex's tip ends just
  above the `Lv. 1  5.0%` line.
- `390x844_fwd/radial_390x844.png`: the bush is at the right edge under HANDS, so the title and labels sit to its left.
- `/tmp/deadfront-ui-shots/radial_edge_1600x900.png`: `Birch Tree` under its ring, with `Branch`, `Log` and `Bark Strip` labels clear of it.
  One run before the soft-blocker change, `Branch Lv. 1` sat on the title (`B Branch`). The new edge gate failed on it, and I fixed it.
  Review 6's version: `../../audit/ui-ux/labshots/radial_edge_1600x900.png`.
- `844x390_glc/atlas_844x390.png`, `667x375_fwd/atlas_667x375.png`: the card column scrolls (scrollbar at the right), and
  `Private Grassland` and `Savannah Island` are visible. `390x844_glc/atlas_390x844.png`: one card plus a scrollbar.
  `1600x900_glc/atlas_1600x900.png`: four cards, unchanged.

## Integrator hooks

None for main.gd: hook 1 landed on the branch. Two notes remain:

1. `game/scripts/ui/hunt_hud.gd:69` (now W2-HUD's): `set_anchors_preset(Control.PRESET_FULL_RECT)` ->
   `set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)`. It is not in the landed patch, and I left it out on purpose. The HUD's
   `mouse_filter` is IGNORE, so it would not eat taps. But giving the HUD a real rect can move any child anchored to it,
   and I have not run that. Run the lab at all four sizes if it lands.
2. `run_all.gd`: no edit. Under the plan, `tools/test.sh` (W1-QA) runs every `t_*.gd`, which includes `t_ui.gd`.

## Labs to register

`tools/labs.txt` does not exist yet. Proposed line, one lab:

`ui_real_capture_lab  windowed  --resolution 844x390 -- --lab=ui_real_capture_lab --shot-dir=DIR   # also 1600x900, 667x375, 390x844; add --rendering-method gl_compatibility for web; expect "[uireal] PASS", exit 0`

The scene is `game/scenes/dev/ui_real_capture_lab.tscn`. It is green on the branch now; register it as a required gate.

## Assumptions (`# ASSUMPTION:` in code unless noted; review 7 added the last three)

- `display_mode.gd` `LANDSCAPE_MIN_W := 804.0`: the bag's three columns need about 804 usable px. Narrower landscape
  phones get 804 px at a smaller scale: 10 pt smallest text on a 667 pt SE, 9.6 pt on a 640 pt Android, and about
  11.2 pt on a notched 844 pt iPhone.
- `display_mode.gd` `side_inset_px` / `MIN_USABLE := 0.75`: on mobile, the side safe-area insets come off before the floor
  applies, and the safe area never leaves less than 75 % of the width usable. Unit-tested only.
- `held_item_slot.gd`: mirrors hunt_hud's rail (four 64 px hexes, 10 px apart, 96 px up). The new landscape HANDS zone
  in `UiTokens.hud_reserved` (`Rect2(232, h - 200, 76, 96)`) mirrors that placement. A comment there says so; t_ui checks
  that the zone covers the slot.
- `ui_real_capture_lab.gd` `hud_blocks`: the vitals, quest and level-line rects mirror hunt_hud.gd `_draw` and `_draw_quest`.
- `skills_sheet.gd` SYMBOLS: item symbols stand in for skill art (W1-ICONART). The character cards reuse them.
- `craft_ui.gd` STATIONS: the crock pot uses the `boiled_meat` cauldron symbol and the campfire uses `skewer`.
- `level_display.gd`: no longer an assumption. The orchestrator decided that the shown level is stored + 1.
- `character_creation.gd` `STORY_TIGHTEN := 8`. Phone cards show the head-start skill without `Lv. 20` or a symbol.
- `hex_button.gd` focus: only the station menu opts its hexes into focus. The radials do not call `focus_first`, so a
  controller does not drive them yet (ui-gamepad-01 is shared with W2-SCREENS).
- `ui_tokens.gd` `xp_line_zone`: 180x26 px at the bottom centre, mirroring hunt_hud's XP line (13 px text at `r.y - 7`).
- `gather_radial.gd`: the title clears the bottom edge by 24 px (the XP line). In `pick_label_rect`, the plant counts at a tenth of
  the weight of text.
- `ui_real_capture_lab.gd`: a hex or label may graze the plant's hull by at most 5 % of its own box; the title may not touch it.
  Where the plant sits under the HUD at a screen edge (390x844), no ring keeps fully clear (0.6 % measured).
- No `game/ui/deadfront_theme.tres`: the theme is built from tokens at runtime.

## Open decisions (for the orchestrator)

- **Starter title.** `titles.json` key `1` ("Venture into the World") was granted by the first level-up when the shown level was the
  stored one. Now a survivor starts at `Lv. 1`, and the first level-up shows `Lv. 2`, so no level-up grants it. Options: grant it at
  character creation (one toast, owned by W2-PLAYER or whoever owns creation), or re-key titles.json (not W1-UI's file). I changed neither.
- **Skill levels from 0 or 1.** The player level reads `Lv. 1` for a new survivor, but all twelve skills read `Lv. 0`
  (`skills_sheet.gd:230,261`), and the bag profile reads `Gathering 0` (`inventory_ui.gd:443`). The owner's
  `docs/reference/durango-skill-screen.webp` shows Lv. 1 as the lowest skill level. Showing skills from 1 also shifts every
  skill node's required-level text (`skills_sheet.gd:277`). I left skills at 0 until that is decided.

## What is left / risks

- **Phone fit needs one device or mobile-web run.** There is no device here and no web export on this shared machine. The notch path and
  `DisplayServer.screen_get_scale()` on mobile web are unit-tested only. On a device, record the boot line
  `[display] window (W, H) -> logical (w, h)` and the lab's `[uireal] phone=... min_pt=...` line.
- hunt_hud.gd keeps 11 lines of colour emoji (list in review 7 row 5). That is W2-HUD/W1-ICONART work: white symbols for animals,
  tackle, kick, guard, chase/hold, XP and debug. t_ui caps the count at 11.
- On the smallest landscape phone (667x375) and in portrait, the gather title can sit a little away from its plant, because the space
  under and around it is taken by the HUD. Everything is clear, but on a crowded edge the title reads less clearly as the plant's.
- Portrait 390x844 radial is crowded near HANDS (clear by a few px, gate PASS).
- On the protected bag at 1600x900, the four-column Legs/Ring slots touch the panel's right border. On a 390 pt landscape phone the
  bag's fourth row and food slots need a scroll.
- Animal screen has no backdrop (`animal_screen.gd`: `set_anchors_preset` inside the tree keeps an empty rect). The lab still saves
  `animals_<w>x<h>.png` on every run, and nothing on that screen is gated. This is for W2-SCREENS.
- The HUD minimap turns with the camera while the atlas is north-up (W2-HUD). `UiTokens.hud_reserved` and the lab's
  `hud_blocks` mirror hunt_hud geometry; replace both with rects the HUD exports.
- The white-symbol shader is checked on Forward+ and gl_compatibility on macOS (Metal), not on a phone GPU.
- The atlas card shows the home island as `Lv. 10` (its tier in world data). That is a data question.
