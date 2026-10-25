# 05 | Material levels, signed traits, fusion, food, buildings and persistent quality

**Status, 2026-10-25:** OWNER INTENT + PROPOSED DETAILED CATALOG / MATH, not currently shipped trait mechanics and not an owner-approved numeric balance table. Owner direction: most individual gathering/butchering **lots contain consequential negative traits**; rare positive traits become valuable; **durable equipment and buildings** are the most desirable long-term trait investments; **cooking matters** through immediately useful Energy/temporary buffs. **LATEST OWNER IDEA:** a processing operation should let a player **combine TWO material batches into ONE output and inherit BOTH batches' positive and negative traits**. Preserve this key fantasy in implementation, with controlled repeatability to prevent infinite multiplication.

Related: [Systems vision and open decisions](../design/2026-10-25-systems-vision-and-open-decisions.md), [18 weapons / multi-stage processing](23-weapons-and-material-crafting-progression.md), [blueprint worksite contract](../design/world-design.md), [Tribe, workers and charmed trait hunting](../design/tribe-lineage-domain-and-labor.md), [Armor and weight](22-dinosaur-mass-armor-and-grappling.md), [economy](../design/economy.md). Existing code/data: [`ItemStack`](../../game/scripts/items/item_stack.gd), [`Crafting.build_output`](../../game/scripts/items/crafting.gd), [`HarvestNode`](../../game/scripts/world/harvest_node.gd), [`Food`](../../game/scripts/items/food.gd), [food buffs](../../game/data/food_buffs.json), [recipes](../../game/data/recipes.json).

## 1. Material identity versus rolled signed traits

- **Base material identity** (`def_id`: stone, dense bone, talon, wood, meat, copper ore, etc.), **level**, **tier** and **source/biome/harvest lot** are NOT rare perks. A level-50 piece is better on progression grounds even if imperfect.
- A **trait** is a named, signed effect with eligibility, magnitude, clear source and conditions. Positive traits are rare; **drawbacks usually appear on harvested lots**; good lots can have mixed good and bad. A lot means one coherent haul/harvest or butchering outcome, not each single bone getting a unique random stack.
- Player inventory needs trait sign, **actual computed effect**, matching compatible downstream outputs and warning whether a desirable material will be consumed as primary/secondary. Identical-level resources with different traits are different assets.
- Physical reality matters: `Dense` adds mass and helps Impact; `Springy` is for limb/tension components; `Nutrient-Rich` is for edible ingredients; `Low-Inclusion` ore improves forge outputs, not instant combat force while raw.
- For rare loot-targeting charms, the user accepts the idea of **biasing chance of a named beneficial trait**. Whether “+20% chance” is relative probability or +20 percentage points is **not decided**. No hidden reroll on saves, transfer or display.

## 2. NEW core processing mechanic: two materials -> one composite that absorbs both trait signatures

### 2.1 Player-facing rule

**Combine 2 eligible inputs into 1 more advanced material.** Consume both inputs, transfer **ALL eligible named positive AND negative traits from both sources into the resultant component**, and show them together in the craft preview. Do not discard an excellent secondary input simply because the recipe names one as “primary.” The result is special precisely because the player sourced **both** input lots.

