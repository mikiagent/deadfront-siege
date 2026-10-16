# Durango: Wild Lands — client systems inventory vs the Systems PRD

**Date:** 2026-10-16
**Source:** Android client `durango-wild-lands-5-2-1plus2001141741.apk` (build 5.2.1, January 2020, late global). Unity 2018-era build, IL2CPP, arm64 and armv7.
**Evidence tag used below:** **[client]** = the name exists in the shipped client's type metadata.

## How this was produced

Only identifier names were read. The IL2CPP file `global-metadata.dat` (format version 24.0) stores the names of every namespace, type, method, field and enum member. A short parser listed them. No code was decompiled, no native library was opened, and no art, audio, text tables or other assets were extracted. Nothing from the client went into `game/`.

What this evidence can and cannot show:

- A name proves the client knew about a concept. It does not prove the feature was live, tuned, or reachable in this build.
- Enum members are the most reliable signal. They are closed lists the client and server agreed on, so a missing member is meaningful.
- Balance numbers, recipes and species lists are data, not names. They are not in this inventory.
- Most game rules ran on the server. The client mirrors them through a shared `Shared.*` enum layer and about 985 network message types in a `Messages` namespace.

## Architecture facts worth knowing

- **Client/server split.** The client is a thin view over a server. `Shared.*` holds enums both sides used. `Durango.Network` sends MsgPack packets.
- **An offline mode existed in the client.** A `Durango.Offline` namespace holds a local `GameServer`, `World`, `Gateway`, `MarketManager`, crop and terrain loaders, and `Cheats`. It looks like a developer harness that runs the server rules in-process. This is the same shape Deadfront needs: one process, server-style rules, no network.
- **The tutorial is a data-driven flow graph.** `Durango.Logic.PlayGuide` has about 110 types: `Flow`, `FlowCondition`, `FlowStack`, and dozens of to-do and condition nodes such as `FindCraterToDo`, `CraftToDo`, `KillAnimalCondition`, `MarketBuyToDo`. Designers authored onboarding as JSON flows, not code.
- **Terrain is chunked tiles** with separate mobile and PC chunk implementations, a landmark library and per-biome sprite info.
- **Mobile push notifications** fired on craft complete, build complete, skill research complete, faction, explore, mail, market, chat, estate, clan and event.

## Confirmations of the PRD

These PRD claims match the client's closed lists.

| PRD section | Client evidence |
|---|---|
| §5.2 eight base attributes | `Strength, Charisma, Dexterity, Agility, Endurance, Will, Intelligence, Perception`. Constitution is Endurance and Wits is Perception. |
| §5.1 eight occupations | `Engineer, Office, Student, Farmer, Waiter, Soldier, Homemaker, Jobless`. Technician is Engineer, flight attendant is Waiter, job seeker is Jobless. |
| §7.2 twelve skill trees | `Survival, MeleeCombat, RangedCombat, Defense, Butchery, Gathering, Cooking, Weaponcrafting, Armorcrafting, Constructing, Farming, Process`. Tailoring is Armorcrafting. A thirteenth, `S02OilPoison`, belongs to Season 2. |
| §7.1 unlearning | Skill requests are `Info, Learn, Untrain`. A returner action `SkillReset` also exists. |
| §11.5 pet aging | Pets carry `AgingSince` and `AgingUntil`. Pet food has a `RejuvenatingDays` value, so rejuvenation came through food. |
| §11.5 no breeding | No breeding, egg-hatching or generation identifiers exist. |
| §11.4 no flying or aquatic species | No flying, pterosaur or aquatic identifiers exist. Swimming is a player and pet state only. |
| §4.4.1 no caves | No cave identifiers exist. |
| §14.5 unstable goods need cargo warp | `CheckUnstableItem`, `CollectUnstableItemCondition`, `Cargo`, `CargoReceiver`, and `CargoWarpholeTaxToClanFund`. |
| §16 encouragement | An `Encourage` identifier exists. |
| §6.3 hunger and thirst as states | Player statuses are fatigue modifiers. `Hungry` and `Thirsty` appear as animal states. See gap 4 for the stat layer. |
| §13.3 sprinklers, rated medium | **Upgrade to confirmed.** `Sprinkler`, `SprinklerState` and a sprinkler data reader exist. |

## Gaps and contradictions

Each item says what the client shows and what the PRD should do about it.

### World

