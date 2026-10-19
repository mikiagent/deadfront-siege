# W1-SAVE: crash-safe, sanitized and isolated saves

Branch `claude/mmo-w1-save`, cut from `claude/mmo-overhaul`. Commits:

- `c2cc29e` Crash-safe, sanitized and isolated saves (W1-SAVE): the whole package
- `19b9301` WIP save (interrupted by usage limit): only Godot `.uid` churn, no package work
- `2a41f49` Untrack Godot .uid churn committed by the interrupted WIP (files stay on disk, untracked)
- `d6d70bc` the first report
- `c6de4a5` review round 1 fixes (below), then this report update

No Meshy or Tripo credits spent.

## What shipped

- `save_game.gd`: writes go to a `.tmp` file and are renamed into place, and the previous good save is kept as `.bak`. When a save is unreadable or has a newer schema, the file is copied to `.corrupt-<unix>` and left as it is, and the loader falls back to `.bak`. If no good copy exists, every `save_now()` is refused (`blocked_reason`) until `confirm_new_game()`. Character creation opens with a `SaveWarning`. Because the refusal sits inside `save_now()`, it also stops World's 60 s autosave without any edit to world.gd. Automated runs (`--lab`, `--smoke`, `--bot`, probe or test flags, `--script`) save under `user://runs/<name>/` (`SaveGame.run_name()`). The current away island's buildings, storage and claims now persist. Offline catch-up is clamped to 7 days. A restored building row must pass `can_place`; a row that fails, or has an unknown kind, is refunded to camp cargo.
- `save_sanitizer.gd` (new): drops unknown item, equipment and pet ids. Clamps count to stack size, level to 60, durability to the item's ceiling, skills to 60 or less, SP to what the levels paid, t_stones to 0..100000 and position to the world limit, with a default spawn if position is empty.
- `save_migrations.gd`: a non-dict `player`, `home` or `unstable` is dropped before the typed steps run, and `schema_of()` rejects a schema marker that is not a number.
- `home_lab.gd`: uses `SaveGame.path` instead of the hardcoded `user://save_1.json`.
- `tools/shell_test.sh`: runs Godot with `HOME` set to a `mktemp -d` directory and removes it afterwards. It no longer references `app_userdata`.
- Fixtures in `game/tests/fixtures/`: `save_v1`, `save_v3_golden`, `save_truncated`, `save_future`, `save_forged` (v0 and v2 already existed).
- Test: `game/tests/t_save.gd`.

## Review round 1: what changed

