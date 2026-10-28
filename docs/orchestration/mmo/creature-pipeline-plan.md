# Creature 3D pipeline plan (concept to shipped clips)

Status: **proposal**, 2026-10-28, from the jaws + gaits thread. Nothing here is shipped except `tools/jaw/`
(prototype, T. rex only, not copied into the game). Earlier gait work: [locomotion-lessons.md](locomotion-lessons.md)
on `claude/mmo-locomotion`.

## What is wrong today (measured)

| problem | evidence | cause |
|---|---|---|
| No jaw on 9 of 11 species | glTF node names: only `tyrannosaurus` (`Jaw`) and `stegosaurus` (`jaw`) have one | Meshy auto-rig skeleton (39/41 nodes) has no jaw bone; every Meshy species inherits that |
| T. rex mouth stretches "like tape" | `alert` opens the jaw 52 deg (`attack_primary` 34, `feed` 26); weights were only tested at 25 deg. Renders: lip faces span upper to lower jaw | the generated mesh has the mouth **shut** (our prompts ask for "mouth closed"), so upper and lower lips are one surface. A jaw bone on a fused surface can only stretch it. There is also no mouth interior |
| Moonwalking | `python3 tools/audit_gaits.py`: stance-foot drift is **positive** (foot slides forward while planted) on coelophysis, compsognathus, gallimimus, utahraptor, velociraptor walk and run; T. rex walk has one foot each way (L -0.77, R +0.78). Deinonychus and the quadrupeds are negative (correct) | the Meshy library walk/run is authored for its own forward axis; on our import contract it plays backwards, and the auto-rig foot weights add slide |
| Same walk/run across species | all six Meshy bipeds: walk 2.46 s, run 0.71 s; utahraptor and velociraptor run drift identical (+0.488 / +0.429). Megaloceros, protoceratops, stegosaurus v1: walk 1.62 s, run 0.96 s | Meshy's rig step hands every biped the same library walk + run, and every quadruped the same pair. Walk and run differ from each other, but not between species |

## Concept prompts in use

1. **Meshy route**, `tools/creature_pipeline.py` (`BIPED_SIDE`, `BIPED_FRONT`, `QUAD_SIDE`, `QUAD_FRONT`), sent to
   Meshy text-to-image (`nano-banana-pro`), then Meshy multi-image-to-3d. Side view text:
   "Orthographic left-side profile of a {name}, accurate palaeoart, full body, spine horizontal and parallel to the
   ground, long stiff tail straight back. Only two legs touch the ground. Forelimbs SHORT and folded up against the
   chest, clawed hands tucked at the ribs far above the knees, clearly arms not legs. {look} neutral standing pose,
   flat even lighting, plain white background, no shadow, no text, whole animal visible with margin."
   `{look}` is the species JSON `look` field.
2. **Tripo route**, `game-asset-pipeline` skill: Codex (or Higgsfield GPT Image 2.5) four-view sheet (front, left,
   right, back), owner-approved, then Tripo P1 multiview. The T. rex came this way.
3. **Templates**, `docs/art/durango-asset-benchmarks-and-tripo-prompts.md`: theropod/quadruped text plus a negative
   block that includes **"open mouth"**, and a neutral pose line that says **"mouth closed"**.
4. **Standard**, `assets/concept-art/STYLE.md` "Reference-sheet standard".

## The plan

### 1. Concept prompt (owner gate for new species only)
Keep the existing four-view standard and add to the pose line:
"mouth slightly parted, lips apart with a visible dark gap along the whole mouth line, teeth of both jaws separate".
Remove "open mouth" from the negative block and replace it with "wide open mouth, roaring". A slightly parted mouth
gives the mesher two lip surfaces, which removes most of step 3's surgery. Re-sheeting an existing species is a
Milan gate; fixing its rig is not.

### 2. Generation
- Tripo (multiview from the approved sheet) for hero creatures, Meshy multi-image for the rest. Existing balances only.
- Generate **mesh only** where possible; never accept the generator's library walk/run as final clips.
- Tripo is fine because we do not retarget its animations: we rig our own skeleton (step 3) and author clips on it.

