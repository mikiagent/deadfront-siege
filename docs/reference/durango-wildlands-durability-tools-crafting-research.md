# Durango: Wild Lands — Durability, Tools, Combat, and Crafting Systems

**Historical research and game-design reference**  
**Game:** *Durango: Wild Lands* (Nexon)  
**Coverage:** Historical mechanics reported from 2016–2019  
**Research caveat:** Durango changed substantially during its lifetime. Several numerical values below come from contemporaneous player tests or archived recipe lists, and should not be assumed to describe every patch or the final shutdown build.

## Executive summary

Durango made weapons, tools, armor, workstations, and processed materials part of a connected survival economy:

- **Equipment wear:** Weapons, tools, and armor lost durability through use in the later game, not simply by sitting in inventory.
- **Finite repair life:** Repair restored usability but could reduce an item's *maximum* durability, encouraging eventual replacement.
- **Tool specialization:** Gathering, material processing, crafting, construction, and combat used distinct categories of tools, although some tools had overlapping uses.
- **Multi-stage production:** Raw resources were gathered, processed into better materials or components, and assembled into finished gear at suitable workstations.
- **Material-derived stats:** Resource properties and processing operations could affect finished equipment's durability and other characteristics.
- **Quality of life:** Appropriate gathering tools could be automatically selected from inventory, reducing constant manual switching.

The key design principle is that **equipment consumption creates demand for gathering and crafting, while good materials and skilled processing create superior equipment**.

---

## 1. Durability mechanics and patch history

### 1.1 How the system evolved

| Period | Reported behavior |
|---|---|
| Early versions, approximately 2016–early 2018 | Weapons, tools, and armor experienced natural durability deterioration, potentially even while unused. |
| March 8, 2018 patch | Durability consumption was reduced: gathering, crafting, and construction tools reportedly used 67% of prior consumption; combat equipment 80%. Repair penalties were also adjusted. |
| June 14, 2018 patch onward | Weapons, tools, and armor no longer naturally deteriorated while idle. They lost durability through relevant usage. |
| Buildings and other structures | Separate time-based deterioration systems could continue to apply. |

**Design consequence:** The newer system stopped punishing players for stockpiling equipment or going offline while preserving resource and repair costs for active gameplay.

### 1.2 Which actions consumed durability?

| Equipment | Typical cause of wear |
|---|---|
| Combat weapons | Attacking creatures or enemies |
| Armor and clothing | Combat hits and relevant use |
| Gathering tools | Harvesting, chopping, mining, and butchering |
| Processing tools | Executing processing recipes that require those tools |
| Crafting tools | Executing crafting recipes that require those tools |
| Construction tools | Construction work requiring the tool |
| Buildings and furniture | Separate deterioration rules, potentially time-based |

This is a *system-level classification*. The exact wear event for any individual item may have varied by patch and recipe.

### 1.3 Current vs. maximum durability

Durango distinguished **current durability** from **maximum durability**:

- Using equipment depleted its current durability.
- At or near zero, equipment could become unusable until repaired.
- Repair could restore current durability to a *lower maximum*, permanently shortening the item's remaining lifetime.
- Eventually, repeated repairs could make the item unattractive to maintain compared with crafting or buying a replacement.

A February 2018 player experiment found repair resulting in about **80% of the previous maximum durability** for items in that test. Later patches altered repair penalties, so **20% loss per repair is not a proven universal rule**.

**Illustrative mathematical example only:** If each repair left 80% of the previous maximum, an item starting at 100 maximum would follow:

| State | Maximum durability |
|---|---:|
| New | 100.00 |
| After first repair | 80.00 |
| After second repair | 64.00 |
| After third repair | 51.20 |
| After fourth repair | 40.96 |
| After fifth repair | 32.77 |

Formula for that *illustration*, not an independently verified universal Durango formula:

`new_maximum = old_maximum × 0.8`

**Equipment lifecycle:** Craft → Use → Repair → Use again → Eventually replace.

---

## 2. Gathering and work tools

Durango did not put every activity behind the same generic tool. Tool categories were tied to resources, recipe requirements, and progression.

| Tool | Gathering role | Processing / crafting / other role |
|---|---|---|
| **Work Knife** | Plant resources, leaves/fibers, some branches, skinning/butchering | Cut or prepare materials, handles, leather, assorted components |
| **Work Axe** | Trees, logs, wood resources | Cutting pillars, producing planks, woodworking and some recipe components |
| **Work Hammer** | Stone and rock gathering in some contexts | Metalworking, manufacturing, construction and many processing recipes |
| **Saw** | Primarily preparation rather than field gathering | Trimming wood, bone, stone and other materials |
| **Pickaxe** | Mining ore and metal deposits | Mineral extraction |
| **Shovel** | Soil, mud, clay | Materials for buildings and farming |
| **Hoe** | Cultivating fields | Agriculture |
| **Harpoon** | Fishing | Acquiring fish resources |
| **Needle** | Not a normal field gathering tool | Sewing, modifying fabric and other textile recipes |
| **Cooking utensils** | Not a gathering tool | Cooking-specific recipes |

