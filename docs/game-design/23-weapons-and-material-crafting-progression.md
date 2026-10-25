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

### Intermediate material processing: the NEW backbone of mid/late crafting

**Owner correction (2026-10-25): no final endgame weapon recipe may directly use raw `dense_bone`, `branch`, `raptor_talon`, `predator_tendon`, `raw_hide`, `wood_log`, `copper_ore`, `iron_ore`, or even unshaped `iron_ingot` as an assembly component.** Those belong upstream in **Processing, Tailoring, Carpentry, Lamination or Smithing**. Endgame weapons must assemble **processed parts** that represent manufactured wood, bone, sinew, hide and forged metal. Early primitive items intentionally still use crude gathered inputs. Mid composite weapons introduce worked wood, sinew and bone and First Copper. All named components **[ADD]** below are **NOT in `items.json` or `recipes.json`** unless marked **EXISTS**.

**Existing processing operations, verified in `recipes.json`:**
- `wood_log ×1 -> split_wood ×2`, Workbench (existing); `split_wood ×2 -> plank ×1`, Workbench (existing).
- `fibre_stalk ×2 -> twine ×1`, Hand (existing category `fibre`); `raw_hide ×1 -> dried_hide ×1`, Drying Rack (existing category `green_hide`).
- `dried_hide ×1 -> hide_strap ×2`, Workbench (**existing recipe accepts general `uncut_hide`, including raw hide**, so the stricter dried-hide path must be enforced for advanced crafting).
- `wood_log ×2 -> charcoal ×1`, existing general `burnable ×2` charcoal recipe. **Current item/recipe supports charcoal, but dedicated fuel rules for a new Smelter remain to implement.**

**NEW processed animal/wood items and exact proposed recipes:**

