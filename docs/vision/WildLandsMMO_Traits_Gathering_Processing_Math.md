# WildLands MMO | Materials, Gathering, Processing and Trait Math

> **Status:** WORKSHOP PROPOSAL (numerical formulas, names, percentages and example values not yet approved).  
> **Owner-established direction:** Signed traits are usually detrimental, exceptional positives are rare; real material lots and provenance matter; two eligible primary inputs can produce one composite inheriting both trait signatures. **Skilled processing can reduce/remove eligible negative traits for significant investment.** Workers gather autonomously at mining/logging sites, gaining **speed, bounded higher-level output bias and a modest boost to positive-trait odds** with skill; a level-50 site yields levels 45–50. Exact rates and formulas are unapproved.  
> **Companion references:** [Game Vision](WildLandsMMO_Game_Vision.md), [Crafting and Building](WildLandsMMO_Crafting_Building_Math.md), [Combat](WildLandsMMO_Combat_Math.md), [Existing material notes](05-material-level-traits-and-loot.md), [Decision register](decisions.md).

## What gathering should feel like

A grove, mineral seam, dinosaur carcass or specialized gathering site contains resources of a recognizable kind and tier. Individual harvest lots differ in level, quality, defects and rare virtues. A player can collect personally or organize physical tribe workers to collect, transport and deposit materials. A gifted worker is faster and may reliably select a higher-quality part of the site's existing range, but cannot conjure level-60 ore from a level-50 deposit. Site resources, tools, access, worker fatigue, hauling, storage and environmental exposure remain meaningful.

### Proposed material identity

Each distinct harvest lot is described by material/species, level, source region/site tier, amount, signed traits, freshness if perishable, and processing history. Material level and special traits are different axes. Lots with unlike traits or spoilage histories are not assumed interchangeable. Consumable stacking must not erase the difference between an excellent piece and a flawed one.

### Proposed gathering-site level roll

**Illustrative rule:** For site level `S` with eligible yield width `w = 5`:

`L_min = max(1, S - 5)`  
`L_max = S`  
`L_item = L_min + min(5, floor(6 × U^γ))`, where `U` is uniform over `[0,1)`.

- Novice worker: `γ = 1.5` (more low-range results).
- Competent worker: `γ = 1.0`.
- Expert worker with suitable tools: `γ = 0.75` (more near-cap results).
- A level-50 site always yields level **45, 46, 47, 48, 49 or 50**, never above 50. Other site types may have a different width, but their bounds are visible.
- A site that has no available supplies, is occupied by enemies or lacks a valid worker/tool does not generate phantom production.

This is a candidate distribution, not an approved rule that worker stats are the sole influence on level. Distinct mineral richness, tools and source quality can affect probabilities *inside* the site's permitted band.

### Proposed autonomous production math

`Collected_units_per_hour = Base_rate × Site_efficiency × Worker_skill_efficiency × Tool_efficiency × Energy_factor × Access_factor`.

Candidate bounded factors:

| Variable | Example range | What the player notices |
|---|---:|---|
| Base site rate | 8 units/hour | Vein or grove potential |
| Site efficiency | 0.7–1.3 | Poor versus developed installation |
| Worker skill | 0.75–1.5 | Specialization and training |
| Tool factor | 0.5–1.25 | Appropriate picks and axes matter |
| Energy factor | 0.25–1.0 | Overworked people slow or rest |
| Access factor | 0–1.0 | Missing routes, hostile interference, full storage stop work |

For a site with 8 base units/h, `1.10` site, `1.20` worker, `1.0` tool, `0.8` energy and open access, production is **8.448 units/hour**, subject to the supply available, carrying capacity, and worker/worksite allocation. Offline progress uses the same physical limitations and can stop; it is not unlimited free income.

Worker proficiency has **three distinct rewards**: production throughput, a modest item-level quality bias toward the top of the site's existing band, and a **small improvement in positive-trait odds**. This three-part design is owner-confirmed; the relative impact of each factor is still a balance proposal. Equipment, traits and site investment can specialize those rewards. Dinosaurs can haul or assist only when their role, training and equipment make sense.

### Proposed rare-trait worker bonus

`P_positive = min(P_site_cap, P_source × (1 + worker_specialization_bonus + eligible_tool_bonus))`