**Important distinction:** A *Work Axe* was not necessarily interchangeable with a combat axe, and a *Work Hammer* was not necessarily interchangeable with a combat hammer. Recipes could demand a particular work-tool category and minimum level.

### 2.1 Auto-selection of gathering tools

Durango reportedly chose an appropriate gathering tool from the player's inventory when the player began a suitable resource action. A player could keep their combat weapon equipped but automatically use an axe when chopping a tree, without manually equipping the axe first.

That quality-of-life feature let players carry specialized equipment without constant inventory micromanagement.

### 2.2 Tool-tier thresholds

A reconstructed community guide lists approximate field-gathering thresholds:

| Resource level | Required tool level in the referenced guide |
|---|---|
| Below level 35 | Lower-tier tools typically sufficient |
| Level 35+ | Level 25+ tool |
| Level 55+ | Level 45+ tool |

These values are community-reconstructed historical thresholds, **not an authoritative universal list for every resource or game build**. Individual recipes also demanded particular tool levels.

---

## 3. Combat weapons vs. work tools

Combat weapons belonged to separate weapon families and informed combat skills, attack behavior and stance/ability selection.

| Weapon family | Combat role |
|---|---|
| One-handed knife | Fast close-range cutting attacks |
| Two-handed knife | Larger melee cutting attacks |
| One-handed axe | Cutting and wound-oriented attacks |
| Two-handed axe | Heavy cutting attacks |
| One-handed hammer | Blunt and impact damage |
| Two-handed hammer | Heavy impact / stunning role |
| Spear or lance | Extended-reach melee attacks |
| Bow | Ranged hunting and combat |
| Crossbow | Alternative ranged combat |

Durango combat was semi-automatic, but equipment could determine which skills and defensive or offensive actions were available.

Early guides sometimes described axes and hammers as having utility and combat applications. In practical crafting terms, however, later recipe records clearly named **dedicated work-tool variants**. Do not assume that any combat weapon satisfied a same-shaped work-tool requirement.

---

## 4. Gathering, processing, crafting, and workstation requirements

Durango distinguished the stages of production:

1. **Gather:** Obtain logs, minerals, hides, plants, bones, and other raw materials using appropriate field tools.
2. **Process:** Cut, trim, refine, dry, tan, extend, alloy, or otherwise change materials. Many processes needed both a portable tool and a workstation.
3. **Produce components:** Create blades, weapon heads, bow limbs, planks, fasteners, and other subassemblies.
4. **Assemble finished goods:** Build weapons, armor, tools, structures or other equipment using the required skill, crafting tool and workstation.
5. **Use, repair, replace:** Finished gear consumed durability, sustaining demand for production.

### 4.1 Archived material processing recipes

The following represent **documented archived recipe examples**, not a verified final-patch exhaustive catalog.

| Recipe / process | Required tool | Workstation | Purpose |
|---|---|---|---|
| Trim Material | Saw Lv. 5 | Workbench Lv. 20 | Prepare wood, stone or bone |
| Cut Pillar | Work Axe or Work Knife | None listed | Split wood or bone pillar |
| Peel Bark | Work Axe or Work Knife Lv. 10 | Workbench | Process bark |
| Make Plank | Work Axe Lv. 5 | Workbench | Produce construction components |
| Extract Gem | Work Hammer | Workbench Lv. 20 | Process gems |
| Refine Ore | Work Hammer Lv. 25 | Kiln Lv. 35 | Refine metal |
| Create Metal Nails | Work Hammer Lv. 25 | Kiln Lv. 35 | Produce fasteners |
| Extend Fabric | Needle Lv. 5 | Workbench Lv. 20 | Process textiles |
| Dry Leather | None listed | Drying Rack Lv. 15 | Produce dried leather |
| Waterproof Material | Work Hammer Lv. 25 | Drying Rack Lv. 15 | Treat material |

### 4.2 Archived weapon crafting recipes

| Recipe | Required crafting tool | Workstation |
|---|---|---|
| Stone Axe Head | Work Axe or Work Knife Lv. 5 | Workbench Lv. 15 |
| Bone Bow Limb | Work Axe or Work Knife Lv. 5 | Workbench Lv. 15 |
| Ironwood Bow Limb | Work Axe or Work Knife Lv. 25 | Workbench Lv. 40 |
| Metal War Axe Head | Work Hammer Lv. 25 | Kiln Lv. 35 |
| Improved One-Handed Axe | Work Hammer Lv. 25 | Workbench Lv. 40 |
| PRO-class One-Handed Axe | Work Hammer Lv. 45 | Weapon Workbench Lv. 50 |
| PRO-class Bow | Work Hammer Lv. 45 | Weapon Workbench Lv. 50 |