| Processing recipe example | Material A, rolled signature | Material B, rolled signature | Finished composite with BOTH |
|---|---|---|---|
| **Bone Lamination: `2 carved_bone_rib -> 1 reinforced_bone_block`**, plus an optional binding catalyst | `Resilient +` | `Shock-Absorbent +` | `Resilient +` AND `Shock-Absorbent +`; excellent durable hammer core or stiff weapon stock |
| **Bone Lamination with a flaw** | `Resilient +` | `Brittle -` | `Resilient +` AND `Brittle -`; improved hit resistance but imperfect fracture durability, not free purification |
| **Wood Lamination: `2 treated_plank -> 1 composite_plank` [NEW]** | `Straight-Grained +` | `Rot-Resistant +` | Accurate launcher stock/strong structure timber retaining both traits |
| **Bar Consolidation: `2 refined_iron_bar -> 1 masterwork_iron_billet` [NEW]** | `Low-Inclusion +` | `Edge-Retaining +` | Advanced forging blank retaining both, later shaped into a metal weapon head |
| **Cord Braiding: `2 sinew_cord -> 1 braided_sinew_cable`** | `Elastic +` | `High-Tension +` | Higher-quality cable, both mobility/recovery and draw-force potential |
| **Cooked Food Combination: `meat + herb -> 1 herbed_meal`** | `Nutrient-Rich +` | `Aromatic +` | One consumable with better Energy and buff effect/duration within a cap, not permanent weapon-style traits |

**Stage distinction:** Bone/wood/tendon/iron processing can be `2-to-1`, then include small catalyst quantities of cured binding, pitch, resin, charcoal, etc. The term “two into one” refers to **two primary trait-bearing material lots**, not a ban on catalysts. If the recipe uses an additional trait-bearing functional ingredient, give its effect a defined contribution rather than silently stripping it.

**Compatibility:** Similar materials can be **fused** when a corresponding recipe exists (bone+bone; plank+plank; iron bar+iron bar). Different materials can be **assembled** into mixed composites with role-specific inheritance (wood+bone into reinforced stock; hide+wood into covered handle; scute+bone into armor core), but no nonsensical general recipe that merges meat into iron or arbitrary inventory materials into a universal material. Current `reinforced_bone_block` in chapter 23 already has `carved_bone_rib ×2` and catalysts; this is its intended trait-fusion step.

### 2.2 Crucial behavior: full inheritance does not mean unlimited stacking

1. **Two distinct trait IDs:** preserve both signatures. If `Resilient +` and `Shock-Absorbent +`, both are present, with source provenance.
2. **Both signs:** `Resilient +` and `Brittle -` BOTH survive as distinct traits. Do not turn “better” material into free negative purification. Skilled processing may reduce a drawback only if the recipe explicitly grants a known purification outcome/cost.
3. **Same trait in both input lots:** preserve two contributor records, but merge into **ONE displayed trait entry** and apply **diminishing returns** and a hard value cap. **Illustrative ONLY:** stronger magnitude + 25% of weaker magnitude, capped per trait. The 25% is a candidate, not approved. Negative duplicates also aggregate; a defect does not magically benefit from stacking. Avoid full `+10% +10% -> +20%` every repeated fusion layer.
4. **Input provenance / lineage:** each original material lot has an ID/signature; if one original lot's effects were already fused and later contribute again to the same product lineage, count its trait effect only **once**. No cloning via splitting/reprocessing, repairs, undoing assemblies, conversion loops or repeated ingredient transfers.
5. **Recipe tiers and legitimate stage transitions:** DO NOT allow a generic `composite + composite -> composite` recipe with no cap. A finite production DAG is allowed: `raw bone -> carved ribs -> reinforced block -> weapon`. New higher-tier composite recipes can fuse when explicitly designed; no arbitrary infinite fusion depth or craft-output multiplier.
6. **Stat relevance and bounded expression:** the composite **retains the source trait records**, but a finished object's displayed numeric effects depend on actual component role and a final-stat cap. Sharp talon on a greatblade edge affects Slash; a decorative talon on a hammer shaft shouldn't. Wood Straight-Grained may affect bow accuracy and a building's framing strength by distinct allowed-effect mappings.
7. **Quality/level:** keep the game's material-level progression separate from traits. Output level is derived deterministically from input levels, recipe cap and relevant craft skill; fusion should not elevate levels through repeated recycling. Trait magnitude/strength is stored and not rerolled during fusion.
8. **Quantity/tradeoff:** consuming two valuable ingredients for one component is an actual rare-material sink. Processing time, fuel, worker skill and finished durability/cargo volume determine economic cost; never produce one extra free copy of each source rare attribute.

