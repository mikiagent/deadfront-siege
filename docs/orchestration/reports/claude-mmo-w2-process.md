# W2-PROCESS: process stations, spoilage, queues that keep running

Branch `claude/mmo-w2-process`, cut from `claude/mmo-overhaul` 36299a96, base 5e05197e merged in (clean, no
overlapping files). Commits: ec4e9375 (stations, spoilage, buffs, steam cap, t_process), c00f7179 (process_lab,
label and smoke tuning), the base merge, and the commit carrying this report.

## What shipped

- **`ProcessStation`** (`game/scripts/world/process_station.gd`, new). A child node that `CraftStation._ready`
  attaches to every kind with a row in `processing.json` `stations`: drying rack (4 slots: dry_meat, dried_hide),
  smoker (4: smoke_meat), crock pot (1 slot + 3 queued: camp_stew), steamer (2 + 2: steam).
  - Inputs leave the bag through the existing `Crafting.consume_for_craft` (exact stacks, primary first) and sit
    on the station. Output level is fixed at load from the loader's skill, so nobody needs to be near at the end.
  - A job is only timestamps on `Food.now_s()` (wall clock). It finishes while the player is 50 m away, on another
    island or with the game closed. When a slot frees, the next queued job starts **at the freeing time**, so an
    offline catch-up gives the same result as a watched run.
  - Finished outputs wait on the station. **COLLECT** (new hex on the station menu) moves them into the bag; what
    does not fit stays. Processing XP is paid once, when a job's output leaves the station.
  - The craft route is the same as before (craft sheet, walk to the station), but at a process station the survivor
    hangs the inputs and is free to go. No stand-and-wait craft is left for these recipes.
  - Visible: the drying rack swaps W1-STRUCTART's stage models (`empty` / `raw` / `drying` / `dried`) based on
    the progress of the least-advanced running strip. Smoke (rack, smoker) or steam (crock pot, steamer) comes from
    CPUParticles3D, which looks the same in Forward+ and gl_compatibility. Fired stations show an ember glow. A world
    label reads `Drying 4/4 · 4:58` and then `Ready: 4 Dried Meat`, and it is scaled up to HUD size on a 390 px phone.
  - Saved inside the station's existing row (`CraftStation.to_dict` `"process"`). `SaveRestore.spawn` already
    calls `CraftStation.from_dict`, so no save-code change or migration is needed: old rows simply have no key. On
    load, a start time in the future is clamped to now. Rows for recipes the station no longer runs come back as
    collectable outputs; they are never deleted.
  - Pack-up hands back everything on the station first, and refuses (the station stays) when the bag cannot
    take all of it.
- **Spoilage**: `ItemStack.spoil_at` (unix s; 0 = keeps), stamped in `ItemStack.make` from `processing.json`
  `spoil`. Raw meat spoils after 1800 s. `preserved` and `cooked` keep. A spoiled stack restores x0.25 energy,
  always gives a stomachache, shows `SPOILED` / `spoils in 12m` in tooltips and the inspector, and cannot go on
  a station (a fresh stack beside it is picked instead). On a merge the stack keeps the older clock. A saved
  clock can only move earlier on load (a save cannot un-spoil meat), and an old row without the key gets a fresh
  clock, so nothing spoils on upgrade. Rows of food that keeps keep the old shape byte for byte.
- **Preserved food carries a buff**: `processing.json` `item_buffs` maps dried_meat to Trail Ration (cold
  resist +1, 900 s) and smoked_meat to Smokehouse Ration (defense +8, 600 s). The buff rows live in
  `processing.json` and are merged into the `food_buffs.json` set, so items.json (W2-DATA) is untouched.
- **Steam cap (food-01)**: `attributes.steams` counts steams; `Crafting.picks_valid` refuses a dish at
  `steam_cap` (3). kitchen_lab's sashimi-steam-steam route is still under the cap and still wins.

## Acceptance

| Check | Result |
|---|---|
| process_lab windowed: 4 raw strips pass through 3 stages over the configured time, smoke while active | Shots at 0, 50 and 100 % looked at (below): red strips, then maroon, then near-black. Smoke is on at 0 and 50 % and off at 100 %. `[process_lab] shot ready proc=50% view=rack rack stage=drying label='Drying 4/4  ·  5:00' smoke=true` |
| Save/reload mid-process resumes with the right remaining time | `[t_process] ok reload mid-process resumes with 300s left (was 300s)` (JSON round trip through `SaveRestore.spawn`) |
| t_process: the queue keeps running with the player 50 m away | `[t_process] ok nobody within 50 m` / `ok rack finished 4 on its own clock (ready 4)`. The station's own `_process` did it, not a test call. process_lab with a real survivor: `PASS finished with the survivor 50 m away (ready 4, dried)` |
| Raw meat spoils per processing.json; dried meat in the same bag does not; eating dried meat applies its buff | `[t_process] ok raw meat spoils after its processing.json time`, `ok dried meat in the same bag does not spoil`; `[process_lab] PASS raw meat spoiled, dried meat did not`, `PASS dried meat applied its Trail Ration buff (["trail_ration"])` |
| kitchen_lab and craft_lab PASS | `[kitchen_lab] PASS`, `[craft_lab] PASS` (exit 0, after the base merge) |

