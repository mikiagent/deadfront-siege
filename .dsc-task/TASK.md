# Task: ICONS3 — land the ICONS2 item renders (65 missing or weak icons) onto canon

Branch `claude/mmo-icons2` (2026-10-21) re-rendered 32 missing and 33 weak item icons with headless Blender
(tools/blender/items/, game/assets/icons/render/, game/data/icons_manifest.json). Every render was done and looked at,
but its gate never passed: `armor_scute` did not re-render byte-identically (determinism), 7 ids were never
repro-checked, and the needed `game/tests/t_iconart.gd` change was flagged out of scope. Read its reports first:
`git show claude/mmo-icons2:docs/orchestration/reports/claude-mmo-icons2.md` and `...:dsc-icons2.md`.
Canon has since added items (240 now: W2-GATHER traits, FOODFX foods, CRAFTFEEL); check which ids still lack a render.

Do:
1. Bring in ONLY the in-scope paths from the branch (no `work/`, no root TASK.md, no tools/dsc/):
   `git checkout claude/mmo-icons2 -- game/assets/icons/render tools/blender/items` (then inspect; keep canon's newer
   files where the branch is older — compare before overwriting), and merge `game/data/icons_manifest.json` by hand
   so canon's entries survive and the branch's new ones are added.
2. Fix armor_scute determinism at the root in the render script (seeded noise / fixed sample count / no time-based
   input), re-render it, and repro-check the 7 unchecked ids: re-render twice, bytes identical.
3. Apply the t_iconart.gd change the branch needed (read its report), keeping every existing assert.
4. List items in canon that still have no icon render in the report (do not render new ones unless < 10 and the
   existing pipeline handles them with no new art direction).
Milestones: M1 files in + manifest merged + t_iconart stage 1. M2 determinism fix + repro of 8 ids. M3 report
docs/orchestration/reports/dsc-icons3.md + full verify. Headless only: Blender headless is fine; no Godot windowed labs.
Blender: /Applications/Blender.app/Contents/MacOS/Blender --background (one at a time). No paid generation.

## How to run Godot (exactly)
- Headless test: `/private/tmp/claude-501/-Users-milankinzy-Documents-deadfront-siege/1899b1df-f06b-4b94-91be-9e3f3c22081d/scratchpad/gslot.sh perl -e 'alarm 400; exec @ARGV' /Applications/Godot_mono.app/Contents/MacOS/Godot --headless --path game --script res://tests/<t>.gd > /tmp/icons3_t.log 2>&1` (bash timeout_ms 460000).
- After adding a class_name file or an asset: `... perl -e 'alarm 900; exec @ARGV' /Applications/Godot_mono.app/Contents/MacOS/Godot --headless --path game --import > /tmp/icons3_import.log 2>&1`.
- Parse-check every new or edited .gd before a long run: `... --headless --path game --check-only --script res://<path>`.
  `--check-only` ALWAYS prints "Identifier not found: Data / World / Game / TouchControls" (autoloads do not exist in that
  mode): ignore those lines; only `Parse Error` lines are real. Real tests run with `--script res://tests/<t>.gd`, where the
  autoloads DO exist once the first frame runs: the test must load() every game script on its first frame instead of
  naming classes at compile time (copy game/tests/t_domain.gd's structure exactly).
- Never pipe Godot into tail/head/grep: read the log file afterwards. Never re-run a failed or hung command unchanged.
## Known traps
- `:=` cannot infer from max()/min()/ternaries/Variant returns: use maxf/maxi or an explicit type.
- Await coroutines. A `--script` test has no autoloads on its first frame: load() scripts on the first frame and add a 60 s
  quit watchdog, as game/tests/t_domain.gd does; print `[<test name>] PASS` or FAIL lines.
- game/tests/t_save.gd prints 5 deliberate SCRIPT ERRORs; that is normal.
- A lab log with `SHADER ERROR` or `Unknown character` means the shader did not compile and every card draws grey: the
  gate fails on it. GDScript `##` comments are not shader syntax; shaders use `//`.
- Scratch files go in $TMPDIR/icons3, never /tmp or docs/. Never `rm -r` a path that has tracked files.
- Key any per-item data by a stable id (file name, src_rect), never by list order.
- Write big files in parts (write_file, then edit_file); never python `s.replace()` without checking it matched.
## Gates
- Verify: `bash /private/tmp/claude-501/-Users-milankinzy-Documents-deadfront-gate/a2917b6d-2049-454d-9c63-314953df33d7/scratchpad/dsc/verify_job.sh icons3 [1|2]` (no argument = the full gate). Read it and
  `/private/tmp/claude-501/-Users-milankinzy-Documents-deadfront-gate/a2917b6d-2049-454d-9c63-314953df33d7/scratchpad/dsc/job_icons3.conf` (TEST, LAB, LAB_ASSERT, RELATED, SCOPE) before you start.
- The lab gets `--shot-dir=<dir>`: save every PNG there. It must print exactly one line `[icons3] RESULT k=v k=v ...` with every
  key LAB_ASSERT reads, MEASURED from the live scene (never constants), then quit.
- Milestones: write them to .dsc/PLAN.md and call milestone_done after each (milestones before MS_STAGE2 run stage 1, later
  ones stage 2). Anything visual: open the PNG, and write the path and a one-line verdict in .dsc/NOTES.md before ticking.
## Constraints
- Your files are the SCOPE regex in the conf; touch nothing else. Edit shared files, do not rewrite them; keep existing asserts.
- Keep game/override.cfg. Never touch other worktrees, ~/Documents/deadfront, the owner's save, or the main checkout. Do not
  merge branches, push or deploy. No new dependencies.
- Do not tune balance numbers (HP, damage, XP, fatigue or energy rates). Owner: "game balancing like tuning hp and damage wont
  make sense until crafting building and skills is done and tuned". Mark every number the docs do not give `# ASSUMPTION`.
- Report docs/orchestration/reports/dsc-icons3.md: what shipped, before/after numbers, the shots you looked at, assumptions,
  what the integrator needs.