**Authoritative requirement overriding current code behavior:** Current `Crafting.build_output()` copies `primary.attributes` onto the output, ignoring the nonprimary traits for inheritance. This is **NOT compliant** with the owner's new two-input fusion requirement. It must be revised to inspect all consumed ingredient *lots*, merge compatible trait records in a deterministic bounded routine, and save them in the output. Do not simply `Dictionary.merge()` because equal trait keys collide, negatives disappear and provenance is lost.

**Suggested data contract (not final serialization):**
```json
{
  "def_id": "reinforced_bone_block",
  "level": 41,
  "process_stage": "laminated_bone",
  "traits": [
    {"id":"resilient","sign":"+","magnitude":0.08,"source_lot":"lot_a"},
    {"id":"shock_absorbent","sign":"+","magnitude":0.06,"source_lot":"lot_b"},
    {"id":"brittle","sign":"-","magnitude":0.04,"source_lot":"lot_b"}
  ],
  "provenance": ["lot_a","lot_b"],
  "recipe_id": "laminate_bone_block"
}
```

Record roll seeds or stable lot signatures and contributor IDs compactly. This is an **illustration**, not a demand for literal unbounded arrays of all ancestor materials in every stack. Test stacking, lock status, save/load and transfer for identical fusion signatures. Effects must be calculated once per output stat from the saved aggregate, not once for every source record every time the item is loaded.

### 2.3 What the user should see

```text
Bone Lamination           [Lamination Press]
[ Carved Bone Rib lv41 ]      Resilient +8%
[ Carved Bone Rib lv40 ]      Shock-Absorbent +6%, Brittle -4%

Requires: 1 Binding Pitch (catalyst)
OUTPUT: Reinforced Bone Block lv40
  + Resilient
  + Shock-Absorbent
  - Brittle
Preview: Hammer core Durability +...; Impact mitigation +...; flaw -...
```
Player must be able to select **specific lots**, not have recipe auto-spend the rarest component, and should be warned before fusing locked/rare goods. Do not show a material's final weapon effect until the player knows which actual weapon component slot it occupies; ingredient traits can be dormant for inappropriate output types but traceable in Details.

## 3. Equipment, tools, weapons and dinosaur armor: proposed positive trait catalog

**Existing list from owner's preceding discussion, now organized by eligible component rather than universally random bonuses.** This is a **PROPOSED catalog**; none of these percentages or named perk effects are approved runtime rules.

| Named positive perk | Eligible materials/components | Effect on appropriate output |
|---|---|---|
| **Dense** | stone, bone, heavy core | Increased landed Impact/stagger and carried mass (slower handling/encumbrance tradeoff) |
| **Fine-Grained** | stone, obsidian | Better cutting edge retention/durability |
| **Straight-Grained** | lumber and treated plank | Better bow/sling accuracy or structural frame integrity |
| **Springy** | suitable bow wood | Better bow prod tension/recovery; prone to excessive flex at overdraw if relevant |
| **Resin-Rich** | wood/resin-bearing gather | More useful protective pitch/finish yield or longer weather resistance |
| **Resilient** | bone, wood, forged parts | Better shock/durability behavior in structural or weapon cores |
| **Shock-Absorbent** | bone, padding, dense composite | Lower local Impact wear/force transmitted through armor/bracing |
| **Thick-Plated** | scutes, heavy hide | More effective armor coverage/stability, **higher actual mass** |
| **Interlocking** | scutes and fitted plates | Better physical Slash/Pierce protection over valid equipped area |
| **Razor-Edged** | talons, teeth, actual cutting blade | More effective Slash hits to suitable targets |
| **Needle-Pointed** | teeth/horns/spikes | Better Pierce performance if used as functional point |
| **Barbed** | claws/horns/teeth | Better bleeding wound buildup on actual Pierce/Slash valid contact |
| **High-Tension** | tendon, sinew cord/cable | More bow/crossbow energy and durable binding capacity |
| **Elastic** | fibers and sinew | Faster weapon recovery or more reliable tension return |
| **Supple** | properly treated hide | Less armor movement/turning penalty |
| **Thick-Hided** | hide | Better cover, with greater mass |
| **Insulating** | hide, fur, padding | Cold-weather protection for wearer and housing if used as insulation |
| **High-Yield** | ore | More usable metal per refining batch, **spent at refinement**, not a permanent +damage perk |
| **Low-Inclusion** | ore or metal bar | Cleaner refined metal and higher final part durability |
| **Edge-Retaining** | forged edged metal | Blades stay effective longer; reduce damage loss from wear |

