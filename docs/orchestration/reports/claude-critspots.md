# CRITSPOTS: crit spots on every animal, on the hurtboxes

Branch `claude/mmo-critspots`, from `origin/claude/mmo-overhaul`. Not merged to canon. No credits spent.

Owner (Milan): "since we have hitboxes now, I want you to add crit spots to every animal".

How it works: `docs/current/crit_spots.md`. Assumptions: CS1-CS6 in `docs/vision/WildLandsMMO_Open_Questions.md`.

## What shipped
- **Data**: `game/data/creatures/hitboxes.json` `crit_spots`. Every species has 1-3 spots: a sphere on a real bone, with an offset and a radius.
  - Placed from each rig's rest-pose bones and hurtboxes. `t_hitboxes.gd -- --bones` is a new mode of the calibration tooling that prints them.
  - The spots scale with the genome size and turn with their bone.
  - Shared default: x2.0, radius 0.3 m. Per-spot overrides set the radius and mult; the armoured species' spots use x2.5.
  - Stand-ins with no rig (brachiosaurus, the retired protoceratops) fall back to a default head spot. A new rigged species with no row gets a head spot on its `Head` bone, but `t_critspots` fails until it has its own row.
- **Rules** (`game/scripts/combat/crit_spots.gd`), all in the shared hit resolution:
  - `Hitbox._sweep` checks the segment that first touches a hurtbox against the target's spots and puts the spot on the hit.
  - `Hunt.land_hit` makes a spot hit a sure crit at the spot's mult. Any other hit rolls the chance crit as before (crit_base, crit_behind, per level, x1.75). The two never stack.
  - Kick, tackle and stones use the same `CritSpots.land`. Brains are untouched.
- **Feedback**:
  - a gold hit flash and a gold burst out of the spot's bone, instead of the body burst;
  - a gold "WEAK SPOT -N!" float;
  - camera shake 0.45 (`combat_tuning.json camera.weak_spot`);
  - a 0.08 s hit-stop on the target's animation.
  - Teaching (ASSUMPTION CS5): after the first weak-spot hit on an animal, its spots glow faintly gold through its body for the rest of its life (`CritSpotMarks`). Nothing depends on hover.
  - The H debug view draws every animal's spots magenta.
- **No damage retune**. The only new numbers are the spot mults and radii, all marked ASSUMPTION.
- **Docs**: `docs/current/crit_spots.md`, plus a README row and notes in the fight-lab and hitbox docs. Review lab: `--lab=critspot_lab --out=DIR`.

## Spots per species
Multiplier x2.0 unless shown. Heights are at rest and size 1; idle poses carry heads lower. A survivor's swing reaches about 2.1 m.

