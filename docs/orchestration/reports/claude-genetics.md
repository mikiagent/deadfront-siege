# claude-genetics: GENETICS + ALPHAS

Branch `claude/mmo-genetics` (from `claude/mmo-overhaul`), worktree `.claude/worktrees/mmo-genetics`.
Owner asks: (1) "dinosaur size and color variation (heritable stats)", (2) "alpha dinosaurs with special
loot but are on steroids and really hard to kill". This is a visual direction for the owner to review before
merging.

## What shipped

**Genetics (phase 1)**
- `CreatureGenetics` gets `size` and `alpha`, next to the IVs and the colour profile that were already
  there. `for_species(def, rng, colour_rng)` rolls the size inside the species range (ai.json
  `genetics.size_range` 0.85-1.15, overridable per species JSON). The size draws after the colours, so
  seeded colour rolls are unchanged.
- Size scales the `CreatureView`, which also scales the eye points, mount socket and saddle under it. The
  eye dots keep their anatomical world radius. It also scales the collision capsule, `body_radius()`, the
  plate anchor/box and the label. `Creature.size_scale()` is the ragdoll hook. Stats go through
  `size_factor` (HP +1.0, attack +0.5, speed -0.3 per unit of size), for wild animals and for pets
  (PetStats).
- Saves: new optional fields, sanitizer shape, asset validator range check. An old save loads 1.0x.
- `CreatureGenetics.inherit(a, b, rng)` and `CreatureColoration.blend` do a blend inside the parents'
  range plus a bounded mutation. Breeding is not built.
- The Animals detail card has a Size row ("1.31x") with a swatch. The Taming Pen shows "Size 1.08x" with a
  swatch. The swatch is the species' mean texture colour with the animal's own shift.

**Alphas (phase 2)**
- `Spawner` rolls one alpha per group at 8 %. `make_alpha` sets the size to 1.24-1.32x and makes the
  colours darker and richer, still natural. Eyeshine is 2.5x stronger with a wider bloom.
- While wild: HP x3, defense x1.5, attack x1.6, speed x1.15, on top of size. The pack_flanker
  `tactics.alpha` block sets cooldowns x0.6 and pounce/charge/combo weights x1.6.
- Pack aura: packmates within 12 m get attack x1.15, defense x1.1 and speed x1.1.
- Loot: every rare row is guaranteed, every part carries a rare trait, and there is a new `alpha_trophy`
  item (epic, icon alias raptor_talon). XP is x4.
- Name: a genetic alpha is always "Alpha ..." with the nature chip under it.
- A fix on the way: `Creature._on_died` raised on an untyped `[]` when no survivor was around, which
  aborted the corpse. The fallback is typed now.

## Gates (all on the final tree)
t_genetics, t_alphas, t_ai, t_tactical, t_canim, t_tame, t_natures, t_mounts, t_petfollow, t_save,
t_uianimals, t_uiworld, t_eyeglow all PASS. So do t_data (taught the alpha trophy source), t_colors,
t_eyetrails, t_butcher, t_rareattr, t_combat, t_energy, t_srvdom and t_capture09. run_all prints
`[tests] PASS`. `tools/smoke.sh --no-import` prints `SMOKE PASS`. In the first baseline t_petfollow failed
once (pets did not settle) on the untouched base. It passes on every run since, so it is flaky.

## Review shots (`docs/orchestration/reports/genetics/`)
1. `01_lab_lineup_5_deinonychus.png`: 0.86-1.14x deinonychus, stripes / spots / plain / countershade.
2. `02_lab_alpha_vs_normal.png`: the same genes as a normal animal (1.00x) and as an alpha (1.31x).
3. `03_lab_alpha_vs_normal_night_eyes.png`: at night, the alpha's eyeshine is stronger.
4. `04_game_camera_alpha_vs_normal.png`: the iso game camera, with the plate "Lv. 35 Alpha Deinonychus / Aggressive".
5. `05_card_size_swatch_1600x900.png` and `06_card_size_swatch_844x390.png`: the Animals card with Size 1.31x and the swatch.

Lab: `Godot --path game --resolution 1600x900 -- --lab=genetics_lab --shot-dir=DIR [--canvas=844x390]`.

## Assumptions (Open Questions G1-G12, 2026-10-28 section)
- G1 size range 0.85-1.15.
- G2 size stat factors.
- G3 mutation bounds, and what is not inherited.
- G4 an old save loads 1.0x.
- G5 8 % per group, member 0.
- G6 alpha size 1.24-1.32 and stat multipliers.
- G7 alpha tactics.
- G8 alpha look.
- G9 alpha loot, trophy and 4x XP.
- G10 aura of 12 m and its buffs.
- G11 a tame loses the buffs.
- G12 (open) a pack leader and a genetic alpha are both named "Alpha".

## Risks / for the next agent
- The deinonychus `real_length_m` is 10.2, but the model renders about 5 m long. Plate boxes are sized off
  real_length x size, so plates sit far from big animals (shot 4). This was already true; scaling makes it
  31 % larger on an alpha.
- The alpha colour shift is deliberately limited to the natural palette. In daylight it reads as "richer
  rust" more than "dark". If the owner wants it darker, raise `alpha.val_mult` (it is clamped at value
  0.55).
- Only pack_flanker has an alpha tactics block. Other classes get the stat buffs only.
- Ragdoll (held branch): scale its bone shapes by `Creature.size_scale()`.
- The mount fallback path (no saddle) reparents the rider under the scaled mount socket. A sized mount
  would scale the rider. All 9 saddled species use the saddle path, so this is untested.
- PackIndex leader order uses max HP, so an alpha always leads its pack.

Credits spent: none (no paid generation).
