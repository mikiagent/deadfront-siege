# DEADFRONT MMO program prompt (2026-10-20)

Paste into a new Claude Code session in ~/Documents/deadfront.

```text
Continue DEADFRONT, my dinosaur survival MMO, in ~/Documents/deadfront (Godot 4.7.1, typed GDScript, branch claude/mmo-overhaul). Goal: an ARK: Survival Ascended-quality open-world survival MMO with Durango: Wild Lands-depth systems: real taming, breeding, combat, survival, building, crafting, a persistent server-authoritative world and a real player economy (fixed-price Island Market, auctions, buy orders, dinosaurs traded as caged items with their stats and genetics). Nothing fake: every transaction moves real items, currency and ownership.

READ FIRST, IN ORDER
1. docs/orchestration/mmo/HANDOFF.md: what is merged, what is half done on which branch, the backlog.
2. GAUNTLET.md: the loop every change goes through, product rules, and how to use DeepSeek workers.
3. docs/orchestration/mmo/STATUS.md "Owner decisions" (newest wins) and docs/design/durango-prompts/01-12 (binding design input; do not invent canon; mark gaps # ASSUMPTION).

QUALITY BAR
- ARK for visual fidelity (models, animation, lighting, terrain, water). Durango for UI, information hierarchy and system depth.
- Judge on real pixels: desktop Chrome 1600x900 on the web renderer (gl_compatibility) and phone LANDSCAPE 844x390. Logs are not visual evidence.
- "Works" is not done. Done = acceptance gates pass, an independent reviewer passes it, a blind A/B judge prefers it for anything visual, it is merged with all tests green, and (when I allow deploys) a tester sees it on production.

PRIORITY ORDER (unless I say otherwise)
1. Merge the built packages in the HANDOFF merge order: items/recipes ladder (hooks + review) -> skill trees (fix the save-test review issue) -> non-stacking inventory (I approved the save change: merge once its review passes and old saves migrate cleanly in tests) -> processing stations (fix packing up a station destroying its contents first) -> gathering and loot (review) -> modular building (review) -> market engine (finish and test the fix so a player cannot send their own deposit call). Ragdolls and item icons: finish their few fixes alongside.
2. The core loop end to end: gather -> process -> craft -> build, with a rare-item economy and recipe-gated progression (specs 03-05, 08, 10-12).
3. The market over the real server (Island Market, auctions, buy orders, caged pets), then the server-simulated world.
4. Art: Tripo creatures from concept sheets I approve, rigged and animated to the verifier gates.
Production runs 31c064a08/2284b9bf56; deploy the merged state only when I say.

HOW TO WORK
- One package per branch (claude/mmo-<key>) with an owned-files list; shared files get hooks, not edits.
- Every package: build -> independent reviewer who did not write it (reruns every check, takes its own screenshots, tries to break it) -> fix -> blind A/B judge for visual work -> ONE serialized integrator merges, reruns all gates and screenshots, then pushes to GitHub.
- Keep STATUS.md current: owner decisions, merge log, blockers.
- Workers: Claude agents design, review and integrate. DeepSeek (dsc) workers take narrow, gated mechanical jobs per GAUNTLET.md "DeepSeek workers"; after each job log the outcome and a DeepseekCLI improvement prompt in docs/orchestration/dsc-improvements.md. Codex (model gpt-reserve; my usage is limited) only for focused one-bug debugging.
- Limits: usage caps will cut runs, so commit WIP often and restart packages from their real state (do not resume parallel workflows blindly). At most 5 Godot runs at once, each with a timeout. Re-import after merging assets. Never message a running workflow agent.
- Tests are silent and use a git-excluded game/override.cfg; never touch my real save.

MY GATES (ask me, one focused question at a time)
- Concept sheets and new species (batch approval is fine). Credits: existing Meshy/Tripo balances only, never buy. Tripo for creatures and characters; headless Blender for buildings and props.
- Deploys only when I say. Merging into main only when I say. The server stays local until I pick a host.
- Anything that changes saves, money, multiplayer authority, species identity or a major visual direction.

REPORT
Blunt and short: what changed, gates with their output lines, screenshots you looked at, review and judge verdicts, commit and PR, production link and stamp if deployed, remaining risk. Never claim a test, screenshot or comparison you did not actually run.

Run this as a self-paced /loop: each iteration reads STATUS.md, advances the top priority, and stops when everything is blocked on me.
```
