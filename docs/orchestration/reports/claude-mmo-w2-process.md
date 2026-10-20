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

## Round 4: vision-check fixes (docs/orchestration/mmo/vision-check.md)

The owner judged the full vision audit too exhaustive and it was stopped early (vision-check.md, first
paragraph). Two of its reader findings are for this package. Both cited lines say what the finding claims, and
both fixes are small, so both are built:

| Fix | Cited line (checked) | What changed | Proof |
|---|---|---|---|
| A station uses the instances the player picked | Spec 08:98: "A multi-material recipe consumes *specific instance IDs* atomically" (and 08:98 "Support a material-preview before committing a food process") | `ProcessStation.load_from(..., picks)`: the first job takes exactly the bag picks the craft card showed, or nothing. There is no substitute. `refuse_reason` names why ("No processing left on that one." / "That one is no longer in your bag."), and `StationCraft` shows it as a notice. Queued repeats auto-pick with `Crafting.default_picks`, which now does the spent-primary swap that `ProcessStation._picks` used to do, so the card previews the instance the station really takes. `_picks` is deleted | `ok the rack takes the picked lv 31 meat, not the default lv 9`; `ok a spent pick is refused, the other meat is not substituted: 'No processing left on that one.'`; `ok a pick that left the bag is refused`; `ok a batch takes the pick first, then auto-picks the repeat` |
| A destroyed station never deletes its contents | Spec 10:102: "A change in building state must not silently delete stored items." Spec 11:155: "Handle demolished stations, cancellations, full output containers and server restarts without losing items or duplicating output." | `CraftStation.salvage_contents()` / `ProcessStation.salvage_contents()` hand over and clear the inputs, outputs and waiting jobs. W2-BUILDSYS's `StructureHealth` child emits `destroyed` before it `queue_free()`s the station, and `CraftStation` listens to it duck-typed (`child_entered_tree`). The contents go into camp cargo all-or-nothing through `SaveRestore._refund`. When the cargo is full they wait in `SaveRestore.pending_refunds`, which is saved and retried on every load. So BUILDSYS needs no change and merge order does not matter | `ok a destroyed rack's dried meat (same uid) and drying hide go to camp cargo`; `ok cargo full: the contents wait in pending_refunds (1 rows)`; `ok with room, the next load's retry hands both over` |
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
- Picks are bag indices from the same default order the card previews, resolved when the survivor arrives.
  There is no per-slot picker yet; that is W2-CRAFT ("family slots filled by exact picked instances",
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
  - A world label shows `Drying 4/4 · 4:58`, then `Ready: 4 Dried Meat`, and is scaled up on a 390 px phone.
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
  and spec 11 §9 asks that cancellations lose nothing. A cancel action that hands inputs back is not built.
- **Burn:** process jobs never burn unless the recipe has `burn_on_fail`. The roll happens at load.

## Integrator hooks

`docs/orchestration/reports/claude-mmo-w2-process-hooks.patch` (round 4): 3 lines in `game/scripts/core/save_restore.gd`
(W1-SAVE's file). `SaveRestore._items_of` adds a station row's process contents, so a row the grid refuses on
load is refunded with what hung on it. It applies clean on claude/mmo-overhaul 6e26ef2a (the file's blob
cd8df9b8 is the patch's index line).

The pack-up fix needs no change in `build_placer.gd` or `player_actions.gd`: `BuildPlacer.pack_up_blocker`
already asks `pack_up_block_reason()` duck-typed before any side effect, on the base and on W2-BUILDSYS
(58c3a87d, line 302). Notes:
- **W2-BUILDSYS merge:** no hook needed for process stations. `CraftStation` listens to the `destroyed`
  signal of BUILDSYS's `StructureHealth` child and salvages first. A basket's `storage` on that path is
  BUILDSYS's to handle (`salvage_contents()` is the duck-typed name to reuse).
- t_process is not in run_all; run it like the other `t_*.gd`.
- For W3-SRVACT: load and collect are local calls, not PlayerActions intents.

## Left / not done

- **Not built:**
  - crafting quality windows (HANDOFF P3);
  - the rest of the spec 11 Processing profession: material in-place methods with attribute trade-offs, Handicraft/Metal ability, alloys, and tool and station-level gates;
  - the rest of the spec 08 cooking work (W2-COOK): slot roles, digestion and inheritance. Property buffs use
    FoodBuffState's refresh-by-id rule (eating a second smoked meat restarts the Warming Meal; it does not stack);
  - a cancel action that takes a running job's inputs back;
  - market value from processing history (ECON is not merged; nothing fake in the economy).
- **Steamer pick:** the steamer takes the first food in the bag, raw meat included. Steaming raw meat
  (21.6 energy) is worse than grilling it; steaming cooked food is where it pays. A "prefer cooked" pick or a
  recipe selector belongs to the craft-sheet work (W2-SCREENS).
- **Needs other packages:** a tanning frame and kiln/smelting need a model, placement and items from
  W1-STRUCTART, W2-BUILDSYS and W2-DATA. Hide drying already runs on the rack.
- **Visual limits:**
  - The rack stage GLBs are single meshes, so one strip shows a full rack.
  - Station labels overlap when stations stand closer than about 2 m on a phone.
- **Audio:** none (audio-build-10). Sourcing sounds needs the owner's yes.

## Open owner decisions

None from this package. The steam-steam question was already open in the PRD (open question 13).
