# HITBOXES: every melee hit is an attacking part touching a hit-able part

Branch `claude/mmo-hitboxes`, from `origin/claude/mmo-overhaul`, with overhaul merged in three times (bigreach,
ankyloai and isleshow; then coelomoves, pinfeel, sp-pachycephalosaurus and zebrawalk; then sp-smilodon, sp-woolly and
isocam). Not merged to canon. No credits spent.

Owner (Milan): "are we even using hitboxes for attacks? We should have hitboxes and it should correlate with
whatever is used to attack and whatever is hitable on the body".

Before this change, nothing used hitboxes. A hit landed when the attacker's centre was within a reach distance
of the target's centre (plus a facing check), whatever the jaw, tail or blade was doing.

How it works now: `docs/current/hitboxes.md`. Assumptions: HB1-HB7 in `docs/vision/WildLandsMMO_Open_Questions.md`.

## What shipped
- **Hurtboxes** (`game/scripts/combat/hurtboxes.gd`):
  - Every modelled species and the survivor get capsules on their bones: head, jaw, neck, torso, hips, tail segments, legs and arms.
  - Each body has 14-24 capsules, fitted once per model from the skinned mesh in 2-3 ms. Every vertex goes to its strongest bone, thin bones roll into their parent, and each capsule follows its vertices' principal axis with a 95th-percentile radius.
  - Tuning lives in `data/creatures/hitboxes.json` `hurtbox`: per species, per bone and for the survivor. Creatures use 1.25x, the survivor 1.0x.
  - The capsules sit on physics layer 20 (`Area3D`, mask 0), so they never block movement.
  - They are built on first use and synced to the live pose right before each check.
