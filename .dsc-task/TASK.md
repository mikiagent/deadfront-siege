# Task: ICONS4 — render the remaining unrendered item icons with the existing pipeline

76 of 240 items still have no render (`game/assets/icons/render/manifest.json` "missing"; the list and context are in
docs/orchestration/reports/dsc-icons3.md). Render as many as the EXISTING pipeline can do in the established style:
tools/render_icons.py + the builders in tools/blender/items/ (resources.py, camp.py, food.py, gear.py, kit.py),
headless Blender (/Applications/Blender.app/Contents/MacOS/Blender --background, one at a time), consistent studio
light, transparent PNG, the same framing/crop and .png.import settings as the existing renders. Read dsc-icons3.md and
the builders first; reuse existing parts/materials (an ingot builder for a new ingot, a hide builder for a new hide,
food shapes for foods). Do NOT invent a new art direction; an item that needs one goes on the "needs art" list instead.
Priority order: items a new player sees in the first hour (gathered materials, foods and drinks, first tools and
kits), then the rest.

Rules: every render must be deterministic (render twice, bytes identical — see how ICONS3 fixed armor_scute);
manifest entries added, "missing" regenerated exactly; t_iconart PASS; open every PNG you produce and write a one-line
verdict per id in .dsc/NOTES.md (does it read as the item at 48 px?) — redo or drop any that do not.
Milestones: M1 first-hour batch (aim 20+) rendered, checked, manifest updated, t_iconart stage 1.
M2 second batch. M3 report docs/orchestration/reports/dsc-icons4.md (rendered list with verdicts, still-missing list
with reasons) + full verify. Headless only; no Godot windowed labs. No paid generation.

## How to run Godot (exactly)
- Headless test: `/private/tmp/claude-501/-Users-milankinzy-Documents-deadfront-siege/1899b1df-f06b-4b94-91be-9e3f3c22081d/scratchpad/gslot.sh perl -e 'alarm 400; exec @ARGV' /Applications/Godot_mono.app/Contents/MacOS/Godot --headless --path game --script res://tests/<t>.gd > /tmp/icons4_t.log 2>&1` (bash timeout_ms 460000).
- After adding a class_name file or an asset: `... perl -e 'alarm 900; exec @ARGV' /Applications/Godot_mono.app/Contents/MacOS/Godot --headless --path game --import > /tmp/icons4_import.log 2>&1`.
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
- Scratch files go in $TMPDIR/icons4, never /tmp or docs/. Never `rm -r` a path that has tracked files.
- Key any per-item data by a stable id (file name, src_rect), never by list order.
- Write big files in parts (write_file, then edit_file); never python `s.replace()` without checking it matched.
## Gates
- Verify: `bash /private/tmp/claude-501/-Users-milankinzy-Documents-deadfront-gate/a2917b6d-2049-454d-9c63-314953df33d7/scratchpad/dsc/verify_job.sh icons4 [1|2]` (no argument = the full gate). Read it and
  `/private/tmp/claude-501/-Users-milankinzy-Documents-deadfront-gate/a2917b6d-2049-454d-9c63-314953df33d7/scratchpad/dsc/job_icons4.conf` (TEST, LAB, LAB_ASSERT, RELATED, SCOPE) before you start.
- The lab gets `--shot-dir=<dir>`: save every PNG there. It must print exactly one line `[icons4] RESULT k=v k=v ...` with every
  key LAB_ASSERT reads, MEASURED from the live scene (never constants), then quit.
- Milestones: write them to .dsc/PLAN.md and call milestone_done after each (milestones before MS_STAGE2 run stage 1, later
  ones stage 2). Anything visual: open the PNG, and write the path and a one-line verdict in .dsc/NOTES.md before ticking.
## Constraints
- Your files are the SCOPE regex in the conf; touch nothing else. Edit shared files, do not rewrite them; keep existing asserts.
- Keep game/override.cfg. Never touch other worktrees, ~/Documents/deadfront, the owner's save, or the main checkout. Do not
  merge branches, push or deploy. No new dependencies.
- Do not tune balance numbers (HP, damage, XP, fatigue or energy rates). Owner: "game balancing like tuning hp and damage wont
  make sense until crafting building and skills is done and tuned". Mark every number the docs do not give `# ASSUMPTION`.
- Report docs/orchestration/reports/dsc-icons4.md: what shipped, before/after numbers, the shots you looked at, assumptions,
  what the integrator needs.
