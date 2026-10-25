# Weapons

**Status:** v1, 2026-09-17. Owner asked for the crossbow specifically. Source: systems PRD §9.5 (one-hand vs two-hand, spears, work variants, ranged safer but lower DPS), roster PRD §3.2 (player-inflicted statuses).

| Weapon | Hands | Tree | Level | Rate | Damage type | Player status on hit | Notes |
|---|---|---|---|---|---|---|---|
| Stone knife (work) | 1 | Weapon/Tools 1 | 1 | fast | slash | bleeding_target on crit | cheap, weak, spares combat durability |
| Combat knife | 1 | Weapon/Tools 15 | 15 | fast | slash | bleeding_target 25% | |
| Club | 1 | Weapon/Tools 1 | 1 | medium | blunt | groggy 35% | the capture opener |
| Work axe / Combat axe | 1 | Weapon/Tools 1 / 15 | 1 / 15 | medium | slash | bleeding_target | gathers wood |
| Spear | 1 | Weapon/Tools 10 | 10 | medium | pierce | — | reach, no 1H/2H split (PRD) |
| Two-hand axe | 2 | Weapon/Tools 25 | 25 | slow, AoE | slash | bleeding_target | Onslaught stance |
| Two-hand club | 2 | Weapon/Tools 25 | 25 | slow, AoE | blunt | groggy 50% | best capture opener |
| **Bow** | 2 | Ranged 10 | 10 | 1 shot / 1.4 s | pierce | bleeding_target on crit | arrows: stone, bone, copper, iron heads; kiting at Ranged 20 |
| **Crossbow** | 2 | Ranged 35 | 35 | 1 bolt / 2.6 s, reload animation | pierce, high | bleeding_target 40%, groggy 20% on head | 2.2× bow damage per shot, half the fire rate, no move-and-shoot; the raid weapon. Bolts: bone, copper, iron |
| Throwing stone | 1 | Ranged 1 | 1 | 1 / 1.0 s | blunt, low | — | pulls a single creature |

Crossbow recipe (flexible slots, Weapon/Tools 30 + Ranged 35, technical workbench): **stock** (wood with `straight`, primary), **prod** (bone, horn or copper), **string** (tendon or twine), **trigger** (copper or black iron part). Level = mean of the four. Bolts: **shaft** (branch or bamboo, primary) + **head** (bone, copper, iron) at any workbench.

Design rule from the PRD: ranged is safer and lower DPS than a good melee set, and the default for group hunts and raids. The crossbow is the exception that trades rate for burst, so a solo player can open a Utahraptor fight from range and still pay in reload time.


## 2026-10-25 owner direction: six archetypes, tied to current damage channels

The canonical future-system specification is [Combat, Pack Leadership and Existing Godot Integration](../game-design/15-pve-exploration-and-combat.md). **Weapons are classified by primary use attribute (Dexterity or Might) and damage channel (Impact, Pierce, Slash):**

| Primary inherited IV | Impact **I** | Pierce **P** | Slash **S** |
|---|---|---|---|
| **Dexterity (D)** | **DI:** boulder thrower, catapult, slingshot | **DP:** bow, gun, blowdart, crossbow (proposed) | **DS:** whip, throwing axe |
| **Might (M)** | **MI:** hammer warrior, boxer, stomp | **MP:** javelin, spear, Stegosaurus tail spikes | **MS:** sword, axe |

This is **owner-provided taxonomy**, not verification that every item is implemented. Current [combat counter values](../../game/data/combat_counters.json) use `blunt`, `pierce`, `cut` internally, so **displayed Impact -> internal `blunt`**, **Pierce -> `pierce`**, **Slash -> `cut`/`slashing`**. A swung axe may be Might/Slash while its throwing attack is Dexterity/Slash if mode-based attributes are approved. Keep **Melee/Ranged skill and personal equip levels** separate from raw attributes. **Dexterity** supports aiming/catapult targeting, while Endurance affects the constructor operating/loading it; **Intelligence** can support commander coordination. See the full chapter for current raptor-pack AI and planned research/worksite dependencies.

**OPEN:** damage/accuracy formulas, secondary stat weights, support rally mechanics, whether crossbows use this Pierce family as suggested, and catapult siege-team proficiencies. Do not treat all of these example weapons as existing items.

**LATEST owner-approved terminology:** **Dexterity** and **Might** are inherited IVs; **Impact**, **Pierce** and **Slash** label attack actions. Final shorthand **DI, DP, DS, MI, MP, MS**. An individual creature may have more than one mode. **Stegosaurus** spiked tail should chiefly Pierce: heavy **MP**, aimed **DP**; optional glancing rake **DS** is proposed. Future **Brontosaurus** example has **DS** tail whip and **MI** stomp, huge HP but low defense vulnerable to Slash; current **Brachiosaurus** does not yet work that way. [Species and mechanics](../game-design/15-pve-exploration-and-combat.md).

## Latest owner technology and mounted-combat preference (2026-10-25)

