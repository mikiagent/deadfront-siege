# 23 | Eighteen defining weapons: dinosaur materials, gathering and the metal breakthrough

**Status:** 2026-10-25, **OWNER-REQUESTED WORKING RECIPE PROPOSAL / ASSET BACKLOG**, not approved item numbers, final weapon unlocks or implementation. User wants **six weapons per era** (one for each **DI, DP, DS, MI, MP, MS**), across **early / mid / late**, whose **ingredients are grounded in the game's actual gathering and butcher resources** or explicitly **marked for addition**. Critical fantasy: primitively collected wood, stone and bone -> sophisticated animal-composite tools -> **a transformative acquisition of refined copper/iron**, with dinosaur tissue and trophies still valuable in refined weapons. Civilization can remain mostly primitive; modern guns/exosuits are **not** assumed.

Related: [Weapons](../design/weapons.md), [Armor](06-inventory-equipment-and-storage.md), [Mass/armor/pounce](22-dinosaur-mass-armor-and-grappling.md), [Mounted Combat](12-expedition-mounts-and-command.md), [Dinosaur catalog](11-dinosaurs-and-genetics.md), [Decisions](decisions.md).

**Source audit:** [`game/data/items.json`](../../game/data/items.json) (153 item definitions), [`game/data/recipes.json`](../../game/data/recipes.json) (73 recipes), [`game/data/butchering.json`](../../game/data/butchering.json) (19 creature drop entries), [`game/data/nature_manifest.json`](../../game/data/nature_manifest.json) (harvest definitions), [`game/data/world/climates.json`](../../game/data/world/climates.json) and [`game/data/world/islands.json`](../../game/data/world/islands.json) (source biomes/tiers), [`game/data/skills/trees.json`](../../game/data/skills/trees.json) (skills), and the [crafting code](../../game/scripts/items/crafting.gd). Existing item/ingredient presence **does not by itself prove a new weapon can currently be crafted, equipped or swung in game**. New outputs, stations, ammo and mastery behaviors need code and content.

## 1. Classification and weapon behavior

- **DI** = **Dexterity / Impact**: sling, staff sling, mechanically aimed stone launcher; **Longshot** for skillful difficult hits, force/stone body contact.
- **DP** = **Dexterity / Pierce**: bow, crossbow, specialized bolt thrower; precise focused damage, weak-point aiming.
- **DS** = **Dexterity / Slash**: controlled knife, whip, precision cut; short-contact arcs, bleeding/controlled timing; melee eligible for Combo on direct hits where specified.
- **MI** = **Might / Impact**: club, hammer, maul; stagger and Heavy-plate control.
- **MP** = **Might / Pierce**: spear, lance, heavy braced long-point weapon; **Momentum Strike** when truly approaching/aligned on a mount.
- **MS** = **Might / Slash**: stone axe, great axe, forged greatblade; heavy melee Slash with **Combo/Rend** and possible Berserker **Frenzy** synergy.

**Damage type is NOT firing/attack speed.** A slow MS greatblade is still Slash. Equipment delivery and actual weapon hit/reach (including saddle height) matter. The metal era must improve some combination of **durability, precision, armor matchup reliability, sophisticated attack modes and repairability** instead of only multiplying weapon damage by rarity.

## 2. 18 defining weapon recipes (exact hypothetical ingredients)

**Legend:** `existing output` = item is in current `items.json`; `existing recipe` = exact output already in current `recipes.json` (even if mechanics/type scaling still incomplete); `NEW` = output/recipe must be added. Resource names in code format are **actual current item IDs** unless **[ADD]** is attached. All listed craft counts are **illustrative proposals**. Do **not** silently assume special ingredients can be enforced by category alone.

### Early game: stone, wood, fiber and first dinosaur hunts (suggested personal levels 1–20)

