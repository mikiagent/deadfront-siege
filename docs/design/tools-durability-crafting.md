# Tools, durability and crafting: what we keep, adopt and skip

**Status:** PROPOSED, 2026-10-30. No code changes yet. Every number marked `# ASSUMPTION` is a default the build
can ship with and the owner can retune; each one is logged in
`docs/vision/WildLandsMMO_Open_Questions.md` § TOOLSDOC.

**Input:** `docs/reference/durango-wildlands-durability-tools-crafting-research.md` (Milan's upload, 2026-10-30). It is
historical research about Durango: Wild Lands, mostly player tests and archived community tables. It is reference
data, not canon. Where it disagrees with our own design sources, ours win:

- `docs/vision/WildLandsMMO_Game_Vision.md`, `WildLandsMMO_Crafting_Building_Math.md`,
  `WildLandsMMO_Traits_Gathering_Processing_Math.md` (the vision set)
- `docs/design/durango-prompts/04`, `11`, `12` (owner specs for materials, processing and skill trees)
- `docs/design/weapons.md`, `docs/design/skills.md`

The `docs/prd/` folder named in AGENTS.md does not exist on `claude/mmo-overhaul`; the vision set and the
durango-prompts are the design sources on this branch.

**Build checked:** `origin/claude/mmo-overhaul` at `d1f710b3` (after KNIFESPLIT `a431ba31`).

---

## 1. Summary

| Research point | Today | Decision |
|---|---|---|
| Use-based wear only, no idle decay | Done for tools and weapons | Keep. Add armor wear (P1). |
| Work-tool families vs combat weapon families | Done (KNIFESPLIT, `is_work_tool`) | Keep. Recipe gates accept work tools only (P2). |
| Auto-pick the work tool from the bag, weapon stays equipped | Done (`Inventory._best_tool`) | Keep. Reuse it for recipe tools (P2). |
| Recipes gated by tool type, tool level, workstation | Workstation yes, tool no (`requires_tool` is unread data) | Adopt tool class + minimum tier gates and craft wear (P2). |
| Repair restores current, cuts max ~20 % per repair | No item repair (`recipes.json repairs` is unread data) | Adopt station repair, max x0.8 per repair, 4 repairs (P3). |
| Material traits carry into gear | Traits copy onto the gear but change no stat | Adopt durability, damage, armor and gather-power effects (P4). |
| Gather wear scales with resource level vs tool | Flat 1 per gather | Adopt a level-gap multiplier (P1). |
| Resource level needs a minimum tool level | Per-material pick tier gate exists | Skip level gates; keep tier gates. |
| Repair kits with capacity tiers | None | Skip; a carried `workbench_kit` is the field repair station. |
| New tool classes (hammer, saw, needle, shovel, harpoon) | knife, axe, pick, hoe only | Skip for now; open question. |

Four packages follow in §4: **P1 WEAR**, **P2 RECIPETOOLS**, **P3 GEARREPAIR**, **P4 TRAITGEAR**.

---

## 2. What the build does today

File references are on `claude/mmo-overhaul` at `d1f710b3`.

**Durability fields.** `ItemStack.durability` and `max_durability` (`game/scripts/items/item_stack.gd:12-13`).
`apply_level_stats()` sets max from `items.json max_durability x stat_multiplier(level, material_tier)` when the item
is made (`item_stack.gd:42-48`), so a higher level or a better material tier already means a longer life
(`ProgressionScaling.TIER_POWER`, stone 1.0 to steel 2.45). `is_broken()` is `durability <= 0`. Nothing decays
over time: wear only happens in the call sites below.

**Tools in data** (`game/data/items.json`): `tool_class` knife / axe / pick / hoe, `is_work_tool`, `max_durability`.
Work tools: `stone_knife_work` (Work Knife, 120), `work_axe` and `work_pick` (50), `hoe` (60), the bone-to-steel
knives / axes / picks (40 / 50 / 50). Combat weapons with a tool class: `stone_knife` (Stone Dagger, knife, not a
work tool, 80), `barbed_knife` (knife, 160). Swords, spears, club, bone hammer, slingshot: weapons with no tool class.
Armor and clothing carry 150-400 durability.

**Auto-pick.** `Inventory.find_gather_tool(class)` (`game/scripts/items/inventory.gd:235`) returns the held tool when
it is a work tool of that class, else `_best_tool(class)` (`inventory.gd:285`): work tools before weapons, then the
highest `gather_power()`, from the whole bag plus the worn weapon. The weapon stays equipped. KNIFESPLIT: a Stone
Dagger only cuts when no work knife is carried.

**Combat weapon choice.** `Inventory.equipped_weapon()` (`inventory.gd:532`): the worn weapon, else a bag weapon that
is not a work tool, else a work-tool weapon (an axe), else fists. A work tool fights at `work_tool_mult` 0.45 damage
(`game/data/combat_tuning.json`, `hunt.gd:259`).

**Wear call sites.**
- Gathering: `Inventory.wear_tool()` (`inventory.gd:266`) costs 1 for a work tool and 3 for a weapon used as a tool,
  flat (`# ASSUMPTION` in code). Called from `PlayerActions` (`player_actions.gd:155`, `:428`), the gather intent
  (`server/intent_handlers.gd:114`), helper tools (`GatherService.wear_role_tool`, `gather_service.gd:93`),
  butchering cuts (`corpse.gd:138`, `:381`, `:413`) and tribe harvests (`tribe_member.gd:429`).
- Combat: `Hunt.wear_weapon()` (`combat/hunt.gd:308`) costs `weapon_wear_per_hit` (1) on every landed hit, melee and
  slingshot (`stone_projectile.gd:66`). Tribe members wear their weapon 1 per hit (`tribe_member.gd:280`).
- Not worn anywhere: armor and clothing (`Inventory.equipped_armor()` skips broken pieces at `inventory.gd:98`, but
  no code ever lowers their durability), crafting tools (no recipe uses a tool).

**Wear vs resource.** Wear is flat. Tool level and tier change gather speed (`ProgressionScaling.tool_power`,
`harvest_node.gd:356`) and trait odds (`loot_tables.json rare_trait.tool_tier_bonus`, `GatherService.tool_tier`),
not wear. Minerals gate on pick tier per material (`nature_manifest.json min_pick_tier`, `HarvestNode.can_gather`,
`harvest_node.gd:323`): flint needs bone, obsidian flint, copper obsidian, iron and black iron bronze.

**Recipe gates** (`game/data/recipes.json`, `game/scripts/items/crafting.gd`, `world/craft_station.gd`).
- Workstation: 141 of 196 recipes name a `station` (workbench 65, anvil 35, mortar 10, bonfire 9, forge 8, ...).
  `Crafting.station_nearby()` and `CraftStation.station_gate()` (`craft_station.gd:83`) also read `station_tags` and
  `station_level`; only `trimmed_plank` (1) and `fine_plank` (2) use a level today.
- Skill: `min_level`, `required_ability`, `requires_node`, `required_survival` (`Crafting.progression_block`).
- Tool: only `field_small` and `field_large` carry `"requires_tool": "hoe"`, and no script reads the key.

**Repair.** None for items. `recipes.json` has a `repairs` table (per tier: station, one tier material,
`restore_fraction` 0.5) that its own `_repairs_about` calls unread data, and `item_inspect_panel.gd:320` says the
same. Structures repair (`structure_placer.gd:203`) for half the blueprint, scaled by damage.

**Material traits.** Gathered lots roll signed traits (`loot_tables.json rare_trait.by_category`: firm, high_density,
lightweight, sharp_section, pointy, compact_structure, tough_fiber, high_elasticity, thin and their opposites), at
most 2 per lot (PERKCAP), magnitude up to 3, plus rare green traits with tiers I-V. `Crafting.build_output()`
(`crafting.gd:404`) copies the primary material's attributes onto the output and stamps `material_tier`;
`roll_outcome_for` carries the primary's rare trait. The gear holds the numbers, but no stat reads them. Buildings do
read them (`structures.json quality.attributes`: High Density +2 durability per level, Lightweight +3 storage, ...).

**Tribe workers.** A worker wears its tool through `wear_gather_tool` and stops when the tool breaks
(`tribe_member.gd:429`). The Game Vision says workers stop at **one point of durability remaining** (§ Tools and
resource conservation), so a worker breaks a tool the vision says it should spare.

---

## 3. Point by point

### 3.1 Use-based wear only, no idle decay (research §1.1-1.2, §9 row 1-2)

- **Already:** no timer touches item durability. Tools wear on gathers and cuts, weapons on landed hits
  (`hunt.gd:308`). Freshness is separate from durability (Game Vision § food).
- **Adopt (P1):** armor wears on hits taken, so the research's "combat wear" row holds for the whole kit. Rule: each
  creature hit that deals damage after defense wears **1** durability on **one** worn, unbroken armor or clothing
  piece, picked at random weighted by its armor value. `# ASSUMPTION` (1 point, one piece, weighted). A broken piece
  already stops counting (`equipped_armor`). Tribe members' armor follows the same rule.
- **Skip:** structure decay over time. The research says Durango buildings decayed on a separate clock; our
  buildings take damage from creatures only, and spec 29 parks decay with Civilized Islands (Phase E).

### 3.2 Work-tool families vs combat weapon families (research §2-3)

- **Already:** `is_work_tool` splits the two. KNIFESPLIT: the Work Knife butchers and gathers, the Stone Dagger
  fights; combat picks a non-work weapon first, so the Work Knife never takes combat wear. Work tools hit at 0.45x.
  `weapons.md` lists "Stone knife (work) ... spares combat durability".
- **Adopt (P2):** a recipe's tool gate accepts **work tools only**, so a Stone Dagger or a barbed knife never
  satisfies "needs a knife" at the workbench (research §3: "do not assume that any combat weapon satisfied a
  same-shaped work-tool requirement"). Field gathering keeps the KNIFESPLIT fallback (a dagger cuts when no work
  knife is carried) because that is the owner's 2026-10-29 bug fix.
- **Note, no change:** with no combat weapon in the bag, `equipped_weapon()` falls back to a work axe, which then
  wears 1 per landed hit like any weapon. That is use-based wear on a tool used as a weapon, and the 0.45x damage
  already tells the player to carry a real weapon. KNIFESPLIT's guarantee is about the Work Knife, which has no
  weapon slot, and it holds.
- **Skip:** two-handed families, stances and bow / crossbow classes. `weapons.md` owns the weapon roster.

### 3.3 Auto-pick the right work tool while the weapon stays equipped (research §2.1, §9 row 8)

- **Already:** `find_gather_tool` / `_best_tool` pick from the bag, work tools first, best `gather_power` next;
  `HarvestNode.can_gather` picks the best qualifying pick and keeps a deliberately held lower-tier one
  (`harvest_node.gd:330-337`); NOHANDS removed the hands quick slot, so nobody equips a gather tool by hand.
- **Adopt (P2):** recipe tool gates and craft wear use the same `_best_tool` order (filtered to work tools that
  meet the tier), so the player never equips a tool to craft.
- **Skip:** nothing.

### 3.4 Recipes gated by tool type, tool level and workstation (research §4, §9 rows 4-5)

- **Already:** workstation type on 141 recipes, workstation level on 2 (`station_level`), skill gates on many.
- **Adopt (P2):**
  - `requires_tool` becomes `{"class": "axe", "min_tier": "stone"}`; the old string form (`"hoe"`) still reads as
    that class at any tier. Tier, not level, because our tool ladder is the material tier (stone, bone, flint,
    obsidian, copper, bronze, iron, steel) and the gather gates already use it (`min_pick_tier`). An optional
    `min_level` is read too but no row sets it yet. `# ASSUMPTION`.
  - `Crafting.progression_block` refuses with "needs a work axe" / "needs a flint work axe or better", shown on the
    craft row the way the station gate is.
  - Each craft run wears the chosen tool **1** durability, success or failure (research §1.2: crafting tools wear
    when a recipe that needs them runs). `# ASSUMPTION`.
  - First data pass `# ASSUMPTION`, all at stone tier except where noted:
    - axe: `pillar`, `plank`, `plank_shape`, `pillar_shape`, `trimmed_plank`, `fine_plank` (flint). Research rows:
      Cut Pillar, Make Plank.
    - knife: `hide_strap` and the other cut-hide / strap recipes. Research rows: Peel Bark, leather work.
    - hoe: `field_small`, `field_large` (the existing unread rows, now enforced).
    - no tool: drying (`dried_hide`; research "Dry Leather: none listed"), cooking, forge and anvil recipes (see
      skip).
  - A ladder audit (P2 test gate) proves no deadlock: from the starter kit, every gated recipe's tool is craftable
    through recipes that do not need a better tool.
- **Skip:** hammer, saw, needle, shovel, harpoon and cooking-utensil tool classes. None exists in `items.json`, the
  vision set does not name them, and adding them is new items and recipes. Forge and anvil recipes stay gated by the
  station alone until the owner decides (open question TD7).

### 3.5 Repair restores current durability but lowers max ~20 % per repair (research §1.3, §6, §9 row 7)

- **Already:** the `repairs` table in `recipes.json` (station and material per tier, `restore_fraction` 0.5) and
  structure repair. No item repair.
- **Adopt (P3):**
  - Repair at the tier's station from `recipes.json repairs`: workbench for stone to obsidian, anvil for copper to
    steel. Cost: `ceil(missing / (restore_fraction x max))` units of the tier material, so a broken tool costs 2
    units and a half-worn one 1.
  - Result: `max_durability = round(max_durability x 0.8)`, `durability = max_durability`,
    `attributes.repairs += 1`. `# ASSUMPTION` (0.8 is the research's one measured value, which the research itself
    calls unproven).
  - At most **4** repairs (41 % of the first max); the fifth is refused with "worn out". `# ASSUMPTION`.
  - Works on broken items and on damaged ones; refused at full durability.
  - Tooltip (`ItemInspectPanel.repair_text`): station, cost and "max 50 -> 40 (repair 2 of 4)". Market listings show
    the repair count, since buyers care.
- **Skip:** repair kits with capacity tiers (Basic 5 / Practical 25 / Advanced 100). The PRD set is silent on kits,
  and the research says kit capacity did not map to restored points, which is hard to read on a phone. Field repair
  already has a route: `workbench_kit` is portable, so an expedition carries a workbench and tier material.
  Skill-based repair quality: skip (research §6: kit quality did not change the result).

### 3.6 Material traits carry into gear (research §7, §9 row 6)

- **Already:** the primary material's attributes copy onto the gear (`crafting.gd:404`), rare traits carry, buildings
  apply traits through `structures.json quality.attributes`.
- **Adopt (P4):** gear reads the traits it already carries. Effects follow spec 04 (our source; the research's
  table differs on Pointy and Sharp Section):

  | Trait (and opposite) | Gear stat | Per level `# ASSUMPTION` |
  |---|---|---|
  | high_density / low_density | max durability | +3 % / -3 % |
  | firm / soft | weapon damage | +2 % / -2 % |
  | tough_fiber / soft_fiber | armor value | +2 % / -2 % |
  | high_elasticity | tool gather power | +2 % |

  The sum on one stat is clamped to **+-15 %**, the cap `WildLandsMMO_Crafting_Building_Math.md` uses for
  structural traits. Rows live in `game/data/world/rules.json crafting.gear_traits`, the same shape as
  `structures.json quality.attributes`. The inspect panel shows each line ("+9 % durability, High Density 3").
  Only new crafts get the effect; stored max durability on existing gear is not recalculated (no save migration).
- **Skip:** lightweight (accuracy / evasion), compact_structure (lethality), pointy (penetration), sharp_section
  (wound damage), full (stun). The combat model has no accuracy-from-gear, lethality, penetration or wound stat to
  feed; they join when those stats exist (open question TD9). Processing actions that raise traits (compress, alloy,
  tan) are `processing-depth` (spec 11), already on the roadmap.

### 3.7 Gathering wear scales with resource level vs tool (research §2.2, §5, §9 row 3)

- **Already:** flat wear; tier gates per mineral; level and tier raise max durability and speed.
- **Adopt (P1):** `wear = base x clamp(1 + 0.04 x (resource_level - tool_level), 0.5, 2.5)`.
  - `base` stays 1 for a work tool and 3 for a weapon used as a tool.
  - `resource_level` is the landed lot's level (after the gathering downrank); for a butcher cut it is the carcass
    level. `tool_level` is the tool stack's level.
  - 0.04 per level matches the research's measured slope (level 16 to 26 resource, level 19 tool: 3.25 to 4.5,
    about 3.8 % per level). Clamp 0.5 to 2.5. `# ASSUMPTION`.
  - A fractional result rounds stochastically with `GatherService.rng` (1.3 wears 1 seventy percent of the time and
    2 thirty percent), so durability stays an integer and saves do not change.
  - Better tiers already last longer through `stat_multiplier` (iron 2.12x the stone max), so the gap term is the
    only new lever: a level-1 stone knife on a level-26 carcass wears 2 per cut, a level-30 knife 0.5.
  - Numbers live in `game/data/world/rules.json gathering.wear`.
