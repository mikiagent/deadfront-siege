# claude-mmo-stego-art: four-spike thagomizer and sheet palette for Stegosaurus v2 (STEGO-ART)

Two faults in the v2 asset that STEGO put in game: the thagomizer fanned **eight** spikes in a starburst (four a
side: up, up-out, sideways, down), and the hide read grey-blue. Fixed in headless Blender, 0 Meshy/Tripo credits.

Branch `claude/mmo-stego-art` from `claude/mmo-stego` (8e7a1d17). The STEGO hooks patch
(`docs/orchestration/reports/claude-mmo-stego-hooks.patch`) is applied **uncommitted** in the work tree, as on
STEGO, and every game gate below ran with it. Merge order: STEGO + its hooks patch, then this branch.

## What shipped

- `game/assets/creatures/stegosaurus/stegosaurus.glb`: four spikes, regraded albedo. Rebuilt from the committed
  v2 GLB (662dc0d2) by `tools/blender/stegosaurus_art/build.sh`. The build is deterministic: repeated builds
  gave identical bytes. The committed GLB (md5 364defea...) is byte-for-byte the one I checked in game
  (`iter/i1`).
- `stegosaurus_tex_graded_albedo.jpg` (+ `.import` md5): Godot re-extracted it from the GLB on import. Its bytes
  equal the embedded image. The image name stays the same, so the uid and file path do not change.
- `sheet.png`: redone for the fixed model (SCHEMA: four views plus a clip contact sheet; 9 clips x 6 frames).
- `stegosaurus.json`: pipeline block only (`recolour` extended, `thagomizer` added). Gameplay fields untouched.
- `docs/orchestration/mmo/asset-replacement.md`: stegosaurus row says STEGO-ART, still REVIEW.
- `tools/blender/stegosaurus_art/`:
  - `glb_io.py`: GLB read/write.
  - `fix_thagomizer.py`: spike cut and caps.
  - `recolour.py`: albedo grade.
  - `verify.py`: invariants check.
  - `render_tail.py`: review renders.
  - `sheet.py`: sheet.png.
  - `build.sh`: runs all of the above from the v2 commit.
- No `v2a/` copy: the register does not ask for one, and git history has v2 (662dc0d2).

### How (and why at glTF level)

The edit works on the glTF arrays, not through Blender's importer and exporter. A Blender round trip
re-derives the bone rest frames, and the 9 clip GLBs carry absolute local rotations keyed to the v2 frames.
Blender is the runtime (numpy, `mathutils`, image codecs, renders), so the work is headless Blender throughout.

