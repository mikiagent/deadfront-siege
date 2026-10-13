# Survivor sleep clips

2026-10-13. Meshy credits: 0. No deployment or gameplay wiring.

Accepted clips in game/assets/characters/survivor/anim:
- sleep.glb: KayKit Lie_Idle, 2.667-second breathing loop.
- sleep_down.glb: KayKit Lie_Down, 3-second transition.
- sleep_up.glb: KayKit Lie_StandUp, 2.333-second transition.

CC0 source and license are in tools/standins/kaykit. Exact source:
https://kaylousberg.itch.io/kaykit-character-animations

Retargeted to the actual current-main 24-joint survivor, not a new rig. Base model
and existing clips are unchanged. Each animation carries the same 24 joint names,
skeleton rest transforms, and proxy skin. No textures needed on clip-only assets.
Root horizontal translation is fixed; vertical movement preserves ground contact
using the evaluated original skinned mesh, with a 1.5 cm ground clearance. Start/end
sleep pose matches; the resting pose is sideways with legs loosely bent.

Pixel QA: original textured survivor, floor, fixed orthographic camera, 5 samples
per clip. Accepted-only sheet: docs/art/reviews/survivor-sleep-accepted.jpg.
First candidate failed grounding; rejected and rebuilt before acceptance.
Godot 4.7.1 imports/remaps all three with missing=0; smoke test: SMOKE PASS.

Integration: load sleep as LOOP_LINEAR (current RiggedModel.LOOPING does not yet
include it). sleep_down and sleep_up are one-shots. Wire to existing sleep state;
world gameplay start/loop/wake verification remains the implementation task.

Rig-history correction: 2333308 'Rig revision 3' is already on main but modifies
nine creature rigs. No replacement survivor GLB appears in fetched branch history.
