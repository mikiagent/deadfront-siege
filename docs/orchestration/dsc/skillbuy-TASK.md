# Task: SKILLBUY: skill nodes cannot be bought

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

## Defect
In the Skills screen every node in every tree says "not in the game yet", so skill points pile up with nothing to buy
(SP 20 at Lv. 3; shot 11-desk-skilltree-notingame.jpg). W2-SKILLS built the Durango 1-60 trees (game/data/skills/ or
trees.json, game/scripts/.../skill_state.gd, skill_rules.gd, the skills sheet UI); read
docs/orchestration/reports/claude-mmo-w2-skills.md. Find why live nodes show as unavailable (data flag, effect wiring, a
filter) and make every node whose effect exists in the game buyable with the cost/requirements the data gives. Nodes whose
effect truly does not exist stay marked; wire the cheap ones now (stat bonuses, recipe/skill unlock gates, yield bonuses).

## Requirements
- Test `game/tests/t_skillbuy.gd`: a fresh survivor at character Lv. 3 with each occupation can buy at least one node in
  each tree it has levels in; buying spends SP, the node shows as learned in the sheet's data, and its effect is
  measurable (print it); it prints how many nodes are buyable vs "not in the game yet" per tree, e.g.
  `[t_skillbuy] PASS buyable=<n> unavailable=<n>`; it fails if unavailable is more than half of all nodes.
- Report docs/orchestration/reports/dsc-skillbuy.md.

Verify command: `bash /private/tmp/claude-501/-Users-milankinzy-Documents-deadfront-siege/72cebc8b-d241-430b-9ea6-94d65339bfef/scratchpad/dsc/verify_skillbuy.sh` (read it; it must exit 0).
