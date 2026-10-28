# Creature clips (current build)

What every creature rig ships in `game/assets/creatures/<id>/`. Generated 2026-10-28 from the files on
`claude/mmo-jaws`; regenerate when clips change. How they are made: [creature pipeline plan](../orchestration/mmo/creature-pipeline-plan.md);
timing data (hit fractions, airborne windows): `game/data/creatures/anim_events.json`.

| species | jaw | wings | alert | attack_heavy | attack_primary | bite_combo | charge | death | dodge_left | dodge_right | feed | hit_react | hop_back | idle | kick | knockdown | leap_back | pounce | run | sleep | strafe_left | strafe_right | tail_swipe | walk | walk_back |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| coelophysis | yes | - | x | x | x |  |  | x |  |  | x | x |  | x |  | x |  |  | x | x | x | x |  | x | x |
| compsognathus | yes | - | x | x | x |  |  | x |  |  | x | x |  | x |  | x |  |  | x | x | x | x |  | x | x |
| deinonychus | yes | yes | x | x | x | x |  | x | x | x |  | x | x | x |  | x | x | x | x |  | x | x |  | x | x |
| gallimimus | - | - | x | x | x |  |  | x |  |  | x | x |  | x |  | x |  |  | x | x | x | x |  | x | x |
| megaloceros | - | - | x | x | x |  | x | x |  |  | x | x |  | x | x | x |  |  | x | x | x | x |  | x | x |
| protoceratops | - | - | x | x | x |  | x | x |  |  | x | x |  | x | x | x |  |  | x | x | x | x |  | x | x |
| stegosaurus | yes | - | x | x | x |  | x | x |  |  |  | x |  | x | x | x |  |  | x |  | x | x |  | x | x |
| tyrannosaurus | yes | - | x | x | x |  |  | x |  |  | x | x |  | x |  | x |  |  | x | x | x | x | x | x | x |
| utahraptor | yes | - | x | x | x |  |  | x |  |  | x | x |  | x |  | x |  |  | x | x | x | x |  | x | x |
| velociraptor | yes | - | x | x | x |  |  | x |  |  | x | x |  | x |  | x |  |  | x | x | x | x |  | x | x |
| zebraceratops | yes | - | x | x | x |  | x | x |  |  | x | x |  | x | x | x |  |  | x | x | x | x |  | x | x |

Open: gallimimus has no jaw (toothless beak with no painted mouth seam; three tries tore the throat, waiting on a
repainted seam or a parted-beak sheet). Clips beyond the contract (bite_combo, pounce, leaps, dodges, strafes,
walk_back, kick, charge) load once `CreatureClips.OPTIONAL` lists them.