| Stage | Output item [ADD] | Inputs, counts and output | Processing station / requirement | Actual role |
|---|---|---|---|---|
| Mid | `binding_pitch` | `resin ×2 + charcoal ×1 -> binding_pitch ×2` | Campfire, Processing ~15 | Resin/charcoal adhesive for composite pieces; resin sourced from temperate/tundra pine |
| Mid | `carved_bone_rib` | `dense_bone ×2 + stone ×1 -> carved_bone_rib ×1` | Workbench, Processing ~20 | A truly shaped rigid bow prod, crosspiece, warhammer insert or tool rib |
| Mid | `sinew_cord` | `predator_tendon ×2 + twine ×1 -> sinew_cord ×1` | Workbench, Processing ~15 | Dried/twisted tension component; not loose muscle |
| Mid | `shaped_scute_plate` | `armor_scute ×2 + stone ×1 -> shaped_scute_plate ×1` | Workbench, Processing ~25 | Cut, trimmed protective scute plate that can be laminated into armor, tool guards and later a forged maul core |
| Mid | `honed_talon_set` | `raptor_talon ×2 + stone ×1 -> honed_talon_set ×1` | Workbench, Processing ~25 | Polished/cut piercing or cutting edge blanks. Rare talon supply stays meaningful |
| Mid | `treated_plank` | `plank ×2 + resin ×1 -> treated_plank ×2` | Drying Rack (resin coat + cure), Processing ~25 | Water/weather-resistant stiff structural wood |
| Mid | `cured_hide_binding` | `dried_hide ×1 + resin ×1 -> cured_hide_binding ×2` | Drying Rack, Processing ~25 | Better bindings/grip than green hide straps |
| Mid | `braided_sinew_cable` | `sinew_cord ×2 + binding_pitch ×1 -> braided_sinew_cable ×1` | Drying Rack or later Lamination Press, Processing ~35 | Repeatable high-tension string/cable for engineered launchers |
| Mid, Copper | `refined_copper_bar` | `copper_ingot ×1 + charcoal ×1 -> refined_copper_bar ×1` | **Forge [ADD]**, Processing ~30; copper ore must first be smelted | Heat-worked copper stock for small fittings |
| Mid, Copper | `copper_trigger_assembly` | `refined_copper_bar ×1 + carved_bone_rib ×1 + cured_hide_binding ×1 -> copper_trigger_assembly ×1` | Forge, Weapon/Tools ~35 | Crossbow trigger/sear and braced mechanical fittings, not a spring magically produced from raw copper |
| Late | `reinforced_bone_block` | `carved_bone_rib ×2 + binding_pitch ×1 + cured_hide_binding ×1 -> reinforced_bone_block ×1` | **Lamination Press [ADD]**, Processing ~40 | **Bone block**: shaped/interlocked bone laminated and bound as a shock-resistant core. Not literal molten bone |
| Late | `reinforced_stock` | `treated_plank ×2 + reinforced_bone_block ×1 + cured_hide_binding ×1 -> reinforced_stock ×1` | Workbench, Weapon/Tools ~45 | Rigid launcher/crossbow frame |
| Late | `reinforced_haft` | `treated_plank ×1 + carved_bone_rib ×1 + cured_hide_binding ×1 -> reinforced_haft ×1` | Workbench, Weapon/Tools ~40 | Maul/greatblade/chain-whip grip |
| Late | `long_lance_shaft` | `treated_plank ×3 + braided_sinew_cable ×1 + cured_hide_binding ×1 -> long_lance_shaft ×1` | Workbench, Weapon/Tools ~45 | Reinforced tall riding lance shaft, stiff and light relative to full metal |
| Late | `refined_iron_bar` | `iron_ingot ×2 + charcoal ×1 -> refined_iron_bar ×1` | **Forge [ADD]**, Processing ~45; iron ore -> iron ingot smelting first | **Refined metal bar**: consolidated/bloom-refined and reheated into workable metal stock, distinct from crude ingot |
| Late | `forged_iron_fittings` | `refined_iron_bar ×1 -> forged_iron_fittings ×2` | Forge, Weapon/Tools ~45 | Pins, ring fittings, reinforcement plates |
| Late | `iron_trigger_mechanism` | `refined_iron_bar ×2 + treated_plank ×1 -> iron_trigger_mechanism ×1` | Forge, Weapon/Tools ~50 | Stronger bow/sear/winding mechanism; no modern firearm needed |
| Late | `iron_bolt_magazine` | `refined_iron_bar ×1 + treated_plank ×1 -> iron_bolt_magazine ×1` | Forge, Weapon/Tools ~50 | Simple gravity-fed repeating-bolt channel (magazine refill/reload balanced separately) |
| Late | `iron_chain_links` | `refined_iron_bar ×2 -> iron_chain_links ×2` | Forge, Weapon/Tools ~50 | Controlled chain whip links with no unsafe use of raw ingots as finished weapon |
| Late | `forged_maul_head` | `refined_iron_bar ×3 + reinforced_bone_block ×1 + shaped_scute_plate ×1 -> forged_maul_head ×1` | Forge, Weapon/Tools ~50 | Iron striking shell over shock-managing dinosaur bone core |
| Late | `forged_spearhead` | `refined_iron_bar ×2 + honed_talon_set ×1 -> forged_spearhead ×1` | Forge, Weapon/Tools ~50 | Long metal point with fitted talon barb |
| Late | `forged_greatblade` | `refined_iron_bar ×3 + honed_talon_set ×1 -> forged_greatblade ×1` | Forge, Weapon/Tools ~50 | Forged blade with properly mounted talon tooth-barb edges (not bone substituted for steel) |
| Late, tools | `forged_iron_axehead` | `refined_iron_bar ×2 + reinforced_bone_block ×1 -> forged_iron_axehead ×1` | Forge, Weapon/Tools ~50 | Durable lumber axe blade assembly, distinct from greatblade |

**New processing stations and world dependencies:** existing Workbench/Drying Rack/Campfire suffice for many early and Mid components. **Forge, Furnace/Smelter and Lamination Press must be craftable/buildable, unlocked and recognized by `CraftStation`, with station-specific queue/nearby checks and processing costs**. A creature-only bone block can first be shaped at Workbench then laminated at a press. Metal needs **ore extraction -> furnace smelt into coarse ingot -> forge refinement into bar -> forge shaping of final functional component**. All endgame recipes below consume shaped components, never raw fossils or ore.