**The owner explicitly prefers exploring a comparatively primitive civilization, not assuming automatic progression into modern automatic guns, rocket launchers, exosuits or mechs.** The advanced firearms in earlier six-class brainstorms are **optional experiments only**, not a default or approved tech tree. **Might** must be powerful/accessible early with clubs (MI), spears and thrown heavy javelins (MP), axes (MS), before advanced Dexterity ranged weapons are common. **Dexterity** naturally expands later to better bows, crossbows, accurately thrown/controlled weapons and possible advanced precision tools. **Might still matters late**, especially with better metal/materials, trained individuals and **mounted melee/polearms and timed cavalry attacks**; being mounted is not automatic damage amplification.

**Proposed primitive six-cell examples:** **DI** sling/accurate stone throw; **DP** bow/crossbow; **DS** thrown cutting axe or accurate passing slash; **MI** maul/mount-assisted club or body shove; **MP** heavy javelin, lance, long spear, braced mounted thrust; **MS** heavy axe, greatblade, rider's pass-by cleave. Range, attack speed, recovery, wield mode and creature attack class remain separate. **Future Brontosaurus** long **DS whip** at range and near-leg **MI stomp** punish blind approaches, while visible animations/attack windows create opportunities for foot melee and mounted attackers. [Mounted combat](../game-design/12-expedition-mounts-and-command.md).

## 2026-10-25 owner-accepted weapon classification and dinosaur matchup test

**Owner selected the six-class framework as the working weapon design direction:** **Dexterity = control**; **Might = force**, both valid for **melee and ranged**, crossed with **Impact = disrupt**, **Pierce = penetrate**, **Slash = shred**. A weapon/attack mode has **one primary IV** (D or M), **one damage verb** (I/P/S), and **independent delivery** (melee/ranged/siege) and **behavior** (speed, range, spread, burst/automatic, windup/recovery). **Do not categorize solely by firing speed.** Avoid making Might synonymous with melee.

|  | **Impact (I)** | **Pierce (P)** | **Slash (S)** |
|---|---|---|---|
| **Dexterity (D): controlled operations** | **DI** slingshot, portable grenade/rocket launcher, aimed catapult | **DP** bow, crossbow, rifle, sniper | **DS** shotgun or shred-pattern scattergun, throwing blade, supported Gatling |
| **Might (M): force/heavy handling** | **MI** hammer/maul, heavy handheld demolition cannon, powered hammer | **MP** spear/lance, heavy harpoon gun | **MS** greatsword/chainblade, physically carried heavy rotary/minigun |

**Proposed gun distinction:** Shotgun/Gatling 'Slash' is an *intentional videogame shredding abstraction*; bullets physically penetrate, so later realism-first design may choose different ammo/modes. A mounted Gatling may be **DS**, its carried heavy-handling variant **MS**, provided the mass/stabilization/stamina/recovery differences actually exist. DI portable explosive launcher versus MI heavy mobile cannon similarly differ by what IV determines operation; Might can still enjoy **ranged endgame**.

**Proposed armor matchup bands:** **Slash -> Exposed + Light; Pierce -> Light + Medium; Impact -> Medium + Heavy**, while attack contact, reach, mobility and defensive armor totals remain independent of weakness. **All 19 existing animal species** have proposed best **D** and **M** weapons, with current counters and unimplemented firearm status marked, in [Dinosaur Weapon Matchups](dinosaur-weapon-matchups.md).

**Status:** The six archetype names/definitions and independence of fire rate, delivery and defense are owner accepted as *design direction*. The example firearms, powered weapons, animal matchups, exact ammo types, fire rates, numerics and crafting unlocks are still speculative. No runtime weapons added.

## Conditional Weapon Mastery Bonuses (owner requested 2026-10-25; values unapproved)

Owner now asks for **some weapons to reward skillful conditions**, particularly **MP** mounted lance/spear/javelin hits as rider/mount speed builds, and **DI** (Dexterity/Impact) accurately landed long-distance stones/projectiles. The bonus is a **per-attack optional mechanic**, *not* an automatic rule about all Pierce being speed dependent or all Impact being long-range. The existing six classes remain unchanged.

| Example | Type | Skill condition | Intended payoff |
|---|---|---|---|
| Mounted lance/spear | **MP** | Forward closing speed, straight committed run-up, aligned strike contact | **Momentum Strike**: extra capped hit or stagger, mount may miss/collide/overrun; requires rider timing |
| Forward-thrown heavy javelin | **MP** | Genuine forward motion and release control, projectile reaches target | **Running Throw**: limited launch-force benefit; no automatic bonus for throwing farther |
| Sling stone | **DI** | Accurate projectile hit after traveling through demanding fraction of sling's effective range | **Longshot**: limited precision-hit damage or stagger; aim difficulty increases with distance |
| Bow/crossbow | **DP** | Optional accurate weak-point distant shot | **Sharpshot** rather than blanket range damage |
| Charging club/hammer | **MI** | Valid committed body momentum or breakable defensive posture | **Collision Break** stagger (not a free constant buff) |
| Two-hand axe/sword | **MS** | Correct flank timing or genuine multi-target cleave | **Follow-through** for sustained Slash |
| Controlled whip / thrown cutting blade | **DS** | Timed passing sweep / target positioning | **Passing Cut**, situational accuracy/arc reward |

