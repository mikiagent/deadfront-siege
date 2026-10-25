# dsc orchestration update, 2026-10-25

## Integrated

- `2e7b74bb` PROPS2D
- `18b06398` CRAFTFEEL
- `979b5983` DOMAIN-D
- `977512f1` BIOMEDRESS
- `cdeaeab1` ISLANDPICK
- `d4b7e60a` BIOMEPROPS

BIOMEPROPS changes only prop-radius data, headless structural coverage, and a lab. It does not
rewrite any biome GLB or Blender exporter source. I retained the painted-card metadata and the
indestructible rock-spire behavior while resolving the merge conflict. Its colour-space decision
needs a later rendered comparison.

## Workers

FOODFX is still running on `claude/mmo-foodfx`, session `20261025-145253-h7zp`, model
`deepseek/deepseek-v4.1-flash-1017`. The first completion was rejected because six newly added
items had no `item_rarity.json` mirror rows and `t_data` failed. The repair round adds those rows,
adds `t_data` to the job gate, and rechecks `t_save` with the cross-job lock.

All workers were told to remain headless. Godot runs use `gslot.sh`, Dummy audio, a timeout, and a
writable scratch HOME. No visible Godot or Blender process was launched. No Meshy credits were spent.

## Reliability findings

A read-only DeepSeek review launched Godot without the writable cache setup. macOS recorded two
Codex-hosted Godot aborts at 09:44. Re-running the unchanged island-choice test with the required
headless setup passed. This was a test-runner sandbox failure, not a game-code crash.

The general `run_all` and `t_bags` paths still print unexpected script errors before reporting PASS.
The same output occurs on the untouched `977512f1` baseline, so it did not come from ISLANDPICK.
The aggregate gate needs to fail on these errors, except for the documented deliberate probes in
`t_save`.

## Next

Review and merge FOODFX only after `t_data`, `t_save`, its own test and smoke are clean on the
repaired branch. Then start the intentionally blocked balance package. Run visual labs later, when
the owner permits a visible window, before approving food UI or biome colour appearance.
