# Deadfront | Dinosaur-by-dinosaur ideal weapon matchup workshop

**Status: owner-requested THEORY TEST, 2026-10-25. NOT implemented, and species weapon assignments not owner-approved.** The owner accepted the **six weapon classes** as a working design direction: **Dexterity = control / Might = force**, crossed with **Impact = disrupt / Pierce = penetrate / Slash = shred**. **Delivery (melee/ranged/siege), speed, firing rate, AoE, range and stamina are separate weapon attributes**, not the six classes themselves. Aim here: can every dinosaur have a readable weakness and a viable D and M weapon choice as difficulty increases?

**Source of tiers, speed, HP, attack type:** [Current creature JSON](../../game/data/creatures/); all **19** current species assessed in ascending tier after starting with the owner's requested Compy and Zebraceratops. The existing [counter table](../../game/data/combat_counters.json) **does not** yet implement these proposed vulnerability classes. For any new ranged weapon, fantasy firearm, spread mode, armor tier or attack mode, do **not** imply the item or ability already ships. Related: [Weapons](weapons.md), [Armor classes](../game-design/06-inventory-equipment-and-storage.md), [Dinosaur archetype catalog](../game-design/11-dinosaurs-and-genetics.md), [Combat](../game-design/15-pve-exploration-and-combat.md).

**LATEST TECHNOLOGY AND MOUNTING QUALIFICATION, 2026-10-25:** This entire per-dinosaur table is a **stress test of arbitrary future equipment, not a commitment to guns/rocket launchers or to replacing close combat**. The owner now favors a **mostly primitive world** where **Might is strong early** and **Dexterity branches into more crafted weapons later**, and where **rider+dinosaur cavalry makes heavy melee/polearms practical versus big animals** through movement/reach/windows (without a global mounted damage multiplier). **IMPORTANT: previous tables below proposing automatic firearms and guns as the 'ideal' counter are now historical examples of one optional high-tech path. Do NOT treat them as the intended endgame.** The more suitable near-term matchups are Might long spear/braced pike/javelin, warhammer, heavy axe, shield and mounted lance versus Dexterity bow/crossbow/slingshot/throwing axe; player+mount as one slot with tradeoffs. A Brontosaurus's long **DS tail whip** and **MI stomp** require safe angles and telegraphed recovery so skilled foot and mounted melee can contribute. Full updated scope: [12 Mounted Combat and Primitive Weapon Progression](../game-design/12-expedition-mounts-and-command.md).

## 1. Current proposed attack and defense framework

| Primary aptitude IV | Impact: disrupt | Pierce: penetrate | Slash: shred |
|---|---|---|---|
| **Dexterity D**, control/aim/tool handling | **DI**: slingshot, precisely aimed grenade/rocket launcher, catapult | **DP**: bow, crossbow, rifle, sniper | **DS**: shotgun as an *abstracted shredder*, accurate thrown blade, supported/mounted Gatling/rotary gun |
| **Might M**, physical output/heavy handling | **MI**: hammer/maul, powerful blow, portable heavy recoil-intensive demolition cannon | **MP**: spear/lance, heavy harpoon gun | **MS**: greatsword/chainsaw axe, heavy handheld rotary/minigun with sustained load |

A weapon's **primary IV is selected for its firing/attack mode and support configuration**, not because all guns must be Dexterity or all Might must be melee. Example: supported/mounted rotary gun is **DS** (aim and tracking) and physically carried heavy rotary system may be **MS** (sustaining the heavy operation). Both can be Slash-style **shredding** as a game abstraction even if individual bullets physically penetrate and do not literally cut like swords. A portable grenade launcher **DI** can coexist with a more demanding heavy demolition cannon **MI**. Neither must be faster/slower by definition.

| Defender band | Favorable damage types |
|---|---|
| **Exposed**: huge unarmored slow bodies | **Slash** |
| **Light**: fast thin/flexible hide | **Slash + Pierce** |
| **Medium**: moderately protected/layered hide | **Pierce + Impact** |
| **Heavy**: plated/rigid shells | **Impact** |

**Modifiers beyond armor:** encounter behavior, pack count, target speed, weapon range, telegraph/dodge, staggering, area coverage, sustained DPS/bleed and ammunition/stamina cost. **Swarm special case:** Area-control **Impact** can be unusually effective against a pack of tiny Light Compys, but **light armor by itself does NOT make single-target Impact a favored damage matchup**. **Slash on Light** can also be useful, particularly with sweeping blades or scatter weapons. Exposed huge bosses require sustained Slash strength without uncapped percent-of-HP bleed.

## 2. Full 19-species theoretical matchup progression

Proposed defense, **D** best weapon/mode, and **M** viable best counterpart. Each row is an owner's requested **workshop hypothesis**, not a change to `combat_counters.json` or current creature difficulty. Tech level and exact weapon unlocks remain open; gun/launcher options are **future** gear, not claims players currently have them at these tiers.

