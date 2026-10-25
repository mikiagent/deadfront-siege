# 06 | Equipment, armor weight and defense profiles

**Status:** DESIGN PROPOSAL for owner review, 2026-10-25. The owner asked to explore **Light, Heavy and other armor types** as an extension of the confirmed **Dexterity (D), Might (M), Impact (I), Pierce (P), Slash (S)** combat framework. This chapter defines a plausible **Light / Medium / Heavy** proposal, not a confirmed classification or implemented mechanic. It also preserves the original planned inventory/storage topics for later design work.
**Related:** [11 Dinosaur defensive taxonomy](11-dinosaurs-and-genetics.md), [15 Combat](15-pve-exploration-and-combat.md), [02 IVs and progression](02-characters-levels-and-age.md), [Decision register](decisions.md).

## 1. Armor class must not be confused with attack style, character IV or innate dinosaur defense

Separate **five dimensions**:
1. **Attack profile:** action uses an inherited **Dexterity or Might** aptitude and deals **Impact / Pierce / Slash**. Six modes DI, DP, DS, MI, MP, MS. This is **offense**, not armor.
2. **Body/anatomy:** exposed enormous fleshy hide, small fast evasive body, or plated/armored shell. Determines the *species' natural defensive matchup*.
3. **Armor equipped:** **Light / Medium / Heavy** weight class, chosen by an individual human or perhaps added to a dinosaur by harness/barding. Affects protection, movement, stamina and weight.
4. **Material/coverage:** cloth, leather/hide, layered/scute, bone, metal; quality/level, signed traits, integrity and helmet/torso/leg coverage. Can bias physical resistance within a weight class without overriding its general identity.
5. **Individual career/equipment rules:** personal-level equip gate, learned Defense/Tailoring and Dexterity/Might IV effects, endurance/exhaustion, injuries. A body with exceptional Might does not get to ignore high-item-level requirements.

The game's **natural defense weakness** and an attacker's **offensive channel** remain entirely independent. A **Stegosaurus** may be **Impact-weak** thanks to natural plates but wield a **Might/Pierce thagomizer**.

## 2. UPDATED overlapping armor-counter bands (owner's 2026-10-25 direction)

**Latest owner preference, still a balancing proposal:** **Slash is good against Exposed and Light**, **Pierce is good against Light and Medium**, and **Impact is good against Medium and Heavy**. Each channel has **exactly two favorable defensive tiers**, which gives Slash equal theoretical category coverage. This supersedes this chapter's previous **Light -> Pierce only / Medium -> neutral-only** model.

**Exposed is not wearable armor.** It is an unarmored or unprotected body category, suited to large soft-bodied sauropods. Wearable categories are **Light**, **Medium**, **Heavy**; natural dinosaur body profiles can be classified analogously without pretending dinosaur plates are equippable items.

| Defender tier | Slash (S) | Pierce (P) | Impact (I) | Intended visual/body profile |
|---|---|---|---|---|
| **Exposed / Unarmored** | **Favored** | Neutral | Neutral | Bare flesh, especially giant slow HP sponges like proposed Brontosaurus |
| **Light** | **Favored** | **Favored** | Neutral | Cloth/hide/light leather, fast agile bodies, relatively limited coverage |
| **Medium** | Neutral | **Favored** | **Favored** | Layered hide, reinforced leather, flexible scute/plate combinations |
| **Heavy** | Neutral | Neutral | **Favored** | Thick scute/bone/metal plating, rigid protective shells/frills |

**Design check:** **Slash -> Exposed + Light**; **Pierce -> Light + Medium**; **Impact -> Medium + Heavy**. These are preferential matchups, *not* automatic hits. Neutral is ordinary damage after the defender's baseline protection. **Heavy still has higher armor than Exposed in its unfavorable Impact matchup**; Impact beats heavy alternatives by more effective stagger/guard damage or *relative* penetration, not by making armor worse than none.

## 3. Prevent Slash from becoming the weakest option again

