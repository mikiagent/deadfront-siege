# DEADFRONT: Skyblock economy + Durango survival + ARK breeding, with optional frontier risk

**Status:** Owner-directed design clarification, 2026-10-25. This document separates **CONFIRMED** requirements from **PROPOSED** solutions and **OPEN** balance choices. No gameplay systems are claimed to be implemented.
**Related:** [World](world-design.md), [Economy](economy.md), [Skills](skills.md), [Safe Home / Logistics / Upbringing](safe-home-expeditions-offspring-and-identity.md), [Tribe / Lineage](tribe-lineage-domain-and-labor.md), [PvP / Sieges](pvp-raiding-local-alphas-and-siege-fairness.md).

## 1. Product synthesis

**Owner framing:** Think **Minecraft Skyblock mixed with Durango and ARK: Survival Evolved**.

- **Skyblock-like pillar:** A small but permanently safe, player-owned home island is the heart of an expandable, increasingly automated production economy. The player saves materials, accumulates durable infrastructure, recruits/raises inhabitants, unlocks efficient resource chains, and can **purchase larger private islands for a hefty in-game price**. This reference is to a protected island-building/economic-progression fantasy; it does **not** automatically require literal floating islands or Minecraft-style block generators.
- **Durango-like pillar:** Expedition to distinct regional islands/climates, meaningful gathering, signed material traits, cooking buffs, specialization, attribute-sensitive crafting and markets.
- **ARK-like pillar:** Diverse prehistoric animals, wild stat spikes, selective breeding/raising of animals and humans, meaningful equipment, persistent rosters, optional exposed frontier settlements and dangerous combat.
- **Owner's strategic rule:** **Players should naturally keep their best people, elite breeding stock, irreplaceable gear and exceptional materials at their private island**, with only affordable-to-lose workers, mounts, tools, structures and inventory deployed to risky locations. Players voluntarily decide how much to gamble. Progress should be possible and rewarding without PvP raiding.

**Success measure:** A cautious non-PvP player can build an impressive tribe, develop better lineages, access engaging PvE expeditions and progress their economy without being forced to expose home. A risk-seeking player can earn additional profit from frontier territories, but repeatedly raiding others must not be an easier dominant progression strategy than farming, manufacturing, trading, exploring or raising a productive tribe.

## 2. Safe home: island sizes and costly upgrades

**CONFIRMED:**
- Every player receives a private, permanently **unraidable** home island; people, dinosaurs, gear, buildings and stored loot kept there are not subject to hostile PvP/PvE raids.
- The player can **buy a larger, fresh private home island for a hefty in-game price**, which contains **higher-level natural resources**. Purchasing means **abandoning the old island**, not adding land to it. This is a meaningful wealth sink, not a real-money shortcut.
- A larger island increases viable space for housing, farms, manufacturing, pens, education, storage, staging and logistics. Supporting population also needs buildings/food/infrastructure; raw land alone does not guarantee free unlimited inhabitants.
- All materials recovered from remote regions may be secured at home.

**PROPOSED island-upgrade loop:**
1. Start with a modest island that is sufficient for early survival, a handful of stations and people.
2. Earn a hefty **in-game resource/currency** requirement and optional economic infrastructure prerequisites to purchase a larger private island.
3. **Abandon the former private island** and start again on a fresh larger private island with higher-level nodes. Dismantled old-island **building materials** transfer through a dedicated **Ender Chest-like salvage box**, separate from ordinary gathered-item storage. Migration of residents, dinosaurs, inventories, live worksites and non-dismantled buildings is OPEN. No free automatic rebuild or item duplication.
4. The larger home makes maintaining more skilled workers, high-value bloodlines, advanced education and safe material stockpiling convenient. More space is economic throughput and planning flexibility, **not a direct PvP combat stat bonus**.
5. Make island-scale progression a high-value **non-PvP sink** for the game's simulated economy. A player must not be compelled to enter PvPvE to obtain a reasonably satisfying private island.

**RESOLVED:** Purchases replace the old home with a fresh larger, higher-resource-tier island; the old home is abandoned. Dismantled construction inputs go to the special salvage-only recovery chest, **not an automatic transfer of intact buildings**. **OPEN:** number of island size/resource tiers; price currency and amounts; salvage yield (full or partial); whether purchases wait for dismantling; transfer of humans/dinosaurs/inventories/crops/eggs/unfinished worksites; chest capacity; coastline, map procedural generation and performance caps. [Canonical decision](../game-design/decisions.md).

## 3. Age is connected to level without making newborns instant adults

**CONFIRMED:** The player's **age/life-stage presentation should be related to individual level**. Offspring still **mature on timers** with food quantity/quality and youth education requirements. New adult descendants begin at a low personal level, grow skills through experience and can someday become veteran specialized workers. Existing characters never reset on adoption.