| Code | Defining weapon (output id) | Concrete ingredient counts, all items defined now | Item/recipe status | Reason to use |
|---|---|---|---|---|
| **DI** | **Bone Slingshot** (`slingshot`) | `bone ×1 + branch ×1 + (twine / bark_strip / root) ×2`; ammo `stone_shot` from `stone ×1` | **EXISTING ITEM + RECIPE** `slingshot` and `stone_shot` (recipe uses any `bone/handle/lashing`) | First controlled ranged **Impact** and eventual **Longshot** |
| **DP** | **Sinew Shortbow** (`sinew_shortbow` **[ADD]**) | `branch ×2 + predator_tendon ×2 + hide_strap ×1`; proposed **Stone Arrow Bundle** `branch ×1 + stone ×1 + twine ×1 -> stone_arrows ×3` **[ADD]** | **NEW WEAPON + AMMO + RECIPES**, all ingredient items have sources | First focused ranged **Pierce**, animal sinew bowstring |
| **DS** | **Stone Combat Knife** (`stone_knife`) | `stone ×1 + branch ×1 + hide_strap ×1` | **EXISTING ITEM, ADD dedicated combat recipe**; existing `improvised_stone_knife` instead outputs `stone_knife_work` | Fast precise melee **Slash**; optionally add thrown cutting mode later, not automatically |
| **MI** | **Dense Bone Hammer** (`bone_hammer`) | `dense_bone ×2 + branch ×1 + (twine / bark_strip / root) ×2` | **EXISTING ITEM + RECIPE**; early `club` is the before-bone starter | Heavy **Impact** and stagger, rewarding first Zebraceratops hunt |
| **MP** | **Bone Spear** (`bone_spear` **[ADD]**) | `raptor_bone ×2 + branch ×2 + predator_tendon ×1 + hide_strap ×1` | **NEW ITEM + RECIPE**, all ingredient IDs present | Reach, bracing and early heavy **Pierce**; later first mounted stab |
| **MS** | **Stone Axe** (`work_axe`) | `stone ×1 + branch ×1 + (twine / bark_strip / root) ×1` | **EXISTING ITEM + RECIPE** `work_axe`, which is a real gather tool with combat Slash; add explicit **Might-primary** combat classification | Primitive versatile tool/weapon; simple meaningful **Slash** and gathering economy |

**Early acquisition loop, specifically grounded:** Grassland home sources yield branches, stones and fibers. **Home Compys** yield `bone, raw_hide, predator_tendon`; **home Zebraceratops** yield `raptor_bone, raw_hide, dense_bone, armor_scute`. `twine` (`fibre ×2`) and `hide_strap` (`uncut_hide ×1`, workbench) already have processing recipes. A player can obtain **ingredients** for every Early recipe through declared home sources; the bold **NEW** weapons and arrow/knife recipes are **not yet craftable in shipped game**. A new weapon with `stone_knife` as output should respect current `stone_knife_work` vs combat distinction.

### Mid game: hunter composites, horn/talon tension weapons, first refined copper (suggested ~25–44)

| Code | Defining weapon (output id) | Concrete ingredient counts, all items defined now except an explicitly blocked copper ingot | Status | Why it changes play |
|---|---|---|---|---|
| **DI** | **Scute Staff Sling** (`scute_staff_sling` **[ADD]**) | `dense_bone ×1 + armor_scute ×1 + branch ×2 + predator_tendon ×2 + hide_strap ×1`; fires `stone_shot` | **NEW**; ingredients already have sources | Longer-range Impact, reliable **Longshot** mastery; animal bone braces/staff |
| **DP** | **Copper-Trigger Crossbow** (`copper_crossbow` **[ADD]**) | `plank ×2 + dense_bone ×2 + predator_tendon ×3 + copper_ingot ×1 + hide_strap ×1`; **Bone Bolt Bundle** `branch ×1 + raptor_bone ×1 + twine ×1 -> bone_bolts ×3` **[ADD]** | **NEW + COPPER REFINING PIPELINE NEEDED**. `copper_ingot` item exists but **no real copper_ingot smelt recipe** | First technological **step change**: high impulse, crossbow prod/trigger, reload trade-off |
| **DS** | **Talon Whip** (`talon_whip` **[ADD]**) | `raptor_talon ×2 + predator_tendon ×3 + hide_strap ×2 + branch ×1` | **NEW**; `raptor_talon` is a rare real Velociraptor/Deinonychus butcher drop | Reach and skillful repeated controlled **Slash**; risk-reward and Combo eligible if melee |
| **MI** | **Scute Warhammer** (`scute_warhammer` **[ADD]**) | `dense_bone ×2 + armor_scute ×3 + branch ×2 + hide_strap ×2` | **NEW**; existing species drop scutes/dense bone | Heavy-plate disruption and stagger; animal composite Impact |
| **MP** | **Talon War Lance** (`talon_war_lance` **[ADD]**) | `raptor_bone ×2 + raptor_talon ×1 + branch ×2 + predator_tendon ×2 + hide_strap ×1` | **NEW**; all resource items obtainable by declared routes, talon rare | First serious **mounted Momentum Strike** weapon; heavy Pierce/bracing |
| **MS** | **Obsidian Great Axe** (`obsidian_great_axe` **[ADD]**) | `obsidian ×2 + dense_bone ×1 + branch ×2 + hide_strap ×2 + predator_tendon ×1` | **NEW**; obsidian gathered from **Tropical ~25** `ObsidianNode` | Extremely sharp Slash, heavy arcs and slower Combo/Rend, but brittle/repair-intensive |