These examples show why a player could have sufficient raw materials yet still be unable to make an item: they might lack the right **tool type, tool level, crafting skill, processed components, or workstation**.

### 4.3 Simplified example: ore deposit to combat axe

> The following combines historical recipe stages to explain the system; it is **not** presented as one exact complete archived recipe.

1. **Mine ore** with the appropriate pickaxe.
2. **Refine ore** at a suitable kiln using a work hammer and fuel/materials.
3. **Craft an axe head** with the appropriate work tool and workstation.
4. **Prepare handle and fastening parts** from processed wood and other materials.
5. **Assemble the weapon** at the relevant crafting station.
6. **Equip and fight** until durability is depleted.
7. **Repair or replace** the axe as its remaining useful life declines.

This allows specialized gatherers, processors, weapon crafters, and fighters to participate in the same economy.

---

## 5. Gathering wear and resource difficulty

A December 2016 Inven experiment investigated gathering equipment wear. It reported several patterns:

- Higher-level resources increased durability consumption.
- Stronger/better tools generally lost less durability for the same work.
- The tested failure, ordinary success and great-success outcomes did not materially change durability consumed.
- Resources of similar levels could inflict similar wear despite being different resource types.

### Historical measurement: level 19 stone tools

| Resource level | Approximate durability consumed per gathering action |
|---|---:|
| 16 | 3.25 |
| 20 | 3.65 |
| 23 | 4.05 |
| 26 | 4.50 |

**Interpretation:** These are approximate midpoint values summarized from the 2016 test, **not the official final-game formula**. The June 2018 changes mean later wear values may differ.

This mattered for expeditions: taking too few tools risked being unable to harvest high-level resources; taking too many consumed carrying capacity that could otherwise hold valuable materials.

---

## 6. Repair kits and repair economy

An Inven February 2018 repair-kit experiment documented these historical tiers:

| Repair kit | Repair capacity | Reported ingredients |
|---|---:|---|
| Basic | 5 | 2 blades, 2 wooden sticks, 2 small ropes |
| Practical | 25 | 3 bone sticks, 2 adhesives, 2 small ropes |
| Advanced | 100 | 6 trimmed bones, 1 metal blade, 2 ropes |

**Critical distinction:** A repair kit's *capacity* was used to satisfy the repair requirement. It was **not** a straightforward promise to restore that many current-durability points.

The test also suggested that:

- Increasing repair-kit level or quality did not automatically improve the repair result.
- Higher-level copies of the same work tool did not necessarily require more repair capacity.
- Repair cost was closely tied to equipment category and recipe tier.
- Some weapons' repair costs related to the tier of their head, blade or analogous component.
- Examples in the test ranged from an early work tool requiring about 5 capacity to some advanced combat weapons requiring 100.

A 2019 player discussion described selecting an item with a zero-durability/broken indicator and applying a suitable repair kit.

### Economic effect

**Repairing postponed replacement but did not eliminate it.** The gradual loss of maximum durability could maintain long-term demand for skilled equipment manufacturers and processed materials.

---

## 7. Material properties and the durability of crafted items

One of Durango's most distinctive systems was that **material properties could carry forward into finished products**.

A community Mastersheet recorded associations such as:

| Material trait | Reported effect |
|---|---|
| High Density | Increased durability |
| Low Density | Reduced durability |
| Firm | Increased attack |
| Compact Structure | Increased lethality |
| Lightweight | Improved accuracy |
| Pointy | Improved relevant processing ability |
| Sharp Section | Improved relevant gathering ability |

Certain processing choices could intentionally improve useful material traits:

| Processing action | Reported trait effect |
|---|---|
| Compress bone or wood | High Density +2 |
| Desulfurize metal | High Density +2 |
| Alloy copper and tin into bronze | High Density +5 |
| Select attack-oriented material processing | Potentially more damage at a durability trade-off |
| Fiber-tan leather | High Density +2 |

**Evidence level:** These numeric bonuses are preserved in historical community sheets and should be independently tested against the intended game version before being treated as exact canonical formulas.

### Why this mattered

A craftsman could target different equipment uses:

- A **high-durability gathering axe** for hundreds of resource interactions.
- A **high-damage combat axe** with possible durability trade-offs.
- **Lightweight ranged components** that emphasized accuracy.
- **Specialized crafting equipment** benefiting from relevant processing or gathering traits.

The outcome depended not just on unlocking the recipe, but also on the properties of materials selected and the processing steps completed.

---

## 8. System interactions at a glance

