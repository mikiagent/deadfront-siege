# W1-SAVE: crash-safe, sanitized and isolated saves

Branch `claude/mmo-w1-save`, cut from `claude/mmo-overhaul`. Commits:

- `c2cc29e` Crash-safe, sanitized and isolated saves (W1-SAVE): the whole package
- `19b9301` WIP save (interrupted by usage limit): only Godot `.uid` churn, no package work
- `2a41f49` Untrack Godot .uid churn committed by the interrupted WIP (files stay on disk, untracked)
- `d6d70bc` the first report
- `c6de4a5` review round 1 fixes (below), `cd4384d` its report update
- `c0763e3` review round 2 fixes (below), `3c166dd` its report update
- `61dce59` review round 3 fixes (below), `20cfdb2` lazy sanitizer load in `read()` and `save_restore.gd.uid`, then this report update

No Meshy or Tripo credits spent.

## What shipped

- `save_game.gd`: writes go to a `.tmp` file and are renamed into place, and the previous good save is kept as `.bak`. When a save is unreadable or has a newer schema, the file is copied to `.corrupt-<unix>` and left as it is, and the loader falls back to `.bak`. Building rows that cannot be rebuilt while camp cargo is full are kept in `pending_refunds` (saved, retried on every load) instead of losing items. If no good copy exists, every `save_now()` is refused (`blocked_reason`) until `confirm_new_game()`. Character creation opens with a `SaveWarning`. Because the refusal sits inside `save_now()`, it also stops World's 60 s autosave without any edit to world.gd. Automated runs (`--lab`, `--smoke`, `--bot`, probe or test flags, `--script`) save under `user://runs/<name>/` (`SaveGame.run_name()`). The current away island's buildings, storage and claims now persist. Offline catch-up is clamped to 7 days. A restored building row must pass `can_place`; a row that fails, or has an unknown kind, is refunded to camp cargo.
- `save_restore.gd` (new, `SaveRestore`, round 3): rebuilds saved building rows, refunds the ones the grid rejects (kit, contents, a pen's captured animal, a planted field's seed) and holds `pending_refunds`. Moved out of save_game.gd (now 316 lines, was 415). `SaveGame._restore_buildings` and `_spawn_building` remain as one-line delegates because world.gd, run_all.gd, kitchen_lab.gd and siege_probe.gd call them.
- `save_sanitizer.gd` (new): drops unknown item, equipment and pet ids. Clamps count to stack size, level to 60, durability to the item's ceiling, skills to 60 or less, SP to what the levels paid, t_stones to 0..100000 and position to the world limit, with a default spawn if position is empty.
- `save_migrations.gd`: also holds the file layer (atomic write, read + migrate + sanitize, quarantine, run-dir wipe; it was `save_file.gd` in round 1, now deleted). A non-dict `player`, `home` or `unstable` is dropped before the typed steps run, and `schema_of()` rejects a schema marker that is not a number.
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

## Review round 2: what changed