**Mid acquisition loop:** first visit tropical Tier 25 for **obsidian** and **bamboo** (bamboo may be an optional flexible stock for the bow, but it is not required in the recipe); hunt or butcher raptors for rare **talons** and tendons, ceratopsians for scutes/dense bone; access **Desert Tier 35** for **copper_ore**. Current Ranged tree already *lists* bow unlock at 10 and crossbow at 35, **but actual bow/crossbow weapon items/recipes are absent**. Refined copper is the first coherent mechanical crossbow trigger/fitting, not a freely swapped generic ingot. For Mid 25–34, five dinosaur/stone-composite weapons can work without a smelter; Copper Crossbow is the Tier ~35 **breakthrough** after a proper furnace unlock.

**Optional first-metal upgrades, not additional defining weapon classes:** forge copper fittings onto the **Scute Staff Sling, Talon Whip, Warhammer, War Lance and Obsidian Great Axe**. These should improve durability, fitting/repair, some animation or armor control but do **not** reclassify the weapon. Implement via recipes that preserve primary-item level/material traits once the player has a forge. Do not gate the five base Mid designs behind nonexistent copper.

### Late game: iron forging, hardened mechanisms and rare dinosaur trophy upgrades (suggested ~45–60)

**Important:** `iron_ingot` item **already exists**, but the current game has **no `iron_ore` item/source or specific iron-ingot refinement recipe**. The iron progression below is **BLOCKED pending added world content and metallurgy**, not currently craftable. Base recipes use real **existing dinosaur items** wherever possible. Optional horns/teeth require new drops (tracked in backlog).

| Code | Defining weapon (output id) | Exact proposed ingredients | Implementation dependencies | Defining late-game advantage |
|---|---|---|---|---|
| **DI** | **Iron Torsion Stonecaster** (`iron_stonecaster` **[ADD]**) | `iron_ingot ×2 + plank ×3 + predator_tendon ×4 + dense_bone ×2 + hide_strap ×2`; ammo existing `stone_shot` or future heavier shot | **NEW WEAPON + missing iron loop** | More accurate, hard-hitting engineered **Impact**, deliberate launch/reload; not a modern rocket launcher |
| **DP** | **Iron Repeating Crossbow** (`iron_repeating_crossbow` **[ADD]**) | `iron_ingot ×4 + plank ×3 + predator_tendon ×4 + armor_scute ×1 + hide_strap ×2`; fires `bone_bolts` or future `iron_bolts` | **NEW WEAPON + iron loop + bolt ammo** | Controlled short volley of high-Pierce bolts, longer refill/reload; strict cost and stamina/reload balance |
| **DS** | **Iron Talon Chain Whip** (`iron_talon_whip` **[ADD]**) | `iron_ingot ×3 + raptor_talon ×2 + predator_tendon ×3 + hide_strap ×2` | **NEW WEAPON + iron forging / link shaping** | Extended controlled **Slash** with heavy wear resistance, contact combos and movement timing |
| **MI** | **Scute-Core Iron Siege Maul** (reuse existing `raid_maul`, **RECIPE REVISION**) | `iron_ingot ×5 + armor_scute ×2 + dense_bone ×2 + branch ×2 + hide_strap ×2` | **CURRENT `raid_maul` EXISTS + generic 8-metal recipe**, needs targeted upgrade/new variant + iron source/station | Massive **Impact**, break Heavy body plating, stagger; advanced forged head reinforced by bone/scute core |
| **MP** | **Forged War Lance** (`iron_war_lance` **[ADD]**) | `iron_ingot ×2 + dense_bone ×2 + raptor_talon ×1 + branch ×2 + predator_tendon ×2 + hide_strap ×2` | **NEW + iron loop**; optional true `ceratops_horn` variant **[ADD DROP]** from Styracosaurus/Triceratops | Reinforced **Pierce**, largest controlled mounted **Momentum Strike** without needing futuristic weapons |
| **MS** | **Iron Talon Greatblade** (`iron_talon_greatblade` **[ADD]**) | `iron_ingot ×4 + dense_bone ×1 + raptor_talon ×2 + predator_tendon ×2 + hide_strap ×2` | **NEW + iron loop**; optional `predator_tooth` prestige variant **[ADD DROP]** from higher predators | Wide heavy **Slash** with durability, deliberate Combo/Rend and Berserker follow-through |

