# Task: NATURETAG — the nature is a tag under the name, not part of the name

Owner (verbatim, 2026-10-28): "for animal's natures, put it as a tag under their name, not in the name itself."
NATURES (merged) put the nature into the display name ("Timid Velociraptor", "Brave Alpha Raptor") via
CreatureNatures.display_name in game/scripts/creatures/brains/brain_natures.gd. Change every place that shows a
creature/pet name so the name no longer contains the nature (variant prefixes like "Alpha" stay in the name), and the
nature appears as a small tag/chip directly under the name: world nameplates (creature plates / labels), the Animals
screen, the pet radial header, the capture/tame card and any other place display_name was used (grep for it).
Chip style: use UiTokens.trait_chip_style (spec docs/design/ui-redesign-spec.md §5) — pick a neutral polarity for
natures (# ASSUMPTION: natures are not good/bad; use the &"positive"/gold style for none — add a 4th neutral chip
style in UiTokens only if trait_chip_style can't express neutral; if you must add it, keep the existing three intact).
Keep the nature text short ("Timid"). Nothing jumps between frames; plates keep their size budget.
Milestones: M1 update t_natures (and t_targetui/t_petradial if they assert names): display name has no nature word;
a nature chip node exists under the name with the nature's label on the plate, the Animals screen row and the pet
radial; variant prefix still in the name. Stage 1. M2 implementation. M3 docs/current/creatures-capture-taming.md +
hud.md notes, spec §11 line "[owner 2026-10-28] nature shown as a chip under the name", report
docs/orchestration/reports/dsc-naturetag.md + full verify. Headless only.

## How to run Godot (exactly)
- Headless test: `/private/tmp/claude-501/-Users-milankinzy-Documents-deadfront-siege/1899b1df-f06b-4b94-91be-9e3f3c22081d/scratchpad/gslot.sh perl -e 'alarm 400; exec @ARGV' /Applications/Godot_mono.app/Contents/MacOS/Godot --headless --path game --script res://tests/<t>.gd > /tmp/naturetag_t.log 2>&1` (bash timeout_ms 460000).
- After adding a class_name file or an asset: `... perl -e 'alarm 900; exec @ARGV' /Applications/Godot_mono.app/Contents/MacOS/Godot --headless --path game --import > /tmp/naturetag_import.log 2>&1`.
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
- Scratch files go in $TMPDIR/naturetag, never /tmp or docs/. Never `rm -r` a path that has tracked files.
- Key any per-item data by a stable id (file name, src_rect), never by list order.
- Write big files in parts (write_file, then edit_file); never python `s.replace()` without checking it matched.
## Gates
- Verify: `bash /private/tmp/claude-501/-Users-milankinzy-Documents-deadfront-gate/a2917b6d-2049-454d-9c63-314953df33d7/scratchpad/dsc/verify_job.sh naturetag [1|2]` (no argument = the full gate). Read it and
  `/private/tmp/claude-501/-Users-milankinzy-Documents-deadfront-gate/a2917b6d-2049-454d-9c63-314953df33d7/scratchpad/dsc/job_naturetag.conf` (TEST, LAB, LAB_ASSERT, RELATED, SCOPE) before you start.
- The lab gets `--shot-dir=<dir>`: save every PNG there. It must print exactly one line `[naturetag] RESULT k=v k=v ...` with every
  key LAB_ASSERT reads, MEASURED from the live scene (never constants), then quit.
- Milestones: write them to .dsc/PLAN.md and call milestone_done after each (milestones before MS_STAGE2 run stage 1, later
  ones stage 2). Anything visual: open the PNG, and write the path and a one-line verdict in .dsc/NOTES.md before ticking.
## Constraints
- Your files are the SCOPE regex in the conf; touch nothing else. Edit shared files, do not rewrite them; keep existing asserts.
- Keep game/override.cfg. Never touch other worktrees, ~/Documents/deadfront, the owner's save, or the main checkout. Do not
  merge branches, push or deploy. No new dependencies.
- Do not tune balance numbers (HP, damage, XP, fatigue or energy rates). Owner: "game balancing like tuning hp and damage wont
  make sense until crafting building and skills is done and tuned". Mark every number the docs do not give `# ASSUMPTION`.
- Report docs/orchestration/reports/dsc-naturetag.md: what shipped, before/after numbers, the shots you looked at, assumptions,
  what the integrator needs.
