# claude-tentsleep: sleep inside the tent, see through it, stay as long as you like

Branch `claude/mmo-tentsleep` (from `origin/claude/mmo-overhaul`). Credits spent: none.

Owner (verbatim): "sleeping in a tent doesn't place me within the actual tent. When sleeping in the
tent, put the player inside laying down and use the occlusion to see through the tent slightly
transparent", then "make it so you can stay in the tent for as long as you would like. It kicks you out
when you are no longer exhausted".

## Cause

`start_sleep` already moved her onto the tent's centre, but the tent is a StaticBody3D with a box
collider the size of the model. The first `move_and_slide()` of `_tick_sleep` pushed her capsule back
out to the box's edge, so she slept beside the tent.

## What shipped

- `player_sim.gd`: `_enter_bed()` / `_leave_bed()`. Lying down adds a collision exception with the
  bedding, puts her at its centre, and turns her along its long axis. It also holds the tent faded.
  Every way a sleep ends goes through `_end_sleep()` -> `_leave_bed()`: completed, moving, Get up, a
  real hit (`interrupt_sleep`), or death. That steps her out of the doorway, removes the exception and
  releases the fade. Status ticks still do not wake her (Player's existing guard).
- Staying in a tent: when the sleep's drain is paid (exhaustion 0), a tent keeps her asleep inside
  (`_slept_full`, `_sleep_left` held at `STAY_LEFT` = 0.001 so every "asleep" check still holds). The
  use, "Rested" and Well Rested land once, when she leaves: Get up, a move or a hit. A sleep that
  reached 0 counts as completed even when a hit ends it. A straw roll still ends on its own.
- `player_input.gd`: while asleep, the only context hex is **Get up** (a 70 px HUD hex), and it calls
  `PlayerSim.get_up()`.
- `placed_building.gd`: `sleep_yaw()` (long axis), `wake_anchor()` (now the real doorway: +X, half the
  collider + 0.6 m), and `keeps_sleeper()` (tent, canvas_tent).
- `occlusion.gd`: `Occlusion.hold(node, on)` keeps a node's between-meshes faded whatever the sight
  line says, using the same dither fade (BETWEEN_DROP: about 45 % opacity). The tent's meshes were
  already occludable but faded only when they were on her sight line. Hold makes the occupied tent
  fade reliably.
- Tests whose tent sleeps expected an automatic wake now call `get_up()`: t_rest, t_needs, the
  sleep_lab and bot_survivor dev scripts.

## Verification

- `game/tests/t_tentsleep.gd` (new, PASS headless and windowed):
  - Asleep: she is inside the footprint, every bone is within its half extents, the clips run
    sleep_down then sleep, the collision exception is on, and the tent is at 45 % opacity.
  - Exhaustion 0: she is still asleep inside, no use is spent yet, and the only hex is Get up.
  - Get up: sleep_up plays, she stands outside the doorway, collision is back, the tent is opaque,
    one use is spent, and Well Rested is granted once (a second `get_up` changes nothing).
  - A real hit: the same restore, with no use spent.
  - A straw roll still ends on its own.
- PNGs (1600x900): `docs/orchestration/reports/tentsleep/asleep_in_tent.png`,
  `rested_still_inside.png`, `awake_outside.png`.
- t_rest, t_player, t_playervisible, t_needs, t_movepriority, t_save (own HOME) PASS; run_all `[tests] PASS`; `tools/smoke.sh --no-import` SMOKE PASS.

## Assumptions

- `# ASSUMPTION:` the sleep axis comes from the models: tent.glb (tent and canvas_tent) has its ridge
  along local X with the door at +X (structures.py turns the A-frame 90 deg). The straw roll is long
  along Z.
- `# ASSUMPTION:` only tents keep her asleep after the drain. The straw roll ends as before.

## Not done / for the next agent

- A save made while she is asleep in a tent stores her position inside it. On load she has no
  collision exception, so the tent pushes her out to its edge. Nothing breaks.
- Tall grass scattered under a placed tent still grows through it (visible in the shots). That is a
  pre-existing placement issue.
