# WildLands MMO | Crafting, Worksites, Buildings and Production Math

> **Status:** WORKSHOP PROPOSAL. Numeric multipliers, prices and recipe quantities are illustrations, not locked gameplay.  
> **Established fantasy:** Crafting, gathering, processing, buildings, dinosaurs and tribe labor create real professions. Recipes use actual component sources and material history. Completed structures are packable, valuable trade goods. Private home upgrades return 100% of invested building materials to a recovery vault.  
> **Related:** [Game Vision](WildLandsMMO_Game_Vision.md), [Materials and Gathering](WildLandsMMO_Traits_Gathering_Processing_Math.md), [Loss and Revival](WildLandsMMO_Loss_Recruitment_Revival.md), [Existing construction reference](08-blueprints-worksites-and-building.md).

## The manufacturing fantasy

The best goods emerge from a sequence of choices: where to source materials, which imperfect lots to keep, which to fuse, which specialist to assign, which tool/workstation to use, and whether to sell the component or manufacture something higher in the chain.

### Three eras of meaningful transformation

| Era | Resource story | Common outputs |
|---|---|---|
| Early: stone, fiber, hide, bone | Accessible gathering and hunting, primitive heat and binding | Simple tools, cloth/hide gear, clubs, bows, shelter |
| Middle: animal composites, treated wood, first copper | Targeted hunting, differentiated professions, real processing stations | Reinforced bones, composite stocks, better tools, modular rooms |
| Late: refined iron and exceptional sourced components | Dangerous access, specialized labor, supply chains | Durable class-defining weapons, siege fittings, high-end crafted buildings |

Metal does not arrive as generic finished ingots without smelting and shaping. Dinosaur parts remain useful deep into the metal era. The weapon system includes **six classes (DI, DP, DS, MI, MP, MS) across three eras**, a target of 18 defining weapon types. Technology ceiling beyond refined primitive/metalwork remains an open artistic and balance decision.

## Proposed crafting-result mathematics

Inputs each have a level, source traits, mass and process stage. A completed object's properties are based on the roles fulfilled by components, not a blind sum of all bonuses anywhere in the recipe.

**Level proposal for a multiple-component finished item:**

`L_item = min(Recipe_cap, floor(Σ w_i × L_i / Σ w_i))`

Where `w_i` is **functional importance**, not arbitrary market value. For a spear, the head could receive 55% weight, haft 30%, binding 15%. With head level 50, haft 44 and binding 40:

`L_item = floor(0.55×50 + 0.30×44 + 0.15×40) = 46`.

An important low-tier part still matters. Tool skill might modify durability, waste or the probability of producing the item as planned, but it cannot bypass explicit personal equipment level gates or upgrade the input material level for free.

**Proposed applied trait effect:**

`Object_trait_bonus = clamp(Σ role_weight × relevant_source_magnitude × component_coverage, -Family_penalty_cap, +Family_bonus_cap)`.

For a weapon head that provides 70% of its applicable edge function, a `Sharp-Edge +8%` head contributes **+5.6%** to that specific edge-related channel *before any family cap*, not +8% to stamina, fire resistance and sale price simultaneously.

**Proposed process loss:** Quality-control failure causes **scrap/recovery** from specifically imperfect batches, not an invisible disappearance of all valuable inputs. Candidate: `Scrap_chance = clamp(Base_process_risk × (1 − Skill_reduction) × Station_factor, 0.01, 0.20)`. This should be tested cautiously so rare traits do not feel like a casino inside every workshop. Whether failure destroys, downgrades or partially returns materials is unresolved.

## Blueprint-first construction

Buildings are designed as blueprint/worksite structures, with modular 2×2, 3×3 and 4×4 room concepts. A worksite consumes real delivered processed components and labor. Skilled builders can create valuable structures; less-skilled people can help haul and deliver without bypassing the lead builder's expertise.

A building can become a uniquely identifiable manufactured product carrying its creator, material traits, durability, appearance and eligible upgrades. When empty and eligible it can be **packaged, moved, traded and redeployed**. Packing is not the same as dismantling for resource salvage and never creates a second copy.

### Proposed worksite labor model

`Work_units_per_hour = Base_builder_rate × Skill_factor × Endurance_factor × Tool_factor × Worksite_access × Coordination_factor`.