Illustration: if the ordinary source chance of any positive trait is **7%**, an expert's **+15% relative** bonus gives **8.05%** with no tool bonus, **not 22%**. Candidate bounds: worker specialization adds 0–20% relative bonus, and the site's own trait cap limits all sources. Every eligible lot is rolled once at harvest. Faster workers generate more *attempts per hour*, so both throughput and per-lot odds must be balanced together to avoid making automation the only rational source of rare materials. Worker expertise never changes the site's item-level maximum.

## Proposed signed-trait frequency

For early balance experiments, **96% of newly gathered lots** carry at least one negative trait and **7%** independently carry at least one positive trait. If independent, about **3.72%** of lots are completely neutral; some lots contain *both* signs. Of the positive-lot pool, only a minority should roll its strongest available magnitude. Neither these odds nor the correlation between rarity and high-tier sites is final.

The aim is frequent compromise and occasional treasure, not an inventory of equally perfect resources. A possible dedicated trait-finding charm could increase the **relative positive-roll chance** (e.g. 7% × 1.20 = 8.4%, *not* 27%). Whether a named trait has a separate targeted roll is still open. The owner has **not** approved the candidate 96%/7% odds, only the high-drawback/rare-positive direction and costly expert treatment of some negatives.

### Proposed trait catalog

All numeric effects below are **examples, not approved values**. Actual values should be visible on an item. Traits express only when relevant to a component and its role.

| Trait | Sign | Eligible sources | Example expressed effect and tradeoff |
|---|---|---|---|
| Resilient | + | Bone, wood, scute | +6% weapon/construct integrity when load-bearing |
| Brittle | - | Stone, bone, metal | -8% breakage resistance/condition life |
| Dense | + / tradeoff | Stone, heavy bone, iron | +5% eligible Impact power **and** +8% carried mass |
| Porous | - | Stone, ceramic | -10% weather resistance |
| Straight-Grained | + | Timber, planks | +5% structural stability or launcher control |
| Knotted | - | Timber, planks | -7% precision or fitting efficiency |
| Elastic | + | Tendon, cord, springy wood | +6% eligible draw/handling quality |
| Frayed | - | Fiber, cord, straps | -9% tension life |
| Low-Inclusion | + | Ore, refined metal | +6% shaped-metal reliability |
| Impure | - | Ore, refined metal | -7% forge yield or quality |
| Sharp-Edge | + | Talon, shaped blade | +6% appropriate Slash edge effectiveness |
| Warped | - | Wood, metal parts | -6% relevant alignment/control |
| Weatherproof | + | Treated roofing, sealed timber | -10% weather-related wear in constructed role |
| Leaky | - | Roofing, containers | +10% environmental wear or food exposure |
| Insulating | + | Hide, panels, ceramic | -10% eligible room thermal/food decay impact |
| Heavy-Handed | - | Awkward tool material | +6% tool energy burden |
| Nutrient-Rich | + | Meat, fruit, herbs | +8% eligible meal energy restoration |
| Aromatic | + | Herbs, food | +8% compatible timed food-buff duration |
| Rancid | - | Meat, fats | +12% spoilage rate or food-safety penalty |
| Preservable | + | Food lots | -10% spoilage rate before container effects |

The same words do not magically grant the same stat to every object. A resilient hammer head affects hammer integrity, but a decorative stud cannot fortify an entire fortress.

### Trait magnitude and caps

An experimental raw-positive band could be **+3% to +10%** per positive source trait; a common drawback band could be **-3% to -12%**. Family-specific outcome caps (example: +15% quality benefit, -25% drawback) prevent a rare combination from making all ordinary equipment obsolete. Tradeoffs such as Density's extra mass are not erased just because its Impact bonus is capped.

## Two-source processing and material inheritance

Two compatible **primary material lots** become one legitimate next-stage material. The result retains the appropriate **positive and negative** source effects and enough provenance to avoid counting the same ancestor twice. A recipe may also require binding, fuel or other catalysts. Material fusion is constrained to finite, legitimate production stages, not an endlessly repeatable upgrade trick.