**Late acquisition loop:** high-tier **iron ore** must become obtainable from a genuinely gated Tier ~45–50 frontier node, rather than falsely reusing all `ore` from trivial sources. Tier-60 **Volcanic** has `black_iron`, enabling **prestige black-iron** enhancements AFTER its own furnace/forge refining recipe exists. Current `bronze_ingot` and `steel_ingot` item definitions **are not evidence of usable recipes or raw material sources**. Bronze additionally needs **tin** or a grounded alternate source; steel needs a deliberate **iron + carbon/charcoal** process, not an imaginary spontaneously smelted ingot. Late primitive weapons must still use **dense bone, scutes, talons, tendon and hides** for grips, laminates, braces and bone horn/trophy shapes.

**Optional aspirational prestige materials NOT currently available:** `ceratops_horn` and `predator_tooth`; a `muscle_fiber` material is **not** necessary just to say 'muscle': **predator_tendon** is already a credible extracted sinew/structural tension resource, while raw meat becomes pet food. If adding muscle later, give it a biologically coherent use such as processed glue/collagen, not implausible structural metal replacement. `raptor_talon` and `predator_tendon` are already real butcher items.

## 2A. Work tools follow the same material eras, without becoming additional weapon classes

The user also wants **tools** made from dinosaur materials and stone/wood. These are **civilian/work progression examples**, separate from the **18 defining combat weapons**. Do not multiply the six combat classes by every mining/skin-gathering variant.

| Stage | Work tool | Exact proposed ingredient example | Status and why this matters |
|---|---|---|---|
| **Early** | **Stone Work Knife** (`stone_knife_work`) | `stone ×1 + branch ×1 + twine ×1` | **Existing item + hand recipe** (generic `blade_mat, handle, lashing`); harvest plants and process hides |
| **Early** | **Stone Pick** (`work_pick`) | `stone ×1 + branch ×1 + twine ×1` | **Existing item + workbench recipe**; enables progression to stone/clay and ultimately ore nodes |
| **Mid** | **Raptor Talon Skinning/Combat Knife** (`barbed_knife`) | `raptor_talon ×1 + branch ×1 + hide_strap ×1` | **Existing item + workbench recipe**. Has `tool_class: knife` and bleed-capable weapon stats; verify its actual harvest-tool ability in gameplay before advertising as improved skinning yield |
| **First copper** | **Copper Quarry Pick** (`copper_pick` **[ADD]**) | `copper_ingot ×2 + dense_bone ×1 + branch ×1 + hide_strap ×2` | **New tool/recipe after Smelter**. Copper pick is durable vs stone, but should not simply be the best iron-mining tool; tune tier and ore hardness instead of an implausible copper-beats-all progression |
| **Late** | **Iron Quarry Pick** (`iron_quarry_pick` **[ADD]**) | `iron_ingot ×3 + armor_scute ×1 + branch ×2 + hide_strap ×2` | **New item/recipe after iron forge**; enables effective hard-rock and higher-level frontier mining |
| **Late** | **Iron Lumber Axe** (`iron_lumber_axe` **[ADD]**) | `iron_ingot ×2 + dense_bone ×1 + branch ×2 + hide_strap ×2` | **New item/recipe**. Longer durability and higher resource throughput while retaining the living wood/hide/bone supply chain |

**New tool backlog WPN-20:** Add `copper_pick`, `iron_quarry_pick` and `iron_lumber_axe` definitions/recipes, actual gathered-node hardness/tool-tier progression, and repair/durability costs; test whether existing `barbed_knife` is a valid harvesting knife before making economic yield promises. These are **additional work tools**, not new attack-class letters. Ensure early `work_pick` can legally gather enough copper ore to bootstrap copper refining; iron requires higher ore-tier access. If resource hardness rules are added, never deadlock an era by demanding an iron tool before any iron can be obtained.