| Finding | Fix | Test that would have caught it |
|---|---|---|
| blocker: SaveWarning covered the bottom row and was clipped | The label now goes into character creation's layout column under the subtitle (child index 2), at the subtitle's font size. The card grid shrinks to make room, and the column already sits inside character creation's margins | t_save: `the warning sits in the layout column under the subtitle`. Screenshots below |
| blocker: wrong-typed leaves aborted `load_now`, then autosave wiped the save | (1) Guard: `_apply` sets `blocked_reason = LOAD_UNFINISHED` first and clears it as its last statement. A load that dies partway leaves saving refused for the session and shows a notice. `confirm_new_game()` never deletes the file in that state. A sanitizer that aborts makes `SaveFile.read` report "it could not be checked" (quarantine plus warning path), so a half-checked save is never applied. (2) Coercion: building rows (`BUILDING_ROW`: rot, x, z, hp, sleeps_left, timers, growth, and the bools), claims rows (at least 4 numbers), vitals (numbers 0..1e6), statuses, ground snares, camp_layout rows, legacy `skills` (bool values only) | t_save `_test_hostile_types`: six payloads (rot `{}`, string hp and bools, claims with `{}`, string vitals, legacy skills `{x: y}`, junk statuses, snares and layout) must load the golden's t_stones 42 and 6 stacks, then save. `_test_aborted_load` aborts `_apply` on purpose and checks refusal, unchanged bytes after 70 s of autosave, that the file survives `confirm_new_game()`, and that the next good load lifts the block |
| major: the bot resumed from a leftover `.bak` | `_pick_path` now empties `user://runs/<name>/` for every automated run (`SaveFile.wipe_dir`) | t_save `_test_fresh_run_dir`: leftover save, `.bak` and `.tmp` present, then `_pick_path()`, then `exists()` must be false |
| major: `clear_occupancy()` freed the camp pieces' cells | Removed. Both callers run on a freshly built runtime | t_save: a restored basket on the CampFire cell is refunded (`basket_kit == 2`). After an away load, `can_place` on the CampFire cell is refused |
| major: forged skill purchases | `_skills` keeps a node only if it is in trees.json, the tree level reaches it, its prerequisite is kept, and the running cost stays within the SP the levels paid (trees walked in order). `sp_spent` is set to that cost. The legacy dict keeps known survival.json ids with bool values only, and when a skill-tree save exists, a `true` must be backed by a kept tree node (or the arabic-numbered twin that `SkillState.unlock` mirrors) | Forged fixture: survival L10 lists every node and the legacy dict forges `capture_technique_I`. Only `island_access_15` survives, with `sp_spent 5`, and no capture technique unlocks. `_test_skill_purchases` unit-checks the cost, the prerequisite and the legacy mapping |
| minor: round trip only proved idempotence | `LEGACY` table: v0, v1 and v2 must keep their building kinds, bag contents, t_stones and island after the first load | `[t_save] legacy save_v1.json buildings=["basket"] bag={ "stone": 3, "branch": 2 } t_stones=25.0 island=home_grassland` |
| minor: probes reused earlier state; `--lab=../` escaped | All automated runs start fresh (above). `run_name` passes through `validate_filename()` and replaces `.` with `_` | run_name cases `--lab=../../evil` -> `______evil` and `--lab=..` -> `__` |
| minor: god file; `blocked_reason` stuck | Atomic write, read/validate and quarantine moved to new `game/scripts/core/save_file.gd` (`SaveFile`). save_game.gd is 385 lines, down from 421, even with the guard added. A successful `_apply` clears `blocked_reason` | covered by `_test_aborted_load` ("a later complete load clears the block") |

## Acceptance checklist (all run on 2026-10-19 from this work tree, through gslot)

| Item | Result | Exact output line |
|---|---|---|
| t_save passes (rerun after review fixes) | pass | `[t_save] PASS` (exit 0). The one `SCRIPT ERROR: Invalid call. Nonexistent 'int' constructor.` in the log is the deliberate abort. It is announced by `[t_save] the next SCRIPT ERROR (Nonexistent 'int' constructor) is the deliberate abort` |
| Hostile types load completely | pass | `[t_save] hostile 'building rot {}' blocked='' t_stones=42 stacks=6`, and the same line for the other five payloads |
| v0, v1, v2 content survives migration | pass | `[t_save] legacy save_v0.json buildings=["basket"] bag={  } t_stones=20.0 island=home_grassland`, the v1 line above, `[t_save] legacy save_v2.json buildings=[] bag={  } t_stones=20.0 island=home_grassland` |
| Truncated fixture: sha unchanged, `.corrupt-*` exists, save_now false until confirm | pass | these are `_check`s inside t_save, so any failure would print `[t_save] FAIL ...`. None printed and the run ended in `[t_save] PASS` |
| Future fixture unchanged after 70 s of autosave | pass | `[t_save] future fixture after 70 s on_disk_schema=99.0` |
| Two saves: `.bak` holds the first, no `.tmp` remains | pass | a t_save check, covered by `[t_save] PASS` |
| v0, v1, v2, v3-golden load and re-save field for field | pass | `[t_save] round trip save_v0.json fields=22 diffs=0` (the same line, with `diffs=0`, for v1, v2 and v3_golden) |
| Forged fixture clamps (helm x1 L60, unknown and negative stacks dropped, t_stones 0, skills <= 60, default position, no SCRIPT ERROR) | pass | t_save checks, covered by `[t_save] PASS`. A grep for `SCRIPT ERROR` in the log returned nothing |
| Schema-99 save, boot main.tscn, idle more than 63 s | pass | headless boot for 75 s, then `on_disk_schema_after_75s 99` with the same sha256 before and after (`a58d72a7…`). Log: `[save] refused: user://save_1.json is unreadable (it was made by a newer version (schema 99)); confirm a new game first` |
| `--lab=build_lab` leaves `user://save_1.json` alone | pass | `before mtime=1792417723 sha=a74edd435959091c after mtime=1792417723 sha=a74edd435959091c`. A new `runs/build_lab/save_1.json` and `.bak` were written (mtime Oct 19 08:48) |
| Away-island basket survives save and load | pass | `[t_save] away island=temperate_25 is_home=false placed_baskets=1 stone_in_baskets=9` |
| saved_unix=0 clamps catch-up to <= 7 days | pass | `[save] offline catch-up clamped 1792417518s -> 604800s` |
| `grep -n 'app_userdata' tools/shell_test.sh` | pass | no output (grep exit 1) |
| Existing suite (rerun after review fixes) | pass | `[tests] PASS` (run_all.gd, exit 0) |
| Smoke (rerun after review fixes) | pass | `SMOKE PASS` (`tools/smoke.sh --no-import`) |