| Creature / existing tier | Proposed defense | Ideal Dexterity counter | Ideal Might counter | Why these work / what they must overcome |
|---|---|---|---|---|
| **Compsognathus (Compy), 15** | **Light + swarm exception** | **DI** broad scatter/splash impact shot **(proposed AoE mode)** | **MI** broad sweeping club/maul hit **(proposed AoE mode)** | Tiny fragile individual, but attacks in packs of 4–8; *coverage* and knockback matter. A narrow Impact strike is NOT a general advantage against each Light body |
| **Zebraceratops, 13** | **Medium** | **DI** slingshot | **MI** bone hammer | Compact head protection, slow head shoves; Impact is accessible for both stats. Pierce also favors Medium but is not necessarily better at staggering |
| **Coelophysis, 18** | **Light / fast** | **DP** bow | **MP** long spear | Darting flock animal; ranged tracking and keep-out reach beat chasing it with slow melee |
| **Protoceratops, 20** | **Medium** | **DI** slingshot | **MI** hammer | Stocky beak/frill, herd solidarity; Impact for reliable interruption, Pierce equally favorable in category table |
| **Velociraptor, 25** | **Light / fast** | **DP** bow | **MS** two-hand sweeping axe | Bow intercepts speedy pounce; sweep punishes multiple attackers when positioned correctly. Slash also works vs Light; MP spear alternative for one-on-one |
| **Gallimimus, 30** | **Light / extreme speed** | **DP** bow or aimed crossbow | **MP** braced spear or thrown javelin | Fastest existing runner (speed 900); intercept, do not pursue with slow hammer. Might's reach/momentum requires timing, may be less forgiving than ranged DP |
| **Megaloceros, 30** | **Light / fast** | **DP** bow/crossbow | **MP** lance / braced spear | Fast antlered gore and fleeing; timed reach catches a charge, rifle later offers easier tracking |
| **Deinonychus, 35** | **Light / pack-flanker** | **DP** crossbow, or later **DS** shotgun | **MS** long sweeping battleaxe | Multiple agile flankers; focused ranged burst removes priority target, wide Slash arc protects a melee fighter; claws inflict bleed |
| **Dilophosaurus, 40** | **Light / mobile** | **DP** crossbow or later rifle | **MP** thrown javelin / long spear | Ranged venom threat makes long-distance removal safer. Might fighter needs reach and venom avoidance; harpoon gun later gives Might a safer ranged answer |
| **Smilodon, 45** | **Light / predator** | **DS** shotgun/scattergun **(proposed gun)** or DP crossbow | **MS** sweeping greatblade, or MP braced spear | Pouncing light target vulnerable to Slash/Pierce on contact; close range exposes melee to deep bleeding. Pierce allows safer interception if timing difficult |
| **Stegosaurus, 45** | **Heavy / plated** | **DI** grenade launcher **(future)**, or slingshot only if scaled to tier | **MI** heavy maul or carried demolition cannon **(future)** | Thick dorsal plates, broad spiked-tail threat, deep bleed. Heavy armor favors Impact but reaching melee range is dangerous; Might ranged option matters |
| **Styracosaurus, 45** | **Medium-to-Heavy / horned** | **DI** impact explosive launcher **(future)** | **MI** hammer or carried concussion cannon | Frill/skull protect, telegraphed horn sweep/charge; Impact stagger and positioning more important than standing in front |
| **Allosaurus, 50** | **Light-to-Exposed / large flesh** | **DS** shotgun or supported rotary gun **(future)** | **MS** heavy handheld rotary gun **(future)** or powered axe | Large fleshy predator with deep bleed/fracture; Slash-style sustained pressure valuable; melee needs extreme positioning |
| **Ankylosaurus, 50** | **Heavy / plated** | **DI** grenade launcher | **MI** portable heavy cannon or powered maul | One of the heaviest defenses, very dangerous tail-club fractures; hammer fits damage type, **Might cannon is safer** |
| **Utahraptor, 50** | **Light / fast apex predator** | **DP** rifle | **MP** heavy harpoon gun or a braced lance | Lunge, huge raking claw and deep bleed; ranged Pierce / control of leap is preferable. Slash is also favored on Light if the player can connect |
| **Triceratops, 55** | **Heavy / armored charger** | **DI** grenade/rocket launcher | **MI** heavy demolition cannon or powered hammer | Massive frontal charge, fractures and knockdown; Impact from outside charge path is safer than face-to-face melee |
| **Brachiosaurus, 60** | **Heavy / titan (CURRENT GAME)** | **DI** impact rockets/catapult | **MI** heavy siege cannon | Current 90k HP / 500 defense giant `titan`; currently favors Impact and **resists Slash**. Not the owner's distinct future Slash-weak Brontosaurus |
| **Tarbosaurus, 60** | **Exposed-to-Light large predator (PROPOSED CHANGE)** | **DS** shotgun/rotary shredder | **MS** heavy rotary gun or powered chainblade | Pinned/grapple and bleed risk, high HP and relatively less armor; Slash sustains damage. **Current `giant` actually resists Slash** |
| **Tyrannosaurus rex, 60** | **Exposed-to-Light boss (PROPOSED CHANGE, unapproved)** | **DS** mounted/supported rotary shredder | **MS** heavy handheld rotary gun, optionally powered greatblade | 200k HP and boss attacks make sustained ranged damage safer than suicidal melee. Needs encounter-group/raid tuning and careful bleed status cap. **Current `giant` resists Slash** |

