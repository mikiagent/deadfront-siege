# 3D-RESOURCES (full-3D package 3), part 1: trees and palms draw under the model path

Branch `claude/mmo-3d-resources`, cut from canon 23c8407c. No credits spent.

## Cause of "trees and palms do not draw under --models"
BUILDSPEED (07be76d0) removed the `for b in rt._batches: b.commit()` loop from `IslandScatter.scatter`
while every resource drew as a card (the list was always empty then). Under `--models` every resource
batch was filled but never committed, so no MultiMesh cell was ever created: trees, palms, bushes, rocks
and every other resource model stayed invisible, with only the tree shadow discs left standing. Restored
the loop (empty and free under cards).

## Dead model paths
The A/B report counted 30 dead nature model paths on the cloud box. On the Mac every `.glb` named in
`game/data` for nature resolves (0 missing); the cloud checkout lacked those files. Nothing to fix here.

## Check
`t_card2d` now asserts that under `resource_render = "model"` every tree's batch has a drawn cell
(55 of 55 on home_grassland). It fails without the fix (0 of 55).

Shots (Mac, `--lab=ab3d_lab --models --only=trees`): `3d-resources/ab3d_models_home_trees.png`,
`ab3d_models_jungle_trees.png`. Trees, birches and bushes draw with shadows.

## Not done (needs the owner)
The default stays `resource_render = "card"`. Flipping it is a visual-direction call for Milan after an
A/B, and most nature GLBs are untextured placeholders, so the flip waits for packages 4-6 (new art).