- **Adopt (P1):** tribe workers stop at **1** durability (Game Vision § Tools and resource conservation): a worker's
  wear call refuses when it would leave the tool at 0, releases the node and reports "tool worn" on the work card.
- **Skip:** hard minimum tool levels per resource level (research: level 35+ needs a level 25+ tool, 55+ needs
  45+). `ProgressionScaling` is built on "a clear difficulty step without hard gates", the tier gates already stop a
  stone pick on iron, and the wear multiplier makes an under-levelled tool expensive instead of impossible.

### 3.8 Research §9: the rest of the design translation

| Row | Decision |
|---|---|
| Durability while idle: none | Already true (3.1). |
| Combat wear | Weapons already; armor in P1 (3.1). |
| Gathering wear by difficulty | P1 (3.7). |
| Work-tool requirements | P2 (3.4). |
| Workstations gate processing | Already on 141 recipes; P2 adds tool gates, not new stations. |
| Material properties into items | P4 (3.6). |
| Repair lowers max | P3 (3.5). |
| Auto-selection | Already (3.3). |
| Expedition logistics: spare tools and kits meaningful | P1 makes tool life depend on the island's level, P3 makes a carried workbench and tier material the repair plan. No kit item. |
| "Field tools vs professional tools" (Deadfront Siege paragraph) | Skip as a new item class: the material-tier ladder already runs from field-grade stone to steel, and the permanent / expedition split is the island design's (`docs/design/island-resources.md` on its own branch). |
| "Crafters and traders rewarded" | Comes from P3 (replacement demand) and P4 (trait-graded gear); no market change here. |

