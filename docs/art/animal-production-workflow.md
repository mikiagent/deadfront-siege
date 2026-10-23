# Animal production workflow

This is the repeatable path for adding any dinosaur or other animal to Deadfront. It supplements the file/data contract in `game/data/creatures/SCHEMA.md`; that contract remains authoritative for names, paths, orientation, scale, and required clips.

The goal is not merely “a GLB that imports.” A finished animal must have a recognisable silhouette, game-scale geometry, a stable skeleton and skin, readable animation, correct gameplay bounds, and acceptable results at the actual isometric camera on the mobile target.

## Definition of done

An animal is shippable only when all of these are true:

- Its species, anatomy, dimensions, visual description, behavior, and gameplay role come from the PRDs. Any gap is marked as an assumption rather than invented lore.
- The accepted reference pack and generation/provenance IDs are saved with the species.
- The model has clean silhouette, topology, UVs, PBR materials, scale, orientation, and a feet-level origin.
- The skeleton follows the animal's anatomy, the skin uses at most four normalized influences per vertex, and all joints deform cleanly at animation extremes.
- Every required clip exists, uses the same bone names/rest transforms, has intentional timing, returns cleanly from loops, keeps contacts stable, and does not translate the gameplay root.
- Godot loads the real asset, collision and interaction sizes match the visible body, required clips play, and the animal is readable in gameplay by day and night.
- The automated gates and the human review sheet pass. A failed gate returns the animal to the stage that owns the problem; it is never waived by a later stage.

## Stage-gated workflow

### 0. Intake, scope, and credit approval

1. Add or review `game/data/creatures/<species>.json` against the PRDs and `SCHEMA.md`.
2. Record real length, shoulder/head height, body plan, signature silhouette, locomotion, required attacks, tame/capture needs, and target polycount.
3. Choose the closest existing skeleton family and donor only when the proportions and joint layout are compatible. A donor is an animation source, not proof that a rig fits.
4. Estimate Meshy credits and get the orchestrator's explicit cap before running a paid stage. Dry runs, local Blender work, and validation cost no credits.
5. Create `docs/orchestration/reports/<agent>-<species>.md` immediately and keep its task IDs, attempts, rejections, credit total, and open risks current.

**Exit gate:** approved JSON brief, named rig route, required clip list, target budget, and (for paid work) an explicit credit cap.

### 1. Reference pack and anatomy approval

Build side, front, and three-quarter references. Add top view when horns, plates, wings, fins, or body width matter. All views must describe the same individual and neutral pose.

Check before generating geometry:

- overall length/height ratio and horizontal spine;
- skull, neck, torso, pelvis, limb segment, digit, and tail proportions;
- species-defining structures and integument;
- grounded feet, unambiguous left/right limbs, and no hidden appendages;
- eyes at anatomical scale and location. Eyeshine is a material/presentation layer, never oversized geometry.

Save accepted references under `game/assets/creatures/<species>/ref/`; rejected attempts stay in `work/`.

**Exit gate:** a reviewer can identify the species from the silhouette alone and signs off the same reference set that will drive modeling.

### 2. Mesh generation or modeling

Use `python3 tools/creature_pipeline.py <species> --dry-run` to inspect prompts and route without spending credits. With an approved cap, run only the paid stage authorized by the task. The pipeline is resumable; do not restart successful stages to “try one more.”

Prefer multi-view image-to-3D. Reject rather than repair a mesh with the wrong body plan, missing/duplicated limbs, fused mouth, truncated tail, or unrecognisable signature feature. Local cleanup is for topology and form refinement, not reconstructing a failed generation.

**Exit gate:** correct anatomy and silhouette from side/front/three-quarter views, neutral stance, separate usable mouth/limbs where animation requires them, and no catastrophic surface defects.

### 3. Geometry, UV, and material cleanup

In Blender:

- remove hidden shells, floating pieces, non-manifold fragments, duplicate vertices, and accidental internal faces;
- put deformation-friendly loops around shoulders/hips, elbows/knees, wrists/ankles, jaw, neck, and tail base;
- preserve the target polygon budget and create LODs where the current plan requires them;
- verify UVs do not overlap unintentionally and have consistent texel density;
- check albedo, normal, roughness, and metallic channels under neutral light; animal tissue must not be metallic;
- set metres, Y-up, recorded forward axis, uniform scale, feet-level origin, and centered lateral alignment.

Run a neutral sheet:

```bash
/Applications/Blender.app/Contents/MacOS/Blender --background \
  --python tools/render_glb.py -- \
  game/assets/creatures/<species>/<species>.glb \
  game/assets/creatures/<species>/sheet.png --validate-clips
```

**Exit gate:** clean static asset, measured source height/length recorded in JSON, and a neutral sheet with no material or silhouette surprise.

### 4. Skeleton design

The skeleton must serve the animal, not force the animal into a donor's shape.

- Keep a single gameplay root at the origin; do not bake locomotion into root translation.
- Place joint pivots inside anatomical joints. Give long spines, necks, and tails enough segments to form smooth arcs.
- Add jaw, head, and any gameplay-critical appendage bones. Eyes attach to the head bone; they do not need independent oversized meshes.
- Keep bone names and rest transforms identical across the base GLB and every clip GLB.
- Pose-test the rest rig at crouch, full stride, attack extension, turn, knockdown, and death before animation production.

