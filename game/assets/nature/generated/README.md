# Generated trees (Durango-style pilot)

Meshy production trees from the September 23, 2026 pilot, replacing lowpoly Quaternius trees over time. Species/biome mapping per docs/design/world-design.md and nature_manifest.json. Not yet wired into nature_manifest.json.

- `tree-common-a.glb`: broadleaf CommonTree, clumped crown, root flare (grassland/temperate).
- `tree-common-b.glb`: broadleaf CommonTree, rounded dense crown (grassland/temperate).
- `tree-palm-a.glb`: single palm, bushy crown (tropical/blue tropical).
- `tree-palm-twin.glb`: twin-trunk palm clump (tropical/blue tropical).

Rejected in pilot: bubble-crown cartoon common tree with grass disc; three umbrella acacias (faceted neon canopy, tiny crown on stick, floating leaf fragments); dead acacia and one palm with baked ground pads.

Pilot round 2 (September 23, 2026; generated without remesh for natural foliage, then Meshy remesh to ~30k triangles):
- `tree-acacia-a.glb`: umbrella thorn acacia, wide clumped canopy (savannah/desert).
- `tree-birch-a.glb`: white birch, oval clumped crown (grassland/temperate).
- `tree-willow-autumn-a.glb`: weeping willow with golden autumn foliage (swamp/temperate autumn variant).

Rejected in round 2: 2 acacias (ground disc; double crown), 2 birches (ground pad; white snow-like leaf patches), 3 pines (ground pads; sparse; bubble-cone crown), 2 willows (ground disc; washed-out gray foliage).

Pilot round 3 (September 23, 2026):
- `tree-pine-a.glb`: tall conical pine with layered needle tiers (temperate/tundra/snowfield).
- `tree-willow-a.glb`: green weeping willow (temperate/swamp).

Rejected in round 3: 2 pines (blobby bubble crown; too sparse), 1 willow (ground disc).
All generated GLBs use 1k JPEG textures for mobile.
- `tree-birch-b.glb`: second birch, slim white trunk with clumped crown and exposed roots.
- `tree-willow-b.glb`: second green willow, full weeping crown.

Rejected (variant b round): pine_v2 (puffball foliage, flared root skirt), acacia_v2 (cotton-ball crown, held back as borderline), common_v3 (root pad), palm_v3 (small pad).

Material-swap variants (recolored base-color texture of the committed meshes, no new generation):
- `tree-pine-snow.glb`: pine-a with snow-laden branches (tundra/snow biome).
- `tree-common-snow.glb`: common-a with frosted crown (snow biome edge).
- `tree-common-dead.glb`: common-a with withered brown foliage and greyed bark (wasteland/dead zones).
- `tree-birch-dead.glb`: birch-a with dried brown foliage.

Foliage regrade (Sep 24): the green trees (common a/b, birch a/b, pine-a, acacia-a, palm-a, palm-twin, willow a/b) had neon lime foliage albedo that read as highlighter green under the island's warm light. Their base-color textures were recolored toward deeper, less saturated greens: hue about 105 degrees, saturation capped at 0.45, foliage brightness normalized to V 0.38. Foliage now averages about RGB (70,97,55), matching the dark natural greens in docs/reference/durango-*. Snow, dead and autumn variants are unchanged.