1. **Biome is a tile property, climate is an island label.** The `Biome` enum has 15 members: `TemperateForest, TropicalForest, Desert, Tundra, SnowField, Grassland, SwampMud, Volcanic, PebbleBeach, SandBeach, ColdOcean, WarmOcean, River, Lake, Lava`. "Savannah" and "Blue Tropical" are absent. The PRD's ten climates in §4.4 are probably island-level names over a mix of tile biomes. **Action:** split §4.4 into tile biomes and island climates.
2. **Fatigue has twelve climate categories, not five resistances.** `FatigueCategory` lists `Default, Hot, VeryHot, Cold, VeryCold, Humid, Arid, ScorchingSun, Gale, Poison, Snowstorm, VolcanicHeat`. Heat and cold each have two tiers. Arid, poison gas, snowstorm and volcanic heat are separate. **Action:** replace the five-resist list in §5.2 and §6.6 with these categories.
3. **Weather has six states.** `Sunny, Cloudy, Rainy, Snowy, HeavyRainy, HeavySnowy`. Snow weather is missing from §4.4.1. Volcanic ash storms are not a weather state, which fits the `VolcanicHeat` fatigue category instead. Wetness is tracked on characters and materials.
4. **Region roles are a closed list of nine.** `Sandbox, Tutorial, Rural, Risky, Outpost, Urban, Safehouse, Instance, Personal`. This maps cleanly onto §4.2: Urban is the city island, Rural the village, Risky the unstable island, Personal the private island, Safehouse the tutorial camp. `Instance` and `Sandbox` have no PRD entry.
5. **Points of interest are a closed list of seven.** `Port, Warphole, Crater, Crack, FactionProp, CargoWarphole, Rift`. Cracks and rifts are in the PRD only in passing. Animal herds spawn from `Region, CraterStable, CraterUnstable, WarpAccelerator`, so craters come in stable and unstable kinds.
6. **Sailing is a route system.** Interactions include register route, explore, travel, withdraw, sailing back, a party's routes, a random personal region and an archipelago region. This supports the §4.3 harbor-route model and adds party sailing.

### Character and survival

7. **The stat model has gauges the PRD omits.** Derived stats include `HungryMax, HungryVelocity, GroggyMax, GroggyVelocity, LifeMax, LifeVelocity, StaminaMax, StaminaVelocity`, plus `LifeSpan, AnimalProductQuality, MaxTamingPet, MaxModularSize`. The enum is shared with animals, so the hunger gauge is most likely the pet hunger budget of §12.4, not a player starve meter. **Action:** keep §6.3 as written, and add a note that hunger is a gauge for animals.
8. **Three summary power scores.** `CombatPower, CraftingPower, CollectingPower`. Stat bonuses come from `Level, CategoryLevel, Title`. The PRD has no summary scores.
9. **Status effects have a type system.** Effect types are `Survival, Fatigue, Modifier, IncrAmplifier, DecrAmplifier, AllowAction, ProhibitAction, Flag, Immune`, plus pet and research effects. §6.4's table describes outcomes. This list is the implementation shape for them.

### Combat

10. **A stagger gauge drives knockdown.** `GroggySection` is `Super, Weak, Groggy, KnockDown`, fed by `GroggyMax` and `GroggyVelocity`. §10.5 and §12.1 describe stun then knockdown as procs. The client models a meter with four sections. **Action:** describe capture windows as a stagger meter.
11. **Animals take injuries per body part.** Combat targets `Head, Body, Arm, Leg, Tail, Back`, and animals carry matching injury flags. The PRD's "no limb-injury sim" in §6 is right for players and wrong for animals. **Action:** add body-part targeting and animal injuries to §10 and §11.
12. **Defense outcomes include automatic versions.** Results are `Hit, Guarded, Dodged, Missed, Evaded, Countered, AutoGuarded, AutoDodged, AutoCountered`. Effects include `CrossCounter, Incapacitate, Tamed`. Actions come in `Random, Sequence, Combo` sets. §10.3 covers manual rolls and parries only.
13. **Weapon classes are wider than the PRD lists.** `BareHands, Dagger, Sword, Axe, Blunt, Spear, Arrow, Stone, Bomb, Chainsaw, Demolition`, plus animal tear and body attacks. Thrown stones, bombs and chainsaws are not in §9.5.
14. **Animal AI has 22 states.** Among them `Peace, Alert, Scared, Battle, Runaway, GiveUp, Help, FoundBody, Eat, Hungry, Thirsty, Sleep, AvoidHot, NotReachable, Groggy, KnockDown`. This is a ready state list for the §11.3 archetypes. `Help` matches herd solidarity. `FoundBody` matches scavenging. `AvoidHot` shows animals reacted to heat.

### Crafting and items

15. **Crafts have four outcomes.** `BigFailure, Failure, Success, GreatSuccess`. The PRD mentions great success and failure but not big failure.
16. **Items can be modified and reformed after crafting.** `CraftType` is `Craft, Modify, Reform`. The PRD has no post-craft editing. This is a large system gap.
17. **Attributes are tags with grades, including negative ones.** Tag grades are `Negative, Neutral, Positive, Rare`. Rareness is `Bad, Normal, Rare, SuperRare`. Tags combine through AND and OR filters. §8.3's yellow and green pips leave out negative tags.
18. **Dye uses colour channels.** Dye recipes extract red, green and blue channels, either randomly or mixed. §9.1 says colour follows material. Dyeing is a separate system.
19. **Items have a coarse grade.** `Bad, Normal, Good`, separate from level and tags.

### Building and land