Illustrative bounded factors:
- `Skill_factor = min(1.6, 1 + 0.015×learned_construction_level)`.
- `Endurance_factor` 0.4–1.0 based on energy/rest.
- `Tool_factor` 0.7–1.25.
- `Worksite_access` 0 if materials/access/permissions are missing, otherwise up to 1.
- `Coordination_factor` accounts for multiple workers without infinite crowding.

For multiple contributors, one candidate is `Effective_team_work = Best_worker_rate + 0.60×Second_worker_rate + 0.35×Third_worker_rate`, with site occupancy caps and actual consumed energy/tool durability. If solo work takes 10 work-hours, adding two workers makes it faster, not free.

**Material conservation:** If a room lists 10 structural panels and 20 beams, at no point does packaging, cancellation, dismantling, home transfer or deployment generate more panels/beams than were actually present. The known **100% invested-material refund** for a paid home-island replacement is a special explicit rule, not an automatic refund on combat destruction or unstable-island resets.

## Buildings as crafted assets

| Material / room property | Positive trait | Negative trait | Where it should matter |
|---|---|---|---|
| Framing | Straight-Grained | Warped | Structure integrity, fit |
| Roofing | Weatherproof | Porous or Leaky | Exposure and degradation |
| Insulation | Insulating | Drafty | Rest and appropriate pantry effects |
| Workshop fuel use | Efficient Draft | Poor Draft | Eligible furnaces, cookers, workstations |
| Stone/bone fortification | Resilient | Brittle | Wall/structural integrity |
| Storage | Airtight | Leaky | Actual contained spoilage rate, not island-wide buff |

**Example structural formula:** `Structure_HP = Base_HP × (1 + min(0.15, Σ structural_material_share × allowed_integrity_trait))` before damage, building level and repair state. A single +10% special nail occupying 1% of the load-bearing build may contribute only +0.1% to a structural calculation. A 49% / 51% material style change should not create a discontinuous leap in defense.

### Functional rooms

Rooms gain local functions based on actual enclosure, equipment and furnishing:
- Bedroom: improved sit/sleep recovery at occupied beds.
- Kitchen: shorter cooking labor or lower waste under fuel and resource costs.
- Workshop: working comfort or reduced wear for eligible activities.
- Pantry: slower spoilage for food stored in the proper containers.
- Barracks: efficient housing with lower comfort than a well-furnished bedroom.
- Animal facility: real species-appropriate feeding, pen and handling utility.

**Candidate ambience diminishing returns:** `Room_bonus = Cap × (1 − exp(−Valid_points / Scale))`. With `Cap=0.10`, `Scale=20` and `Valid_points=20`, a kitchen improves eligible work time by about **6.3%**, not a free 10% from one arbitrary table. More similar furnishing helps less and less. Bonuses remain strictly local to the correct activity.

## Food and long-term production

Freshness is separate from durability. Spoilage progresses during offline time in bags, homes, stores, boats, worker inventories and markets. At zero freshness edible lots become rotten material suitable for alternate uses, not an untracked deletion. Food traits modify meals, processing or preservation where they are relevant.

**Illustrative linear decay:** `Freshness(t) = max(0, Freshness_start − 100 × elapsed_hours × Storage_decay_factor / Base_shelf_life_hours)`.

Example: raw meat with 12-hour base life held 6 hours normally has **50%** freshness. Putting it in a container with half decay rate gives **12 additional hours**, not 24 new hours. Cook/preserve processes cannot revive fully rotten ingredients.

## Proposed viability constraints

- Exceptional crafted goods may command premiums, but quality should be discoverable from item tooltips.
- Workstations consume actual labor, tools, inputs, fuel and storage capacity.
- Housing/food/population are limiting factors for automation, not artificial worker slots alone.
- Finished structures have mass/cargo requirements when packed; transport matters.
- A high-level purchased item still respects the actual individual's equip-level requirement.
- Industrialized peaceful players should remain viable without having to participate in raiding.

## Decisions to workshop

1. Should crafting skill affect **time, resource waste, trait expression**, or the chance of a masterwork bonus?
2. Does the player personally build every advanced blueprint, or can a qualified hired tribe member be the registered lead builder?
3. When a finished building is sold, does the buyer receive all material traits and installed upgrades, or are some furnishings separate?
4. How much time should high-tier production take while respecting short, self-directed play sessions?
