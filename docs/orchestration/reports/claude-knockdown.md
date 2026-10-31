# KNOCKDOWN: heavy creature hits knock the survivor down or throw her

Owner 2026-10-31: "the dinosaurs should be able to charge and knock us on our ass or throw us etc. the player should
get thrown around and have a falling on his butt animation, wind knocked out of him".

Branch `claude/mmo-knockdown` (from `claude/mmo-overhaul`, merged again before the final runs). Not merged to canon.
Credits spent: none (no Meshy, no Tripo; the clips are built from clips already on the survivor rig).

## What shipped

- `game/scripts/player/player_knock.gd` (PlayerKnock, owned by PlayerSim as `sim.knock`). One reaction ladder for
  every heavy creature hit, picked from the hit, not the species:
  - force = shove metres x attacker size (height / 3 m, clamped 0.6-1.5); any upward lift (horn toss) = throw.
  - light (< 2): the old `PlayerSim.shove` slide + flinch, unchanged.
  - knockdown (>= 2): slid back along the push, `fall_back` (stagger, lands on her butt, chest folds, rolls onto her
    back), `lie` 1 s, `get_up`.
  - throw (>= 5 or lift): ballistic arc (move_and_slide every frame, so floors and walls stop it), `airborne` loop,
    lands into `fall_back` from its butt-landing frame, tumbles on 45 % of the flight speed for 0.4 s, then lie and
    get_up. Distance 3-9 m. Into water: she comes up swimming, winded.
  - while down she holds the `knockdown` status (cannot_act: no walk, roll, swing, tackle, kick; its HUD chip), topped
    up while down and cleared when she stands.
  - afterwards: new `winded` status (statuses.json, 3 s, move x0.6, flags `no_sprint` + new `no_attack`, cough puffs,
    chip icon = the smoke-inhalation lungs), the `winded` idle (hands on knees, deep fast breaths) and a "Winded" notice.
  - the Knockdown status from anything else (species `status_applied` tokens, the ankylosaur's tail smash) now lays her
    down too, lying out the status (it used to freeze her standing for 4 s with no clip).
  - already down: a throw relaunches her, a ram shoves her along the ground (or back down if she was getting up);
    nothing lands in the air.
  - Pinned wins (the knock state ends and PINFEEL lays her down its own way); death cancels it.
  - Mounted: a throw-tier hit dismounts her and throws her; a knockdown-tier hit leaves her in the saddle with the old shove.
  - GOD mode: reactions all play, no damage (they never touch health).
- Wiring: `PlayerSim.shove(push, stagger_s, lift_mps, who)` asks PlayerKnock first; `TacticalBrain` passes the attacker
  on the charge impact and the horn-ram (`heavy_shove_m`) shove. `ClubTailBrain` (ankylosaur, another agent's file) is
  untouched: its shoves count at size 1.0. `hunt.gd` swings, tactics and ranged fire refuse under `no_attack`.
  `PlayerAnim`: `play_knock` / `end_knock`, the knock clips are never replaced by a flinch, `winded` is a mood idle.
- Clips (`game/assets/characters/survivor/anim/`): `fall_back` 1.3 s, `airborne` 1 s loop, `lie` 2 s loop, `get_up`
  1.6 s, `winded` 2 s loop. Built by `tools/make_knockdown_clips.py` (Blender, ~5 s) from knockdown.glb, sleep_up.glb
  (KayKit Lie_StandUp; its lying pose matches the knockdown's last frame) and idle_exhausted.glb: per-bone slerp
  between key poses plus small procedural layers. Every frame the skinned mesh is evaluated and the hips raised so the
  lowest vertex is at 0.015 m (seated, lying and standing frames are also lowered onto it): no foot or body through
  the floor, nothing floating (script prints the min/max lowest vertex per clip).
- Lab: `--knockshots=DIR` in the creature lab (with `--species=X`) fires the brain's real charge impact on the survivor
  and saves one shot per phase. Review shots: `docs/orchestration/reports/knockdown/` (`strip_*.png` Blender strips
  front + side with a floor line; `game_*.png` in-game, triceratops / woolly rhino / pachy).
- `docs/current/fight-lab.md`: a row for the survivor reactions, and the knock-shots command.

## Which moves throw and which knock down (current data)

| Move | push x size | Tier |
|---|---|---|
| Triceratops charge | 4.0 x 1.5 = 6.0 | throw |
| Carnotaurus charge | 3.5 x 1.5 = 5.25 | throw (hooked 60 deg off the line) |
| Carnotaurus horn ram (heavy_shove) | 4.0 x 1.5 = 6.0 | throw |
| Woolly rhino charge + horn toss | 5.0 x 0.98, lift 5.5 m/s | throw |
| Megaloceros (stag) antler charge | 4.5 x 1.32 = 5.9 | throw |
| Styracosaurus charge | 4.0 x 0.75 = 3.0 | knockdown |
| Pachycephalosaurus dome charge | 3.5 x 0.6 = 2.1 | knockdown |
| Ankylosaurus tail whip / club sweep | 3.0 / 3.5 x 1.0 | knockdown |
| Ankylosaurus tail smash | Knockdown status | knockdown |
| Any hit carrying the Knockdown token (carnotaurus, gallimimus, megaloceros, pachy, styracosaurus, triceratops, woolly rhino, velociraptor pounce) | status | knockdown |
| Zebraceratops / protoceratops ram | 2.5 x 0.6 = 1.5 | light (old shove) |
| Tarbosaurus / T. rex | pin (existing PINFEEL) | unchanged |

## Tests

- New `game/tests/t_knockdown.gd`: tiers per species; a pachy ram knocks her down (fall_back, holds Knockdown, no
  swing/roll/walk, shoved ~3.4 m), she lies, a flinch does not stand her up, she gets up; Winded (winded idle, no
  sprint/attack/tactics, x0.6) ends on time and she walks; a triceratops charge throws her 1.3 m up and 6.2 m away,
  she lands on the floor (not in it); thrown at a wall she stops at its face; GOD: a styracosaurus heavy's token lays
  her down with no health lost, and a toss still throws her.
- After the second merge of `origin/claude/mmo-overhaul`: t_knockdown, t_combat, t_tactical, t_pinfeel,
  t_kicktackle, t_mounts, t_sp_carnotaurus, t_sp_woolly_rhino and the wider subset listed in the final reply,
  t_styraco, t_roll, t_godlab, t_ankyloai, t_sp_pachycephalosaurus, t_zebra, t_movepriority, t_capture09, t_tame,
  t_alphas, t_sp_tarbosaurus, t_sp_raptor, t_sp_smilodon, t_water, t_ragdoll, t_foodtorpor, t_autoability,
  t_playerturn, t_tamingodds, t_skilltrees, t_w2_skills, t_targetui, t_rest, t_bigreach all PASS. t_bigreach's live
  triceratops approach now gets 20 s (the trike throws her; she gets up and walks back in). t_colors FAILs on
  "stegosaurus uses the placeholder boxes" (a nil material_override; no stegosaurus file differs from canon).
  run_all (`[tests] PASS`; its 4 "Nonexistent function 'new'" SCRIPT ERRORs are on canon too), `tools/smoke.sh`
  SMOKE PASS.

## ASSUMPTIONs (all in code)

Force thresholds 2 / 5, size scale height / 3 m clamped 0.6-1.5, throw lift 5 m/s when the hit has none, throw
distance 3-9 m, lie 1 s, tumble 45 % for 0.4 s, Winded 3 s / x0.6 / no sprint / no attack (roll allowed), the mount
keeps her on for a knockdown-tier hit, a hit in the air does nothing, the Knockdown token's 4 s is fall + lie + get-up.

## Not done / for the next agent

- No breath sound: the game has no audio system yet (no AudioStreamPlayer anywhere in scripts).
- No mash-to-recover (not required).
- The winded chip reuses the smoke-inhalation lungs icon; a dedicated icon is an art pass.
- Species Knockdown tokens fire on basic attacks of several species (gallimimus peck, pachy, styracosaurus...), so those
  now visibly knock her down on any landed hit. That was already a 4 s no-control freeze before; balancing which moves
  carry the token is a tuning call for the owner.
- Mounted throw is covered by code (dismount, then throw) but not by a test.
- The throw has no body spin; the tumble is the airborne flail clip plus the landing slide.