**Owner additional hypothetical creature, NOT in JSON:** **Brontosaurus** = **Exposed / extremely high HP / low defense**, weak to Slash, offense **DS tail whip + MI stomp**. Ideal counters: **DS** shotgun/supported rotary fire, **MS** handheld heavy rotary or powered Slash blade if highly protected. Distinct from existing protected Brachiosaurus.

## 3. What this theory actually proves or fails to prove

- **Pro:** All six labels can map onto real species; different weapon shapes and behaviors matter beyond damage channel. **Dexterity and Might both have a ranged endgame.**
- **Pro:** Light is vulnerable to **both Slash and Pierce**; fast enemies often favor Pierce because tracking/range lets it **hit**, while packs may favor Slash sweep or scatter **when they close**.
- **Pro:** Heavy enemies favor Impact, and late Might does not have to run face-first into a Stegosaurus, Ankylosaurus or Triceratops; **MI portable demolition cannon** offers ranged force handling.
- **Problem:** This first pass overuses **Impact** against armored herbivores, **Pierce** against speedy predators, **Slash** on upper-end fleshy predators; natural morphology supports that, but each family needs multiple distinct encounters rather than six cosmetic weapon icons.
- **Problem:** Early Compy Impact AoE currently isn't implemented as slingshot scatter or club sweep. This is an **AoE design requirement**, not evidence for free Impact advantage vs lone Compy.
- **Problem:** Equipping very late guns to fight the tier-15 animals would trivialize them due to gear-level power; those firearm columns only explain **role**, not legal unlock level. Preserved rule: a person cannot equip gear above their personal level.
- **Problem:** `game/data/combat_counters.json` currently maps **`fast_hunter` -> Slash advantage**, **`giant` -> Impact advantage and Slash resistance**, so present counter-family multipliers disagree with most ideal future Pierce/Slash setups. Need per-species def profile & boss exception migration before implementation.
- **Problem:** Shredding guns are a purposeful **RPG abstraction**. Real shotgun/Gatling rounds pierce; if user later prefers physics realism, retain Pierce for gun bullets and use Slash for actual blade/fragment/disk payload types.
- **Problem:** A Might-range gun only meaningfully scales on Might if its handling/recoil/mass/sustained force has an appreciable mechanic. **Don't arbitrarily label identical mounted/handheld gun performance M vs D** unless recoil handling, movement, support and stamina actually behave differently.
- **Problem:** On large bosses, melee should be *high-risk/high-reward* not trivially optimal by an unexplained bonus; protected exosuits, group protection, status control and ammo tradeoffs can help.

## 4. Best weapon archetype by enemy, alternative archetype and defense

**Do not interpret best weapon category as guaranteed hit/kill.** Damage family selects which defensive class the strike is good against; speed and contact shape determine if it can connect; player class stats and skills make it feasible; equipment level and rarity affect the actual numbers.

**Possible simple UI:** Enemy codex `Armor: Light`, `Weak: Slash + Pierce`, `Behavior: Fast / Swarm`, `Suggested: DP accurate ranged OR MS wide sweep`. Avoid indicating a single weapon is mandatory.

## 5. Validation questions and next implementation design

1. **Are the six categories genuinely distinct by feel and mitigation,** or are we accidentally only renaming fire rate? Target hit geometry, range, stagger, bleed and sustained ammo/stamina usage must differentiate them.
2. **Early Impact AoE vs Compys:** Do we need a special low-level scatter sling and a club sweep? Can plain melee slash sweeps be a simpler early-game anti-swarm option consistent with Light -> Slash?
3. **Do all large predators become Slash-favored?** Tarbosaurus and especially T. rex need explicit owner decision because their shipped family currently strongly resists Slash.
4. **Is Might ranged viable early enough?** Spear throwing exists only at design level; strong mid-game harpoon and cannon progression may be needed before firearms dominate.
5. **Can species hold mixed defenses?** Styracosaurus/Triceratops frontal armor vs exposed flanks suggests weak-point/part-based armor rather than one global label. Such complexity is not yet implemented.
6. **What firearm era fits the island fantasy?** The user explored rifles, shotguns, Gatling, grenade and rocket launchers, but the technology unlock order and frequency of automatic weapons are NOT agreed.
7. **What is supported vs handheld gun classification?** Require explicit weapon-mode class profiles and practical gameplay differences without accidentally rewarding a user for mounting/dismounting purely to swap their higher IV.

**No item definitions, animal stats, combat multipliers, skill tree unlock levels, Godot weapon code or save formats were changed by this document.**
