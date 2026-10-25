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
