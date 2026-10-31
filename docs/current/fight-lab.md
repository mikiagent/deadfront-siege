# Fight lab (god mode)

The creature lab with the survivor in GOD mode, for going through every modelled species and judging its
model, clips and AI in a real fight. Code: `game/scripts/dev/creature_lab.gd`, `game/scripts/dev/lab_spawn_panel.gd`,
the flag `Game.god_mode` (`game/scripts/core/game.gd`), checked in `game/scripts/combat/vitals.gd`.

## Launch

Double-click `tools/fight_lab.command` (Finder), or run:

```bash
/Applications/Godot_mono.app/Contents/MacOS/Godot --path /Users/milankinzy/Documents/deadfront-siege/.claude/worktrees/mmo-overhaul/game -- --lab=creature_lab --god --skip-charcreate
```

It runs the canon worktree (`mmo-overhaul`), windowed.

## What GOD does

- `Vitals.take_damage` lands the hit (flinch, HUD flash) but takes no health, so the survivor never dies.
- `spend_energy`, `spendable_energy` and `drain_energy` always succeed and take nothing; fatigue never rises.
- Cooldowns, creature AI and damage dealt by the survivor are unchanged.
- Dev only: `--god` counts only beside a `--lab=` (not `--lab=tutorial`); the creature lab turns it on by
  default and off when it exits. It is never saved.
- With `--god`, F is the real attack (hunt, swings, tactics 1-4) instead of the lab's flat 100 damage.

## Controls

| Button / key | Does |
|---|---|
| NEXT / T | Clears every wild animal and spawns the next species in the list: one Aggressive animal, 8 m in front, already coming at you. The info line under the buttons shows its brain, moves and fight clips |
| GOD / G | Toggles GOD mode (ON by default here) |
| SPAWN | Opens the selector: species (modelled only; "Stand-ins: on" adds the box stand-ins), count 1-6, nature, Alpha, SPAWN, CLEAR ALL |
| Alpha (in SPAWN) | NEXT spawns an alpha while it is ON |
| F, 1-4, Q, Shift | Attack, tactics, roll, sprint (as in play, see [controls.md](controls.md)) |
| 1-9 outside a fight | Force the nearest creature's clips |
| N | Enrage the nearest creature (enraged cooldowns are shorter than normal play) |
| H (or `--hitboxes`) | Hitbox debug draw: every hurtbox green, crit spots magenta ([crit_spots.md](crit_spots.md)), each attack's swept hitbox red, yellow where it touched ([hitboxes.md](hitboxes.md)) |
| 0 | Play bite_combo on the nearest creature that has one |

Buttons are 64 px tap targets; mouse, keyboard and touch all work.

## Modelled species

Moves come from the brain `Creature._make_brain` picks and the archetype's `tactics.sequences` in
`game/data/creatures/ai.json`; clips are the fight clips with an authored GLB in `game/assets/creatures/<id>/anim/`.
Verdict: approve / new animations / reject model / new moves or AI.