Gate after the base merge (every run under gslot): import exit 0; `[t_process] PASS`; `[process_lab] PASS`;
run_all `[tests] PASS`; t_ai, t_build, t_canim, t_combat, t_harbour, t_iconart, t_items, t_light, t_lighting,
t_occlude, t_player, t_save, t_server_domain, t_srvdom, t_structart, t_tame, t_ui, t_web all PASS (t_save's 5
SCRIPT ERRORs are its deliberate ones); `SMOKE PASS` (`tools/smoke.sh --no-import`).
**t_uiicons FAILS on the base, not because of this branch**: `[t_uiicons] FAIL station_grindstone (from
props_manifest.json) has its own icon, not the fallback`. The grindstone row came in with the DSC-CAMP merge
(9b8d618d). This branch touches no icon or manifest file (`git diff --stat claude/mmo-overhaul HEAD` lists only
the 12 files above).

t_process can fail. Its first run caught two real faults: a test meat stack that was already spoiled, and a
50 m check that did not wait long enough for the 4 Hz station tick. Both showed as FAIL lines before they were
fixed.

## Screenshots looked at

In `/private/tmp/claude-501/-Users-milankinzy-Documents-deadfront-gate/b2302670-e08e-4f7f-8e24-c720e0f2b372/scratchpad/shots/`:
- `rack_p0_fwd.png`, `rack_p50_fwd.png`, `rack_p100_fwd.png` (1600x900 Forward+): stages read by colour, smoke
  rises through the strips, label above the name chip.
- `rack_p0_glc.png`, `rack_p50_glc.png`, `rack_p100_glc.png` (1600x900 gl_compatibility): same stages. The rack
  smoke is fainter on the paler compat grass, so its alpha was raised from 0.30 to 0.42.
- `all_p50_fwd.png`, `all_p50_glc.png`: all four stations working, with steam on the crock pot and steamer,
  smoke from the smoker roof and the rack, and a label per station.
- `all_p50_phone_glc.png`, `rack_p100_phone_glc.png` (844x390 glc): a first pass had the labels at about 6 px.
  They now scale with the window height and read at HUD size. On the phone the steamer label sits partly under
  the HUD vitals panel in this lab's framing.

## Assumptions (`# ASSUMPTION`, all tunable in processing.json)

- Station times: dry meat 10 min, dry hide 10 min, smoke meat 15 min, camp stew 3 min, steam 1 min. Spec 11's
  times are Durango:0 values marked unverified.
- Raw meat (categories `raw_meat`, `raw`) spoils in 30 min of wall time, offline included. `cooked` and
  `preserved` keep. The spoiled multipliers are illustrative.
- Buffs: Trail Ration for dried meat and Smokehouse Ration for smoked meat. The PRDs name no buff for them.
- Steam cap 3 (the planner's default, open owner question 17).
- On a merge the stack keeps the older spoil clock. Owner rule 08 removes food stacking anyway, and W2-INV and
  W2-DATA own that.
- Process jobs never burn unless the recipe has `burn_on_fail`. The roll is made at load with the loader's skill.

## Integrator hooks

None required: save, restore, labs (`--lab=process_lab` resolves by scene name) and the menu all run through
owned files. Optional:
- run_all does not include t_process. Run it with `--script res://tests/t_process.gd` like the other `t_*.gd`.
- W3-SRVACT: load and collect are local calls (`ProcessStation.load_from` / `collect_into` from StationCraft),
  not PlayerActions intents yet.

## Left / not done

- **Crafting quality windows (HANDOFF P3)** and spec 11's full Processing profession (in-place modification
  with finite attempts, Handicraft/Metal ability, alloys, tool and station-level gates) are not built. The
  engine here (exact-instance jobs, timed queues, saved state) is what that work would sit on.
- **Tanning frame and kiln/smelting**: no station model, placement or items exist (they need W1-STRUCTART, W2-BUILDSYS
  and W2-DATA). The rack's hide drying (`dried_hide`) runs as a process job. A new station is one
  `processing.json` row once it can be placed.
- Strip count on the rack: the stage GLBs are single meshes, so 1 strip shows a full rack. Per-strip nodes in
  the Blender set would let the station hide unused ones.
- Audio (audio-build-10): the project has no sounds, and sourcing them needs the owner's yes.
- Station labels can overlap each other when stations stand closer than about 2 m on a phone.