Logs are in `/private/tmp/claude-501/-Users-milankinzy-Documents-deadfront-siege/1899b1df-f06b-4b94-91be-9e3f3c22081d/scratchpad/w1/save/` (`t_save.log`, `overwrite99.log`, `build_lab.log`, `run_all.log`).

## Screenshots inspected

These are windowed runs of main.tscn with a schema-99 save and `World._boot()`, from `scratchpad/w1/save/shot/runner.gd`. I looked at both images.

- `scratchpad/w1/save/shot/save_warning_1600.png` (1600x900): the orange warning is a single line between the subtitle and the card grid. Nothing overlaps it, and the Body / Woman / Man / name / ENTER THE RIFT row is fully visible at the bottom. Rect `P: (24.0, 161.0), S: (1552.0, 38.0)`.
- `scratchpad/w1/save/shot/save_warning_1947.png` (window 844x390, phone landscape; the stretched viewport is 1947 wide): the warning wraps to two lines under "Pick a background…". The cards shrink, and the bottom row stays fully visible and is not covered.

## Assumptions

- `save_game.gd`: `MAX_OFFLINE_SECONDS = 7 days`. Offline growth is capped at a week, so a wrong device clock can fast-forward farms no further than that.
- `save_sanitizer.gd`: `MAX_T_STONES = 100000`. No shipped faucet comes close to this; the cap only stops forged balances.
- `save_sanitizer.gd`: `WORLD_LIMIT = 2000 m` from the island origin.
- `save_sanitizer.gd`: `butchering_I`/`II` exist only in survival.json and have no trees.json node (only the debug panel sets them). Next to a skill-tree save they load as false.
- `save_sanitizer.gd`: vitals are clamped to 0..1e6. This only stops non-numbers and negatives. A forged `max_health` below that still loads (see "left").
- After an aborted load, the world the player sees is half-built and saving is refused for that session. The file is never overwritten. The next launch tries it again, and the hole that caused the abort should then be closed in the sanitizer.

## Integrator hooks

None needed. The autosave stop lives inside `SaveGame.save_now()`, so world.gd is unchanged.

## Labs to register

None new. `home_lab` and `build_lab` already exist.

## Failed or left

- `game/scripts/core/save_file.gd` is a new file in `game/scripts/core/`, and that directory is not on the Owns list. The reviewer asked for the extraction. It is a new file, so it cannot conflict with another package.
- Not coerced, but covered by the load guard and the callee's own error return: pet record numeric fields (`PetRecord.from_dict` belongs to W1-TAME), `unstable.harvested` rows (world.gd) and `pioneer_crafts`/`pioneer_buildings` values. A wrong type inside a callee only aborts that callee. `_apply` carries on.
- Forged but well-typed vitals maxima (for example `max_health 900000`) are not checked against equipment. `refresh_equipment_vitals` runs before `from_dict`, which then overwrites it. Fixing this needs `Vitals` (not owned).

- I did not run `tools/shell_test.sh` end to end. It builds and serves packs, which is heavy on a shared machine. Only the edit was checked: the temp HOME and the grep above.
- The branch was cut before survivor-v2 and the asset-replacement register landed on `claude/mmo-overhaul`. The tests above ran on this branch's base and not on the current overhaul tip, so the merge needs a fresh `[tests] PASS` and `SMOKE PASS`.
- While running the probes I overwrote this worktree's isolated `user://save_1.json` (in `~/Library/Application Support/deadfront-mmo-w1-save/`, not app_userdata) and then restored it from a copy. An older `save_1.json.corrupt-1792378954` from the previous attempt is still there.
