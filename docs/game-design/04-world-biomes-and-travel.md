# 04 | World islands, unstable resets, settlements and travel

**Status:** DRAFT, 2026-10-25; the old Durango-oriented description of islands that sink is historical until exact reset presentation is clarified.
**References:** [Decisions](decisions.md), [Audit](audit-and-open-questions.md), [Home island migration](03-private-islands-and-upgrade-migration.md), [PvPvE/captives](16-pvp-frontier-siege-and-captives.md).

## World categories
**Private home island:** Permanently **safe from player and animal raids**. This is the owner's protected economy and housing center. Larger fresh homes are purchased at a high in-game price; largest homes contain approximately level 50–55 natural resource nodes.

**Unstable resource island:** Expands gathering opportunities outside protected home. **Its resources/world state reset periodically**. When it resets, **any constructed base is automatically dismantled and the building materials go to the special Ender Chest-like salvage box**. The island is **not itself a raid target**. Whether reset keeps the same terrain layout or regenerates a new island seed remains OPEN.

**PvE settlement:** A **built camp/base/worksite** in PvE territory, which **may be attacked by dinosaurs or wild animals**, but **cannot be raided by other human players**. The island/wilderness itself is not raided.

**PvPvE settlement:** A **built settlement** in optional level-60 frontier content. **Players may raid this settlement**, not the island itself. The owner has not decided whether hostile animals also attack PvPvE settlements.

## Progression and travel rules
- Higher-resource private homes are substantial non-PvP progression rewards; top safe resources are roughly level 50–55.
- Level-60-and-higher materials occur beyond private homes, preserving PvE expedition and optional PvPvE risk/reward. Source exclusivity and numerical levels beyond 60 remain OPEN.
- **Tribe keeps an achieved level-60 island unlock permanently**, but the **actively controlled human personally must be level 60 to enter PvPvE**. A level-1 descendant may switch to a veteran to visit instead.
- Strict equipment-level gates prevent any newly switched descendant, trader or market purchaser from wielding items above their own level.
- Boats may leave a remote dock **even during ongoing PvPvE raids**; ship and cargo become unattackable only once genuinely **departed toward protected home**. Cargo quantity is bounded by **boat and harbor levels and traits**; dock staging and loading remain vulnerable until departure.

## Resource reset event versus enemy raid
**Reset (CONFIRMED):** resource/node renewal with automatic building dismantle and salvage-vault delivery. No enemy wins the terrain or plunders it by initiating the reset.

**Raid (CONFIRMED):** NPC dinosaur/animal attack on a placed PvE settlement, or a human-player raid on a built PvPvE settlement. Raids can cause combat death, capture and losses under still-open detailed rules. The safe private home never participates.

**OPEN:** Reset frequency, warning/evacuation timing, map reseeding, active workers/animals, stored supplies, eggs, partly supplied worksites and refund percentage. Do **not** automatically copy the **100% paid-home-move material return** to unstable reset.

**OPEN:** Whether player-raided PvPvE settlements are built on resetting islands or on distinct stable territories; reset-versus-siege ordering and safety contracts if overlap is permitted. Permanent base ownership is inconsistent with surprise frequent dismantling unless deliberately designed.

## Tests
1. Players cannot initiate a raid against an island itself, an eligible PvE base or the private home; only an eligible PvPvE **settlement**.
2. PvE animal/dinosaur attack affects placed PvE defenses but not the protected private island.
3. Resource reset restores unstable island resources and dismantles its buildings into salvage recovery exactly once, with approved refund amount, even across save/load.
4. A level-1 controlled descendant with inherited tribe unlock cannot enter PvPvE.
5. A homebound departing boat cannot be intercepted by the ongoing siege after departure.
6. Newly bought larger private home contains appropriate richer local resources and transfer/salvage records.