**Common negative counterpart ideas:** Brittle (fractures/breaks faster), Fractured (less structural force), Dull (lower Slash), Blunted (less Pierce), Warped/Knotted (accuracy, handling and beam defects), Rotting (durability), Frayed (tension), Rigid (armor movement cost), Cracked (scute protection), Porous (weather damage), Impure/Slag-Ridden (forge yield/quality), Degraded (processing loss). Negative traits should not all be silently converted to one generic durability penalty.

## 4. COOKING: food perks and drawbacks

**Player fantasy:** gather uncommon delicious/nutritious/medicinal ingredients; choose **two or more real ingredients** in the Crock Pot, Grill, Smoker or other appropriate station; make an actual dish with a predictable Energy value and a **short-lived buff**. Long-term trait-hunting still prioritizes durable equipment/buildings: food should not require five clicks of min-maxing every meal.

**Verified today:** `game/data/recipes.json` has `camp_stew` (meat+herb+fruit), `seasoned_roast`, `herbed_meal`, `spiced_skewer`, jerky/smoke/steam/grill variants. `game/data/food_buffs.json` defines **Gather Haste** (`gather_speed`), **Sturdy Meal** (`defense`), **Warming Meal** (`cold_resist`) and **Cooling Meal** (`heat_resist`). The food engine restores Energy, has raw/poisoned checks and permits `food_buff` attributes; it does **not** implement the following named signed ingredient-trait conversions or multi-trait dish inheritance.

### Food positives (proposed, new catalog)

| Food trait | Sources / examples | Concrete cooked effect | Caveat |
|---|---|---|---|
| **Nutrient-Rich** | dinosaur meat, berries, tubers | More Energy restored by final dish | Immediate effect, not permanent IV/level |
| **Aromatic** | herbs, spices, fragrant berries | Longer duration of an existing compatible meal buff | Does not give every buff in the game |
| **Hearty** | rich meat, hearty root | More Energy and/or longer Full status/less need to eat again | Must not permanently increase max HP |
| **Fresh** | fruit, recently butchered meat | Lower spoiled/poisoned risk for uncooked or stored input | Effects disappear after spoilage threshold |
| **Warming** | pungent herbs/spice | Stronger or longer **Warming Meal** (`cold_resist`) | Applies only where recipe makes the warming buff |
| **Cooling** | cooling fruit, herbs | Stronger or longer **Cooling Meal** (`heat_resist`) | Weather resistance remains conditional |
| **Fortifying** | specific meat/herbs | Improves existing **Sturdy Meal** (`defense`) magnitude/duration | Resist permanent defense inflation |
| **Invigorating** | strong herbs/berries | Improves compatible **Gather Haste** duration or Energy recovery | Existing food-buff hooks, not new speed stat |
| **Pure** | clean water, clean herbs | Reduced sickness/contamination chance in final dish | Raw danger not always fully neutralized |
| **Preservable** | dry meat, low-moisture produce, salt-friendly ingredients | Longer ingredient/dish spoilage time **when spoilage exists** | **Spoilage is not yet a finished comprehensive system** |
| **Tender** | favorable meat | Higher edible yield or easier cooking/energy efficiency | Recipe must track cook method |
| **Medicinal** | appropriate herb/fruit | Better medicine/food remedy effect or shorter negative food debuff | Medicine remains primary direct Health restoration |

