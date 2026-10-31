# How hits work: hitboxes and hurtboxes

Every melee hit between a body with a skeleton (each modelled species, the survivor) is decided by an
attacking part touching a hit-able part. Code: `game/scripts/combat/hurtboxes.gd`, `game/scripts/combat/hitbox.gd`,
`game/scripts/combat/hitbox_debug.gd`. Data: `game/data/creatures/hitboxes.json`. Test: `game/tests/t_hitboxes.gd`.

## Hurtboxes: what can be hit

- A few capsules per body, each riding one skeleton bone: head, jaw, neck, torso, hips, tail segments, legs, arms.
- Fitted once per model from the skinned mesh (`Hurtboxes._fit`):
  - every sampled vertex (up to 6000) goes to its strongest bone;
  - a bone holding under `hurtbox.min_share` (1.5 %) of the samples hands them to its parent;
  - each remaining bone gets the capsule along its vertices' principal axis, ends trimmed at `end_pct`
    (1 % / 99 %), radius covering `radius_pct` (95 %) of them, times `radius_scale`.
- `radius_scale` is 1.25 for creatures and 1.0 for the survivor. Override per species (`species.<id>.hurtbox`),
  per bone (`hurtbox.bones.<bone>.radius_scale`) or for the survivor (`survivor.hurtbox`).
- They sit on physics layer 20 (`Hurtboxes.LAYER`, bit 1 << 19) on an `Area3D` named `Hurtboxes`, mask 0,
  `PROCESS_MODE_ALWAYS`. They never block movement.
- Built on the first hit, reach check or debug draw, and moved onto the live pose right before each check
  (`Hurtboxes.sync`). Each capsule carries its bone name (`part`) and a region (head, neck, torso, hips, tail,
  leg, arm, body).
- Bodies without a skeleton (box stand-ins, structures, catapults) have none and keep the old reach rule
  (`MeleeQuery`, centre distance).

## Hitboxes: what hits

- Every move names its attacking parts in `hitboxes.json`.
  - A part is a bone plus a sphere radius, or a capsule: `length` along `axis` in the bone frame, starting at
    `offset`. Examples are a blade in the fist and a horn.
  - The radius defaults to the attacker's own hurtbox at that bone. Creature metres scale with the genome size.
- Active window: `window` [from, to] as clip fractions. The default opens `creature_defaults.lead_frac` (0.25) of
  the clip before the hit frame (`anim_events.json` `hit_frac` / `hit_fracs`) and closes on it. Each bite of
  `bite_combo` has its own window.
- The window is baked once per animal, move and body size from the clip's own tracks
  (`Hitbox.baked`: samples 1/60 s of clip apart, at most 48).
- At the hit, the parts' path through the window is swept against the target's hurtbox capsules
  (`Hitbox.strike`, exact capsule-to-capsule distance). Each sample checks:
  - the part where it is,
  - and each end's path since the previous sample, so a fast swing cannot pass through a thin body
    between frames.
- The first hurtbox touched is the hit location. It is written to `Health.last_hit_part` (creatures) or
  `Vitals.last_hit_part` (survivor) before the damage.
- A hit lands once per target per move. A miss counts as `CombatAvoid` "miss".
- Unchanged: roll invulnerability (`RollRules`), telegraph dodges, damage numbers, statuses, cooldowns. They all
  still run in `CreatureAttack.apply_for` / `Hunt.land_hit` after the hitbox says contact.

## Which move uses which parts

