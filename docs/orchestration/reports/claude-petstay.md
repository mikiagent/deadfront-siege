# PETSTAY: Stay / Follow command for companions

Branch `claude/mmo-petstay` (from `origin/claude/mmo-overhaul` 36d1fac8). Not merged to canon.

## What shipped
- `PetBrain` order `&"stay"`: holds the spot it was told to stay at (`stay_spot`), no auto-targeting, ignores the
  survivor's hunt target. Whatever wild animal hits it (`on_aggro`) it fights back, then walks back to the spot
  (start beyond 0.6 m, stop inside 0.3 m).
- Pet radial: one toggle segment before Dismiss, **Stay** (icon `hold`) while the pet follows, **Follow** (icon `heel`)
  while it stays. Follow sends it back to guard. `PlayerPets.set_command` sets brain and record and shows a notice.
  `pet_radial.gd` needed no change (rows come from `PlayerPets.entries`). Zebraceratops ring now has 8 segments; at
  844x390 the band is 64 px deep and ~66 px wide at its middle.
- Kept through dismiss/summon (summon re-orders stay at the new summon spot) and dismount (stays where you got off).
- Whistles (SIC / HEEL / GUARD) skip staying pets.

## Save format (owner review)
- New additive PetRecord key **`command`**: `"follow"` or `"stay"`. Missing or anything else loads as follow.
- Also allowed in `AssetValidator.PET_KEYS` (value must be follow/stay) and typed in `SaveSanitizer.PET_ROW` (string).

## Gates
- t_petfollow PASS (new section 8: survivor walks 20 m, stayed pet moves 0.000 m; hit by a compy it chases it,
  foe dead -> back 0.27 m from its spot; save round trip; old row -> follow; dismiss/summon keeps stay; Follow
  brings it to its slot).
- t_petradial PASS (segment ids incl. stay; Stay tap parks, ring then offers Follow, Follow tap frees).
- t_tame, t_save, t_mounts PASS; run_all.gd `[tests] PASS`; `tools/smoke.sh --no-import` SMOKE PASS.
- Shots (windowed off-screen, 844x390, `pet_radial_lab`): `petstay/radial_stay_zebraceratops_844x390.png`,
  `petstay/radial_stay_compy_844x390.png`. `pet_radial_lab` ids updated for the new segment.

## Known / not done
- `pet_radial_lab` (not a gate) fails "tap outside closes and does not walk" in windowed runs on the base commit too
  (checked on a clean 36d1fac8 checkout at 844x390 and 1600x900); its later checks are flaky in off-screen windows.
- Assumptions logged in `docs/vision/WildLandsMMO_Open_Questions.md` (PETSTAY): whistles skip stayed pets, 15 m
  leash, a re-summoned stayed pet stays at the new summon spot. No Follow screenshot.
