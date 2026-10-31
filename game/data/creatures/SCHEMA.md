# Creature data and asset contract

This is the handoff boundary between the art pipeline (Codex + Meshy) and the
game (Cursor + Godot). Both sides read this file. Change it only through the
orchestrator (Claude Code) because both sides have to move together.

## 1. Files per species

```
game/data/creatures/<species>.json            stat block, clips, prompts   (Codex writes, Godot reads)
game/assets/creatures/<species>/
  <species>.glb                               rigged, skinned, textured mesh. May contain walk/run clips.
  anim/<clip>.glb                             one file per clip, same armature, skin optional
  ref/<species>_side.png                      accepted reference image(s) used for image-to-3D
  ref/.gdignore                               keeps Godot from importing reference images
  work/                                       intermediates, rejected meshes. Has a .gdignore
  sheet.png                                   validation render: 4 views + clip contact sheet (Blender)
```

Species keys are lowercase scientific names: `utahraptor`, `velociraptor`,
`deinonychus`, `protoceratops`. Variants (`velociraptor_snow`) never get their
own mesh; they override material and scale in JSON only.

## 2. Clip contract

Every creature exposes these clip names inside Godot. The file name under
`anim/` IS the clip name, so no renaming is needed inside the GLB.

| clip            | required | source (bipeds)                     |
|-----------------|----------|-------------------------------------|
| idle            | yes      | Meshy library preset                |
| walk            | yes      | rig output                          |
| run             | yes      | rig output                          |
| attack_primary  | yes      | text-to-motion (json `clips`)       |
| attack_heavy    | yes      | text-to-motion, must contain a held telegraph beat |
| hit_react       | yes      | library preset                      |
| knockdown       | yes      | text-to-motion. Ends lying on side; this is the capture window |
| death           | yes      | library preset                      |
| alert           | bipeds   | text-to-motion                      |
| feed            | optional | text-to-motion                      |

**Meshy's rigging and motion APIs are humanoid-only (confirmed by three 422s in
C2), so no dinosaur takes the Meshy automated route.** Clips come from whichever
rigging tool the plan currently names (see `docs/orchestration/plan.md` §4, C2b)
or from Blender. Missing optional clips fall back: `run` = `walk` at 1.6x,
`alert` = `idle`, `hit_react` = first 40% of `knockdown`.

## 3. Orientation, scale, units

*(Revised 2026-09-17 after C2: generated meshes do not come out facing +Z or at
real size, so the game normalises instead of the asset promising.)*

- The JSON `pipeline` block records what the asset actually is:
  `"forward_axis": "+Z" | "-Z" | "+X" | "-X"` and `"source_height_m": <measured>`.
  Codex measures both with `tools/render_glb.py` and writes them. Default when
  absent: `-Z` (Godot forward) and no rescale.
- `CreatureView` in Godot rotates the model so `forward_axis` becomes Godot's
  `-Z`, then scales it uniformly so the measured height matches `height_meters`.
  Cursor never edits the mesh; Codex never bakes a rotation into it.
