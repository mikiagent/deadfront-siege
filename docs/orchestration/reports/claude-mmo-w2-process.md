# W2-PROCESS: process stations, in-place processing, queues that keep running

Branch `claude/mmo-w2-process`, cut from `claude/mmo-overhaul` 36299a96. Base merged in twice (5e05197e, then
1c89134a), both clean with no overlapping files. Commits:
- ec4e9375: stations and t_process
- c00f7179: process_lab, label and smoke tuning
- ccf9a9bf: round 2, following spec 08 (below)
- two base merges, and the commit carrying this report
- round 3 (review r1 fixes): base merge c59dd1de (5daa97ef, docs only), ff8d6c4c (pack-up, payoff, level,
  tests), 4b5b88eb and 0ec9253f (process_lab), plus this report
- round 4 (vision-check fixes): 10a2993b (label placement), base merge 4afcb170 (6e26ef2a, docs only),
  6a385058 (exact picks, destroyed-station salvage, hooks patch), plus this report
- round 5 (resumed run): base merges 061cc651 and 910327f9 (548059bc, 34b6d459, docs only), 619c3b0a (the
  destroyed listener is dropped), 19fbb83b + 3f5835cb (a label move tried and reverted), ffc3833f (smoke on
  gl_compatibility), plus this report
- round 6 (review `docs/orchestration/mmo/handoff/findings/w2-process-review-r1.json`): e6b69abf (picks by uid,
  save boundary, status on the HUD chip), cbb9e595 (hooks patch), 81ec4348 + 76875ea4 (process_lab),
  8fd3e3f6 (asset register), plus this report. The base has not moved since 34b6d459
  (`git log HEAD..claude/mmo-overhaul` is empty), so no merge was needed
