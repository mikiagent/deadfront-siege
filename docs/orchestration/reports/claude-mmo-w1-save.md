# W1-SAVE: crash-safe, sanitized and isolated saves

Branch `claude/mmo-w1-save`, cut from `claude/mmo-overhaul`. Commits:

- `c2cc29e` Crash-safe, sanitized and isolated saves (W1-SAVE): the whole package
- `19b9301` WIP save (interrupted by usage limit): only Godot `.uid` churn, no package work
- `2a41f49` Untrack Godot .uid churn committed by the interrupted WIP (files stay on disk, untracked)
- the report commit (this file)

No Meshy or Tripo credits spent.

## What shipped

- `save_game.gd`: writes go to a `.tmp` file and are renamed into place, and the previous good save is kept as `.bak`. When a save is unreadable or has a newer schema, the file is copied to `.corrupt-<unix>` and left as it is, and the loader falls back to `.bak`. If no good copy exists, every `save_now()` is refused (`blocked_reason`) until `confirm_new_game()`. Character creation opens with a `SaveWarning`. Because the refusal sits inside `save_now()`, it also stops World's 60 s autosave without any edit to world.gd. Automated runs (`--lab`, `--smoke`, `--bot`, probe or test flags, `--script`) save under `user://runs/<name>/` (`SaveGame.run_name()`). The current away island's buildings, storage and claims now persist. Offline catch-up is clamped to 7 days. A restored building row must pass `can_place`; a row that fails, or has an unknown kind, is refunded to camp cargo.
- `save_sanitizer.gd` (new): drops unknown item, equipment and pet ids. Clamps count to stack size, level to 60, durability to the item's ceiling, skills to 60 or less, SP to what the levels paid, t_stones to 0..100000 and position to the world limit, with a default spawn if position is empty.
- `save_migrations.gd`: a non-dict `player`, `home` or `unstable` is dropped before the typed steps run, and `schema_of()` rejects a schema marker that is not a number.
- `home_lab.gd`: uses `SaveGame.path` instead of the hardcoded `user://save_1.json`.
- `tools/shell_test.sh`: runs Godot with `HOME` set to a `mktemp -d` directory and removes it afterwards. It no longer references `app_userdata`.
- Fixtures in `game/tests/fixtures/`: `save_v1`, `save_v3_golden`, `save_truncated`, `save_future`, `save_forged` (v0 and v2 already existed).
- Test: `game/tests/t_save.gd`.

## Acceptance checklist (all run on 2026-10-19 from this work tree, through gslot)

| Item | Result | Exact output line |
|---|---|---|
| t_save passes | pass | `[t_save] PASS` (exit 0) |
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
| Existing suite | pass | `[tests] PASS` (run_all.gd, exit 0) |
| Smoke | pass | `SMOKE PASS` (`tools/smoke.sh --no-import`) |

Logs are in `/private/tmp/claude-501/-Users-milankinzy-Documents-deadfront-siege/1899b1df-f06b-4b94-91be-9e3f3c22081d/scratchpad/w1/save/` (`t_save.log`, `overwrite99.log`, `build_lab.log`, `run_all.log`).

## Screenshots inspected

None. This package changes no visuals, and I make no claim about how the SaveWarning label looks.

## Assumptions

- `save_game.gd`: `MAX_OFFLINE_SECONDS = 7 days`. Offline growth is capped at a week, so a wrong device clock can fast-forward farms no further than that.
- `save_sanitizer.gd`: `MAX_T_STONES = 100000`. No shipped faucet comes close to this; the cap only stops forged balances.
- `save_sanitizer.gd`: `WORLD_LIMIT = 2000 m` from the island origin.

## Integrator hooks

None needed. The autosave stop lives inside `SaveGame.save_now()`, so world.gd is unchanged.

## Labs to register

None new. `home_lab` and `build_lab` already exist.

## Failed or left

- I did not run `tools/shell_test.sh` end to end. It builds and serves packs, which is heavy on a shared machine. Only the edit was checked: the temp HOME and the grep above.
- The branch was cut before survivor-v2 and the asset-replacement register landed on `claude/mmo-overhaul`. The tests above ran on this branch's base and not on the current overhaul tip, so the merge needs a fresh `[tests] PASS` and `SMOKE PASS`.
- While running the probes I overwrote this worktree's isolated `user://save_1.json` (in `~/Library/Application Support/deadfront-mmo-w1-save/`, not app_userdata) and then restored it from a copy. An older `save_1.json.corrupt-1792378954` from the previous attempt is still there.
