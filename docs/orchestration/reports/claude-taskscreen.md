# claude-taskscreen: the Task screen (Durango reference)

Branch `claude/mmo-taskscreen` (local, not pushed), cut from `origin/claude/mmo-overhaul` and merged with
its later head 65f0f6f9.

## What shipped

- **Task screen** (`game/scripts/ui/orders_sheet.gd`; the class is still `OrdersSheet`, so the HUD API is
  unchanged). It uses the SheetChrome frame: back + "Task", close X. On the left are five category tabs:
  Daily Task, Achievement, Domain Construction, Main Task, Weekly Task. The open tab has GOLD corner
  brackets, and a tab with something to receive shows a red dot. On the right is a scrolling list of rows.
  Each row has a grey flat-top hex icon, a GOLD title, a grey description, a thin GOLD bar with "got/want"
  centred, and a reward line (GOLD T-stone coin, brain = skill point, XP hex). A GOLD **Receive** button
  shows only when the task is complete. Receive opens a popup headed "<Task> Complete" in GOLD, with one row
  per reward and a wide GOLD OK. Rows sort: claimable first, then in progress, then received (dimmed).
  Main Task rows that are not done have a Track / Tracking button, which points the HUD card at that order.
  On a 844x390 phone the tab column scrolls: 5 x 64 px is more than the 308 px of body.
- **Tasks core** (`game/scripts/core/tasks.gd`, data in `game/data/world/tasks.json`):
  - `rows(cat)`, `claim(id)`, `claimable_count(cat)`.
  - Daily and weekly counts reset at 00:00 UTC and Monday 00:00 UTC.
  - Counting hooks: gather units (GatherService.after_unit), every craft and per recipe (World.note_craft),
    builds (World.note_building), kills by the survivor or her pet (Creature._on_died), part kinds taken
    from a carcass (Corpse.first_take_of), landings on Lv 30+ islands (World.load_island), and Lv 60
    minerals.
  - Achievements read levels only through `skills.level_of` / `skills.character_level`. Skill points are
    paid through `skills.sp_extra` + `sp_now()`. skill_state.gd is not edited.
- **Manual rewards.** `Objectives.settle` still advances the orders, but it no longer pays. A finished order
  is recorded in `Tasks.done` and waits in Main Task. Receive pays once.
- **Badges.** HuntHud polls `Tasks.claimable_count` once a second into `HudField.tasks_ready`. This count
  adds to the nav entry (renamed "Orders" -> "Tasks") and to the MENU hex badge, the same way waiting
  recruits already count on Animals.
- **The in-world Orders card** (collapses into the minimap, hidden in combat unless relevant, auto-expands)
  is unchanged and still shows the tracked Main Task.
- **Durango import** (coordinator request):
  - `docs/reference/durango_all_tasks_research.xlsx` copied in, with 10 CSVs in
    `docs/reference/durango_tasks_csv/`.
  - Mapping in `docs/reference/tasks.md`.
  - 8 Task Board rows imported (5 daily, 1 weekly, 1 achievement, plus domain SP rewards). 5 are data-only
    (`hidden: true`). Faction missions, career guides, Google Play achievements and events are not imported
    (they belong to other systems).
