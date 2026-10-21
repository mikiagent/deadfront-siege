# 28. Jungle cliff and tall jungle tree concepts (owner, 2026-10-21)

Owner's words, verbatim: "jungle cliff concept" (two images) and "tall jungle tree concept" (one image). Spec 27 covers the
other green-screen sheets: same art style, same green background for chroma keying.

References (docs/reference/):
- `concept-jungle-cliffs.webp` is a target, not a cut source. Its left half is a finished scene. Its right and bottom halves
  are a kit on an olive background, which a chroma key cannot cut cleanly.
- `2d-assets/sheet-jungle-cliffs.webp` is a green-screen sheet.
- `2d-assets/sheet-jungle-trees.webp` is a green-screen sheet.

The rest is the orchestrator's reading of the images, not the owner's text.

## The scene (target look for the tropical jungle zone, islands plan 1.4 "Tropical: jungle, lagoon ...")
- **The landmass.** It reads as stepped plateaus of grey-ochre limestone, with mossy tops and vine- and root-hung faces. Two
  or three tiers stand 5-15 m tall.
- **Water.**
  - Several waterfalls drop tier by tier into turquoise pools.
  - A river winds from the pools to a sand beach.
  - Sea stacks and rock islets stand in clear shallow water.
- **Vegetation.**
  - Giant buttress-root trees and coconut palms grow on the plateaus.
  - Ferns, bromeliads with red leaves, and banana plants fill the understorey.
- **Small details.** Sandy paths cross the plateau tops. The beach has shells, driftwood and fallen logs.

## The cliff sheet (the kit)
- **The landmark.** A big tiered cliff with a double waterfall and curtains of hanging roots.
- **Cliff blocks.** Plateau chunks, a natural arch and a long arch, and tall pillars or sea stacks, some with a palm on top.
- **Waterfall chunks.** Three small cliff pieces, each with a fall and a splash.
- **Rocks.** Boulders, flat slabs and small rocks.
- **Hanging growth.** Vine and root curtains.
- **Plants.** Palms, banana plants, ferns and bromeliads.
- **Beach debris.** Shells, driftwood, and log and branch bundles.

## The tree sheet
- **Row 1, canopy trees.** Six giant buttress-root canopy trees with hanging vines (kapok or fig-like). One variant is tall
  and slender, and one is small.
- **Row 2, palms and banana plants.**
  - Coconut palms: leaning, tall and slender, in clusters, and young.
  - One tall tree covered in vines.
  - Banana and traveller's-palm plants.
- **Row 3, understorey.** Vine-draped small trees, saplings, a bromeliad cluster with red leaves, tree ferns, cycads and
  broadleaf shrubs.

## What it means
- **Cut them like spec 27.**
  - Run the two green sheets through the same SPRITES2D cut-out as the four spec 27 sheets.
  - Leave the olive-background concept uncut; it is a reference.
- **The tall trees** are jungle-zone trees. They are resources (wood), shown as 2D cards with the spec 25 sway and parallax.
  Their buttress roots block movement; the hanging vines do not.
- **The big cliffs, arches and pillars** are non-resource props.
  - They block movement and cannot be destroyed (owner: "most props can be destroyed except for like really big cliffs").
  - The small boulders, slabs, vines and shells are props that can be destroyed. The step-over rule decides which of them
    block: a top above 1.25 m blocks.
- **Waterfalls** are props too. ASSUMPTION: the falling water scrolls or flickers in the shader, the splash gets a little foam
  mist, and the plunge pool is ordinary water.
- **Terrain shape still comes from the heightmap** (islands plan P3: cliffs and terraces).
  - These cliff cards dress the faces and the coast. They do not replace the terrain.
  - Cliff faces from the heightmap should paint the same grey-ochre rock as the cards, so the two meet without a seam.

## Tall grasses on terrain (owner: "tall grasses on terrain concept", same day)
Reference: `2d-assets/sheet-tall-grasses.webp`, a green-screen sheet in the same style. Orchestrator's reading:

**What the sheet holds.**
- Ground tiles, drawn as iso diamonds: bare dirt, sparse grass, lush grass, mixed weeds, trampled grass, muddy grass, dry
  golden grass and marsh water. There are also edge and corner pieces where grass meets dirt.
- Single grass clumps, small to tall, both green and dry.
- Cattail and reed clumps, leafy weeds, and long low grass strips (one with a fallen log).
- Dirt paths and clearings fringed with grass.
- Three large ground patches:
  - a dry savanna clearing with a banana plant;
  - a muddy marsh with puddles;
  - a reed-fringed pond.

**What it means.**
- The clumps, reeds and strips are the **ground cover** that islands plan P2 calls the biggest gap: wide, low clump cards
  scattered densely, swaying, never blocking movement. Cut them with SPRITES2D.
  - Map them to the families Grass, WildGrass, DryGrassTuft, FibreTuft and ReedPlant when the clump is gatherable.
  - Otherwise map them to `prop:grass_clump` or `prop:reeds`. These never block, and are destroyable.
- The **iso tiles are colour and texture references** for ground painting (plan P1), not game pieces. The terrain is a 3D
  heightmap seen by a camera that is not locked to the tiles' angle.
  - ASSUMPTION: cut them, mark them `unused`, and sample their colours for the grass, dirt, dry and marsh zone palettes.
- The **large patches** show how zones blend: dirt shows through, clumps thicken at the edges, and reeds ring the water. They
  are a target for the zone-edge look, not sprites to place. ASSUMPTION: same handling as the tiles.
