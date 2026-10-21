# Task: saddles for every rideable tame - SADDLES

Context: DEADFRONT is a Godot 4.7.1 typed-GDScript dinosaur survival game (project `game/`). Tamed animals with the
"mount" role in game/data/creatures/<species>.json can be ridden. Only the T. rex has a real saddle today: a howdah
(`game/assets/creatures/tyrannosaurus/mount/saddle.glb` + `mount.json`: socket bone, `rider_offset`, `rider_in_mount`
in glTF model space), attached by creature_view.gd (`RiggedModel.attach_skinned`) and used by player.gd / player_pets.gd
when mounting; every other mount falls back to a hips-socket offset with no saddle. The owner: "make it so more of the
tames are mountable and have this" (this = the T. rex saddle).

How the T. rex one was made (reuse it): docs/orchestration/reports/art-survivor-v2-armor-mount.md section 3, the Blender
scripts in /Users/milankinzy/Documents/deadfront-dsc-work/survivor-v2/anim/work/ (saddle.py, howdah_surface.py) and
/Users/milankinzy/Documents/deadfront-dsc-work/verifiers/tools/mount_to_model_space.py. Read them first.

## Requirements

For each of these mount-role species that have a game model (game/assets/creatures/<s>/<s>.glb):
zebraceratops, megaloceros, protoceratops, gallimimus, velociraptor, utahraptor, coelophysis
1. Build a riding saddle in headless Blender (`/Applications/Blender.app/Contents/MacOS/Blender -b --factory-startup -P <script>`;
   scripts committed under tools/blender/saddles/, one shared script driven by a per-species config): a leather seat
   shaped to the animal's back, girth straps around the body, stirrups/footrests, reins to the head - same style family
   as the T. rex howdah but sized to the animal (no howdah box on small animals). Skin it to the species' own skeleton
   (seat and straps on the spine/back bones, reins on the neck/head) so it moves with every clip without floating or
   cutting through the body. Export `game/assets/creatures/<s>/mount/saddle.glb`.
2. Write `game/assets/creatures/<s>/mount/mount.json` in the same format as the T. rex one: socket bone, `rider_offset`,
   `rider_in_mount` (rider armature root in the species' glTF model space, facing the animal's forward), computed with
   mount_to_model_space.py against the game's own GLB, at the species' in-game scale (height_meters).
3. Make the game use them: extend creature_view/player mounting so any species with mount/mount.json uses the saddle
   path (today it is effectively the T. rex only) - keep the hips-socket fallback for species without one.
   If a species is far too small to carry a person (rider taller than the animal's back height x 1.6), do NOT ride it
   on top: leave it on the fallback, mark it in the report with the numbers, and do not change the data.
4. Lab: extend game/scripts/dev/equip_mount_lab.gd with `--species=<id>` (and `--all-mounts`) so it spawns that pet,
   mounts it, plays idle/walk/run, checks the rider hips stay above the back, the saddle stays on the socket bone across
   walk/run frames (drift under 3 cm), the rider does not sink into the body, and dismount restores the rig; it prints
   `[mountlab] PASS species=<id>` per species and saves side and iso shots with `--shot-dir=<dir>`.
5. Test `game/tests/t_mounts.gd`: every species with role mount and a GLB either has mount/saddle.glb + mount.json
   with all keys, or is listed as too small in game/data/mounts_skip.json with its measured numbers.

## Constraints
- Godot only through `/private/tmp/claude-501/-Users-milankinzy-Documents-deadfront-siege/1899b1df-f06b-4b94-91be-9e3f3c22081d/scratchpad/gslot.sh`
  with its own timeout (`gslot.sh perl -e 'alarm 600; exec @ARGV' /Applications/Godot_mono.app/Contents/MacOS/Godot ...`),
  max 5 Godot runs machine-wide, never --editor; `--headless --path game --import` after adding GLBs.
- Do not change creature meshes, rigs or clips; do not change the T. rex saddle; no paid generation (no Tripo/Meshy).
- Keep game/override.cfg. Never touch other folders under .claude/worktrees/, the owner's save, or ~/Documents/deadfront.
  Do not push, merge or deploy. Typed GDScript, no new dependencies.
- Report docs/orchestration/reports/dsc-saddles.md: per species (saddle tris, socket, rider height above ground, shots).
- Verify command: `bash /private/tmp/claude-501/-Users-milankinzy-Documents-deadfront-siege/72cebc8b-d241-430b-9ea6-94d65339bfef/scratchpad/dsc/verify_saddles.sh` (read it; it must exit 0).
