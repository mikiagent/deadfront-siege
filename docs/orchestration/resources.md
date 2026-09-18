# Third-party asset sources and licences

Every external asset in the repo, where it lives, and what its licence requires. Update this when adding a pack. CC-BY packs need a line in the credits screen.

| Pack | Author | Licence | In repo | Used for | Status |
|---|---|---|---|---|---|
| Gobkit Free Dinosaur Pack | Gobkit | CC0 | `tools/standins/gobkit/` | First stand-ins (chibi). Superseded by the transplant route | superseded |
| Animated LowPoly Dinosaurs (Dec 2018) | Quaternius | CC0 | `tools/standins/quaternius/` (Velociraptor + Trex FBX, License.txt) | **Donor rigs and clips** for the skeleton transplant (`tools/transplant_rig.py`). Triceratops rig is the planned donor for Protoceratops | in use |
| Ultimate Nature Pack (150 models) | Quaternius | CC0 | `game/assets/nature/*.glb` + `LICENSE-quaternius-nature.txt`, manifest `game/data/nature_manifest.json` | Island vegetation, rocks, harvest-node visuals (M5). 41 families across temperate, tropical, desert, tundra, swamp | in use |
| Poly Haven terrain textures (`aerial_grass_rock`, `brown_mud_leaves_01`, `aerial_beach_01`, `rocky_trail`) | Poly Haven contributors | CC0 | `game/assets/terrain/*.jpg` | Terrain tile shader textures for grass, dirt/mud, sand, rock (M5b terrain look) | in use |
| Everything Library 01 – Animals | David O'Reilly | **CC-BY 4.0** (credit + licence link + note changes) | not downloaded | 239 static, unrigged, vertex-coloured meshes: insects, arachnids, amphibians, birds, reptiles. Candidate for ambient critters later (insects for the bite/sting statuses, lizards and horseshoe crabs from the PRD bestiary). No dinosaurs, no rigs, so not for v1 | candidate |
| Crossbow prop | Meshy text-to-3D (15 credits) | Meshy terms | `game/assets/props/meshy/crossbow.glb` | weapon model + icon | in use |
| Meshy generations | this project | Meshy terms (commercial use on paid plan) | `game/assets/creatures/*/work/*_i2m_v1.glb`, `game/assets/characters/survivor/` | Dinosaur meshes and textures, the survivor | in use |

Conversion notes: Quaternius FBX materials import into Blender with Principled Alpha = 0 and export as fully transparent glTF materials. `tools/fbx_to_glb.py` forces alpha 1. Any future FBX pack goes through the same tool.