**Required crude-metal chain (currently incomplete):**
```text
Desert copper_ore x2 + charcoal x1
   -> [Smelter] copper_ingot x1
   -> + charcoal x1 [Forge] refined_copper_bar x1
   -> + carved_bone_rib + cured_hide_binding [Forge] copper_trigger_assembly

Higher-tier iron_ore x3 + charcoal x2  [iron_ore and source must be ADDED]
   -> [Smelter/Bloomery] iron_ingot x1
   -> x2 iron_ingot + charcoal x1 [Forge] refined_iron_bar x1
   -> [Forge: shape] iron fittings / trigger / magazine / chain / maul head / spearhead / blade

dense_bone -> carved_bone_rib -> + binding_pitch + cured_hide_binding
   -> [Lamination Press] reinforced_bone_block
wood_log -> split_wood -> plank -> + resin [Drying Rack] treated_plank
predator_tendon -> sinew_cord -> + binding_pitch [Drying Rack] braided_sinew_cable
raw_hide -> dried_hide -> + resin [Drying Rack] cured_hide_binding
raptor_talon -> + stone [Workbench] honed_talon_set
```

**Processing by specialized careers:** Butchering supplies rare quality bone/scute/talon/sinew, Gathering supplies lumber/ore/resin and fuel, Processing cures and laminates, Weapon/Tools shapes and assembles, Tailoring helps bind/grip, Construction builds workstations. The material level/provenance and rare traits need a defined inheritance rule through multi-stage processing so a high-quality talon doesn't turn into a generic level-one finished weapon. Processing quality should matter while avoiding unlimited repeated processing for infinite item levels.

### Mid game: worked dinosaur composites and first copper (suggested ~25–44)

| Code | Defining weapon (output id) | **Actual assembly recipe, now uses processed materials** | Status | Why it changes play |
|---|---|---|---|---|
| **DI** | **Scute Staff Sling** (`scute_staff_sling` **[ADD]**) | `carved_bone_rib ×1 + armor_scute ×1 + plank ×2 + sinew_cord ×1 + hide_strap ×1`; fires existing `stone_shot` | NEW weapon + intermediate processing items | Longer-range Impact, Longshot mastery |
| **DP** | **Copper-Trigger Crossbow** (`copper_crossbow` **[ADD]**) | `plank ×2 + carved_bone_rib ×2 + braided_sinew_cable ×1 + copper_trigger_assembly ×1 + cured_hide_binding ×1`; **Bone Bolts [ADD]**: `branch ×1 + raptor_bone ×1 + twine ×1 -> bone_bolts ×3` at workbench | NEW weapon/ammo; **real copper Smelter+Forge chain mandatory** | First high-force engineered Pierce shot with slow reload |
| **DS** | **Talon Whip** (`talon_whip` **[ADD]**) | `honed_talon_set ×1 + sinew_cord ×2 + hide_strap ×2 + plank ×1` | NEW; intermediate animal processing items | Dexterity control, repeated Slash, range/position |
| **MI** | **Scute Warhammer** (`scute_warhammer` **[ADD]**) | `carved_bone_rib ×2 + armor_scute ×3 + plank ×2 + hide_strap ×2` | NEW; worked bone, scute and processed wood | Impact control and armored target stagger |
| **MP** | **Talon War Lance** (`talon_war_lance` **[ADD]**) | `carved_bone_rib ×1 + honed_talon_set ×1 + plank ×2 + sinew_cord ×1 + hide_strap ×1` | NEW; rare talons/prepared point and weapon shaft | Mounted Momentum Strike with serious Pierce reach |
| **MS** | **Obsidian Great Axe** (`obsidian_great_axe` **[ADD]**) | `obsidian ×2 + carved_bone_rib ×1 + plank ×2 + hide_strap ×2 + sinew_cord ×1` | NEW; obsidian is a **raw cutting head** until worked directly into an axe, acceptable for MID | Big Slash combo, brittle but sharp |

