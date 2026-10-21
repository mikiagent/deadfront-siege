# Task: re-animate the quads of deadfront-siege so their combat and ground clips read as real animals

Work in HEADLESS Blender only: /Applications/Blender.app/Contents/MacOS/Blender -b -P <your_script.py> -- args.
Never connect to or use the Blender MCP server (another agent holds it). Keep your scripts in work/.

## Why
An audit of the game (2026-10-18) measured these problems on the current clips:
- attack_primary looks the same as idle (no visible strike).
- knockdown ends legs-up (dead bug).
- feet slide relative to movement; no sleep or feed clip.
These came from a donor rig transplant and procedural clips. The player sees them in every fight.

## Inputs (read-only)
- input/<species>/<species>.glb : rigged mesh in the game's contract. NEVER change the mesh, bone names, bone
  hierarchy or rest pose: the game binds clips by bone name.
- input/<species>/anim/*.glb : the current clips (one Action each). Keep clips you are not told to fix.
- ref/SCHEMA.md : the creature runtime contract (clip names, lengths, loops, export rules).
- ref/anim_events.json : hit timing (attack_primary hit fraction, attack_heavy windup etc.). Keep it.
- ref/animation-rules.md : limb and ground rules. Follow them exactly. Key them as SMALL LOCAL ROTATIONS
  from rest; never key aim/look-at or armature-space matrices (that is what twisted earlier clips).


## Species: protoceratops, megaloceros

## Deliverables per species (milestone name = species)
out/<species>/<species>.glb (copy of the input mesh, unchanged) and out/<species>/anim/ with EVERY clip the
verifier requires (idle, walk, run, attack_primary, attack_heavy, hit_react, knockdown, death, alert), each
re-authored or kept as the rules below say, plus sleep and feed (optional clips the game can now play).
Rules per clip:
- attack_primary / attack_heavy: the strike comes from the head/jaws (bipeds: bite, then for heavy a leap and
  sickle-claw rake; quadrupeds: a head/horn thrust or tusk/antler sweep with a planted brace), with
  anticipation, contact at the anim_events hit fraction, and follow-through. The tail counterbalances
  horizontally; it must never whip vertical. The attack must look clearly different from idle.
- knockdown and death: the animal ends lying on its SIDE with the body resting on the ground (not belly-up,
  not legs in the air, not hovering on its heels). Knockdown holds its last frame.
- hit_react: a flinch away from the hit, back to stance.
- walk/run: loops (first frame == last frame), feet planted while in contact (no sliding inside the clip),
  digitigrade feet, knees bending the correct way, no bone static for more than 25% of the loop.
- sleep: lying on its side or curled, breathing loop. feed: head down, bite-and-tear loop.
After each species, render a contact sheet of every clip with
python3 ~/Documents/DeepseekCLI/verifiers/tools/render_clip.py (read its --help) into out/<species>/sheets/ and
LOOK at them; fix anything that would look wrong to a person even if the verifier passes.
Write out/REPORT.md: per species and clip, what you changed and why, and the verifier output.

## Verify
./verify.sh must exit 0 (it runs the creature verifier on every out/<species>). Never edit verify.sh or the
verifier. Do not stop at "verifier passes": the sheets must look right.
