# Milestone M10 — skills, proficiency, skill points, occupations, character creation

The PRD already defines this (systems PRD §5.1, §7; `docs/design/skills.md`;
`game/data/skills/trees.json` with twelve trees and SP budgets). Durango's twelve skills:
Survival, Gathering, Butchering, Processing, Melee, Ranged, Defense, Weapon/Tools,
Tailoring, Construction, Cooking, Farming. Eight occupations start with proficiency 20 in
one tree: Soldier→Melee, Job seeker→Defense, Office worker→Construction, Technician→
Weapon/Tools, Flight attendant→Tailoring, Student→Gathering, Homemaker→Cooking,
Farmer→Farming (none start in Survival, Processing, Butchering or Ranged). What is
missing is the implementation. No autoloads, no `project.godot`, no `game/shell/`.

## Tasks

1. **Proficiency model.** `scripts/skills/skill_state.gd` (`SkillState`, owned by the
   player, saved in schema 3): per tree `level` (0–60, ≤ character level), `xp`, and the
   set of unlocked nodes; `sp_available`, `sp_spent`. XP sources (`# ASSUMPTION` rates):
   gathering +2 per unit (by node family: rocks also +1 Processing), butchering +3 per
   option taken, melee/ranged/defense from hits dealt/taken, construction +8 per
   placement, cooking/weapon_tools/tailoring +6 per craft in that recipe's tree
   (`recipes.json` gets a `tree` field), farming per plant/harvest, survival passively
   +1 per minute played and per new island. Level curve from `trees.json`
   (`sp_budget.per_level` bands); level-up grants SP per the budget and prints
   `[skill] gathering 21 (+12 SP)`; `World.pioneer_changed`-style signal `skill_changed`.
2. **Gates.** Gathering level = max material level without downrank (`rules.json`
   `gathering_downrank`, already specified): a Lv. 25 node gathered at Gathering 10 yields
   level-10 items. Construction level gates kits (`items.json` `min_skill`), Cooking
   gates recipes (M7), Melee/Defense scale damage dealt/taken by 1 % per level
   (`# ASSUMPTION`). Tree node effects from `trees.json` `nodes[].unlocks` apply where a
   system exists (island access tiers, recipe unlocks, bag size); log the rest as
   `[skill] node X has no effect yet`.
3. **Skills sheet.** Replace `SkillDebug` with a `SkillsSheet` opened by the SKILLS hex:
   twelve rows (icon glyph, name, `Lv. N`, XP bar, `SP n`), tap a row → its tree as a
   vertical list of nodes with cost, requirement level, state (locked / available /
   owned), tap to spend SP (confirm hex), refunds per `trees.json.refund`. All targets
   ≥ 56 px, one-handed on a phone.
4. **Character creation.** First launch (no save): a full-screen sheet with the eight
   occupations as cards (name, one-line story, starting skill `Lv. 20`), gender toggle
   (two survivor variants later; one model now), name field (default `Survivor`). Pick →
   `SkillState` seeded, `survivor.json` `display_name` overridden in the save, the
   level-up overlay (M8d Part C) shows `Title <occupation> acquired`. `--lab=` and
   `--smoke` skip it; a `--occupation=<id>` user arg preselects for tests.
5. **HUD hooks.** The XP bar along the bottom shows the **character** level (sum of tree
   levels / 4, `# ASSUMPTION`) and its progress; the top-left vitals keep working.
6. **Lab** `--lab=skills_lab` headless: seeds Office worker, prints
   `[skill] construction 20`, gathers 10 units → `[skill] gathering N (+SP)`, spends SP on a
   node → `[skill] unlocked <node>`, saves/loads → `[skill] restored 12 trees`.

## Acceptance
- Screenshots `m10-creation.png` (occupation cards), `m10-skills.png` (sheet), `m10-tree.png` (a tree).
- Headless skills_lab prints the lines above; `tools/smoke.sh` → `SMOKE PASS`.
- Report `docs/orchestration/reports/<agent>-M10-skills.md`; commit `M10: skills, SP, occupations, character creation`.
