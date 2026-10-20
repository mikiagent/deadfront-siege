# Task: route every first-player lookup through PlayerRegistry

## Why

The game (Godot 4.7.1, typed GDScript, project in `game/`) assumes one local player: 35 places call
`get_tree().get_first_node_in_group("player")`. The new static class `PlayerRegistry`
(`game/scripts/core/player_registry.gd`, already written, do not edit it) is the one place that answers
"which player?", so multiplayer can come later without touching these call sites again.

PlayerRegistry API (all static, all return `Player` or null):

- `PlayerRegistry.local()` : the survivor this client controls.
- `PlayerRegistry.nearest(pos: Vector3, max_d: float = INF)` : nearest living survivor.
- `PlayerRegistry.owner_of(c: Creature)` : the survivor a pet is bonded to (null for wild animals).
- `PlayerRegistry.credit_for(source: Object)` : the survivor if `source` is one, the owner if it is a pet, else null.

## What to do

Edit exactly these lines. Keep everything else in each file byte-for-byte the same (indentation is TABS).
Where the old line ends with `as Player`, `as Node3D` or `as PhysicsBody3D`, drop the cast unless noted:
the registry already returns `Player`, which is a `CharacterBody3D`.

| File (under game/scripts/) | Line (approx.) | Replace `<tree>.get_first_node_in_group("player") as X` with |
|---|---|---|
| core/save_game.gd | 316 | `return PlayerRegistry.local()` (the whole `Engine.get_main_loop().root.get_tree()...` expression goes) |
| core/main.gd | 23 | `var player := PlayerRegistry.local()` |
| core/game.gd | 112 | `var player := PlayerRegistry.local()` |
| core/game.gd | 196 | `var player := PlayerRegistry.local()` |
| core/world.gd | 331 | `return PlayerRegistry.local()` |
| combat/telegraph.gd | 12 | `var player := PlayerRegistry.local()` |
| combat/telegraph.gd | 40 | `var player := PlayerRegistry.nearest(attacker.global_position)` |
| world/world_weather.gd | 44 | `var p := PlayerRegistry.local()` |
| world/taming_pen.gd | 103 | `var player := PlayerRegistry.local()` |
| world/build_grid.gd | 208 | `var player := PlayerRegistry.local()` (the following `if player is Node3D:` stays) |
| world/island_terrain.gd | 424 | `var p := PlayerRegistry.local()` |
| creatures/corpse.gd | 164 | `var p := PlayerRegistry.local()` |
| creatures/brains/creature_brain.gd | 378 | `var player := PlayerRegistry.nearest(creature.global_position)` |
| creatures/brains/pet_brain.gd | 37 | `var player := PlayerRegistry.owner_of(creature)` |
| creatures/creature.gd | 256 | `var p := PlayerRegistry.owner_of(self)` |
| creatures/creature.gd | 613 | two lines: `var owner := PlayerRegistry.credit_for(_source)` then, same indent, `if owner == null:` and one deeper `owner = PlayerRegistry.nearest(global_position)` |
| creatures/creature.gd | 635 | `var p := PlayerRegistry.credit_for(_source)` (replaces the whole `_source as Player if ... else ...` expression) |
| dev/web_soak.gd | 17 | `var player := PlayerRegistry.local()` |
| dev/counter_matchup_probe.gd | 23 | `player = PlayerRegistry.local()` |
| dev/bot_rest_probe.gd | 10 | `bot.player = PlayerRegistry.local()` |
| dev/earned_training_probe.gd | 11 | `bot.player = PlayerRegistry.local()` |
| dev/raid_fight_probe.gd | 20 | `player = PlayerRegistry.local()` |
| dev/progression_probe.gd | 27 | `var player := PlayerRegistry.local()` |
| dev/siege_probe.gd | 15 | `var player := PlayerRegistry.local()` |
| dev/bot_survivor.gd | 85 | `player = PlayerRegistry.local()` |
| dev/raid_gear_probe.gd | 18 | `var player := PlayerRegistry.local()` |
| dev/camp_travel_probe.gd | 12 | `var p := PlayerRegistry.local()` |
| dev/tyrant_window_probe.gd | 18 | `player = PlayerRegistry.local()` |
| dev/cargo_capacity_probe.gd | 12 | `var p := PlayerRegistry.local()` |

`grep -rn 'get_first_node_in_group("player")' game/scripts` lists every site. After your edits it must list only
the 6 sites in `game/scripts/ui/` (world_ui.gd x3, food_inspector.gd, creature_plates.gd) and
`game/scripts/items/crafting.gd`. Those belong to other teams: leave them exactly as they are.

If a replaced variable was later used through a cast type that no longer compiles (for example a method only
`Node3D` has is fine, `Player` is a `Node3D`), fix it minimally on that line and say so in the commit body.

## Rules

- Change only the files in the table. Never touch `game/scripts/ui/`, `game/scripts/items/`,
  `game/scripts/player/`, `game/scripts/combat/hunt.gd`, `game/scripts/core/player_registry.gd`, `game/tests/`,
  scenes, data, tools, `game/override.cfg` or `game/.godot/`.
- Run Godot ONLY through the slot wrapper and with a timeout:
  `/private/tmp/claude-501/-Users-milankinzy-Documents-deadfront-siege/1899b1df-f06b-4b94-91be-9e3f3c22081d/scratchpad/gslot.sh perl -e 'alarm 240; exec @ARGV' /Applications/Godot_mono.app/Contents/MacOS/Godot --headless --path game ...`
  Never run `--editor`, never `--import`, never play audio (no afplay/say).
- `./verify_registry.sh` defines done (read-only; do not edit it). It prints `VERIFY PASS` on success.
- Commit your edits in one commit (do NOT add TASK.md or verify_registry.sh) with the message
  `Route first-player lookups through PlayerRegistry` and these trailer lines in the body:
  `Co-Authored-By: DeepSeek (dsc) <noreply@deepseek.com>`
- Do not push. Do not rewrite history.
