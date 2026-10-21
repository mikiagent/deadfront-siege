# CHAR-APPEARANCE plan

Planner note for docs/orchestration/mmo/char-appearance-plan.md. Read-only: nothing changed or committed and 0 credits spent. The Tripo balance read with the free tool is 3,205. All renders were made in headless Blender under scratchpad/char-appearance/model/, and I looked at each one cited here.

## 1. Fix the premise first
- `survivor/survivor.glb` (v2, Tripo task 82d5db79) is a man. `survivor_body_front.png` shows short dark hair, stubble, a charcoal tee and shorts, bare feet and an A-pose.
- The woman is `survivor_v1` (Meshy, 24 joints, T-pose, jacket and jeans). She cannot use v2's clips or kits.
- These still describe it the other way round:
  - spec 19 ("The only survivor model is a woman", re-read at HEAD de73f92f);
  - STATUS:383;
  - the CHARCREATE prompt;
  - `survivor.json:6`.
- So the gap is a **female** v2 base. CHARCREATE should label its preview as male.

## 2. What the model allows
- **Mesh and rig:**
  - one mesh and one 2048² PBR material, with 5 byte-identical copies across the base and its 4 body regions;
  - 65 Mixamo bones;
  - no face, jaw or eye bones and no shape keys.
- **Hair** is a shell 1.4-1.6 cm over a real scalp, about 3.7k tris. Cutting it out leaves a clean bald head (`bald2_*.png`), apart from a jagged hairline at the forehead, temples and nape.
- **Stubble** is painted into the texture: the beard zone is 38k texels.
- **UVs** are Tripo's automatic unwrap, 1125 head islands scattered over the whole atlas. Every mask and decal has to be baked from the geometry, not painted in UV space.
- **Colour keying won't work:** the hair and the clothes are both near-neutral. The two model passes also disagree on hair saturation (0.045 vs 0.18-0.25), so do not build masks on a saturation threshold.
- **Helmets bring their own face:** forager is 5,025 tris and hide_and_bone is 2,958 tris with spiky hair. Equipping either one hides the chosen look.
  - An 8 mm shell cut is not enough yet. `shell_forager_3q.png` leaves shards on the jaw and cheek. `shell_hide_and_bone_3q.png` leaves spikes floating above the head.
- **On-screen size:** the head is about 15 px at 1600x900 and about 6 px at 844x390. Face detail only matters in the creation screen and the portrait.

## 3. Per slot
| Slot | Route | Start with | Credits |
|---|---|---|---|
| Outfit colour 1-3 | Geometry-baked RGB tint masks: base R shirt / G shorts; one mask per kit atlas (R chest / G legs / B sleeves-trim); skin flagged. Tint = colour × texel / 0.29 | base + 3 kits | 0 |
| Skin / eye / lip | Skin channel in the base mask. Eye and lip masks tightened from the coarse boxes; the iris is about 12 texels wide | 8-10 / 6 / 5 swatches | 0 |
| Hairstyle | A: split the baked hair into `body_hair.glb`, plus buzz, bald and short-crop pieces on the scalp. B: Tripo variants of the same man, hair-only cut | 4 free + 4 Tripo | 0; then cap 300 |
| Facial hair | Clean-shave inpaint, 4 projected decals, 2 shell beards rigid on Head | 7 | 0 |
| Features | Decals: brows ×3, scars, freckles, paint, age lines. No shape keys: they would pay off only in portraits and break hair, beard and helmet fit. Face presets come later from occupation batches | 6 + 3 brows | 0 |
| Helmets (prereq) | Shell-cut with component cleanup and a closed crown; hide `["hair"]` only | 2 | 0 |

`# ASSUMPTION:` Outfit Color 3 does nothing on the bare-foot base (there is no third garment) and drives sleeves/trim on the kits.

## 4. Packages (in order)
1. **P0 PREMISE:** fix the docs, the prompt and `survivor.json:6`.
2. **P1 MASKS:** base, eye/lip and per-kit masks; collapse the duplicate textures.
3. **P2 HAIR-SPLIT:** bald head and `body_hair.glb`; add a `hair` region to PlayerEquipment (engine side); 4 hairstyle entries in `appearance.json`.
4. **P3 HELMET-SHELL:** re-extract the two helmets so the chosen head survives under them.
5. **P4 FACE-DECALS:** facial hair and features.
6. **P5 CONCEPT SHEETS:** CA-01 to CA-03 (and CA-04 if the female base is approved). The owner approves before any spend.
7. **P6 TRIPO HAIR:** cap 300.
8. **P7 FEMALE V2:** cap 250. Only after the owner says yes.
9. **P8 OCCUPATION OUTFITS:** 50 per generation, 400 per gender, batched later.

## 5. Gates for every piece
- **kit-verify:**
  - 65 joints;
  - FAIL on bind drift over 5 mm, WARN at about 1 mm;
  - WARN over 12k tris.
- **Clips:** all 29 clips play with the piece attached and nothing pokes through the body. Report the maximum penetration for each clip on any hair below the ears.
- **Helmets:** render every helmet × hairstyle combination. No hair shows through, and the face under the brim keeps the chosen skin tone.
- **Masks:** at least 2 px of dilation, zero skin texels in the outfit channels, no seams at UV islands in a mock tint.
- **Screens:** preview, world and portrait shots at 1600x900 in Forward+ and in gl_compatibility, plus 844x390. Then a `record_equip.sh` video. The owner calling anything gray or ugly is a fail (GAUNTLET:38).

## 6. Concept brief (the owner approves before any spend)
- **CA-01 Hairstyles:**
  - the v2 head, bald, in four views;
  - the 4 free options as real renders;
  - the 4 Tripo targets drawn on the same head, all clear of the shoulders;
  - a hair-tint strip.
- **CA-02 Facial hair and features:** each option at portrait size and at the 15 px in-play size.
- **CA-03 Palette:**
  - muted swatches for skin, hair, eye, lip and outfit, using the same colour ids as the world dye system;
  - the swatches mock-tinted on the base and on travel_clothes;
  - a proposed framing for rendered portraits.
- **CA-04 Female base:** only if the owner approves. Same A-pose and base layer, locked to the v2 base_ref renders.
- **Style:** STYLE.md grounded survival realism at the ARK bar. No Durango art as input.

## 7. Credits
- Free work: P0-P5.
- Tripo, if approved: 300 for hair, 250 for the female base, 400 per gender for occupations. That is at most about 1,350 of the 3,205 balance.
- Meshy is unusable (its key was rejected). Higgsfield has 28 credits; use it for sheet art only with the owner's OK.

## 8. Not checked
- Blend-shape cost in Godot.
- Whether `split_by_bones` keeps shape keys (moot while they are skipped).
- The bald-skull shrinkwrap, a hair-only cut on a Tripo variant, and a decal prototype: the costs and times for these are estimates.
- Codex image availability today.
- The CHARCREATE prompt file: it is not at `handoff/workflows/charcreate.js` in ~/Documents/deadfront, so line 20-22 is quoted from the earlier notes.
