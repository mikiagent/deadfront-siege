# W2-PLAYER report: player.gd split, PlayerActions, grounding, roll, attack and pet fixes

Branch `claude/mmo-w2-player` (work tree `.claude/worktrees/mmo-w2-player`). No credits spent.
Spec: `docs/orchestration/mmo/plan-register.md` section "W2-PLAYER". Synced with `claude/mmo-overhaul`
through `1e96dbc` (DSC-MINORS, DSC-CLIPS, codex-harbour and codex-animals merged in `55e2c42`, `cb688bb`,
`29ae55f`; the one conflict,
`_begin_gather`, is ported into `PlayerActions.begin_gather`: can_gather first, refusals on the HUD).

## What shipped

- **Split (`game/scripts/player/`).** `player.gd` went from 2,370 to 456 lines. It keeps
  the state other systems read (bag, vitals, statuses, hunt, pets, work targets) and wires five
  RefCounted parts, built in `Player._init` so a `Player.new()` (run_all's counter fixture) works too:
  - `PlayerSim` (585): walking, tap-to-walk routes, roll and stagger, sleep, autofeed timing,
    fall/shoreline guards.
  - `PlayerView` (406): rig setup and grounding, sockets, lantern, beacon, tap markers and the
    route line, footsteps, the ear, UI hosts.
  - `PlayerInput` (545): keys, pad and taps, the interact key, hold-to-walk, HUD context hexes.
  - `PlayerActions` (588): the command layer, see below.
  - `PlayerPets` (334): summon/dismiss, the pet hex menu, orders, feeding, bag dumps, riding.

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
  `owner_of(pet)`, `credit_for(source)`. `owner_of` gives a pet whose record nobody holds yet
  to the local survivor: `field_tame` calls `become_pet` before `bonded.append`, and labs make
  unbonded pets, so without it pet_passthrough_lab's tame-path check and a fresh tame's first
  brain frame went ownerless (found in this pass, fixed in `2f2d569`, checked in t_player). The dsc worker replaced the first-player lookups in 29 call
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

Run on `cb688bb` unless a line says otherwise; after the last base merge (`29ae55f`) SMOKE, every
t_*.gd, run_all, equip_mount_lab, pets_lab, capture_lab, player_lab and pet_passthrough_lab were rerun: all PASS. Godot 4.7.1 mono via gslot.

- `wc -l`: player.gd 456 (<= 800); player_sim 585, player_view 406, player_input 545,
  player_actions 588, player_pets 334, player_registry 53 (each <= 600). PASS.
- Idle lowest bone 0.031 m above the floor (was 0.95 m): `[t_player] ok idle lowest bone within 0.05 m
  of the floor (0.031 m)`; player_lab on the real home island: 0.031 m from the terrain. PASS.
  Pixels: windowed gl_compatibility player_lab 1600x900 and the Chrome soak's first checkpoint both show
  her feet on the ground with her shadow under her (looked at both PNGs).
- Roll: `accepted 0.3 s into an attack in 20 of 20 tries`, `dash follows the input vector (worst dot
  1.000)`, `busy clears within 0.05 s of the dash end (worst 0.017 s)`, refusal says why. PASS.
- HOLD in reach: `5 hits in 4.5 s (period 1.0 s)`; Auto off: F swings and lands once; `F with only a pet
  nearby starts no hunt`. PASS.
- Pets: `dismissed at 40 %, summoned back at 40 %`; protoceratops menu `[ride, bag, feed, orders]`;
  `Bag opens the protoceratops's bag`; `full bag: the stack stays in the corpse, no XP (count 3)`; with
  room `moved 3, XP +3 once`; pet bag dump `moved 1, kept 1`. PASS.
- Walking into a compsognathus, zebraceratops, velociraptor for 5 s (contact=true): raised 0.00 m each
  (was +0.97, +1.16, +1.82 m), flat floor and island terrain; unstick never steps into them. A summon at the
  island origin: top pet speed 0.0 m/s (t_player) and 7.2 m/s (player_lab, walking after her), both < 15. PASS.
- `grep -c 'get_first_node_in_group("player")' -r game/scripts`: 6 (35 before). NOT MET on this branch:
  all 6 are in files other packages own right now (ui/world_ui.gd x3, ui/food_inspector.gd,
  ui/creature_plates.gd: W1-UI; items/crafting.gd: W2-PROCESS/W2-INV). Hook 1 below takes it to 0; I applied
  it in my tree, saw grep 0, SMOKE PASS and [tests] PASS, and reverted it.
- equip_mount_lab `[equiplab] PASS`, pets_lab `[petslab] PASS 5/5`, capture_lab `[capture] PASS bonded+=2`,
  player_lab `[playerlab] PASS`. PASS.
- `--combat-test` and `--gather-test`: FAIL on this branch and identically on the base (`cf4112b`, no
  W2-PLAYER code): a fresh user:// opens character creation and never loads an island, so World.runtime is
  null (combat: SCRIPT ERROR add_child on null at main.gd:111, also reported by W1-COMBAT; gather: "no branch
  node"). With hook 3 (main.gd, W2-INT's) applied: `[combattest] ok chest open storage=true` and
  `[gathertest] ok +3 branch` (+4 on the first run). Hook 3 reverted, not committed.
- Desktop Chrome soak (`tools/production_soak.mjs` against a local `export_web.sh --soak` export of
  `55e2c42`, served on 127.0.0.1): unmodified, every checkpoint through `build-closed` including the real
  Chrome click that opens the workbench ring, then it times out on travel with "Needs Survival 20" (the
  web_soak.gd fix W1-QA owns). With hook 4 (Survival 20 in web_soak.gd): `SOAK PASS (11 checkpoints)`.
  The export needed PAYLOAD_MAX_MB=300: the pack is 274.2 MB against the 220 MB gate (assets, not code;
  W2-WEB2). Hook 4 reverted.
- Gates: SMOKE PASS; `[t_player] PASS`; run_all `[tests] PASS`; t_ai, t_build, t_canim, t_combat,
  t_harbour (islands=15), t_iconart, t_items, t_light, t_lighting, t_save (its 5 deliberate SCRIPT ERRORs),
  t_structart, t_tame, t_web all PASS.
- Extra labs on the dsc1 call sites: pet_passthrough_lab CHECK PASS, ai_validation_lab, wild_ai_sweep_lab,
  hunt_lab, combat_rules_lab PASS; bot_rest, cargo_capacity, earned_training probes PASS; progression,
  raid_gear, raid_fight PARTIAL as designed. camp-travel-probe ("exactly one basket after return") and
  siege-probe ("platform never destroyed") FAIL here and on the base, so not from this package.
- Kick: `[combattest] kick moved=0.00` here and on the base with the same hook (not asserted by the test).

## dsc usage

- **dsc1** (sub-worktree `.claude/worktrees/mmo-w2-player-dsc1`, branch `claude/mmo-w2-player-dsc1`, one
  `dsc cook --once` worker): replaced `get_first_node_in_group("player")` in 29 call sites across 25 files
  outside game/scripts/player (AI, pets, corpse, creature, telegraph, world, build grid, weather, terrain,
  pen, save, game/main, 10 dev probes, web_soak) with `PlayerRegistry.local()/nearest()/owner_of()/
  credit_for()`, gated by a read-only verify script (grep count, SMOKE, run_all). Its two commits are merged
  (`8a09d6a`) with the code exactly as it wrote it; TASK.md and verify_registry.sh were left out.
- What I changed after it: its choice of `owner_of(self)` for pet passthrough and `owner_of(creature)` in
  PetBrain returned null for a freshly tamed or lab-made pet (no bonded entry yet), which turned
  pet_passthrough_lab red. Fixed once at the root in `PlayerRegistry.owner_of` (`2f2d569`) with a t_player
  check, rather than in its call sites.
- No second worker in this pass: the machine was at the 8-worker cap when I started (`pgrep` count 8), and
  what was left (6 call sites in W1-UI and items files, report, merges, gates) is either in another package's
  files or not mechanical.

## Integrator hooks

All four were applied in my tree, checked, and reverted; none is committed.

1. **Last 6 first-player lookups (W1-UI: ui/world_ui.gd, ui/food_inspector.gd, ui/creature_plates.gd;
   W2-INV/W2-PROCESS: items/crafting.gd).** Takes the grep to 0. Checked: SMOKE PASS, [tests] PASS.
   ```sh
   sed -i '' 's/get_tree().get_first_node_in_group("player") as Player/PlayerRegistry.local()/' \
     game/scripts/ui/world_ui.gd game/scripts/ui/food_inspector.gd game/scripts/ui/creature_plates.gd
   sed -i '' 's/return (tree as SceneTree).get_first_node_in_group("player") as Player/return PlayerRegistry.local()/' \
     game/scripts/items/crafting.gd
   ```
2. **PetRecord.hp_now (W2-BREED, game/scripts/pets/pet_record.gd)** so a hurt pet's HP survives save/load
   (PlayerPets already uses the field when it exists, else record meta). Checked: t_player, t_save, t_tame PASS.
   ```gdscript
   # after `var hp: float = 0.0`
   ## HP the pet has now; -1 = full (never hurt, or it died). PlayerPets keeps it in sync while the pet is out.
   var hp_now: float = -1.0
   # in to_dict(), after "hp": hp,
   		"hp_now": hp_now,
   # in from_dict(), after r.hp = float(d.get("hp", 0.0))
   	r.hp_now = float(d.get("hp_now", -1.0))
   ```
3. **--combat-test / --gather-test load an island (W2-INT, game/scripts/core/main.gd).** In `_combat_test` and
   `_gather_test`, right after the first `await get_tree().create_timer(2.5).timeout`, add
   `await _test_island()`, and add this function before `_process`. Checked: both print ok and exit 0.
   ```gdscript
   ## A fresh user:// opens character creation and never loads an island; the headless tests need one.
   func _test_island() -> void:
   	if World.runtime == null:
   		var cc := get_node_or_null("CharacterCreation")
   		if cc:
   			cc.queue_free()
   		World.load_island(self, &"home_grassland", Vector3(0, 1, 18), false)
   		await get_tree().create_timer(1.0).timeout
   ```
4. **Web soak travel gate (W1-QA, game/scripts/dev/web_soak.gd)**, the known "Needs Survival 20" hang.
   Before `World.travel(&"temperate_25", &"sail")`:
   ```gdscript
   	var st = PlayerRegistry.local().skills
   	if st and st.trees.has("survival"):
   		st.trees["survival"]["level"] = maxi(int(st.trees["survival"]["level"]), 20)
   ```
   Checked: Chrome `SOAK PASS (11 checkpoints)`.

Optional cleanup for W2-PANIM: when `_ground_sleep_visual` in player_anim.gd stops lowering Visual,
`PlayerView._keep_grounded` becomes a no-op and can be deleted.

## Assumptions (marked `# ASSUMPTION:` in code where they are code)

New in this package (the other markers in these files moved over from the old player.gd unchanged):

- `player.gd`: a 2.0 m capsule holds the 1.72 m model with its 1.18 legibility lift (pc-misc-01).
- `player_actions.gd`: F with no target hunts within Hunt's 28 m leash (it used to take the nearest
  creature at any range, pets included).
- `player_actions.gd`: online intents carry local instance ids until W3 gives replicated nodes net ids.
- `player_view.gd`: footfalls every 0.75 m walking, 1.0 m running.
- `player_view.gd`: the ear sits 1.65 m above the feet.
- Shortcuts (marked `shortcut:`): `PlayerRegistry.local()` is the first node in the group, and `owner_of`
  falls back to it for an unbonded pet (W3: keep remote replicas out of the group and pass the tamer in);
  online intents are queued in `sent`, not sent (W3-SRVACT swaps `_send`); pet HP is record meta until
  hook 2; `_keep_grounded` reads PlayerAnim's sleep drop instead of changing player_anim.gd.

## Limits and what is left

- Acceptance not met on this branch alone: the grep (6, hook 1), --combat-test and --gather-test (hook 3),
  and the Chrome soak (hook 4 plus the payload ceiling). Each fails the same way on the base, and each
  passes with its hook applied.
- The kick in --combat-test moves the compy 0.00 m, here and on the base. Not mine to tune (combat).
- camp-travel-probe and siege-probe fail here and on the base.
- Pet HP survives dismiss and summon, but not save/load, until hook 2 lands.
- No action mode: PlayerActions has the hook point for W2-ACTION's verbs (swing, dodge, block, aim) and
  nothing else.
- Godot crash reports: none from my runs. One new report appeared at 13:15:29, `Godot-2026-10-20-131531.ips`
  (SIGABRT 50 ms after launch, parent already exited). None of my commands launched Godot then; my only
  Godot process at that time was a headless main-scene run that started at 13:11 and exited normally at 13:18.
- Not touched: the occlusion system. The owner's latest note ("partially see through ... not a clear hole")
  belongs to W2-OCCLUDE.