**Crucial gameplay distinction:** effective velocity **toward** target and attack alignment, not the mount's maximum speed or a speed meter in isolation. Distance bonus rewards **rare precision successes**; the projectile doesn't become magically more powerful simply for traveling farther. Any actual bonuses need caps, projectile range/accuracy constraints, and no auto-boost vs stationary enormous bosses. A mounted human+dinosaur is still one companion unit with limited independent mount attacks, not two full damage dealers. Late primitive weapons, high-grade tame training and skills can remain viable without guns. Full behavior spec: [12 Mounted Combat: Mastery Bonuses](../game-design/12-expedition-mounts-and-command.md). No new skills, item definitions or stats implemented.

## 2026-10-25 melee Slash combos, Berserker Frenzy and large-mount reach

**Owner's newest attack mastery proposal:** **Consecutive landed direct attacks ramp damage**, creating an especially attractive **melee Slash** identity. **Berserker/Ravager Frenzy** is the mount class's signature consecutive-hit reward; some human **MS (Might/Slash) and DS (Dexterity/Slash) melee** weapon modes may share a smaller **Combo/Rend** version. These bonuses follow **actual validated hits** and capped stacks; a miss, disruption, long gap or target change normally resets them, and bleed/poison ticks or cleave hits on many enemies must not produce extra automatic stacks. Attack cadence grace should permit heavy slower Slash axes/greatswords, not only quick daggers. An example +5% per qualifying follow-up up to +20% is **not approved tuning**. A Berserker trades exposure/time within enemy range for a higher sustained-damage ceiling. **Tyrant T. rex** instead favors large committed bites/stomps rather than Frenzy.

**Important T. rex logistics:** **T. rex IS tameable and rideable by owner's design decision**, though **current creature JSON still marks it non-tameable**. A human rider high on Rex's back can't hit a tiny ground dinosaur with an ordinary sword just because the T. rex can reach it with jaws or feet. Validate **rider's own weapon hit volume**, hand position, saddle elevation and target body part separately from **mount attack volumes**. On huge mounts a rider typically commands MP bite/MI stomp and uses a real line-of-sight ranged weapon; low/mid mounts support practical close-quarters MS/MP cavalry. Natural mount attack power uses the dino's genes/attack strength; rider intelligence/training helps targeting rather than transmuting personal human Might into Rex's teeth. All damage chains must obey one composite attack budget for a mounted pair.

[Full Frenzy, giant saddle reach, tameable Rex and mount tactics specification](../game-design/12-expedition-mounts-and-command.md). No implementation changes in this discussion.

## New 18-weapon craftable material progression (owner requested 2026-10-25)

The new [Six-Class Weapon Crafting and Materials chapter](../game-design/23-weapons-and-material-crafting-progression.md) lists **all 18 proposed core weapons** (one DI/DP/DS/MI/MP/MS each in Stone/Bone Early, dinosaur-composite + first Copper Mid, and Forged Iron Late), **exact proposed item ID/ingredient quantities**, existing butcher/gather sources, proposed stations, and **WPN-01..WPN-24** missing-item/recipe/metal-smelting implementation backlog.

**Core material truth:** `slingshot`, `bone_hammer`, `work_axe` already have both item and recipe; `stone_knife` item exists but currently no separate combat-item recipe (improvised recipe makes `stone_knife_work`); `raid_maul` item/recipe exist with **generic metal** rather than intended forged iron + dinosaur scute/bone. `bow`, `crossbow`, spear item, arrow/bolt ammo, whip etc. are missing even where skills are listed. `predator_tendon`, `raptor_talon`, `dense_bone`, `armor_scute` drops already exist, as does Desert copper ore. Copper/iron-ingot item definitions exist but correct ingot production and Smelter/Forge stations do not; `iron_ore`, true teeth and horn drops need future additions. **Do not claim all 18 currently craftable.** Modern firearms remain outside this primarily primitive default weapon progression.

**Owner refinement: endgame WEAPONS USE MANUFACTURED COMPONENTS, NOT RAW DROPS (2026-10-25).** The [current canonical 18-weapon and crafting chapter](../game-design/23-weapons-and-material-crafting-progression.md) supersedes its first direct-ingredient Iron table. Final Late assemblies consume crafted parts such as **reinforced_bone_block, reinforced_stock, reinforced_haft, long_lance_shaft, cured_hide_binding, braided_sinew_cable, honed_talon_set, forged_iron_fittings, iron_chain_links, forged_maul_head, forged_spearhead, forged_greatblade and iron_trigger_mechanism**. Each has a documented upstream item-level craft chain from existing dinosaur butcher loot or gathered wood/resin plus true ingot smelting/refined-bar forging. `Scute-Core Iron Siege Maul` must have a genuine **shaped_scute_plate** in its forged head. Existing raw wood->split->plank stages are confirmed; **treated_plank, shaped bone blocks, refined bars and shaped iron components are NEW**. Adding their items/recipes/stations and strict-identity crafting gates is now specifically tracked as **WPN-21..WPN-24** in the chapter. No game code or item data was changed.