**PROPOSED hybrid:**
- Timed, well-fed development is required to progress from infant -> child -> youth/learner -> eligible young adult. No newborn becomes an adult merely by performing a few actions.
- After adulthood, **level bands drive apparent adult age and experience** (young adult, mature specialist, seasoned veteran, potentially elder), including body posture/visual aging and interaction flavor. This ties the feeling of maturity to personal progress without using adult age as a punitive timer.
- Chronological time still exists in the genealogy/childcare simulation; consider whether adults physically age in real time a separate **OPEN** decision.
- Do not make gaining XP lead to automatic death or inherited skill reset unless explicitly chosen after playtesting. Let a great smith remain productive as a veteran.

**OPEN:** Exact stage/level mapping; whether the number labeled Age is literal years or a visual maturity tier; whether real-time adulthood aging can ever cause death or retirement; how youth study interacts with personal levels.

## 4. No market or loot progression bypass through high-level equipment

**CONFIRMED (owner settled): Strict personal-level equip gate, NO downscaling alternative.** A human cannot equip a weapon, armor piece, power accessory or power-bearing tool above their **own earned level**, whether acquired by gathering, crafting, trading, purchase, gifting, raid or inheritance. A level-5 descendant may store, carry, inspect and trade a level-40 crossbow but cannot **equip or activate** it. No special passive or gear-triggered effect should remain usable by an underleveled human to bypass the restriction.

The rule must apply to **players and NPC human workers/companions** and not depend on tribe wealth or a predecessor's level. Enforce skill/profession prerequisites where high-tier crafting/station production could otherwise bypass personal experience. **OPEN** exceptions for building materials, consumables, boats, dinosaurs, construction blueprints and whether a definition's minimum required level always equals its item level.

**Market purpose:** People should still buy and sell supplies, food, inputs, blueprints and aspirational rare materials, specialize economically and trade legitimately. The market substitutes for some labor, **not for individual levels, training, education, cultivation, genetics or dangerous-area eligibility**. Keep the economy useful without letting wealthy accounts create instantly max-powered successors.

**OPEN:** exact treatment of consumables, ammo and power-bearing tools; whether skill/profession gates accompany strict item-level gating; whether raw premium materials can be used at lower levels; how regional PvP power brackets interact with gear that remains individually level-legal.

## 5. Contested expansion: disposable investments, not civilization-wide catastrophe

**CONFIRMED:**
- Remote gathering settlements are **raidable** in their applicable PvE/PvPvE regions. People and dinosaurs deployed there may permanently die and are potentially **capturable** through raid mechanics.
- Players may **depart homebound by boat during an active raid**, limited by boat and harbor **level and traits**. Once an actually loaded boat has departed toward protected home, ship, personnel and cargo cannot be attacked in transit.
- **No player-declared PvP raid vulnerability windows.** The owner answered **NO** to raid windows/appointments; do not reintroduce them as mandatory timers.
- **CONFIRMED:** PvPvE access is locked behind **reaching personal level 60 and unlocking level-60 islands**. No earlier PvPvE. Players can remain PvE-only after unlocking if they prefer. **OPEN:** whether a level-60 zone unlock remains with the tribe once the player adopts a personally lower-level descendant, and whether companions/worker garrisons need level-60 access individually.
- Raiding should be difficult, costly and potentially valuable to an attacker, with a realistically strong defender advantage. It must not be a cheap path to exponential wealth compared with industry and non-PvP adventure.

**PROPOSED practical progression path:** protected home economy -> increasingly risky **PvE** expeditions and outposts -> reach **personal level 60** and unlock **level-60 islands** -> optionally establish a **PvPvE frontier** outpost, entered deliberately via a territorial claim/license and displayed loss-risk terms. A developed safe home remains a viable endgame alternative. This gives time to learn siege AI, trade, breeding, crafting and valuable item traits before PvP.

**Workshops not yet decided:** zone-weight classes vs rated attacks vs hybrid; how power classes behave for offline settlements; PvE raid frequency; attacker siege permit/stake and cooldowns; whether an open PvPvE outpost can be attacked fully offline; permanent-death/capture loss limits; if defenders receive advance scouting signals (not windows).

## 6. What winning attackers can take, without making raiding the best industry

**CONFIRMED candidate reward categories** (owner wants these available in the raid fantasy):
- **Salvaged materials from dismantling an exposed remote base**, not from protected private home.
- **Captured exposed adult human tribe members.**
- **Captured exposed dinosaurs.**
- **Exposed gathered resources and unsent storage**, including gear/blueprints/materials that have not actually departed homeward.
- **Equipped items and accessories** on captured, defeated or otherwise loot-eligible exposed units.
- **Potential further rewards** remain open.

