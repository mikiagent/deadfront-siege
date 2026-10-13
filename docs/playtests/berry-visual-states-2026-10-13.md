# Berry visual states - October13

Base8f771cc contains the corrected accepted green shrub pairs. No snowc pair exists. BushBerries and berry_bush now map fulla/b models to their explicit empty counterparts. No yields, regen durations, pool sizes, collider dimensions or resources changed.

HarvestNode chooses full/empty from berry or berries availability, not whole-node depletion. Other yields may remain when berries run out. Individual pool refill and save restore refresh the visual. Fully depleted bushes keep their bare foliage, with collision/tap layers disabled until a yield returns. Both batches share the exact same transform, so no size/yaw jump. Post-batch commit refresh handles initial states; VegBatch retains visibility on later recommits instead of resurrecting both states.

Generated berry-bush clump placement now keeps centre separation at least3.8m (acceptedb can be3.6m wide at2.2m height). The existing narrow0.55m collision shape is unchanged. This spreads crowded shrubs enough to read separately, without making a new broad collider that jams routes. Non-berry and snow bushes remain unchanged.

## Verification

Godot4.7.1 full regression PASS; boot smoke PASS. Added `--lab=berry_state_lab` deterministic home-world fixture using actual manifest/renderer/HarvestNode pool consumption:
- Full/empty batch state, exact paired transforms, depletion through consume_unit, no berries after berry pool reacheszero.
- Empty foliage retention with collision/tap disabled when fully depleted.
- Refill, save restore, berries absent while fibre remains, and correct batch state after recommit.
- Procedural home39mapped berry bushes; nearest centre separation4.00m.
- Actual navigation through the fixture clump advances11.00m in6seconds without a stall.

Rendered800x450 home-world captures inspected: two full and two empty shrubs, then all depleted, then regrown. Close view shows pink/magenta berry dots disappear from both shapes while foliage stays; untouched nearby shrub retains berry dots as a control. B is broad and dome-shaped, a is branchier, clump silhouettes remain separate. Existing Compatibility lighting is pale; raspberry/magenta fruit matches the accepted QA nuance, not oversized candy. No material rework performed.

These are seeded deterministic fixtures, not earned gathering/player-feel acceptance or production performance measurement. No production deployment from this workspace. Parent owns authenticated landing/deployment follow-through.
