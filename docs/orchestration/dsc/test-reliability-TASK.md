# Task: TEST-RELIABILITY — stop false-green Godot test gates

Work only in the fresh dsc worktree cut from `claude/mmo-overhaul`. This is a narrow, headless-only reliability task; it is not gameplay, balance, UI, asset, save-schema, or deployment work.

## Goal

Two test entry points currently report success after unexpected engine errors. Repair the real test/load-order defects and make the existing checks honest. Do **not** hide or filter failures. The final strict verifier must exit 0 only when both tests execute without unexpected `SCRIPT ERROR` lines and their PASS marker is present.

## Baseline (reproduce before editing)

Run the provided verifier once before editing. It currently fails for these exact, reproducible signals:

- `t_bags` prints `[t_bags] PASS` and exits 0, but emits `SCRIPT ERROR: Invalid access of index '0' on a base object of type: 'Array[int]'` at `tests/t_bags.gd:276`. Its preview fixture gives `raw_hide`, `fibre_stalk`, and `twine`, while `basic_bag` requires the `dried_hide`, `fibre`, and `lashing` recipe categories.
- `run_all` prints `[tests] PASS` despite compile errors for `World` in `scripts/skills/skill_state.gd:44` and `scripts/ui/level_display.gd:12`, then `Invalid call. Nonexistent function 'new' in base 'GDScript'` at `tests/process_checks.gd:107`.

The assignment is to establish the causal chain, not to assume it. In particular, prove whether the process-check `SkillState` failure remains after the autoload/load-order repair.

## Required behaviour

1. The bag preview test supplies valid instances for every required `basic_bag` recipe category, chooses valid picks safely, and asserts the intended preview/crafted-result contract. It must fail meaningfully if a recipe category is absent; it may never index an unchecked empty candidate array.
2. `run_all` must not compile or execute code that assumes autoloads exist before the engine first frame. Follow the established first-frame `load()` test pattern (`t_domain.gd` is the reference). Keep all existing assertions; move/defer only what is needed for correct lifecycle ordering.
3. Resolve the `SkillState`/`World` and `LevelDisplay`/`World` load boundary with a real runtime-safe access path that works in normal gameplay as well as `--script` tests. Do not replace behaviour with constants, delete XP/UI behaviour, or catch-and-ignore errors.
4. Make `process_checks.gd` load/instantiate the existing `SkillState` correctly after the load-order fix. Its test must preserve the real `collect pays Processing XP ... once` assertion.
5. The test runner must fail if any of these real test paths emits a `SCRIPT ERROR`; `t_save` is deliberately out of scope and remains the only documented exception.

## Scope — strict

You may edit only:

- `game/tests/t_bags.gd`
- `game/tests/run_all.gd`
- `game/tests/process_checks.gd`
- `game/scripts/skills/skill_state.gd`
- `game/scripts/ui/level_display.gd`
- `docs/orchestration/reports/dsc-test-reliability.md`

Do not edit `game/project.godot`, `game/override.cfg`, `tools/`, data files, scenes, assets, save code, game balance values, or any other gameplay/UI code. If the actual fix needs a file outside this list, stop after documenting the exact blocker; do not expand scope.

## Headless operation — mandatory

The owner is multitasking. Never open, focus, or control a visible app or browser. Do not pass `--computer`, `--computer-foreground`, `--editor`, screenshot, window, rendering, or non-headless Godot flags.

Every Godot invocation (including smoke) must run exactly through:

```bash
/private/tmp/claude-501/-Users-milankinzy-Documents-deadfront-siege/1899b1df-f06b-4b94-91be-9e3f3c22081d/scratchpad/gslot.sh \
  perl -e 'alarm 300; exec @ARGV' \
  /Applications/Godot_mono.app/Contents/MacOS/Godot --headless --path game ...
```

Redirect Godot output to a `/tmp/test_reliability_*.log` file and read it afterwards. Never pipe Godot into `grep`, `head`, `tail`, or `tee`; never use `--readonly`. Run engine tests serially. Do not touch the owner’s real save or any other worktree.

## Milestones

1. Run `bash docs/orchestration/dsc/gates/verify_test_reliability.sh`, record the three baseline errors above in the report, and write `.dsc/PLAN.md` with these milestones.
2. Repair the bag fixture and run the verifier far enough to prove `t_bags` passes cleanly. Parse-check only edited GDScript through gslot before a full test.
3. Repair the autoload/load ordering and process-check chain. Prove `run_all` passes cleanly, including its process assertion.
4. Run the full strict verifier and write the report: before/after output, exact changed files, commands/results, and remaining limitations. Call `milestone_done` only after each relevant command passes.

## Done when

`bash docs/orchestration/dsc/gates/verify_test_reliability.sh` exits 0, the report exists, and the diff is within scope. The runner will commit verified work. Do not push, merge, deploy, rewrite history, or use destructive cleanup.