**PROPOSED distinct combat jobs:**
- **Slash = soft-body sustained pressure.** Useful against exposed and lightly protected targets, with high uptime, bleeding where biologically appropriate, or sweeping multi-target contact. Suits soft massive high-HP Brontosaurus and ordinary Light bodies. **Bleed is a separate status**, not a Slash-only automatic trait, and it needs boss caps so fractional-max-HP bleeding does not trivialize giant raid bosses.
- **Pierce = reliable focus.** Good against **Light and Medium** contact, with targeted reach, fast target interception, strong single-target accuracy and potential specific vulnerable-point attacks. Against a fast Light raptor, Pierce can connect more easily than a slow/short Slash despite **both channels** being favorable on contact.
- **Impact = guard and structure breaker.** Good against **Medium and Heavy**, knockback/stagger/guard disruption. Great for armored Stegosaurus/Ankylosaurus while higher wind-up or narrow melee reach can make it harder to land on agile Light targets.

**Armor mobility is separate from intrinsic contact damage.** Light wearers may dodge slow Impact swings better, but that is movement/telegraph timing, not magical reduction after a successful hit. Medium can maintain an important customizable-material niche, even though both Pierce and Impact are favorable when they connect.

**Important category tension:** Light and Medium each have **two** incoming favored channels while Exposed and Heavy each have one, but this doesn't make them automatically weak gear. Exposed has essentially no base defense; Light gains mobility; Medium gains substantially more fixed protection; Heavy maximizes protection but has larger fatigue/weight/movement cost. A **matched weapon level, same-quality material, equal-hit** test should confirm that equipping Medium still makes a survivor tougher overall than equipping Light.

**Tiny clustered swarms are an AoE exception, not another armor tier:** Impact sweeping/area attacks may hit multiple Compsognathus, but a narrow slow blunt hit isn't guaranteed to land on an individual tiny fast creature. Species anatomy, Dodge and natural armor still vary above and below the band defaults.

**Current Godot conflict:** The prior `game/data/combat_counters.json` numbers (`fast_hunter` currently Slash-favored, `armored` Impact-favored) are **existing damage-family modifiers**, not implementation of this **new wearable 4-band countertable**. Do not globally replace values or double-count protection. Distinguish on-hit type effects from hit chance, status and natural dinosaur resistance when designing the formula.

## 4. Match concrete Deadfront animals and humans

- **Brontosaurus (owner future fantasy):** **Exposed/large/slow**, huge HP but low defense -> primary **Slash** weakness; attacks **DS tail whip** and **MI stomp**. This **is not** current Brachiosaurus, which has `titan` boss-like protection and already resists Slash.
- **Velociraptor:** **naturally Light/mobile**, exposed to **both Slash and Pierce on contact**, but Pierce's accuracy/reach should make it the more reliable anti-raptor counter; its own **DS claw** or **DP bite** is a separate offensive identity. The current `fast_hunter` data is Slash-favored; **adding Pierce favor is a proposal**, not shipped.
- **Stegosaurus:** **naturally plated/heavy**, **Impact**-weak defensively, **MP** or **DP** spike Pierce offense (plus existing `deep_bleed` status). Natural plates are not removable worn gear.
- **Ankylosaurus:** heavy plating, **Impact** counter, **MI** tail club offense; explicitly distinct from a giant Slash-weak soft body.
- **Human scout:** **Light** leather/hide, relies on evasion and precise ranged aim; both **Slash and Pierce** deal favorable damage on contact, Pierce more reliable against evasive movement.
- **Human defender:** **Heavy** reinforced scute/metal plating for frontier siege defense. Survives Slash/Pierce much better at cost of mobility and prolonged exertion; a big Might IV may **reduce some heavy handling penalties** if so balanced, but does not change its innate IV.
- **Medium-armored spearman:** mixed flexibility and protection, but both **Pierce and Impact** are relatively effective against its layers. Material traits and learned defensive technique help maintain a useful middle tier.
- **Dinosaur barding (future):** optional harness/plate equipment with species-specific fit/weight/coverage and cargo/riding costs. A tiny raptor should not freely wear a huge ankylosaur-style metal shell without gameplay tradeoffs. Tamed dinosaur gear requires separate item/slot/level/capture rules; **not present now**.

