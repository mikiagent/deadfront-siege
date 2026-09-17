# C2 three-theropod handoff

Status: BLOCKED at rigging, not complete. All three Meshy rig submissions returned HTTP 422, `Pose estimation failed, please provide a valid model`. None returned a task ID. No final species GLB or required animation clip has shipped. Do not integrate the intermediates as completed creatures.

## Budget and stages

Balance before: 3,871. Balance after: 3,823. C2 spent 48 of 300 credits. The rejected rig requests cost zero by balance reconciliation. C1's 24 credits are separate.

| Species | Reference | Textured image-to-3D | Rig | Animation | C2 credits | Verdict |
|---|---|---|---|---|---|---|
| Utahraptor | Reused C1 | Reused C1 | HTTP 422 at 2.0 m | Not submitted | 0 | Blocked |
| Deinonychus | First attempt accepted, 9 | First attempt, 15 | HTTP 422 at 1.2 m | Not submitted | 24 | Blocked |
| Velociraptor | First attempt accepted, 9 | First attempt, 15 | HTTP 422 at 0.8 m | Not submitted | 24 | Blocked |

No retries were spent. Repeating the same deterministic rejection without changing the input would not address pose estimation. The prompt permits mesh regeneration for failed silhouettes, but another silhouette attempt would not resolve the demonstrated humanoid-rig limitation. No text-to-motion or preset application was submitted without a successful rig.

## Task IDs

| Species | Reference | Image-to-3D |
|---|---|---|
| Utahraptor, C1 reuse | 01a0b175-73e3-70d1-9fdc-cca7041aa146 | 01a0b176-5fef-720d-b1ba-017c28587335 |
| Deinonychus | 01a0b17b-1fad-7691-9116-53e883622c01 | 01a0b17b-ab48-721c-8493-0ff19ff49bf3 |
| Velociraptor | 01a0b17d-8fc2-7493-aaec-d11213e1fcf0 | 01a0b17e-628c-74f6-9f88-b6e289c93bbc |

Utahraptor's historical preview remains `01a0b154-f2ac-746c-9437-931104d6a615`. IDs are in `tools/meshy_state.json` and each species JSON pipeline block. Each `work/C2_rig_failure.json` records the rejected request's source, height, status and error. There are no rig or animation task IDs to record.

## Art evidence

Each species has `ref/<species>_side.png`, `work/<species>_i2m_v1.glb`, and `sheet.png`. Reference and work folders have `.gdignore`. Sheets are four static views, not animation contact sheets, because there are no animations.

- Utahraptor retains C1's horizontal back, long tail and visible claws. Neck/chest defects remain. C2's prohibition on local mesh re-export and rotation was respected; no repair was attempted that would leave the local mesh different from the task input being rigged.
- Deinonychus reference and side mesh show a roughly horizontal spine, a tail around half total length and clearly raised sickle claws. The top view reveals a forked tail-feather shape and the front view has protruding shoulder geometry. These are art defects, not a production pass.
- Velociraptor reference shows the feathered body and long tail, but its legs overlap. The mesh preserves a horizontal back and roughly half-length tail. Its sickle claw is weak, and the front view shows stretched triangles. Signature-feature acceptance is not established.

All three raw models face -X in GLTF. None was rotated. A game-side 180-degree Y turn alone does not fix this mismatch with the +Z asset contract.

Measured visible-mesh heights are 0.5 m for Utahraptor, 0.6 m for Deinonychus and 0.5 m for Velociraptor. All fail the 15% height tolerance against 2.0, 1.2 and 0.8 m respectively. The planned rig height adjustment never ran successfully.

Deinonychus's image-to-3D GLB unexpectedly already contains a 62-bone skeleton rooted at `root`, with `pelvis`, `Tail0` through `Tail6`, and IK bones. It has no animation actions. It is not a completed Meshy rig task and cannot be supplied as `rig_task_id`. Utahraptor and Velociraptor intermediates have no armature. No walk/run clips were returned, embedded or separate.

## Presets selected, not purchased

Read the BodyMovements and Fighting catalogues, then searched idle names. Selected the same intended mapping for all species:

| Clip | ID | Library name | Reason |
|---|---|---|---|
| idle | 0 | Idle | Neutral idle without a weapon or prop |
| hit_react | 178 | Hit Reaction | Generic hit reaction rather than gunshot or airborne reaction |
| death | 8 | Dead | Generic death rather than a weapon-specific fall |

These choices are based on library names. Their actual sway, stagger and final ground pose remain unverified. Every required clip is missing; telegraph holds and side-lying knockdown holds cannot be judged.

## Tooling and checks

- Rigging prefers recorded `i2m` over legacy `refine` and passes the species height. Preview, refine, rig, preset and motion stages now resume recorded task IDs instead of submitting twice.
- Motion generation refuses to spend without a recorded rig. It includes the required duration field. `# ASSUMPTION:` four seconds allows anticipation, action and recovery or hold; this still requires visual validation.
- Fetch reads rig and animation URLs from the documented `result` object. It writes contract filenames, keeps intermediates in `work/`, and splits merged preset clips in API action order. The splitter changes animation JSON only; binary data, skinning and node transforms remain intact. It reports absent separate walk/run clips for inspection rather than inventing them. Embedded-only walk/run extraction remains to be implemented if a successful task needs it.
- Rendering frames evaluated visible geometry and excludes hidden bone custom shapes. This fixed misleading bounds and small renders on the generated Deinonychus skeleton.
- `--validate-clips` checks the nine required files, nonempty identical bone sets and positive animation durations. Its real Deinonychus check correctly failed with all nine clips missing. Successful animated output and animation contact-sheet rendering remain unverified and unfinished.
- Mocked checks passed for rig source selection, resume without duplicate submissions, required motion duration, and lossless clip splitting. The earlier Godot 4.7.1 smoke check printed `SMOKE PASS`. The final rerun failed after concurrent game-side edits: `Data` is undefined in player code, `res://scenes/creatures/creature.tscn` is missing, and the smoke player is absent. These are outside Codex ownership; the latest smoke result is FAIL.

No scenes or scripts were changed. Unrelated staged archive moves were left to their owner.

## What must change before continuing

The C2 premise that any biped can run this API route is disproved by the three requests. Meshy's current [rigging documentation](https://docs.meshy.ai/en/api/rigging) explicitly excludes non-humanoid assets and identifies this 422 as pose estimation failure. It also requires +Z facing for URL inputs, so switching to `model_url` with these unchanged -X meshes is not a sound retry.

The orchestrator needs to choose a dinosaur-capable rigging workflow, such as manual Blender rigging and animation, and resolve permission to correct facing and scale. Preserve these references and intermediate meshes for that work. Revisit chest/shoulder geometry and tail feathers before skinning. Do not spend the remaining 252 credits on unattached motion clips.

API details verified against the official [animation](https://docs.meshy.ai/en/api/animation) and [text-to-motion](https://docs.meshy.ai/en/api/text-to-motion) docs. Motion application needs a successful Meshy rig task, and motion creation requires duration. The handoff is evidence and resumable tooling, not three animated creatures.
