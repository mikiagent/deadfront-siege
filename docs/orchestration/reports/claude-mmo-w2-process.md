# W2-PROCESS: process stations, in-place processing, queues that keep running

Branch `claude/mmo-w2-process`, cut from `claude/mmo-overhaul` 36299a96. Base merged in twice (5e05197e, then
1c89134a), both clean with no overlapping files. Commits:
- ec4e9375: stations and t_process
- c00f7179: process_lab, label and smoke tuning
- ccf9a9bf: round 2, following spec 08 (below)
- two base merges, and the commit carrying this report

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
  - Pack-up returns everything on the station first, and refuses if the bag cannot take it all.

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
- **Output level:** an in-place output keeps the existing skill-capped crafted level.
- **Burn:** process jobs never burn unless the recipe has `burn_on_fail`. The roll happens at load.

## Integrator hooks

None are required. Two optional notes:
- t_process is not in run_all; run it like the other `t_*.gd`.
- For W3-SRVACT: load and collect are local calls, not PlayerActions intents.

## Left / not done

- **Not built:**
  - crafting quality windows (HANDOFF P3);
  - the rest of the spec 11 Processing profession: material in-place methods with attribute trade-offs, Handicraft/Metal ability, alloys, and tool and station-level gates;
  - the rest of the spec 08 cooking work (W2-COOK): slot roles, digestion, and property-driven buffs with refresh rules.
- **Needs other packages:** a tanning frame and kiln/smelting need a model, placement and items from
  W1-STRUCTART, W2-BUILDSYS and W2-DATA. Hide drying already runs on the rack.
- **Visual limits:**
  - The rack stage GLBs are single meshes, so one strip shows a full rack.
  - Station labels overlap when stations stand closer than about 2 m on a phone.
- **Audio:** none (audio-build-10). Sourcing sounds needs the owner's yes.

## Open owner decisions

None from this package. The steam-steam question was already open in the PRD (open question 13).