## 5. Stats and costs that make armor meaningful

**Recommended minimum visible stats:**
- **Armor rating:** ordinary flat protection/mitigation.
- **Weight class:** Light/Medium/Heavy; impacts movement/roll speed, sprint drain, recovery and (maybe) noise.
- **Damage matchups:** player-facing **Impact / Pierce / Slash** effectiveness/guard/stagger; material traits can modify those.
- **Condition/durability:** armor becomes less effective if damaged/broken, integrates repair. **Material level and signed traits remain economically important**.
- **Coverage:** Head, Body, Legs (the engine already supports these); later weak-spot targeted hits can reference coverage instead of making every hit use the same torso plate.
- **Climate adaptation:** light breathable vs insulated warm/cold, aligned with existing fatigue and climate systems; don't create a dominant single outfit for every biome.
- **Individual personal-level gate:** absolute requirement on worn armor for player and follower. Might IV cannot bypass higher-level plate.

**Avoid numbers until a playtest proves them:** exact raw armor per weight class; ratio of damage-channel reduction to flat defense; how much a Might IV offsets armor weight; whether Dexterity IV or learned Defense skill affects roll speed; whether heavy armor is mount-compatible and how food/fatigue interacts.

**Balance invariants:**
- **Heavy is still protective** even when Impact is its *relative* weakness. Impact should counter plating through shock/stagger/guard, not necessarily inflict more HP damage than on a nude target.
- **Medium must have a reason to exist**: stable well-rounded kit, specialized material choices, less tiring than Heavy, sturdier than Light, not the always-optimal middle.
- **Light relies on agency**, not a free damage-avoidance % that trivializes boss swings or fast enemy stabs.
- **Material trait economy** must materially vary same-class armor (mostly negative signed traits, uncommon advantageous traits) while respecting item-level restriction.
- **Armor is not raw IV or career mastery**: Dexterity improves handling, Might heavy load, Defense techniques/parry/roll and Tailoring crafting all train separately.
- **Sieges and local alphas:** extra armor adds to practical assault/defense power, caps and anti-punching-down assessment rather than treating a low-level heavily geared follower as equal power to bare counterpart.

## 6. Existing Godot implementation, verified before this draft

- [`game/scripts/items/inventory.gd`](../../game/scripts/items/inventory.gd) already has **Head, Body, Legs** worn equipment slots and sums `item.scaled_armor()` into one `equipped_armor()` value. **No Light/Medium/Heavy enum, weight system, or per-damage-type worn resistance** yet.
- [`game/scripts/combat/creature_attack.gd`](../../game/scripts/combat/creature_attack.gd) currently applies creature damage to players using `(20 + equipped_armor) × defense multiplier` as a general defense value. Player dodging and attacker accuracy are already considered, but not worn armor class versus Impact/Pierce/Slash.
- [`game/scripts/combat/vitals.gd`](../../game/scripts/combat/vitals.gd) manages **Energy and Exhaustion**, including stamina cap/recovery penalties; [`game/scripts/player/player.gd`](../../game/scripts/player/player.gd) already spends stamina to sprint and changes movement speed by move status. **Gear weight does not yet feed these calculations.**
- [`game/data/items.json`](../../game/data/items.json) already includes three-piece **Raid Hide Helm/Cuirass/Greaves**, each with defense ratings/durability and item level. It does not represent general Light/Medium/Heavy armor class options yet.
- [`game/scripts/items/inventory.gd`](../../game/scripts/items/inventory.gd) has a special **raid protection** check requiring the whole high-level raid kit; [`game/scripts/combat/creature_attack.gd`](../../game/scripts/combat/creature_attack.gd) exempts fully protected players from specific tyrant `fracture`/`pinned` statuses. **Do not accidentally remove this existing behavior when introducing general armor.**
- [`game/data/skills/trees.json`](../../game/data/skills/trees.json) already proposes **Tailoring** unlocks for hide/scute armor and **Defense** unlocks for roll/parry/recovery. Some planned armor-tier recipes and the full protective armor system remain **not implemented**. [`game/data/recipes.json`](../../game/data/recipes.json) currently has recipes for raid helm/cuirass/greaves rather than a complete multi-tier armor lineup.
- [`game/data/combat_counters.json`](../../game/data/combat_counters.json) has creature-family **Impact(=`blunt`), Pierce(=`pierce`), Slash(=`cut`)** multipliers; applying those to worn gear is *new implementation*. Natural defense categories and armor piece bonuses need careful stacking rules.

