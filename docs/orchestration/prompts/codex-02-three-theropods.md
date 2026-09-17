# Codex task C2 — Velociraptor, Deinonychus, Utahraptor, fully animated

C1 proved the image-to-3D route (see `docs/orchestration/reports/codex-C1-utahraptor-proof.md` and apply whatever it says to change). Now produce three complete theropods to the clip contract, for at most **300 Meshy credits**. Bipeds only; all three run the automated route.

## Read first
- `AGENTS.md`, `game/data/creatures/SCHEMA.md` (the contract: files, clip names, orientation)
- `docs/prd/dinosaur-roster-and-3d-pipeline.md` §4.1, §4.5, §4.6
- `game/data/creatures/velociraptor.json`, `deinonychus.json`, `utahraptor.json` (specs, clip prompts, `height_meters`)
- `tools/meshy.py`, `tools/render_glb.py`, `tools/meshy_state.json` (resume from recorded task ids; never regenerate a stage that has one)
- Your C1 report

## Per species, in this order: utahraptor (reference exists), deinonychus, velociraptor

1. **Reference image** (skip for utahraptor): same method as C1, at most 2 image attempts. Velociraptor is turkey-sized and feathered (2 m, most of it tail); Deinonychus is 3.4 m, leaner than Utahraptor. Save to `ref/<species>_side.png`.
2. **Image-to-3D** textured, meshy-t2 smart-topology, one attempt unless the silhouette fails validation (then one retry).
3. **Rig**: `python3 tools/meshy.py rig <species>` posts to the rigging endpoint with `height_meters` from the JSON. The driver currently reads the `refine` task id; change it to prefer `i2m`. Rig output includes walk and run.
4. **Library presets** for `idle`, `hit_react`, `death`: run `python3 tools/meshy.py library --category BodyMovements` and `--category Fighting`, pick ids whose names are the closest neutral match (an idle sway, a hit reaction that staggers, a death that ends on the ground). Reuse the same three ids for all three species. `animate <species> --actions a,b,c` (3 credits each).
5. **Text-to-motion** for `attack_primary`, `attack_heavy`, `knockdown`, `alert` using the prompts in the JSON `clips` block, prime mode, applied to the rig (`meshy.py motion <species> --clip <name>`). `attack_heavy` must contain a visible held beat before the strike; that beat is the telegraph the game keys off. `knockdown` must end with the animal lying on its side and hold.
6. **Fetch and lay out** per SCHEMA §1: `game/assets/creatures/<species>/<species>.glb` is the rigged, skinned, textured mesh; each clip goes to `anim/<clip>.glb`. Extend `meshy.py fetch` so it writes those names directly (rig output → `<species>.glb`, plus `anim/walk.glb` and `anim/run.glb` if the rig task returns them separately; preset actions and motions → `anim/<clip>.glb`). Nothing else may live in the species folder root except `sheet.png`; intermediates go in `work/`.
7. **Validate** with Blender: open `<species>.glb` and every `anim/*.glb`, assert identical bone name sets, print clip durations, render `sheet.png` with the four views plus one frame from each clip (a contact sheet). Check SCHEMA §5 criteria. Fix or regenerate one clip at most per species; otherwise report the defect.
8. Record everything in the JSON `pipeline` block (task ids, accepted file names, credits) and in `tools/meshy_state.json`.

## Report
`docs/orchestration/reports/codex-C2-three-theropods.md`: balance before/after, per-species table of stages, credits, and verdicts; which preset ids you chose and why; any clip that is weak (say which and how); what the game side must know (e.g. actual bone root name, whether walk/run came embedded in the rig GLB or separate). Commit only files you own.

## Hard limits
- 300 credits. Report at the cap.
- One retry per stage per species, no more. A weak-but-usable clip ships; note it.
- Do not rotate, rescale, or re-export the meshes to change orientation; the game handles the +Z to -Z flip.
- Do not touch `game/scenes` or `game/scripts`.
