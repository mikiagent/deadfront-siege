# claude-kicktackle: survivor kick and tackle clips

Branch `claude/mmo-kicktackle` (from `origin/claude/mmo-overhaul`). Owner: "i don't think we have kick or tackle
animations". Before this, tackle played `attack_heavy` and kick played `attack_primary` (weapon swings). No paid
generation; no credits spent.

## What shipped

- `game/assets/characters/survivor/anim/kick.glb`: 12 frames at 24 fps (0.46 s, kick lock 0.45). Front push-kick
  with the **left** leg: knee chambers up, the sole drives out level, recoils, sets down. Torso leans back a little,
  arms come up into a guard. The right (support) leg keeps the idle's keys, so it stays planted with no slide.
  The left leg kicks because the idle's left toes sit 4.5 cm above the right foot's; standing on that foot would float.
- `tackle.glb`: 14 frames (0.54 s, tackle lock 0.55). Shoulder-first lunge: a hinge-crouch dip (22 deg knees, feet
  stay put), a 34 deg forward lean, the right shoulder turned forward ~32 deg, right forearm across the chest, left
  arm braced, head up. Recovers to the stance. No root motion (the code moves the body 1 m).
- Both are authored by `tools/make_work_clips.py` (new `push_kick_body` / `tackle_body` entries, same FK-on-idle
  method as `kick_dirt`). Both start on idle frame 0 and end with every offset back at zero (idle pose).
  Rebuild them with:
  `Blender -b --python tools/make_work_clips.py -- game/assets/characters/survivor/survivor.glb game/assets/characters/survivor/anim/idle.glb game/assets/characters/survivor/anim /dev/null --only kick tackle`
- Wiring: `PlayerAnim.on_tactic(clip, heavy)` plays the clip, or falls back to `on_attack(heavy)` when the rig lacks
  it; `Player.play_tactic(clip, heavy)`; `CombatTactics.tackle` / `kick` call `play_tactic(&"tackle", true)` /
  `play_tactic(&"kick", false)`. `kick` and `tackle` are busy one-shots and blend back to locomotion (0.12 s) like
  the punch. Both clips are listed in `data/characters/survivor.json`.
- `game/tests/t_kicktackle.gd`: clips load; `use_tackle()` / `use_kick()` play them; the tackle still lunges the
  survivor (1.00 m) and the kick still shoves the raptor (1.94 m); back in `idle` within lock + 0.3 s; through each
  clip the lowest foot bone stays within 3 cm of the idle's ground (kick +0.1 cm worst, tackle -1.0 cm).
  `-- --shots <dir>` writes the contact sheets.

## Shots (`docs/orchestration/reports/kicktackle/`)

- `godot_kick.png`, `godot_tackle.png`: in-engine, 4 frames each (10 / 37 / 63 / 90 % of the clip). These came from
  an off-screen windowed run (`--position 6000,3000 ... -- --skip-charcreate --shots`) that quit by itself.
- `blender_kick.png`, `blender_tackle.png`: front and side views, 7 frames each.

## Gates

t_kicktackle PASS, t_combat PASS, t_posefix PASS, t_tactical PASS, run_all `[tests] PASS`, `tools/smoke.sh` SMOKE PASS.
t_player has the 2 auto-swing failures that are already on canon (`HOLD in reach`, `Auto off: F swings`). Another
agent owns those, so they are left as they are.

## Notes / assumptions

- ASSUMPTION: the kick uses the left leg (see above); the tackle leads with the right shoulder.
- The clips end on the idle's pose at their own last frame (idle frame 11 / 13, not frame 0), the same as kick_dirt;
  the 0.12 s blend covers the sub-millimetre difference.
