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

## 2. Proposed Light, Medium, Heavy armor classes

| Armor | Typical look/crafting | Defensive identity | Tradeoff | Best archetypes |
|---|---|---|---|---|
| **Unarmored / Exposed** (baseline, not an equipment class) | Bare skin, very thin clothing, huge soft-body hides | Low raw protection. **Slow high-HP exposed bodies tend to be Slash-weak**; exposed fast prey can instead be Pierce-weak | Full mobility; zero worn gear protection | Future Brontosaurus / exposed giant |
| **Light** | Woven cloth, reinforced hide, light leather, flexible fur | **High mobility**, short recovery and usable dodge against telegraphed Impact; limited armor coverage can make accurate **Pierce** attacks dangerous **when they connect** | Lower fixed damage reduction; less stagger resistance; status exposure | Scout, archer, fast raptor defensive analogy |
| **Medium** | Layered hide, stitched/scute inserts, reinforced flexible plates | **Balanced** reliable defense and movement; can be tailored by materials toward Slash, Pierce or Impact rather than gaining a built-in universal immunity | Neither fastest nor toughest; sustained Energy costs in between | Mixed human expedition fighters, versatile NPC guards |
| **Heavy** | Large scute/bone plates, metal plates, thick protective layers | **High fixed protection against Slash/Pierce** and good guard/stagger protection; **Impact** is the relative counter through transmitted force, posture damage or stagger, NOT automatically a bigger absolute hit than unarmored | Slower sprint/recovery/dodge, higher exertion/heat burden, heavier carrying/mount logistics | Shield/guard, heavy infantry, naturally plated Ankylosaurus or Stegosaurus |

**Important non-RPS caveat:** **Medium armor is balanced, not an obligatory third vulnerability** just to fill a 3×3 chart. We should not force an unnatural rule saying every medium outfit is weak to Slash if real armor construction would protect from Slash. A useful decision can be **Light mobility vs Medium flexibility vs Heavy raw protection** plus the **enemy's attack channel and encounter geometry**. The defender's class determines a tradeoff, not absolute immunity.

**Important hit vs dodge distinction:** Light armor does not magically resist the force of a hammer once struck. Light armor may enable **dodging the slow telegraphed Impact**, while high-control **Pierce** attacks may have reach/targeting capable of punishing its mobility. The actual hit calculation must honor animations, range and aiming. A fast raptor remains fast whether or not a gear label is displayed.

## 3. Countertable for readability (proposed, qualitative)

| Defender | Impact | Pierce | Slash |
|---|---|---|---|
| **Large, unarmored, slow** | Neutral / strong single hit | Neutral | **Weak** |
| **Light, mobile** | **Easier to evade** if slow/telegraphed (not impact resistance) | **Weak on connection** if gaps/openings exposed | Some mitigation from hide/cloth; profile-dependent |
| **Medium, layered** | Moderate | Moderate | Moderate; material can favor one counter |
| **Heavy, plated** | **Relative weakness** via shock/stagger/guard | Strong protection absent weak-point aim | Strong protection |
| **Tiny swarm** (situational) | **Weak to area-control Impact**, not every narrow hammer swing | Vulnerable if individually hit | Vulnerable if individually hit |

A **gameplay weakness should be legible before attacking** from silhouette/codex, with one clear primary counter (and special enemy phase exceptions). For bosses and extreme levels, attack properties, stamina and stats all matter; tags do **not** guarantee an equal-level win.

## 4. Match concrete Deadfront animals and humans

- **Brontosaurus (owner future fantasy):** **Exposed/large/slow**, huge HP but low defense -> primary **Slash** weakness; attacks **DS tail whip** and **MI stomp**. This **is not** current Brachiosaurus, which has `titan` boss-like protection and already resists Slash.
- **Velociraptor:** **naturally light/mobile**, likely **Pierce** counter by reach, controlled timing and vulnerability to contact; its own **DS claw** or **DP bite** is a separate attack identity. Current `fast_hunter` counters do not yet assign Pierce weakness, so this is proposed.
- **Stegosaurus:** **naturally plated/heavy**, **Impact**-weak defensively, **MP** or **DP** spike Pierce offense (plus existing `deep_bleed` status). Natural plates are not removable worn gear.
- **Ankylosaurus:** heavy plating, **Impact** counter, **MI** tail club offense; explicitly distinct from a giant Slash-weak soft body.
- **Human scout:** **Light** leather/hide, relies on evasion and precise ranged aim; vulnerable to accurate Pierce once caught.
- **Human defender:** **Heavy** reinforced scute/metal plating for frontier siege defense. Survives Slash/Pierce much better at cost of mobility and prolonged exertion; a big Might IV may **reduce some heavy handling penalties** if so balanced, but does not change its innate IV.
- **Medium-armored spearman:** mixed flexibility, modest burden, broadly usable; not necessarily strictly superior to either class, and should be buildable through Tailoring/Processing/Weapon-Tools specializations.
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

1. Should Light, Medium and Heavy be **three distinct gear tiers**, with **Unarmored/Exposed** as a baseline, or should **Exposed, Mobile, Plated** be the three core **defensive profiles** independent of armor weight class (recommended separate axes)?
2. Should **Heavy armor's Impact weakness** primarily appear as **stagger/guard-break**, **extra HP damage**, or both? Recommend stagger/guard and reduced mitigation so Heavy always protects more than being naked.
3. How should **Might IV** influence Heavy armor? Recommended: higher carrying/handling comfort and lower mobility/exertion penalties, **but it never removes equipment level gates**.
4. Should medium armor have **material-customizable type resistance** as its selling point, or a defined specialty? Recommend material choice over forced weaknesses.
5. Are **dinosaur saddles/barding** included in armor weights, with body-part protection and rider/animal separate hit boxes, or deferred until the human armor system is balanced?

**Nothing here changes runtime code, in-game armor parameters or approved existing creature stats.**
