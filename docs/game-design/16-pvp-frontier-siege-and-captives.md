# 16 | Level-60 frontier, settlement siege, prisoners and ransom

**Status:** DRAFT canonical system chapter, 2026-10-25. Requirements marked **CONFIRMED** are owner-directed; exact numerical balance and edge cases are **OPEN**. No implementation or tested multiplayer is claimed.
**References:** [Decision register](decisions.md), [World and island resets](04-world-biomes-and-travel.md), [existing siege workshop](../design/pvp-raiding-local-alphas-and-siege-fairness.md).

## Invariants
- Every player's **private home island is permanently protected**. Islands themselves **are not raid targets**. Only placed **PvPvE settlements** are raidable by players; **PvE settlements** may be attacked by animals/dinosaurs.
- **PvPvE entry:** the tribe keeps the permanent level-60-island unlock once earned, but the **currently controlled human personally must be level 60** to enter. A low-level successor cannot enter just because the tribe has unlocked it.
- Personal-level equipment requirements are strict: over-level purchased, looted, crafted or inherited items are **unequippable**, with no stat-downscaling alternative.
- Owner wants local alphas, not repeat low-player farming. Attacks must be costly, difficult, bounded and realistically defensible; **no player-selected vulnerability/raid windows**.
- When a boat actually leaves a remote harbor **toward home**, its crew/cargo are attack-proof, even during an active raid. Boat/harbor level and traits limit the manifest; undeparted goods remain vulnerable.

## Eligible raiding prizes
- Salvaged materials from dismantling **exposed settlement structures**.
- Captured **human tribe members and dinosaurs**.
- Resources waiting in contested storage/docks; items and accessories belonging to exposed fighters/workers.
- Claim/territory transfer, fractional salvage, capturable numbers, limitations on death, and exact equipment loss **OPEN**. Do not steal from a safe private island or raided 'entire island' landmass.

## Prisoners and ransom: confirmed owner contract

**CONFIRMED:** A captured human or dinosaur becomes a **prisoner/captive**, not instant fully loyal attacker property. **The defending owner gets a ransom opportunity with a time limit. If the defending owner does not pay before the ransom deadline, the attacking player can acquire the captive.** Recruitment, exchange and ransom are all intended pathways.

**Do not over-assume:** The user has not decided exact clock duration, automatic price versus negotiated price, whether transfer to attacker occurs automatically on expiry or requires a claim action, whether inherited loyalty/personal learned skills have friction, or whether the player-controlled avatar can be captured. Such choices remain **OPEN**.

## Proposed custody state machine (subject to owner sign-off)

1. **Captured**: server verifies capture at a raidable PvPvE settlement, records original tribe, attacker tribe, stable individual human/dino ID, creature/person traits, equipment and time; removes normal deployment availability from prior roster without duplicating identity.
2. **Ransom pending**: present price/terms and **visible countdown** to the defender; attacker holds exclusive custody. Captive cannot be cloned, instantly bred for profit, simultaneously listed on markets or used as an attacker while ransom is unsettled (recommended precaution).
3. **Paid within deadline**: escrow moves one payment; same persistent captive returns to original tribe by approved transport/recovery path. Resolve gear and medical condition, keep log.
4. **Deadline expires unpaid**: original owner's ransom priority ends. The attacker now has a **right to acquire/claim** the human/dinosaur. Whether system automatically completes transfer or requires an explicit claim is undecided.
5. **Acquisition**: attacker obtains same identity/genetics/personal XP subject to loyalty/recruitment/holding-capacity conditions. The owner specified ability to acquire, not an immediate free perfect laborer or breeding asset.
6. **Other outcomes**: mutually agreed exchange, negotiated early release, possible rescue/escape, or intentional release, only if later confirmed. Prevent conflicting simultaneous ransom, transfer and rescue transactions.

## Ransom anti-grief design risks
- A deadline running while the defender is offline may erase days of lineage investment before the player ever sees a notice. Recommend a **generous real-time response period**, prominent push/inbox warning and guaranteed minimum notice, but **duration remains open**.
- Very low automatic ransom makes raids pointless; exorbitant ransom makes 'buyback' a sham. Option: system-regulated ransom range informed by stats, level, equipment and species, not unlimited free-form extortion.
- Repeated recapture of a just-released elite person/dinosaur risks becoming the best form of farming. Consider ransom-protection cooldowns, captor-cost fees and raid/captive caps; these are proposed, not approved.
- Optional late PvPvE should not generate wealth faster or more reliably than private industry, trade, breeding and PvE expeditions.
- The original owner keeps other people, dinosaurs and goods **at safe home** for this reason. Only units deliberately fielded to contested settlements are exposed.

## Settlement siege versus island resets
An **unstable island resource reset** is never a player siege and should automatically **dismantle bases** on the resetting island into the dedicated building-material recovery chest. The specific refund percentage on reset is **unsettled**; private-island paid upgrades have separately confirmed **100% building-material returns**. PvPvE raids attack *settlements*, not islands.

## Acceptance scenarios
1. A human captured at a PvPvE outpost appears exactly once as captive with original persistent identity and a ransom deadline.
2. Original owner pays on time: captive returns, attacker cannot separately claim them, and payment/assets do not duplicate.
3. Original owner fails to pay by expiration: attacker can acquire/claim that captive under agreed recruitment rules, rather than the captive automatically returning for free.
4. Original owner remains protected with all residents, livestock and inventory still safely at home.
5. PvE settlements face animal/dinosaur raids only, not human-player sieges.
6. Homebound boat departs mid-raid with only level/trait-capacity permitted cargo; it is not intercepted.
7. Body-switch to low-level descendant preserves tribe frontier unlock, but low-level avatar cannot enter or equip level-60 items.
8. Offline deadline and payment error/retry do not silently duplicate, delete or transfer wrong humans/dinos.

## Highest-impact open questions
1. **Ransom deadline:** hours, days, game time or real time? How do notifications work if player is offline?
2. **Pricing:** system-generated mandatory offer, attacker chooses within guardrails, or free negotiation?
3. **Expiry:** attacker manually claims later, or automatic ownership transfer?
4. **Captive usability:** immediate full loyal tribe member after claim, or additional relationship/training/containment?
5. **Loss limits:** one or multiple captures per raid; can a controlled survivor be captured? Can prisoners die or be rescued?
6. **Raid availability:** offline attacks and permanent capture under AI-only garrisons without player-selected windows?
