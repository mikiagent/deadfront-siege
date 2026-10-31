# STUNLOCK: heavy and armoured species shrug off her staggers

Branch `claude/mmo-stunlock` (from `origin/claude/mmo-overhaul` 1066e9c9; canon merged back in three times, last at 91010e7f). Not merged to canon.

Owner, fight lab (`tools/fight_lab.command`, `--lab=creature_lab --god`): "ankylosaurus is getting stunlocked and not fighting back"; earlier "I should not be able to punch it over and over up close without consequence".

## What the lab player does

`--god` keeps Hunt's real attack (`Game.lab_flat_attack` off). Hunt has Auto and Auto-ability on by default, so with a target in reach every frame she:

- auto-casts the best ready ability first (`AutoAbility.try_cast`, rows in `combat_tuning.json auto_ability`): Tackle (6 dmg, 8 s cooldown, groggy, 0.8 s stagger), then Kick (4 dmg, 6 s cooldown, shove, 0.5 s stagger). GOD makes the stamina free, so both fire every time they are off cooldown;
- otherwise swings: bare hands = a punch every 1.0 s (`basic_cooldown_s`). Each landed hit staggers the animal 0.3 s (crit 0.45 s) at most once a second and plays its hit_react clip; each blunt hit also adds torpor and a 35 % chance of Groggy;
- Groggy (6 s, move -30 %) turns the next hit into a Knockdown (4 s, cannot act) only once the animal is at or under 30 % HP: the capture window, kept as designed and held out of the test.

Roll and Net are manual-only. There are no combos on the survivor's side.

## Root cause

1. **Tackle and Kick wrote `stagger_left` directly.** They skipped the once-a-second gate in `Creature._on_damaged` and TyrantBrain's armour, so even the T. rex was staggered by them.
2. **The hit stagger had no poise.** A punch a second against a one-second immunity window staggered every punch and played hit_react every time; hit_react marks the animation busy, and every brain refuses to start an attack while staggered or busy. A heavy animal spent 10-40 % of the fight frozen.
3. **The ankylosaurus deadlocked in "hold"** when she stood behind it at the wrong bearing: its sidestep test measured from her origin (her capsule centre, 1 m up), so it never passed, the walk target sat 0.1 m away and it stood still for the whole fight while she punched it. That was the "not fighting back" the owner saw.
4. **The carnotaurus charged from point blank**: the locked line ran its horns past her chest and pushed for the whole charge, so it rarely hit back up close.

## Fix

