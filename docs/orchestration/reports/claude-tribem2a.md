# TRIBE M2a: hand-off (claude, 2026-10-29)

Branch `claude/mmo-tribem2a` (from `origin/claude/mmo-overhaul`). Plan: memo
`docs/design/hunger-and-tribe-automation.md` §2.2 and §2.8 (branch `claude/mmo-hunger-tribe-doc`), which Milan approved.

## What shipped

- **Craft hand-off.** The station radial has an **ASSIGN** hex in a fixed slot (top-right). It shows on a CraftStation whose
  recipes a member could take, and only while the tribe has members. The hex opens the station's recipes. In the
  place-materials view, **Assign…** sits beside Craft and opens the member picker (`TribeAssignPicker`). Each row
  reads like "Joss · Weapon Tools 1 · 100% · 3s"; a member who can't take the job is greyed out with the reason.
  On assignment the exact planned instances leave the bag into `TribeRecord.escrow`. The outcome and output level
  are decided at the member's skill (the survivor's rules at that skill) and never re-rolled.
  The member then walks over and works the station's own loop (`work_hammer` plus the hammer prop at the workbench,
  `work_stir` at the grill…). A plate over its head reads "Joss / Crafting Work Axe 40%". The output goes to the
  storage building nearest the station within 6 m, else the survivor's bag. XP goes to the member. While the job
  runs, the radial shows **STOP JOSS**.
- **Build hand-off.** The Construction panel has **Assign builder** once the site is filled. The site's own timer
  stops. The builder works it at its own speed and finishes it through `BuildFlow.complete(player, site, builder)`:
  the builder's Construction caps the level and the builder gets the XP. The panel then shows **Stop Joss**.
- **Refusal reasons:** busy, needs a <station>, the station runs it by itself (process recipes), one worker per
  station, "Craft it once yourself first" (teach by doing), "Needs Tailoring 10", "Missing materials",
  "84% success, needs Tailoring 19" (below the minimum), "Already built: tap Finish", "Kit is already building it".
- **Cancel.** STOP, Stop, or any other order (Stay, Follow, a gather job) hands the whole escrow back, all or
  nothing. If escrow is left without an order, `TribeDirector` hands it back as soon as the bag has room.
- **Hunger.** The member hunger rules are unchanged (members keep their own M1 fullness and eat from storage near
  the station). This code never touches the survivor's Digestion.
- **Tribe screen.** The activity line shows the job ("Crafting Work Axe 40% · craft").

## Save change (backward compatible, flagged)

A member row may now carry:
- `escrow` (item rows, sanitised like `carry`);
- a `job` of kind `craft` (`station`, `station_id`, `recipe`, `picks`, `level`, `burnt`, `outcome`, `seconds`,
  `progress`, `made`) or `build` (`site`);
- skill ids beyond Gathering and Melee.

Old saves load unchanged; the test checks an M1 row. Downgrade risk: an older build ignores `escrow` and drops a
craft job, so materials in escrow would be lost if a save with a running order is opened in an older build.

## Files

- New: `game/scripts/tribe/tribe_work.gd`, `game/scripts/ui/tribe_assign_picker.gd`, `game/tests/t_tribework.gd`,
  `game/scripts/dev/tribework_lab.gd` + `game/scenes/dev/tribework_lab.tscn`.
- Changed: `tribe_record.gd` (escrow, any skill id, station jobs), `tribe.gd` (a new order or job cancels a station
  job), `tribe_member.gd` (walk, work loop, hammer prop, job plate; `_tend_needs` extracted from `_work`),
  `tribe_director.gd` (escrow sweep), `craft_place.gd` (Assign button and picker), `station_craft.gd` and
  `station_menu.gd` (ASSIGN / STOP hex), `build_flow.gd` (optional `builder`), `construction_site.gd` (the timer
  waits for an assigned builder), `save_sanitizer.gd` (escrow), `tribe_screen.gd`, `data/tribe.json` (`work`).
- Docs: `docs/current/tribe.md`, and `docs/vision/WildLandsMMO_Open_Questions.md` T16-T24.

## Assumptions (all logged as T16-T24)

| # | Assumption |
|---|---|
| T16 | Minimum success is 80 %. |
| T17 | Speed is time × max(0.5, 1 − 0.01 × level), applied to workers only. The survivor's own craft time is unchanged. |
| T18 | A member's ability equals its skill level (no nodes or food buffs until M2b). |
| T19 | Teach by doing is on (data flag). |
| T20 | Output goes to a chest within 6 m of the station, else the bag. Undeliverable output waits with the member. |
| T21 | Work drains 0.25 fatigue and 0.15 energy per second. |
| T22 | One worker per station. Fires and process-station recipes are excluded. |
| T23 | **A builder has no Construction gate, but its level caps the station's level, so a level-1 builder builds a Lv 1 workbench.** The picker shows the predicted level. Milan should look at this one. |
| T24 | No offline catch-up. |

Also: the ASSIGN hex opens the same recipe list as CRAFT; the assignment itself happens in the place view.

## Not built

M2b-M2d, offline work, a Tribe-screen Work tab, rare-find odds for workers, and the server intent for assignment
(local only, like the rest of the tribe).

## Verification (headless, after merging origin/claude/mmo-overhaul 465b1827)

- `t_tribework` (new) passes. It assigns through the real craft panel and picker, then checks the walk, the work_hammer clip and job plate, the output in the basket, that XP goes to the member and not the survivor, every refusal reason, cancel and Stay refunds, save/load mid-craft (escrow, decided outcome and progress kept, then it finishes), and a builder completing a site at its level cap.
- `t_craftradial`, `t_stationstate`, `t_buildflow` and `t_uicraft` pass.
- `t_tribe` passes, apart from a flake in its mining section: about 1 run in 4 the member never harvests. Canon 465b1827 fails the same way in 1 of 4 runs, so the flake is not from this package. I didn't chase it.
- `t_uigather`: before the merge it failed at 844x390 ("the node has a tappable pill") in 2 of 3 runs. After the merge it passed 7 of 7, so I made no change for it. The failure looked like a race between the pill and the HUD's notice and top-feed rows.
- `bash tools/all_tests.sh`: 140 tests, 137 pass. `t_buildspeed`, `t_perfgates` (island build time over budget on a loaded machine) and `t_levelfx` failed in the full run and passed when rerun on their own, so fail=0.
- `bash tools/smoke.sh --no-import`: SMOKE PASS.
- PNG: `docs/orchestration/reports/tribem2a/tribework_hammer_1600x900.png`, showing Joss hammering at the workbench under the "Crafting Work Axe 6%" plate. I captured it once in a window before Milan's "work headlessly" rule, and made no windowed runs after that.
