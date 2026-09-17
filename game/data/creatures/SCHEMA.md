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
codex screen later).

`archetype` values the game implements: `apex_raptor`, `raptor_pack`,
`flock_harass`, `swarm`, `runner`, `venom_ranged`, `pack_mule`, `horned_charger`,
`club_tail`, `spiked_tail`, `saber_cat`, `antlered`, `titan`, `tyrant`.

## 5. Validation before handoff

Codex marks a species done only when:

1. `sheet.png` shows a horizontal spine, a long stiff tail (at least 40% of
   total length for dromaeosaurs), and the species' signature feature.
2. Every required clip file exists and loads in Blender with the same bone names as `<species>.glb`.
3. `python3 tools/meshy.py status <species>` lists task ids for every stage.
4. `docs/orchestration/reports/codex-<species>.md` records credits spent.

Cursor marks a species integrated only when `scenes/dev/creature_lab.tscn`
plays every clip on the real mesh and the smoke test still passes.