**Spikes** (`fix_thagomizer.py`):
1. Finding the shafts. Faces wholly 0.4 m beyond the tail axis (the tail_05 joint's axis) fall into exactly 8
   shells, one per spike.
2. Choosing the four. The script keeps the 4 with the most upward axis: the two pairs at +38 and +30 degrees
   elevation, rooted 0.3 m apart along the tail. It cuts the sideways pair (-1 degree) and the down pair
   (-18 degrees). It asserts 8 shells found, 2 kept a side, and a clean up/down split.
3. What counts as a cut spike's surface. A vertex goes with its spike when:
   - it lies outside a tail-core model (a capsule of 0.21 m that tapers to 0.12 m and lifts 0.10 m toward the
     tip, because the knob's underside rises; measured from the mesh), and
   - it is nearer, along the surface, to that spike's shell than to any other (multi-source Dijkstra).
   That takes the bases and the webs between fused spikes along with each spike. A kept spike's own shaft
   (within 0.10 m of its axis) is never cut.
4. Growing the cut. The cut then grows 2 rings over knob that stands proud of the core, never so that the two
   holes merge, to take thin flaps of old spike base.
5. Closing the holes. Each of the 2 holes (one a side) is closed by 4 rings of new vertices and a centre. They
   are relaxed into a smooth membrane, and any part that cuts into the knob is pushed back out to the core
   surface.
   - Cap vertices copy joints and weights from the nearest hole-edge vertex. The cut stays on tail_04..07
     (asserted), and the thagomizer is tail_05-rigid.
   - The hole-edge ring keeps the skin's own normals, so there is no shading seam.
   - Cap UVs are laid on a plain tail-skin island at that island's texel density.

**Palette** (`recolour.py`):
1. Regions come from the rig, rasterised into UV space and grown into the island padding:
   - plates: vertices bound rigidly to one hips/spine/neck/tail_01..04 bone (the v2 rig made plates rigid; skin is
     blended);
   - spikes: tail_05-rigid vertices beyond the tail;
   - hide: everything else.
2. Each region gets a hue move, saturation scaled to a target median, and a value gain. The hues are the concept
   sheet's (`assets/concept-art/creatures/stegosaurus/concept-sheet-v01.png`, sampled: hide 38-41 degrees at sat
   0.22-0.27 and value 0.45-0.66; plates 18-22 degrees at sat 0.33-0.46). The hide is nudged toward yellow-olive
   and made more saturated and lighter than the sheet's medians, for this reason:
   - The first grade used the sheet's own numbers (hide 44 degrees, sat 0.26, value unchanged). It looked right in
     a neutral Blender render. In the game it barely moved: the stego_lab flank stayed blue-grey (mean hue 202
     degrees, sat 0.41, against v2's 207 degrees, 0.45).
   - The visible flank is lit mostly by the sky ambient.
   - I tried three grades in game (`iter/i1..i3`) and kept the one that reads olive green-brown with rust plates.

   | region | share of texels | before (hue, sat median, value median) | after |
   |---|---|---|---|
   | hide | 84.2 % | 31.2 deg, 0.18, 0.41 | 46.0 deg, 0.42, 0.56 |
   | plates | 12.2 % | 26.3 deg, 0.30, 0.58 (salmon) | 17.0 deg (rust), 0.60, 0.58 |
   | spikes | 3.6 % | 30.5 deg, 0.21, 0.49 | 38.0 deg (ivory), 0.13, 0.58 |

   In the game (stego_lab, home_grassland idle, mean over the flank) the hide went from hue 207 degrees, sat
   0.45 (blue) to 185 degrees, sat 0.29 under Forward+ and 200 -> 172 degrees under gl_compatibility. By eye it
   reads olive green with rust plates; the shaded side stays cool because the sky lights it. In neutral light
   (Blender) the same texture reads khaki-mustard, warmer and more saturated than the sheet. Under the game's
   light it reads closer to the sheet.
3. Pale hide (belly, throat, inner legs; value over 0.75) eases to a cream at saturation 0.13 instead of turning
   bright olive. The darkest plate texels lose some saturation toward the sheet's charcoal rims.
4. The normal map and the ORM map are byte-identical, so roughness is unchanged.

## Checks, with numbers

`verify.py` (v2 vs fixed GLB), ALL CHECKS PASSED:
- nodes (34 joints, names, rest TRS, hierarchy), skin and inverse bind matrices byte-identical;
- material, texture and image lists identical; normal and ORM maps byte-identical; base colour regraded;
- 17,334 kept vertices with position, UV, normal, joints and weights byte-identical, 0 changed, 232 new cap vertices;
- triangles 29,928 -> 29,396: 28,982 unchanged from v2, 414 cap triangles (each uses a new vertex), 946 v2
  triangles removed;
- mesh closed (every welded edge shared by exactly two triangles): no holes; one connected piece: no floating fragments;
- 4 spike shafts beyond 0.6 m (2 L, 2 R), tips (-0.84, 4.36, 7.73), (+0.85, 4.36, 7.74), (-0.56, 4.56, 7.27), (+0.58, 4.55, 7.28): all up and back;
- bounds y 0 .. 6.400 m, x +-1.209 m (unchanged; the cut spikes were inside them); z max 7.747 m (was 7.768 m).

`fix_thagomizer.py` self-checks: cap vertex normals facing out of the core 94.0 %. The threshold is 90 %,
because where a cap runs onto a kept spike's flank the core's gradient is only roughly its normal.

The 9 clips (`anim/*.glb`) are untouched, so the clip files are byte-identical. In Godot every clip binds:
`[creature] clip <name> tracks=23-28 remapped=all missing=0`.

## Gates

The final asset is commit c0b9a2fa, with the STEGO hooks patch applied uncommitted. Logs are under
`.../scratchpad/stegoart/gates2/` and `lab2/`; the import log is `gates/import3.log`.

| Gate | Result |
|---|---|
| `creature-verify.mjs <stegosaurus dir> stegosaurus --height 6.4` (deadfront-dsc-work/verifiers, as v2 used it) | ALL HARD CHECKS PASSED. 3 warnings are the optional feed/sleep/tail_swipe clips, as for v2. 34 joints, 7 tail bones, jaw, height 6.40, faces -Z, 9 clips |
| `--import` after replacing the GLB (and again after sheet.png) | exit 0, 0 ERROR, 0 "couldn't resolve track". The GLB, the extracted albedo and sheet.png reimported |
| `t_stego` | `[t_stego] PASS`, 6 of 6 sections: 29,396 triangles, rest span 0.00-6.40 m, head z -3.12 and tail tip z 7.49 (-Z). All 9 clips bind (0 unresolved). Knockdown lowest skin 0.07 m, death skin 0.03-2.98 m. Stride check passes. Skin in motion: worst edge growth 0.200 m (death 50 %), the same as v2, so the caps add no stretch |
| every `game/tests/t_*.gd` (23 files) | all exit 0 and print PASS. t_save prints its 5 deliberate SCRIPT ERRORs, each announced by the test. 0 SCRIPT ERROR and 0 "couldn't resolve track" in every other test |
| `run_all.gd` | exit 0, `[tests] PASS`, 0 SCRIPT ERROR |
| `tools/smoke.sh --no-import` | `[smoke] ok player_pos=(0.0, 1.0, 0.0) phase=day`, `SMOKE PASS` |
| stego_lab windowed, home_grassland (4,16) and temperate_45 (-160,20), each in Forward+ 1600x900, gl_compatibility 1600x900 and gl_compatibility 844x390 | 6 of 6 `[stegolab] PASS`, 0 SCRIPT ERROR, 0 unresolved, 7 shots each. Camp-spot toes worst 0.00 / 0.07 m. Slopes 21.2 and 19.3 degrees, worst toe 0.11 / 0.06 m. Same numbers as STEGO |
| four-spike render (headless Blender, close rear-3/4) | `build3/steg_tail_rear34.png`: exactly four spikes. `verify.py` counts 4 shafts (2 a side, all up and back) |
| `verify.py` / `build.sh` | ALL CHECKS PASSED (above). Two builds wrote byte-identical GLBs, and the committed GLB is that build (md5 364defea...) |

An earlier full run on bfe088ee (the first, weaker grade) also passed every gate above (`gates/`, `lab/`). The
only change since then is the albedo's colours.

## Shots (all opened and looked at)

Under `/private/tmp/claude-501/-Users-milankinzy-Documents-deadfront-siege/72cebc8b-d241-430b-9ea6-94d65339bfef/scratchpad/stegoart/`:

- `build3/steg_tail_rear34.png`: **the four-spike gate render** (headless Blender, Eevee, close rear-3/4 of the
  tail). Also `steg_tail_side.png`, `steg_tail_rear.png`, `steg_tail_low.png`, `steg_side.png`, `steg_rear34.png`.
- `before/v2_*.png`: the same six views of the v2 GLB. `before_after.png`: v2 vs fixed, tail rear-3/4 and side.
- `tailmotion.png`: the tail close-up through attack_primary, attack_heavy, death, knockdown and walk (5 frames
  each) on an earlier build of the same geometry (the cut is unchanged since; only the grade moved).
- `game/assets/creatures/stegosaurus/sheet.png` (committed): 4 views plus 9 clips x 6 frames.
- `lab2/{fwd,glc,phone}_{home_grassland,temperate_45}_{idle,walk,attack,hit,dead,slope,iso}.png`: the final
  stego_lab runs, 42 PNGs. Contact sheets: `lab2/sheet_<config>_<island>.png`. Configs:
  - `fwd`: 1600x900, Forward+;
  - `glc`: 1600x900, gl_compatibility;
  - `phone`: 844x390, gl_compatibility.
- `ingame_v2_vs_final.png`: home_grassland idle crop, STEGO's v2 (blue-grey, eight spikes) next to this branch.
  `iter/i1..i3_*`: the three in-game grade tries. `lab/` is the first full run, with the first (too weak) grade.
- `crop_attack.png`: the in-game attack frame enlarged (tail raised, four spikes).

What I saw:

- **Four spikes everywhere.** Gate render, sheet, all 9 clips in Blender, and every stego_lab shot in all three
  configs on both islands. Two pairs point up and back: the upper pair at about 38 degrees, the outer pair at
  about 30 degrees, splayed. In the attack frame the raised tail shows exactly four. They stay rigid through the
  attacks and the death roll. No stretching, and nothing left of the cut spikes at game distance.
- **The tail end.** The tail ends in the knob. The two caps are smooth skin. From below and close (tail_low,
  death frames) a few thin flaps of old spike base stay at the knob's underside (see risks).
- **Colour in game.**
  - Body: olive green with darker mottling, no longer blue-grey (`ingame_v2_vs_final.png`).
  - Plates: rust to maroon, with yellow-olive bases.
  - Belly: cream, clearest in the dead pose.
  - Spikes: ivory in sun, dark in shade.
  - The shaded flank is cooler (green-teal) on temperate_45 than on home_grassland. It is the same texture, so
    the difference is the islands' light.
  - gl_compatibility matches Forward+ apart from shadow softness. At 844x390 the silhouette and the four spikes
    still read, and the iso phone shot shows the plates and spikes.
- **Neutral light (Blender).** Khaki-mustard hide, red-orange plates with yellow bases, ivory spikes, cream belly.
  This is more saturated than the sheet, on purpose (see How).

## Not done, and risks

- **Concept sheet status.** `assets/concept-art/INDEX.md` lists `concept-sheet-v01.png` as `DRAFT` ("Seen by
  Milan; approval not received"). The task calls it approved. I matched it as asked and say so here. The
  "exactly four spikes" approval is the journal combat art's (INDEX, combat knockback row), which this now meets.
- **Close-up, low-angle leftovers.** Under the knob there are still two or three thin flaps, about 3-5 cm, where
  the cut spikes were fused into the knob's underside. They show only in close renders from below (tail_low,
  the death frames). They never show at game camera distance or in the gate's rear-3/4.
- **Cap texture.** The caps use a flat projection of plain tail skin. Close up, the two caps read as smooth,
  slightly lumpy skin patches beside the kept spike bases. They are not seams or holes.
- **The plates are graded, not repainted.** The sheet's plates darken to charcoal at the rim. The v2 plates
  have pale rims and pale bases, so they read rust with lighter rims and yellow-olive bases. A rim-darkening
  repaint is a texture job beyond hue/saturation/value.
- The dark-grey speckled skin on top of the tail stays greyish. Its source saturation is near zero, so a
  saturation scale cannot make it olive.
- `game/assets/creatures/stegosaurus/work/rig_manifest.json` is still v1's (noted by STEGO; not touched).
- `real_length_m` stays 18.0 (STEGO's note; a balance call for the owner).

## Assumptions

- The four spikes to keep are the most upward pair of pairs (two pairs angled up and back, as the sheet's side
  and rear-3/4 views and the journal art show). The sideways and downward pairs go.
- The tail-core model (capsule 0.21 -> 0.12 m, lifted 0.10 m at the tip) stands for "the knob without spikes".
- Region hues are read off the concept sheet. Saturation and value are set by eye in the game's light (three
  in-game tries), not by the sheet's neutral-light medians. The game is where the owner sees it.

Credits spent: 0.
