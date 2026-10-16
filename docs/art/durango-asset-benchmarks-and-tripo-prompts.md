# Durango asset benchmarks and Tripo prompt templates

**Date:** 2026-10-16
**Source:** the Unity data bundled in the Android client `durango-wild-lands-5-2-1plus2001141741.apk` (build 5.2.1, January 2020).
**Use:** a quality and budget target for Deadfront models generated with Tripo, and prompt templates that hit it.

## Ground rules

- **Benchmarks, not references.** This note records measurements and describes style in words. No Durango mesh, texture, screenshot or concept art goes into `game/` or into Tripo as an input image. Image-to-3D inputs must be Deadfront's own concept images.
- **Real species only,** per `docs/prd/dinosaur-roster-and-3d-pipeline.md`. The templates do not describe Nexon's original creatures or reproduce their markings.
- Measurements were read with UnityPy in a scratch folder outside the repo. Nothing extracted was kept.

## What the APK actually contains

The APK only ships the **prologue and character-creation content**. The full bestiary, buildings and islands were streamed from Nexon's servers, which are gone. So the benchmarks rest on:

- Two creatures: a **T. rex** and a **raptor**.
- About 24 survivor body variants across 8 occupations and 2 sexes, plus modular heads and about 25 hairstyles.
- The train set, the prologue scene, effects and UI.

Two creatures is a thin sample. Treat the creature numbers as the style's order of magnitude, not a per-species table.

## Budgets

| Asset | Triangles | Vertices | Bones | Texture |
|---|---|---|---|---|
| T. rex, 12 m raid boss | 2,986 | 1,776 | 31 | 512² colour, second 512² variant, tiny normal map |
| Raptor | 1,728 | 1,261 | 36 to 38 | about 512², separate "bloody" variant |
| Survivor body, outfit included | 1,250 to 2,000 | 850 to 1,600 | 24 | 128² to 256² tint mask |
| Survivor head | 230 to 340 | 150 to 270 | 1 | 16² to 128² |
| Hairstyle | 220 to 370 | 180 to 270 | 1 to 11 | 64² to 128² |
| NPC agent, full figure | about 2,700 | about 2,050 | 25 | 256² plus 64² skin and 32² hair |
| Train car, large static prop | 4,200 to 8,100 | 6,800 to 13,500 | 0 | lightmapped |

Texture sizes across the whole APK: most are 128², then 256² and 512². Only nine textures reach 1024², and none are creatures or characters.

**Deadfront comparison.** The current Meshy creatures are 24,000 to 31,000 triangles before remeshing. That is **10 to 15 times** Durango's budget for the same isometric camera. At isometric distance the extra density is invisible, and it costs draw time on phones. Target the table above.

**Suggested Deadfront targets,** derived from the table:

| Class | Triangles | Bones | Texture |
|---|---|---|---|
| Small creature, under 2 m | 1,200 to 1,800 | 25 to 35 | 512² |
| Medium creature, 3 to 6 m | 1,800 to 2,500 | 30 to 40 | 512² |
| Large creature or boss, 8 m and up | 2,500 to 4,000 | 30 to 45 | 512² or two 512² |
| Survivor body with outfit | 1,500 to 2,000 | 24 humanoid | 256² |
| Hand-held item or small prop | 150 to 600 | 0 | 128² |
| Building piece | 300 to 1,500 | 0 | 256², shared atlas where possible |

## How the look is made

**Matcap lighting, not PBR.** Every character and creature material uses a "LitSphere" shader. Lighting comes from a 64² sphere image, a soft grey ball lit from the upper left. Variants exist for dinosaurs, giant dinosaurs, skin, hair, wet dinosaurs, and inside versus outside the train. The colour texture carries almost no lighting of its own. This is why the models read well with so few triangles: the matcap gives a smooth, sculpted sheen everywhere.

**Creature textures are photo-sourced and overpainted.** The T. rex sheet is realistic reptile scale detail in desaturated grey-brown and olive, with baked ambient occlusion in the folds. Scars are painted in as pale cracks. Claws and teeth are dark and sharp-edged. Saturation is low because the matcap and lighting tint add warmth. Left and right sides share mirrored UV space.

**Clothing is a three-channel tint mask.** Outfit textures are painted in pure red, green and blue regions. Each channel is a dye slot, and the shader multiplies in the player's chosen colours. Patterns such as knit motifs live in channel intensity. This is the mechanism behind the dye system's red, green and blue colour channels.

**Status overlays are full texture swaps.** Each body has variants for clean, dirty, very dirty, bleeding, rash and poisoned. The raptor has a bloody variant. Deadfront's bleed and poison statuses can use the same trick: one extra 512² overlay per state, not new geometry.

**Modular characters.** A survivor is a body mesh with two submeshes, plus a separate head and hair. Hair carries up to 11 bones for long styles. Heads and hair are cheap, which makes variety cheap.