- `Creature.stagger(seconds)`: the one door for every stagger from her hits and Tackle. A poised body refuses it; anyone else is staggered at most once per stagger + `STAGGER_IMMUNE_S` 0.7 s. `_on_damaged` and `CombatTactics.tackle` call it; the kick's extra `stagger_left` write is gone.
- `CombatTactics.poised(c)` = the kick cannot shove it (`kick_push == 0`): mass_proxy >= `kick.giant_mass` 40, or listed in the new `kick.armoured` (ankylosaurus, mass 36). A poised animal plays the procedural flinch instead of hit_react, so it is never busy from her hits.
- `Creature.shove` (the kick's slide, the teleport fix) is unchanged and still always slides a kickable animal; it now also starts the immunity window.
- `ClubTailBrain._position`: the shuffle spot sits at the animal's own height.
- `ai.json horned_hunter.tactics.charge_min_m` 6.0: no straight charge from inside 6 m; up close the carnotaurus uses its point-blank horn ram and bite.

Small and medium animals (compy, raptors, pachycephalosaurus, deer) keep the same stagger: a 0.3 s hit stagger still leaves the same 1 s window as before, and the kick still shoves them.

## Check: `game/tests/t_stunlock.gd`

The survivor in GOD mode, Hunt with Auto and Auto-ability on, against each species spawned as the lab's NEXT does (one Aggressive animal 8 m ahead, on her). Species: the owner's seven plus every modelled species with mass_proxy >= giant_mass. Its HP is held full (no capture knockdown). Per species: her hits land; a poised body spends <= 1 % of the fight staggered by her or in hit_react (others <= 35 %); it starts 2+ attacks with no 16 s of her up-time between them; something it does lands on her. About 300 s.

Before and after (canon 2eecfc3e without the fix, then the merged head with it; "staggered" = staggered by her or in hit_react, share of the fight):

| Species | Poised | Before: staggered / its attack starts / hits on her | After |
|---|---|---|---|
| ankylosaurus | yes (armoured) | 24 % / 3 / 2; other runs: 27 %, 0 starts, 0 hits in 24 s (the hold deadlock) | 0 % / 3 / 2 |
| stegosaurus | yes | 41 % / 7 / 31 | 0 % / 7 / 30 |
| triceratops | yes | 19 % / 3 / 3 | 0 % / 2 / 2 (joust: one pass per wheel) |
| styracosaurus | yes | 10 % / 3 / 13 | 0 % / 2 / 4 |
| pachycephalosaurus | no (mass 7) | 7 % / 7 / 6 | 6 % / 7 / 6 |
| carnotaurus | yes | 31 % / 4 / 2 | 0 % / 3 / 3 |
| tyrannosaurus | yes | 9 % / 5 / 8 (Tackle and Kick got past its armour) | 0 % / 2 / 19 |
| allosaurus | yes | 13 % / 5 / 4 | 0 % / 5 / 5 |
| megarex | yes | 0 % / 5 / 9 | 0 % / 5 / 3 |
| therizinosaurus | yes | 9 % / 3 / 7 | 0 % / 2 / 21 |
| majungasaurus | yes | 7 % / 6 / 16 | 0 % / 5 / 33 |
| gallimimus | yes (mass 46) | 20 % / 7 / 6 | 0 % / 6 / 5 |
| tarbosaurus | yes | 23 % / 5 / 18 | 0 % / 6 / 9 |
| utahraptor | yes | 8 % / 5 / 16 | 0 % / 4 / 33 |
| spinosaurus | yes | 36 % / 14 / **0** in 30 s | 0 % / 5 / 17 |
| megatherium | yes | 24 % / 3 / 11 | 0 % / 3 / 19 |
| ceratosaurus | yes | 18 % / 9 / 11 | 0 % / 8 / 21 |
| dilophosaurus | yes | 17 % / 6 / 31 | 0 % / 7 / 32 |

On canon the test fails on 16 of the 18 (17 failures); with the fix it passes. The fight lengths differ run to run (the fight runs 14 s from her first hit, up to 30 s until it has hit back), and single runs are not deterministic, so compare the staggered column, not the counts.

## Gates (merged head d9e4eebc, canon 91010e7f merged)

| Gate | Result |
|---|---|
| t_stunlock | PASS (310 s) |
| t_ankyloclose | PASS |
| t_combat | PASS |
| t_knockdown | PASS |
| t_hitboxes | PASS |
| t_plantedflinch | PASS (poised species now flinch instead of hit_react; feet still planted) |
| t_noteleport | PASS on this head. **Flaky, also on canon**: in earlier runs one to four random small species' kick missed ("kick X missed: no hurtbox in the way", slides 0 m) and the gallimimus leap_back stepped 2.5-8 m in a frame; three runs on canon without this branch failed the same way (velociraptor, megaloceros, gallimimus). Not caused here; the kick's hitbox placement in that test needs its own look. |
| run_all.gd | `[tests] PASS` |
| `tools/smoke.sh --no-import` | SMOKE PASS |

Also passed on the first merged head: t_styrafix, t_sp_trikealpha, t_sp_woolly_rhino, t_sp_carnotaurus, t_tactical.

## Assumptions (logged as SL1-SL4 in `docs/vision/WildLandsMMO_Open_Questions.md`)

- SL1: poised = kick cannot shove it (mass >= 40, or `kick.armoured`); that includes gallimimus (46), dilophosaurus (43), ceratosaurus (48) and utahraptor (65).
- SL2: 0.7 s immunity after any stagger; the tackle's stagger now respects it.
- SL3: the ankylosaurus is no longer shoved by the kick (was 0.78 m).
- SL4: carnotaurus `charge_min_m` 6. The same 6 m on the horned_charger archetype made the triceratops circle at 5 m and never attack, so it was not applied there.

## For the next agent

- The triceratops and styracosaurus can still stall a straight charge against a survivor standing at their face (the triceratops now jousts, which mostly avoids it). Needs a point-blank shove or a back-off before the charge.
- t_noteleport is flaky on canon (see above).
- The test spawns the animal with `position` set before `add_child`: added at the origin, its body carried the survivor 8 m along as a moving platform on its first frame. Any lab or test that adds a creature and then moves it can hit the same thing.
- The fight lab itself was not run windowed; the owner should re-test the ankylosaurus, stegosaurus and carnotaurus there.