**Critical design distinction:** The *types* of loot are owner-directed; that does **not** automatically authorize effortless or total stripping of everything at every successful raid. **PROPOSED safeguards**:
1. Raid permits/consumable siege supply, finite attack force and equipment, travel/replacement costs, and permanent attacker-side casualties create **meaningful sunk cost**. A failed raid should be expensive; a successful raid should not always produce huge *net* wealth.
2. Only the contested outpost and gear of deployed inhabitants are eligible; nothing can pull valuables out of the private home through raid resolution.
3. **Capture** must be a substantial tactical objective with eligibility, containment/transport requirements and time/position costs. Do not instantly convert any downed human or dinosaur to a permanent fully-loyal max-stat worker/pet; identity, prisoner handling, treatment, escape/rescue and allegiance rules are **OPEN**. Restricting captured humans to adults is a conservative proposed starting rule.
4. Dismantling buildings takes time and equipment, may yield **partially recovered materials**, and exposes attackers to defensive counterattacks. Total destruction/claim capture versus partial salvage remains **OPEN**.
5. Limited carrying/storage/extraction capacities and possible per-raid resource/capture limits ensure a successful raid cannot quietly teleport the entire outpost's assets home.
6. A successful defense should preserve the defended property and reward defenders with captured siege equipment/gear, local recognition and economic reputation; attackers should not profit from spamming defenseless sites or easy repeat raids.
7. Use attacker-side **scarce raid opportunities**, meaningful cooldown/permit costs, escalating consecutive-raid costs and unprofitable mismatch rewards to keep **ordinary production/expedition/trading the expected superior wealth strategy**. These limit the *attacker*, not the defender's chosen hour of vulnerability; they are compatible with "no raid windows."
8. Once claimed, a very expensive high-end specimen/worker may be worth defending/evacuating. This is why players keep elite lineages home and send backups to exposed settlements.

**Economy tuning principle:** Compare the expected net value/hour and permanent-loss exposure of optimized raiding with equivalent farming, crafting and trading. Balance so raiding is *occasional high-variance play*, not the mathematically dominant default. This requires simulations with real repair, troop losses, siege supply and loot prices; no percentage is locked yet.

## 7. Regional local alphas without beginner farming

A local alpha should dominate **their chosen region's environment**, feel proud of a superior tribe, and still have stronger environments to explore. A trivial level-only raid gate is exploitable by high-gene low-level descendants, rare traded gear, allied fighters and breeding lines.

**PROPOSED** hybrid: (i) frontier zones have tier ceilings on deployed attacking animals/humans/gear/siege effects; (ii) attacker **whole-force** effective power must be eligible for the target domain's class; (iii) caps include **level-gated equipment** but never assume item ownership equals usable strength; (iv) alliances/summons are counted. No character is forced to leave a region just for becoming successful. Strong enough local alphas should still have meaningful defensive advantages.

An owner's private island is outside this system. No "low-level" attacker may break into someone's protected home. The PvPvE area must have clear opt-in warnings and progression gates so a novice doesn't accidentally place irreplaceable assets there.

## 8. Noncombat retention and safe prosperity checks

1. Play hundreds of hours developing the protected island and skilled tribe with no compulsory PvP. Purchase a larger protected island through **expensive in-game progression**.
2. A newcomer purchases a level-40 crossbow but cannot shortcut from level 5 to top-tier damage, profession bonuses or trait effects. The rule also applies to a new low-level descendant and NPC worker.
3. Raise a child with sustained adequate food, achieve youth education, and become a young adult at their own level. Individual leveling develops visible maturity without deleting the person's earlier career.
4. A dangerous remote outpost with modest replaceable workers loses materials, exposed gear and perhaps some buildings in a raid; elite breeders and premium stockpiles retained at home remain untouched.
5. A defender sends off a loaded boat **during** a raid. Its finite level/trait-based manifest arrives untouched at protected home; remote goods not shipped remain exposed.
6. A powerful tribe cannot farm Stone-age beginners via alt bodies, extraordinary companion dinosaurs, purchased gear or coalition manipulation.
7. In repeated simulated hours, a well-organized industrial/market player can outperform a player trying to live exclusively from attacking weaker bases.

## 9. High-leverage design decisions awaiting owner answers

1. **Gear rule (RESOLVED):** Strict unequippable until the **individual's** required level. **Still OPEN:** consumables and skill requirements, level legal on NPCs, and item/equip level mismatch.
2. **Age map:** Should a level-1 new adult appear about 18–20 and a level-60 character appear older/seasoned, or should level correspond directly to literal age? How do real-time childhood timers and veteran aging interact?
3. **Late PvP entry (RESOLVED in part):** Reach **personal level 60** to unlock **level-60 islands**, where PvPvE is available, always optional to participate. **OPEN:** does the island permission survive switching to a newly low-level descendant, or must the currently controlled character reach 60 to enter?
4. **Attack rate without raid windows:** Spend scarce siege permissions/items and have long attacker cooldowns, or allow constant attempts where costs are the only deterrent? Should offline-garrison defense be separately protected/capped?
5. **Capture and salvage:** Can attackers take multiple deployed humans/dinosaurs in a single raid, and does captured person retain old loyalty/skills with a chance of rescue/escape? How much of structures is recoverable? Can they capture a *domain claim*?
6. **Big-island purchase (RESOLVED in part):** Abandon prior private island for fresh larger higher-resource-level home; store **dismantled building materials only** in a special salvage vault. **OPEN:** upgrade cost/size ladder, whether all property must be dismantled, resource refund fraction and logistics of survivors/dinosaurs/stored items.

**Next step:** Owner workshop choices followed by per-subsystem specs with exact data ownership, save schema/migrations, training/gear requirements, UI details and fairness tests. Do not turn any undecided mechanic into a shipping rule by default.