**Example:** Carved Bone Rib level 45 with `Resilient +8%` and Carved Bone Rib level 50 with `Shock-Absorbent +6%, Brittle -4%` become one Reinforced Bone Block retaining all three named effects, subject to eligibility and final-role caps.

### Proposed level inheritance

`L_output = min(Recipe_cap, min(L_A,L_B) + floor(0.40 × abs(L_A - L_B)))`.

Thus:
- Levels 45 + 50 yield **47** before any lower recipe cap.
- Levels 20 + 50 yield **32**, not an effectively free level-50 product.
- Levels 50 + 50 yield **50**.

Manufacturing skill affects whether the process is available and its labor/scrap outcomes; it does not create high material level out of a lower-tier source without a separately designed rule.

### Proposed duplicate-trait fusion

When distinct source lots contribute **the same trait ID and same sign**:

`Combined = sign × min(Trait_cap, strongest_absolute + 0.25 × weaker_absolute)`.

Example: Resilient +8% with Resilient +6% becomes **+9.5%**, not +14%. Negative duplicates follow the same bounded stacking logic; a second brittle source cannot somehow improve its reliability. Opposite signed effects remain transparent instead of disappearing silently. Distinct IDs retain distinct contributions with compatible role-specific limits. Existing ancestor contributions count once, even through repackaging, repairs or successive production stages.

### Skilled purification of a flawed material

**Owner-confirmed gameplay rule:** A qualified specialist can deliberately **mitigate or remove eligible negative material traits**, paying a meaningful cost in materials, fuel, specialized facilities, labor and possibly risk. This can turn an exceptional-but-flawed lot into a valuable manufacturing input. It does **not** mean ordinary two-source fusion filters out negative traits: fusion still inherits them unless a separate explicit treatment legitimately changes the material.

**Proposed candidate math only:** For an eligible negative effect with absolute magnitude `d` and treatment reference `d_ref = 0.10`, a full-removal recipe's specialized resource-cost index could be:

`Purify_cost = Base_treatment_cost × Station_tier_factor × (1 + 2 × d/d_ref)`

Example: removing a **Brittle -8%** trait costs **2.6×** the baseline treatment index at tier factor 1. Less-expensive mitigation could shrink the defect from **-8% to -4%** without eliminating it. The base cost, whether costs increase with material level, the treatment's specific recovered effects and eligibility by trait are all OPEN. A fully deterministic expensive treatment is one *candidate* that avoids destroying rare ingredients by unlucky rerolls; a failure/scrap risk is a competing unapproved design.

- No treatment adds positive trait IDs or rerolls an existing positive into a stronger one.
- A cured defect is removed or reduced from the current lot and recorded in its processing provenance; splitting, trading or recombining must not restore an old rare benefit twice.
- Individual recipes specify which defects they can alter; not all disadvantages can necessarily be purified, especially innate physical mass tradeoffs such as Density.
- A material's lot quantity, recipe stages, input conservation and material level remain meaningful. Purification is a special manufacturing profession, not free post-processing.

### Proposed processing identity

- **Early:** Split logs, cord, hide, stone knapping, carcass butchering.
- **Middle:** Treated timber, worked bone, reinforced scutes, copper ore, melt/refine operations.
- **Late:** Refined iron, shaped forged components, advanced animal composites, complex modular structures.
- Raw components transform into specialized manufactured parts before becoming a finished high-level product.
- Rare component combinations are valuable to specialist professions and trade.

## Risks and discussion points

1. **ANSWERED direction:** Master gatherers improve throughput, within-band levels and positive trait chances. **OPEN:** relative strengths, site/tool caps, how to prevent runaway automated rare-material output.
2. **OPEN:** Are the example 96% drawback odds and 7% positive odds good starting values, or should the trial compare other distributions?
3. **ANSWERED direction:** Qualified processors may reduce/remove eligible negatives at substantial cost. **OPEN:** which defects qualify, deterministic vs risky treatment, exact inputs and cost curves.
4. **OPEN:** Should other site types use fixed or variable yield-width bands? The owner's level-50 → level-45 through 50 example remains intact.

Unresolved details also appear in [Open Questions](WildLandsMMO_Open_Questions.md).

> All values in this document are workshop candidates. Nothing here overrides the owner's currently confirmed site example, material identity requirements or game vision.