| Species | Spot | Bone | Radius (m, size 1) | Mult | Centre height at rest (m, size 1) |
|---|---|---|---|---|---|
| allosaurus | head | Head | 0.54 | 2.0 | 5.79 (ranged / out of reach on foot) |
| allosaurus | hamstring_L | Shin.L | 0.30 | 2.0 | 2.31 |
| allosaurus | hamstring_R | Shin.R | 0.30 | 2.0 | 2.31 |
| ankylosaurus | belly | Body | 0.22 | 2.5 | 0.36 |
| ankylosaurus | throat | Neck | 0.20 | 2.5 | 0.55 |
| carnotaurus | head | Head | 0.53 | 2.0 | 5.09 (ranged / out of reach on foot) |
| carnotaurus | hamstring_L | BackLowLeg.L | 0.30 | 2.0 | 1.16 |
| carnotaurus | hamstring_R | BackLowLeg.R | 0.30 | 2.0 | 1.16 |
| ceratosaurus | head | Head | 0.37 | 2.0 | 3.50 (ranged / out of reach on foot) |
| ceratosaurus | hamstring_L | Shin.L | 0.30 | 2.0 | 1.35 |
| ceratosaurus | hamstring_R | Shin.R | 0.30 | 2.0 | 1.35 |
| coelophysis | head | Head | 0.15 | 2.0 | 1.85 |
| compsognathus | head | Head | 0.12 | 2.0 | 1.10 |
| deinonychus | head | Head | 0.18 | 2.0 | 2.67 (ranged / out of reach on foot) |
| dilophosaurus | head | Head | 0.27 | 2.0 | 3.13 (ranged / out of reach on foot) |
| gallimimus | head | Head | 0.12 | 2.0 | 3.64 (ranged / out of reach on foot) |
| gallimimus | hamstring_L | Shin.L | 0.30 | 2.0 | 1.22 |
| gallimimus | hamstring_R | Shin.R | 0.30 | 2.0 | 1.22 |
| majungasaurus | head | Head | 0.43 | 2.0 | 4.53 (ranged / out of reach on foot) |
| majungasaurus | hamstring_L | Shin.L | 0.30 | 2.0 | 1.51 |
| majungasaurus | hamstring_R | Shin.R | 0.30 | 2.0 | 1.51 |
| megaloceros | neck | Neck | 0.30 | 2.0 | 2.25 |
| megarex | head | Head | 0.90 | 2.0 | 8.23 (ranged / out of reach on foot) |
| megarex | hamstring_L | Shin.L | 0.50 | 2.0 | 2.75 (ranged / out of reach on foot) |
| megarex | hamstring_R | Shin.R | 0.50 | 2.0 | 2.75 (ranged / out of reach on foot) |
| megatherium | neck | Neck | 0.35 | 2.0 | 2.27 |
| megatherium | belly | Torso | 0.35 | 2.0 | 1.02 |
| pachycephalosaurus | throat | Neck1 | 0.15 | 2.0 | 1.24 |
| raptor | head | Head | 0.29 | 2.0 | 3.02 (ranged / out of reach on foot) |
| smilodon | throat | Neck | 0.20 | 2.0 | 1.24 |
| spinosaurus | head | Head | 0.60 | 2.0 | 6.31 (ranged / out of reach on foot) |
| spinosaurus | hamstring_L | Shin.L | 0.30 | 2.0 | 2.78 (ranged / out of reach on foot) |
| spinosaurus | hamstring_R | Shin.R | 0.30 | 2.0 | 2.78 (ranged / out of reach on foot) |
| stegosaurus | belly | spine_02 | 0.30 | 2.5 | 2.21 |
| stegosaurus | throat | neck_01 | 0.25 | 2.5 | 2.96 (ranged / out of reach on foot) |
| styracosaurus | behind_frill | Neck | 0.35 | 2.5 | 4.79 (ranged / out of reach on foot) |
| styracosaurus | belly | Torso | 0.30 | 2.5 | 1.94 |
| tarbosaurus | head | Head | 0.82 | 2.0 | 5.79 (ranged / out of reach on foot) |
| tarbosaurus | hamstring_L | Shin.L | 0.30 | 2.0 | 2.30 |
| tarbosaurus | hamstring_R | Shin.R | 0.30 | 2.0 | 2.30 |
| therizinosaurus | head | Head | 0.54 | 2.0 | 7.39 (ranged / out of reach on foot) |
| therizinosaurus | hamstring_L | Shin.L | 0.30 | 2.0 | 2.14 |
| therizinosaurus | hamstring_R | Shin.R | 0.30 | 2.0 | 2.14 |
| triceratops | behind_frill | Neck1 | 0.30 | 2.5 | 3.10 (ranged / out of reach on foot) |
| triceratops | belly | Spine1 | 0.30 | 2.5 | 0.87 |
| tyrannosaurus | head | Head | 0.74 | 2.0 | 6.98 (ranged / out of reach on foot) |
| tyrannosaurus | hamstring_L | Shin.L | 0.30 | 2.0 | 1.55 |
| tyrannosaurus | hamstring_R | Shin.R | 0.30 | 2.0 | 1.55 |
| utahraptor | head | Head | 0.55 | 2.0 | 4.16 (ranged / out of reach on foot) |
| utahraptor | hamstring_L | BackLowLeg.L | 0.30 | 2.0 | 0.55 |
| utahraptor | hamstring_R | BackLowLeg.R | 0.30 | 2.0 | 0.55 |
| velociraptor | head | Head | 0.12 | 2.0 | 1.17 |
| woolly_rhino | hump | Shoulders | 0.35 | 2.0 | 2.59 (ranged / out of reach on foot) |
| woolly_rhino | neck | Neck2 | 0.30 | 2.0 | 1.51 |
| zebraceratops | behind_frill | Neck | 0.18 | 2.0 | 1.51 |
| brachiosaurus (stand-in) | head | none (fallback) | 0.35 | 2.0 | 85 % of height |
| protoceratops (retired stand-in) | head | none (fallback) | 0.35 | 2.0 | 85 % of height |