| Species | Brain (archetype) | Verb | Moves | Fight clips | Verdict |
|---|---|---|---|---|---|
| Ankylosaurus | ClubTailBrain (club_tail) | tail club behind, stomp / shove / tackle / tail spin in front and beside, joust from far off | behind or away: shuffles to turn its tail to you; TAIL WHIP (side sweep, knockback), TAIL SMASH (overhead slam behind it, knockdown + shockwave), CLUB SWEEP (long arc behind, also when two of you are close); order whip, whip, smash, whip, sweep; close in front: STOMP (a forefoot slammed down, area in front, knockdown) and TACKLE (a coil, then a run of up to 2.5 m into you, knockdown; also when you stand just past the stomp), then a TAIL SPIN (a 200 deg turn on a front foot that swings the club round through the front); STEGOSPIN: it never backs its tail into you (out of reach it pivots and comes head first); from 11 m or more it JOUSTS: a straight charge past you, an arc round on the run, and again; close beside it: SHOVE (head and shoulders swung into your side, 3 m knockback sideways); one punch from close makes it fight (no look-around), it waits for you to get up; each move shows a ring + its name, roll through it | alert, attack_primary, attack_heavy, tail_swipe, stomp, shove_left, shove_right, tackle, spin_left, spin_right, pivot_left, pivot_right | close moves added per owner 2026-10-31 ("hardly fighting back"); no back-in, front spin and joust added (STEGOSPIN), re-test |
| Coelophysis | TacticalBrain (flock_harass; the deinonychus profile) | flock harass, darting bites | backstep, strafe, pounce, charge, combo, ambush from cover, leap-in, back-leaps; lighter hits (pounce x2.0, combo x0.8) | alert, attack_primary, attack_heavy, bite_combo, pounce, charge, hop_back, leap_back, dodge_left, dodge_right | reworked per owner 2026-10-31, re-test |
| Megaloceros | JoustBrain (antlered, skittish-territorial) | antler joust, flees | see the stag/doe row below | | jousting per owner 2026-10-31 (claude/mmo-megajoust), re-test |
| Compsognathus | TacticalBrain (swarm) | swarm nips, four to eight at once | charge, pounce, strafe, backstep | alert, attack_primary, attack_heavy, pounce | |
| Deinonychus | TacticalBrain (pack_flanker) | pack flank, sickle-claw rake | backstep, strafe, pounce, charge, combo | alert, attack_primary, attack_heavy, bite_combo, pounce, charge | |
| Gallimimus | CreatureBrain (runner) | charge, kick, outruns you | primary, heavy after 3 primaries | alert, attack_primary, attack_heavy | |
| Megaloceros (stag, then doe on the next NEXT; SPAWN has a Body button) | JoustBrain (antlered, skittish-territorial) | antler joust (stag), low tackle (doe), rear-up stomp, rear kick | runs from the first threat, then turns and jousts, no strafing: tell (charge_crouch: stag lowers the antlers and scrapes; doe drops low) -> straight pass through you and 8 m on (stag ram / doe tackle, throws you off the line) -> wheel wide at a gallop on run_turn_left/right (9 m radius) -> tell again; the stag opens with the rut roar; the doe runs straight off 3.5 s after every pass before she wheels (more running than charging); point blank still rear-up stomp / rear kick / hook or forehoof strike; runs again under 30 % HP | alert, attack_primary, attack_heavy, kick, charge, charge_crouch, run_turn_left/right | joust + rebuilt antlers 2026-10-31 (claude/mmo-megajoust), re-test |
| Gallimimus | TacticalBrain (runner; the deinonychus profile without the pounce, skittish-territorial) | charge, kick, outruns you | runs from the first threat, then turns and fights; kick (spring-and-rake, point blank), peck, peck flurry, charge into a peck, strafe, dodge, back-hops; no pounce; runs again under 30 % HP | alert, attack_primary, attack_heavy, bite_combo, charge, hop_back, leap_back, dodge_left, dodge_right | reworked per owner 2026-10-31, re-test |
| Therizinosaurus | TacticalBrain (claw_guardian, territorial) | sickle claws: sweep, hook pull, overhead rake | turns on you inside ~14 m; threat display (rears, arms wide, claws fanned) then the hook (first hit drags you in), backhand, rear-up, double thrust; point blank the overhead rake (both arms high and trembling, bleeds) or the claw sweep (shoves you back 3 m); behind it the claws miss | alert, attack_primary, attack_heavy, bite_combo | new species 2026-10-31 (claude/mmo-sp-therizinosaurus), test |
| Pachycephalosaurus | TacticalBrain (pack_mule) | dome headbutt charge | display, charge, strafe | alert, attack_primary, attack_heavy, charge | |
| Protoceratops | TacticalBrain (pack_mule) | shoving beak, herd solidarity | display, charge, strafe | alert, attack_primary, attack_heavy, kick, charge | removed by owner 2026-10-31 |
| Raptor | TacticalBrain (pack_flanker, species tactics x1.25) | pounce, pin and bite; sickle-claw slash | crest-flare display + pounce, pounce -> pin under the foot + two bites, sickle slash point blank, the deinonychus combo, charge, back-leaps and power strafes; five colour morphs (Body button) | alert, attack_primary, attack_heavy, bite_combo, pounce, pin_stab, charge | |
| Stegosaurus (both looks: graded, ochre) | ClubTailBrain (spiked_tail) | thagomizer spin, stomps | round its rear: TAIL SPIN (a 220 deg turn on a planted front foot, the rear body and tail swept round, knockdown + 6 m knockback; spins again at once while you stay in reach); 90 deg PIVOTS on a front foot to re-aim or to turn head first; in front: STOMP (left forefoot) and REAR SLAM (rears up, both forefeet, wide area), TACKLE past the stomp; beside the shoulders: SHOVE; beside the hips: HIND STOMP; never backs into you; each move shows a ring + its name | alert, spin_left, spin_right, pivot_left, pivot_right, stomp, rear_slam, hind_stomp_left, hind_stomp_right, shove_left, shove_right, tackle | spin and stomps added per owner 2026-10-31 (STEGOSPIN), re-test |
| Styracosaurus | TacticalBrain (horned_charger + its own tactics block) | horn charge and impale | display, impale charge (paw, run, impale or miss, recover), horn swipe, kick, strafe | alert, attack_primary, attack_heavy, kick, charge, charge_windup, impale, charge_recover | reworked per owner 2026-10-31, re-test |
| Triceratops | JoustBrain (horned_charger + joust) | full charge | display, then joust: charge through, wheel wide (10 m), charge again; no strafe | alert, attack_primary, attack_heavy | joust 2026-10-31 (claude/mmo-megajoust), re-test; no charge or turn clips (passes and wheels on the run) |
| Tyrannosaurus | TyrantBrain (tyrant) | three-phase raid: stomp, roar, tail | telegraphed bite, stomp every 3rd attack (a stomp that lands pins you under its foot), tail whip from behind, roar on spotting | alert, attack_primary, attack_heavy, tail_swipe, pin_foot | |
| Woolly rhino | TacticalBrain (horned_charger, species tactics) | paws the ground, charges and tosses with its horn | paw (display), charge + horn toss, horn sweep point blank, forefoot stamp | alert, attack_primary, attack_heavy, charge, toss | |
| Giant ground sloth | TacticalBrain (titan, species tactics on horned_charger) | rears up on its tail, hooks with its claws and crushes in a bear hug | tripod display, bear hug (grab windup -> hug -> pin + two squeezes), lumbering upright advance (super armour, topples onto her), two-arm overhead swipe (bleeds) and hooking claw pull point blank | alert, grab, pounce, pin_stab, charge, toss, attack_heavy, attack_primary | |
| Utahraptor | TacticalBrain (apex_raptor; the deinonychus profile, distances x1.4) | one devastating claw strike | backstep, strafe, pounce (x3.0), charge, combo, ambush from cover, leap-in, back-leaps | alert, attack_primary, attack_heavy, bite_combo, pounce, charge, hop_back, leap_back, dodge_left, dodge_right | reworked per owner 2026-10-31, re-test |
| Velociraptor | TacticalBrain (pack_raptor; the deinonychus profile, distances x0.75, no tree ambush) | pounce knockdown from off-screen | sniff, then the investigate hold (3 s), then backstep, side bounds round you (HOPSTRAFE), pounce, charge, combo, leap-in, back-leaps; arms grab and rake on every attack; 1.35 m tall; lighter hits (pounce x2.0, combo x0.8) | alert, investigate, sniff, attack_primary, attack_heavy, bite_combo, pounce, charge, hop_back, leap_back, dodge_left, dodge_right | hops + arms + size per owner 2026-10-31 (HOPSTRAFE), re-test |
| Zebraceratops | TacticalBrain (pack_mule) | head shove, herd solidarity | display, charge, strafe | alert, attack_primary, attack_heavy, kick, charge | |
| Big-dinosaur stomp (BIGSTOMP, every big species: tyrannosaurus, tarbosaurus, megarex, carnotaurus, triceratops, styracosaurus, woolly rhino, therizinosaurus, ceratosaurus) | BigStomp (`game/scripts/combat/big_stomp.gd`, ticked by CreatureBrain before any brain thinks) | stands under it, gets stomped | when you stand in the ring round where its foot lands (under the body): the foot is hauled up and held 0.6-0.9 s (by size) over a yellow ring with the foot's dark shadow in it ("STOMP - ROLL AWAY"), then slammed down: dust, camera shake by size and distance; in the shadow: 2.5 x attack (kills outside GOD) and pinned under the foot (pin_foot, one bite at 1.5 s, Pinned 4 s); in the ring: knocked down; roll or step out to dodge; never on someone already down; ankylosaurus keeps its own stomp; pins from any foot-pinner start only at the foot (no pulling under it) | big_stomp, pin_foot | new per owner 2026-10-31, test |
| Survivor hit reactions (KNOCKDOWN, any species) | PlayerKnock (`game/scripts/player/player_knock.gd`) | knocked on her butt, thrown | from the hit, not the species: force = shove metres x attacker height / 3 m (0.6-1.5); light (< 2) the old shove + flinch, knockdown (>= 2: zebraceratops no, pachy ram yes, a heavy hit's Knockdown token) falls on her butt then back, lies 1 s, gets up; throw (>= 5 or any horn lift: triceratops, carnotaurus charge and horn ram, woolly rhino toss, styracosaurus impale, megaloceros stag charge) flies a 3-9 m arc, lands, tumbles, gets up; then Winded 3 s (-40 % move, no sprint, no attack); throw-tier hits unseat a rider; GOD shows it all, no damage | survivor: fall_back, airborne, lie, get_up, winded | new 2026-10-31, test |

ClubTailBrain (ANKYLOAI, `game/scripts/creatures/brains/club_tail_brain.gd`): moves and numbers in `ai.json
archetypes.club_tail.club_moves`; test `game/tests/t_ankyloai.gd`; review shots `--lab=ankyloai_lab --out=DIR`.
ANKYLOCLOSE: the close moves and the zone that draws them are `ai.json archetypes.club_tail.close_moves` / `close_zone`;
test `game/tests/t_ankyloclose.gd`; review shots `--lab=ankyloai_lab --out=DIR --moves=stomp,shove_right,tackle`.

Planted flinch (owner 2026-10-31, "rattled but the feet stay planted"): a hit never moves the feet. Without an
authored hit_react the body rattles on the bones (head chain pitch + yaw, tail sway; legs and root untouched); with
one, the clip plays and the feet's drift is taken off the root bone. Code: `game/scripts/creatures/planted_flinch.gd`
(a SkeletonModifier3D on every rigged creature); test `game/tests/t_plantedflinch.gd` (run with `--fixed-fps 60`);
review shots `--lab=plantedflinch_lab --out=DIR`.

HOPSTRAFE (owner 2026-10-31: "smaller animals hop around more than they strafe, big and heavy dinosaurs strafe more than
they hop"): `TacticalBrain.reposition_style` from bulk (real_length_m x height_meters) or `tactics.reposition`. Hoppers
(compsognathus, velociraptor, coelophysis) circle in body-length side bounds with planted pauses and only sometimes
strafe-walk; strafers (triceratops, utahraptor and every TacticalBrain body of bulk 40+; gallimimus overridden to mixed) side-step on foot and
back off at a scurry, never airborne; the rest (deinonychus, raptor, megaloceros, woolly rhino) as authored. Test:
`game/tests/t_hopstrafe.gd`; numbers HS1-HS4 in the Open Questions.

No glide (owner 2026-10-31): a body never moves under a one-shot. Attacks play in place; alert, sniff and hit_react
give way to the stride-matched gait when the brain moves the body; leaps move on their own arc. Test:
`game/tests/t_compyfeel.gd` (planted-toe slide per step, live fights for compsognathus, deinonychus, ankylosaurus).


STEGOSPIN (`ClubTailBrain`, data `ai.json archetypes.spiked_tail` and `club_tail`): turn moves (spin, pivot) turn the body in
code in step with the clip about a planted front foot. Test `game/tests/t_stegospin.gd`; review shots
`--lab=stegospin_lab --out=DIR [--species=ankylosaurus] [--variant=ochre] [--moves=spin_right,stomp,joust]`.

One deinonychus profile (owner 2026-10-31): `ai.json` pack_flanker tactics. Coelophysis, Gallimimus, Utahraptor and
Velociraptor name it as `"tactics": {"base": "pack_flanker", "scale": k, ...overrides}` in their species JSON
(`TacticalBrain.resolve`: distances x scale, then the overrides). Their attack, combo, pounce, charge and leap clips
are the deinonychus clips moved onto each rig (`tools/gait/transfer_clips.py --floor-feet --pin-toes`).

Skittish-territorial (Gallimimus, Megaloceros; `tactics.territorial` in `ai.json`): the first threat sends it running;
after 3 s, or when the flight outruns the leash, it turns on the threat (within 30 m) and fights while the threat stays.
Under 30 % HP it runs again; once the threat is gone it grazes and the cycle restarts. Test: `game/tests/t_coelomoves.gd`.

Knock shots: `-- --lab=creature_lab --god --skip-charcreate --species=triceratops --knockshots=DIR` (windowed, off screen
with `--position 6000,3000`) fires the brain's charge impact on the survivor and saves one shot per phase (airborne,
fall, lie, get_up, winded), then quits. Clips: `tools/make_knockdown_clips.py`. Test: `game/tests/t_knockdown.gd`.

Stomp shots: `-- --lab=creature_lab --god --skip-charcreate --species=tyrannosaurus --stompshots=DIR` (windowed, off screen
with `--position 6000,3000`) saves the wind-up (game camera and a three-quarter), the slam and the stomp-pin as
DIR/<species>_<k>_<what>.png, then quits. Data: `ai.json big_stomp`; clips: `tools/gait/make_big_stomp.py` (+
`tools/gait/big_stomp.json`, gate `check_big_stomp.py`), the tyrannosaurs `make_rex_moves.py big_stomp`. Test:
`game/tests/t_bigstomp.gd`.

Cornered (owner 2026-10-31: "Animals that run away from you should get territorial and attack you if you chase them";
`BrainCornered`, on every brain): any animal that is fleeing (skittish grazers on sight, defensive grazers and Timid
natures after a big hit) and is chased turns and fights. Chasing = within 10 m and moving at it at 1.5 m/s or more, or
hitting it (+1.5 s each). After 3 s of that, or 20 m of pursuit, it stops, plays its display clip (alert today; roar,
crest_flare or stomp first when a rig has one) and fights with its own attacks for 12 s; under 30 % HP it runs again.
Stand still and it keeps running. Numbers: `ai.json default.cornered`, per species a `"cornered"` block in its tactics.
Test: `game/tests/t_cornered.gd`.

| Species | Brain | Flees when | Chased into a fight |
|---|---|---|---|
| Zebraceratops, Pachycephalosaurus, Protoceratops (pack_mule, skittish) | TacticalBrain | on sight | its display, charge, shove, kick |
| Gallimimus (runner), Megaloceros (antlered) | TacticalBrain | on sight | its fight; it also still turns by itself after one 3 s flight (territorial) |
| Stegosaurus (defensive), Triceratops, Styracosaurus, Woolly rhino (territorial) | CreatureBrain / TacticalBrain | a big hit while not provoked | its own attacks |
| Any species with the Timid nature | any | a big hit (retreat_as_flee) | its own attacks (Timid no longer means never fights back once chased) |
| Not affected | | swarm and pack flights (`_flee_left`, compsognathus, mate-death scatter), a Timid rage (enrage_flee); every other brain (ClubTail, Tyrant, MegaRex) inherits the rule whenever it is in `flee` | |

Pin shots: `-- --lab=creature_lab --god --skip-charcreate --species=tyrannosaurus --pinshots=DIR` (windowed, off
screen with `--position 6000,3000`) saves the stomp, the foot pin and the release, then quits. Test: `game/tests/t_pinfeel.gd`.

## Styracosaurus (reworked per owner 2026-10-31, re-test)

Owner on the first pass: "make styracosaurus bigger by like 3x. the animations and brain needs some work. Its like
bugging out though". Now 6.75 m tall and 15.2 m long (3x), turning at 1.4 rad/s. Its charge:
1. **Paw**: it stops, lowers its horns and paws the ground with a fore-foot (charge_windup), turning onto you.
   It paws again until it is aimed. Hits do not interrupt it.
2. **Run**: a straight line in the direction it faced, locked at the end of the paw, no steering. It speeds up over
   0.5 s on the charge clip and its feet keep pace with the ground.
3. **Impale**: when you are where its horns will dip, it stops, scoops you up on the nose horn, carries you up and
   throws you ahead (heavy hit plus knockdown).
   - If you are beside the line against its flank, you are shoved aside instead.
   - If you step or roll off the line during the run, it misses, slows to a stop and stands winded for 2 s
     (charge_recover). Hits during that time flinch it.
4. It only charges from 10 m or more. Up close it uses the horn swipe in front and the hind kick behind.

Headless check: `game/tests/t_styrafix.gd` (60 s GOD fight, per-frame state and clip log with `-- --log=PATH`).
Shots: `--lab=creature_lab --god --impaleshots=DIR` saves one frame per charge phase, then quits.

Test: `game/tests/t_godlab.gd` (GOD survives a T. rex bite chain at full health, off without `--god`; NEXT
cycles every modelled species, one model each).

Reach on big bodies (BIGREACH): a swing is in reach by the old centre rule or when the survivor's edge is within
`player_melee.edge_reach_m` (0.5 m) of the creature's visible footprint (`Creature.footprint()`, mesh bounds), so
the flank, legs, head and tail all count; auto-attack walks to the nearest point of that footprint, not the centre.
The collision capsule is clamped to the visible half-width. Test: `game/tests/t_bigreach.gd`.

JOUST (MEGAJOUST, owner 2026-10-31: "a deer would normally charge and do a circle and charge again. Like a joust"; "the
jousting brain is good for many of the four legged animals"): any species opts in with a `joust` block in its tactics
profile (`game/scripts/creatures/brains/joust_brain.gd`, keys in its header). Megaloceros (stag, doe), woolly rhino,
triceratops and zebraceratops use it. A rig with `charge_crouch` plays it as the tell, with `run_turn_left/right` it wheels
on them (planted hooves follow the arc; megaloceros only), else on its run. Test: `game/tests/t_megajoust.gd`; review
shots: `--lab=megajoust_lab --out=DIR [--before=res://...glb] [--species=megaloceros:stag,woolly_rhino:]` (windowed,
`--position 6000,3000`, self-quitting).
