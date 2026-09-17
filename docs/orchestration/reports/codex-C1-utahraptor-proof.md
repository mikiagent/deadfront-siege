# C1 Utahraptor image-to-3D proof

Verdict: PASS for the requested silhouette proof. This is an unrigged intermediate, not a production-ready creature. Front and three-quarter views reveal neck/chest triangles and stretched surfaces that need repair before C2 rigging.

## Credits and tasks

Balance before: 3,895. Balance after: 3,871. Spent: 24 of the 60-credit cap. One image at 9 credits and one textured mesh at 15 credits. No second attempt, text-to-3D, rigging, or animation calls.

| Stage | Task ID | Result |
|---|---|---|
| Historical preview, no new cost | 01a0b154-f2ac-746c-9437-931104d6a615 | Preserved |
| Reference attempt 1 | 01a0b175-73e3-70d1-9fdc-cca7041aa146 | Accepted |
| Image-to-3D attempt 1 | 01a0b176-5fef-720d-b1ba-017c28587335 | Accepted for silhouette proof |

The supplied reference prompt exceeded the MCP tool's 600-character limit. Validation rejected it before task creation and without a charge. The shortened prompt retained the posture, tail, claw, feather, colour, and background requirements.

## Visual acceptance

Estimates below come from inspecting the side images, not skeletal measurements. The tail root is estimated at the rear of the pelvis, so ratios carry roughly five percentage points of uncertainty.

| Criterion | Reference attempt 1 | Mesh attempt 1 |
|---|---|---|
| Tail at least 40% of total length | PASS, about 55% | PASS, about 55% |
| Spine within about 15 degrees of horizontal | PASS, about 0–5 degrees | PASS, about 0–5 degrees |
| No upright tripod stance | PASS, body horizontal, tail off ground | PASS, body horizontal, tail off ground |
| Sickle claw visible | PASS, both raised toe claws clear | PASS, raised curved claws visible, less distinct at sheet scale |
| No frill or JP-style features | PASS, feathered body, no frill | PASS for silhouette, no frill; chest artifacts are a separate quality failure |

Accepted reference: `game/assets/creatures/utahraptor/ref/utahraptor_side.png`.

Mesh: `game/assets/creatures/utahraptor/work/utahraptor_i2m_v1.glb`.

Validation sheet: `game/assets/creatures/utahraptor/sheet.png`. Quadrants are left side, front, top, three-quarter.

Comparison: `game/assets/creatures/utahraptor/work/preview_sheet.png`. The old preview is a scaly theropod with a curved tail and no clear raised sickle claw. This particular old preview is less upright than the later failures described in the PRD; do not confuse it with those other attempts.

## Tooling shipped and validation

`tools/render_glb.py` imports GLB without altering source geometry, prints world bounds and any bone names, and renders a 1024 × 1024 four-view sheet using neutral white environment lighting. Tested first on the old mesh before spending credits, then on the new mesh. `--forward=-X` selects cameras for the new mesh's actual orientation. The default assumes contract-facing +Z in GLTF, which imports as -Y in Blender.

`tools/meshy.py i2m utahraptor` uploads the accepted PNG as a data URI and records `i2m` in state before polling. Repeating resumes the existing task. `--attempt 2` creates or resumes a separate recorded attempt. The command downloads into `work/` and creates `.gdignore`. Its request uses meshy-t2, smart-topology, triangles, 12,000 target polygons, GLB, texture and PBR enabled, 2k textures, and the species texture prompt. Fields were checked against the MCP schema. The image-to-3D schema has no geometry text prompt field, so the species geometry prompt was not sent as an unsupported field.

A mocked request/resume check proved that two invocations submit only once and verified model, topology, format, texture and PBR fields. An explicit second attempt submits separately. Godot 4.7.1 `tools/smoke.sh` printed `SMOKE PASS`.

## C2 handoff

- Keep the reference wording for horizontal spine and half-length stiff tail. It worked on the first attempt.
- Repair the neck/chest holes or stray triangles and stretched underside surfaces before rigging. Side-only conditioning leaves these areas poorly constrained. A matching front or three-quarter reference could help, but multi-image does not support smart-topology and needs a separately approved model and budget.
- The raw mesh faces -X in GLTF, not contract +Z. No rotation was baked into the asset. Coordinate the correction with the orchestrator before rigging; a game-side 180-degree turn alone cannot correct this source.
- Blender world bounds are 1.316195 × 0.287918 × 0.5 metres, with Z height. GLTF height is therefore 0.5 metres, below the species target of 2.0 metres. Set and validate the 2.0-metre rig height in C2. Old preview bounds were 2.810150 × 9.624060 × 5.0 metres in Blender.
- No armature exists in either intermediate. Required clips and final `utahraptor.glb` remain C2 work.

Assumption: the renderer defaults to the contract orientation; the explicit camera override handles this observed exception without mutating the mesh. No lore, mechanics, or species were added. Scenes and scripts were untouched.
