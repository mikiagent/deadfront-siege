# Zebraceratops art and rig preflight

Date: 2026-09-20. Status: preparation complete; final creature not built.

The user requested a Durango Wild Lands Zebraceratops, a solid quadruped rig, and animations, with particular concern about the existing Protoceratops hurt animation. They permit free assets and Meshy. A task-specific Meshy credit cap has been requested and has not been answered. No paid requests were submitted. Credits spent: 0. Last balance observed: 3350.

## Delivered

- Connected the installed Blender MCP addon to live Blender 5.2.0 LTS. Addon enabled persistently; telemetry disabled. Verified protocol 7, addon 1.7, and scene access.
- Art direction and complete side/front reference prompts in `game/assets/creatures/zebraceratops/work/art_direction.json`. The front prompt is intended for image-to-image using the accepted side reference to preserve the animal's design.
- `tools/author_quadruped_recoil.py` builds a separate 0.6-second hurt action from a donor's first idle pose. It rotates the neck/head with a fast recoil, small overshoot, and recovery. It does not reuse death frames.
- Editable donor proof and exported GLB in `game/assets/creatures/zebraceratops/work/recoil_proof/`. These are unmodified Triceratops art with a new animation, not final Zebraceratops art. Quaternius CC0 license included.
- Reproducible source and exported-GLB checks with JSON measurements. The exported animation has 19 sampled frames at 30 fps, zero foot-bone travel, zero added ground penetration, under 0.8% maximum top-height change, at most four skin influences, and normalized weights within 9e-8. Source check also measures vertices in the lowest 3.5% of the model; those remain fixed.
- Protoceratops hurt audit retained in `work/`. Its evaluated bounds move from a top height of 0.916 to 1.309 and a minimum height of -0.001 to -0.122 at the midpoint. The clip is authored from death frames in the current transplant script. Base/clip skeleton transforms match, so a mismatch between those two files was not demonstrated. Anatomical fit and individual weights still need investigation. Existing Protoceratops files were not changed.

## Reference and assumptions

The [in-game reference](https://cdn-www.bluestacks.com/bs-images/screenshot03.jpg) comes from [BlueStacks' Durango taming guide](https://www.bluestacks.com/de/blog/game-guides/durango-wild-lands/dinos-zaehmen-de.html). It shows dark hide, ivory bands and a reddish frill rim. The image is used for visual study, not shipped as a texture. The prompts specify a compact body, short brow horns, small nasal horn, matte skin, separate legs and a level neutral stance. Horn proportions are an interpretation of the reference and the user's Triceratops description.

The systems PRD explicitly includes Zebraceratops; the older roster PRD excludes fantasy species. The user's explicit request controls this art task. No creature balance, roster entries, scenes, or scripts have been added.

The new hurt timing and modest recoil are an assumption, marked in the authoring script. Donor-rig validation does not prove a future generated mesh's fit, weights, or full animation set.

## Validation and remaining work

`tools/smoke.sh` printed `SMOKE PASS` on 2026-09-20.

Pending budget choices presented to the user: 48 credits for two references and one textured mesh, 96 credits allowing one retry, or free assets only. Wait for a response before spending. The options do not authorize purchases or paid rigging.

Once the route is selected: inspect reference images, build the mesh, fit the skeleton to real anatomical landmarks, keep the skull/frill/horns rigid, check skinning throughout every clip, create the complete animation contract, render previews, validate exported assets in Godot, and deliver a final editable blend plus GLBs. No final asset, animation suite, or game integration has been claimed complete.