---

## 4. Implementation packages and test gates

Each package passes the CURRENT merge gates (all `t_*.gd`, `tools/all_tests.sh`, `tools/smoke.sh` SMOKE PASS,
windowed shots at 1600x900 and 844x390) plus its own gate below. No package changes the save format beyond new keys
inside `attributes`, so old saves load unchanged.

**P1 WEAR: gather wear by level gap, armor wear, tribe spares tools.** `rules.json gathering.wear`,
`Inventory.wear_tool(s, resource_level)` with stochastic rounding, every caller in §2 passes the lot or carcass
level; armor wear in the creature-hit path for the player and tribe members; tribe stop-at-1.
- `t_toolwear.gd`: with a seeded rng, 1,000 wears of a level-1 work knife on a level-26 lot average 2.0 +- 0.1 per
  gather, a level-30 knife on the same lot 0.5 +- 0.05, an equal-level knife exactly 1; a weapon-as-tool is 3x the
  work tool; the multiplier never leaves 0.5-2.5.
- Armor: 100 damaging hits on a survivor in four pieces take 100 durability in total, more from the higher-armor
  pieces; a hit fully absorbed or dodged wears nothing; a broken piece is never picked.
- Tribe: a worker with a 3-durability axe on a level-1 tree stops with the axe at 1 (never 0) and the work card
  says so.