### Food negatives (proposed)

| Food drawback | Applies to | Effect and cooking interaction |
|---|---|---|
| **Sour** | berries, fruit | Lower Energy or short uncomfortable debuff; recipe/taste may mask some |
| **Mealy** | fruit/roots | Reduced cooking Energy/meal quality |
| **Tough** | meat | Poor grilled quality; slow stew/pressure cooking can recover some yield |
| **Gamey** | meat | Lower immediate value/meal quality until seasoned |
| **Rancid** | meat/fat | Higher sickness risk; processing may not reliably make unsafe material safe |
| **Contaminated** | water, meat, herbs | Unsafe unless appropriate boiling/purification; serious sources should remain inedible |
| **Moldy** | fruit, herb, dried material | Foodborne illness or outright spoilage; not neutralized by generic +spice |
| **Watery** | produce | Less Energy per ingredient; may still be useful for hydration if implemented |
| **Withered** | plants | Shorter/less effective ingredient buff |
| **Irritating** | herbs/spices | Temporary stomachache/negative status or reduced comfort |

**Food trait fusion example:** `Nutrient-Rich Meat (+Energy)` + `Aromatic Herb (+buff duration)` -> **Herbed Meal** displaying **both** effects. `Contaminated Meat` + `Aromatic Herb` must keep the contamination drawback until a legitimate safe-cooking check handles it. Ingredient effects map to a **single dish status payload**, not permanent weapon bonuses, and cook times/quality gates matter. Processing retains provenance for the two actual ingredients and bounded final Energy/buff totals; **not** free max stats, injury healing, instant breeding IV or infinite duration stacking.

**Pet feeding / offspring note:** The owner confirmed that sustained food quality across growth phases affects **eventual expressed stats** of raised humans; quality feed may affect animal rearing. This is a **separate long-term nutrition model with caps, costs and phases**, not a way to equip one Nutrient-Rich berry and instantly overwrite inherited Might/Dexterity IVs. Pet feed must use its actual recipe and relevant food benefits.

## 5. BUILDING CONSTRUCTION: permanent properties from material input

**Owner's fixed construction direction:** Unlock/craft a **blueprint in the same Crafting menu**, place the blueprint as a persistent **worksite**, then deliver real material batches and labor to complete the building. The **BUILD interface is placement only**. Therefore an expensive rare **wood plank/stone block/scute padding trait should come from DELIVERED physical material inputs**, not the inexpensive blueprint paper. Materials' levels, quantities and source identity matter; refund and save rules must follow real deposited lots.

**Verified station/structure examples in existing recipe/world docs:** workbench, cabin bed, log shelter, fence/gate, basket, well, smoker, drying rack, stone grill, farming plot, crock pot, plus **planned** forge, raised storehouse, repair station and upgraded housing.

### Building / construct positives

| Trait | Material/part | What it benefits in appropriate buildings |
|---|---|---|
| **Straight-Grained** | reinforced plank, beams | More structural durability / hitpoints for walls, supports and boats |
| **Rot-Resistant** | treated wooden beams, boards | Slower structural deterioration/weather-related maintenance |
| **Fire-Resistant** | suitable clay/stone/plaster/treatment | Less fire damage to fireplaces/cabin/forge surround |
| **Dense / Load-Bearing** | stone block, reinforced bone/wood | Greater structural mass/stability, sturdier fortification wall/anchor |
| **Weatherproof** | cured hide, roofing, resin-treated plank | Less weather damage to roofs, tents, shelters and covered storage |
| **Insulating** | hides/fur/roof padding | Better indoor cold/heat protection and rest efficiency, where buildings support it |
| **Precisely Cut** | stone/wood building component | Faster construction alignment or better finished structural fit |
| **Reinforced** | layered metal/wood/scute wall piece | Higher structure HP and harder raids, at heavier material/logistics cost |
| **Low-Friction** | hinge wood/metal fittings | Better gate opening/closing/turns, with eventual mechanical animations |
| **Spacious** | specially cut storage frame/structural layout | Slight increase to usable storage slots/organization **only on storage buildings** |
| **Heat-Retaining** | furnace brick/stone | Lower fuel use or improved thermal consistency on furnace/smoker/cooking stations |
| **Efficient Draft** | chimney/pottery kiln/flue materials | Reduced fuel per smelting/smoking batch with correctly built station |
| **Sterile** | clean plaster/clay clinic lining | Better hygienic hospital/medicine station outcomes |
| **Level / True** | straight construction beams/planks | Faster/fewer repair needs on moving docks/harbor structures, not generic all-purpose DPS |

