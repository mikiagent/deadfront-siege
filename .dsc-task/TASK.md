# Task: NATURES — creature natures that change behaviour, shown in the name

Owner (2026-10-28): Durango had named animal variants (Timid Raptor, Raptor, Alpha Raptor), per-animal stats (health,
attack, defense, move speed, carrying capacity), wild behaviours (aggro, attack, flee/disengage, sleep) and tamed
companions for combat, riding and storage. The owner wants a Pokémon-like Nature system where a creature's nature
changes its AI BEHAVIOUR, not just its stats:
| Nature | Effect (owner's words) |
|---|---|
| Timid | Avoids combat, more likely to flee |
| Brave | Protects its rider even when wounded |
| Aggressive | Attacks nearby threats without orders |
| Loyal | Stays close and prioritizes protecting its owner |
| Stubborn | Harder to tame, resistant to fear |
| Docile | Easier to tame, less effective in combat |

Read first: docs/current/creatures-capture-taming.md, game/data/creatures/ai.json (archetypes + `temperaments`
skittish/defensive/territorial — natures LAYER ON TOP of these; do not replace them), game/scripts/creatures/brains/
creature_brain.gd (how temperament/flee/retreat/aggro/leash are read), pet_brain.gd (guard radius, drop target),
game/scripts/pets/pet_record.gd, field_tame.gd, capture_system.gd, creature.gd.

Do (data-driven, behaviour only; do NOT change species identity, art, models or animations; do not retune any
existing number — natures are multipliers/offsets around today's values, each `# ASSUMPTION` in natures.json "_about"):
1. game/data/creatures/natures.json: the six natures, each a small set of knobs the brains already read, e.g.
   flee_threshold_mult / retreat_threshold_mult (Timid up, Brave down), aggro_radius_mult and auto_engage (Aggressive),
   pet guard/follow distance and owner-protect priority (Loyal), tame feeds_needed / tame window / fear immunity
   (Stubborn harder + fear-resistant, Docile easier), damage_dealt_mult (Docile < 1), protect_rider_below_hp (Brave keeps
   fighting for its rider when wounded). Plus spawn weights per nature (Docile/Timid common, others rarer) and which
   archetypes may roll which natures (a T. rex is never Timid; herbivore grazers rarely Aggressive) — # ASSUMPTION.
2. Every creature gets a nature at spawn (seeded, deterministic from its spawn seed) and keeps it when tamed (PetRecord
   gains `nature`). Wild AI and pet AI read the knobs at the existing decision points — one place per knob, no second
   brain.
3. Name: the nature shows as a prefix on the creature's displayed name/plate ("Timid Velociraptor"); keep "Alpha"
   style variants working if they exist (check `variants` in creature_def.gd and the raptor pack alpha) — e.g.
   "Brave Alpha Raptor" ordering: nature, then variant, then species.
4. Taming: Stubborn/Docile change feeds_needed / window via the existing FieldTame/pen code; capture09's rule
   (stunned at any HP or <= 30 %) is NOT changed.
5. Saves: PetRecord.nature is an additive optional field. Old saves load with no loss: a pet without `nature` gets a
   deterministic nature from its uid. Fixture test with an old pet record. Server character store (srvdom) round-trips
   it too.
6. docs/current/creatures-capture-taming.md: a short "Natures" section (facts + code paths).

Milestones (.dsc/PLAN.md; milestone_done after each):
M1 game/tests/t_natures.gd (t_domain.gd structure; load() on first frame; watchdog; prints "[t_natures] PASS"):
   per nature, a measured behaviour difference on the brain's decision (Timid flees at higher HP than default; Brave
   pet keeps fighting below the default retreat when its owner is riding; Aggressive engages a target inside its radius
   unprovoked where default does not; Loyal pet's follow distance < default; Stubborn needs more feeds and ignores
   fear; Docile needs fewer feeds and deals less damage), deterministic roll from seed, name prefix, old-save load.
   Fails on base. Stage 1.
M2 natures.json + spawn roll + PetRecord field + save migration. Stage 1.
M3 wild + pet AI hooks + taming hooks + name prefix. Stage 1.
M4 docs + report docs/orchestration/reports/dsc-natures.md + full verify.
Headless only: the owner reserved the machine — no windowed labs or screenshots.

## How to run Godot (exactly)
- Headless test: `/private/tmp/claude-501/-Users-milankinzy-Documents-deadfront-siege/1899b1df-f06b-4b94-91be-9e3f3c22081d/scratchpad/gslot.sh perl -e 'alarm 400; exec @ARGV' /Applications/Godot_mono.app/Contents/MacOS/Godot --headless --path game --script res://tests/<t>.gd > /tmp/natures_t.log 2>&1` (bash timeout_ms 460000).
- After adding a class_name file or an asset: `... perl -e 'alarm 900; exec @ARGV' /Applications/Godot_mono.app/Contents/MacOS/Godot --headless --path game --import > /tmp/natures_import.log 2>&1`.
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
- Scratch files go in $TMPDIR/natures, never /tmp or docs/. Never `rm -r` a path that has tracked files.
- Key any per-item data by a stable id (file name, src_rect), never by list order.
- Write big files in parts (write_file, then edit_file); never python `s.replace()` without checking it matched.
## Gates
- Verify: `bash /private/tmp/claude-501/-Users-milankinzy-Documents-deadfront-gate/a2917b6d-2049-454d-9c63-314953df33d7/scratchpad/dsc/verify_job.sh natures [1|2]` (no argument = the full gate). Read it and
  `/private/tmp/claude-501/-Users-milankinzy-Documents-deadfront-gate/a2917b6d-2049-454d-9c63-314953df33d7/scratchpad/dsc/job_natures.conf` (TEST, LAB, LAB_ASSERT, RELATED, SCOPE) before you start.
- The lab gets `--shot-dir=<dir>`: save every PNG there. It must print exactly one line `[natures] RESULT k=v k=v ...` with every
  key LAB_ASSERT reads, MEASURED from the live scene (never constants), then quit.
- Milestones: write them to .dsc/PLAN.md and call milestone_done after each (milestones before MS_STAGE2 run stage 1, later
  ones stage 2). Anything visual: open the PNG, and write the path and a one-line verdict in .dsc/NOTES.md before ticking.
## Constraints
- Your files are the SCOPE regex in the conf; touch nothing else. Edit shared files, do not rewrite them; keep existing asserts.
- Keep game/override.cfg. Never touch other worktrees, ~/Documents/deadfront, the owner's save, or the main checkout. Do not
  merge branches, push or deploy. No new dependencies.
- Do not tune balance numbers (HP, damage, XP, fatigue or energy rates). Owner: "game balancing like tuning hp and damage wont
  make sense until crafting building and skills is done and tuned". Mark every number the docs do not give `# ASSUMPTION`.
- Report docs/orchestration/reports/dsc-natures.md: what shipped, before/after numbers, the shots you looked at, assumptions,
  what the integrator needs.
