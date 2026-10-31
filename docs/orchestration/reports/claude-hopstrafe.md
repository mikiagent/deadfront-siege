# HOPSTRAFE: small animals hop, big ones strafe; velociraptor arms and size

Branch `claude/mmo-hopstrafe` (from `origin/claude/mmo-overhaul` ead77769, merged again with the current canon). Pushed, not merged. No credits spent (Tripo 0, Meshy 0).

The owner's verdict, word for word: "velociraptor seems too small or something. it should also use arms in attacks. the strafe is too small of a step because it's so small it looks like twinkletoes or like an agility drill. new general rule: smaller animals hop around more than they strafe, big and heavy dinosaurs strafe more than they hop"

## The rule (TacticalBrain)
- `TacticalBrain.reposition_style(def)` picks a style for each species. It reads `tactics.reposition` (`hop`, `strafe` or `mixed`) when the species sets one. Otherwise it uses bulk, which is real_length_m x height_meters (the same mass proxy the kick-shove uses):
  - bulk 15 or less, with dodge_left/right clips: **hop**;
  - bulk 40 or more: **strafe**;
  - anything in between: **mixed**, which is the profile as authored.
- **hop**:
  - Circling becomes bounds. The animal stands planted for 0.3-0.7 s, facing the prey, then either takes a side bound along the ring (50 %) or strafe-walks for 0.6-1.1 s (50 %).
  - Its dodges and back-offs were already leaps. Back-hops are now twice as likely.
  - A bound covers max(strafe_m, one body length). Body length = 0.8 x real_length_m x genetic size.
  - The flight lasts as long as a real jump of that arc height, 2 sqrt(2h/g). The clip stretches up to 2x through the new `CreatureAnim.stretch` to cover it.
  - It turns only while airborne, so landed feet don't pivot on their prints.
  - A short ring arcs at most 120 deg around the prey.
  - A leap-in that lands short runs the last steps into the bite or combo. Hoppers don't creep into the jaws on the ring, so without this their combos never fired.
- **strafe**: filler dodges become walked side-steps (the strafe clip, at the ring pace). Sequence strafe_left/right steps are walked too. Back-offs scurry. The body never leaves the ground.
- New signal `reposition(kind)` (`hop` or `strafe`) for tests, and `last_hop`.

| Style | Species |
|---|---|
| hop | compsognathus (3.6), velociraptor (6.2), coelophysis (12.0) |
| strafe | triceratops, stegosaurus, tyrannosaurus, utahraptor (64.7), styracosaurus, tarbosaurus, carnotaurus, ceratosaurus, dilophosaurus, therizinosaurus, megarex, allosaurus, brachiosaurus |
| mixed (unchanged) | deinonychus (17.2), raptor, megaloceros, woolly rhino, ankylosaurus (36, ClubTailBrain anyway) |
| mixed: small, but its rig has no side-hop clips | pachycephalosaurus, zebraceratops, protoceratops, smilodon |
| mixed by override | gallimimus (`"reposition": "mixed"`): a light runner, so its bulk of 45.6 should not make it a strafer |

Stegosaurus and ankylosaurus run other brains (CreatureBrain and ClubTailBrain). Neither ever jumps; t_hopstrafe checks the stegosaurus.

**Deinonychus is not a hopper.** It stands 2.87 m, above the survivor's head, and t_tactical pins its authored profile. Setting `"reposition": "hop"` in its JSON makes it bound. That needs the owner's call (HS1).

**Utahraptor became a strafer.** Its dodges are now walked and its back-offs scurry. claude/mmo-raptorflank also touches the utahraptor (arms), but only its clips, so the files do not conflict. Worth a look in the lab.

## Velociraptor
- **Scale:**
  - height_meters 1.06 -> **1.35** (x1.27), which is 3.67 m long on screen;
  - real_length_m 3.6 -> **4.6**: still the small pen, and bulk 6.2 keeps it a hopper;
  - before the change its head sat about at the survivor's hip, a turkey next to her (`hopstrafe/before/lineup.png`). Now it is about chest high (`hopstrafe/lineup.png`);
  - it is still the smallest raptor (deinonychus 4.81 m, utahraptor 11.19 m);
  - it still cannot be ridden: seat 0.85 m x 1.6 = 1.35 m, under the 1.78 m rider. `mounts_skip.json` is updated and t_mounts passes;
  - this breaks the 1.8 : 3 : 7 chart ratio (it is now 2.3 : 3 : 7), and the compy is now shorter than it (HS4).
