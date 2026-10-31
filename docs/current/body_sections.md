# Body sections, Wounds, Armor breaks, aimed ranged, heavy blades and the bow

Owner: "when attacking with a ranged weapon ... I want to be able to click the intended body section. Crits should be small
and hard to hit ... Melee weapons should make their own crits by attacking and focusing the same body part, it should form a
crack in armor (Armor break) or a gash in the skin (Wound)". Every number is an ASSUMPTION (PC1-PC12 in
`docs/vision/WildLandsMMO_Open_Questions.md`). Report: `docs/orchestration/reports/claude-partcombat.md`.

## Sections (`game/scripts/combat/body_sections.gd`, data `game/data/creatures/hitboxes.json` `sections`)
- Built from each body's hurtbox capsules, no per-species code: `bones` patterns name a capsule's section (head, neck,
  torso, tail, foreleg_L/R, hindleg_L/R), `splits` carve belly (under the torso), frill (back of a ceratopsian skull) and
  plates (top of the stegosaurus torso) from a capsule by where the hit lands, `species.<id>.exact` renames one bone
  (the woolly rhino's Shoulders are its hump).
- Flags: `armoured` (data) and crit (computed: the section holding a crit spot).
- `aim_point(c, section)`: the live point a shot or swing goes for (the crit spot when the section holds one).
- Test `game/tests/t_bodysections.gd`.

## Wounds and Armor breaks (`game/scripts/combat/body_wounds.gd`)
- Each landed melee hit (`Hunt.land_hit` with the `Hitbox.strike` result) adds build-up to the section it connected with,
  per the move's channels (`survivor.moves.<move>.channels`) or the weapon's (`sections.wounds.channels`): slash -> Wound
  on skin, impact -> Armor break on armour, pierce -> both at 0.5.
- Switching sections keeps half of every other section's build; idling decays it.
- A Wound: hits there are sure crits x2.0 (WOUND float), it bleeds, a red gash decal rides the bone. An Armor break: the
  armour's x0.25 cut is gone there, a glowing orange crack rides the bone. WOUND! / ARMOR BREAK! float once each.
  Both clear after 30 s without a player hit.
- Shots also take the armour cut and crit through Wounds; they build nothing.
- Test `game/tests/t_wounds.gd`.

## Picking a section
- `SectionPicker` (`game/scripts/ui/section_picker.gd`): a 64 px AIM chip under the top target bar while she fights an
  animal with hurtboxes; a tap opens a grid of its sections (64 px buttons, ARMOUR / BROKEN / WEAK / WOUND tags).
- A tap on the body of the animal she fights picks the section under the finger (`PlayerInput.interact_tap_target`,
  `BodySections.on_ray`).
- The picked section glows cyan on the animal (`SectionHighlight`). Melee walks to and swings at its nearest reachable
  capsule (`Hunt.focus_point`); ranged shots aim at it.

## Aimed ranged (`Hunt.aimed_shot`, `StoneProjectile`)
- The shot flies at the section's live point at release, plus a miss drawn from `Hunt.shot_sigma` (grows with distance and
  target speed, shrinks with projectile speed); the target keeps moving while it flies.
- Flights are tested against hurtbox capsules (a T. rex head is shootable), the struck capsule names the section, and the
  line on through the capsule passing a crit spot is a sure crit. Box stand-ins keep the collider hit.
- Speeds: `combat_tuning.json ranged.projectile_speed` (arrow 45, stone 18). Test `game/tests/t_aimedranged.gd`.

## Weapons
| Item | Hands | Moves (clips `game/assets/characters/survivor/anim/wpn_*.glb`) | Carry |
|---|---|---|---|
| Iron Slab Blade `iron_slab_blade` | one | cross-slash combo cross1 / cross2 / cross3 (slash), impale (pierce), heavy chop (impact + slash) | tip dragged behind her |
| Steel Greatblade `steel_greatblade` | two | overhead slam (impact x2 + slash, the main Armor-break move), bat sweep out and back (slash, two hits) | tip dragged behind her |
| PRO-Class Bow `pro_bow` + `arrow` | bow in the left hand | draw, aim hold (idle while she has a target), release | bow upright at her left side |

- Meshes: `tools/blender/items/heavy_weapons.py` -> `game/assets/props/blender/`. Clips: `tools/make_heavy_weapon_clips.py`
  (legs from idle / walk / run, IK arms on the weapon's grip). Rows: `props_manifest.json weapons.<id>` (scale, grip_frac,
  hand, carry, aim, draw_clip, release_clip); `HeldModel` holds them, `PlayerAnim.sync_carry` swaps the carry clips in.
- Hitboxes: `hitboxes.json survivor.weapons.drag_blade / great_blade` (a capsule along the blade), moves `wpn_*` with
  hit windows (`hits`), channels and damage_mult. Tests `t_heavyblade_1h`, `t_heavyblade_2h`, `t_bow`.
- Review shots: `Godot --path game --position 6000,3000 --resolution 1688x780 -- --skip-charcreate --lab=partcombat_lab
  --out=DIR` (`--poses [--weapon=id]` for clip contact frames).