**Mid-era exception:** `armor_scute` and `obsidian` can be consumed in a worked composite weapon at this tier. **By Late, use fully shaped components**, with scutes captured within cores or forging and talons pre-honed rather than raw natural drops in the last assembly step. If desired later, add `shaped_scute_plate` as an optional Mid processing component, but it is not required to unblock the 18 baseline designs.

**Mid sourcing:** Existing Compy and Zebraceratops provide bone/tendon/scutes for initial progression; Temperate provides pine `resin`; Tropical Tier25 has obsidian; rare raptor talon from Velociraptor and beyond. Copper from Desert Tier35 can only be used after proper smelting+refining; five other Mid weapons stay available without metal so the transition remains satisfying.

### Late game: forged shaped metal + reinforced dinosaur composites (suggested ~45–60)

**Critical late-game rule:** The final weapon assembly contains **processed components only**, with neither raw resources nor coarse `iron_ingot` consumed at the last step. Iron ore currently lacks an item/source. `iron_ingot` item is already defined but not genuinely smeltable in a specific iron process, and `refined_iron_bar` plus downstream parts are entirely new. The following six weapon recipes replace earlier direct iron-ingot/raw-dinosaur recipes.

| Code | Defining weapon (output id) | **Final assembly input list (all processed components)** | Implementation dependencies | Weapon role |
|---|---|---|---|---|
| **DI** | **Iron Torsion Stonecaster** (`iron_stonecaster` **[ADD]**) | `forged_iron_fittings ×2 + reinforced_stock ×1 + braided_sinew_cable ×2 + reinforced_bone_block ×1 + cured_hide_binding ×1`; uses `stone_shot` ammo | NEW item/recipe/attack + processed stock/metal fittings | Precise long-range Impact and Longshot |
| **DP** | **Iron Repeating Crossbow** (`iron_repeating_crossbow` **[ADD]**) | `iron_trigger_mechanism ×1 + iron_bolt_magazine ×1 + reinforced_stock ×1 + braided_sinew_cable ×2 + cured_hide_binding ×1`; `bone_bolts` / new iron bolts | NEW item/recipe/bolt delivery + forge and magazine | Accurate multi-bolt Pierce; longer magazine refill |
| **DS** | **Iron Talon Chain Whip** (`iron_talon_whip` **[ADD]**) | `iron_chain_links ×2 + honed_talon_set ×2 + braided_sinew_cable ×1 + reinforced_haft ×1 + cured_hide_binding ×2` | NEW item/recipe/chain weapon animation | Controlled Slash reach and timed consecutive-hit combos |
| **MI** | **Scute-Core Iron Siege Maul** (existing `raid_maul`, **UPGRADE RECIPE**) | `forged_maul_head ×1 + reinforced_haft ×1 + cured_hide_binding ×2` | `raid_maul` item exists, but generic `metal ×8` recipe must be replaced, gated or made a legacy low-tier variant | Crushing Impact vs armored dinosaurs |
| **MP** | **Forged War Lance** (`iron_war_lance` **[ADD]**) | `forged_spearhead ×1 + long_lance_shaft ×1 + cured_hide_binding ×2` | NEW item/recipe/extended physical mounted-hit geometry | Heavy braced Pierce, true movement Momentum Strike |
| **MS** | **Iron Talon Greatblade** (`iron_talon_greatblade` **[ADD]**) | `forged_greatblade ×1 + reinforced_haft ×1 + cured_hide_binding ×2 + honed_talon_set ×1` | NEW item/recipe/Slash Combo + refit geometry | Masterwork heavy Slash with sustained combos |