The stand-in heights are 85 % of the body's height.

## Shots (`docs/orchestration/reports/critspots/`)
All shots come from windowed off-screen runs that quit themselves: `--position 6000,3000 -- --skip-charcreate --lab=critspot_lab --out=DIR`.
- `velociraptor.png`, `tyrannosaurus.png`, `ankylosaurus.png`, `stegosaurus.png`, `triceratops.png`, `woolly_rhino.png`: the H debug view, with hurtboxes in green and crit spots in magenta.
- `crit_landing.png`: the game camera on the survivor's real auto-attack. The lab moved her around a velociraptor until a swing landed in its head (natural, not scripted; it took 9 to 24 tries across runs). The shot shows the gold "WEAK SPOT -1!" float, the gold flash, and the glow on the spot. The damage is 1 because the lab's raptor has 1e9 HP.

## Gates (final tree, after merging canon at carnofeel + stegoslam)
- New test `game/tests/t_critspots.gd`: **PASS**. It checks:
  - Every species in `data/creatures` has 1-3 spots, including the stand-ins. Every modelled species has its own row.
  - Every spot bone exists on each model (base, triceratops alpha, megaloceros doe), and every spot sits on the body.
  - A sweep through a spot, run through `Hitbox._sweep`, carries the spot. The swing then crits at exactly the spot's mult (velociraptor, ankylosaurus, T. rex, woolly rhino).
  - A hit on the body away from every spot carries no spot. It does not crit when the chance crit is 0, and crits at x1.75 when the chance is 1.
  - A stone through a spot hits at the spot's mult.
  - The feedback fires: the WEAK SPOT kind, a burst on the spot, the gold flash, the hit-stop holding and then releasing, the glow after the first hit, and magenta in the H view.
- `t_hitboxes` PASS, `t_combat` PASS, `t_knockdown` PASS.
- `run_all.gd`: `[tests] PASS`.
- `tools/smoke.sh --no-import`: SMOKE PASS.
- No new species landed in the merges. Carnofeel and stegoslam changed only moves.

## For the next agent
- **A new species**: run `godot --headless --path game --script res://tests/t_hitboxes.gd -- --bones`, then add `crit_spots.species.<id>` with offsets measured from the bone origin. `t_critspots` fails until the row exists.
- **Reach**: the heads of the big theropods, the styracosaurus frill and the stegosaurus throat are out of reach on foot. Melee gets the hamstrings and bellies; the rest is for ranged or mounts later.
- **Ranged shortcut (CS6)**: a stone is tested along its flight into the body's collision capsule. A spot outside that capsule, such as a T. rex head, cannot be shot until stones test the hurtboxes on layer 20.
- **Not done**:
  - The server's `act.attack` has no hitboxes, so it keeps only the chance crit.
  - Creature-on-creature and creature-on-survivor hits ignore spots.
  - The camera shake is not asserted in the test, because a headless run has no IsoCamera. It is visible in the lab.
- **Balance**: every mult and radius is an ASSUMPTION waiting for the balance pass (systems before balance).
