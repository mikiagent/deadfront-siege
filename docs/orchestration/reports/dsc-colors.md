# dsc COLORS — wild dinosaur colour profiles

Task: wild dinosaurs get natural per-individual colouration (and hide patterns), taming keeps it,
and it survives saving.

## What shipped

**Profile model** — `game/scripts/creatures/creature_coloration.gd` (`CreatureColoration`):
`hue_deg` (degrees), `sat` and `val` (scales around 1.0), `morph` label, `rare` flag, and a pattern
layer (`pattern`, `pattern_scale`, `pattern_strength`, `pattern_tone`, `pattern_seed`).
`roll(block, rng)` reads the species ranges, `from_dict`/`to_dict` (rounded to 0.0001 so a JSON
round trip compares equal), `derive(id, block)` (FNV-1a seed + warmed RNG: the same id always gives
the same profile), `shift_color()` for the placeholder path.

`CreatureGenetics.coloration` holds it beside the IVs, so it follows the same tame and save path.
`CreatureGenetics.roll(rng, coloration_block, colour_rng)` keeps the IV stream and the colour stream
separate: a wild spawn seeds only the colours from its spawn point, the IVs stay random.

**Data** — `coloration` blocks in all 19 `game/data/creatures/*.json`, read by `CreatureDef.coloration`.
Documented in `game/data/creatures/SCHEMA.md` (§4, "Coloration block").

Ranges chosen (ASSUMPTION: natural, never neon):

| species family | hue_deg | sat | val | patterns (weights) |
|---|---|---|---|---|
| raptors (velociraptor, deinonychus, utahraptor, compsognathus, coelophysis, dilophosaurus, gallimimus) | 12–16 | 0.14–0.20 | 0.10–0.12 | stripes 3, spots 2, countershade 2, plain 3 |
| big carnivores (tyrannosaurus, tarbosaurus, allosaurus, smilodon) | 10–12 | 0.14–0.16 | 0.12 | stripes 3, spots 1, countershade 3, plain 3 |
| ceratopsians / ankylosaurus / stegosaurus / megaloceros | 12–16 | 0.16–0.18 | 0.10–0.12 | saddle 2, stripes 2, countershade 3, plain 3 |
| sauropod (brachiosaurus) | 12 | 0.16 | 0.10 | saddle 3, stripes 2, countershade 2, plain 3 |

Every species: `rare_chance` 0.02 (about 1 in 50), `rare_morphs` labels per family
(dark/pale/rufous). A rare roll uses the species range × `RARE_SCALE` (2.4), clamped to
`HUE_LIMIT * 1.5`, and gets a bolder pattern (strength ×1.35). Normal rolls always stay inside the
declared range: named morphs (dark/pale) *narrow* the range, they never widen it.

**Shader** — `game/scripts/creatures/creature_color.gdshader`: samples the original albedo, shifts it
in HSV, keeps normal / roughness / metallic (honouring the glTF ORM channels the importer set), and
draws the pattern from the **rest-pose vertex positions** in `CUSTOM0`, never from UV or the skinned
`VERTEX`. Status FX (`darken`, `tint_color`/`tint_amount`, damage `flash_amount`) are uniforms applied
on top of the shifted, patterned colour.

`CreatureView.apply_coloration()` binds a `ShaderMaterial` per surface per individual (authored
materials cached, so re-applies re-copy the real textures). `CreatureView.rest_mesh()` rebuilds each
species mesh once with `ARRAY_CUSTOM0 = rest xyz` (`ARRAY_CUSTOM_RGB_FLOAT`) and caches it in a
static dict keyed by the source mesh. The placeholder box path (stegosaurus) shifts `_tint` with the
same HSV math, and FX still apply.

**Tame / save**
- Field tame (`field_tame.gd`) and net capture (`capture_system.gd`) already hand the creature's own
  `genetics` to `PetRecord.from_def`; nothing is re-rolled. `PetRecord.from_def` now also seeds a
  profile for a hand-built genetics record.
- `PetRecord.from_dict` keeps a saved profile; when a save has none (pre-COLORS), it derives one from
  the pet's uid → same on every load, written back on the next save.
- `SaveSanitizer` GENETICS shape now carries `coloration` (numbers, `rare` bool, `morph`/`pattern`
  labels); all-junk blocks are erased to `{}` and then derive.
- `taming_pen.gd:142` and `intent_handlers.gd:352,395` now pass `def.coloration` instead of rolling a
  profile-less genetics record.

**Tests** — `game/tests/t_colors.gd` (8 sections): defaults/ranges, rare share over 2000 rolls
(1–4 %, every normal roll in range, every rare inside its wider bound) and pattern kinds, 20 wild
spawns of 4 species (≥5 distinct, in range), view shader + FX on GLB and placeholder, tame keeps
profile and genetics (including a forced rare striped morph through tame + save/load), save/load and
sanitizer round trip, old-save derivation stable across two loads, forged profile clamped.

**Lab** — `game/scripts/dev/colors_lab.gd` + `scenes/dev/colors_lab.tscn` (wired like the other labs
through `--lab=`): 8 individuals (4 velociraptors, 4 protoceratops) on flat ground with a pale band,
stripes / spots / countershade / saddle / plain / one labelled **RARE** morph. It asserts the lineup
and, from the rendered frame, 0 % near-white pixels + mean saturation ≥ 0.18, and that a walk clip
keeps the flank pattern still (rest channel identical, pattern mask bit-identical, ≥80 % of flank
pixels within tolerance). Prints `[colors_lab] PASS n=8`.

## The near-white skin bug (found by the audit, fixed)

The colour shader assigned `EMISSION` on the gl_compatibility renderer; even with the emission
uniform at 0 this added a white emissive term, rendering every creature near-white. Removing the
emission branch (`creature_color.gdshader`) and the emission uniforms (`CreatureView._color_material`)
restores tawny skins. Verified by one-shot A/B renders (each candidate line toggled in one image) and
now guarded by the lab's look assert (0 % near-white, mean saturation 0.20).

Shot: `$TMPDIR/colors/colors.png` (1600×900, gl_compatibility), regenerated by the verify script as
`colors-out/colors.png`.

## Verified

- `t_colors` PASS, plus `t_save`, `t_data`, `t_tame`, `t_srvdom`, `t_server_domain` all PASS after the
  tame/save changes.
- `colors_lab` PASS n=8 with the shot written; visual check: tawny striped raptor, dark spotted
  raptor, countershaded one, one rufous RARE raptor, protoceratops with saddle / countershade /
  plain / stripes hides, all on a neutral band.

## Known issues / next agent

- **Git index writes are blocked in this sandbox** (`index.lock: Operation not permitted`), so
  `git rm --cached` on my throwaway probe files failed. The files themselves are deleted from the
  worktree; only the checkpoint commits' index may still mention them. Clean with
  `git rm --cached game/scripts/dev/_* game/scenes/dev/_*` outside the sandbox.
- `CreatureView` keeps a static rest-mesh cache keyed by source mesh; it is never evicted (a few MB
  per species actually rendered). Fine for 19 species, revisit if the roster grows a lot.
- Patterns are procedural and approximate (stripes follow the longest bounds axis); a species whose
  mesh is longer across than along would get cross-body stripes.
- Placeholder (box) creatures carry the colour shift but no pattern (no usable bounds channel).