**Example endgame player-visible craft tree: Iron Talon Greatblade**
```text
Mine iron_ore -> charcoal smelt -> iron_ingot -> forge refine -> refined_iron_bar
                -> forge greatblade with pre-honed talons -> forged_greatblade
Hunt raptors -> rare raptor_talon -> hone/polish -> honed_talon_set
Hunt ceratopsians -> dense_bone -> carve -> carved_bone_rib
Gather wood -> split -> plank -> resin treat -> treated_plank
Gather hide -> drying rack -> dried_hide -> resin cure -> cured_hide_binding
Treated plank + carved bone rib + cured hide binding -> reinforced_haft
Assembly: forged_greatblade + reinforced_haft + cured_hide_binding + honed_talon_set
   -> IRON TALON GREATBLADE (MS)
```

**Quality/economy:** Rare large dinosaur materials can yield higher-level/more durable components with appropriate skills, but the weapon should have a coherent **material contribution and cap** after processing. An iron weapon needs the chain for metal parts as well as biological parts, not merely one iron ingot in a cosmetic slot. Progressing into refined metal means players now coordinate mining, charcoal burning, furnace smelting, forge refining, specialized shaping, lamination and assembly.

**Endgame tech ceiling:** This is all achievable in a mostly primitive iron-age/advanced workshop civilization. No rocket launchers, mechs, modern ammo factories or miniguns required.

## 2A. Work tools follow the same material eras, without becoming additional weapon classes

The user also wants **tools** made from dinosaur materials and stone/wood. These are **civilian/work progression examples**, separate from the **18 defining combat weapons**. Do not multiply the six combat classes by every mining/skin-gathering variant.

| Stage | Work tool | Exact proposed ingredient example | Status and why this matters |
|---|---|---|---|
| **Early** | **Stone Work Knife** (`stone_knife_work`) | `stone ×1 + branch ×1 + twine ×1` | **Existing item + hand recipe** (generic `blade_mat, handle, lashing`); harvest plants and process hides |
| **Early** | **Stone Pick** (`work_pick`) | `stone ×1 + branch ×1 + twine ×1` | **Existing item + workbench recipe**; enables progression to stone/clay and ultimately ore nodes |
| **Mid** | **Raptor Talon Skinning/Combat Knife** (`barbed_knife`) | `raptor_talon ×1 + branch ×1 + hide_strap ×1` | **Existing item + workbench recipe**. Has `tool_class: knife` and bleed-capable weapon stats; verify its actual harvest-tool ability in gameplay before advertising as improved skinning yield |
| **First copper** | **Copper Quarry Pick** (`copper_pick` **[ADD]**) | `refined_copper_bar ×2 + carved_bone_rib ×1 + plank ×1 + hide_strap ×2` | **New tool/recipe after copper Smelter + Forge and shaped bone**. Copper pick is durable vs stone, but should not simply be the best iron-mining tool; tune tier and ore hardness instead of an implausible copper-beats-all progression |
| **Late** | **Iron Quarry Pick** (`iron_quarry_pick` **[ADD]**) | `forged_iron_fittings ×2 + reinforced_haft ×1 + reinforced_bone_block ×1 + cured_hide_binding ×1` | **New item/recipe after bone lamination + iron forge**; enables effective hard-rock and higher-level frontier mining |
| **Late** | **Iron Lumber Axe** (`iron_lumber_axe` **[ADD]**) | `forged_iron_axehead ×1 + reinforced_haft ×1 + cured_hide_binding ×1` | **New item/recipe and forged shaped axehead**. Longer durability and higher resource throughput while retaining the living wood/hide/bone supply chain |

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
| `resin` | Existing PineTree/PineTree_Snow harvesting in temperate/tundra, required for pitch and treated wood | Mid processing expeditions; verify node spawn at intended tier |
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

