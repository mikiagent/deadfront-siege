# Codex codebase status audit, 2026-09-23

## What shipped

- Read the plan, recent milestone reports, current scripts and data, and Git state. This was an audit; no gameplay code or assets changed.
- Ran `tools/smoke.sh`: `SMOKE PASS` on Godot 4.7.1.
- Ran `tools/test.sh`: `[tests] PASS`. The `Save schema 4 is newer than this build (3)` log comes from the intentional future-schema rejection test in `game/tests/run_all.gd`.
- Ran headless `build_lab`: placed a tent, basket, three fences and a gate; rejected overlap and an unclaimed cell; restored six buildings after save/load.

## Status and gaps

- The original `docs/orchestration/plan.md` stops at earlier milestones. The code has since shipped private island travel/save, cooking/farming, 12 skill trees, context UI, creature interactions, a 12-step objective ladder and a 15-rung session bot. Keep the plan aligned with the shipped state before assigning more milestone IDs.
- Latest bot report reached 12/15 rungs. Its windowed run found the placement ghost invalid at five spots despite claimed ground. The direct-cell build lab passing does not cover this pointer/ghost path. No subsequent commit appears to fix that path. Reproduce in a windowed run, then add a focused regression check.
- `game/scripts/world/build_placer.gd` has no `_kit_id`, `_spawn` or `_pay` cases for `field_small`, `field_large`, `mortar`, `stone_grill`, `steamer` or `well`. Kits and stations exist in data/code, so players cannot place them through this flow. Check payment order when adding cases so a failed spawn cannot consume a kit.
- `SkillState.unlock()` affects survival data for capture; other unlocked node IDs are not read by gameplay. Recipe and building gates and node effects still need wiring. `Crafting.skill_level_for()` treats level 0 as level 60, a temporary soft unlock.
- `game/data/world/missions.json`, `factions.json` and `market.json` exist, but `Data._load_world()` loads only rules, climates, islands, props and the objective ladder. Those larger systems remain data drafts.
- Creature data has 19 species definitions and 10 top-level GLBs. `CreatureView` explicitly forces Stegosaurus to a procedural placeholder because of broken mesh weights. Other unmeshed species use placeholders. Art acceptance remains open.
- `game/data/world/climates.json` lists flint, obsidian, copper ore and black iron, but current harvest families do not emit those item IDs. The bot report says the material ladder stalls at bone. Verify each material's source and recipe before relying on those climate lists as playable content.
- The checked-in pack manifest is `20260921.2350-49b723c`, older than HEAD `f1aeabf` from 2026-09-22. A TestFlight upload and web deployment are documented, but this audit did not check the remote services or a physical phone. Device performance and touch acceptance remain unmeasured here.
- The working tree already contained two modified art files and roughly 700 untracked files, chiefly `game/addons/`, `game/demo/`, `artifacts/` and `research/`. Do not sweep these into a release without reviewing ownership and intent.

## What failed

- No gate failed in this audit. Windowed placement, phone performance, remote deployment and a full bot session were not run, so their current status is based on code and prior reports.

## Credits spent

- Meshy: 0.

## What the next agent needs

1. Reproduce and fix the player-facing placement ghost, then wire the six missing kit kinds and verify the full craft-to-place-to-save loop.
2. Give skill purchases real effects and gates, starting with construction and cooking, then rerun the full session bot.
3. Decide which untracked plugin/demo/research files belong in the project. Update the orchestration plan and release manifest after gameplay fixes are accepted.
4. Validate on a physical iPhone, including touch reach, frame rate, draw calls and memory. Then schedule remaining world systems and creature art against the PRD.