**Implementation guidance, after owner review:** Add `weight_class` and limited `defense_profile` to armor item data; keep existing `armor_value`, item level and equipped slots. Query actual attack channel at hit resolution; apply only one coherent combination of creature natural protection, worn coverage and material factors; do not multiply an innate dinosaur defense-family penalty by an identical worn weak-to-type penalty a second time by accident. Map player-facing `impact` to saved `blunt`; `pierce` unchanged; `slash` to `cut`/`slashing`. Test old raid-armor boss immunity, saves/slots, broken-armor handling and three-damage counters.

## 7. Owner questions

1. **Proposed answer based on owner direction:** Exposed baseline plus wearable Light/Medium/Heavy, and analogous natural creature body profiles. Confirm whether **armor tiers also apply to animal outfitting** or merely biological categories for wild animals.
2. Should **Heavy armor's Impact weakness** primarily appear as **stagger/guard-break**, **extra HP damage**, or both? Recommend stagger/guard and reduced mitigation so Heavy always protects more than being naked.
3. How should **Might IV** influence Heavy armor? Recommended: higher carrying/handling comfort and lower mobility/exertion penalties, **but it never removes equipment level gates**.
4. Medium has **both Pierce and Impact vulnerability in the new band proposal**. Does material customization or fixed protection and balanced speed offer enough utility?
5. Are **dinosaur saddles/barding** included in armor weights, with body-part protection and rider/animal separate hit boxes, or deferred until the human armor system is balanced?

**Nothing here changes runtime code, in-game armor parameters or approved existing creature stats.**

## 8. New dinosaur armor and load request (2026-10-25, future mechanic)

The owner explicitly wants **dinosaur barding and a weight system with meaningful trade-offs**, including a hypothetical **heavily armored Brontosaurus**, plus mass-dependent stomp/trap and raptor pounce mechanics. The full, newest dedicated specification is [22 Dinosaur Mass, Armor and Grappling](22-dinosaur-mass-armor-and-grappling.md).

**Reconcile human gear with creature protection:** human `Head/Body/Legs` slots remain as implemented, while dinosaurs would need **fitted animal-equipment slots** and local body coverage. Separate **body mass** from **armor mass**, **saddle mass**, **rider/cargo** and relative **comfortable carry capacity**. One dinosaur may have exposed legs (Slash favored) plus Heavy plates over the torso (Impact favored). Armor should improve protection but reduce **turning/acceleration and stamina or cargo headroom** at sufficient loads; avoid punitive stacking of every mobility penalty. Fitted protection does not make an unarmored sauropod a naturally plated Ankylosaurus or change the rider's reach.

**Guardrail:** Heavily armored Brontosaurus retains lethal huge DS tail reach and MI footfall pressure, but turning/recovery plus visible attack windows, weak leg zones, high upkeep and carried burden give opponents counterplay. A giant's foot can trample multiple tiny bodies only at actual planted footprint contacts, not a passive body-aura. Pin/Gore and raptor Maul are separate attack/control move events, not new IV/damage types. **None of this is implemented today.**