**Metal Stage D: refine and shape:** Copper `copper_ingot -> refined_copper_bar -> copper_trigger_assembly`. Iron `iron_ingot -> refined_iron_bar -> forged_iron_fittings / iron_trigger_mechanism / iron_bolt_magazine / iron_chain_links / forged_maul_head / forged_spearhead / forged_greatblade`. Copper enables reliable trigger/limb fittings, stronger armor components and forge repair. Iron unlocks tougher edge geometry, solid armor-breaking heads, chain links, larger crossbow mechanisms, heavier mass-bearing components and specialized attack properties. **The late weapon recipes consume these forged parts and worked organic materials only.** Dinosaur bone/tendon remains essential because metal has weight/material cost, and tension/wrap/bracing still benefits from biological materials.

**Metal Stage E: visible economy:** Different regions and dangerous hunts create **complementary supply chains**. Smelter fuel and transport/research matter; workers and player remain bound by individual equipment-level gates. Preserve current crafting level inherited from input materials and rare signed traits; high-level base recipes shouldn't be craftable by a new level-1 survivor simply buying iron.

## 5. Exact implementation backlog (THIS IS THE 'REMEMBER TO ADD' LIST)

**Processing chain priority:** The user now expressly requires advanced weapons and tools to use **finished components, not raw material piles**. This expands the WPN backlog with **WPN-21..WPN-24** for reusable production recipes and station tech. **The final six rows above are now authoritative** for all late-game weapon ingredients. Earlier versions which used coarse `iron_ingot`, `dense_bone`, `predator_tendon`, `branch` or `raptor_talon` directly in a final Late recipe are superseded.

**P0, MUST before claiming even stone/early set is complete:**
- **WPN-01** Add `sinew_shortbow` weapon item, recipe, equipped ranged aim/projectile, and `stone_arrows` ammo item/recipe; connect Range skill `bow_1` unlock to actual recipe and attack.
- **WPN-02** Add **combat** `stone_knife` recipe separate from shipped `stone_knife_work`; classify **DS**, implement appropriate valid melee Combo if intended.
- **WPN-03** Add `bone_spear` item/recipe (MP), reachable foot and mounted stab, mount alignment/Momentum mastery later.
- **WPN-04** Classify shipped `slingshot` as **DI**, `bone_hammer` as **MI**, `work_axe` as **MS**, add actual **D/M scaling** without overwriting existing `blunt/pierce/slashing` saves or current tool function; keep `stone_shot` as actual ammo.
- **WPN-05** Fix weapon equip gate and skill unlock so strict **person-level** and relevant crafting/ranged requirements are tested, not inferred from `max_level:60`.

**P1, MID hunter composite sets:**
- **WPN-06** Add `scute_staff_sling` (DI), `talon_whip` (DS), `scute_warhammer` (MI), `talon_war_lance` (MP), `obsidian_great_axe` (MS), complete recipes, unique animation/hit geometry/status roles.
- **WPN-07** Add `copper_crossbow` (DP), `bone_bolts` ammo and an actual reload/aim/projectile model; skill level ~35. **Blocked by metallurgy until WPN-08.**
- **WPN-08** Add Smelter/Furnace+Forge stations/kits and **`refined_copper_bar`, `copper_trigger_assembly` processes**; enforce real `copper_ore`, `copper_ingot`, `charcoal` and processed bone/hide inputs; item-level/Processing requirements. Replace generic workbench `ingot` placeholder so copper and iron require different source/mining/quality.
- **WPN-09** Optional forge **copper reinforcement** variants for the five Mid dinosaur-composite weapons, preserving individual crafted level, durability, provenance and signed item traits.

