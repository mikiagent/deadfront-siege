# dsc-savefix: autosave before creation, max HP drift, fatigue rising too fast

Task: `docs/orchestration/dsc/savefix-TASK.md`. Branch `mmo-savefix`, worktree `<repo>/.claude/worktrees/mmo-savefix`.
Test: `game/tests/t_savefix.gd` (`godot --headless --path game --script res://tests/t_savefix.gd`, prints
`[t_savefix] PASS`). It was written first and run against the base commit `9ee4b4a6`: **14 FAIL lines** (log kept
in `.dsc/before.log`); after the fixes it prints PASS (`.dsc/after.log`).

## Before / after numbers (t_savefix on base `9ee4b4a6` vs the fix)

| check | before (base) | after |
|---|---|---|
| autosave timer 61 s while character creation is open (a Player node is live, as in the game) | wrote the save (`last_save_unix` set, file exists) | nothing written |
| `SaveGame.save_now()` called during creation | wrote the save | refused (`[save] deferred`) |
| the island pick panel while creation is unfinished | absent (mode ``) | on screen (mode `terrain`) and nothing saved under it |
| boot with a schema-3 save with no occupation (the bug's save) | loaded the world as "Survivor", no creation | opens CharacterCreation, file kept until the new world saves |
| schema 1 / schema 0 saves (real old saves) | load | load (unchanged) |
| max HP after two Pioneer levels (+5 each) then Drink + Wash | 110 -> **100** (status sync rewrote it) | **110** |
| max HP after status expiry | 100 | 110 |
| max HP after save + reload | 100 (level bonus never saved) | 110 |
| Infected Wound: max HP, then cure | 110 -> 80 -> **80** (never came back) | 110 -> 88 -> 110 |
| HUD line explaining a status max-HP change | none (`""`) | `Infected Wound: max HP -20%` |
| status with `fatigue_per_min` 0.5, one minute of its tick | **+24.8** fatigue | +0.25 (data 0.5/min x the 0.5 accumulation) |
| 20 s walking in rain: fatigue from Wet | (with the old x100 charge: Wet alone 30/min, refreshed by rain) | 0.0 from Wet, 0.5 from walking |
| 10 min walking on flat home ground | 1.1-2.6/min -> 26.1 fatigue, stamina cap x1.00 | same walk rate, 26.1, cap x1.00 |

Walk rate did not change (the walk itself was never the problem: `PlayerSim._walk` charges 0.05/s walking,
0.09 jog, 0.2 sprint, halved by `FATIGUE_ACCUMULATION_MULT`). Owner correction (2026-10-21): the playtest's
67/103, 69/106, 65/100 are exactly 0.65 x max = `Vitals.stamina_cap_mult()` at fatigue 50-74 %, so stamina's
rapid regen (16/s calm, spec 01) was left alone and the fatigue source was fixed instead.

## What changed

### 1. No save before creation and the first island pick (defect 1)
- `game/scripts/core/world.gd`: `creation_pending` flag (set in `start_new`, cleared by `finish_creation`). The
  60 s autosave skips while it is set. Boot's decision moved into `ensure_survivor(host)`: a save that predates a
  survivor (`SaveGame.has_precreation_save()`) opens character creation instead of loading it; a real save loads
  and, for schema >= 3, lifts the flag (a reload after the bug could otherwise never save again).
- `game/scripts/core/save_game.gd`: `save_now()` refuses while `World.creation_pending`;
  `is_precreation(data, schema)` = **schema 3 only** with no `player_name` or no `occupation` (v0-v2 never stored
  those fields and are real saves); `has_precreation_save()` reads the **main file only**, never `.bak`;
  `disk_schema()`.
- `SaveGame._apply` (a survivor really loaded) and `confirm_new_game()` (the player accepted a new world after an
  unreadable save) both clear `creation_pending`, so a failed load cannot leave autosaving off for the session.
- `game/scripts/ui/world_ui.gd`: `_choose_terrain` calls `World.finish_creation()` before its first save;
  `_process` puts the island pick back up whenever creation is still pending and nothing else is open, so a new
  survivor cannot reach the world (and a save) without picking.
- Old saves: v0/v1/v2 and the v3 goldens all still load (`run_all`, `t_save`, `t_water` pass).

### 2. Max HP (defect 2)
- `game/scripts/combat/vitals.gd`: `level_health` / `level_energy` (Pioneer-level part, **saved**), `grant_level_bonus()`;
  `from_dict` derives them for old saves (`max_health - 100`), so a levelled old save keeps its max.
- `game/scripts/combat/status_effects.gd`: `_sync_vitals` now writes `(100 + level_health) x status product` instead
  of a flat `100 x product` — the line that took the +5 back. `max_health_note()` gives the HUD a line for a status
  that changes max HP. `clear_all()` (used by `Player.respawn`) drops every status including its max-HP penalty.
- `game/scripts/ui/hunt_hud.gd`: `_on_level_up` goes through `grant_level_bonus`; the status area draws the
  max-HP line (`status_maxhp`) when one is explained.
- Drinking and washing change no max HP (they only add Quenched/Clean, neither has `max_health_mult`).
  The only status that does is **Infected Wound (x0.8)**, and it now says so. Gear HP is the derived
  `equipment_health_bonus` (never healed, unchanged); food adds no max HP.
- HUD words follow spec 01's fatigue scale: `RESTED` (<25), `WORN` (25-49), `TIRED` (50-74), `EXHAUSTED` (75+).
  The old labels called 25 % "TIRED", which is what the playtest reported.

### 3. Fatigue rising too fast (defect 3, after the owner's correction)
- `game/scripts/combat/status_effects.gd` `_dot`: `fatigue_per_min` was charged as
  `per_min * (0.5/60) * 100` (x100) per 0.5 s tick. Removed the x100.
- `game/data/statuses.json`: Wet `fatigue_per_min` 0.3 -> 0.0 (PRD :284: Wet modifies climate fatigue and adds
  no fatigue of its own; rain refreshes Wet forever), and Wet gets the documented heat cut
  (`heat_fatigue_mult` 0.8). The cold +30 % / humidity +30 % halves are not modelled (noted in the data).
- Energy/stamina code is untouched: calm regen 16/s, combat 2.5/s, sprint 9/s, jog 3/s, rolls 12.

## Verified
- `t_savefix` PASS (before-run and after-run logs in `.dsc/`).
- `t_water` PASS, `run_all` PASS, `tools/smoke.sh --no-import` SMOKE PASS (verify command
  `.../dsc/verify_savefix.sh` exits 0).
- `t_water` change: the pinned saved-vitals key list now includes `level_health` / `level_energy`.
- `t_save`: two checks failed until `confirm_new_game()` also lifted the creation flag (the "saves refused" path
  never finishes character creation). After that `t_save` PASS.

## Running the verify
`verify_savefix.sh` runs `tools/smoke.sh --no-import`, and Godot writes its user dir under
`~/Library/Application Support/deadfront-mmo-savefix`; inside this sandbox that is not writable and the smoke run
exits 134 (`Could not create directory`). `gslot.sh` handles this for the test runs by pointing HOME at scratch. The
verify was therefore run as `HOME=/tmp/sfhome bash .../verify_savefix.sh` -> `VERIFY PASS: [t_savefix] PASS`. Nothing
in the repo was changed to work around it.

## Assumptions / open items
- `# ASSUMPTION:` a schema-3 save with no name or no occupation is pre-creation (that is exactly what the bug
  wrote); v0-v2 saves are never treated as pre-creation.
- The pick panel re-opening only applies to a world made this session (`creation_pending`); a loaded save whose
  terrain is empty is not re-asked (out of scope).
- Wet's cold/humidity multipliers from PRD :284 are not modelled yet (needs a cold-fatigue modifier path).
- Not fixed (not in this task): `SaveMigrations.read` runs a full sanitize on every boot just to answer
  "is this a pre-creation save".
