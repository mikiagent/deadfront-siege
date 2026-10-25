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

**CONFIRMED:** A captured human or dinosaur becomes a **prisoner/captive**, not instantly loyal attacker property. The defending owner has **72 real-world hours** from the server-confirmed capture event to pay a **game-calculated ransom**. **Paid before expiry:** the original player gets the same human/dinosaur back with **their prior personal level, learned skills and trained EVs (effort/training values) intact**, plus the same inherited IVs. **Unpaid at expiry:** the attacker gains the right to acquire/claim that captive. When acquisition is finalized, the captive is an **adult level-1 recruit** who retains **their inherited IVs, physical adult appearance, identity and pedigree**, but must **earn levels, skills and EVs anew**. The claimed captive retains the **inherited IVs/genetic potential**, while their prior **earned level, skills and EVs do not transfer as trained progress to the attacker**. Recruitment, exchange and ransom remain gameplay paths, with acquisition never an instant ready-made master worker or fighter.

**Confirmed details:** 72-hour **real-world** countdown (not 72 played hours); ransom amount is **calculated by the game**, not freely set to an arbitrary amount by attacker; ransom preserves **level + skills + EVs**, attacker recruitment retains **IVs** while requiring a fresh career/EV training. **Open details:** the ransom pricing formula, payment currency and caps; how a 72-hour expiry interacts with service outages or missed notifications; whether the attacker must click Claim after expiry; the adult captive's level-1 career begins immediately on attacker acquisition, while **their adult body and appearance do not de-age**; how exchange/rescue paths affect prior EV/skills; and whether the currently controlled avatar can be captured. The user's phrase *freshly leveled* establishes a **reset of trained progression upon attacker recruitment**, but does not itself establish a specific starter level or retroactive reset of a captive that is ransomed successfully.

## Custody state machine: confirmed invariants, proposed engineering mechanics

1. **Capture event (CONFIRMED):** Only an eligible exposed PvPvE settlement person or dinosaur may be captured. On server acceptance, start the **72 real-world hour deadline**. Assign a persistent captive record with the original person's/dinosaur's stable ID, original tribe, attacker tribe, **IVs**, personal level, earned skills, **EVs**, equipment and captivity status. This custody record is authoritative and not a duplicated roster entity.
2. **Pending ransom (CONFIRMED):** The **game calculates** a ransom amount and displays the price and deadline to the original owner. The attacker has custody but **cannot recruit/train the captive yet**. Prevent duplicate listing, breeding or battle deployment while awaiting the outcome (PROPOSED anti-exploit).
3. **Paid during the 72-hour window (CONFIRMED):** On server-verified payment, the same captive returns to the defender with their **original level, original learned skills, trained EVs and inherited IVs all preserved**. Exact health, injuries, equipped item ownership and recovery destination remain OPEN.
4. **72 hours expire unpaid (CONFIRMED):** The original owner's standard ransom window ends and **attacker acquisition becomes allowed**. Whether transfer happens automatically or via a manual **Claim** action is OPEN. If the system supports negotiated exchanges or rescue, concurrency and deadlines must be explicit.
5. **Claim and recruit/train (CONFIRMED gameplay outcome):** The new owner receives the *same inherited IV/genetic potential*, but **does not receive the original owner's career level, trained skill progress or earned EVs** as immediately usable strength. They must **recruit, level and train** this **level-1 adult** for their own tribe. **CONFIRMED state outcome:** at finalized attacker acquisition, reset **personal level to 1 and its earned XP, trained EVs and learned skills to fresh-start values**, **retain physical adulthood and appearance**, and preserve genetic IVs, identity and pedigree. **PROPOSED technical implementation:** represent this with a new career/progression record on the same permanent individual ID, keeping biological development/visual adulthood separate from earned-level-based age styling. Do not destroy the captured snapshot earlier, or paid ransom cannot restore the trained owner record.
6. **Resolved / released:** A person/dinosaur cannot exist as both an active defender worker and an active attacker recruit, and the 72-hour deadline must close atomically with payment/claim. Exchange, rescue, release and captivity death remain separate **OPEN** transitions.

### IV vs EV and progression interpretation

| Attribute | Defender pays ransom on time | Attacker gains captive after nonpayment |
|---|---|---|
| Inherited IV / genotype | **Preserved** | **Preserved** |
| Previously earned level / personal XP | **Preserved** | **Level 1; earned XP restarts** |
| Learned skills / trained proficiencies | **Preserved** | **Not transferred at trained values; retraining required** |
| Earned EVs (development/training values) | **Preserved** | **Start fresh and re-earn** |
| Person or creature identity / pedigree | **Same individual** | **Same inherited specimen; transfer ownership, no duplicate** |
| Adult body / physical appearance | **Preserved** | **Preserved adult appearance; does not turn into child** |
| Equipment, injuries, mental state | **OPEN** | **OPEN** |

**Interpretation note:** In this design, **IVs** means inherited individual/genetic values and **EVs** means developed values gained through training, experience or upbringing. Whether childhood nutrition modifies inherited IV, expressed baseline or earned EV must be specified in the genetics chapter. **Owner confirmed exact recruit starting level: 1.** Regardless of the prior owner's earned career, **captured adults remain adults, with the same adult visual appearance**, even when their new career restarts at level 1. For dinosaurs, retain the corresponding existing physical maturity and model/appearance; do not recreate a baby or restart childcare. This is a deliberate exception to the general presentation rule that experienced characters may look older at higher levels. Exact later visual-aging behavior is still OPEN.

