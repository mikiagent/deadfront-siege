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