**Small effects stay tiny.** Effect textures are 32² to 128², with additive and alpha-blended particle shaders.

## Animation checklist from the raptor

The raptor's clip set is a complete small-creature list. Use it as the minimum for each Deadfront creature rig.

| Group | Clips |
|---|---|
| Locomotion | idle, stand alert, walk, run, turn, limp |
| Offence | attack, leap attack, jump |
| Behaviour | threat display, eat, look-at layer |
| Sleep | sleep begin, sleep loop, sleep end |
| Damage | small hit react, heavy blow react, groggy stagger, death |

"Limp" and "groggy" exist because Durango animals had per-body-part injuries and a stagger meter. See `research/durango-wild-lands-client-systems-inventory.md`, items 10 and 11.

## Turning this into Tripo settings

Tripo returns a dense mesh with PBR textures by default. To land on the budgets above:

1. **Cap the face count** at generation, using the targets table. Use Tripo's low-poly or smart-mesh mode where offered.
2. **Ask for a diffuse-only, evenly lit texture.** Godot's matcap or toon shading supplies the lighting. Baked highlights fight it.
3. **Generate in a neutral rig pose,** legs apart, mouth closed, tail straight, so auto-rigging and our own retarget work.
4. **Bake to 512²** for creatures and 256² for survivors after generation, whatever resolution Tripo returns.
5. **For survivors and clothing,** generate the shape with Tripo, then repaint the texture as a red, green and blue tint mask in-house. Tripo will not produce a usable tint mask by itself.

Parameter names change between Tripo versions. Check the current Tripo API reference for the exact face-limit, texture and style fields before scripting this.

## Prompt templates

Fill the bracketed fields. Keep the fixed lines unchanged so every model in a set shares one style.

### Shared style block

Append to every prompt.

```text
Stylized realism for an isometric mobile survival game. Low-poly game asset, clean readable silhouette from a high three-quarter camera. Matte surfaces, hand-painted texture over realistic detail, low saturation, baked soft ambient occlusion in folds, no specular highlights, no strong directional lighting baked in. Single mesh, no ground plane, no base, no text.
```

### Negative block

```text
photoreal render, glossy, wet look, chrome, high-frequency noise, fur cards, floating parts, extra limbs, fused legs, open mouth, saddle, armor, props, base, pedestal, background scenery
```

### Theropod

```text
[Species], [period], [length] m long. [Two or three anatomy facts that make it read as this animal, for example: deep narrow skull, forward-facing eyes, short two-fingered arms]. [Integument: scaly hide / feathered body with short quills / feathered forearms]. Colour: [base colour] with [one pattern: faint countershading / irregular dark banding along the back / pale throat]. Neutral rigging pose: standing on two legs, spine level, tail straight out behind, arms relaxed, mouth closed, feet flat and apart. Target about [N] triangles.
```

### Quadruped

```text
[Species], [period], [length] m long. [Anatomy facts, for example: low broad body, wide hips, bony osteoderms in rows, heavy tail club]. Colour: [base colour] with [one pattern]. Neutral rigging pose: four legs straight and separated, all feet flat, head level, tail straight, mouth closed. Target about [N] triangles.
```

### Survivor body

```text
Adult [sex] survivor, [occupation] clothing from the modern day, worn and torn from a disaster. Proportions slightly stylized: head a little large, hands slightly large. A-pose, arms 45 degrees down, feet shoulder width. Separate head and hair are not needed: smooth neck stump only. Clothing in flat, untextured light grey so it can be repainted as a dye mask. Target about 1,800 triangles.
```

### Hand-held tool or weapon

```text
Primitive [tool], made from [primary material] lashed to a [handle material] with [binding]. Chunky readable shape, slightly oversized for visibility at isometric distance. Single object, centred, no hand. Target about [N] triangles.
```

### Worked example: Velociraptor

```text
Velociraptor, Late Cretaceous, 2 m long including tail. Long low narrow snout, slightly upturned tip, large sickle claw raised on the second toe of each foot, long stiff tail. Feathered body with short quills, longer pennaceous feathers on the forearms forming small wings, scaly feet and snout. Colour: dusty sand brown with faint darker banding along the back and a pale underside. Neutral rigging pose: standing on two legs, spine level, tail straight out behind, arms folded at the sides, mouth closed, feet flat and apart. Target about 1,500 triangles.
```

Then append the shared style block and pass the negative block.

## Review checklist for each generated model

- Triangle count is inside the class range.
- Texture is 512² or smaller after bake, with no baked highlights.
- Silhouette reads as the species at isometric distance with the texture switched off.
- Pose is neutral, limbs separated, mouth closed.
- The rig carries the full animation checklist above.
- Status overlay textures are planned: clean, dirty, bleeding, poisoned.