### Building negatives

| Trait | Material | Actual penalty |
|---|---|---|
| **Warped** | wood beams/planks | Lower frame HP/durability; more maintenance and misalignment |
| **Cracked** | stone/clay/bone blocks | Reduced structure integrity; repair sooner |
| **Porous** | roofing stone/wood | Weather ingress and higher upkeep; worse storage food preservation |
| **Flammable** | dried wood/oil/resin | Increased fire vulnerability if fire mechanics apply |
| **Rot-Prone** | timber/fiber | More frequent repairs, shorter component life |
| **Loose-Grained** | timber | Weak load-bearing timber or reduced boat/bridge durability |
| **Uneven** | stone floor/paver, dock parts | Slower/less efficient construction or resulting durability defect |
| **Leaky** | pottery/waterproof hide/container | Water loss or worse stored-good protection |
| **Heat-Wasting** | forge clay/brick | Higher fuel use per batch |
| **Fragile Joint** | nail/metal binding | Lower structure protection at load-bearing or moving joinery |
| **Overweight** | dense blocks/metal | Stronger stability possible but higher transportation/construction work and limited dock/boat cargo |
| **Infested / Mildewed** | untreated wood, fiber | Degrades food/storage protection and shelter quality |

**Do not give every building every perk:** Dense stone in a stockpile wall can help fortify it but won't increase a medical bench's Medicine skill. An Efficient Draft furnace lining affects fuel consumption, not tower projectile damage. Spacious storage framing boosts storage only, not a random wall's HP. `Fire-Resistant` cannot prevent enemy attacks of all types. Perk effect must be traceable to **specific installed component/zone and active production operation**.

**Building material fusion example:** `Straight-Grained treated_plank + Rot-Resistant treated_plank -> Composite Beam`; the delivered **composite beam** contributes **both** structural integrity and longevity to the cabin/workshop made from it. If another required roof stack is `Flammable`, the final building also carries that real vulnerability unless specifically protected by roof design. Once installed, the input's trait effect should be represented in a compact per-structure stat summary, not through a 500-element hidden item stack.

**Structural aggregation guardrails:** Aggregate based on **material roles/quantity/share**, not one extraordinary plank causing an entire castle to inherit +20% HP. Consider structural parts **Foundation / Frame / Wall / Roof / Insulation / Machine Internals** as sufficient coarse buckets, rather than per-voxel simulations. If a single critical special component is intended to dominate a machine's output, label that in its blueprint/worksite recipe. Rare materials provide value but cannot trivially create unraidable outposts; home private island is always unraidable as separate safety policy.

**Building efficiency should not produce materials ex nihilo:** Better lumberyard/forge hardware improves speed, fuel consumption or low bounded recovery from waste; still requires finite resource nodes, hauling, worker time and material inputs. Preserve actual delivered material inventory/reservation and no retroactive duplicate refund on dismantle.

## 6. OTHER great places for traits

Rather than giving every system an isolated 30-perk catalog, allow a **shared trait vocabulary** to express different **contextual stats** through eligibility roles. The following are the highest-value expansions.