**P2, LATE iron and prestige weapons:**
- **WPN-10** Add **`iron_ore` item + harvest node + truly higher-tier source** in Tier ~45–50 world, with gear/gathering gate; enable ore rather than giving ingots as free loot. Ensure home/early temperate nodes don't spawn iron by accident.
- **WPN-11** Add `iron_ingot` process from `iron_ore+charcoal` at Smelter/Bloomery, then `refined_iron_bar` from `iron_ingot+charcoal` at Forge, then shaped weapon-part recipes. The item itself already exists, but processing/source do NOT.
- **WPN-12** Add `iron_stonecaster` (DI), `iron_repeating_crossbow` (DP), `iron_talon_whip` (DS), `iron_war_lance` (MP), `iron_talon_greatblade` (MS) with FINAL ASSEMBLY consuming only intermediate worked materials, animations, actual player weapon hit/equip and ranged ammo. Make sure **Might** remains compelling late and rider height constrains reach.
- **WPN-13** Integrate existing **`raid_maul`** into MI late progression by a **`forged_maul_head + reinforced_haft + cured_hide_binding` final assembly** or new Scute-Core Iron Maul variant. Existing `raid_maul` generic `metal ×8` recipe is **not** the new proposed trophy-core crafting, and can be satisfied with wrong metal types.
- **WPN-14** Add genuine late reward `black_iron_ingot` item + Volcanic black iron refining and optional prestige upgrades; keep base iron weapons feasible without the level-60 volcanic material.

**P3, prestige creature drops and additional materials (NOT mandatory to build base 18):**
- **WPN-15** Add `ceratops_horn` drop item and species-appropriate Styracosaurus/Triceratops butcher source (rare), optional forged lance/charge tip upgrade.
- **WPN-16** Add `predator_tooth` drop item from appropriate large theropods (e.g. Allosaurus, Tarbosaurus and owner-confirmed tameable/rideable T. rex). Optional greatblade trophy variant.
- **WPN-17** Clarify `predator_tendon` = harvestable sinew in anatomy/codex. If requested, add a **bone glue/collagen** processed material from bone/hide; **do not invent an unsupported muscle fiber item** to simulate bow tension when tendon already exists. Raw meat remains food/animal feed.
- **WPN-18** Bronze requires `tin_ore` location/drop and bronze alloy recipe if bronze age desired. Steel needs iron/charcoal forge process. Neither is assumed to be shipped despite current ingot item IDs.
- **WPN-19** Test biome and creature drop source paths **in a real loaded world**; repair incorrect `nature_manifest` IDs and enforce rare butcher skill gates so crafted ingredient sources and progression aren't misleading.

**P0/P1/P2 cross-tier processing pipeline, NEW required tracked additions:**
- **WPN-21** Add **all new processed component item definitions and recipes**: `binding_pitch`, `carved_bone_rib`, `sinew_cord`, `shaped_scute_plate`, `honed_talon_set`, `treated_plank`, `cured_hide_binding`, `braided_sinew_cable`, `reinforced_bone_block`, `reinforced_stock`, `reinforced_haft`, `long_lance_shaft`. Make sure input IDs are real, the outputs use correct categories and downstream recipes can't substitute raw variants.
- **WPN-22** Add actual **refined bars and shaped metal component** definitions/recipes: `refined_copper_bar`, `copper_trigger_assembly`, `refined_iron_bar`, `forged_iron_fittings`, `iron_trigger_mechanism`, `iron_bolt_magazine`, `iron_chain_links`, `forged_maul_head`, `forged_spearhead`, `forged_greatblade`, `forged_iron_axehead`. Each metal part must depend on forged bar and every bar on the correct smelted ingot; do not smelt metal at Workbench.
- **WPN-23** Add **Lamination Press** as a craftable building/station for reinforced bone blocks; complete build/unlock and proximity/UI/recipe flow for **Smelter and Forge**. Existing Workbench, Drying Rack and Campfire handle earlier steps; ensure processing/Tool/Career skill tree gates and proper processing work time/fuel. Do not force all intermediate steps to invent separate stations unnecessarily.
- **WPN-24** **Recipe integrity/economic chain validation:** enforce exact-item and material-stage requirements, audit all dependency edges, prevent raw bone/ore/log substitution at late final assembly, carry level/quality attributes through multi-stage inputs, avoid unlimited reprocessing level inflation, balance refining yields/craft times/fuel, and test ore/charcoal/wood resin/butchery supply and accessibility at intended unlock level. Ensure final six Late recipes consume **only prepared parts**, not coarse ingots or raw loot. Update tool recipes (`copper_pick`, `iron_quarry_pick`, `iron_lumber_axe`) to follow same principle.

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
4. **Late source chain:** genuinely high-tier iron ore nodes -> specific iron ingot smelting -> refined iron bar -> forged functional head/trigger/fittings; dinosaur dense bone -> worked ribs -> laminated bone block; logs -> split wood -> planks -> cured/treated stock; tendon -> braided sinew, hide -> cured bindings. **No raw bone, log, ore, talon, tendon or simple ingot in final late-weapon assembly.** These chains lead to all six Late weapons; no broad `metal` recipe allows an early copper/generic ingot to replace iron.
5. **Class combat:** each of DI/DP/DS/MI/MP/MS has an animated attack mode, real damage type, actual D/M IV scaling, correct armor matchups, weapon range and attack timing. Distinct move rewards **Longshot, Momentum, Combo/Frenzy, stagger, precision** matter and maintain equal-tier combat choices.
6. **Mount realism:** mounted spear hit depends on approach geometry; tall T. rex rider cannot sword-swing into a Compy far below; dinosaur attack is separate; rider+mount occupies one party slot.
7. **Metal feels different:** copper/iron weapons make more than a generic +damage number change, while nonmetal weapons still have early resource economy and situational high-tier roles when using great-quality dinosaur materials.
8. **Save/rarity/economy:** recipes consume real stacks and respect material trait provenance, output personal equip level and progression, durability/repair, no duplicative ammo/ingot loopholes, and clear status for incomplete content.