### 3. Rig (every species, including existing ones)
0. Cleanup before rigging (required): `tools/transplant_rig.py` repair drops loose shells under 1 % of the mesh,
   merges doubles and fills holes (the new deinonychus lost 588 stray fragments). Afterwards check islands: only
   the body, teeth and claws may remain; `open_mouth.py` pins teeth rigid and moves pieces an auto-rig left on a
   stray bone (Tripo's `neutral_bone`) onto the Head or Jaw, or they float off the head in game.
1. Skeleton with a **`Jaw` bone** under `Head`, pivot at the jaw joint (measure the mouth crease from the mesh, as the
   T. rex REPORT did). Meshy-rigged species get a `Jaw` bone added under their head bone; no other bone changes, so
   existing clips stay valid.
2. Weights: bone-heat, then the T. rex fixes (hard Head/Jaw split, teeth islands rigid), then
   `tools/jaw/open_mouth.py` to rip the lips along the mouth line and add a mouth bag (palate on Head, floor on Jaw,
   throat at the corner). Lips still meet with the mouth shut.
3. Foot weights checked with `fix_weights.py` / `measure_skin.py` from the locomotion branch, kept only if they win.

### 4. Clip set per species (authored on our skeleton, not library clips)
| clip | rule |
|---|---|
| idle | breathing, tail sway, small jaw movement |
| walk | footfall-table gait from `tools/gait/make_gait.py` (locomotion branch): lateral-sequence for quadrupeds, alternating for bipeds; stride from leg length |
| run | a different gait, not a sped-up walk: trot/gallop for quadrupeds, suspended run for bipeds; shorter duty factor |
| attack_primary / bite | jaw opens 30-45 deg, snaps shut on the hit frame |
| alert / roar | jaw 45-55 deg, held |
| feed / eat | head down, 3-4 small bites, 15-25 deg |
| sleep, death, hit_react, knockdown | as now |

Per species numbers (stride, cadence, jaw angles) live in `<species>.json` next to the gait config.

### 5. Automatic checks (block the clip, no human needed)
- **Moonwalk:** stance-foot drift must point backwards relative to travel for every planted foot, and its speed must
  match the clip's natural speed within 15 %. `tools/audit_gaits.py` already measures drift; make it exit non-zero,
  calibrated on known-good (deinonychus, the new megaloceros walk) and known-bad (velociraptor walk) first.
- **Walk vs run:** distinct cadence and duty factor, not only different values.
- **Across species:** no two species share a walk or run clip (duration + per-channel compare).
- **Jaw:** at the clip's widest jaw frame, no skin edge stretches over 1.5x its rest length and the upper skull
  does not move (`measure_skin.py --where` on the head).
- **Grounding and loops:** existing checks (lowest vertex at 0, loop first == last frame).

### 5b. Commit what Godot unpacks
After replacing a creature GLB, run `Godot --headless --path game --import` and commit the textures it extracts next
to the GLB (`<species>_<Color|NormalGL|ORM>_<task>.*`) with their `.import` files, plus the `.import` of every new
clip. Untracked, a checkout with a stale import cache cannot load the creature.

### 6. Review gate (GAUNTLET)
Matched before/after renders and short clips per species (`tools/jaw/render_head.py` for the head,
`render_clip.py` for gaits), blind A/B judge with sides flipped per scene; the new version must win. Then the anim
lab in game, natural speed rebake (`tools/bake_clip_speeds.py`), smoke.

### Per-species checklist
- [ ] `Jaw` bone, pivot measured
- [ ] lips ripped, mouth bag, closed mouth seals
- [ ] teeth rigid
- [ ] own walk + own run, gait checks pass, no moonwalk
- [ ] bite / roar / eat clips use the jaw
- [ ] blind A/B won, anim lab looked at, speeds rebaked

Order: T. rex (done as prototype) -> velociraptor, utahraptor, deinonychus (the hunt loop) -> other bipeds ->
quadrupeds.

## T. rex prototype result

`tools/jaw/open_mouth.py` on `tyrannosaurus.glb`: weld 18,008 -> 7,025 verts, 29 teeth islands rigid, lip line taken
from the teeth roots, 330 lip faces ripped at the exact crossing, 17-slice mouth bag, a 5 cm lining wall behind every
torn edge. Material: [jaws/tyrannosaurus/](jaws/tyrannosaurus/) (`before-after-roar.png` is old left, new right; the
`scene*` stills and mp4s are the blind set, answers in `ab-key.txt`).

Blind judge, three rounds with sides flipped per scene:
| round | change | open-mouth scenes won by new | closed mouth |
|---|---|---|---|
| 1 | rip + bag, black texel | 2 of 3 | lost slightly (chin crack) |
| 2 | gum-red texel, bag keeps own normals | 3 of 3 | lost slightly (zig-zag seam at the chin) |
| 3 | lip line from teeth roots, exact-crossing cut, lining wall | 3 of 3 | tie |

The judge still calls neither version shippable up close: torn-looking lining edges, stray slivers near the snout tip,
flat-shaded interior plates. At the game camera the new mouth reads as a mouth; the old one reads as a sheet.
Not copied into `game/` yet; next polish: smooth and subdivide the bag, drop lining walls on edges shorter than 1 cm,
re-check which side each front tooth belongs to.

## Tools and skills checked
- Skill catalog search (Blender, rigging, animation, retarget, 3D, Tripo): nothing relevant to install.
- `game-asset-pipeline` (our own skill): the right base. It has anatomy verifiers but no jaw step and no foot-slide
  check; steps 3 and 5 above should be added to it.
- `github.com/kevinbadi/blender-skills` (checked 2026-10-28, commit b2f0f81): product-video camera moves, PolyHaven
  materials/HDRIs, a Three.js export, Meshy image-to-3D wrappers (we already have `tools/meshy.py`) and a copy of
  Dev-GOM's `blender-toolkit` (Mixamo humanoid to Rigify retargeting over a WebSocket addon). Nothing for jaws,
  weights, quadruped/theropod gaits or foot contact. No licence file, so the code is not ours to copy. Idea worth
  keeping: score a bone mapping by how many critical bones matched before auto-applying a retarget.
- `github.com/EL4CTEO/blender-skills` (checked 2026-10-28, commit 71d031d, **MIT**, Blender 5.2, 22 skills with tests):
  the better of the two. Nothing for jaws, theropod/quadruped gaits or foot-contact checks either; its rigging and
  stress poses assume humanoids (Rigify, Mixamo, UE, Roblox). Worth taking: `rig_check.py`'s skin checks (weights on
  root or non-deform bones, more than 4 influences, unnormalised, L/R asymmetry), which match locomotion lesson 6, and
  `blender-animation`'s Blender 5.x notes (actions use slots and channelbags; `action.fcurves` is gone). Its scripts
  were read, not run here (running outside code needs Milan's OK).
- `universal-modder:asset-pipeline`: 2D sprites from 3D, not useful here.
- Blender MCP: failed to connect this session; everything ran as headless Blender scripts, which is also what
  dsc workers can run unattended.