```text
Raw world resources
     |
     v
Gathering profession + gathering tools
     |
     v
Raw materials (level, quality, traits)
     |
     v
Processing skill + work tools + workstations
     |
     v
Improved materials / weapon components
     |
     v
Crafting skill + recipe + work tools + workstations
     |
     v
Finished combat gear / work tools / structures
     |
     v
Use in combat, gathering, crafting, construction
     |
     v
Durability loss
     |
     +----> Repair kits (potential max-durability reduction)
     |                |
     |                +----> Return to use
     |
     +----> Craft or purchase replacement
                      |
                      +----> Demand for more resources and crafting
```

The full loop tied active gameplay to the production economy rather than treating crafting as a one-time unlock ladder.

---

## 9. Design translation for a Durango-inspired survival game

These are **recommendations**, not assertions about Durango's original implementation.

| Mechanic | Recommended approach | Reason |
|---|---|---|
| Durability while idle | None for weapons, armor and portable tools | Avoid punishing time offline |
| Combat wear | Degrade equipment through combat use | Connect danger to upkeep |
| Gathering wear | Scale by resource difficulty vs. tool capability | Reward quality tools and expedition preparation |
| Work-tool requirements | Specific tool family and tier for recipes | Preserve profession identity |
| Workstations | Gate important processing/advanced crafting by station | Make bases economically useful |
| Material properties | Inherit or translate selected traits into finished items | Reward gathering and material expertise |
| Repair | Restore current durability but gradually lower maximum | Keep replacement economy active |
| Auto-selection | Automatically choose suitable tool from inventory | Reduce tedious swapping |
| Expedition logistics | Make spare tools and repair kits meaningful, not mandatory micromanagement | Create risk/reward choices |

### Application to Deadfront Siege

A natural distinction would be:

- **Field tools:** Easy-to-transport, multipurpose tools for temporary expedition bases and initial recovery after a loss.
- **Professional tools:** More efficient, specialized equipment used with advanced workstations at permanent settlements.
- **Combat gear:** Designed for fighting, with separate wear and skill progression from productive tools.
- **Crafters and traders:** Rewarded for improving material quality, making dependable equipment, and providing replacements.
- **Automation:** Auto-select tools and simplify repetitive chores, while manual gathering and skilled processing remain more rewarding.

This fits a design with **permanent player islands** and **temporary, periodically resetting expedition islands**: valuable permanent infrastructure supports high-grade production, while portable equipment and field repairs determine expedition readiness.

---

## 10. Open historical questions / verification gaps

The remaining points should not be treated as definitively established without additional primary-source or video verification:

1. Exact **final-patch** durability-consumption formula by tool level, resource level, and activity.
2. The complete repair/max-durability formula **after** all 2018 balance changes.
3. Exact conditions under which **armor and clothing** lost durability in each patch.
4. Whether every listed **weapon family and tool class** existed simultaneously in the final version, with unchanged names.
5. Full per-recipe repair capacity requirements and work-tool substitutions.
6. Exact material-trait inheritance, stacking, and processing-attempt limits for final recipes.
7. Whether there were exceptions to automatic gathering-tool selection or tool wear on failed processing/crafting attempts.

These are good targets for future archival research rather than points to silently fill in with assumptions.

---

## Sources and research leads

The following links were cited in the earlier research. They include contemporary Korean reporting, archived community recipe tables, and player-maintained reference material. Some sources are community documentation rather than official developer specifications.

1. **Inven — June 2018 durability changes:** https://www.inven.co.kr/webzine/news/?news=201409&site=durango
2. **Inven — Repair and durability experiment:** https://www.inven.co.kr/webzine/news/?news=193654&site=durango
3. **Inven — December 2016 gathering durability investigation:** https://m.inven.co.kr/webzine/wznews.php?idx=169621&site=durango
4. **Archived Durango Wiki — Material Processing recipes:** https://durango-archive.fandom.com/wiki/Crafting%3A_Material_Processing
5. **Archived Durango Wiki — Weapon recipes:** https://durango-archive.fandom.com/wiki/Crafting%3A_Weapon
6. **Community Durango Wildlands Mastersheet:** https://www.scribd.com/document/501357601/Durango-Wildlands-Mastersheet

**Source limitations:** Historical item lists, player tests, and patch descriptions may disagree because they refer to different game builds. Prefer dated primary patch notes for chronological changes and contemporary experiments for what actually happened within a specific build.

---

## Bottom line

Durango's durability system connected **resource gathering → tool wear → advanced material processing → weapon/tool production → combat and field use → repair → eventual replacement**. The most transferable elements are **use-based wear, quality-of-life auto-tool selection, specialized crafting tools, material-derived durability, and finite repair lifetimes**. Together, they supported a persistent gathering and crafting economy without requiring players to micromanage every equipment swap.