**All exact processing outputs, quantities, unlock levels and new station names are design proposals requiring implementation. Existing split-wood/plank/charcoal/drying stages are verified data, but advanced bone blocks/treated planks/refined bars and processed final assemblies are NOT currently craftable.**

**THIS IS A PROPOSAL/BACKLOG.** None of these new items, stations, nodes, crafting recipes, status changes or weapon modes have been added to the game by writing this chapter.

**Important trait-specific refinement, 2026-10-25:** The owner's preferred `2× material -> 1× processed component` mechanic must **absorb BOTH input lots' positive AND negative trait records**. The existing `carved_bone_rib ×2` into `reinforced_bone_block`, `sinew_cord ×2` into `braided_sinew_cable`, and `iron_ingot ×2` into `refined_iron_bar` are natural two-primary-input trait-fusion opportunities. A hypothetical extra `2 treated_plank -> 1 composite_plank` and `2 refined_iron_bar -> 1 masterwork_iron_billet` are optional further stages; do not create unlimited free recursive fusion or bypass shaped part recipes. **Two different traits coexist; duplicate same-ID trait effects merge with diminishing capped return; negatives also carry**. Current `Crafting.build_output()` copies `primary.attributes` only, which would **lose the secondary source's rare trait**; new deterministic all-input merge/provenance and UI preview required before claiming this mechanic implemented. [Canonical fusion and perk catalog, including food and buildings](05-material-level-traits-and-loot.md).

**New defensive-turret ammo expansion (2026-10-25):** The owner wants **automatic and assigned-tribe-crewed turrets**, each requiring real finite ammo or wound mechanism charges, not infinite free firing. [24 Turrets/Ammo/Crews](24-turrets-siege-ammunition-and-guard-crews.md) proposes **`sharpened_stake_bundle`, `bone_ballista_bolt`, `iron_bolt_bundle`, `iron_harpoon_bolt`, `shaped_siege_stone`** and durable but wearing blade/ram charges (NEW item/recipe defs), sourced through this chapter's actual plank→treated plank, bone→carved rib, tendon→sinew, iron ore→smelted ingot→refined bar→forged tip chain. Existing `stone_shot` and `toxin_pot` are shipped and manually fired through `FieldCatapult`; existing player-only catapult is **not automatic** and its operator is not yet an AI tribe human. Turret construction/packing uses [08 Building](08-blueprints-worksites-and-building.md), especially BUILD-13/14 unique manufactured tradeable building instances. Full implementation tasks TURRET-01..12 in 24; no new recipes coded.
