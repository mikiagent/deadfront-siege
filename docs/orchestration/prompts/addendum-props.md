# Addendum for Cursor: building and tool visuals (applies to M6 and later)

`game/assets/props/kenney/` holds 80 CC0 Kenney Survival Kit models re-exported at metre scale with textures embedded. `game/data/props_manifest.json` maps game ids to models: every building in the M6 catalogue (bonfire, workbench, drying rack, tent, bedroll, basket, large box, chest, fence, gate, taming pen ring, sign, floor, wall, roof), the tool models (work axe, axe, hammer, pick, hoe, shovel) and pickup visuals for logs, planks, stone and branches. `model_sizes_m` gives each model's real size so footprints and collision boxes can be derived rather than guessed.

Rules:
- `BuildPlacer` ghosts and placed buildings use the manifest model; the taming pen is a 4x4 ring of `fence-fortified` with one `fence-doorway`.
- Tools held by the survivor attach to the `RightHand` bone attachment from M4a; scale the tool model so its handle spans the hand.
- Dropped items on the ground use `resources_pickups` where a model exists, otherwise the generic bag icon.
- Nothing in `game/assets/props/` is edited by hand; ask the orchestrator for changes.