- **Hitboxes** (`game/scripts/combat/hitbox.gd`):
  - Every move names its parts in data: a bone plus a sphere, or a capsule along a bone axis (the survivor's blade).
  - Each move also has a window in clip time, by default from 0.25 of the clip before the hit frame (`anim_events.json`) up to it.
  - The window is baked once per animal from the clip's tracks, at 1/60 s samples.
  - At the hit, the sweep is tested against the target's capsules: each sample, plus each end's path between samples, so nothing tunnels. The test is exact capsule-capsule distance after a bounds pre-check.
  - The touched hurtbox goes to damage as `Health.last_hit_part` / `Vitals.last_hit_part`.
- **Every attack migrated**:
  - Creature clip hits: `Creature._on_hit` for attack_primary / heavy / bite_combo (a window per bite) / kick / tail_swipe, on every brain incl. pets.
  - TacticalBrain straight charge: tries every frame in reach until the head reaches her.
  - TacticalBrain pounce: jaws, head and hind claws.
  - TyrantBrain bite, stomp and tail whip.
  - ClubTailBrain: its club is swept live each frame with `Hitbox.touch`. It must touch her hurtboxes before its closest-pass timing lands it.
  - Survivor: punch, swing and heavy per weapon class (knife / slashing / blunt blades out of the thumb side, as `HeldModel` holds them), kick and tackle. The auto-ability uses the same kick and tackle.
- **Not changed**: roll invulnerability, telegraph dodges, damage numbers, statuses and cooldowns. They still run in `CreatureAttack` / `Hunt.land_hit`, after the hitbox says contact.
- **Survivor reach is the hitbox** (`Hunt.in_reach`):
  - She swings when the swing she would play, turned toward the target, sweeps through a hurtbox.
  - She walks to `Hunt.aim_point`, the nearest hurtbox she can reach from the ground, for example a T. rex's leg rather than the belly over her head.
  - A swing may bend 1.2 m down or 0.3 m up to meet the body (HB5).
  - The kick now steps in up to 0.8 m like the tackle's lunge. A whiff still costs stamina and cooldown (HB6).
- **BIGREACH converted**: "melee connects against big bodies" is now hurtbox contact. `t_bigreach` places her where her capsule touches a hurtbox. Sides where the collider holds her off every part at her height are skipped and covered by its approach runs. The "refused" check stands 1.5 m clear of the footprint.
- **Calibrated radii** (HB2): where a clip stops short of the brain's contact reach, or passes over a 1.78 m survivor, the part is widened just enough that today's AI still connects. The parts are marked `"calibrated": true`. Regenerate with `t_hitboxes.gd -- --calibrate`, which covers both ends of each species' size range.
  - The worst are the T. rex bite at 5.5 m (its jaws never come below 3.3 m) and its tail whip at 3.65 m.
  - Next: utahraptor 1.8-2.7 m, pachycephalosaurus hip check 2.0 m, stegosaurus head 1.7 m.
  - These radii are animation or AI-spacing debt. COELOMOVES CM5 already fixed spacing for four species, and the velociraptor's jaw dropped from 1.08 m to 0.43 m after that merge.
- **Debug draw** (`hitbox_debug.gd`):
  - Hurtboxes draw green. Each judged sweep draws red for 0.45 s, yellow where it touched.
  - It is on with the debug toggle, and in the fight lab with key H or `--hitboxes`.
  - It keeps drawing while the tree is paused.
- **Review lab** `--lab=hitbox_lab --out=DIR`: self-quitting shots at the hit frame.
- **Docs**: `docs/current/hitboxes.md`, a README row, and the fight-lab controls row.

## Shots (`docs/orchestration/reports/hitboxes/`)
They come from windowed off-screen runs: `--position 6000,3000 -- --skip-charcreate --lab=hitbox_lab --out=DIR`. The run quits itself.
- `velociraptor_attack_primary.png`: the jaw sweep (0.43 m calibrated sphere) touches her chest.
- `triceratops_attack_heavy.png`: the head and horn sweep. The trike's head hurtbox is 1.45 m with the frill.
- `deinonychus_bite_combo.png`: the first bite's window. The head sphere is calibrated to 0.74 m, and the jaws close over her head.
- `tyrannosaurus_attack_heavy.png`: the stomp. The toe sweep comes down on her, and the jaw sweep passes high.
- `survivor_swing.png`: her auto-attack walked to the stegosaurus's hind leg and the swing landed on `hind_thigh_R`.

## Gates (final tree, after the third overhaul merge)
- `game/tests/t_hitboxes.gd`: **PASS**. It checks, per modelled species and the survivor:
  - hurtboxes cover at least 85 % of the posed skinned mesh;
  - head or neck and leg regions exist;
  - attack_primary's sweep rides its bone within 5 cm of the live seeked bone, in a window that closes on the hit frame;
  - a target where the part is before the window is not hit;
  - every brain move connects with a survivor at its contact reach, behind for kicks and the tail whip, where pounces
    land, and lying Pinned for the smilodon's pin_stab;
  - bites miss a survivor beside the hips;
  - a real velociraptor bite hits a survivor in its jaws exactly once, and one beside it 0 times;
  - the hit location reaches `Vitals.last_hit_part` and `Health.last_hit_part`;
  - a thin target between two far-apart tail-whip samples is hit by the sweep, though neither sample touches it;
  - the survivor's moves bake, and her swing hits in front but not facing away;
  - her auto-attack walks up from the flank of every species and lands within 8 s;
  - perf: 20 creatures' checks take 0.7 ms in all (gate 12 ms, worst 1.5 ms), and syncing 20 bodies' hurtboxes 0.4 ms;
  - the debug draw draws.
- Also PASS: t_combat, t_tactical, t_kicktackle, t_autoability, t_rexclips, t_ankylo3d, t_raptorfeel, t_godlab,
  t_boneparts, t_perfgates, t_bigreach, t_ankyloai, t_coelomoves, t_pinfeel, t_sp_pachycephalosaurus, t_sp_smilodon,
  t_sp_woolly_rhino.
- `run_all.gd`: `[tests] PASS`.
- `tools/smoke.sh --no-import`: SMOKE PASS.
- Under load (other agents' Godot runs), `t_bigreach`'s "triceratops (AI on)" case is close to its 10 s limit.
  The trike charges and knocks her down, and she needs 2 landed swings. It passed 5 runs out of 5 after the swing margin.
- `t_perfgates` failed once on island build time with the machine at load 10. It passed in the final run.

## For the next agent
- **Plugging a move in**:
  - Add `species.<id>.moves.<move>` in `hitboxes.json` with `parts` (bone, radius / length / axis / offset) and, optionally, `window`.
  - At the impact, call `Hitbox.strike(creature, move, target, hit_index)`. Treat `{}` as a miss and call `Hitbox.mark(target, hit)` before the damage.
  - A brain that runs its own window frame by frame calls `Hitbox.touch(attacker, from, to, radius, target)` with the part's world path, as ClubTailBrain does.
- **sp-smilodon, sp-woolly**: their `pipeline.hit_parts` bones are now the moves' parts in `hitboxes.json`. Their
  `Creature.part_hit` check remains only for targets without hurtboxes.
- **styrafix, compyfeel**: had not landed in overhaul at merge time.
  - A styracosaurus impale from the horns is a `styracosaurus.moves.<move>` row with a `Head` capsule along the horn (`length`, `axis`) or a horn bone, if the rig has one.
  - Re-run `-- --calibrate` and drop calibrated radii the new clips no longer need.
- **sp-tyrannosaurus**: when the remodel lands, its bite should reach the ground; re-run calibrate and the 5.5 m sphere shrinks.
- **Hits judged at the hit frame (HB1)**: a part that touches earlier in the window still lands on the hit frame, not on contact.
- **One target only (HB3)**: only the brain's attack target or her hunt target is tested. No cleave and no friendly fire.
- **Physics layer**: the capsules are on layer 20 for other systems (projectiles later). Hitbox itself does not query the physics server, because a shape moved this frame only reaches the broadphase on the next physics step.
- **Pets**: PetBrain hits go through `_on_hit`, so a tamed ankylosaurus swings its club part through the clip window. AK8 timing is unchanged.
- **Sides of big animals**: from the pure side of a T. rex, stegosaurus or utahraptor, the collider holds her more than 0.45 m from every hurtbox at her height. She walks to a leg she can reach (`aim_point`). The bigreach approach runs land, but the swing from exactly mid-flank is refused.

## Re-integration (2026-10-31, after the canon gate went red on 8082c43b)
The coordinator reported that t_hitboxes, t_bigreach and t_sp_megaloceros failed on the merged canon. I merged
overhaul twice more (sp-tarbosaurus, megaloceros stag and doe, compyfeel, sp-carnotaurus, sp-raptor) and fixed:
- **New species plug in from their own JSON.** A move with no `hitboxes.json` row takes the species'
  `pipeline.hit_parts.<move>` bones as its parts. `Creature.part_hit` remains only for targets without hurtboxes.
  Tarbosaurus, carnotaurus and raptor are covered this way, and calibration adds rows where a radius must grow.
- **Model variants.** `species.<id>.variants.<variant>` overrides the species row: the megaloceros doe strikes with
  her forehooves and stomps. t_hitboxes checks each variant that has its own model; colour morphs share one model and
  are checked once.
- **Bug: the bounds pre-check grew by the larger radius only, not both radii together.** It skipped touches at the
  edge of the bounds, the cause of gallimimus attack_primary. Fixed.
- **Survivor swing.** The hit is judged facing where the swing was aimed, else where she has turned since. The
  nearest hurtbox can flip to another part mid-swing (the tarbosaurus head).
- **Calibration.** Per move and bone, at four sizes, in the same state the checks run in, with a 0.2 m margin. The
  pounce is measured where `TacticalBrain._land_short` lands it (the tarbosaurus lands with its jaws on the prey). The
  survivor stands back up after the pin_stab check.
- **t_bigreach.** Each side is touched with the animal at rest; the last side's flinch and grogginess moved the
  tarbosaurus head.
- New calibrated outliers: megaloceros doe forehoof about 3 m (her strike barely leaves the body), tarbosaurus pounce,
  carnotaurus jaw about 2 m. The full table is in `docs/current/hitboxes.md`.

## MegaRex (2026-10-31, canon 1bb8adec)
- MegaRex moves are judged on hitboxes: bite, stomp, tail whip, and the bite and shake (`MegaRexBrain._impact_special`
  now strikes with its jaws). `hitboxes.json` megarex gets the tyrannosaurus layout.
- TyrantBrain moves are calibrated at 0.6x and 1x of the contact reach, because a tyrant swings at anything inside its
  reach (t_sp_megarex bites from 3 m).
- MegaRex radii are the largest: bite and shake about 7 m, bite about 6 m, tail about 6 m. Its jaws sit high and far
  ahead of its body.
- Each hurtbox capsule now gets a cheap bounding-box test before the exact distance check. The per-strike perf gate is
  3 ms; under load one MegaRex sweep ran 1.7 ms, and 20 creatures take 1.7-5 ms in all.
- I checked every merged .gd file for duplicate function names: none.

## Styrafix merge (same pass)
- The STYRAFIX impale lands only when the horns (`styracosaurus.moves.impale`: Head_end, Head) reach her hurtboxes.
  The flat horn-tip distance check stays for targets without hurtboxes. The body-check glance is unchanged: it is
  body contact, not an attacking part.
- `TacticalBrain`: the charge cooldown restarts when the recover ends (ASSUMPTION). With hitboxes, a missed charge
  could paw into the next one in the same frame, and t_styrafix's A->B->A check failed.
- `t_styraco`: the sidestep scenario now starts with her on the charge line. Where the earlier ram left her depends on
  which of its hits landed.
- `t_bigreach`: the AI-on approach gets 20 s instead of 10 s. Live, the animal charges, knocks her down and turns
  away, and a swing at a part that moved misses. It failed about one run in three at 10 s.

## Ankyloclose, ceratosaurus, trike alpha, cornered, plantedflinch merge (same pass)
- **ANKYLOCLOSE.** The stomp (forefeet) and the shoves (shoulders, torso, front leg) are clip strikes on hurtboxes
  (`ankylosaurus.moves.stomp / shove_left / shove_right`). They are calibrated with her standing on each move's aim
  spot. The tackle's run keeps its contact sphere, and bodies without hurtboxes keep the spot sphere.
- **Ceratosaurus and the trike alpha** plug in through `pipeline.hit_parts` and the calibration.
- **Duplicate func names** in the merged .gd files: none.

## Therizinosaurus merge (same pass)
- The therizinosaurus claws come from its `pipeline.hit_parts`.
- Front moves are now calibrated at 0.85x and 1x of the contact reach (a tyrant at 0.6x and 1x): brains strike prey
  that walks inside their reach (t_sp_therizinosaurus sweeps at 5.2 m with a 5.97 m reach).
- `t_plantedflinch` failed on the therizinosaurus feet, on canon as well. flinchtheri fixed it on canon, and it passes after the last merge.
- The smilodon chase leap (smilorun) is judged with its own clip (`_pounce_land(clip)`). Its parts come from the
  smilodon row.