### Pricing and timer contracts

- **Fixed duration:** 72 hours of real elapsed time starting from the confirmed server-side capture. This is **not** a login/playtime timer. Use a UTC expiry timestamp, display the owner-local date/time plus remaining time, and verify payment/expiry atomically on the server (PROPOSED technical implementation).
- **Fixed method:** System-calculated price. Its *formula* remains OPEN: relevant inputs may be species, IV potential, original level, skills, trained EVs, rarity and historical value. The attacker does not freely invent ransom prices.
- **Online/offline behavior:** Countdown continues in real time, but notification channel, reminder delivery, outage protection and dispute/error retries remain OPEN. This is a substantial risk for permanently valuable individuals. Do not silently assume a user reads messages while offline.
- **Single-economy control:** Payment must debit once and resolve captive state once. On timeout, even an attacker who can claim does not instantly receive the defender's completed training. Level/skills/EV reset applies **on attacker acquisition**, not before defender could pay.

## Ransom anti-grief design risks
- **72 real-world hours** is confirmed and continues while offline. Defenders can lose valuable genetic specimens if they miss it. Provide prominent inbox/push notices and early reminders, and explicitly decide what to do about failed notification or service outage (PROPOSED mitigation, **not** a change to the settled 72-hour duration).
- **Game-calculated ransom** is confirmed. The exact algorithm and currency, minimum/maximum cost, whether original acquired skills/EVs affect the price, and how much an attacker earns versus a currency sink remain **OPEN**. Ransoming an elite individual should be consequential without becoming guaranteed unaffordable extortion.
- Repeated recapture of a just-released elite person/dinosaur risks becoming the best form of farming. Consider ransom-protection cooldowns, captor-cost fees and raid/captive caps; these are proposed, not approved.
- Optional late PvPvE should not generate wealth faster or more reliably than private industry, trade, breeding and PvE expeditions.
- The original owner keeps other people, dinosaurs and goods **at safe home** for this reason. Only units deliberately fielded to contested settlements are exposed.

## Settlement siege versus island resets
An **unstable island resource reset** is never a player siege and should automatically **dismantle bases** on the resetting island into the dedicated building-material recovery chest. The specific refund percentage on reset is **unsettled**; private-island paid upgrades have separately confirmed **100% building-material returns**. PvPvE raids attack *settlements*, not islands.

## Acceptance scenarios
1. A human or dinosaur captured at a PvPvE outpost appears exactly once as captive with original persistent identity, **server-set 72-hour real-world expiry**, original IVs, level, skills and trained EV snapshot, and **game-calculated price**.
2. Original owner pays on time: captive returns with identical **IVs + prior level + learned skills + trained EVs**; attacker cannot claim them or receive a duplicate after expiry.
3. Original owner fails to pay by hour 72: attacker may claim the same inherited-IV specimen as a **level-1 adult**, with **unchanged adult physique/appearance and pedigree**. Earned XP/skills/EVs restart, and attacker must train them; the original mature specimen does **not** become a juvenile. Housing, recruitment, handling and equipment rules still apply.
4. Original owner remains protected with all residents, livestock and inventory still safely at home.
5. PvE settlements face animal/dinosaur raids only, not human-player sieges.
6. Homebound boat departs mid-raid with only level/trait-capacity permitted cargo; it is not intercepted.
7. Body-switch to low-level descendant preserves tribe frontier unlock, but low-level avatar cannot enter or equip level-60 items.
8. The 72-hour real-time deadline works with offline players. Payment vs expiry race, backend retry, failed notification or maintenance cannot silently duplicate, delete, revert or grant prematurely any human/dino.

## Highest-impact open questions after 2026-10-25 rulings

1. **Game-calculated ransom formula:** What should determine its amount: inherited IV quality, *original trained level/skills/EV*, species, market value, etc.? Which currency is used, and should there be a hard affordability bound?
2. **After expiry:** Does the attacker have to manually click **Claim**, or does their ownership transfer automatically? Could they decline/free the prisoner?
3. **Fresh recruit progression (partly resolved):** Captives restart at **level 1** and keep **adult appearance and inherited IVs**. Should past childhood/education history remain inspectable as biography without granting earned EV/skills? How do visual-age bands work after a captured adult starts fresh at level 1?
4. **Player offline:** Is the confirmed **72 real-world hour** timer always absolute, with multiple push/inbox reminders and perhaps maintenance extensions? How do we avoid technical outages stealing irreplaceable bloodlines?
5. **Other resolution paths:** Can captives be exchanged or rescued while ransom runs, and if so does the original owner preserve all earned EVs/levels on return just as with ransom?
6. **Captive limits and viability:** Per-raid maximum humans/dinos; cannot capture active player avatar or can? What happens to equipment, original family lineage, housing requirements and recruitment/loyalty time?

**Resolved, do not re-ask:** duration **72 real-world hours**; ransom **calculated by the game**; on payment preserve **level/skills/EVs and IVs**; on attacker acquisition **level-1 adult with original adult appearance/physical maturity and IVs**, needing fresh XP, skills and EV training.
