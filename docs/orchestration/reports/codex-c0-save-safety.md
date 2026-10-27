# C0 save safety handoff

Starting point: `origin/main` at `923657262cd335fefee9126df61dd0fff4b93321`.
Implementation branch: `codex/c0-save-recovery`. No main merge or deployment.

## Changes

The existing `SaveGame.save_now()` and `load_now(host)` APIs and schema-3
snapshot remain in place. `save_recovery.gd` checks save shape and version,
stages and verifies bytes, retains the previous valid primary as `.bak`, and
promotes the staged file by rename. It refuses to replace an invalid or newer
primary. Missing primary with an existing backup also stops saving. The bot's
throwaway path does not create a persistent backup.

Invalid, incomplete and future-version saves now show a recovery error instead
of starting a new character. Saving remains blocked during world restoration,
so a partial load cannot be autosaved. The error gives the backup path when one
exists. A user must currently restore a backup manually; there is no automatic
restore or destructive new-game choice.

## Checks

On the untouched baseline, `tools/test.sh` returned 0 and printed `[tests] PASS`;
`tools/smoke.sh --no-import` returned 0 and printed `SMOKE PASS`. The baseline
suite deliberately prints the future-schema error and reports shutdown leaks.

With Godot 4.7.1 Mono, after the change:

- `--headless --path game --script res://tests/c0_save_guard_regression.gd`:
  exit 0, `C0 SAVE GUARD PASS`.
- `--headless --path game --script res://tests/c0_save_write_regression.gd`:
  exit 0, `C0 SAVE WRITE PASS`. Includes a staged backup-promotion failure,
  repeated saves, a partial pending file and future-version preservation.
- `--headless --path game --script res://tests/c0_save_compat_regression.gd`:
  exit 0, `C0 SAVE COMPAT PASS: schema 0, 1, 2 and 3`.
- `--headless --path game -- --lab=c0_save_recovery_lab`: exit 0,
  `C0 SAVE RECOVERY LAB PASS`. Exercises current player inventory, item
  attributes and flags, pet genetics, cargo, claims, basket contents and
  position, plus an actual schema-1 load and coordinate conversion. Test saves
  use unique `/private/tmp` paths.
- `GODOT_PATH=/Applications/Godot_mono.app/Contents/MacOS/Godot bash tools/test.sh`:
  exit 0, `[tests] PASS`. The sandbox also produced a Godot editor socket
  permission warning and a certificate warning; the future-schema message and
  shutdown leak warnings were present in the baseline.
- `GODOT_PATH=... bash tools/smoke.sh --no-import`: exit 0, `SMOKE PASS`.
- `--headless --path game -- --smoke --touch`: exit 0, `[smoke] ok`, touch layer
  reported `tap-only`.

The test commands above were run through the repository's Godot slot wrapper
and a timeout. A native Godot recovery-screen screenshot was inspected at
1600x900 and 390x844. The initial portrait text was too small; the second
portrait capture was readable. The inventory baseline was captured in the
existing UI lab. Screenshot files are local temporary evidence, not committed.

## Remaining verification and risks

- The browser/IDBFS and mobile filesystem rename and persistence behavior has
  not been verified. `flush()` and rename are not a proof of durable hardware
  fsync or browser synchronization. Do not deploy this change until those paths
  are tested on the target platforms.
- The interrupted-write tests simulate a partial pending file and an actual
  failed backup promotion; they are not a power-loss test.
- Schema 0 and 2 were tested through migration and staged-file round trips;
  schema 1 and current schema 3 additionally received actual world-load tests.
  Not every historical save shape or nested corrupt field is covered.
- Desktop and portrait images were inspected, but real mouse/touch interaction
  and a browser screenshot were not exercised. The recovery screen is a safe
  blocking state, not an in-game restore flow.
- The existing full inventory/crafting suite passed; no new fusion rules or
  gameplay formulas were implemented. C1 still requires an approved fusion
  contract, trait merge caps, and compatibility tests.

DeepSeek evaluation is recorded separately under `docs/worker-evaluations/`.
No Meshy credits were spent. The rebuild plan remains paused.
