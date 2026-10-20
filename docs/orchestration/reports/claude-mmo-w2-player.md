# W2-PLAYER report: player.gd split, PlayerActions, grounding, roll, attack and pet fixes

Branch `claude/mmo-w2-player` (work tree `.claude/worktrees/mmo-w2-player`). No credits spent.
Spec: `docs/orchestration/mmo/plan-register.md` section "W2-PLAYER". Synced with `claude/mmo-overhaul`
(STATUS/merge log through W1-STRUCTART, `1ec6551`, plus FINAL_SYNC).

## What shipped

- **Split (`game/scripts/player/`).** `player.gd` went from 2,370 to PLAYER_LINES lines. It keeps
  the state other systems read (bag, vitals, statuses, hunt, pets, work targets) and wires five
  RefCounted parts, built in `Player._init` so a `Player.new()` (run_all's counter fixture) works too:
  - `PlayerSim` (SIM_LINES): walking, tap-to-walk routes, roll and stagger, sleep, autofeed timing,
    fall/shoreline guards.
  - `PlayerView` (VIEW_LINES): rig setup and grounding, sockets, lantern, beacon, tap markers and the
    route line, footsteps, the ear, UI hosts.
  - `PlayerInput` (INPUT_LINES): keys, pad and taps, the interact key, hold-to-walk, HUD context hexes.
  - `PlayerActions` (ACTIONS_LINES): the command layer, see below.
  - `PlayerPets` (PETS_LINES): summon/dismiss, the pet hex menu, orders, feeding, bag dumps, riding.

  Every old entry point that labs, probes, `main.gd` and the HUD call (`_begin_gather`,
  `_try_roll`, `_interact_tap_target`, `_closest_nav_point`, `summon_pet`, `context_action`, ...)
  stays on `Player` as a one-line forward, so no caller outside my files changed.
- **PlayerActions.** The one command layer for gather, loot, craft, place, equip, eat, tame and
  attack (plus coat, snare, claim, medicine, structure taps). Offline each verb applies locally as
  before. With `online = true` each verb records `{"op": "act.<verb>", "a": {...}}` in `sent`
  (contracts.md 0.3 names and args) and changes nothing locally. `_send` is the single place W3-SRVACT
  swaps for the socket. The header says how W2-ACTION adds a verb (swing, dodge, block, aim): one
  method that returns `_send(...)` online and applies locally offline, called from PlayerInput.
  No action mode was built.
- **PlayerRegistry (`game/scripts/core/player_registry.gd`).** `local()`, `all()`, `nearest()`,
  `owner_of(pet)`, `credit_for(source)`. The dsc worker replaced the first-player lookups in 29 call
  sites outside my files (35 -> 6; the 6 left are in other packages' files, hooks below). AI targeting
  and the telegraph dodge use `nearest()`, the pet brain and pet passthrough use `owner_of()`, kill
  credit uses `credit_for()` with `nearest()` as the fallback.
- **Grounding (pc-anim-01, pc-misc-01).** The rig is lowered by the capsule half height, so the
  feet stand on the floor (lowest idle bone 0.031 m above it, was 0.95 m). `PlayerView` cancels
  PlayerAnim's sleep drop of Visual on the rig (PlayerAnim is W2-PANIM's), so sleeping stays on the
  floor. The capsule is now 2.0 m tall to hold the 1.72 m model with its 1.18 legibility lift
  (was 1.8 m for a 2.03 m figure).
- **Roll (pc-combat-01).** Accepted during a swing, a flinch or a stagger (it cancels them; a swing
  in flight loses its hit because Hunt already checks `rolling` at contact). It dashes along the
  stick (camera-relative input, facing only when the stick is idle), buffers 0.2 s while another roll
  is running, plays the roll clip at the dash length (0.45 s) and drops to idle when the dash ends.
  Refusals say why ("Dismount to roll.", "Can't roll while resting.", "Can't roll while knocked
  down.", "Too hampered to roll.", "Out of stamina.").
- **Attack (pc-combat-04, pc-bug-01).** `Hunt.swing_now()` is a manual swing: F, pad X or a tap
  on a wild animal swings now when it is in reach, with Auto off or on HOLD too. HOLD no longer
  stops auto-attack; it only stops the chase. F with no target hunts the nearest wild animal
  within Hunt's 28 m leash and never a pet.
- **Pets (tame-11, tame-13, tame-16, tame-21, phys-spawn-01, phys-mount-01, build-storage-01).**
  - A tap (or E) on your pet opens a hex menu: Ride (mount species), Bag (when it has one), Feed,
    Orders (Attack / Heel / Guard). A protoceratops (bag + mount) used to mount and never show its bag.
  - Feeding reaches the pet whose menu was opened last, else the nearest pet out that eats it
    (was: only the first summoned pet).
  - Pet HP is kept on the record: a pet dismissed at 40 % comes back at 40 %, a pet that died comes
    back full. It is synced while the pet is out, so a save can carry it once the PetRecord field
    lands (hook 2).
  - A summon is positioned on the ground before `add_child`, and gets zero velocity.
  - Riding moves at the pet's walking pace (`pet_record.speed`, statuses, hunger) and the rider
    slides the mount after the creature's own tick, which used to zero the steering. The howdah
    (saddle) path is unchanged; equip_mount_lab passes.
  - A pet-bag dump into a basket moves only what fits; the rest stays in the pet's bag.
- **Corpse radial (sec-loss-08, sec-xpfarm-07).** A radial take moves only what fits
  (`Inventory.transfer_to`); with a full bag the stack stays in the corpse and no XP is paid. With
  room it pays Butchering +3 once (was paid twice per take, and paid on a full bag).
- **Physics (phys-climb-01, phys-path-01).** A rise that only a creature caused is undone, and the
  stall fallback's `unstick` takes a collision-tested step and never hops (the hop is what put her
  on dinosaurs' backs). A route whose router gives no direction now walks straight at the goal
  instead of creeping one frame per 1.2 s. A ground move to a tile no route reaches stops at the
  closest reachable tile and says "Can't get all the way there."
- **Structures (build-gate-01, build-remove-01).** A tap on a placed structure calls its own
  `interact()` first (gates open and close); sprint + tap at home packs any kind up through
  `BuildPlacer.pack_up_node` (all or nothing on the bag).
- **Audio hooks (audio-footsteps-08, audio-spatial-12).** `Player.footstep(foot, surface, speed)`
  fires once per stride (0.75 m walking, 1.0 m running; surface = island TileType, -1 off island,
  -2 water). An `AudioListener3D` ("Ear") sits 1.65 m above her feet and is made current; it turns
  with the camera so screen-left is ear-left.
- **Tests and lab.** `game/tests/t_player.gd` (all acceptance rows that run headless) and
  `game/scripts/dev/player_lab.gd` + `scenes/dev/player_lab.tscn` (flat floor and the real
  home island; windowed runs save `/tmp/dfs-player-*.png`).

## Acceptance

ACCEPTANCE

## dsc usage

DSC

## Integrator hooks

HOOKS

## Assumptions (marked `# ASSUMPTION:` in code where they are code)

ASSUMPTIONS

## Limits and what is left

LIMITS