- **Tutorial orders.** Main Task lists `Objectives._steps()`, which on the tutorial branch is the 19
  tutorial orders while the tutorial runs. Completion is a saved set, not the index, so:
  - the tutorial's hand-over (`tutorial_resume_at`) never pays a skipped standing order;
  - a finished but unreceived tutorial order stays claimable after the tutorial ends.

  The tutorial branch (`claude/mmo-tutorialfix`) is still not on canon. I checked a trial merge into a
  scratch worktree and then aborted it. It conflicts in objectives.gd (settle's notice), save_game.gd
  (`Tasks.from_dict` and `Tutorial.from_save` lines) and world.gd (start_new, note_building). Each conflict
  resolves by keeping both sides. Keep the tutorial's `grant_home` / `break` after my `Tasks.mark_done`
  call. A spawner.gd conflict comes from canon vs the tutorial, not from this branch.

## Merges and the tutorial (2026-10-29)

- **Merges:** origin/claude/mmo-overhaul was merged three times. The second merge brought TUTORIAL ISLAND and its siblings, the third BAGUI, the last 465b1827.
  - Conflicts were resolved by keeping both sides.
  - `Tasks.mark_done` runs before the tutorial's `grant_home` / `break`.
  - The tasks save block loads after `World.tutorial`, so an old save reads the list it was running.
- **Tutorial orders are Main Task.** Each tutorial order's reward, including the knife order's 10 Warp Gems, waits for Receive. An order finished but not received stays claimable after the ferry. Standing orders the tutorial skips (before `tutorial_resume_at`) never pay. All of this is covered in t_taskscreen.
- **BAGUI:** rewards now include Warp Gems, and T-stones read "Gold" on screen.
- **TS13, new tutorial order 2 "Claim your reward in Tasks"** (`tut_claim`, ASSUMPTION, owner go).
  - The pointer goes MENU -> Tasks -> Receive. The Task screen opens on Main Task while an order waits.
  - The tutorial bot opens Tasks and presses the highlighted Receive. After that it receives each order's reward, as a player would.
- **Occupation side effect:** the occupation's Lv 20 head start makes two skill achievements claimable at once (Lv 10 and Lv 20 in that tree).
- **t_tutorial**, 3 runs, each with its own HOME: 2 PASS, 1 FAIL.
  - The failure was the stone knife breaking before butchering after a long compy hunt.
  - Canon 465b1827, 3 runs, own HOME: 2 PASS, 1 FAIL (a walk to the fire pit).
  - Hunt length follows the crafted knife's damage, which varies with material traits: 3.5-5.6 per hit on both branches. I count it as a bot flake. I did not tune it.

## Save change (owner's gate)

- New top-level `"tasks"` block, always written:
  `{"claimed": {id: true}, "done": {"main.<order>": true}, "counts": {"daily.gather": n, "weekly.*": n, "life.*": n}, "day": utc_day, "week": utc_week}`.
- **Old saves** (no block) load with every order before `objective` marked done and received. Those orders
  were already paid, so nothing pays twice and nothing is lost.
- Domain tasks read the existing `pioneer_buildings`, so an old save may find some already claimable.
- SaveSanitizer: SHAPE now includes `tasks`. `Tasks.from_dict` type-checks every field, so a forged block
  loads with no errors and no counts.
- Golden fixtures are unchanged: t_save ignores extra keys.

## Tests

- New `game/tests/t_taskscreen.gd` checks:
  - the tabs list the right tasks, and hidden tasks stay out;
  - progress follows each hook;
  - Receive pays once and only when complete, and the popup itemises the rewards;
  - red-dot and nav-badge logic;
  - the daily reset, the weekly carry-over and the Monday reset;
  - skipped orders after a hand-over;
  - save -> load, an old save, and a forged block.
- `-- --taskshots=<dir>` writes the PNGs (windowed, `--position 6000,3000`).
- Updated tests:
  - `t_uichar`: the Orders section now drives the Task screen (Main Task, Track).
  - `t_uinav`: the nav label now reads "Tasks".
- Final head, after merging 465b1827:
  - `bash tools/all_tests.sh`: **140 pass, 0 fail**. This run includes t_taskscreen, t_uichar, t_uinav and t_tutorial.
  - `t_save` with its own HOME: PASS.
- `bash tools/smoke.sh --no-import`: SMOKE PASS.

## PNGs

`docs/orchestration/reports/taskscreen/`:
- `task_achievement_1600x900.png` and `task_achievement_844x390.png`: the Achievement tab, with Level Up
  Cooking claimable.
- `task_claim_popup_1600x900.png` and `task_claim_popup_844x390.png`: the claim popup.

## Assumptions

All are logged as TS1-TS12 in `docs/vision/WildLandsMMO_Open_Questions.md`. Main ones:

- **Rewards wait for Receive.** A finished order no longer pays on its own; nothing pays until Receive is
  pressed.
- **Reset times.** Daily resets at 00:00 UTC and weekly at Monday 00:00 UTC, on the device clock.
- **Quantities and amounts.** Every quantity and reward amount the sheet leaves blank is ours.
- **Weekly Explore Level-30 Islands** pays 100 T-stones instead of Durango's ~10,000 estimate. Owner call.
  A load on a Lv 30+ island also counts as a landing.
- **Achievement level chains** are ours. Each milestone pays 1 SP, about 84 SP over a full game.
- **Domain tasks** are ours. Each pays 1 SP.
- **Durango items** mapped to our recipes: Trimmed Material -> `trimmed_plank`, Pebble Stone Blade -> stone
  knives.
- **No Prodigal Pioneer tab.**
- **The Durango hunt task has no sheet row.** The daily and weekly hunts stay ours.

## Credits

None.

## Next

- The rows do not refresh live while the screen is open (they rebuild on open, tab change and Receive).
- The HUD card still says "ORDERS n/m".
- The economy server's `objective.claim` op is not wired to Receive; it was not wired to settle before either.
