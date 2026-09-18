# Claude M10 — skills, proficiency, SP, occupations, character creation

PRD §5.1 and §7, `docs/design/skills.md`, `game/data/skills/trees.json` (twelve trees, SP budget).

## What shipped
- `scripts/skills/skill_state.gd` (`SkillState`, child "Skills" of the player): per tree `level` (0–60), `xp`, unlocked nodes; `sp_available` / `sp_spent`; `add_xp` levels up with SP from `trees.json.sp_budget` (10/12/14/16 by band) and prints `[skill] <tree> N (+SP)`; `unlock` / `refund` with cost, level and prerequisite checks (`[skill] unlocked …`); survival nodes also flip `Data.survival_unlocked`; `apply_occupation` seeds Lv. 20 from `data/skills/occupations.json` (8 occupations = PRD table); `character_level()` = sum of tree levels / 4 (`# ASSUMPTION`); `to_dict` / `from_dict` (`[skill] restored 12 trees`). XP curve `# ASSUMPTION`: 20 + 8·level per level.
- **XP sources**: gathering +2 per unit (+1 processing on rocks/clay), butchering +3 per loot stack, melee +2 per hit and damage ×(1 + 1 %/level), defense +1 per hit taken, construction +8 per placement, crafts +6 in the tree derived from the output's category (`Crafting.tree_for_recipe`: food→cooking, tool/weapon→weapon_tools, clothing/bag→tailoring, building→construction, else processing), survival +1 per minute and +5 per island change.
- **Gate**: gathering downrank (`rules.json`): material level capped at the Gathering level, floor 5 (`# ASSUMPTION`).
- **Skills sheet** (`scripts/ui/skills_sheet.gd`, opened by the SKILLS hex): twelve rows with glyph, level, XP bar, owned count; tap → tree page listing nodes with cost, level, unlock text and state (Unlock / Refund / reason). Tap outside closes.
- **Character creation** (`scripts/ui/character_creation.gd`): on a new game (`World.start_new`, or `--new-game`): eight occupation cards, body toggle, name field, Start; then the home island + terrain pick. `--occupation=<id>` preselects and starts (tests). Name and occupation saved (`player_name`, `occupation`); the HUD name and the XP bar use them (`Lv.` = character level).
- Save: `skills_v2` in the payload; loads after the inventory.
- Lab `--lab=skills_lab` (headless): office worker → `[skill] construction 20`, ten gathers → `[skill] gathering 1 (+10 SP)`, `[skill] unlocked forage_1 (gathering, 5 SP)`, round trip `[skill] restored 12 trees` + `roundtrip construction=20 gathering=1 owned=["forage_1"] sp=5`, `[skill] character level 5`.

## Evidence
- `docs/orchestration/reports/m10-creation.png`, `m10-skills.png`, `m10-tree.png`; `--new-game --occupation=student` prints `[skill] gathering 20 (occupation student)` and `[world] new survivor Survivor (student, f)`.
- `tools/smoke.sh` → `SMOKE PASS`.

## Not yet
- Skill level ≤ character level cap, Construction `min_skill` on kits, Cooking recipe gates (M7), farming XP (no farming yet), defense damage scaling, node effects beyond survival (logged as text only), refund day limits, a second survivor body.
