# Task: PETFOLLOW — tames follow within a radius, not on top of the player

Owner (verbatim, 2026-10-28): "tames should follow within a certain radius of the player, not directly on top of the
player". Code: game/scripts/creatures/brains/pet_brain.gd (follow/guard), game/scripts/player/player_pets.gd (summoned
pets, whistle SIC/HEEL/GUARD), creature.gd (path, face_towards with the new per-species turn rate). NATURES: Loyal
pets follow closer (keep that knob working, it scales the radii below).

Do (numbers in game/data/creatures/ai.json under a "follow" block, each `# ASSUMPTION`):
1. Each summoned pet gets a follow SLOT: an offset behind/beside the player, fanned so several pets take distinct
   slots (e.g. slots on an arc behind the player, by summon order), slot distance scaled by the pet's body size
   (big tames hang back further).
2. Hysteresis: the pet only moves when it is farther than an outer radius from its slot (~4-6 m scaled), and stops once
   inside an inner radius (~2-3 m scaled) — no constant shuffling while the player stands still.
3. Never path into the player's own capsule: keep a minimum clearance (player radius + pet radius + margin); if the
   player walks into a pet, the pet steps aside instead of stacking.
4. HEEL/GUARD/SIC keep working (guard radius, attack target) and riding is unaffected.
Milestones: M1 game/tests/t_petfollow.gd ("[t_petfollow] PASS"): with 3 summoned pets and a still player, after
settling every pet is between the inner and outer radius of its own slot, no two pets within (r1+r2) of each other,
none inside the player's clearance; walking the player 20 m, pets follow and settle again; a big pet's slot is farther
than a small one's; a Loyal pet's slot is closer; while the player stands still for 5 s pets do not move (no
shuffling). Fails on base. Stage 1. M2 implementation. M3 docs/current/creatures-capture-taming.md note + report
docs/orchestration/reports/dsc-petfollow.md + full verify. Headless only.

## How to run Godot (exactly)
- Headless test: `/private/tmp/claude-501/-Users-milankinzy-Documents-deadfront-siege/1899b1df-f06b-4b94-91be-9e3f3c22081d/scratchpad/gslot.sh perl -e 'alarm 400; exec @ARGV' /Applications/Godot_mono.app/Contents/MacOS/Godot --headless --path game --script res://tests/<t>.gd > /tmp/petfollow_t.log 2>&1` (bash timeout_ms 460000).
- After adding a class_name file or an asset: `... perl -e 'alarm 900; exec @ARGV' /Applications/Godot_mono.app/Contents/MacOS/Godot --headless --path game --import > /tmp/petfollow_import.log 2>&1`.
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
- Scratch files go in $TMPDIR/petfollow, never /tmp or docs/. Never `rm -r` a path that has tracked files.
- Key any per-item data by a stable id (file name, src_rect), never by list order.
- Write big files in parts (write_file, then edit_file); never python `s.replace()` without checking it matched.
## Gates
- Verify: `bash /private/tmp/claude-501/-Users-milankinzy-Documents-deadfront-gate/a2917b6d-2049-454d-9c63-314953df33d7/scratchpad/dsc/verify_job.sh petfollow [1|2]` (no argument = the full gate). Read it and
  `/private/tmp/claude-501/-Users-milankinzy-Documents-deadfront-gate/a2917b6d-2049-454d-9c63-314953df33d7/scratchpad/dsc/job_petfollow.conf` (TEST, LAB, LAB_ASSERT, RELATED, SCOPE) before you start.
- The lab gets `--shot-dir=<dir>`: save every PNG there. It must print exactly one line `[petfollow] RESULT k=v k=v ...` with every
  key LAB_ASSERT reads, MEASURED from the live scene (never constants), then quit.
- Milestones: write them to .dsc/PLAN.md and call milestone_done after each (milestones before MS_STAGE2 run stage 1, later
  ones stage 2). Anything visual: open the PNG, and write the path and a one-line verdict in .dsc/NOTES.md before ticking.
## Constraints
- Your files are the SCOPE regex in the conf; touch nothing else. Edit shared files, do not rewrite them; keep existing asserts.
- Keep game/override.cfg. Never touch other worktrees, ~/Documents/deadfront, the owner's save, or the main checkout. Do not
  merge branches, push or deploy. No new dependencies.
- Do not tune balance numbers (HP, damage, XP, fatigue or energy rates). Owner: "game balancing like tuning hp and damage wont
  make sense until crafting building and skills is done and tuned". Mark every number the docs do not give `# ASSUMPTION`.
- Report docs/orchestration/reports/dsc-petfollow.md: what shipped, before/after numbers, the shots you looked at, assumptions,
  what the integrator needs.
