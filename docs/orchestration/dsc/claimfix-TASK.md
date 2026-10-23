# Task: CLAIMFIX: CLAIM moves your land; build ghost under the HUD

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
1. CLAIM can be pressed again anywhere and it MOVES your 14x14 claim, dropping the old one (logged `claimed 14x14 at
   (13,23)`) - easy to do by accident and it loses the claimed land. Read docs/design/durango-prompts (domain/claim specs,
   18_domain_banner.md) and the PRD for what a second claim does (expand, move with a confirm, or refuse) and implement
   that; a move must never happen without an explicit confirm that names what is lost, and buildings inside the old claim
   must not be orphaned silently.
2. In the build placer the ghost first appears in the bottom-left corner under the HUD buttons, and the
   Rotate/Place/Cancel hexes overlap Menu/Animals/Build. Spawn the ghost in front of the survivor on valid ground inside
   the claim, and lay the placer hexes out clear of the other HUD controls at 1600x900 and 844x390 (64 px tap targets).

## Requirements
- Test `game/tests/t_claimfix.gd`: pressing CLAIM with an existing claim does not move it without the confirm; with the
  confirm the documented outcome happens; the placer ghost spawns within 6 m in front of the survivor; at 1600x900 and
  844x390 no placer hex rect intersects another visible HUD control. Prints `[t_claimfix] PASS`.
- Report docs/orchestration/reports/dsc-claimfix.md.

Verify command: `bash /private/tmp/claude-501/-Users-milankinzy-Documents-deadfront-siege/72cebc8b-d241-430b-9ea6-94d65339bfef/scratchpad/dsc/verify_claimfix.sh` (read it; it must exit 0).
