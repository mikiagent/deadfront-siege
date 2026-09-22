# DEADFRONT art bible

## North star

Grounded prehistoric survival realism, optimized for a readable desktop isometric camera. The result should look custom and coherent across creatures, survivors, gear, stations, props, and biomes. Realism controls anatomy and materials; simplified shape hierarchy keeps silhouettes readable during play.

## Creatures

- Use anatomically credible proportions and locomotion.
- Preserve the defining silhouette and features of each species at gameplay distance.
- Use restrained natural colors and scientifically supported feathering.
- Reject movie-monster frills, tripod postures, rubber limbs, fused feet, broken or dragging tails, floating parts, holes, stray triangles, and decorative anatomy that compromises the species.
- Reference poses must expose the pelvis, shoulders, limb joints, feet, underside, tail base, and signature structures. Separate limbs enough for rigging. Avoid overlapping legs.
- Mountable species use the same approved creature mesh, skeleton, textures, and animations in both variants. Saddles attach to a named `MountSocket`; never regenerate the whole animal with a saddle baked into a different body.

## Survivors, gear, and built objects

Use practical field-survival construction: weathered fiber, hide, bone, stone, wood, and later copper, bronze, iron, and steel. Keep tools, stations, weapons, and actions readable at gameplay scale. Share one material and edge-density language rather than generating unrelated props.

## World

Use realistic materials with controlled simplification. Player-made objects should read warmer against cooler wilderness. Nature is built as reusable biome families and local variants rather than hundreds of unrelated one-off models.

## Palette

- Natural, muted creature bases with species-specific markings.
- Warm survivor-made wood, hide, fiber, bone, and firelight.
- Cooler wild greens, stones, water, and atmospheric distance.
- Avoid glossy plastic surfaces, untextured gray output, and oversaturated fantasy colors unless a later approved biome explicitly calls for them.

## Reference-sheet standard

- Same individual, anatomy, markings, colors, and scale in every view.
- Neutral studio lighting and pale neutral background.
- Full side, front, top, and rear three-quarter views with no crop.
- Neutral animation-ready pose, visible feet and tail tip.
- Human scale silhouette only when it helps review; remove labels and scale figures from generation inputs.
- Concept review sheets may carry discreet view labels. Meshy generation inputs may not.

## Runtime target

- Desktop/laptop Chrome is the current native target; mobile must not break.
- PBR materials.
- 2K authoring maximum for hero creatures; target 1K or atlased runtime output where quality holds.
- Rough triangle targets: 10k-20k ordinary creatures, 20k-35k bosses.
- One material where practical, clean topology, LODs, correct real-world scale, grounded feet, stable pivot, and source facing aligned to the game's import contract.
- Every animated asset must pass inspected-pixel review in Blender and Godot, including deformation, foot contact, loop seams, attack timing, death pose, root motion, bounds, collisions, and mounted clearance where applicable.
