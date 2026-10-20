# Task: a table-driven hostile-argument check for the server character store

DEADFRONT is a Godot 4.7.1 typed-GDScript game (project in `game/`). `game/scripts/server/` holds the
server side of multiplayer: `CharacterStore.apply(op, account, args, ts)` runs one op
(`IntentHandlers`) on a server-owned character and journals it. Clients are hostile: any JSON may
arrive as `args`. Every handler must refuse a bad request with an error code and change nothing,
and must never hit a script error (a script error is caught by a rollback and comes back as
`server_error`, which is the wrong answer and spams the server log).

Today a few hand-written probes cover this. You add one table that covers every op.

## What to write (one file only: `game/tests/srvdom_checks.gd`)

1. A constant `HOSTILE` near the top of the file: an Array of rows `[op, args, expected_err]`,
   **one row per line**, written exactly like `	["act.gather", {"node_id": 7}, "bad_request"],`
   (the verify script counts rows by that shape).
   - `op` is a String from `IntentHandlers.CLIENT_OPS` or `IntentHandlers.SYSTEM_OPS`
     (read `game/scripts/server/intent_handlers.gd`). Leave out `char.get` (a read that never refuses).
     Every other op (16 of them) gets **at least 3 rows**; **at least 60 rows** in total.
   - `args` is a Dictionary literal. Cover, for the keys each op reads (`IntentHandlers.ARG_KEYS`):
     a missing required key, a wrong type (bool, String where an int is expected, int where a
     String is expected, Dictionary, Array), a float that is not whole (1.5), a negative or
     out-of-range int, an over-long String (use a literal of 65+ characters or a key the handler caps),
     and for `char.move` positions holding `NAN`, `INF`, a String, and the wrong length.
     Also the asset-dict keys `act.deposit` refuses and `char.import`.
   - `expected_err` is a **literal String** you work out by reading the handler code
     (`bad_request`, `not_found`, `invalid_asset`, `unauthorized`, `insufficient_items`, ...).
     Never compute the expected code from the result. `server_error` is never an expected code.
2. A function `_hostile_arg_checks()` and a call to it in `run()`, right after `_hardening_checks()`.
   - Fixture: `var w := make_world()` and `var st := _store(16, w)`, then give account 1 a stack:
     `_gather_until(st, 1, "rock", 0, "stone", 2, 2)` so bag slot 0 holds stone.
   - For each row: record `st.state_hash()`, `st.lines.size()` and `CharacterStore._errors.n`; call
     `st.apply(op, 1, args, 3)`; then `expect(...)` that the result is not ok, its `err` equals
     `expected_err`, the hash and journal length are unchanged, and `_errors.n` is unchanged (no
     script or engine error). The failure message names the row index, op, args and what came back.
   - Then, for every op key of `IntentHandlers.ARG_KEYS`: build a Dictionary with every allowed
     key set to 1 plus `"rid": "r"` and `"junk": 1`, and `expect` that
     `IntentHandlers.known_args(op, that)` has exactly the allowed keys plus `rid` (no `junk`).
   - Print exactly one evidence line, with real counted values (not constants):
     `[srvdom] hostile rows=<rows> ops_covered=<distinct ops in HOSTILE> matched=<rows whose err matched> script_errors=<total _errors.n increase> unchanged=<true if every row left hash and journal alone> allowlist_ops=<ARG_KEYS ops checked>`
3. Do not change, remove or weaken any existing check or `[srvdom]` print in the file.

If a row's real answer differs from what you expected, read the handler again. If the handler is
right, fix the row. If you believe the handler is wrong (for example it returns `server_error` or
raises a script error on a hostile input), keep the row with the correct expected code, let the
check fail, and stop: write what you found at the end of this file under "## Findings" and commit.
Do NOT edit anything under `game/scripts/` to make a row pass.

## Rules

- Edit only `game/tests/srvdom_checks.gd` (and this TASK.md's Findings section). No other file.
- House style: typed GDScript (`var x: bool = ...` where the type cannot be inferred), tabs,
  short why-comments, no `class_name` in the test file.
- Run Godot ONLY like this (the machine is shared and must stay silent; never add --editor):
  `/private/tmp/claude-501/-Users-milankinzy-Documents-deadfront-siege/1899b1df-f06b-4b94-91be-9e3f3c22081d/scratchpad/gslot.sh perl -e 'alarm 300; exec @ARGV' /Applications/Godot_mono.app/Contents/MacOS/Godot --headless --path game -s res://tests/t_srvdom.gd`
  Never run Godot without gslot.sh, never run `--import`, never play audio. Keep `game/override.cfg`.
- Commit when the table first runs and again when done, messages ending
  `Co-Authored-By: DeepSeek (dsc) <noreply@deepseek.com>`. Never commit `.godot/`, `override.cfg`,
  `*.import`, `.dsc/` or `.dsc.json`.
- Done means `./verify_hostile.sh` exits 0. Never edit that script.

## Milestones

1. Read `intent_handlers.gd` (every handler's first lines are its validation) and `character_store.gd`
   (`apply`, `_run`, `_errors`).
2. Write `HOSTILE` with 20 rows and the function; run t_srvdom; fix rows until they match; commit.
3. Grow to 60+ rows covering all 16 ops; add the allow-list part; run `./verify_hostile.sh`; commit.

## Findings

No handler bugs found. All 153 rows were refused with the code read from the handler, with the
state hash, journal length and `CharacterStore._errors.n` unchanged, so nothing raises a script
error or returns `server_error` on these inputs. Godot prints two harmless WARNINGs while
`CharacterStore.wire()` round-trips NAN/INF through JSON (JSON.stringify replaces them with
null); they are warnings, so the error logger does not count them.

