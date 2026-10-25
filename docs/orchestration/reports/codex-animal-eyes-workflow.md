# Codex report: animal eyeshine and production workflow

Date: 2026-10-23

## Shipped

- Corrected glowing eyes across every species that uses the eyeshine system, including Compsognathus.
- Eye glow is now capped by the animal's real height with an absolute 2.5 cm maximum radius and a 5 mm surface offset, so it reads as an eye highlight instead of a protruding eyeball.
- Eye placement pushes away from the midpoint between the authored left/right points, which remains valid on transplanted rigs whose head-bone axes are rotated.
- Protected the shared eyeshine material from the creature coloration pass. That pass was stripping the glow material and exposing the blue-grey sphere geometry.
- Increased night HDR intensity and reduced the day fraction so the smaller geometry stays bright in darkness without dominating the daylight model.
- Added `docs/art/animal-production-workflow.md`, a reusable stage-gated workflow from brief/reference approval through mesh, cleanup, rig, skinning, animation, export, Godot integration, mobile QA, and provenance.

## Assumptions

- Eye radius is at most 0.6% of animal height, clamped to 6-25 mm.
- Eyeshine is offset at most 5 mm from the authored eye point.
- Full-night HDR intensity is 20; daylight uses 1% of it.

These constants are marked `ASSUMPTION` at their code definitions.

## Verification

- `game/tests/t_eyeglow.gd`: PASS for all glow species, including size caps, material preservation, brightness, head attachment, animation tracking, and death behavior.
- Native Compsognathus eye lab: PASS (`night_peak=0.71`, `night_head=0.11`, `eye_px=5.7`).
- `game/tests/t_canim.gd`: PASS for the complete creature animation contract.
- `tools/smoke.sh`: `SMOKE PASS`.

## Known limitation / next agent

- Existing accepted creature meshes and animations were not regenerated. Each future animal should follow the new workflow and must pass both automated deformation checks and human worst-pose review before integration.
- The workflow intentionally requires explicit credit approval before paid Meshy stages.

## Failed work and credits

- No requested behavior remains failed.
- Meshy credits spent: 0.