| Mover | Move (data key) | Where it is judged | Parts |
|---|---|---|---|
| Creature (CreatureBrain, TacticalBrain, RaptorPackBrain, PetBrain) | attack_primary, attack_heavy, bite_combo, kick, tail_swipe | `Creature._on_hit` at the clip's hit frame | species `parts` (jaw / head; tail tip for the stegosaurus) or the move's row |
| TacticalBrain straight charge | charge (window 0-1 of the charge clip, else run) | `TacticalBrain._charge_impact`, every frame in reach until the head reaches her | head, horns |
| TacticalBrain pounce | pounce | `TacticalBrain._pounce_land` | jaw, head, both hind feet |
| TyrantBrain | attack_primary (bite), attack_heavy (stomp), tail_swipe | `TyrantBrain._impact` | jaw / head; toes + jaw; tail 5-7 |
| ClubTailBrain (ankylosaurus) | its club_moves | `ClubTailBrain._tick_move`: the club's live path each physics frame (`Hitbox.touch`), landing at its closest pass | Tail5_end, radius 0.6 m |
| Survivor swing | punch (bare hands, attack_primary clip), swing, heavy (heavy blunt weapon) | `Hunt._on_swing_hit` | fist 0.3 m; plus `weapons.<tool_class or damage_type>`: knife 0.45 m, slashing 0.7 m, blunt 0.7 m capsules out of the thumb side |
| Survivor kick | kick | `CombatTactics.kick` after a step-in up to `kick.lunge_max_m` (0.8 m) | both feet 0.35 m |
| Survivor tackle | tackle | `CombatTactics.tackle` after the 1 m lunge | chest 0.5 m, shoulders 0.35 m |
| Survivor roll | none | | |

- The survivor's moves also take `aim_down_m` 1.2 / `aim_up_m` 0.3 (kick 0.9). When the sweep misses where it plays,
  it is tried lower or higher in 0.3 m steps, as a swing bends into a compy at her knees. A target beside or behind
  her is still missed.
- Reach for the survivor is the hitbox (`Hunt.in_reach`):
  - auto-attack and F swing only when the swing she would play, turned to face the target, sweeps through one of
    its hurtboxes;
  - she walks to `Hunt.aim_point`, the nearest hurtbox she can reach from the ground (up to 2.2 m above her feet),
    for example a T. rex leg rather than the belly over her head.
- A whiffed kick or tackle still spends its stamina and cooldown.

## Calibrated radii

A part marked `"calibrated": true` was widened so it reaches a survivor standing at the brain's contact reach
(`CreatureBrain.contact_reach`, centre to centre), in front of the animal or behind it for kicks and the tail whip.
These clips stop short of that distance or pass over her head. Regenerate the radii with
`godot --headless --path game --script res://tests/t_hitboxes.gd -- --calibrate`, which covers both ends of the
species' size range. Shrink a radius when the clip or the AI spacing is fixed.

| Species | Move, part, radius (m at size 1.0) |
|---|---|
| compsognathus | pounce Jaw 0.84; attack_primary Jaw 0.72; attack_heavy Jaw 0.49 |
| deinonychus | pounce Head 0.83; attack_primary Head 0.65; attack_heavy Jaw 0.72; bite_combo Jaw 0.60 |
| gallimimus | attack_primary Head 1.12; attack_heavy Head 1.25 |
| megaloceros | attack_primary Head 1.52; attack_heavy Head 1.41 |
| pachycephalosaurus | charge Head 0.51; attack_primary Head 0.49; attack_heavy Jaw 0.53 |
| stegosaurus | attack_primary head 1.69; attack_heavy head 1.57 (its tail swings behind, the target is in front) |
| styracosaurus | kick BackFoot.L 1.30; charge Head 1.00; attack_primary / attack_heavy Head 1.04 |
| tyrannosaurus | attack_primary Head 5.52 (the bite never comes below 3.3 m); tail_swipe Tail5 3.65 (the tail passes 4.5 m up) |
| utahraptor | attack_primary Head 2.55; attack_heavy Head 1.75 |
| velociraptor | attack_primary Jaw 1.08; attack_heavy Jaw 0.90 |
| zebraceratops | kick BackFoot.L 0.87; charge Head 1.23; attack_primary / attack_heavy Head 1.33 / 1.31 |

Uncalibrated: coelophysis, triceratops, the tyrannosaurus stomp, and the ankylosaurus (ClubTailBrain aims the club).

## Debug draw

- Every hurtbox is drawn green. Each judged hitbox sweep is drawn red for 0.45 s, yellow where it touched.
- Code: `HitboxDebug` under the tree root, on while `Hitbox.debug_draw` is on.
- The debug toggle (`debug_toggle` action, the HUD debug hex) switches it with `Game.debug_overlay`.
- In the fight lab, key H or `--hitboxes` switches it.

## Cost

Measured in `t_hitboxes`:
- 20 creatures each judging attack_primary against the survivor take about 0.7 ms in all. A bounds check skips
  sweeps that cannot touch.
- Syncing 20 bodies' hurtboxes takes about 0.4 ms.
- The fit takes 2-3 ms per model, once.
