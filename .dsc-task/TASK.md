# Task: UITOKENS — UI redesign package 1: tokens, HexButton extensions, shared chrome helpers

Source: docs/design/ui-redesign-spec.md §2, §3 and §8 (read all of it once; build ONLY §2/§3/§8 helpers here).
Later packages (gather pie, field HUD, build row, sheets, world screens) will USE what you add; do not restyle any
screen in this package and do not change how any existing screen looks — every addition is opt-in.

Do:
1. game/scripts/ui/ui_tokens.gd: add the §2 palette constants and trait-chip / MOOD constants exactly as the spec
   lists them, keeping every existing constant. Add the helpers: hex_points(center, r, flat_top),
   hex_radius_at(a, r, flat_top) (the spec's formula), a pie-sector polygon helper (centre + boundary from -90° clockwise
   to -90°+360°·f, sampled every <= 6° and at every hex vertex the sweep passes), trait_chip_style(polarity) for
   &"negative"/&"positive"/&"rare" (0 radius, 3x8 px padding; colour-blind prefix − + ✦ available as a helper),
   draw_brackets(ci, rect, color := GOLD, arm := 18.0, w := 3.0), header_style() and a torn-edge draw (zig-zag 0-12 px).
   A global `HEX_FLAT_TOP := false` (# ASSUMPTION: pointy-top until the owner picks the orientation).
2. game/scripts/ui/hex_button.gd: add flat_top (defaults to UiTokens.HEX_FLAT_TOP), rim_color/rim_width (defaults keep
   today's look exactly — measure today's rim and make the default reproduce it), fill_ratio (pie fill, separate from
   the cooldown sweep), icon_grey, key_hint (hidden on phone). _hex() uses UiTokens.hex_points. Draw order per §3.
   Existing call sites must render identically with defaults.
Milestones (.dsc/PLAN.md; milestone_done each):
M1 game/tests/t_uitokens.gd ("[t_uitokens] PASS"): hex_points gives 6 points at radius r for both orientations;
   hex_radius_at equals r at vertices and apothem at edge midpoints; pie polygon area grows monotonically with f and
   equals the hex area at f=1 (within 1 %); trait_chip_style returns the three distinct bg colours; a HexButton with
   default fields produces the same polygon as before the change (compare against the old _hex() maths); fill_ratio
   and icon_grey change only what they should; key_hint hidden when is_phone. Stage 1.
M2 tokens + helpers. M3 HexButton fields. M4 docs (ui-screens.md / hud.md: one short "tokens available" note, facts
only) + report docs/orchestration/reports/dsc-uitokens.md + full verify. Headless only (owner reserved the machine).

## How to run Godot (exactly)
- Headless test: `/private/tmp/claude-501/-Users-milankinzy-Documents-deadfront-siege/1899b1df-f06b-4b94-91be-9e3f3c22081d/scratchpad/gslot.sh perl -e 'alarm 400; exec @ARGV' /Applications/Godot_mono.app/Contents/MacOS/Godot --headless --path game --script res://tests/<t>.gd > /tmp/uitokens_t.log 2>&1` (bash timeout_ms 460000).
- After adding a class_name file or an asset: `... perl -e 'alarm 900; exec @ARGV' /Applications/Godot_mono.app/Contents/MacOS/Godot --headless --path game --import > /tmp/uitokens_import.log 2>&1`.
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
- Scratch files go in $TMPDIR/uitokens, never /tmp or docs/. Never `rm -r` a path that has tracked files.
- Key any per-item data by a stable id (file name, src_rect), never by list order.
- Write big files in parts (write_file, then edit_file); never python `s.replace()` without checking it matched.
## Gates
- Verify: `bash /private/tmp/claude-501/-Users-milankinzy-Documents-deadfront-gate/a2917b6d-2049-454d-9c63-314953df33d7/scratchpad/dsc/verify_job.sh uitokens [1|2]` (no argument = the full gate). Read it and
  `/private/tmp/claude-501/-Users-milankinzy-Documents-deadfront-gate/a2917b6d-2049-454d-9c63-314953df33d7/scratchpad/dsc/job_uitokens.conf` (TEST, LAB, LAB_ASSERT, RELATED, SCOPE) before you start.
- The lab gets `--shot-dir=<dir>`: save every PNG there. It must print exactly one line `[uitokens] RESULT k=v k=v ...` with every
  key LAB_ASSERT reads, MEASURED from the live scene (never constants), then quit.
- Milestones: write them to .dsc/PLAN.md and call milestone_done after each (milestones before MS_STAGE2 run stage 1, later
  ones stage 2). Anything visual: open the PNG, and write the path and a one-line verdict in .dsc/NOTES.md before ticking.
## Constraints
- Your files are the SCOPE regex in the conf; touch nothing else. Edit shared files, do not rewrite them; keep existing asserts.
- Keep game/override.cfg. Never touch other worktrees, ~/Documents/deadfront, the owner's save, or the main checkout. Do not
  merge branches, push or deploy. No new dependencies.
- Do not tune balance numbers (HP, damage, XP, fatigue or energy rates). Owner: "game balancing like tuning hp and damage wont
  make sense until crafting building and skills is done and tuned". Mark every number the docs do not give `# ASSUMPTION`.
- Report docs/orchestration/reports/dsc-uitokens.md: what shipped, before/after numbers, the shots you looked at, assumptions,
  what the integrator needs.