## 3. Verified ingredient sources and provenance

| Actual item ids | Existing declared source | Expected access |
|---|---|---|
| `branch, wood_log, stone, fibre_stalk, bark_strip` | Grassland `CommonTree, BirchTree, Rock, Bush, FibreTuft, BranchPile`, current nature manifest | Starting home grassland; basic collection/tools |
| `twine, hide_strap, plank, charcoal` | Current `recipes.json`: fiber -> twine; uncured hide -> strap at workbench; split logs -> plank; burnables -> charcoal | Existing crafted intermediates; required stations/tools |
| `bone, raw_hide, predator_tendon` | **Compsognathus** butcher base drops; Coelophysis also later | Home grassland Compy + later early creatures |
| `raptor_bone, dense_bone, armor_scute, raw_hide` | **Zebraceratops/Protoceratops** butcher base drops | Zebraceratops home; Protoceratops Temperate ~20 |
| `raptor_talon` | **Velociraptor, Deinonychus, Utahraptor** rare butcher table, sometimes requires butchering skill | Tiers ~25/35/50; intermittent/rare, not guaranteed |
| `predator_tendon` | **Compy, Coelophysis, Velociraptor/Deinonychus/Utahraptor, Smilodon/Allosaurus** base drops | From early to late |
| `obsidian, bamboo` | Tropical `ObsidianNode, BambooPlant` | Tropical ~25 |
| `copper_ore` | Desert `CopperOreNode`; appears in Desert climate materials | Desert 35/50; new copper smelt recipe needed |
| `black_iron` | Volcanic `BlackIronNode` | Volcanic 60; new advanced refining recipe needed |
| `iron_ingot` | **Item defined, NO recipe for iron_ingot** | Not a trustworthy currently obtainable metal source |
| `iron_ore, ceratops_horn, predator_tooth` | **NO item ids / ore nodes / animal butchering output presently** | Must add a source before required in real recipes |
| `copper_ingot, bronze_ingot, steel_ingot` | **Item ids defined; NO specific per-metal refining recipes** | Items alone are not material production |

**Source caveat:** This is a static review of declared harvest/biome/butchery/recipe data, **not an end-to-end loaded-world test**. Home resource and creature definitions are present, but verify actual spawned node access, tool levels, loot application and save compatibility in game. Some nature manifest rows return names without item definitions (e.g. `ore_chunk`, `spine`), a data-quality concern outside these 18 concrete recipes.

## 4. The metal moment must actually change crafting

**Metal Stage A: acquire ore.** Desert Tier ~35 copper needs a mining tool, skill and dangerous expedition. Give the player a readable first `copper_ore` acquisition quest/tech discovery, not free copper ingots from every stone.

**Metal Stage B: build processing infrastructure.** Introduce **Smelter / Furnace** kit (stone, clay, wood fuel, fiber lashings) and **Forge** for shape/heat treatment. Current generic `ingot` recipe is **2 any `ore` at a workbench** and cannot represent iron/copper/bronze with correct prerequisites. Fix/retire as a generic placeholder or deliberately reframe as crude metal scrap. Don't let generic `ore`/workbench create iron gear by category overlap.

**Metal Stage C: refine actual material:**
- Proposed **copper_ingot** recipe: `copper_ore ×2 + charcoal ×1 -> copper_ingot ×1`, **Smelter**, Processing ~25–30 (source Desert ~35).
- Proposed **iron_ingot** recipe: `iron_ore ×3 + charcoal ×2 -> iron_ingot ×1`, **Smelter/Bloomery**, Processing ~40–45. **Need an `iron_ore` item and a gated min-Tier ~45–50 iron node/island source.**
- Proposed **black_iron_ingot** (new item): `black_iron ×2 + charcoal ×2 -> black_iron_ingot ×1`, **advanced forge/smelter**, Processing ~55+, source Volcanic 60. Final-tier upgrade, not necessary for baseline Iron 50–60 weapons.
- **Steel** (optional after iron): `iron_ingot + charcoal` at upgraded forge plus fuel/time/processing requirements, outputs existing `steel_ingot` if adopted. Additional steps and carbon control are compressed gameplay abstractions.
- **Bronze**: existing `bronze_ingot` needs **tin ore or coherent trading/loot source** and copper/tin alloy recipe. **NOT a usable era until source exists.**

