# Task: GATHERGLIDE: the gather radial glides instead of jumping

Owner context: "UI glitching up and down on resource nodes". DEADFRONT is a Godot 4.7.1 typed-GDScript survival game
(project `game/`), web build, mobile-first (phone 844x390 landscape).
The gather radial is the hex menu that opens on a resource node. A first fix (merged, CONTROLS B1) holds its solved layout
while the camera moves: game/scripts/ui/radial_hold.gd (RadialHold: follow(), SLACK, MAX_DRIFT) and
game/scripts/ui/gather_radial.gd. Read docs/orchestration/reports/claude-mmo-gatherfix.md, its follow-ups section, first.
Lab: game/scripts/dev/gather_jitter_lab.gd (+ scene). Test: game/tests/t_controls.gd.
## What to build
1. When the held layout must re-solve (drift > MAX_DRIFT, or it no longer fits), glide the hexes, title and labels from the
   old layout to the new one, eased, never more than 8 px per frame; a label may change side on its own without re-solving
   the hexes.
2. Fix the one 45 px step on click that the gatherfix report names.
3. Port the phone set-up fixes from CONTROLS B3's gather_jitter_lab on branch claude/mmo-controls (read it with
   `git show claude/mmo-controls:game/scripts/dev/gather_jitter_lab.gd`; do not merge): stand the survivor up, skip the
   screenshot-stall frame, so the lab is valid at 844x390.
## Milestones
- M1 game/tests/t_gatherglide.gd: unit-test the glide (a RadialHold re-solve moves each part <= 8 px per frame and arrives;
  a label side change does not move the hexes). Stage 1.
- M2 The glide and the click-step fix in radial_hold.gd / gather_radial.gd. Stage 1.
- M3 gather_jitter_lab accepts --shot-dir, walks the survivor past nodes while the camera follows and clicks a node, and
  prints `[gatherglide] RESULT max_step_px= side_swaps= click_step_px= resolves= frames=` measured over >= 120 frames, plus
  2 screenshots. Stage 2.
- M4 Phone set-up port and 844x390 numbers. Stage 2.
- M5 Report with before/after numbers and the full verify.

## How to run Godot (exactly)
- Headless test: `/private/tmp/claude-501/-Users-milankinzy-Documents-deadfront-siege/1899b1df-f06b-4b94-91be-9e3f3c22081d/scratchpad/gslot.sh perl -e 'alarm 400; exec @ARGV' /Applications/Godot_mono.app/Contents/MacOS/Godot --headless --path game --script res://tests/<t>.gd > /tmp/gatherglide_t.log 2>&1` (bash timeout_ms 460000).
- Labs and screenshots need a window, never --headless (frame_post_draw never fires headless):
  `... perl -e 'alarm 400; exec @ARGV' /Applications/Godot_mono.app/Contents/MacOS/Godot --path game --resolution 1600x900 --rendering-method gl_compatibility -- --lab=gather_jitter_lab --shot-dir=/tmp/gatherglide_shots > /tmp/gatherglide_lab.log 2>&1`, and again with --resolution 844x390 (the phone, landscape).
- After adding a class_name file or an asset: `... perl -e 'alarm 900; exec @ARGV' /Applications/Godot_mono.app/Contents/MacOS/Godot --headless --path game --import > /tmp/gatherglide_import.log 2>&1`.
- Parse-check every new or edited .gd before a long run: `... --headless --path game --check-only --script res://<path>`.
- Never pipe Godot into tail/head/grep: read the log file afterwards. Never re-run a failed or hung command unchanged.
## Known traps
- `:=` cannot infer from max()/min()/ternaries/Variant returns: use maxf/maxi or an explicit type.
- Await coroutines. A `--script` test has no autoloads on its first frame: load() scripts on the first frame and add a 60 s
  quit watchdog, as game/tests/t_domain.gd does; print `[<test name>] PASS` or FAIL lines.
- game/tests/t_save.gd prints 5 deliberate SCRIPT ERRORs; that is normal.
- Write big files in parts (write_file, then edit_file); never python `s.replace()` without checking it matched.
## Gates
- Verify: `bash /private/tmp/claude-501/-Users-milankinzy-Documents-deadfront-siege/72cebc8b-d241-430b-9ea6-94d65339bfef/scratchpad/dsc/verify_job.sh gatherglide [1|2]` (no argument = the full gate). Read it and
  `/private/tmp/claude-501/-Users-milankinzy-Documents-deadfront-siege/72cebc8b-d241-430b-9ea6-94d65339bfef/scratchpad/dsc/job_gatherglide.conf` (TEST, LAB, LAB_ASSERT, RELATED, SCOPE) before you start.
- The lab gets `--shot-dir=<dir>`: save every PNG there. It must print exactly one line `[gatherglide] RESULT k=v k=v ...` with every
  key LAB_ASSERT reads, MEASURED from the live scene (never constants), then quit.
- Milestones: write them to .dsc/PLAN.md and call milestone_done after each (milestones before MS_STAGE2 run stage 1, later
  ones stage 2). Anything visual: open the PNG, and write the path and a one-line verdict in .dsc/NOTES.md before ticking.
## Constraints
- Your files are the SCOPE regex in the conf; touch nothing else. Edit shared files, do not rewrite them; keep existing asserts.
- Keep game/override.cfg. Never touch other worktrees, ~/Documents/deadfront, the owner's save, or the main checkout. Do not
  merge branches, push or deploy. No new dependencies.
- Do not tune balance numbers (HP, damage, XP, fatigue or energy rates). Owner: "game balancing like tuning hp and damage wont
  make sense until crafting building and skills is done and tuned". Mark every number the docs do not give `# ASSUMPTION`.
- Report docs/orchestration/reports/dsc-gatherglide.md: what shipped, before/after numbers, the shots you looked at, assumptions,
  what the integrator needs.