- KNIFESPLIT regression: 50 hunts with Work Knife and Stone Dagger carried leave the Work Knife untouched.

**P2 RECIPETOOLS: tool class and tier gates on recipes, craft wear.** `requires_tool` object form and string
fallback, `Crafting.progression_block` and the craft row, work-tool-only matching through `_best_tool`, 1 wear per
run, the first data pass in §3.4, the hoe rows enforced.
- `t_recipetools.gd`: `plank` without an axe is refused with the reason; with a Stone Dagger only, a knife recipe is
  refused; with a work axe it runs and the axe loses 1; `fine_plank` refuses a stone axe and takes a flint one; a
  field refuses without a hoe.
- Ladder audit (in `t_recipetools.gd` or `t_data`): from the starter kit, a breadth-first walk of recipes reaches a
  tool of every gated class and tier without needing it first; it fails and names the recipe on a deadlock.
- `t_tutorial` (bot) still finishes the tutorial, and the daily "trim 3 planks" task is still reachable.
- Shots of the craft screen with a tool-blocked row at 844x390.

**P3 GEARREPAIR: station repair with a shrinking max.** Repair action on the item inspect panel at a workbench or
anvil, cost from `recipes.json repairs`, `attributes.repairs`, the 0.8 rule and the 4-repair cap, tooltip and market
line.
- `t_gearrepair.gd`: a max-100 item repairs to 80, 64, 51, 41 and the fifth repair is refused; a broken axe costs 2
  tier units and a half-worn one 1; repair away from the tier's station is refused; a full item is refused; the
  repair count and max survive save and load and a vault round trip.
- Shot of the inspect panel with the repair line at both resolutions.

**P4 TRAITGEAR: material traits change gear stats.** `rules.json crafting.gear_traits`, read in
`ItemStack.apply_level_stats`, `scaled_damage`, `scaled_armor` and `gather_power`; +-15 % clamp; inspect lines.
- `t_traitgear.gd`: an axe crafted from a High Density 3 primary has max durability x1.09 of the plain one; Low
  Density 3 x0.91; Firm 3 raises `scaled_damage` x1.06; a stack of traits summing past 15 % clamps at 15 %; gear
  crafted before the change keeps its stored max after load.
- `t_craftfeel` and `t_bagui` still pass (they already stamp firm and high_density on materials).

Order: P1 and P2 are independent; P3 after P1 (repair matters once wear is real); P4 any time, before P3 merges
if possible so repair works from the trait-adjusted max.

---

## 5. Wiki changes as packages land

- `docs/current/items-traits.md` (generated): durability, repair count and trait effect columns.
- `docs/current/recipes.md`: the tool column.
- `docs/current/tribe.md`: workers stop at 1 durability.
- Strike the TOOLSDOC open questions the owner answers.