- **Arms:** the new `tools/gait/add_arm_strikes.py` adds keys to the arm bones only (FrontUpLeg, FrontLowLeg and FrontFoot); every other channel stays as it was.
  - On each hit (anim_events hit fracs), the arms cock back, flare out and open the claws, then rake forward and down with the hands curling.
  - bite_combo alternates the leading arm. The pounce flares the arms in the air and rakes on the hit. The charge loop holds the arms out and flared.
  - Clips changed: attack_primary, attack_heavy, bite_combo, pounce, charge.
  - Measured against the body: the upper arms swing 79-108 deg and the hands 56-99 deg.
- **Twinkle-toe strafe:** circling is now body-length bounds. In the t_hopstrafe fight it started 11 bounds and 0 strafes.

## Clips
- dodge_left, dodge_right and hop_back for the **velociraptor and coelophysis** were rebuilt with `tools/gait/make_leap.py` (IK-planted toes).
- The old clips, transferred from the deinonychus, slid 7.4 cm (velociraptor) and 11.8 cm (coelophysis) on their ground frames (`check_leap.py`: FAIL). In the game they slid about 30 cm on landing. The new clips slide 0.00 cm (PASS).
- The compsognathus already had make_leap clips. The deinonychus, utahraptor and gallimimus clips are untouched.

## Tests
- **New `game/tests/t_hopstrafe.gd`: PASS.** It checks:
  - the style table above;
  - the velociraptor is at least 1.3 m tall, and its arms swing at least 40 deg in all four attacks;
  - live 30 s fights against a stationary survivor: velociraptor 11 bounds / 0 strafes, compsognathus 12 / 3, coelophysis 11 / 0 (the limit is at least 60 % bounds);
  - every side bound is at least 0.9 of a body length (velociraptor at least 3.08 m, coelophysis 3.73 m, compy 1.87 m, at their genetic sizes);
  - landed toes move at most 5 % of height (4.7, 2.8 and 3.5 cm). The old transferred clips moved 30-33 cm here;
  - the triceratops makes 12 strafes, 0 hops and 0 airborne frames. The stegosaurus has 0 airborne frames.
- **`t_compyfeel` changed.** "Compy circling plays strafes > 30 frames" is now "bounds outnumber ring strafes, and it still strafes more than 10 frames" (686 vs 66 frames). The brain's own dice are now seeded, so the fight replays the same.
- **Gates after the final merge:** t_hopstrafe, t_raptorfeel, t_coelomoves, t_compyfeel, t_combat, t_tactical, t_canim, t_noboxes, t_mounts, t_saddles PASS. `run_all.gd` `[tests] PASS`. `tools/smoke.sh --no-import` SMOKE PASS.
- **Merge:** canon brought SMILORUN's own `_bound(delta)`, so my leap helper is renamed `_hop_leap`. A duplicate-func check over the merged .gd files is clean. The anim_events and tactical_brain conflicts were resolved by keeping both sides.

## Shots (`docs/orchestration/reports/hopstrafe/`)
- `lineup.png` (after) and `before/lineup.png`: survivor, velociraptor, deinonychus, utahraptor, side-on.
- `velociraptor_attack_primary`, `_attack_heavy`, `_bite_combo`, `_pounce` and `_charge.png`: the arm strikes, as in-engine clip sheets.
- `velociraptor_dodge_left`, `_hop_back`, `coelophysis_dodge_left` and `_hop_back.png`: the rebuilt bounds.

All were taken windowed at `--position 6000,3000`, and each run quit by itself.

## Assumptions (Open Questions HS1-HS4)
- HS1: the bulk thresholds 15 and 40, and the gallimimus override.
- HS2: the 50 % bound share, the 0.3-0.7 s pauses, and back-hops at 2x.
- HS3: a bound is one body length, with real-jump flight time capped at a 2x clip stretch.
- HS4: velociraptor 1.35 m.

## Not done / for the next agent
- **Pachycephalosaurus, zebraceratops, protoceratops and smilodon** are small but have no side-hop clips, so they stay mixed. Two of them are on other branches (pachybull, smilorun). Give them dodge clips (make_leap works on the Meshy biped rig) and they hop automatically.
- **Arm rake on screen:** in the in-engine sheets it reads clearly from the side and less from the front. The arms are short on this mesh. Raise `--gain` in add_arm_strikes.py if the owner wants it bigger.
- **The velociraptor never strafe-walked in the 30 s test fight.** That is because its back-hops and dodges are bounds too. Lower HOP_SHARE if the owner wants more walking.