20. **Buildings decay in four stages and can be remodeled.** Condition is `Normal, Old, Worn, Broken`. Actions are build, destruct, repair and remodel. §13.3 has decay but no stages and no remodel.
21. **The building catalog is a closed list.** `Normal, Fence, Gate, MessageBoard, Farm, Road, Trap, EstateFlag, ClanFlag, Modular, Cage, Warphole, Bridge, ClanEstateFlag, CrackActivateFlag, WarpholeTuner, Pool, MiniGameDance`, plus Season 2 modular types. Bridges, pools, cages, modular buildings and warp-hole tuners are missing from §13.3. Message boards take text or freehand drawing.
22. **Buildings pack into capsules.** Packages go `Packing, Sealed, Unpacking`, and there are capsulate and place-capsule interactions. §13.3 has pack-up but not the capsule item.
23. **Land access has six rights.** `Enter, UseFacility, Give, Take, Occupy, Destruct`, granted per license category `Default, Clan, Friend, Other`. §13.1 has only friends and outsiders.
24. **Players could build voxel statues.** A `VoxelStatue` type exists. No PRD mention.

### Pets

25. **Pet ranks run D to S.** §12.1 says S to C. The enum has D as well.
26. **Pets work jobs.** Pet tasks are `Production` and `Training`. There are also grazing slots sold in the shop. §12.3 lacks both.
27. **Pets have their own skills.** Pet skills have types `Action, StatusEffect, Scripted`, ranks D to S, and contexts `Idle, Battle, Riding, Swimming, Resting, Dead, InsideBuilding`. Targets are the pet, its master, the party or the clan. So pets cast aura buffs. §12.3 has no pet skills.

### Clans, research and economy

28. **Research labs exist for clans and individuals.** Lab tiers run T00 to T05. Categories are `Collect, Craft, Adventure, Battle, Advanced, LivingTech, LightTech, HeavyTech`. Effects apply in clan territory, at clan warp holes, personally or always. The PRD treats research only as a skill-level timer.
29. **Clan funds have five uses.** `Research, ExtendTerritory, ExpandTerritory, DeclareTerritory, ClanMatch`. Clans have ally slots and a clan-war chat channel. §13.4 has none of these.
30. **There are eight currencies, not three.** `TStone, Gem, Coin, CashshopMileage, RPiece, MobileCoin, PcCoin, WarpMatter`. Coins split by platform. Season 2 adds three more resources. §14.1 and open question 10 should list them.
31. **Market listings have a full lifecycle.** States include registered, pending, sold, expired, banned and withdrawn, with payment states. Sorting covers price, level and durability.

### Factions and quests

32. **The faction list differs from §15.1.** `ChlorophylForum, ChamberOfPioneer, TheFirm, TheCommittee, Lama, RescueTf, SubStory`, plus Halloween and cherry-blossom event factions. The Company is likely `TheFirm`. Radio University is likely `Lama`. `RescueTf`, a rescue task force, has no PRD row. About 20 named radio contacts exist, including K and Charlie.
33. **Missions are ordered step lists.** Step types are `Hunt, Collect, ObjectFound, PoiFound, Delivery, TraceObject, GetItem, CustomEvent`. Steps start after or alongside the previous one. Missions cancel on region change, time-out or by the player. Support crates come in three slots, A to C.
34. **Quest cadence includes returners and epics.** Types are `Daily, Weekly, Monthly, Once, Returner, Epic`. There is a monthly attendance calendar, a returner calendar, and a returner kit that resets advisors and skills and grants relief goods. The PRD has no returner loop.

### Late live content the PRD lacks

35. **Warp Rush** is a ranked, seasonal mode with player and clan milestones.
36. **Warp Accelerator** is a rift event with states from rift activated through intermission to end, and its own animal spawns and rewards.
37. **PvP Island** has its own system and rankings for wins, plays and kills. This is the late "Combat Island" in §10.6.
38. **Archipelago missions** have completion rewards.
39. **Season 2** has its own skill tree, rooms, modular buildings, equipment slot and three stone resources.
40. **Music and dance.** Concerts with notes and instruments, plus a dance minigame building. §19 mentions instruments only.

## What this changes for Deadfront

- The PRD's core loop survives contact with the client. Stats, occupations, skill trees, fatigue-as-governor, unstable goods and pet aging all check out.
- The biggest design gaps are **post-craft modify and reform**, **pet skills and pet jobs**, **clan and personal research labs**, and the **stagger meter with body-part injuries**. Each is a real system, not a detail.
- The **offline server** and **flow-graph tutorial** are architecture patterns worth copying as ideas. Neither needs anything from the client.
- Open question 18, the combat era, gets a partial answer. This 2020 build still has action sets with sequences and combos, and auto-defense outcomes.

## Limits

- This build is January 2020, the late global era. It cannot settle KR 2018 behavior.
- A name in an enum may be dead code. Treat each gap as **medium** until a second source confirms it was live.
- No numbers, recipes or species data were read, by choice.