**Metal Stage D: meaningful outputs:** Copper enables reliable trigger/limb fittings, stronger armor components, metal-tipped spearpoints, forge-repair and improved durability. Iron unlocks tougher edge geometry, solid armor-breaking heads, chain links, larger crossbow mechanisms, heavier mass-bearing components and specialized attack properties. Dinosaur bone/tendon remains essential because metal has weight/material cost, and tension/wrap/bracing still benefits from biological materials.

**Metal Stage E: visible economy:** Different regions and dangerous hunts create **complementary supply chains**. Smelter fuel and transport/research matter; workers and player remain bound by individual equipment-level gates. Preserve current crafting level inherited from input materials and rare signed traits; high-level base recipes shouldn't be craftable by a new level-1 survivor simply buying iron.

## 5. Exact implementation backlog (THIS IS THE 'REMEMBER TO ADD' LIST)

**P0, MUST before claiming even stone/early set is complete:**
- **WPN-01** Add `sinew_shortbow` weapon item, recipe, equipped ranged aim/projectile, and `stone_arrows` ammo item/recipe; connect Range skill `bow_1` unlock to actual recipe and attack.
- **WPN-02** Add **combat** `stone_knife` recipe separate from shipped `stone_knife_work`; classify **DS**, implement appropriate valid melee Combo if intended.
- **WPN-03** Add `bone_spear` item/recipe (MP), reachable foot and mounted stab, mount alignment/Momentum mastery later.
- **WPN-04** Classify shipped `slingshot` as **DI**, `bone_hammer` as **MI**, `work_axe` as **MS**, add actual **D/M scaling** without overwriting existing `blunt/pierce/slashing` saves or current tool function; keep `stone_shot` as actual ammo.
- **WPN-05** Fix weapon equip gate and skill unlock so strict **person-level** and relevant crafting/ranged requirements are tested, not inferred from `max_level:60`.

**P1, MID hunter composite sets:**
- **WPN-06** Add `scute_staff_sling` (DI), `talon_whip` (DS), `scute_warhammer` (MI), `talon_war_lance` (MP), `obsidian_great_axe` (MS), complete recipes, unique animation/hit geometry/status roles.
- **WPN-07** Add `copper_crossbow` (DP), `bone_bolts` ammo and an actual reload/aim/projectile model; skill level ~35. **Blocked by metallurgy until WPN-08.**
- **WPN-08** Add Smelter/Furnace+Forge stations/kits and relevant recipes; enforce real `copper_ore` and `charcoal` inputs; item-level/Processing requirements. Replace generic workbench `ingot` placeholder so copper and iron require different source/mining/quality.
- **WPN-09** Optional forge **copper reinforcement** variants for the five Mid dinosaur-composite weapons, preserving individual crafted level, durability, provenance and signed item traits.

**P2, LATE iron and prestige weapons:**
- **WPN-10** Add **`iron_ore` item + harvest node + truly higher-tier source** in Tier ~45–50 world, with gear/gathering gate; enable ore rather than giving ingots as free loot. Ensure home/early temperate nodes don't spawn iron by accident.
- **WPN-11** Add `iron_ingot` process from `iron_ore+charcoal` at Smelter/Bloomery plus usable iron forging tools/station. The item itself already exists, but processing/source do NOT.
- **WPN-12** Add `iron_stonecaster` (DI), `iron_repeating_crossbow` (DP), `iron_talon_whip` (DS), `iron_war_lance` (MP), `iron_talon_greatblade` (MS), animations, actual player weapon hit/equip and ranged ammo. Make sure **Might** remains compelling late and rider height constrains reach.
- **WPN-13** Integrate existing **`raid_maul`** into MI late progression by **specific iron+scute+dense-bone recipe** or a new Scute-Core Iron Maul variant. Existing `raid_maul` generic `metal ×8` recipe is **not** the new proposed trophy-core crafting, and can be satisfied with wrong metal types.
- **WPN-14** Add genuine late reward `black_iron_ingot` item + Volcanic black iron refining and optional prestige upgrades; keep base iron weapons feasible without the level-60 volcanic material.

