# Task: SAVEFIX: autosave before character creation, max HP drift, energy drain

Context: DEADFRONT is a Godot 4.7.1 typed-GDScript dinosaur survival game (project `game/`), shipped as a web build
(https://durango-like.vercel.app). A production playtest on 2026-10-21 found the defects below (screenshots: /private/tmp/claude-501/-Users-milankinzy-Documents-deadfront-siege/72cebc8b-d241-430b-9ea6-94d65339bfef/scratchpad/shots/deploy-af03937f/).
Design truth: docs/design/durango-prompts/ and docs/prd/ - read the relevant parts before deciding behaviour; if the docs
are silent, pick the simplest thing and mark it `# ASSUMPTION:` in code. The owner wants the game shippable: fix the
gameplay, keep the change small and in the existing structure.

Process: reproduce each defect on the current code first and write the numbers in the report; write the test so it
FAILS on the current code and passes after the fix (say in the report that you ran it before the fix and what it printed).

## Constraints
- Godot only through `/private/tmp/claude-501/-Users-milankinzy-Documents-deadfront-siege/1899b1df-f06b-4b94-91be-9e3f3c22081d/scratchpad/gslot.sh` with its own timeout:
  `gslot.sh perl -e 'alarm 600; exec @ARGV' /Applications/Godot_mono.app/Contents/MacOS/Godot --headless --path game ...`
  (max 5 Godot runs machine-wide; never --editor). `--import` once after adding class_name files.
- Keep game/override.cfg. Never touch other folders under .claude/worktrees/, the owner's save, or ~/Documents/deadfront.
  Do not push, merge or deploy. Typed GDScript, no new dependencies. Save files: old saves must still load.

## Defects
1. Leaving the character-creation screen open ~60 s triggers an autosave (`[world] saved schema=3 island=home_grassland`)
   before any survivor exists; a reload then skips creation and the island pick and loads a default "Survivor" with no
   occupation. Fix: never autosave until creation and the first island pick have finished; a save written in that state
   (old saves that hit this bug) must load back into character creation.
2. Max HP changed with no visible cause (102/105, then 105/105, then 100/100 after drinking). Find every source that
   changes max HP (statuses like Quenched/Clean, levels, gear, food) and either show it (a status line) or remove the
   unintended change.
3. Energy drains fast while walking (TIRED within a few minutes, WEARY at ~67/103). Compare the drain and recovery rates
   with docs/design/durango-prompts/01_fatigue_and_exhaustion.md and the PRD (owner note in spec 25: "energy seems to
   always recover even in combat" in Durango). Fix rates that do not match the docs; do not invent rules.

## Requirements
- Test `game/tests/t_savefix.gd` covering all three (autosave timer during creation writes nothing; a pre-creation save
  loads into creation; max HP is unchanged by drinking/washing unless a shown status explains it; ten minutes of
  walking on flat ground at the docs' rates ends no worse than the docs say) and printing `[t_savefix] PASS`.
- Report docs/orchestration/reports/dsc-savefix.md with before/after numbers.

Verify command: `bash /private/tmp/claude-501/-Users-milankinzy-Documents-deadfront-siege/72cebc8b-d241-430b-9ea6-94d65339bfef/scratchpad/dsc/verify_savefix.sh` (read it; it must exit 0).
