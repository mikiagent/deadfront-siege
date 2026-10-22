# Current integration build run, 2026-10-22

Agent: Codex

## What shipped

- Identified `claude/mmo-overhaul` at `f99663d7` as the newest integrated playable build. The root `main` checkout is the old prototype, and the pushed clone at `d799cec9` is behind this local integration head.
- Ran `tools/smoke.sh --no-import`. It printed `SMOKE PASS` on Godot 4.7.1.
- Launched the game with `--touch` from the integration worktree. Its git-excluded `game/override.cfg` routes saves to `deadfront-mmo-main`, away from the owner's real save.
- Completed the isolated first-run flow with the Student background and Meadow island. The debug window is running at the harbour with the current painted terrain, prop cards, camera, HUD, and touch controls visible.
- Launch loaded 234 items, 23 statuses, 19 creatures, and 165 recipes. No `SCRIPT ERROR` or runtime `ERROR` appeared.
- Reverted the inaccurate old-build report from the root `main` checkout in commit `63bb79ff`.

## What failed

- The first attempt launched `main`, which the MMO handoff explicitly labels the old folder. That process is stopped.
- Current launch warnings remain for runtime navmesh baking from render meshes, MultiMesh interpolation outside the physics process, and a `ShaderMaterial` occluder that cannot use the `BaseMaterial3D` fade path. None stopped play.

## Credits spent

- Meshy: 0.
- Tripo: 0.

## What the next agent needs

- The running process is the local integration head `f99663d7`, not `main` and not the older pushed clone.
- The disposable survivor is named `Survivor`, has the Student background, and is on a Meadow home island in the isolated `deadfront-mmo-main` user directory.
- Do not merge unfinished feature branches merely because their commit timestamps are later. They are package work, not the integration build.
