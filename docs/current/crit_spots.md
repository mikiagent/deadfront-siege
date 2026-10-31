# Crit spots (weak spots)

Owner: "since we have hitboxes now, I want you to add crit spots to every animal". Code: `game/scripts/combat/crit_spots.gd`,
`crit_spot_marks.gd`. Data: `game/data/creatures/hitboxes.json` `crit_spots`. Test: `game/tests/t_critspots.gd`.
Every number is an ASSUMPTION (CS1-CS6 in `docs/vision/WildLandsMMO_Open_Questions.md`).

## Data
- `crit_spots.species.<id>`: 1-3 spots, each a sphere riding a bone: `name`, `bone`, `offset` [x right, y up, z forward]
  in metres at size 1 from the bone (measured in the rest pose, in the animal's own frame), `radius` (m at size 1),
  `mult` (default `crit_spots.default.mult`, 2.0; the armoured species use 2.5).
- Offsets and radii scale with the genome size. The spot turns with its bone.
- Placing a spot: `godot --headless --path game --script res://tests/t_hitboxes.gd -- --bones` prints every hurtbox
  and bone of every model at size 1, rest pose, in that frame. Pick the bone, measure the offset from its origin.
- A species with no row: a head spot on its first bone named `Head...`; with no rig either (a stand-in), `fallback`:
  `at` [x, y, z] as shares of its width (0.3 x length), height and length, from its feet centre.

## Rules
- Melee: `Hitbox._sweep` checks the sweep segment that first touches a hurtbox against the target's spots
  (`CritSpots.on_path`: the segment, widened by the part's radius, passes within the spot's radius of its centre). The
  spot rides on the hit as `hit.spot`.
- `Hunt.land_hit(t, w, spot)`: a spot is a sure crit, `dealt x spot.mult`, float kind `weakspot`. Otherwise the chance
  crit rolls as before (`crit_base` + `crit_behind` + per level, x `crit_mult`). They never stack.
- Kick and tackle (`CombatTactics._spot_mult`) and stones / darts (`StoneProjectile.impact`, the flight from the stone into
  the body collider) use the same `CritSpots.land`.
- Only the player's hits use spots. Creature hits, and the server's `act.attack`, do not.

## Feedback (`CritSpots.land`)
- Gold hit flash (`CreatureView.flash_damage` colour) and a gold burst at the spot itself instead of the body burst.
- Damage float "WEAK SPOT -N!" in gold (`creature_plates.gd`, kind `weakspot`).
- Camera shake `combat_tuning.json camera.weak_spot` (0.45) and a 0.08 s hit-stop on the target's animation.
- After the first weak-spot hit on an animal, its spots glow faintly gold through the body for the rest of its life
  (`CritSpotMarks`).
- Debug: the H view (`HitboxDebug`) draws every animal's spots magenta.

## Review shots
`Godot --path game --position 6000,3000 -- --skip-charcreate --lab=critspot_lab --out=DIR` saves six species in the
H view and a crit landing from the game camera, then quits.