| Finding | Fix | Test that would have caught it |
|---|---|---|
| blocker: `save_file.gd` outside Owns, new global class | Folded into `save_migrations.gd` (owned); `save_file.gd` deleted, no `SaveFile` class left | `grep -rn SaveFile game/` returns nothing; t_save and run_all pass with the file gone |
| major: dead "sanitizer aborted" guard | `clean()` sets `SaveSanitizer.CHECKED` as its last statement; `read()` erases any forged copy first and treats a missing sentinel as unreadable (quarantine, block) | `_test_sanitizer_abort` forces a real script error in `clean()` (`abort_for_test`), runs the full `load_now`, and checks `read()` errors, saving is refused, bytes unchanged after 70 s of autosave, and a forged sentinel never reaches the loader. Line: `[t_save] sanitizer abort read=it could not be checked` |
| major: pet with `hp {}` left a session that never saves | `save_game.gd` appends a pet only when `PetRecord.from_dict` returns non-null and `save_now` skips nulls; sanitizer `PET_ROW` coerces every numeric field `from_dict`/`CreatureGenetics.from_dict` casts, and drops non-numeric genetics stats | hostile case `pet numbers and genetics junk` (hp, attack, ... `{}`, genetics strings, tamed_role 5, bag "no") must load 1 pet and save with no new SCRIPT ERROR. t_save now counts SCRIPT ERRORs with a `Logger` and fails on any not announced as deliberate |
| major: uncommitted work tree | Finished and committed in `c0763e3`; t_save, run_all and smoke rerun on that commit (below) | n/a |
| minor: forged values still load | Claims: width and depth must be 1..14 tiles (`claim_at`'s plot) and the origin within `WORLD_LIMIT`. Pet stats, `max_health` and t_stones up to 100000 are still open (see "left") | forged fixture now carries a 2000x2000 home claim: `a forged 2000x2000 home claim is dropped, a 14x14 one kept` |
| minor: `--shot=` used the player's slot | `--shot=` without `--lab` is run `shot` (`user://runs/shot/`) | run_name cases `--shot=/tmp/a.png` -> `shot`, `--lab=build_lab --shot=...` -> `build_lab` |
| minor: concurrent runs of one name wipe each other | Not changed: `shortcut:` comment in `_pick_path` (add the pid if parallel runs of one lab need their own saves) | n/a |
| minor: misleading refusal after an aborted load | `save_now` prints `refused: the load of <path> did not finish this session, so the file is left untouched` for `LOAD_UNFINISHED`. An in-game way out (offer the .bak or a new game) is not built: see "left" | seen in the t_save log |
| minor: `_warn_new_world` depends on CharacterCreation's child order | Kept (the reviewer's 844x390 shot shows it correct); asked for a public method under "Integrator hooks" | t_save's existing `the warning sits in the layout column under the subtitle` check fails if the order changes |
| minor: `tools/shell_test.sh` never run end to end | Not run (builds and serves packs; heavy on the shared machine, and it launches Godot without gslot). Listed as an integrator check | n/a |

## Review round 3: what changed