- If a rigging tool requires a specific facing (Meshy's API needs +Z), Codex may
  export a corrected copy under `work/` for that upload and must record the
  final asset's facing in the JSON. The shipped `<species>.glb` is whatever the
  rig tool returned.
- 1 unit = 1 metre. Y up. Origin at the feet, centred.

## 4. JSON fields

Existing files are the reference. Required keys:

```
species, clade, period, real_length_m, height_meters, rig ("biped"|"quadruped"),
tier, climate, archetype, tameable, capture_tier, verb, status_applied[],
stats{hp, attack, defense, speed}, tamed_role[], prompt, texture_prompt, clips{}
```

Optional: `variants[]`, `rig_note`, `stats.bag_slots`, `pipeline{}` (Codex adds
task ids and accepted file names here so the game can show provenance in the
codex screen later), `taming{}` (field-tame food and feed counts; see below),
`turn_rate` (max yaw rate in rad/s; default by `real_length_m`: <= 8 m 5.0, <= 14 m 3.0,
larger 1.4, see `CreatureDef.default_turn_rate`), `tactics{}` (knobs that override the archetype's
`ai.json` tactics for this species only; `attack_range` there sets its reach. The styracosaurus uses it for
its 3x distances and the impale charge: `charge_impale`, `charge_min_m`, `impale_reach_m`, `impale_r_m`,
`toss_up_mps`, `charge_recover_s`).

`archetype` values the game implements: `apex_raptor`, `raptor_pack`,
`flock_harass`, `swarm`, `runner`, `venom_ranged`, `pack_mule`, `horned_charger`,
`club_tail`, `spiked_tail`, `saber_cat`, `antlered`, `titan`, `tyrant`.

### Taming block (`taming`)

Field taming (M9b): knock the animal down, then feed preferred/accepted food while
the knockdown window is open.

```
"taming": {
  "preferred_food": ["berry", "herb_leaf"],
  "accepted_food": ["fibre_stalk"],
  "feeds_needed": 3,
  "window_seconds": 45,
  "requires_pen": false
}
```

- `preferred_food`: +1.0 feed progress per unit consumed.
- `accepted_food`: +0.5 feed progress per unit.
- `feeds_needed`: progress required to finish a field tame.
- `window_seconds`: time from knockdown start to finish the feeds; failing enrages
  the animal (+20% move for 20 s) and blocks another field tame for 60 s.
- `requires_pen`: when true, feeding still extends knockdown but cannot finish the
  tame in the field (plate shows `Tame in pen`). Big animals use the existing pen.

Defaults when `taming` is absent (`# ASSUMPTION:`):
- Herbivore archetypes prefer `berry` + `herb_leaf`, accept `fibre_stalk`.
- Carnivores prefer `raw_meat`, accept `fish` and `raptor_meat`.
- `real_length_m` > 5 → `feeds_needed` 6 and `requires_pen` true; else 3 feeds,
  field-complete allowed.

### Coloration block (`coloration`)

Every wild individual rolls its own natural colour profile and hide pattern at spawn; taming and
saving keep both (they live in `CreatureGenetics.coloration`, beside the IVs). The species only
declares the ranges. Optional block; every value has a natural default.

```
"coloration": {
  "hue_deg": 14,           // +/- degrees of hue shift (or [min, max])
  "sat": 0.18,             // +/- saturation scale around 1.0 (or [lo, hi] as signed offsets)
  "val": 0.12,             // +/- value scale around 1.0 (or [lo, hi] as signed offsets)
  "morphs": [              // optional named looks, weighted; they NARROW the ranges above
    {"id": "dark", "weight": 1, "hue_deg": 8, "sat": 0.10, "val": [-0.22, -0.10]},
    {"id": "pale", "weight": 1, "hue_deg": 8, "sat": [-0.22, -0.08], "val": [0.08, 0.18]}
  ],
  "rare_chance": 0.02,     // ASSUMPTION: about 1 in 50 animals is a rare morph
  "rare_morphs": ["dark", "pale", "rufous"],   // labels for the rare roll
  "rare": {...},           // optional wider ranges for the rare roll (default: the ranges x2.4)
  "patterns": [            // allowed hide patterns, weighted; "" = plain hide
    {"id": "stripes", "weight": 3, "scale": 1.0, "strength": 0.30},
    {"id": "spots", "weight": 2, "scale": 1.0, "strength": 0.26},
    {"id": "countershade", "weight": 2, "scale": 1.0, "strength": 0.28},
    {"id": "", "weight": 3}
  ]
}
```

- Normal rolls stay inside the ranges; only a rare morph (about 1 in 50) goes wider, and it stays
  believable (melanistic, leucistic, a stronger hue) rather than neon.
- Pattern kinds: `stripes` (bands across the body's long axis), `spots`, `saddle` (darker back),
  `countershade` (lighter belly). The pattern is drawn in the shader from the REST-POSE vertex
  positions (a custom vertex channel built once per mesh), so it never slides while animating and
  does not depend on the UVs; the tone is taken from the body colour, never a foreign hue.
- Defaults when the block is absent (`# ASSUMPTION:`): hue +-12 deg, saturation +-15 %,
  value +-10 %, `rare_chance` 0.02, patterns countershading (2) and plain (3).
- A rare morph and its pattern survive taming and saving like any other profile; a save written
  before colour profiles gets one derived from the pet's uid, so it never changes between loads.

## 4b. Making a new species (one command)

```
python3 tools/creature_pipeline.py <species>            # refs -> Meshy 7 mesh -> transplant -> sheets -> json
python3 tools/creature_pipeline.py <species> --version 2 # redo
```
It needs `game/data/creatures/<species>.json` with `species`, `rig`, `real_length_m`,
`height_meters`, `texture_prompt` and a `look` sentence (the visual description used
in the reference prompts). Bipeds get side + front references with the arms
explicitly folded; quadrupeds get four-on-the-floor references. Donor rigs:
Quaternius Velociraptor (bipeds), Trex (bipeds over 8 m), Triceratops (quadrupeds).
Cost: 48 Meshy credits per species. Check `sheet.png` and `work/qa/` before accepting.

## 5. Validation before handoff

Codex marks a species done only when:

1. `sheet.png` shows a horizontal spine, a long stiff tail (at least 40% of
   total length for dromaeosaurs), and the species' signature feature.
2. Every required clip file exists and loads in Blender with the same bone names as `<species>.glb`.
3. `python3 tools/meshy.py status <species>` lists task ids for every stage.
4. `docs/orchestration/reports/codex-<species>.md` records credits spent.

Cursor marks a species integrated only when `scenes/dev/creature_lab.tscn`
plays every clip on the real mesh and the smoke test still passes.
