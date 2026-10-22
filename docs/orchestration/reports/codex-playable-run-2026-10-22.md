# Playable run check, 2026-10-22

Agent: Codex

## What shipped

- Ran the main project with Godot 4.7.1 and touch emulation.
- Confirmed the game window renders the island, survivor, HUD, minimap, objectives, touch actions, and camp interactables.
- The existing save opened during a Tyrannosaurus fight. The survivor died, the normal respawn flow worked, and the game is now running at camp.
- Ran `tools/smoke.sh`. It printed `SMOKE PASS`.
- Ran `tools/test.sh`. It printed `[tests] PASS`.
- Left all in-progress UI, creature, and generated-asset changes untouched.

## What failed

- No runtime gate failed.
- `tools/test.sh` still prints the expected future-save-schema rejection from its negative test, plus five leaked objects and one resource in use during shutdown. The suite passes despite those shutdown diagnostics.

## Credits spent

- Meshy: 0.
- Tripo: 0.

## What the next agent needs

- The game is running in the Godot debug window at the home camp with touch emulation enabled.
- The working tree still contains unrelated changes from other agents. Do not sweep them into this task.
