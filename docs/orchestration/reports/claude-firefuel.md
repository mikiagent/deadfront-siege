# claude-firefuel: fire fuel inventory, visible logs, particle flame

Branch `claude/mmo-firefuel` (from `origin/claude/mmo-overhaul`). Not pushed, not merged.

## What shipped

- **Fuel rule** (owner 2026-10-28): a `branch` adds 60 s, a `wood_log` adds 300 s, capped at 600 s.
  `structures.json` `stone_fire_pit`: `wood_seconds_per_branch` 120 -> 60, new `wood_seconds_per_log` 300.
  Bonfire and campfire use the same defaults (code constants). `Bonfire.add_fuel(player, item)`,
  `seconds_for(item)`, `fuel_block_reason(player, item)`. `load_wood` still works: it adds a branch,
  or a log when the bag holds no branch.
- **Visible wood**: the pit draws `logs_shown() = ceil(minutes left)` logs (0..10). The first two
  lie crossed on the coals, the next six form a teepee, and the last two lean against its foot.
  When the fire is out the pit shows only the rocks and a dark ash bed.
- **States**: `fuel_state()` is roaring (7-10 min), burning (3-6), low (1-2; small flame, the coal
  bed glows hotter) or out. The info line reads "Burning (roaring)", "Burning" or "Burning low".
- **Flame VFX** on every fire (pit, bonfire, campfire): CPUParticles3D, so it works on every
  renderer including web compatibility. It has four parts: a flame body of 36 teardrop "tongue"
  sprites (a procedural 32x64 texture, additive, about 1.3 m tall at full), a hot core of 16, rising
  embers (16) and smoke wisps (8). That is 76 particles per lit fire, and the emitters stop when the
  fire is out. The flame node scales 1.0 / 0.72 / 0.42 by state, and rain still shrinks it on top of
  that. The night fire light scales with the flame.
- **Fuel sheet** (`game/scripts/ui/fire_fuel_sheet.gd`, `FireFuelSheet`, a UiWorldSheet/SheetChrome
  sheet): the station hex is now **FUEL** (wood_log icon) and opens it through
  `HuntHud.open_fire_fuel`. The sheet has 10 wood slots (one per minute left), a fuel bar, the
  state and time left, and two 64 px gold buttons, "Branch +1 min (xN)" and "Log +5 min (xN)". A
  button greys out when the fire is full, too wet to light, or the bag holds none of that wood. The
  sheet refreshes live while open. With no HUD (bare labs) the hex loads wood in place as before. The
  hex is no longer hidden when the fire is full, because the sheet also shows the fire's state.
- **Docs**: `docs/current/building.md` Fires section.

## Save

**No save change.** `fuel_seconds` is the whole fuel inventory, and the logs are derived from it,
so no new field was added. A test checks that a pit saved at 4:30 loads with 5 logs.

## Verify

- `game/tests/t_firepits.gd` adds the FIREFUEL checks:
  - branch and log amounts, the 10 min cap, and a full fire refusing wood while the bag keeps it;
  - logs = ceil(minutes left) at every minute from 10 down to 1, including mid-minute;
  - the state at each stage, and 0 logs with no particles once out;
  - particles emitting when lit, and the flame shrinking as fuel runs low;
  - the save round trip;
  - the fuel sheet's slots, its Branch button, and 64 px buttons;
  - the FUEL hex opening the sheet.
- Windowed shots: `--lab=firefuel_lab` (new `game/scenes/dev/firefuel_lab.tscn`, which runs
  `firepits_lab.gd` on its own so kitchen_lab's quit no longer cuts it short) at `--position 6000,3000`.
  The RESULT line measures `fuel_logs_10min=10 05min=5 01min=1 00min=0 all_ok=1`.
- PNGs in `docs/orchestration/reports/firefuel/`: `firefuel_10min`, `firefuel_05min`,
  `firefuel_01min`, `firefuel_00min`, `firefuel_flame_closeup` (plus the older FIREPITS shots).
  The flame took three passes: a soft round blob, then teardrop tongues, then less pink at the tip.

## Assumptions

- `# ASSUMPTION`: fuel past the 10 min cap is lost. A log fed into a 7 min fire tops it up to
  10 min, and the 2 extra minutes are wasted.
- Bonfire and campfire take branches and logs at the same rates, still up to their own
  `fuel_max_seconds`. The campfire's cap stays at 120 s, so a log fills it.
- The temporary fires keep their baked wood art. Only the permanent pit draws the per-minute logs.

## For the next agent

- The flame is CPU particles. If a perf pass wants fewer particles, the emitter amounts are in
  `Bonfire._make_flame`.
- The fire light still turns on only at dusk, night and dawn, which is existing behaviour.