**P3, prestige creature drops and additional materials (NOT mandatory to build base 18):**
- **WPN-15** Add `ceratops_horn` drop item and species-appropriate Styracosaurus/Triceratops butcher source (rare), optional forged lance/charge tip upgrade.
- **WPN-16** Add `predator_tooth` drop item from appropriate large theropods (e.g. Allosaurus, Tarbosaurus and owner-confirmed tameable/rideable T. rex). Optional greatblade trophy variant.
- **WPN-17** Clarify `predator_tendon` = harvestable sinew in anatomy/codex. If requested, add a **bone glue/collagen** processed material from bone/hide; **do not invent an unsupported muscle fiber item** to simulate bow tension when tendon already exists. Raw meat remains food/animal feed.
- **WPN-18** Bronze requires `tin_ore` location/drop and bronze alloy recipe if bronze age desired. Steel needs iron/charcoal forge process. Neither is assumed to be shipped despite current ingot item IDs.
- **WPN-19** Test biome and creature drop source paths **in a real loaded world**; repair incorrect `nature_manifest` IDs and enforce rare butcher skill gates so crafted ingredient sources and progression aren't misleading.

**Engine contract caveats from inspected code:**
- Current `Crafting._plan()` matches **input categories**, not a required exact item ID; `prefer_id` biases selection but does **not strictly lock** it. Without a new `require_id` or a new required `category` on ingots/items, a recipe stating `iron_ingot ×2` **cannot** be enforced with broad `metal` category; copper/generic ingot may substitute. New strict slot validation is required for the tech gate.
- `max_level` is an upper cap on crafted item output, **not** a level unlock. `Crafting` has optional `min_level` and `required_survival`, but many current weapon recipes have no meaningful min gate. Use explicit player/skill checks and material provenance tests.
- New item IDs are NOT gameplay assets just because their names appear in this design chapter: need `items.json`, `recipes.json`, icons/animations, attack modes and physics, status and skill linking, loot/range availability, save tests and crafting UI support.
- Existing in-game metallurgy currently has just a generic workbench `ingot` recipe; **no Furnace/Smelter or Forge recipe rows/building kits are present**.
- A `bow` or `crossbow` mentioned in the historic [weapons doc](../design/weapons.md) or tree is a **planned unlock**, not currently a craftable weapon item. A `stone_knife` item does exist but has **no recipe for it**; the current improvised knife recipe outputs the work variant. `raid_maul` is already an item with a craft recipe, but **different ingredients** from the dinosaur-composite Iron Siege Maul proposal.

## 6. Gameplay and sourcing acceptance tests

1. **Home-only early crafting:** starting with no advanced stations, a player can gather branch/stone/fibre, hunt Compy/Zebraceratops, butcher, process twine/straps and craft six legitimate early-class weapons as their skill/item access unlocks. No nonexistent feathers/tooth/horn/mineral required for any **base early item**.
2. **Materials make sense:** tendon tension for strings/whips, bone/scute for stiff ribs/heads, hide straps for binding/grip, stone/obsidian for sharp brittle edges, metal for durable sharp edges, pivots and reinforced armor breaking.
3. **Mid early access:** five Tier25–34 composite weapons become feasible from real bone/scute/talon/obsidian sources with rare/field costs. Copper Crossbow visibly requires Tier35 desert ore, charcoal, smelting and smithing rather than just crafting at the starter workbench.
4. **Late source chain:** genuinely high-tier iron ore nodes, iron ingot smelting and shaped forging lead to all six Late weapons; no broad `metal` recipe allows an early copper/generic ingot to replace iron.
5. **Class combat:** each of DI/DP/DS/MI/MP/MS has an animated attack mode, real damage type, actual D/M IV scaling, correct armor matchups, weapon range and attack timing. Distinct move rewards **Longshot, Momentum, Combo/Frenzy, stagger, precision** matter and maintain equal-tier combat choices.
6. **Mount realism:** mounted spear hit depends on approach geometry; tall T. rex rider cannot sword-swing into a Compy far below; dinosaur attack is separate; rider+mount occupies one party slot.
7. **Metal feels different:** copper/iron weapons make more than a generic +damage number change, while nonmetal weapons still have early resource economy and situational high-tier roles when using great-quality dinosaur materials.
8. **Save/rarity/economy:** recipes consume real stacks and respect material trait provenance, output personal equip level and progression, durability/repair, no duplicative ammo/ingot loopholes, and clear status for incomplete content.

**THIS IS A PROPOSAL/BACKLOG.** None of these new items, stations, nodes, crafting recipes, status changes or weapon modes have been added to the game by writing this chapter.
