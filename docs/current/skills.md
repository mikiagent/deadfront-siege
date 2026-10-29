# Skills — current implementation

Updated 2026-10-28 by the skilltrees job (dsc). See `game/data/skills/trees.json` for the data and
`game/tests/t_skilltrees.gd` for the checks.

## Tree levels

A tree goes from level n to n+1 at `SkillState.xp_to_next(n)` = (20 + 8 n) x `skill_xp_cost_mult` XP
(2.5 in `game/data/progression.json`, owner 2026-10-28 "levels up slower"): Lv 1->2 costs 70. A tree
never passes the character level (`SkillState.level_cap`); XP past it is banked.

Research (owner 2026-10-28): every tree but Survival stops at a full bar ("Research ready" on the
card and in the detail). The player presses **Start Research** on the Skills sheet; the level arrives
when the real-time countdown ends (`SkillState.start_research` / `poll_research`, `research` saved with
an absolute unix end, so it runs while the game is closed). One research at a time. Duration
`SkillState.research_s(n)` = min(72 h, 60 s x g^(n-1)), g so 49->50 = 48 h (`progression.json
skill_research`). Instant Completion and Decrease Research Time are disabled stubs. XP past a full bar
keeps banking. The server mirror (`CharacterState.add_xp`) banks gated trees and never levels them.
Tests `t_research`.

Opening the sheet sweeps the gold level track (`SkillsLevelTrack`) to the tree's level in 0.8 s,
flashing each node that can be unlocked as the track passes it and counting the free skill points
up; a reopen within 4 s skips it (`SkillsSheet.tick_sweep`, test `t_skillfeel._test_sweep`). A node
that can be unlocked shows a gold ▲; a node's recipes are listed as "Craft: ..."; a learned node's
button reads **Unlearn** (full SP refund, `SkillState.refund`).

Worn gear can raise a skill: `ItemDef.skill_bonus` {tree: levels}, read through
`SkillRules.effective_level` (butchering cut budget and part rolls use it). Worked example:
Tailoring's Spiky Armor (Lv. 30, 4 SP) unlocks Spiky Armor and its helmet, +5 Butchering each
(test `t_skillgear`).

## What a node's marks mean

Every node in the twelve playable trees carries two fields alongside its `status`:

- `impl` — honest implementation state, judged by grepping the code:
  - `functional` — a code path reads the node's effect today.
  - `partial` — some of its effect is wired (e.g. the ability total exists but no consumer).
  - `defined` — data only; nothing reads it yet.
- `impl_ref` — for functional and partial nodes, `script:line` of the first code path that reads
  the effect (e.g. `game/scripts/skills/skill_rules.gd:157` for the butcher gates).

The old `status` field keeps its meaning (spec-12 provenance wording); `impl` is the job-verifiable
truth. `t_skilltrees.gd` enforces that every functional node's `impl_ref` names an existing script
containing the node id or its effect token (recipe id, item id, or effect type), so a functional
mark cannot drift into decoration.

## Coverage numbers (2026-10-28)

ONEGATHER (owner 2026-10-28, one per harvest): no node raises the **count** of a gather or a cut any
more. Butchering `yield_1` / `yield_2` now read "+20% / +40% cut speed (still one part per cut)";
`yield_1` dropped from functional to defined (cut speed comes from the Butchering level today, the node
adds no bonus of its own yet). Gathering `great_success_1` / `_2` read "a finer material, never extra
units" and stay defined.

The 213 previously imported playable nodes: **35 functional, 19 partial, 159 defined.**

| Tree | Playable | Functional | Partial | Defined |
|---|---:|---:|---:|---:|
| Survival | 27 | 10 | 5 | 12 |
| Gathering | 21 | 8 | 0 | 13 |
| Butchering | 22 | 5 | 5 | 12 |
| Processing | 38 | 4 | 9 | 25 |
| Melee | 10 | 0 | 0 | 10 |
| Ranged | 13 | 0 | 0 | 13 |
| Defense | 12 | 3 | 0 | 9 |
| Weapon / Tools | 22 | 1 | 0 | 21 |
| Tailoring | 15 | 2 | 0 | 13 |
| Construction | 12 | 0 | 0 | 12 |
| Cooking | 11 | 0 | 0 | 11 |
| Farming | 10 | 2 | 0 | 8 |

Spec 12's full 918-node roster is imported as a per-tree `catalog` array in trees.json (not
playable nodes), matching the spec's per-category counts: survival 45, melee 116, ranged 51,
defense 31, butchering 29, gathering 78, cooking 96, weapon_tools 126, tailoring 98, construction
129, farming 57, processing 44 — every catalog row carries `impl` (defined except where a real
node exists). The 13th category, **toxic oil island survival**, is a separate optional pack with 18
zero-SP rows (13 named from the reference: Moss Hut, Wooden Harpoon, Vine Work Outfit, Vine Work
Hat, Work Tools, Cooking Bonfire, Insect Gruel, Makeshift Bow, Fog Shelter, Recycled Gloves,
Recycled Work Outfit, Recycled Boots, Recycled Gas Mask). It stays outside `SkillState.ORDER` so
the runtime twelve-tree system is untouched until a toxic-oil biome exists (ASSUMPTION).

## In the Skills sheet

Each node row's detail shows one small honesty line: **"Not active yet"** for `defined` nodes and
**"Partly active"** for `partial` nodes (functional nodes need no line). This is the only UI change.

## SP economy note

Only nodes the game actually reads are buyable (`SkillRules.buyable`, spec 12:215); 103 of 213
playable nodes are buyable at character Lv. 3+ with an occupation, 92 stay locked as "not in the
game yet". Catalog rows do not participate in SP, saves, or the sheet's node list.