| System | Example positive / negative traits | Meaningful payoff / risk |
|---|---|---|
| **Saddles, harnesses and dinosaur barding** | **Supple**, **Balanced**, **Interlocking**, **Overweight**, **Rigid**, **Weak Stitching** | Reduced mounted movement/stamina cost or improved plate integrity vs reduced turn/acceleration. Heavy armor's approved **pounce-pin deflection** comes from intact covered Heavy protection, not arbitrary perk lottery. Actual armor mass still modifies stomp force and defense via relative mass |
| **Boats, harbors and cargo containers** | **Buoyant**, **Reinforced**, **Precisely Fitted**, **Leaky**, **Overweight**, **Warped** | Actual cargo weight/space and loading/durability/maintenance. **Confirm previous rule:** boats traveling home AFTER departure are unattackable; no rare trait makes them interceptable or immune only on a proc. Harbor and boat levels/traits bound transported cargo capacity |
| **Agriculture, soil amendments and seed lots** | **Vigorous**, **Hardy**, **Fast-Growing**, **Pest-Prone**, **Low-Germination**, **Water-Hungry** | Time to harvest, energy/water input, chance of crop loss and valid yields. Not a free rise in level, genetics or fertile land quality. Fertilizer/deliberate seed processing can change traits with explicit bounded inheritance |
| **Medicines, poultices and antiseptics** | **Potent**, **Pure**, **Soothing**, **Irritating**, **Contaminated**, **Weak** | Magnitude/duration of legitimate healing/condition relief, infection/toxicity risk. **Medicine**, not ordinary food, is the primary direct Health restoration |
| **Animal feed, breeding food and rearing** | **Nutrient-Rich**, **Pure**, **Fortifying**, **Spoiled**, **Contaminated** | Hunger recovery and sustained diet quality, perhaps safe growth-stage expression when approved. Must not override genetics or generate perfect offspring via one rare ingredient |
| **Production station parts** | **Heat-Retaining**, **Low-Inclusion**, **Precisely Cut**, **Heat-Wasting**, **Cracked** | Furnace/fiber press/smoker/forge energy, yield and downtime. Power depends on actually installed machine parts |
| **Camp bedding and homes** | **Insulating**, **Supple**, **Weatherproof**, **Mildewed**, **Rigid** | Recovery conditions, sleep shelter and maintenance rather than permanent +Might |
| **Storage food preservation and transport crates** | **Dry**, **Airtight**, **Weatherproof**, **Leaky**, **Moldy** | Shelf life and spoilage while stored, quality of shipments. Only if spoilage/environment model is implemented |
| **Trade economy** | Any signed practical trait | Trait-aware appraisal, bids for specialist materials and final goods, not old +25% for every raw attribute regardless of its sign |

**Recommended priority of systems:** (1) weapons/tools/animal armor and **two-input trait fusion**, (2) cooking and obvious food outcomes, (3) buildings / machine parts and worksite delivered-quality aggregation, (4) saddles/boats/harbors/storage, (5) farming/medicine/offspring nutrition once proper simulations exist. Avoid trying to implement 100 perks simultaneously.

## 7. Implementation contract and test cases for Claude

**Important live-code gap:** `ItemStack.attributes` is an arbitrary dictionary. `HarvestNode.roll_yield()` copies node-wide `yield_attributes` and assigns level, not a named per-lot signed random trait roll. `Crafting.build_output()` currently copies only primary attributes; `Food` has basic raw/poison statuses and timed buff hooks; buildings use current existing kits and a planned **unified blueprint -> worksite -> labor** flow. None of this is a complete multi-trait inheritance system.