- round 7 (review r2, the findings in this run's prompt): base merge b1756bb0 (cecc936b, docs only), 47f63f0c
  (PlayerActions verbs, honest times, one-line chips, contents), add208b3 (boxed-in chips, lab options), plus the
  commit carrying this report
- round 8 (resumed run, the same r2 findings in this run's prompt): base merge 28b4c50f (ddaab662: W2-DATA,
  W2-SKILLS, WATER), dc645889 (hooks patch regenerated), plus the commit carrying this report
- round 9 (review r3, the findings in this run's prompt): base merge c1af1b83 (946da955: HUD-DAYNIGHT), 255feaa8
  (XP-once check, load capped at capacity, save round trip and done colours in run_all, strip cache), f7ca30df
  (hooks patch), 65bc16dd (done colours), b0c0faca (process_lab exact XP), plus the commit carrying this report

## Round 9: review r3 findings

Base merge c1af1b83 pulled in claude/mmo-overhaul 946da955 (HUD-DAYNIGHT). It merged clean, and none of this
package's files overlap it. Every finding is fixed below, each with a check that fails on the old behaviour.
The mutation logs are in `scratchpad/r3/` (`mutations.log`, `mut_*.log`). Each mutation was planted in the work
tree, run, and reverted with `git checkout`.

**1. XP paid exactly once per job (major, and the acceptance item "No repeated XP", spec 08:126).** The
behaviour was already right. What was missing was a check that pins the amount. `process_checks.gd` now runs
in both t_process and run_all. It builds a Player with `new()` and a fresh SkillState, then runs two rounds of
two dry_meat jobs through the rack, collecting each round, and then does a third collect with nothing ready. It
checks the Processing XP banked against `n x (6 + recipe_seconds)`, counting any level-ups, so a level cap
cannot hide a double grant. Passing line: `ok collect pays 14 Processing XP per dried meat, once: 2 -> 28, 4 ->
56, empty collect -> 56 (want 28, 56, 56)`. process_lab's menu-route check is exact too now (b0c0faca):
`processing XP paid on collect, once per job (1000000.0 -> 1000056.0, want +56)`.
Mutation M1 calls `Crafting.grant_craft_xp` twice per collected output:
- t_process: `[t_process] FAIL collect pays 14 Processing XP per dried meat, once: 2 -> 56, 4 -> 112, empty collect -> 112 (want 28, 56, 56)`
- run_all: `ERROR: [tests] collect pays 14 Processing XP per dried meat, once: 2 -> 56, 4 -> 112, empty collect -> 112 (want 28, 56, 56)`, then `[tests] FAIL count=1`
- process_lab (hooks patch applied): `[process_lab] FAIL processing XP paid on collect, once per job (1000000.0 -> 1000112.0, want +56)`

The bag-full partial collect is not in the new check. `Player.notice` needs the scene tree, and run_all has no
survivor in it. The reviewer's probe covered that path: +28 on each of two partial collects.

**2. `crafting.gd` default_picks collides with W2-INV's hooks patch (minor).** The finding is right. This is
an integrator note, and there is no code change on this branch, because W2-INV has not merged
(`git merge-base --is-ancestor claude/mmo-w2-inv claude/mmo-overhaul` is false). The details are under
"Integrator hooks" below.

**3. Done-state colours (minor).** In `processing.json` `contents.to`:
- Smoked strips go from `#4a2616` (v 0.29, black in the smoker's doorway) to `#7c4324`, a mahogany brown.
- Steamed food goes from `#efe0c0` (s 0.20, read as an empty cream dish) to `#c47f3a`, a golden tan.

A first try, `#925229` / `#d8a25c`, rendered too orange on the smoker and too pale in the steamer bowls
(`scratchpad/r3/shots/old_*`). The new check in `process_checks.gd` requires every station's done colour to
have saturation >= 0.35 and value >= 0.33. Mutation M6 (the r2 colours) fails it:
`[t_process] FAIL smoker done colour 4a2616 is not near-white or near-black (s 0.70, v 0.29)` and
`[t_process] FAIL steamer done colour efe0c0 is not near-white or near-black (s 0.20, v 0.94)`, and run_all fails the same way. The rack's dried
tile stays on the W1-STRUCTART REPLACE row in `asset-replacement.md`. Its strips are part of the frame's atlas
mesh, so they cannot be tinted from code without tinting the frame.

**4. A loaded row ignores capacity (minor).** `load_dict` now turns any job past `capacity()` into a collectable
output of its own inputs (recipe "", no XP), the same way it handles a dropped recipe. Nothing is deleted, and
the refund path (`saved_stacks`) still returns every unit. Check: `ok 40 saved jobs on a 4-place steamer load
as 4 jobs + 36 to collect (40 units kept)`. Mutation M5 (the old load) fails it: `[t_process] FAIL 40 saved jobs
on a 4-place steamer load as 40 jobs + 0 to collect (40 units kept)`, and run_all fails too.

**5. run_all did not round-trip `to_dict` (minor).** `process_checks.gd` now saves a loaded rack through
`CraftStation.to_dict -> JSON -> SaveRestore.spawn` and checks the job's input keeps its uid: `ok a loaded rack
saves and loads its job through to_dict -> JSON -> spawn (uid l3f169073892ad323)`. Mutation M4 (no "process"
key) now fails run_all: `ERROR: [tests] a loaded rack saves and loads its job through to_dict -> JSON -> spawn
(uid )`, then `[tests] FAIL count=1`. t_process reports 34 FAIL lines for M4.

**6. Small costs and leftovers (minor):**
- **HudPills:** the name text is now measured only for a chip that shows a status (hooks patch, f7ca30df).
- **show_strips:** `ProcessFx.find_strips` runs once per stage model. ProcessStation caches the nodes and keys
  the cache on the Prop's instance id, so a stage swap finds the new model's strips. The 4x/s `find_child` walk
  is gone. t_process's stand-in check still passes: `ok one strip loaded shows 2 of the model's 8 strips (2)`.
- **Typed collect / take_back:** the switch is ready as a post-merge snippet under "Integrator hooks". It is not
  a hooks-patch hunk, because the shared rules require the patch to `git apply --check` clean on bare
  claude/mmo-overhaul, and these `station_craft.gd` lines exist only on this branch. The snippet compiles and
  passes: process_lab ran with the hooks patch plus the snippet and gave `[process_lab] PASS` with 0 SCRIPT
  ERROR (`scratchpad/r3/typed_process_lab.log`).
- **Captions and ellipsis at 844x390:** seen again in `rack100menu_844`: COLLECT 4 sits on the smoker roof, and
  the chip reads `Ready: 3 Smoked...`. Steamed food is cut at 1600 too (`Ready: 2 Steamed...`). The StationMenu
  caption and the chip width cap (`UiTokens.LABEL_MAX_W`) belong to W1-UI, as the reviewer says. This package
  leaves them open for W1-UI.

Gates: running on the scratch tree `trees/w2proc-gates9` (b0c0faca + hooks patch); results follow in the next commit.

## Round 8: resumed run, base merged, gates and shots redone

The prompt repeats the r2 findings that round 7 fixed (47f63f0c, add208b3). git log and the code show each fix
is on the branch, and every check from the round 7 table still runs. This round merged the moved base, regenerated
the hooks patch, and redid every gate and the affected shots on the merged tree. No finding needed new code.

- **Base merge** 28b4c50f: claude/mmo-overhaul ddaab662 (W2-DATA items and recipes, W2-SKILLS, WATER). Clean, no
  conflicts. The base touched `crafting.gd` (W2-SKILLS `progression_block`, a `cured_hide` category), and those
  changes sit apart from this package's lines. `processing.json` still matches `recipes.json`: dry_meat and
  dried_hide on the drying rack, smoke_meat on the smoker, camp_stew on the crock pot, steam on the steamer. No new
  recipe uses those four stations.
- **Hooks patch** dc645889: regenerated from the gate tree as `git diff --cached` after applying it. The body is
  the same, and only the line numbers moved, because WATER added drink/wash/fill above `craft()` in
  `player_actions.gd`. The six files it touches are byte-identical on claude/mmo-overhaul ddaab662 and on this
  branch (`git diff --quiet` clean). `git apply --check` is clean.
- **The findings, checked on the merged tree** (t_process, gate tree with the patch applied):
  - PlayerActions: `ok online: collect and take back queue ["act.collect", "act.take_back"] and leave the bag
    and the pot as they are (ready 1, jobs 2)`
  - Honest preview: `ok the drying rack's craft card shows 10:00, not 8.0s (["Lv. — · 10:00 · Locked", "Lv. 7 ·
    10:00 · No station"] | ["Dried Hide\nLv. — · 10:00 ×1"])` and `ok steam 1:00, stew 3:00; recipe_seconds
    (XP) unchanged`
  - Chips on their stations: `ok a chip grazing the survivor steps sideways, its station still under it`,
    `ok a chip with a panel above its station hangs under its anchor`, `ok a chip with no free spot by its
    station says so`
  - Take back: `ok offline take back: the waiting job's own meat (uid l3cc54b81dc8dc631) and its herb and berry
    are back, the running job stays`
  - Dropped station kind: `ok a workbench row with a saved job: COLLECT gives the raw meat back, then it packs
    up`, and `ok an input handed back pays no craft XP`
  - Strips: `ok one strip loaded shows 2 of the model's 8 strips (2)`
- **New on the base, not this package's:** W2-SKILLS gates Dried Hide behind the "Dry Leather" node
  (Processing Lv. 15, 2 SP, `source: spec11`). The rack's craft card therefore reads `Locked` and gives the reason
  ("Learn Dry Leather (Processing Lv. 15, 2 SP) ..."). The station path keeps that gate:
  `ProcessStation.refuse_reason` calls `Crafting.progression_block`. With the base's other change, hide straps
  now need dried hide. That means straps need Processing Lv. 15. The integrator should confirm this with W2-SKILLS
  and W2-DATA.

Shots, all opened and looked at. They use gl_compatibility with the hooks patch applied, on the merged tree.
Files are in `/private/tmp/claude-501/-Users-milankinzy-Documents-deadfront-siege/72cebc8b-d241-430b-9ea6-94d65339bfef/scratchpad/r8/shots/`.
Each run ended in a `[process_lab] PASS shot` line with 0 SCRIPT ERROR:
- `all50_844`: the four one-line statuses each sit over their own station (`Steaming 2/4 · 0:24`, `Stewing 3/4 ·
  1:24`, `Drying 4/4 · 4:54`, `Smoking 3/4 · 7:24`). Check line: `PASS shot all 50%: 4 chips, 0 overlaps (chip
  on chip or on the survivor), 0 station world labels, 0 chips off their station []`. The new SKILLS button and
  minimap from the base are clear of the chips.
- `rack100menu_844`: COLLECT 4 and CRAFT around the rack. `Ready: 3 Camp Stew` is on the pot and `Ready: 3
  Smoked...` is on the smoker (`2 chips, ... 0 chips off their station []`).
- `rack50sheet_844`: "Craft · Meat dryer". Both rows and the detail read `10:00`. Dried Hide is locked by
  W2-SKILLS, as described above.
- `pot50menu_844`: TAKE BACK 2 beside CRAFT, with the pink raw bowls by the pot. The steamer falls back to its name chip.
- `smoker50_844` and the crop `crop_smoker50_844`: the smoker's grey plume rises over its roof up to the Orders
  panel. The rack's lighter smoke is beside it.
- `all50_1600`, `rack100_1600`, `racks3_1600`: the 1600x900 views. Contents are coloured per job, chips sit on
  their stations, and the line reads `3 of 3 working racks with a chip`.
- Seen, not fixed, as in round 7:
  - At 100 % the rack's strips match the frame wood.
  - The extra racks show all 8 strips. Their stage GLB has no `strip_N` nodes (the registered REPLACE).
  - The COLLECT caption touches the smoker's roof (StationMenu, W1-UI).

Round 8 gates. They ran on the scratch tree `trees/w2proc-gates8` at 28b4c50f with the hooks patch applied, every
Godot run under gslot, logs in `scratchpad/r8/gates/`:
- `--import`: exit 0, 0 ERROR lines.
- All 23 `t_*.gd` exit 0, with 0 SCRIPT ERROR apart from t_save's 5 deliberate ones. The list includes the base's
  new `[t_data] PASS items=223 recipes=155`, `[t_water] PASS` and `[t_w2_skills] PASS`, and also `[t_process]
  PASS`, `[t_build] PASS`, `[t_save] PASS`, `[t_ui] PASS`, `[t_web] PASS`, `[t_harbour] PASS islands=15`,
  `[t_uiicons] PASS ids=177 files=116 ...`, `[t_items] PASS` and `[t_player] PASS`.
- `[tests] PASS` (run_all, with the process checks) and `SMOKE PASS` (`tools/smoke.sh --no-import`, 0 SCRIPT ERROR).
- `[process_lab] PASS`, `[kitchen_lab] PASS`, `[craft_lab] PASS` (headless), 0 SCRIPT ERROR each. All 8 windowed
  process_lab shots PASS.
- 0 "couldn't resolve track" lines in any gate or shot log.
- No new `Godot-*.ips`. The newest is still `Godot-2026-10-20-232613.ips`, from before this round.

## Round 7: review r2 findings

Every finding was right. Each fix has a check that fails on the old behaviour; the FAIL lines below come from a
mutation tree (`trees/w2proc-mut7`: the branch, the hooks patch, then one change per finding put back) or, for
the chip layout, from the r1 two-line chip run under the new lab check.

| Finding | Fix | Proof (new code) | Old behaviour / mutation |
|---|---|---|---|
| **Major**: COLLECT changed the bag outside PlayerActions (contracts.md §0.3); online it moved the meat locally and sent no intent | Hooks patch on W2-PLAYER's `player_actions.gd`: `collect(st)` and `take_back(st)` return `_send(&"collect"/"take_back", {"station": net_id(st)})` when online, and otherwise call `ProcessStation.collect_into` / `take_back_into` with one `p.toast` per item id. `StationCraft._on_menu_action` sends both menu verbs to `player.actions.call(action_id, st)`. It uses `call()` because the methods arrive with the hooks patch: a typed call would not compile on the branch alone | `ok online: collect and take back queue ["act.collect", "act.take_back"] and leave the bag and the pot as they are (ready 1, jobs 2)`; `ok COLLECT from the station menu goes through PlayerActions: 1 camp stew in the bag` | online branch removed: `FAIL online: collect and take back queue [] and leave the bag and the pot as they are (ready 0, jobs 2)` |
| **Major**: the craft card showed recipes.json's 8.0s for Dry Meat at the rack (600 s real), the same at the smoker, pot and steamer | `Crafting.preview_time(rec)`: processing.json's job time when the recipe runs on a process station, otherwise `recipe_seconds`. A minute or more is shown as m:ss (`10:00`), less as `8.0s`. `recipe_seconds` is unchanged (XP = 6 + seconds). Hooks patch: `craft_ui.gd` (row meta and detail title) and `station_radial.gd` use it | `ok the drying rack's craft card shows 10:00, not 8.0s (["Lv. — · 10:00  ·  Missing items", "Lv. 7 · 10:00  ·  No station"] \| ["Dried Hide\nLv. — · 10:00    ×1"])`; `ok steam 1:00, stew 3:00; recipe_seconds (XP) unchanged`. Shot `rack50sheet_844`: "Craft · Meat dryer", both rows and the detail read `10:00` | old `craft_ui.gd` meta line: `FAIL the drying rack's craft card shows 10:00, not 8.0s (["Lv. — · 4.0s  ·  Missing items", "Lv. — · 8.0s  ·  Missing items"] ...)` |
| **Major**: two-line chips in a dense row hung over the neighbour stations at 844x390 (the reviewer's `all50_844_glc`, `rack100menu_844_glc`) | Measured first. In the lab row, station anchors are 34-38 px apart vertically. A two-line chip is 42 px tall (46 with its 2 px margin), so it cannot sit at its anchor without covering the next one; a one-line chip (22 px) can. The root cause was a cascade: the rack's chip, placed first, grazed the survivor's figure rect by 2 px, moved a full row up, and pushed every later chip up. Hooks patch on `hud_pills.gd`: (1) a working station's status **replaces** its name on one line (`Drying 4/4 · 4:54`, `2 ready · Drying 4:54`, `Ready: 4 Dried Meat`). (2) Before the shared layout runs, a status chip that is blocked steps sideways, only as far as its anchor stays under it (`w/2 - 12`), then tries hanging just under its anchor, then one row up. (3) If none of these is free, it falls back to the shorter name chip; if that does not fit either, no chip is drawn. HudPills' own header already says a label with no free spot near its anchor is not drawn. Lab check (process_lab `_check_labels`): every chip within `NEAR_PX` = 30 px of its own station's anchor, and no other station's anchor nearer | 844x390 glc: `PASS shot all 50%: 4 chips, 0 overlaps (chip on chip or on the survivor), 0 station world labels, 0 chips off their station []`; same line for `smoker 50%`, `rack 100%` with the menu open, `crock_pot 50%` with the menu open, and every 1600x900 view. t_process: `ok a chip grazing the survivor steps sideways, its station still under it (anchor (412.0, 200.0))`, `ok a chip with a panel above its station hangs under its anchor ((400.0, 226.0))`, `ok a chip with no free spot by its station says so ...` | the r1 two-line chip under the new check: `FAIL shot all 50%: 4 chips, 0 overlaps ..., 4 chips off their station ["drying_rack 46px (nearer another)", "crock_pot 40px (nearer another)", "steamer 171px (nearer another)", "smoker 50px"]` (the reviewer's picture, reproduced in `r1chip_all50_844`). One line without the step: `FAIL ... 3 chips off their station ["drying_rack 26px (nearer another)", "crock_pot 26px (nearer another)", "steamer 105px"]`. Step removed in t_process: `FAIL a chip grazing the survivor steps sideways ... (anchor (400.0, 200.0))` |
| **Major (acceptance)**: stages visible in game for every station; honest preview | Preview: row 2. Stages: the smoker, crock pot and steamer have no stage models, so `processing.json` `contents` puts the things on them. New `ProcessFx` (split out of ProcessStation, so that file did not grow) places one mesh per job or uncollected output at `spots[i]` and colours it `from` -> `to` with that job's progress. **Smoker:** 4 meat strips in the open doorway, red to dark smoked brown. **Crock pot:** bowls on the lit side of the stone ring, pink raw mix to dark stew; waiting stews show as raw bowls. **Steamer:** bowls, pink to pale steamed. All of them stay at the done colour until COLLECT; an empty station shows none. With smoke/steam/glow while a job runs, each station has an empty, a working and a done look | windowed shots below (`pot0_1600` vs `pot100_1600`, `smoker0/100_1600`, `steamer100_1600`, `fwd_all50_1600`) | before: `before_crock_pot50_1600`, `before_smoker50_1600` (no contents; the done station looks like the empty one apart from its chip) |
| Minor: strips | Kept the REPLACE row and updated it. `ProcessFx.show_strips` shows `strip_1..N` in proportion to the filled slots as soon as a stage GLB has those nodes | `ok one strip loaded shows 2 of the model's 8 strips (2)` (stand-in Prop with 8 `strip_N` nodes) | ignored: `FAIL one strip loaded shows 2 of the model's 8 strips (8)` |
| Minor: no cancel | `ProcessStation.take_back_into(inv)`: jobs still waiting for a slot hand their own inputs back, the same instances. All or nothing on the bag (`BuildPlacer.fits_in_bag`). The station menu shows a **TAKE BACK N** hex (icon: the waiting input) and routes it through `PlayerActions.take_back`. A running job is not cancelled. The steamer's default pick is left to W2-INV/W2-CRAFT ordering, and TAKE BACK is the way out of a wrong pick | `ok take back into a full bag moves nothing, the job keeps waiting`; `ok offline take back: the waiting job's own meat (uid l17d5c53c0787698a) and its herb and berry are back, the running job stays`; shot `pot50menu_844` (TAKE BACK 2 beside CRAFT) | `return 0`: `FAIL offline take back: the waiting job's own meat ...` |
| Minor: faint smoker plume on gl_compatibility | `fx_glc_boost: 1.6` on the smoker, read on gl_compatibility only: puffs 1.6x bigger and denser, a 1.6x shorter life so the plume stays by the roof instead of rising behind the phone's Orders panel, and the mid grey instead of the lightened one (light grey vanished on the pale grass). Forward+ is unchanged | crops `crop_before_smoker50_844` vs `crop_i_smoker50_844`: a wisp behind the panel before, a grey column over the roof after; `smoker50_844`, `all50_1600` | - |
| Minor: a saved job on a kind processing.json dropped stuck forever | `ProcessStation.attach_to(host, sid, saved)`: a CraftStation whose save carries jobs gets a ProcessStation even with no rules row. `load_dict` turns its jobs into collectable outputs, so COLLECT works and pack-up follows. **Found on the way:** collecting such a handed-back input (recipe "") paid craft XP and the 25 XP discovery bonus. Those rows now pay nothing | `ok a workbench row with a saved job: COLLECT gives the raw meat back, then it packs up ('collect the workbench first')`; `ok an input handed back pays no craft XP (1001036 -> 1001036)` | no attach: `FAIL a workbench row with a saved job ...`; XP: `FAIL an input handed back pays no craft XP (1001036 -> 1101068)` |
| Minor: per-kind cap hid a third rack's status | A chip with a process status skips the two-per-name cap (hooks patch). process_lab `--extra-racks=N` hangs meat on N more racks, and the label check counts their chips | `PASS shot rack 50%: 5 chips, ... 0 chips off their station [], 3 of 3 working racks with a chip` (`racks3_1600`) | cap restored: `FAIL shot rack 50%: 4 chips, ..., 2 of 3 working racks with a chip` |
| Minor: `SaveSanitizer._num/_int` called from another class | A local `ProcessStation._num` (same clamp: a non-number or NaN gives the fallback). `SaveSanitizer.MAX_LEVEL` (a public const) is still the level ceiling | the round 6 hostile-row checks still pass in t_process and run_all | - |

New assumptions (data, `processing.json` `_about`): the content spots and colours (placed by eye on the
W1-STRUCTART models, above the 0.08 m dirt patch) and `fx_glc_boost` 1.6. In code: `NEAR_PX` 30 (one name-chip
row) in the lab, the sideways step limit `w/2 - 12` in HudPills, and TAKE BACK taking all waiting jobs at once.

Shots for round 7, all opened and looked at. gl_compatibility unless named `fwd_`, the hooks patch applied; files in
`/private/tmp/claude-501/-Users-milankinzy-Documents-deadfront-siege/72cebc8b-d241-430b-9ea6-94d65339bfef/scratchpad/r7/final/`
(before shots and crops one level up):
- **844x390 (phone, landscape):**
  - `all50_844`: the four stations each carry their own one-line status over them (`Steaming 2/4 · 0:24`,
    `Stewing 3/4 · 1:24`, `Drying 4/4 · 4:54`, `Smoking 3/4 · 7:24`). The reviewer's picture had every chip one
    station off; it is reproduced in `r1chip_all50_844` with the r1 chip.
  - `smoker50_844`: `Drying` hangs just under the rack's anchor, off the vitals panel, and `Smoking` sits over
    the smoker. A grey plume shows over the roof (the round 6 `before_smoker50_844` had a wisp behind the Orders panel).
  - `rack100menu_844`: COLLECT 4 and CRAFT around the rack. The rack's own chip is left out: the survivor stands
    in front of it and its menu is open. `Ready: 3 Camp Stew` is on the crock pot and `Ready: 3 Smoked...` on
    the smoker. The reviewer's version had the rack's chip on the smoker and no crock pot chip.
  - `pot50menu_844`: TAKE BACK 2 (the waiting stews) beside CRAFT. Pink raw bowls by the pot. The steamer is
    wedged between the vitals and Orders panels, so it falls back to its `Steamer` name chip.
  - `rack50sheet_844`: "Craft · Meat dryer", Dried Hide and Dried Meat both `Lv. — · 10:00`, and the detail
    `Lv. — · 10:00 ×1`. (A shot file name containing "craft" makes craft_ui open its Bonfire tab, its own shot
    hook, so this one is named `sheet`.)
- **1600x900:**
  - `rack0/50/100_1600`, `pot0/100_1600`, `smoker0/100_1600`, `steamer100_1600`, `all50_1600`:
    - Rack strips go bright red, then maroon, then frame brown (the registered REPLACE).
    - Crock pot bowls go pink to dark brown; its waiting stews stay pink.
    - Steamer bowls go pink to white.
    - Smoker strips in the doorway go red to dark brown, under a grey plume.
    - At 100 % every plume and glow is off and the outputs stay on the station until COLLECT.
  - `racks3_1600`: three working racks, three chips (the farthest faded by the usual 5.5-8 m fade).
  - `fwd_all50_1600` (Forward+): the same contents, white smoke, chips on their stations.
- **Seen, not fixed:**
  - Long ready names are cut at the chip's 140 px text width (`Ready: 2 Steamed...`, `Ready: 3 Smoked...`).
    `UiTokens.LABEL_MAX_W` is W1-UI's.
  - The rack's dried strips still read close to the frame wood: the registered W1-STRUCTART REPLACE.
  - The COLLECT caption touches the smoker's roof in `rack100menu_844`: the StationMenu caption, W1-UI (seen
    in round 6 too).

Round 7 gates (scratch tree `trees/w2proc-gates7` at add208b3 with the hooks patch applied, every Godot run under
gslot; logs in `scratchpad/r7/gates7/`):
- `--import`: exit 0, 0 ERROR lines (`trees/w2proc-gates7/.import.log`).
- All 20 `t_*.gd` exit 0, 0 SCRIPT ERROR except t_save's 5 deliberate ones: `[t_process] PASS`, `[t_build] PASS`,
  `[t_save] PASS`, `[t_ui] PASS`, `[t_web] PASS`, `[t_harbour] PASS islands=15`,
  `[t_uiicons] PASS ids=169 files=114 ...`, and the rest.
- `[tests] PASS` (run_all, which runs the process checks) and `SMOKE PASS` (`tools/smoke.sh --no-import`).
- `[process_lab] PASS`, `[kitchen_lab] PASS`, `[craft_lab] PASS` (headless), 0 SCRIPT ERROR lines each. All 16
  windowed process_lab runs of this round end in `[process_lab] PASS shot ...` with 0 SCRIPT ERROR.
- 0 "couldn't resolve track" lines in any gate log.
- No new `Godot-*.ips` in `~/Library/Logs/DiagnosticReports` during the round (the newest is
  `Godot-2026-10-20-202004.ips`, from before it began).
- Hooks patch: `git apply --check` clean on claude/mmo-overhaul cecc936b (fresh detached tree). The six files it
  touches are byte-identical on the base and on this branch, and the gate tree applied it cleanly.

## Round 6: review r1 findings (w2-process-review-r1.json)

The reviewer was right on every finding. The round 4 claim "the first job takes exactly the picks the card
showed" held for `ProcessStation.load_from`, but the game path re-picked on arrival, so it was false in game.

| Finding | Fix | Proof (new code) | Old code / mutation |
|---|---|---|---|
| **Major**: `_start_craft_cycle` recomputed `_picks` on arrival, so a bag change on the way put a different instance on the station (vision fix 1, spec 08:98 "consumes *specific instance IDs*") | `StationCraft._begin_recipe` records the uid of each picked instance (`_pick_uids`). On arrival, `_load_process_station` maps each uid back to its current bag index and passes those to `refuse_reason`/`load_from`. A uid that left the bag gives index -1, which `refuse_reason` turns into "That one is no longer in your bag." (or "Needs ..." / "No processing left on that one."), shown as a notice. Nothing is substituted. Fungible stacks (no uid) keep the default pick. Queued repeats still auto-pick | `ok craft route: the rack takes the previewed instance after a bag sort (previewed l8c69b43deec199e4, took l8c69b43deec199e4)`; `ok craft route: a previewed instance gone on arrival is refused, lv 4 stays in the bag` (t_process, through `StationCraft.begin` and `_start_craft_cycle`, the reviewer's probe as a test) | `FAIL craft route: the rack takes the previewed instance after a bag sort (previewed ldb8cde7c25900ce9, took lf338ba7432f4d05c)`; `FAIL craft route: a previewed instance gone on arrival is refused, lv 31 stays in the bag` |
| **Major**: the `process` save field bypassed SaveSanitizer: 1e9 units at lv 5e6, a `started: [1,2]` aborted `load_dict` and lost the meat, `started: "abc"` finished at once, a duplicated uid loaded twice, no level ceiling | Inside `process_station.gd`, so both the load path (`load_dict`) and the refund path (`saved_stacks`, used by the hooks patch's `SaveRestore._items_of`) get it: every stack goes through `SaveSanitizer.stacks` (known id, count <= `stack_max`, level <= 60, attribute shapes), a uid already seen on the station is dropped, `started`/`queued_at` go through `SaveSanitizer._num` (clamped to now; not a number = the job waits and restarts, never finishes early), `level` through `SaveSanitizer._int(1, 60)`, `burnt` must be a bool, and `jobs`/`outputs`/`inputs` that are not arrays load nothing instead of aborting | `ok a forged 1e9 x lv 5e6 output loads as one stack of <= 999 at lv <= 60 (... "units": 999, "left": 0)`; `ok a forged job level is clamped to 60`; `ok a string start restarts the job, it does not finish it`; `ok array numbers do not abort the load: the meat stays on the rack (... "jobs": 1, "refund": 1 ...)`; `ok jobs/outputs that are not arrays load nothing and do not abort`; `ok a uid on two outputs loads once` | `FAIL a forged 1e9 x lv 5e6 output ... ("units": 39960, "left": 999960040, "level": 5000000)`; `SCRIPT ERROR: Invalid call. Nonexistent 'float' constructor.` then `FAIL array numbers do not abort the load ... ("jobs": 0)`; `FAIL a string start restarts the job ... ("jobs": 0, "ready": 1)`; `FAIL a uid on two outputs loads once (... "units": 2)`; `FAIL a forged job level is clamped to 60 (... 9999999)` |
| **Major**: status labels unreadable at 844x390 and on the judge renderer (over the survivor's chip, under the vitals panel, under the wrong chip, under the CRAFT hex) | The reviewer's first suggestion. The world `Label3D` is deleted from `ProcessStation`. `label_text()` is now the second line of the station's own HUD chip (hooks patch on W1-UI's `hud_pills.gd`, the line a depleted harvest node uses for its regrow timer). `UiTokens.layout_labels` places that chip off the HUD panels, every hex and caption, the other chips and the survivor, so a status can only sit under its own station's name | windowed `process_lab` check, glc: `PASS shot all 50%: 4 chips, 0 overlaps (chip on chip or on the survivor), 0 station world labels` at 844x390 and 1600x900; same for smoker 50 (2 chips), rack 50 (2 / 3 chips), rack 100 with the menu open (2 chips), rack 100 at 1600 (3 chips). Headless `process_lab`: `PASS survivor at the loaded rack: 0 chips, 0 overlaps ..., 0 station world labels` (headless draws no HUD, so only the world-text part applies there) | old Label3D code with the new lab: `FAIL survivor at the loaded rack: 0 chips, 0 overlaps (chip on chip or on the survivor), 4 station world labels` |
| Minor: no test for the future-start clamp (M7 passed) | `process_checks.gd`: a row with `started = now + 3600` | `ok a start an hour in the future loads as now, label time <= job length (... "label": "Drying 1/4  ·  10:00" ..., 600s)` | M7 (upper bound `INF` instead of now): `FAIL a start an hour in the future loads as now, label time <= job length (... "started": 1792548512.07741 ...)` |
| Minor: the dried stage reads as empty wood; one mesh shows a full rack for any count | Not fixable in engine: each stage GLB is one mesh with one `structures_atlas` material (checked in the GLB JSON: 1 node, 1 primitive, attributes POSITION/NORMAL/TEXCOORD_0), so a material tint would darken the frame too, and there are no per-strip nodes to hide. The fallback the reviewer named: the shared W1-STRUCTART + W2-PROCESS row in `asset-replacement.md` now asks for a darker meat-brown strip tile and `strip_1`..`strip_8` nodes, marked REPLACE | 8fd3e3f6 | - |
| Minor: t_process not in run_all | Hooks patch: `run_all.gd` gets `_test_process_stations()`, which runs `res://tests/process_checks.gd` (the multistack_lab pattern: a RefCounted with `run()` returning label -> bool). t_process runs the same file | see gates | - |
| Acceptance unmet: vision fix 1 through `StationCraft.begin` | Met (row 1) | `ok craft route: the rack takes the previewed instance after a bag sort (previewed l8c69b43deec199e4, took l8c69b43deec199e4)` | the reviewer's `SUBSTITUTED` probe, now a test |

Not a bug, but worth knowing: the sanitizer caps count at the item's `stack_max`, which is 999 for every item
in this build (owner rule, `item_def.gd:42` "everything stacks to 999 until per-item stack sizes are decided").
A forged process row can therefore carry 999 units, the same as a forged bag row in the same save; it can no
longer carry more, or a level above 60. A duplicated uid is caught within one station; across containers
(station vs bag) it is the save layer's job (W1-SAVE), as for bag-vs-cargo duplicates today.

Shots, all opened and looked at
(`/private/tmp/claude-501/-Users-milankinzy-Documents-deadfront-siege/72cebc8b-d241-430b-9ea6-94d65339bfef/scratchpad/shots_r6/`,
gl_compatibility, the hooks patch applied):
- `all50_844`: four chips, each `Name` over its own `Drying 4/4 · 4:54` / `Stewing 1/4 · 1:24` /
  `Steaming 2/4 · 0:24` / `Smoking 3/4 · 7:24` line. Nothing on the survivor, the vitals panel or the orders card.
- `smoker50_844`, `rack50_844`: the rack and smoker chips beside their models, the survivor's name clear.
- `menu100_844`: the COLLECT and CRAFT hexes are clear of `Ready: 4 Dried Meat` and `Ready: 3 Smoked Meat`.
- `all50_1600`, `rack50_1600`, `smoker50_1600`, `rack100_1600`: each chip over its own station, statuses
  readable, the survivor clear.
- **Seen, not fixed:**
  - In `all50_844` (the lab's dense row: four stations within 3 m of each other and the survivor) the drying
    rack's chip, placed first, touched the survivor's figure rect by 3 px. HudPills moved it one row up, and the
    crock pot chip then moved right, so the Drying Rack chip sits by the steamer and the Steamer chip by the
    rack. Every status is still under its own name. The reviewer's before shot shows the same W1-UI layout
    rule (its Steamer chip was pushed to the orders card). A sideways nudge in `UiTokens.layout_labels` would
    fix it for every chip; that is W1-UI's file and behaviour, so it is not in this patch.
  - The COLLECT caption runs onto the smoker's roof. That is the StationMenu hex caption (W1-UI).

Round 6 gates (scratch tree `trees/w2proc-gates` at 76875ea4 with the regenerated hooks patch applied, every
Godot run under gslot, logs in `scratchpad/w2proc-gatelogs6/`):
- `--import`: exit 0, 0 ERROR lines.
- All 20 `t_*.gd` PASS, exit 0, 0 SCRIPT ERROR except t_save's 5 deliberate ones: `[t_process] PASS`,
  `[t_build] PASS`, `[t_save] PASS`, `[t_ui] PASS`, `[t_uiicons] PASS ids=169 ...`, `[t_harbour] PASS islands=15`,
  `[t_web] PASS`, and the rest.
- `[tests] PASS` (run_all, now with the process checks) and `SMOKE PASS` (`tools/smoke.sh --no-import`).
- `[process_lab] PASS`, `[kitchen_lab] PASS`, `[craft_lab] PASS`, 0 SCRIPT ERROR lines each.
- 0 "couldn't resolve track" lines in any log.
- Crash reports: 5 new `Godot-*.ips` appeared during the gate window (`Godot-2026-10-20-201057`, `-201134`,
  `-201146`, `-201353`, `-201403`; a sixth, `-201415`, came after my last run ended at 20:14:04). None is
  from my runs: every one of my Godot runs exited 0 (gslot passes the exit code through; a SIGABRT does not
  exit 0). All are the same SIGABRT in `std::__throw_system_error` on the main thread, about 10 s after launch,
  which is the lifetime of a windowed `--shot-delay=6` run. Other agents were running windowed shot labs
  then (`market_ui_lab`, `r3_skills_lab`, `ui_real_capture_lab`, `bag_ui_lab`, `inventory_lab`). The same crash
  also shows at 19:55:03 and 19:56:19, before this round's runs. My 8 windowed shots (20:08-20:09) left none,
  and rerunning `--import` alone (20:15:29-20:15:35) left none.
- Hooks patch: `git apply --check` clean on claude/mmo-overhaul 34b6d459 (fresh detached worktree).

## Round 5: resumed run (review r1 and the vision fixes, checked against the real branch state)

Rounds 3 and 4 had already built every item of this task. git log and the code show it, so this round
checked each item against the current base and the W2-BUILDSYS tip, redid the gates and the shots, and fixed
what that turned up.

| Task item | State on the branch | This round |
|---|---|---|
| Blocker: shift-tap pack-up destroys station contents | `CraftStation.pack_up_block_reason()` -> `ProcessStation.pack_up_block_reason()`. It refuses while any input, output or job (running or waiting) is on the station, with "the drying rack is still working: collect it when it is ready" / "collect the drying rack first", shown as "Can't pack up: ...". `BuildPlacer.pack_up_node` asks `pack_up_blocker` -> `pack_up_block_reason()` duck-typed before any side effect (base build_placer.gd:176 -> :209; W2-BUILDSYS 4b8c6d23 :265 -> :302), and every pack-up path goes through `pack_up_node`. So the "duck-typed check in pack_up_node" already exists on the base, and the hooks patch needs no `build_placer.gd` or `player_actions.gd` change | rechecked, gates rerun |
| Major: a refused pack-up must not cancel jobs or move items | The station rule is a pure check that runs first. No `return_all` remains | `ok a refused pack-up cancels no job and moves nothing (jobs 2)` |
| Major: slow stations strictly worse than the grill | Cooking properties from spec 08 §2/§4, 11 §1 and 04 (round 3 table below; the cited lines were rechecked: 08:37, 08:43, 08:78, 08:98, 11:138, 11:155, 10:102) | `meal: grilled e=32.7 rel=12.3 \| dried e=23.2 rel=20.7 \| smoked e=31.4 rel=17.8 buffs=[&"cold_resist"] \| stew e=43.6 rel=16.4 \| grilled+steam e=41.2 rel=15.5` |
| Vision (1) exact picks, spec 08:98 | Built in round 4 | rechecked, gates rerun |
| Vision (2) a destroyed station keeps its contents, spec 11:155 / 10:102 | Round 4 gave stations `salvage_contents()` **and** a `destroyed` listener that sent the contents to camp cargo or `pending_refunds`. W2-BUILDSYS 4b8c6d23 now calls `host.salvage_contents()` itself after `destroyed.emit` and drops the stacks into the bag, home cargo, then a loot bag (structure_health.gd:120). With both in place, the listener ran first and took everything, so BUILDSYS's visible loot bag never got the items, which instead waited in `pending_refunds` until the next load. **619c3b0a deletes the listener**; `salvage_contents()` stays as the duck-typed hook. Before BUILDSYS merges nothing can destroy a station, so there is no gap | below |

Proof for vision (2):
- t_process now asks the station the way BUILDSYS does (`has_method("salvage_contents")`):
  `ok a destroyed rack hands over its dried meat (same uid), the drying hide and the drying meat (["dried_meat", "raw_hide", "raw_meat"])`,
  `ok nothing stays on the station, a second salvage hands over nothing`.
- Mutation (method renamed): `[t_process] FAIL a destroyed rack hands over its dried meat (same uid), the drying hide and the drying meat ([])`.
- **On a merged tree** (619c3b0a + claude/mmo-w2-buildsys 4b8c6d23 + both hooks patches, imported, throwaway
  script; the rack is killed through `StructureHealth.of(rack, true).take_damage(1e6)`):
  `[x_proc_bs] ok cargo room 8: the destroyed rack's dried meat (same uid) and drying hide are in cargo or a loot bag (["dried_meat", "raw_hide"])`,
  `[struct] loot bag at (0.0, 0.0, 0.0) holds 1 stacks`,
  `[x_proc_bs] ok cargo room 1: ... (["dried_meat", "raw_hide"])`, `[x_proc_bs] PASS`.
  Found on the way: a `--script` test that names `LootBag` at parse time breaks `LootBag.drop` (the World autoload
  does not exist yet) and loses the stack. That is a harness artefact; in game the autoloads exist.

Break tests asked for, all in t_process:
- pack-up while running: `ok shift-tap pack-up refuses a working rack and touches nothing: 'the drying rack is still working: collect it when it is ready'`
- pack-up while loaded: `ok a rack with dried meat waiting refuses: 'collect the drying rack first'`
- pack-up when empty: `ok an empty rack packs up: kit and both dried meats in the bag`
- save/load mid-job: `ok reload mid-process resumes with 300s left (was 300s)`, `ok reload mid-job: 2 running, the third still waiting (2/3)`
- collect into a full bag: `ok full bag: nothing moves, 4 stay on the rack (ready 4)`, then `ok with room: all 4 dried meat collect, the rack is empty`
- two jobs at once: `ok meat and hide hang on the rack at once`, `ok collect moves both and names each ({ &"dried_meat": 1, &"dried_hide": 1 })`

**Smoke on the judge renderer (ffc3833f).** The round 5 shots showed what round 4 missed. On
gl_compatibility the rack's smoke did not show on the dirt patch, and the smoker's was a thin dark thread.
Forward+ showed white wisps from both. On gl_compatibility only, the smoke colour now goes through
`linear_to_srgb()` and its alpha is x1.5. Looked at: crops of the rack at 50 % before and after; the rack and
smoker now show grey puffs, and Forward+ is unchanged.

**A label move, tried and reverted (19fbb83b, 3f5835cb).** When the survivor stands in front of a station, its
name chip sits on the station's label. I hung the label just in front of the survivor instead. In the rack
view that put it on the smoker's label (`Drying 4/4 · 4:54Smoking 3/4 · 7:24`), which reads worse than the
chip overlap. I reverted it, so the round 4 placement stands. The fix needs a screen-space layout pass for
world labels, which is HUD work.

Round 5 gates (scratch tree `trees/w2proc-gates` at ffc3833f with the hooks patch applied, every Godot run under
gslot):
- `--import`: 0 ERROR lines.
- All 20 `t_*.gd` PASS: `[t_process] PASS`, `[t_build] PASS`, `[t_save] PASS` (its 5 deliberate SCRIPT ERRORs only),
  `[t_uiicons] PASS ids=169 ...`, `[t_web] PASS`, `[t_harbour] PASS islands=15`, and the rest. 0 SCRIPT ERROR
  in all the others.
- `[tests] PASS` (run_all) and `SMOKE PASS` (`tools/smoke.sh --no-import`).
- `[process_lab] PASS`, `[kitchen_lab] PASS`, `[craft_lab] PASS`, 0 SCRIPT ERROR lines each.
- 0 "couldn't resolve track" lines in any log; no new `Godot-*.ips`.
- The branch alone (no hooks patch) fails one line, by design: `FAIL a refunded rack row returns its kit and the 2 meats on it (cargo meat 0)`.
  It needs W1-SAVE's `save_restore.gd` change in the hooks patch.
- Hooks patch: regenerated from the gate tree; the bytes are identical to the committed patch, and
  `git apply --check` is clean on claude/mmo-overhaul 34b6d459.

Round 5 shots, 844x390 landscape, `process_lab --proc=0|50|100 --proc-view=rack|smoker|crock_pot|steamer`. All
24 were opened and looked at
(`/private/tmp/claude-501/-Users-milankinzy-Documents-deadfront-siege/72cebc8b-d241-430b-9ea6-94d65339bfef/scratchpad/shots_proc5/`,
`glc_*` at ffc3833f; `fwd_*` at 619c3b0a, whose Forward+ path is unchanged):
- **Rack:** the strips are bright red at 0 %, maroon at 50 % and dark brown at 100 %. Smoke shows at 0 and
  50 % and stops at 100 %. The label goes from `Drying 4/4 · 9:54` to `Drying 4/4 · 4:54` to
  `Ready: 4 Dried Meat`.
- **Smoker:** a plume over the roof at 0 and 50 %, none at 100 %; the label ends at `Ready: 3 Smoked Meat`.
- **Crock pot:** an orange glow and steam while it stews; at 100 % the glow is gone and the label reads `Ready: 1 Camp Stew`.
- **Steamer:** a white steam plume at 0 and 50 %; at 100 % the label reads `Ready: 2 Steamed Dish`.
- **Both renderers:** the same stages. On gl_compatibility the smoke is lighter and thinner than on Forward+.
- **Seen, not fixed:**
  - The lab puts the survivor at the camera-side corner of the station it frames, so that station's label
    runs under the white `Survivor` chip. The label stays readable in the steamer view and partly in the
    others.
  - The steamer sits under the vitals panel in the rack and smoker views.

## Round 4: vision-check fixes (docs/orchestration/mmo/vision-check.md)

The owner judged the full vision audit too exhaustive and it was stopped early (vision-check.md, first
paragraph). Two of its reader findings are for this package. Both cited lines say what the finding claims, and
both fixes are small, so both are built:

| Fix | Cited line (checked) | What changed | Proof |
|---|---|---|---|
| A station uses the instances the player picked | Spec 08:98: "A multi-material recipe consumes *specific instance IDs* atomically" (and 08:98 "Support a material-preview before committing a food process") | `ProcessStation.load_from(..., picks)`: the first job takes exactly the bag picks the craft card showed, or nothing. There is no substitute. `refuse_reason` names why ("No processing left on that one." / "That one is no longer in your bag."), and `StationCraft` shows it as a notice. Queued repeats auto-pick with `Crafting.default_picks`, which now does the spent-primary swap that `ProcessStation._picks` used to do, so the card previews the instance the station really takes. `_picks` is deleted | `ok the rack takes the picked lv 31 meat, not the default lv 9`; `ok a spent pick is refused, the other meat is not substituted: 'No processing left on that one.'`; `ok a pick that left the bag is refused`; `ok a batch takes the pick first, then auto-picks the repeat` |
| A destroyed station never deletes its contents | Spec 10:102: "A change in building state must not silently delete stored items." Spec 11:155: "Handle demolished stations, cancellations, full output containers and server restarts without losing items or duplicating output." | `CraftStation.salvage_contents()` / `ProcessStation.salvage_contents()` hand over and clear the inputs, outputs and waiting jobs. **Superseded in round 5:** the `destroyed` listener that sent them to camp cargo is gone, because W2-BUILDSYS's `StructureHealth` now calls `salvage_contents()` itself | round 5 proof below |
| Found on the way: a saved station row the grid refuses on load lost its jobs | Same spec 11:155 ("server restarts") | Hooks patch: `SaveRestore._items_of` also returns `ProcessStation.saved_stacks(row.process)`, so a refunded rack row gives back its kit and the meat on it | `ok a refunded rack row returns its kit and the 2 meats on it (cargo meat 2)` (with the hooks patch) |

Mutation run (picks ignored, the `destroyed` connect removed, the base `save_restore.gd`):
```
[t_process] FAIL the rack takes the picked lv 31 meat, not the default lv 9
[t_process] FAIL a spent pick is refused, the other meat is not substituted: 'No processing left on that one.'
[t_process] FAIL a batch takes the pick first, then auto-picks the repeat
[t_process] FAIL a destroyed rack's dried meat (same uid) and drying hide go to camp cargo
[t_process] FAIL cargo full: the contents wait in pending_refunds (0 rows)
[t_process] FAIL with room, the next load's retry hands both over
[t_process] FAIL a refunded rack row returns its kit and the 2 meats on it (cargo meat 0)
```

Limits (shortcuts):
- **Superseded in round 6:** the craft route re-picked on arrival, so this table's first row held for
  `load_from` but not in game. The picks are now kept as uids and mapped back on arrival.
- The picks come from the same default order the card previews. There is no per-slot picker yet; that is W2-CRAFT ("family slots filled by exact picked instances",
  vision-check.md next packages #1).
- "Least valuable first" for repeats is W2-INV's change to the default order. This package uses
  `Crafting.default_picks` and adds no ordering of its own.
- The destroyed path was checked by reading W2-BUILDSYS 58c3a87d (`signal destroyed(source)`, emitted before
  `host.queue_free()`, child named `StructureHealth`). The test uses a stand-in node with the same signal, not
  a merged tree.

Round 4 gates (scratch tree at 6a385058 with the hooks patch applied, every Godot run under gslot):
- `--import`: 0 errors in the log.
- All 20 `t_*.gd` PASS, e.g. `[t_process] PASS`, `[t_build] PASS`, `[t_save] PASS` (its 5 deliberate SCRIPT
  ERRORs only), `[t_uiicons] PASS ids=169`, `[t_web] PASS`. t_lighting prints `[t_light] PASS`.
- `[tests] PASS` (run_all), `SMOKE PASS` (`tools/smoke.sh --no-import`).
- `[process_lab] PASS`, `[kitchen_lab] PASS`, `[craft_lab] PASS`, 0 SCRIPT ERROR lines each.
- 0 "couldn't resolve track" lines; no new `Godot-*.ips` in DiagnosticReports.

Round 4 shots, 844x390 (phone, landscape), all opened and looked at
(`/private/tmp/claude-501/-Users-milankinzy-Documents-deadfront-siege/72cebc8b-d241-430b-9ea6-94d65339bfef/scratchpad/shots_proc/`):
- **gl_compatibility (the judge):**
  - `glc_rack_{0,50,100}`: the strips go bright red, then maroon, then dark brown. Smoke rises from the
    rack and the smoker until 100 %; at 100 % the smoke stops and every label reads `Ready: ...`.
  - `glc_{smoker,crock_pot,steamer}_50`: the smoker and steamer give off their puffs and the crock pot glows.
    Each label hangs under its station.
  - `glc_all_100`: every station is done.
- **Forward+:** `fwd_rack_50` and `fwd_all_50` look the same as glc.
- **Seen and not fixed:**
  - The label at the camera-side corner sits on the survivor's name chip when the survivor stands at that
    corner. It stays readable.
  - In the lab row (stations about 3 m apart) the steamer's name chip touches the orders panel.

## Round 3: review r1 fixes

| r1 finding | Fix | Proof |
|---|---|---|
| **Blocker**: shift-tap pack-up (`player_actions.gd:568` -> `BuildPlacer.pack_up_node`) destroyed what was on the station | `CraftStation.pack_up_block_reason()` -> `ProcessStation.pack_up_block_reason()`: refuses while any job (running or waiting) or uncollected output is on the station ("the drying rack is still working: collect it when it is ready" / "collect the drying rack first"). `BuildPlacer.pack_up_blocker` already calls `pack_up_block_reason` duck-typed before any side effect, and every pack-up path (shift-tap, `CraftStation.pack_up`, t_build) goes through `pack_up_node` -> `pack_up_blocker`. W2-BUILDSYS's `build_placer.gd` keeps the same call (line 302 on 58c3a87d), so **no hooks patch is needed** | `[t_process] ok shift-tap pack-up refuses a working rack and touches nothing: 'the drying rack is still working: collect it when it is ready'`; `ok a rack with dried meat waiting refuses: 'collect the drying rack first'`; `ok an empty rack packs up: kit and both dried meats in the bag`; `[process_lab] PASS shift-tap pack-up refuses a loaded rack` |
| **Major**: a refused pack-up had already cancelled the jobs (`return_all` ran before `pack_up_node`'s own checks) | `return_all` and the `CraftStation.pack_up` override are gone; the station's rule is a pure check that runs first, so a refusal changes nothing | `ok a refused pack-up cancels no job and moves nothing (jobs 2)` (bag with room for the meat but not the kit: the r1 scenario) |
| **Major**: slow stations strictly worse than the grill | Cooking properties, from spec 08/11/04 (next section) | `ok drying: dried meat eases more fatigue than grilled (20.7 vs 12.3)` and the table below |
| Minor: no test that a uid exists once after collect | Added | `ok after collect each uid exists once (bag 2, station 0, save row false)` |
| Minor: clock moved back could show a timer above the job length | `label_text` clamps the remaining time to the job length (`load_dict` already clamps a future start) | read in code |
| Minor: COLLECT toast showed mixed outputs as one item | `collect_into` records `last_collected` per item id; the toast shows each | `ok collect moves both and names each ({ &"dried_meat": 1, &"dried_hide": 1 })` |

Found while testing: an in-place output took the skill-capped crafted level, so a lv 31 meat dried by a
Processing 1 survivor came off the rack at lv 1 (and lost energy, which scales with level). Spec 11 §8: "For
in-place processing, use the existing item as the base; only change level when the actual process rules
require it." `Crafting.build_output` now keeps `primary.level` for in-place steps. Proof: with a survivor in
the test scene the old code printed `FAIL the same two instances came back, levels kept (... [1, 1])`; now
`ok ... levels kept (... [9, 31])`.

**Each new test fails on the old behaviour.** Mutation run (station rule removed, the old return-first
`pack_up` restored, the property rows deleted):
```
[t_process] FAIL drying: dried meat eases more fatigue than grilled (8.7 vs 12.3)
[t_process] FAIL smoking: more relief than grilled (11.8 vs 12.3) and a Warming Meal the grill does not give
[t_process] FAIL shift-tap pack-up refuses a working rack and touches nothing: ''
[t_process] FAIL a refused pack-up cancels no job and moves nothing (jobs 0)
[t_process] FAIL a rack with dried meat waiting refuses: ''
```

### What each slow station gives (spec answer, all values in `processing.json`)

What the specs say:
- Spec 08 §2: "in-place recipes add cooking properties, remove `raw_food` and `wet` tags when applicable, and
  generally consume a processing opportunity. Verify method-specific behavior rather than making every
  method identical."
- Spec 08 §4: "Food benefits may include immediate Energy, digestion-delayed Energy, fullness/satiety, Health,
  reduced Fatigue when supported, temporary stat/ability buffs, and environmental effects. Food benefits must
  be calculated from the actual prepared item's stored state."
- Spec 08 §1: no freshness/decay timer, so "keeps while raw spoils" is not available.
- Spec 11 §1: in-place modification changes one existing material's tags or attributes and spends
  processing opportunities.
- Spec 04: the effects are attributes of the instance.

The specs name the kinds of effect but not which method gives which, so the mapping is `# ASSUMPTION`.

What the game consumes decides the kind. Energy refills by itself out of combat (16/s, `vitals.gd`), so energy
alone does not reward a slow station. Fatigue is the session governor (PRD §6.4), and climate resistance already
cuts climate fatigue (`Player.climate_resistance`). The same PRD gives "Food does not restore Health".

| Station (time) | Mode | What the output carries | Effect when eaten |
|---|---|---|---|
| Drying rack (10 min) | in place, spends 1 of 2 | `Dried` (processing history `dry`) | eases fatigue 12, on top of the meal's own energy break |
| Smoker (15 min) | in place, spends 1 of 2 | `Smoked` (history `smoke`) | eases fatigue 6, plus the existing Warming Meal (`food_buffs.json` cold_resist +1 for 600 s). No food granted it before, so cold islands had no food answer |
| Steamer (1 min) | in place, spends 1 of 2 | process count +1 | +35 % energy per steam (PRD §9.3 "Dumping all process counts into steam explodes energy"), and so a bigger energy break. Its payoff is on cooked food |
| Crock pot (3 min) | new food from meat + herb + fruit | a new instance with fresh opportunities | 32 base energy, which can then be steamed twice |

Measured per raw meat at level 1 (`t_process`, on a real `Vitals` fed the way `EatSession` feeds it):
`grilled e=32.7 rel=12.3 | dried e=23.2 rel=20.7 | smoked e=31.4 rel=17.8 buffs=[&"cold_resist"] | stew e=43.6
rel=16.4 | grilled+steam e=41.2 rel=15.5` (e = energy, rel = fatigue eased, out of 100).

Against the grill, dried meat eases 1.7x the fatigue. Smoked meat eases 1.45x and adds cold resistance. The
stew eases 1.33x and starts fresh. Steaming a grilled meat adds +26 % energy.

How it works:
- `Food.cooking_properties(stack)` reads one `in_place.properties` row per step in the instance's
  `attributes.processed`.
- `Food.buff_ids` adds a row's `buff`. `EatSession._finish` applies `Food.fatigue_relief` through `Vitals.rest`.
- The food inspector shows `Dried: eases fatigue 12`.
- No new save field: the history was already saved, so old saves load unchanged.
- A dried meat made before this package has no history and no property (the effect comes from the stored
  state, not the name: `ok the effect comes from the stored history, not the item name`).
- A stew made from dried meat starts plain (spec 08 §3: recipes that do not inherit).
- Dried hide is not a meal. Its payoff is the hide -> dried hide -> straps route (PRD "Hide -> dried hide -> straps").

## Round 2: spec 08 corrections (coordinator, owner: "the docs decide")

| Round 1 (removed) | Spec 08 says | Now |
|---|---|---|
| Spoil timer: `ItemStack.spoil_at`, SPOILED, a stomachache on spoiled food, a spoil-time save field | Line 37: "Do not introduce a freshness/decay timer unless the existing game or verified design requires it; preserve a field only if used." | Removed. `food.gd` and `item_stack.gd` are byte-identical to base. No save field was added, so old saves load unchanged. Round 1's `spoil_at` was never merged anywhere, and an unknown key in a row is ignored anyway |
| Steam cap 3 (`attributes.steams`) | §1/§2: per-instance processing opportunities (default 2, "not a fully confirmed original server constant"). In-place methods spend one, remove `raw_food`/`wet`, and keep identity and properties | `processing.json` `in_place`: steps `dry`, `smoke` and `steam` are in place. The output keeps the input's uid, origin, creator, created_at, attributes and level, and loses the raw flag. The step is appended to `attributes.processed`, which is the instance's processing history and its spent count. At 2 spent, `Crafting.picks_valid` refuses and stations pick another instance. New-food recipes (sashimi, stew, ...) start with fresh opportunities. Steam spends one like any step: `# ASSUMPTION`, and the PRD's steam-steam question (§9.3, open question 13) stays open and configurable. kitchen_lab's sashimi-steam-steam still runs (2 steams on a fresh sashimi): `energy/piece=37.0 process=4 per_meat=110.9 vs skewer=30.0` |
| Invented Trail Ration / Smokehouse Ration buffs | §4/§7: effects come from the prepared item's stored state | Dropped. Dried and smoked meat carry no buff property, so they give none. Eating gives the stored item's own energy: `[process_lab] PASS the meal is the stored item's own 23.2 energy (eating 23.2)`, `PASS no invented buff: dried meat carries none ([])` |

The station clock moved from Food to `ProcessStation.now_s()` (plus `clock_skew_s` for labs and tests), and the
rules loader moved to `ProcessStation.rules()`.

## What shipped

- **`ProcessStation`** (`game/scripts/world/process_station.gd`, new). `CraftStation._ready` attaches it to every
  kind with a `processing.json` `stations` row:
  - drying rack: 4 slots (dry_meat, dried_hide)
  - smoker: 4 slots (smoke_meat)
  - crock pot: 1 slot + 3 queued (camp_stew)
  - steamer: 2 slots + 2 queued (steam)

  How it works:
  - Inputs leave the bag through `Crafting.consume_for_craft` (exact stacks) and sit on the station.
  - Jobs are timestamps on the wall clock. They finish with the player 50 m away, on another island, or with the
    game closed.
  - A queued job starts at the moment a slot frees, so an offline catch-up equals a watched run.
  - Outputs wait on the station until **COLLECT**, a new hex on the station menu. XP is paid once, when a job's
    output leaves the station.
  - The craft-sheet route walks to the station, hangs the inputs and frees the survivor.
  - The drying rack swaps W1-STRUCTART's empty/raw/drying/dried models from the progress of its least-advanced
    strip.
  - Smoke or steam comes from CPUParticles3D, so Forward+ and gl_compatibility look alike. Fired stations glow.
  - While anything is on the station, its HUD chip shows the status in place of the name, on one line:
    `Drying 4/4 · 4:58`, then `Ready: 4 Dried Meat` (round 7). Round 6 used a second line; until round 5 it was a
    world Label3D, which collided with the survivor and the HUD.
  - The smoker, crock pot and steamer show what is on them (`processing.json` `contents`): strips in the
    smoker's door and bowls by the pot and steamer, coloured by each job's progress (round 7).
  - COLLECT and TAKE BACK (waiting jobs only) are PlayerActions verbs (round 7).
  - Jobs are saved in the station's existing row (`"process"`); `SaveRestore.spawn` already calls
    `CraftStation.from_dict`, so no migration is needed.
  - On load, a start time in the future is clamped to now. Rows for recipes the station no longer runs come back
    as collectable items and are never deleted.
  - Pack-up is refused while anything is on the station (round 3), so it never destroys or cancels anything.

## Acceptance

| Check | Result |
|---|---|
| process_lab windowed: 4 raw strips pass through 3 stages over the configured time, smoke while active | Shots at 0, 50 and 100 % looked at: red, then maroon, then near-black. Smoke is on until 100 % |
| Save/reload mid-process resumes with the right remaining time | `[t_process] ok reload mid-process resumes with 300s left (was 300s)` (JSON through `SaveRestore.spawn`) |
| Queue keeps running with the player 50 m away | `[t_process] ok rack finished 4 on its own clock (ready 4)` (the station's own `_process`); `[process_lab] PASS finished with the survivor 50 m away (ready 4, dried)` |
| Raw meat spoils / dried meat keeps and carries its buff | **Superseded by spec 08**: there is no decay timer and no invented buff (see round 2). Dried meat records its step and is no longer raw: `PASS dried meat records the dry step and is no longer raw (["dry"])` |
| kitchen_lab and craft_lab PASS | `[kitchen_lab] PASS`, `[craft_lab] PASS` |

Spec 08 §9 tests that apply to stations:
- **Nonstacking and identical names:** `ok two identically named meats with uids keep two slots`; `ok a processed instance never merges into a plain stack`.
- **Identity through in-place processing:**
  - `ok drying keeps the instance identity`
  - `ok drying keeps the instance's properties and level`
  - `ok steaming spends the second; still the same instance`
  - `ok the same two instances came back, levels kept ([...] [9, 31])`
- **Opportunities:**
  - `ok no opportunities left: a third in-place step is refused`
  - `ok the rack refuses meat with no opportunities left: 'No processing left on that one.'`
  - `ok a new-food recipe starts with fresh opportunities`
- **No duplication or repeated XP:**
  - `ok two outputs, not more, after repeated advances (ready 2)`
  - `ok collect moves 2, a second collect moves nothing`
  - `[process_lab] PASS processing XP paid on collect`
  - `PASS a second collect pays nothing`
- **Save/load:** `ok identity and spent opportunities survive save/load`; `ok finished outputs survive save/load (ready 2)`.
- **Eating effects:** `PASS the meal is the stored item's own 23.2 energy`.

**Final gate** (after the 1c89134a merge, every Godot run under gslot):
- Import exit 0.
- `[t_process] PASS`, `[process_lab] PASS`, `[kitchen_lab] PASS`, `[craft_lab] PASS`, run_all `[tests] PASS`.
- All of these PASS: t_ai, t_build, t_canim, t_combat, t_harbour, t_iconart, t_items, t_light, t_lighting,
  t_occlude, t_player, t_save, t_server_domain, t_srvdom, t_structart, t_tame, t_ui, t_uiicons, t_web. t_save
  shows only its 5 deliberate SCRIPT ERRORs. t_uiicons now passes because the base fixed the grindstone icon.
- `SMOKE PASS`.

## Screenshots looked at

All in `/private/tmp/claude-501/-Users-milankinzy-Documents-deadfront-gate/b2302670-e08e-4f7f-8e24-c720e0f2b372/scratchpad/shots/`.

- **1600x900, rack, both renderers:** `rack_p{0,50,100}_{fwd,glc}.png`.
- **1600x900, all four stations:** `all_p50_{fwd,glc}.png`, `r2_all_p50_fwd.png` (round 2).
- **844x390 glc (phone):** `all_p50_phone_glc.png`, `r2_all_p50_phone_glc.png`, `rack_p100_phone_glc.png`.
  - Labels are readable at HUD size.
  - In this lab framing the steamer label sits partly under the vitals panel.

## Assumptions (`# ASSUMPTION`, tunable in processing.json)

- **Station times:** dry meat or hide 10 min, smoke 15 min, stew 3 min, steam 1 min. Spec 11 marks the
  Durango:0 times as unverified.
- **In-place steps and opportunities:** `dry`, `smoke` and `steam` are in place, with 2 opportunities per
  instance (spec 08's estimate). Steam spends one; the PRD's steam-steam question stays open.
- **Output level:** an in-place output keeps the instance's own level (spec 11 §8, round 3); new foods use
  the skill-capped crafted level as before.
- **Cooking properties (round 3):** Dried eases fatigue 12; Smoked eases fatigue 6 and gives the Warming
  Meal (cold_resist +1, 600 s). Steam has no property: it adds a process count. The kinds come from spec 08 §4;
  the method-to-effect mapping and the amounts are not in the specs (`processing.json` `in_place.properties`).
- **Pack-up while loaded (round 3):** refused, not "return everything": a running job's inputs are mid-process,
  and spec 11 §9 asks that cancellations lose nothing. Round 7: TAKE BACK hands a waiting job's inputs back; a
  running job is not cancelled.
- **Burn:** process jobs never burn unless the recipe has `burn_on_fail`. The roll happens at load.

## Integrator hooks

`docs/orchestration/reports/claude-mmo-w2-process-hooks.patch` (regenerated in round 9, f7ca30df; `git apply
--check` clean on claude/mmo-overhaul 946da955 through a scratch index, and on this branch). Six files:
- `game/scripts/core/save_restore.gd` (W1-SAVE): `SaveRestore._items_of` adds a station row's process
  contents, so a row the grid refuses on load is refunded with what hung on it. Since round 6 those stacks
  pass `SaveSanitizer.stacks` inside `ProcessStation.saved_stacks`.
- `game/scripts/ui/hud_pills.gd` (W1-UI), round 7:
  - A working process station's chip shows `label_text()` in place of its name, on one line.
  - A blocked status chip steps sideways (anchor kept under it), under its anchor or one row up before the
    shared layout runs. Failing that it uses the name chip, else no chip.
  - Working stations skip the two-per-name cap.
  - `HudPills.last_drawn` records each drawn chip's node, anchor and rect for the lab check.
  - Round 9: the name fallback (`name_text`, `name_w`) is measured only for a chip that shows a status.
  - The old second-line code and the 96 px timer-width change are gone.
- `game/scripts/player/player_actions.gd` (W2-PLAYER), round 7: `collect(st)` and `take_back(st)`, intents
  `act.collect` / `act.take_back` with `{"station": net_id(st)}` when online.
- `game/scripts/ui/craft_ui.gd` (row meta and detail title) and `game/scripts/ui/station_radial.gd` (W1-UI),
  round 7: `Crafting.preview_time(rec)` in place of `"%.1fs" % Crafting.recipe_seconds(rec)`.
- `game/tests/run_all.gd` (integrator): `_test_process_stations()` runs `res://tests/process_checks.gd`.

**After merge, in the integration commit (review r3):** `StationCraft._on_menu_action` calls
`player.actions.call(action_id, st)` only so the branch compiles without the patch. Once the hooks patch has
added `collect` / `take_back` to player_actions.gd, switch to typed calls. This is not a hunk in the hooks patch,
because those lines exist only on this branch and the patch must apply clean on bare claude/mmo-overhaul. It
applies with `git apply` after the merge, and process_lab passes with it (round 9):

```diff
--- a/game/scripts/items/station_craft.gd
+++ b/game/scripts/items/station_craft.gd
@@ -102,11 +102,10 @@ func _on_menu_action(st: Node3D, action_id: StringName) -> void:
 				open_station(st)
 		&"sleep":
 			player._start_sleep(st)
-		&"collect", &"take_back":
-			# Verbs that change the bag go through the command layer (contracts.md §0.3: online they
-			# are act.collect / act.take_back intents). call(): the two methods are W2-PLAYER's file,
-			# added by this package's hooks patch.
-			player.actions.call(action_id, st)
+		&"collect":
+			player.actions.collect(st)  # the command layer (contracts.md §0.3): online an act.collect intent
+		&"take_back":
+			player.actions.take_back(st)
 		&"cauterise":
 			if st is Bonfire:
 				(st as Bonfire).cauterise(player)
```

**W2-INV collision (review r3).** Both packages change `Crafting.default_picks`. W2-INV does it in its hooks patch
(`_plan` -> `_plan_ordered` / `_pick_key`, least valuable instance first, and `plan_spends_traits` after
`default_picks`). This branch adds the spent-primary swap inside `default_picks` (crafting.gd:95-102). The merge
order is W2-INV -> W2-PROCESS, so W2-INV's patch lands on the base first, and merging this branch then conflicts
in `default_picks` (the reviewer saw `error: patch failed: game/scripts/items/crafting.gd:98` with the order
reversed). Resolve it by keeping W2-INV's version and moving the swap onto its ordering: in `_plan_ordered`,
when the slot is the recipe's primary and the recipe is in place (`processing_left(rec, s) != -1`), skip
candidates with `processing_left(rec, s) == 0`, or put them last in `_pick_key`. A spent primary is then replaced
by the least valuable instance that still has processing left, which is the order the task asks for. Two checks
must still pass after the merge: t_process `the rack refuses meat with no opportunities left` and `the instance
that still has one is picked instead`. Until W2-INV lands, the swap takes the first instance in
`stacks_for_slot` order.

The pack-up fix needs no change in `build_placer.gd` or `player_actions.gd`. `BuildPlacer.pack_up_node` calls
`pack_up_blocker` first, and `pack_up_blocker` asks `pack_up_block_reason()` duck-typed before any side
effect. That holds on the base (build_placer.gd:176 -> :209) and on W2-BUILDSYS 4b8c6d23 (:265 -> :302).
Notes:
- **W2-BUILDSYS merge:** no hook needed for process stations. BUILDSYS's `StructureHealth.take_damage`
  calls `host.salvage_contents()` duck-typed and drops the stacks into the bag, home cargo or a loot bag
  (structure_health.gd:120 on 4b8c6d23). Round 5 checked this on a merged tree (below).
- run_all runs `game/tests/process_checks.gd` (round 6, hooks patch), the hostile save rows and a wall-clock
  job. t_process runs the same checks plus the rest.
- For W3-SRVACT: loading goes through `act.craft` (PlayerActions.craft), and since round 7 COLLECT and TAKE BACK
  are `act.collect` / `act.take_back` with `{"station": <net id>}`. The server handlers should run
  `ProcessStation.collect_into` / `take_back_into` on the authoritative station.

## Left / not done

- **Not built:**
  - crafting quality windows (HANDOFF P3);
  - the rest of the spec 11 Processing profession: material in-place methods with attribute trade-offs, Handicraft/Metal ability, alloys, and tool and station-level gates;
  - the rest of the spec 08 cooking work (W2-COOK): slot roles, digestion and inheritance. Property buffs use
    FoodBuffState's refresh-by-id rule (eating a second smoked meat restarts the Warming Meal; it does not stack);
  - cancelling a running job (TAKE BACK covers waiting jobs only, round 7);
  - market value from processing history (ECON is not merged; nothing fake in the economy).
- **Steamer pick:** the steamer takes the first food in the bag, raw meat included (round 7: a wrong pick
  waiting in the queue can be taken back; the pick order itself stays with W2-INV/W2-CRAFT). Steaming raw meat
  (21.6 energy) is worse than grilling it; steaming cooked food is where it pays. A "prefer cooked" pick or a
  recipe selector belongs to the craft-sheet work (W2-SCREENS).
- **Needs other packages:** a tanning frame and kiln/smelting need a model, placement and items from
  W1-STRUCTART, W2-BUILDSYS and W2-DATA. Hide drying already runs on the rack.
- **Visual limits:**
  - The rack stage GLBs are single meshes with one atlas material, so one strip shows a full rack and the
    dried strips cannot be tinted without tinting the frame. Registered for W1-STRUCTART in
    `docs/orchestration/mmo/asset-replacement.md` (round 6).
  - The status is on the HUD chip, so it shows within HudPills' 8 m like every other chip; the stage
    models and the smoke show at any distance.
- **Audio:** none (audio-build-10). Sourcing sounds needs the owner's yes.

## Open owner decisions

None from this package. The steam-steam question was already open in the PRD (open question 13).
