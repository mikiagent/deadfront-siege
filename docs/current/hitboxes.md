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
- `radius_scale` is 1.25 for creatures (the megaloceros 1.0: its antler rack is one wide capsule) and 1.0 for the survivor. Override per species (`species.<id>.hurtbox`),
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
| TacticalBrain pounce | pounce | `TacticalBrain._pounce_land` | jaw, head, both hind feet (raptors) |
| Gallimimus rake, pachycephalosaurus hip check | attack_heavy, kick | `Creature._on_hit` | hind feet + head; Tail2, Tail1, Hips |
| Smilodon, woolly rhino, tarbosaurus, carnotaurus, raptor (any species with `pipeline.hit_parts`) | their moves | `Creature._on_hit`, pounce, charge | a move with no row in `hitboxes.json` takes that species' `pipeline.hit_parts.<move>` bones; `Creature.part_hit` still judges hits on bodies without hurtboxes |
| Megaloceros doe | attack_primary / heavy / kick | `Creature._on_hit` | `species.megaloceros.variants.doe`: forehooves, hind feet (a model variant overrides the species row) |
| TyrantBrain, MegaRexBrain | attack_primary (bite), attack_heavy (stomp), tail_swipe, bite_shake (MegaRex) | `TyrantBrain._impact`, `MegaRexBrain._impact_special` | jaw / head; toes + jaw; tail 5-7; jaw / head. Calibrated at 0.6x and 1x of its reach: a tyrant swings at anything inside it |
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
    its hurtboxes. It must still reach from `Hunt.SWING_MARGIN_M` (0.35 m) farther back, because the hit lands
    about 0.4 s later. The margin is dropped when the animal's collider already stops her;
  - at the hit she is judged turned to her target, since `PlayerSim.face_tick` tracks it through the swing;
  - she walks to `Hunt.aim_point`, the nearest hurtbox she can reach from the ground (up to 2.2 m above her feet),
    for example a T. rex leg rather than the belly over her head.
- A whiffed kick or tackle still spends its stamina and cooldown.

## Calibrated radii

A part marked `"calibrated": true` was widened so it reaches a survivor standing at the brain's contact reach
(`CreatureBrain.contact_reach`, centre to centre), in front of the animal or behind it for kicks and the tail whip;
pounces are also checked where the leap lands (body radius + 0.2 m), the gallimimus rake at its `heavy_reach_m`, and
the smilodon's pin_stab on a survivor lying Pinned at `pin_reach_m`.
These clips stop short of that distance or pass over her head. Regenerate the radii with
`godot --headless --path game --script res://tests/t_hitboxes.gd -- --calibrate`. It measures at four body sizes and
each model variant, adds a 0.2 m margin for idle sway, and prints the radius each part needs. Apply the radius to the
part that needs the least. Shrink a radius when the clip or the AI spacing is fixed.

| Species | Move, part, radius (m at size 1.0) |
|---|---|
| carnotaurus | attack_heavy Head 2.27; charge Head 1.75; attack_primary Jaw 2.17 |
| coelophysis | attack_primary Jaw 0.91; attack_heavy Jaw 0.95; bite_combo Jaw 0.90; pounce Head 1.17 |
| compsognathus | pounce Jaw 0.97; attack_primary Jaw 0.85; attack_heavy Jaw 0.62 |
| deinonychus | pounce Head 0.97; attack_primary Head 0.78; attack_heavy Jaw 0.82; bite_combo Jaw 0.70 |
| gallimimus | attack_heavy BackFoot.R 1.27; attack_primary Head 1.04; bite_combo Head 1.10 |
| megaloceros | kick BackFoot.R 0.89; charge Head 2.01; attack_primary Head 2.01; attack_heavy Head 2.02 |
| megaloceros (doe) | attack_primary FrontFoot.R 3.09; attack_heavy Head 2.36 |
| megarex | attack_heavy Toe.R 2.67; tail_swipe Tail5 4.59; attack_primary Head 7.20; bite_shake Head 7.00 |
| pachycephalosaurus | charge Jaw 0.87; kick Tail2 2.17; attack_primary Head 0.61; attack_heavy Jaw 0.64 |
| raptor | attack_primary Head 0.77; bite_combo Head 0.83; pounce Head 1.69; pin_stab Head 1.80 |
| smilodon | attack_primary FrontFoot.R 1.06; attack_heavy Head 0.85; pounce Head 0.91; pin_stab Head 0.76 |
| stegosaurus | attack_primary head 1.78; attack_heavy head 1.66; STEGOSPIN close moves: stomp front_foot_L 1.87; rear_slam front_foot_R 2.34; shove_left front_upperarm_L 2.69; shove_right front_upperarm_R 2.68; hind_stomp_left hind_foot_L 1.03; hind_stomp_right hind_foot_R 0.85 |
| styracosaurus | kick BackFoot.L 1.44; charge Head 1.13; attack_primary Head 1.17; attack_heavy Head 1.17 |
| tarbosaurus | attack_primary Head 2.07; attack_heavy Head 1.70; pounce Head 1.96 |
| tyrannosaurus | tail_swipe Tail5 3.75; attack_primary Head 6.47 |
| utahraptor | pounce Head 2.84; attack_primary Head 1.97; attack_heavy Head 2.30; bite_combo Head 2.09 |
| velociraptor | pounce Jaw 0.64; attack_primary Jaw 0.58; attack_heavy Jaw 0.65; bite_combo Jaw 0.65 |
| woolly_rhino | attack_primary FrontFoot.R 1.42; charge Horn 0.66 |
| zebraceratops | kick BackFoot.L 1.01; charge Head 1.37; attack_primary Head 1.47; attack_heavy Head 1.45 |

Notes: the T. rex bite never comes below 3.3 m and its tail whip passes 4.5 m up; the stegosaurus tail swings behind while CreatureBrain attacks prey in front.

Uncalibrated: triceratops, the tyrannosaurus stomp, and the ankylosaurus (ClubTailBrain aims the club).

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