`tools/transplant_rig.py` may bootstrap a compatible skeleton and weights. Its output is a starting point that still must pass the deformation review.

**Exit gate:** joint placement and hierarchy are anatomically credible, required controls exist, transforms are clean, and extreme-pose tests do not collapse the model.

### 5. Skinning and deformation

Start with automatic or transferred weights, then hand-correct the important zones: shoulder girdle, pelvis, limb folds, jaw corners, neck/tail bases, belly, and any horns/plates attached near joints.

Rules:

- no vertex has more than four influences;
- weights are normalized and no deforming vertex is unweighted;
- rigid structures do not rubber-band;
- the body keeps volume through full strides and attack extremes;
- feet, teeth, eyes, horns, plates, and claws do not detach or sink through nearby anatomy.

Run the deformation audit for the species:

```bash
/Applications/Blender.app/Contents/MacOS/Blender --background \
  --python tools/audit_creature_deformation.py -- \
  /tmp/<species>-rig-audit.json <species>
python3 tools/check_rig_audit.py /tmp/<species>-rig-audit.json
```

The numerical audit catches tearing, broken weights, rest mismatches, penetration, and loop seams. It does not replace looking at posed renders.

**Exit gate:** automated rig audit passes and a reviewer accepts deformation at the worst poses, not just at rest.

### 6. Animation set

Author the required clip contract from `SCHEMA.md`. For each clip define intent, anticipation/telegraph, contact or impact frame, recovery, duration, loop behavior, and gameplay event timing before polishing.

Quality checks:

- idle/walk/run loops have no visible seam, frozen span, foot slide, or unintended root drift;
- walk and run cadence match the animal's size and the data-driven gameplay speed;
- attacks have a readable wind-up, decisive impact, and recovery; hit events align with contact;
- hit reaction preserves footing unless the design calls for knockdown;
- knockdown ends in the capture pose; death settles without snapping or looping;
- head, tail, and secondary motion support weight and balance rather than wobbling independently;
- every clip recovers to a compatible pose so transitions do not pop.

Render evenly sampled reviews and contact poses:

```bash
/Applications/Blender.app/Contents/MacOS/Blender --background \
  --python tools/render_rig_review.py -- \
  game/assets/creatures/<species>/<species>.glb \
  game/assets/creatures/<species>/work/qa/review \
  --clips idle walk run attack_primary attack_heavy hit_react knockdown death alert \
  --samples 7 --view three_quarter
```

Run `python3 tools/bake_clip_speeds.py --dry-run` after locomotion changes; apply the bake only when the reviewed clips are final.

**Exit gate:** clip contract complete, contacts and timings reviewed, clean loops/transitions, no root drift, and no deformation regression.

### 7. Export and provenance

Export the exact layout from `SCHEMA.md`: base model at `<species>.glb`, one same-armature file per clip under `anim/`, accepted references under `ref/`, and intermediates under ignored `work/`.

Update the JSON `pipeline` block with forward axis, measured source dimensions, version, source/task IDs, donor or authoring route, clip list, and credits actually spent. Never overwrite the last accepted version until the replacement passes all gates.

**Exit gate:** deterministic file layout, complete provenance, clips share the base rest skeleton, and the prior accepted asset remains recoverable.

### 8. Godot integration

Verify the animal in `game/scenes/dev/creature_lab.tscn` and `game/scenes/dev/creature_anim_lab.tscn`, then in a real island encounter.

Check:

- visual height/length matches data after `CreatureView` normalization;
- collision radius/height, melee reach, target ring, nameplate, selection, occlusion, corpse, and interaction points fit the visible model;
- locomotion speed and animation cadence agree; no skating or terrain sinking;
- AI states choose valid clips and gameplay hit timing matches animation contact;
- camera framing works at min/default/max zoom and on mobile aspect ratios;
- coloration/patterns stay attached through animation;
- eyes are anatomically sized in daylight and remain a bright, small eyeshine at night;
- the animal meets current draw-call, material, texture-memory, and polycount budgets.

Run:

```bash
G="$(tools/find_godot.sh)"
"$G" --headless --path game --script res://tests/t_canim.gd
"$G" --headless --path game --script res://tests/t_eyeglow.gd
tools/smoke.sh
```

Then run the native game with touch emulation and inspect the animal in motion:

```bash
"$G" --path game -- --touch
```

**Exit gate:** automated tests pass, mobile/touch playtest passes, and a reviewer accepts the animal at actual gameplay distance in day and night lighting.

## Review record

Each species report should finish with this compact ledger:

| Gate | Evidence | Reviewer | Result |
|---|---|---|---|
| Brief/reference | accepted reference paths | | pass/fail |
| Static mesh/material | `sheet.png`, dimensions, polycount | | pass/fail |
| Rig/weights | audit JSON and worst-pose renders | | pass/fail |
| Animation | review sheet, clip/contact notes | | pass/fail |
| Godot integration | test output and lab screenshots | | pass/fail |
| Mobile performance | device/build, frame time, memory | | pass/fail |

Also record credits approved, credits spent, task IDs, rejected attempts and why, known limitations, and the exact next action. This ledger is what makes the workflow scalable: a new animal follows the same gates, and reviewers can reject a bad stage without guessing what “done” meant.