**Suggested implementation sequence (do not start coding until owner locks the catalog/probabilities/magnitude rules):**
1. **Trait definition registry** `game/data/material_traits.json` **[NEW]**: typed `id, display_name, sign, eligible_sources/materials, effect_tags, transform_rules, stacking_limit, output_roles`. Data-driven; no hardcoded if-statements per tooltip.
2. **Lot roll and provenance:** one persisted deterministic signed-trait outcome per harvest or butcher lot, weights/pools by biome/species/tool/career, inspectable source + probability and reproducible seed. **Near-all negative, rare positive** probability target OPEN.
3. **Trait-visible inventory and batch selection:** useful name, numeric practical effect, color/icon sign, preview and lock; exact-match stacking if signature matches, else configurable material lot grouping to avoid bag explosion.
4. **Two-primary-input **fusion/lamination** process:** strict item/material-stage requirements, consume both, preserve both signed trait lists and contributor/lot signatures; caps and duplicate behavior; crafting UI shows all contributors. Add recipes for **`reinforced_bone_block` (already specified in chapter23), `composite_plank` [NEW], `masterwork_iron_billet` [NEW], `braided_sinew_cable` (chapter23)**. Composite outputs have finite stage/tier so no recursive trait duplication.
5. **Crafting finalization by functional slot:** determine weapon/armor/tool/boat/building stat contributions by functional part tag and size/weight; bounded inheritance and sign-sensitive value. Producer skill affects workmanship, not random rare-trait creation.
6. **Food integration:** meat+herb+fruit and other recipes should compute a final short Energy/buff payload from multiple actual ingredients rather than just primary-meat attributes; cooked preservation, bad food and preparation safety; no instant permanent IV upgrade.
7. **Construction integration:** finished structures calculate frame/wall/roof/machine traits from actually delivered material lots rather than paper blueprints or generic building `attributes`, persisted on building and available to work AI/economy.
8. **Other integrations:** saddle and barding encumbrance + stomp/poise and Heavy anti-pounce; boats cargo under boat+harbor level/traits; market price from signed utility; farming and medicine later.
9. **Saved data and unit tests:** convert legacy item attributes safely, preserve `material_tier`, `tint`, `unstable`, `process_count`, item level and durability; new lot/trait signatures must survive save/reload, transfer, death, market listings, boat cargo and personal-item equip gate. Version snapshots and migration required.

**Acceptance tests:**
- Combine a `Resilient+` bone rib with `Shock-Absorbent+` bone rib; get ONE reinforced block with **both** traits, no RNG reroll.
- Combine a `Resilient+` and `Brittle-` bone rib; both remain, and their actual durability and shock contributions are inspectable.
- Two same-ID beneficial traits produce one capped, transparently merged trait, not +unlimited%; fusing a copy of an already-used source lot never duplicates its original contribution.
- Finishing a weapon from two prepared components never silently uses only `primary.attributes`; all relevant legitimate input contributors are considered.
- Construct a herbed meal from `Nutrient-Rich+` meat and `Aromatic+` herb: food restores appropriately more Energy and improves an actual compatible meal buff, **without permanent character stat inflation**.
- Construct a workshop from `Straight-Grained+` composite beams and `Rot-Resistant+` roofing: display concrete structural HP/upkeep improvements only for that installed structure; damaged component wear and later repair consistent.
- An invalid input pair (meat+iron) has NO arbitrary fusion recipe; the player sees eligibility rules.
- A heavy plated mount's mass/pounce deflection comes from equipped armor and valid coverage; its plate traits can improve component function but don't instantly make a naked raptor immune to pounce.
- A boat's `cargo_capacity` bonus respects boat+harbor level/trait restrictions and doesn't remove the separate guaranteed **safe after departure** rule.
- High-value trait lots aren't silently consumed by broad category recipe selection or offscreen worker orders, and market price does not treat negative traits as positive.
- A +food trait on a weapon shaft does not become weapon DPS and an ore-refining yield trait isn't perpetually multiplied on finished swords.

**No mathematical constants, trait drop rates, effect caps, final perk names, or code is approved/implemented by this chapter.** The catalog above is a concrete proposal intended for owner review and then transformation into an authoritative implementation spec.
