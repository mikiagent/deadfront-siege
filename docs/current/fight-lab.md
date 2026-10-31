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
| 0 | Play bite_combo on the nearest creature that has one |

Buttons are 64 px tap targets; mouse, keyboard and touch all work.

## Modelled species

Moves come from the brain `Creature._make_brain` picks and the archetype's `tactics.sequences` in
`game/data/creatures/ai.json`; clips are the fight clips with an authored GLB in `game/assets/creatures/<id>/anim/`.
Verdict: approve / new animations / reject model / new moves or AI.

| Species | Brain (archetype) | Verb | Moves | Fight clips | Verdict |
|---|---|---|---|---|---|
| Ankylosaurus | CreatureBrain (club_tail) | tail club | primary, heavy after 3 primaries | alert, attack_primary, attack_heavy | |
| Coelophysis | CreatureBrain (flock_harass) | flock harass, darting bites | primary, heavy after 3 primaries | alert, attack_primary, attack_heavy | |
| Compsognathus | TacticalBrain (swarm) | swarm nips, four to eight at once | charge, pounce, strafe, backstep | alert, attack_primary, attack_heavy, pounce | |
| Deinonychus | TacticalBrain (pack_flanker) | pack flank, sickle-claw rake | backstep, strafe, pounce, charge, combo | alert, attack_primary, attack_heavy, bite_combo, pounce, charge | |
| Gallimimus | CreatureBrain (runner) | charge, kick, outruns you | primary, heavy after 3 primaries | alert, attack_primary, attack_heavy | |
| Megaloceros | CreatureBrain (antlered) | antler gore, flees | primary, heavy after 3 primaries | alert, attack_primary, attack_heavy, kick, charge | |
| Pachycephalosaurus | TacticalBrain (pack_mule) | dome headbutt charge | display, charge, strafe | alert, attack_primary, attack_heavy, charge | |
| Protoceratops | TacticalBrain (pack_mule) | shoving beak, herd solidarity | display, charge, strafe | alert, attack_primary, attack_heavy, kick, charge | removed by owner 2026-10-31 |
| Stegosaurus | CreatureBrain (spiked_tail) | thagomizer tail sweep | primary, heavy after 3 primaries | alert, attack_primary, attack_heavy, kick, charge | |
| Styracosaurus | TacticalBrain (horned_charger) | horn sweep, knockback | display, charge, strafe | alert, attack_primary, attack_heavy, kick, charge | |
| Triceratops | TacticalBrain (horned_charger) | full charge | display, charge, strafe | alert, attack_primary, attack_heavy | |
| Tyrannosaurus | TyrantBrain (tyrant) | three-phase raid: stomp, roar, tail | telegraphed bite, stomp every 3rd attack (a stomp that lands pins you under its foot), tail whip from behind, roar on spotting | alert, attack_primary, attack_heavy, tail_swipe, pin_foot | |
| Utahraptor | RaptorPackBrain (apex_raptor) | one devastating claw strike | pack flank, bites, heavy pounce from 4-7 m off-axis | alert, attack_primary, attack_heavy | |
| Velociraptor | RaptorPackBrain (pack_raptor) | pounce knockdown from off-screen | pack flank, bites, heavy pounce from 4-7 m off-axis | alert, attack_primary, attack_heavy | |
| Zebraceratops | TacticalBrain (pack_mule) | head shove, herd solidarity | display, charge, strafe | alert, attack_primary, attack_heavy, kick, charge | |

CreatureBrain swings attack_primary and attack_heavy only, so the kick clips of Megaloceros and Stegosaurus do
not show in a fight, and verbs such as Gallimimus "kick" have no move behind them yet.

Pin shots: `-- --lab=creature_lab --god --skip-charcreate --species=tyrannosaurus --pinshots=DIR` (windowed, off
screen with `--position 6000,3000`) saves the stomp, the foot pin and the release, then quits. Test: `game/tests/t_pinfeel.gd`.

Test: `game/tests/t_godlab.gd` (GOD survives a T. rex bite chain at full health, off without `--god`; NEXT
cycles every modelled species, one model each).