| Finding | Fix | Test that would have caught it |
|---|---|---|
| blocker: a refunded pen lost its captured animal; a refunded field lost its crop | `SaveRestore._items_of` adds the sanitized `occupant` stack and, for a planted crop that has not failed, its seed from farming.json. The all-or-nothing scratch check covers both, so with full cargo the row (occupant included) stays in `pending_refunds` | `_test_pen_refunds`: a running pen with a velociraptor `captured_animal` and a `field_small` with corn on unclaimed cells must put the animal (species kept), both kits and a corn seed in cargo; with full cargo the animal must be in `pending_refunds` on disk, and be refunded once cargo has room; a pen on a free claimed cell keeps its animal |
| major: pen occupants skipped the sanitizer | `_buildings` runs `occupant` through `_stack` (null when dropped). `_stack` now checks every stack's attributes: a `species` must be a known creature or the stack is dropped (as `_pets` does); `grade_seed`, `barbed_hits`, `toxin_hits`, `hardness` (the attributes read with `int()`) and `genetics` are shaped (`ATTR_ROW`), and genetics keep numeric stats only (shared `_genetics`). A pen left without its animal gets `running = false`, since a running pen reads its occupant when the timer ends | four hostile cases: occupant `count {}`, unknown species, unknown id, attribute junk (`grade_seed {}`, `variant []`, genetics strings). Each must load completely, rebuild the pen, and either leave it idle or (attribute junk) finish taming through `TamingPen._process` with no SCRIPT ERROR. The hostile loop now counts SCRIPT ERRORs from before `load_now`, not after it: that gap is why the round-2 run did not flag this per case |
| minor: `wipe_dir` printed an engine ERROR on a run's first launch | Returns early when the folder does not exist | `_test_fresh_run_dir`: `wipe_dir("user://runs/t_save_never_made")` must add no engine ERROR (the `Logger` now counts those too) |
| minor: a refused save skipped the travel cache refresh | `save_now` snapshots the live buildings and refreshes `World._home_buildings_cache` before any refusal (only when a runtime exists); the payload's home buildings read that cache | `_test_refused_save_keeps_camp`: golden camp plus a new basket with 11 stone, `blocked_reason = LOAD_UNFINISHED`, `save_now()` (refused), then what `World.travel` does next (new runtime, `_restore_buildings(cache)`): both baskets and 16 stone must come back |
| minor: god file; production test hook | Restore, refund and `pending_refunds` moved to `save_restore.gd`. `abort_for_test` is kept: a value that makes `clean()` abort would be a sanitizer bug to fix, so no injected value can stand in for it. The hook calls a method on null because that is a real script error, the case the sentinel exists for | `_test_sanitizer_abort` unchanged and passing |
| minor: overhaul tip's `PetRecord.from_dict` casts `tamed_at`, `wild_level` | Added to `PET_ROW` now, with the tip's gate `open` flag in `BUILDING_ROW`, so the merge needs no sanitizer edit. Still rerun t_save, run_all and smoke on the merged tip | n/a on this branch (its PetRecord does not read them) |
| (found while rerunning) run_all.gd printed `SCRIPT ERROR: Compile Error: Identifier not found: Data` at its first compile | Since round 2, `save_migrations.gd` named `SaveSanitizer`, which reads autoloads, and run_all.gd compiles `SaveMigrations` before autoloads exist. `read()` now `load()`s the sanitizer, the house pattern for scripts that touch autoloads | run_all log head: the compile error is gone (only run_all's deliberate `Save schema 4 is newer` remains) |

Negative control: the new t_save, run against the round-2 `save_game.gd`, `save_sanitizer.gd` and `save_migrations.gd` (log `r3/t_save_oldcode.log`), prints 8 FAILs, among them `FAIL a refunded pen and field give back the animal, both kits and the seed (got [0, "", 1, 1, 0])`, `FAIL with room again the kept animal and seed are refunded (animal=0 seed=0)`, `FAIL a refused save still refreshes the home camp cache: both baskets and 16 stone come back (got [1, 5])`, `FAIL a new run name's first launch logs no engine ERROR (got 1)`, `FAIL hostile 'pen occupant attribute junk': ... script_errors=1` and `FAIL no unexpected SCRIPT ERROR (got 5, 3 deliberate)`. The fixed files were restored right after that run (`git diff` checked).

## Acceptance checklist (all run on 2026-10-19 from this work tree, through gslot)

| Item | Result | Exact output line |
|---|---|---|
| t_save passes (rerun on `20cfdb2`) | pass | `[t_save] PASS` (exit 0). The three SCRIPT ERRORs in the log are the deliberate aborts, each announced (`[t_save] the next SCRIPT ERROR (...) is the deliberate ...`); the run itself checks that no other SCRIPT ERROR occurred |
| Hostile types load completely and save | pass | `[t_save] hostile 'pet numbers and genetics junk' blocked='' t_stones=42 stacks=6 pets=1 saved=true`, and the same line for the other twelve payloads |
| Junk pen occupants: pen survives, no SCRIPT ERROR | pass | `[t_save] hostile 'pen occupant count {}' pen kept_animal=false tamed=+0 script_errors=0`, the same for `unknown species` and `unknown id`, and `[t_save] hostile 'pen occupant attribute junk' pen kept_animal=true tamed=+1 script_errors=0` |
| Full cargo never destroys a refund | pass | `[t_save] full cargo refund held_on_disk=[3, 7, 1] after_room=[3, 7, 1]` |
| Refunded pen and field keep the animal and seed; full cargo keeps the animal on disk | pass | `[t_save] pen refund cargo [animal, species, pen kit, field kit, corn_seed]=[1, "velociraptor", 1, 1, 1] whys=["unclaimed", "unclaimed"]` and `[t_save] pen refund full_cargo_kept=1 free_cell_pens=1` |
| A refused save keeps the travel cache | pass | `[t_save] refused save camp cache baskets=2 stone=16` |
| v0, v1, v2 content survives migration | pass | `[t_save] legacy save_v0.json buildings=["basket"] bag={  } t_stones=20.0 island=home_grassland`, the v1 line above, `[t_save] legacy save_v2.json buildings=[] bag={  } t_stones=20.0 island=home_grassland` |
| Truncated fixture: sha unchanged, `.corrupt-*` exists, save_now false until confirm | pass | these are `_check`s inside t_save, so any failure would print `[t_save] FAIL ...`. None printed and the run ended in `[t_save] PASS` |
| Future fixture unchanged after 70 s of autosave | pass | `[t_save] future fixture after 70 s on_disk_schema=99.0` |
| Two saves: `.bak` holds the first, no `.tmp` remains | pass | a t_save check, covered by `[t_save] PASS` |
| v0, v1, v2, v3-golden, v3-away-golden load and re-save field for field | pass | `[t_save] round trip save_v0.json fields=23 diffs=0` (same with `diffs=0` for v1, v2, v3_golden; `save_v3_away_golden.json fields=24 diffs=0`) |
| Forged fixture clamps (helm x1 L60, unknown and negative stacks dropped, t_stones 0, skills <= 60, default position, no SCRIPT ERROR) | pass | t_save checks, covered by `[t_save] PASS`. A grep for `SCRIPT ERROR` in the log returned nothing |
| Schema-99 save, boot main.tscn, idle more than 63 s | pass | headless boot for 75 s, then `on_disk_schema_after_75s 99` with the same sha256 before and after (`a58d72a7…`). Log: `[save] refused: user://save_1.json is unreadable (it was made by a newer version (schema 99)); confirm a new game first` |
| `--lab=build_lab` leaves `user://save_1.json` alone | pass | `before mtime=1792417723 sha=a74edd435959091c after mtime=1792417723 sha=a74edd435959091c`. A new `runs/build_lab/save_1.json` and `.bak` were written (mtime Oct 19 08:48) |
| Away-island basket survives save and load | pass | `[t_save] away island=temperate_25 is_home=false placed_baskets=1 stone_in_baskets=9` |
| saved_unix=0 clamps catch-up to <= 7 days | pass | `[save] offline catch-up clamped 1792417518s -> 604800s` |
| `grep -n 'app_userdata' tools/shell_test.sh` | pass | no output (grep exit 1) |
| Existing suite (rerun on `20cfdb2`) | pass | `[tests] PASS` (run_all.gd, exit 0) |
| Smoke (rerun on `20cfdb2`) | pass | `SMOKE PASS` (`tools/smoke.sh --no-import`, Godot through `godot_silent.sh` for the Dummy audio driver) |

Round 3 logs: `/private/tmp/claude-501/-Users-milankinzy-Documents-deadfront-siege/1899b1df-f06b-4b94-91be-9e3f3c22081d/scratchpad/w1/save/r3/` (`t_save.log`, `t_save_oldcode.log`, `run_all.log`, `smoke.log`, `import.log`). Older rounds: the parent folder (`overwrite99.log`, `build_lab.log`); the schema-99, build_lab and screenshot items were not rerun in round 3 (no change touches them).

## Screenshots inspected

Rounds 2 and 3 changed no UI, so no new screenshots. Round 1:

These are windowed runs of main.tscn with a schema-99 save and `World._boot()`, from `scratchpad/w1/save/shot/runner.gd`. I looked at both images.

- `scratchpad/w1/save/shot/save_warning_1600.png` (1600x900): the orange warning is a single line between the subtitle and the card grid. Nothing overlaps it, and the Body / Woman / Man / name / ENTER THE RIFT row is fully visible at the bottom. Rect `P: (24.0, 161.0), S: (1552.0, 38.0)`.
- `scratchpad/w1/save/shot/save_warning_1947.png` (window 844x390, phone landscape; the stretched viewport is 1947 wide): the warning wraps to two lines under "Pick a background…". The cards shrink, and the bottom row stays fully visible and is not covered.

## Assumptions

- `save_game.gd`: `MAX_OFFLINE_SECONDS = 7 days`. Offline growth is capped at a week, so a wrong device clock can fast-forward farms no further than that.
- `save_sanitizer.gd`: `MAX_T_STONES = 100000`. No shipped faucet comes close to this; the cap only stops forged balances.
- `save_sanitizer.gd`: `WORLD_LIMIT = 2000 m` from the island origin.
- `save_sanitizer.gd`: `butchering_I`/`II` exist only in survival.json and have no trees.json node (only the debug panel sets them). Next to a skill-tree save they load as false.
- `save_sanitizer.gd`: `MAX_CLAIM_TILES = 14`, the side of `IslandRuntime.claim_at`'s plot, its only caller's size.
- `save_sanitizer.gd`: vitals are clamped to 0..1e6. This only stops non-numbers and negatives. A forged `max_health` below that still loads (see "left").
- `save_restore.gd`: a refunded field gives back the seed its crop took, whatever its growth (a mature crop's harvest is not refunded; a failed crop gives nothing).
- `save_sanitizer.gd`: a stack whose attributes name an unknown `species` is dropped, as an unknown pet species is.
- After an aborted load, the world the player sees is half-built and saving is refused for that session. The file is never overwritten. The next launch tries it again, and the hole that caused the abort should then be closed in the sanitizer.

## Integrator hooks

- Owner of `game/scripts/ui/character_creation.gd`: add `func show_notice(text: String) -> void` that places a label under the subtitle, then `SaveGame._warn_new_world` should call `cc.show_notice(note_text)` instead of finding `VBoxContainer` child 1 and `move_child(note, 2)`.
- Integrator check before merge: run `tools/shell_test.sh` once (through gslot) and confirm `SHELL TEST PASS`; whether `HOME=$TMPHOME` works with the mono runtime is unverified.

- world.gd line 178 (`World.travel`): may call `SaveRestore.buildings(_home_buildings_cache, SaveMigrations.CURRENT_SCHEMA)` directly; run_all.gd lines 773/777, kitchen_lab.gd and siege_probe.gd may call `SaveRestore.spawn(row)`. Then the two delegates at the end of save_game.gd can go. Optional: they work as they are.
- After merging onto the overhaul tip: rerun t_save, run_all and smoke. `PET_ROW` already lists `tamed_at` and `wild_level`; if the tip's `PetRecord.from_dict` or a building `from_dict` casts any other new numeric field, add it to `PET_ROW` or `BUILDING_ROW`.

The autosave stop lives inside `SaveGame.save_now()`, so world.gd is unchanged.

## Labs to register

None new. `home_lab` and `build_lab` already exist.

## Failed or left

- Forged but well-typed values that still load (sec-save-05 stays partly open): pet stats and genetics (forged `hp=1000000000 attack=99999` at level 60 load as written; limits belong with W1-TAME's PetStats, which does not exist on this branch), vitals maxima (`max_health 1e6` loads; checking it needs `Vitals`/equipment, not owned), t_stones up to `MAX_T_STONES` 100000, `unstable.harvested` rows and `pioneer_crafts`/`pioneer_buildings` values (type-checked only by their callees).
- After an aborted load there is no in-game way out: each launch loads half-built and refuses saving until the file is fixed by hand. The notice says so; offering the `.bak` or a new game from it needs a UI the package does not own.
- Two automated runs launched at once under the same run name share and wipe one folder (shortcut comment in `_pick_path`).
- `tools/shell_test.sh` not run end to end (integrator check above).
- The branch was cut before survivor-v2 and the asset-replacement register landed on `claude/mmo-overhaul`, so the merge needs a fresh `[tests] PASS` and `SMOKE PASS` on the overhaul tip.
- An older `save_1.json.corrupt-1792378954` from a previous attempt sits in this worktree's isolated user dir (`~/Library/Application Support/deadfront-mmo-w1-save/`).
