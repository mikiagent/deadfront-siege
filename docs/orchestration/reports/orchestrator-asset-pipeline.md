# Orchestrator report: asset pipeline settled (2026-09-17)

## Findings
- Meshy rigging API: humanoid only. Web app: humanoid, quadruped (walk only), Smart Rig beta (no animations). Tripo v2.5: non-humanoid rig types exist but presets are walk-only. Anything World: dogs/cats/horses/humanoids documented, no theropods. No AI service delivers dinosaur combat clips.
- Meshy image-to-3D from a generated orthographic reference gives correct theropod silhouettes reliably (C1/C2 evidence), so Meshy stays the mesh and texture source.
- The Deinonychus GLB's 62-bone skeleton has no vertex weights; it is decoration, not a rig.

## What was built
- `tools/transplant_rig.py`: Quaternius CC0 velociraptor rig (37 bones; idle/walk/run/attack/jump/death) fitted into the Meshy meshes, weighted through a voxel proxy (bone-heat fails on holey AI meshes: 0% weighted direct, 100% via proxy), armature transform baked with location keys rescaled, exported as base GLB + armature-only clip files. Verified in Blender posed renders and through Godot's importer for utahraptor, deinonychus, velociraptor.
- `tools/render_posed.py`: posed contact frames for any GLB, with `--anim` to apply separate clip files.
- Survivor player character through Meshy: `nano-banana-pro` T-pose reference (9), Meshy 7 textured PBR mesh at 20k tris (30), rig at 1.72 m (5), presets idle/hit_react/death (9). Free walk/run from the rig. 53 credits total; balance 3,770. Layout `game/assets/characters/survivor/` matches the creature contract; Godot import verified (24 bones, clip tracks resolve after the M1b remap).
- Blender MCP (`mcp-for-blender`) installed as a Blender 5.2 add-on and registered for Claude Code, Cursor and Codex. One client at a time.

## Open
- Transplant fit is bounding-box only and meshes are unrepaired: C2b (Codex).
- Survivor needs attack, roll, gather, knockdown, mount clips: C2b part B (Codex, ≤80 credits).
- Cursor M1b must land before any of these files animate in-game; M4a then swaps the capsule for the survivor.

## Addendum 2026-09-17 evening: Utahraptor redo
The v1 reference showed the arm hanging to the ground, so Meshy built four leg-like limbs. Regenerated as two references (side + front, arms folded high, 9 credits each) and a Meshy 7 multi-image mesh (30). Result: two legs, short folded arms, no holes. Re-transplanted; front and side posed renders confirm. 48 credits; balance 3,722. Lesson for the roster: always generate a front view alongside the side view, and state "hands tucked at the ribs, above the knees" for every theropod.
