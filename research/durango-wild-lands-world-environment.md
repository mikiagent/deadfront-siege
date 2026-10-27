# Durango: Wild Lands — World / Islands / Travel / Biomes / Weather / Time / Environment

Research notes (not a PRD). Claims are tagged with sources and confidence. Where 2015 design, 2016–17 beta, 2018 KR live, and 2019 global live disagree, that is called out rather than flattened.

**Companion files:** [`durango-wild-lands-systems.md`](./durango-wild-lands-systems.md) (survival, progression, crafting) and [`durango-wild-lands-bestiary-combat.md`](./durango-wild-lands-bestiary-combat.md) (animal roster, capture/taming, **the complete status-effect table** — the environment statuses partially listed in §5 below are a subset of it).

**Fetch tip.** `en.namu.wiki` 403s automated fetches. The **`namu.moe` mirror works**: `https://namu.moe/w/야생의 땅: 듀랑고/<subpage>`.

**Game identity.** Mobile sandbox living MMORPG. Developed by Nexon Korea’s What! Studio (director Eunseok Yi / Lee Eun-seok; creative / technical lead Seungmyeong Yang). Published by Nexon. Engine: Unity. Korean title: 야생의 땅: 듀랑고. English store name: Durango: Wild Lands (also styled Durango: Wild Land, Durango Wildlands).

**Service window (high-level).** KR launch 25 Jan 2018. Worldwide mobile 15 May 2019 (all countries except Japan and China per NamuWiki; Japan never launched). Official shutdown: IAP off 16 Oct 2019, servers off 18 Dec 2019. Offline Creative Island / personal island leftover after shutdown.

---

## How to read this brief

- **Shipped** = KR 2018 and/or global 2019 live service unless a date is given.
- **Design intent** = NDC 2015 / early interviews; not always what shipped.
- **Beta** = 2016–17 limited / overseas beta; several travel rules later changed.
- Confidence: **high** = official press, NDC session pages, in-game Survival Tips transcribed on NamuWiki, or matching developer quotes. **medium** = NamuWiki / fandom that describe in-game UI, or contemporaneous press summarizing talks. **low** = Reddit / guides without numbers in official copy.

There is **no standalone English Wikipedia article**. Wikipedia’s Nexon list is used only for high-level identity and is **wrong on shutdown date** (see contradictions).

No GDC talk was found. The developer talks that exist are **NDC 2015** and **NDC 2018** (Nexon Developers Conference), plus E3 2017 / Jan 2018 KR launch press.

---

## 0. Framing: one persistent world made of many islands

### System name
Persistent open-world MMO without channels; world is an archipelago of independently simulated islands.

### How it actually worked
Director Eunseok Lee at the Jan 2018 KR launch preview: Durango is “a vast space where many players can gather. There is no channel or instance dungeons where a few players can group up to play. The world consists of endless islands scattered across the sea.” Island count is scaled with population so density stays roughly even.

NDC 2018 (Yang): unlike typical MMOs that clone the same land into channels, all users were meant to share one linked world. A single giant continent failed internal tests (Nexon staff of ~300 filled the first continent immediately). Spawning extra continents by population created old-vs-new inequality. The shipped compromise: **stable islands** that never vanish (settlement) + **unstable islands** that periodically vanish and regenerate (exploration).

NDC 2015 (Yang): islands are geographically isolated spaces of various sizes and policies. Travel between them is **sea routes (항로)** from harbors. Route travel is “almost instant teleport.” Physical map position was deliberately replaced by a **logical connection graph**.

### Player-facing rules / numbers
- No channels / no instance dungeons (director, Jan 2018).
- Island count adjustable with player count (same talk).
- One “Bronto server” claimed to hold ~10× a typical mobile MMO server; KR planned 1–3 Bronto servers at launch, then merge toward a single global server (same talk; Korea Herald 9 Jan 2018).
- KR launch actually opened Asia Alpha, then Beta (25 Jan), Charlie (27 Jan), Delta and Echo (28 Jan). Five Asia shards merged 24 May 2018. West added 23 Apr 2019. Asia II added 21 May 2019 after global-launch queues. Region is recommended, not mandatory (NamuWiki).

### Edge cases / design choices
- “No instancing” is a **product claim**. Islands themselves function as **shards**: each island is a separate space with its own chat, population, and (in beta) a hard cap. Housing was *not* a private instance; land claims sit on shared stable islands (NDC 2015 explicitly rejected housing instances as “not sandbox-like”).
- Local chat is restricted to the current island (Survival Tip #75).
- After shutdown, Creative Island is a **local offline** leftover of the personal island, not the MMO world.

### Sources
- Inven Global launch preview (Lee): https://www.invenglobal.com/articles/3977/durango-expected-to-be-released-in-korea-first-on-january-25-we-will-make-it-a-global-success
- Korea Herald 9 Jan 2018: https://www.koreaherald.com/article/1555097
- NDC 2018 session: https://ndcreplay.nexon.com/NDC2018/sessions/NDC2018_0012.html
- Appliv Games NDC18 writeup: https://games.app-liv.jp/archives/355374
- Famitsu NDC18: https://app.famitsu.com/20180429_1287201/
- NDC 2015 session: https://ndcreplay.nexon.com/NDC2015/sessions/NDC2015_0073.html
- NDC 2015 notes (tistory): https://dreamrugi.tistory.com/entry/NDC2015-%EC%95%BC%EC%83%9D%EC%9D%98-%EB%95%85-%EB%93%80%EB%9E%91%EA%B3%A0%EC%9D%98-%EC%8B%9C%EB%AE%AC%EB%A0%88%EC%9D%B4%EC%85%98-MMO-%EC%83%8C%EB%93%9C%EB%B0%95%EC%8A%A4-%EB%A7%8C%EB%93%A4%EA%B8%B0
- Game Donga NDC 2015: https://game.donga.com/79518/
- NamuWiki main (servers, dates): https://en.namu.wiki/w/%EC%95%BC%EC%83%9D%EC%9D%98%20%EB%95%85:%20%EB%93%80%EB%9E%91%EA%B3%A0
- Survival Tips: https://namu.wiki/w/%EC%95%BC%EC%83%9D%EC%9D%98%20%EB%95%85:%20%EB%93%80%EB%9E%91%EA%B3%A0/%EB%A9%94%EB%AA%A8

### Confidence
High on no-channels intent, stable/unstable split, sea-route graph, KR/global dates, shard merge history. Medium on “Bronto = 10×” (director claim, no measured CCU). Low on per-island 500-player cap (Reddit beta only).

### Open questions / contradictions
- Wikipedia Nexon list: “Server closed on October 16, 2019.” Official Facebook / Android Police / NamuWiki: IAP disabled 16 Oct, **servers 18 Dec 2019**. Treat Wikipedia as wrong.
- “Single global server” was the goal; live service always had regional shards (Asia / West / Asia II).
- Beta Reddit: “Each server, island, can only hold up to 500 players. Once an island reaches/nears cap, another island is auto-generated.” No official number found. Matches the *design* of population-scaled island spawn, not a confirmed cap.

---

## 1. Island taxonomy (what actually existed)

English store copy, Korean UI, and 2016 beta names do not match 1:1. Map by function, then list aliases.

### 1.1 Tutorial / Company island — Ancora

**How it worked.** After the train-warp prologue, the player wakes on **Ancora**. K finds them, a dog leads to a Company safehouse, Communications Center gives first missions. Leaving Ancora is the first big step. After tutorial you **cannot return** to Ancora or the Company safehouse.

**Numbers.** Ancora ecology is level 1 (NamuWiki footnote: “no reason to go back”). Resources regenerate with a fixed count (NamuWiki tips). Tutorial exit: gather leaves/branches as balloon fuel, then K’s hot-air balloon (BlueStacks; Reddit beginner guide). Lore notes say survivors left Ancora **on rafts** that broke in currents (Durango Note #2) — flavor, not the live tutorial vehicle.

**Edge cases.** Skip Prologue exists in menu (BlueStacks). Balloon vs raft contradiction is lore vs live tutorial.

**Sources.** BlueStacks getting started: https://www.bluestacks.com/blog/game-guides/durango-wild-lands/getting-started-en.html ; NamuWiki island + main; Durango Notes #1–2 on NamuWiki memo page.

**Confidence.** High.

### 1.2 Personal / Tamed island (개인섬)

**How it worked.** Post-tutorial home. Grassland climate, **level 10 ecology**, player picks **one of five terrains** (cannot re-pick). Buildings do not lose durability if construction is completed. Waypoint tent = free teleport home. First domain claim is 4×4; one extra same-size plot free, then paid expansions. Domain can be reset and re-declared **once per day**. At character level 60, raising Personal Island Pioneer Level expands domain without T-stones.

Added later in live service; **village islands were deleted** because personal islands made them redundant (NamuWiki). After that, tutorial balloon goes to the personal island.

**Numbers.**
- 5 layouts at creation; Creative Island later offered 13 terrains (swamp, desert, temperate, tropical, savannah, snowfield, tundra, volcanic added; **blue tropical not added**).
- Private land: first claim 4×4. Expansion cost +2,500 (currency wording on EN NamuWiki is messy: “won” vs T-stones). Daily upkeep; can prepay a week. Empty funds → grace period → claim released.
- Survival Tip #20: buildings on personal island do not wear.
- Survival Tip #67: personal-island domain reset once/day.
- Survival Tip #87 / #194–195 / #211: pioneer level from 60; research lab when pioneer level is high.

**Resource regen contradiction.** BlueStacks: tamed-island resources **do not replenish**. Reddit ELI5: they respawn unless unrooted. NamuWiki (stable islands generally): trees/rocks spawn on empty land, but fewer than unstable islands. Treat as **version-dependent** and possibly different for personal vs city islands.

**Sources.** NamuWiki island; BlueStacks; Survival Tips #20, #22, #51, #67, #87; Reddit 61 tips (https://www.reddit.com/r/DurangoWildLands/comments/bp60bc/61_tips_and_tricks_for_durango_wild_lands_english/).

**Confidence.** High on existence, climate, 5 layouts, no durability, waypoint. Medium on exact T-stone expansion table. Low on resource regen.

### 1.3 Village island (마을섬) — early live, later removed

**How it worked.** After tutorial (pre-personal-island era), balloon to a shared beginner stable island, typically **level 10 ecology**. Private claims allowed. By ~level 36 the ecology was too low to matter except as storage. Deleted when personal islands shipped.

**Sources.** NamuWiki island. **Confidence.** High that it existed and was removed; medium on exact deletion patch date (not found in official notes).

### 1.4 City / Civilized island (도시섬)

**How it worked.** Shared stable land for real houses and villages. Unlock **level 36**. Required hop to reach unstable islands **level 40+**. Clans declare **enclaves** (clan domain) here. Maintenance fee per domain tile. Predators exist; densely settled temperate city islands starved wildlife spawns. Marketplace / neighbors / fresh water were the real site-selection game.

**English aliases.** Civilized Islands (Play Store / RAWG). Reddit ELI5: Civilized islands (lvl 40).

**Numbers.**
- Unlock 36 (NamuWiki) vs Reddit “lvl 40” — likely “city island ecology/resources cap at 40” vs “you may go there at 36.”
- City-island fish/water max level 40; past player 40 you fetch high-level water from unstable islands.
- Clan chat “<50 local residents” used by players as a new-island heuristic (NamuWiki tips, not a hard rule).
- Farming fails on beach / swamp / gravel / unremovable boulder; Feb 2019 seed-evaporation bug on unsuitable soil.

**Sources.** NamuWiki island; RAWG store text; Reddit ELI5 https://www.reddit.com/r/DurangoWildLands/comments/bo0phk/eli5_different_islands_types/

**Confidence.** High on shared claims, no PvP, clan enclaves, 36 unlock. Medium on 36 vs 40.

### 1.5 Unstable islands / Untamed / Unstable Archipelago (불안정섬 / 불안정 군도)

**How it worked.** High-resource, no land claims, no PvP (except lawless/savage). Appear and disappear on a timer shown on the sail map. Camp near harbor: reduced fatigue, free return-to-camp, shared benches. Communication post for faction quests (reroll quests 3 times; cooldown after accept/abandon). Craters are the reason to go. Discovering a crater grants a large fatigue dump.

February 2018 week-2 update reorganized Unstable Island into **Unstable Archipelago** (NamuWiki). Later, **instability index** on lv.60 archipelagos raised gather difficulty and attribute level of yields. High-index runs needed personal-island pioneer level + body resistance (Survival Tips #207–#211). Party follow-route is required to land on a friend’s instance of an unstable island.

**English aliases.** Unstable Islands (E3 / store). Untamed islands (BlueStacks, Reddit). Unstable archipelagos = “whole strings of unstable islands” (secondary guide).

**Numbers.**
- Access gated by character level. Climate × level table (NamuWiki):

  | Climate | Unstable levels | Resistance |
  |---|---|---|
  | Savannah | 15, 45 | weak heat (15) |
  | Temperate | 20, 35 | weak cold |
  | Tropical | 25, 40 | high heat |
  | Tundra | 30, 40, 55 | high cold |
  | Desert | 35, 50 | heat + scorching sun |
  | Swamp | 45, 55, 60 | heat + humidity |
  | Snowfield | 50, 60 | cold + strong wind |
  | Blue Tropical | 55 | heat + humidity |
  | Volcanic | 60 | heat (열기) |

- Lifespan: “a few days” (NamuWiki, Reddit). Map shows remaining time. Snapshot 16 Mar 2018 17:00: one island per climate except 55 tundra (3 islands, one with **19 hours** left) after a population-density cull.
- Dinos: normal ~island level − 2; crater guards ~island level + 1 (Reddit ELI5).
- No PvP.

**Cannot travel unstable → unstable** in 2016 beta (Reddit). Later archipelago + “connecting islands” + party routes contradict that for 2019 global. Treat as **era split**.

**Sources.** NamuWiki island; Survival Tips #3, #28, #58, #207–#212; E3 press; Reddit ELI5 / map / party-follow threads.

**Confidence.** High on appear/disappear, camps, craters, climate×level, no claims. Medium on exact lifespan. Low on 2016 “no unstable-to-unstable” remaining true in 2019.

### 1.6 Lawless / Savage / Outpost islands (무법섬)

**How it worked.** Max-level PvP / clan-war space. Official KR patch (23 Feb 2018, Game Donga): new unstable-island type, **lv.60**, PvP and clan vs clan. All gathered items are **Unstable** and vanish if you leave without sending them through a **cargo warp hole**. Clan occupies a **거점 (base / warp hole)**; one per clan. After occupy: defense period (cannot be invaded) to build towers / throwers; then attack period. Beta reward: untameable pets (Smilodon, Direwolf, Tarbosaurus); live reward: **one flag** (NamuWiki snark). Harbor and **neutral warp holes** are PvP-safe (Reddit ELI5).

**English aliases.** Savage Islands (2019 store: “coming soon” at global launch — already live in KR). Outpost Islands (official 2016/17 beta patch notes on Reddit: Clan War at lv.26+; 24h war; 1 min delay after declare; safe in own territory).

**Numbers.**
- KR live unlock: **lv.56** via city-island port (NamuWiki). Volcanic islands also lv.56+ (2019 press).
- Beta Outpost: lv.26+ (official Reddit patch). That is a **different, earlier** PvP island layer.
- Materials lv.60.
- Game Donga: occupied base protected for a period; build defense tower, catapult, advanced lab for clan buffs.

**Sources.** Game Donga 23 Feb 2018: https://game.donga.com/89060/ ; NamuWiki island; official beta patch Reddit: https://www.reddit.com/r/DurangoWildLands/comments/5m7dim/official_new_patch_notes_and_clan_war_info/ ; RAWG store; Reddit ELI5.

**Confidence.** High on KR 2018 lawless rules. Medium on mapping Savage = Lawless = Outpost across years (names shifted).

### 1.7 Raid islands

Store listing: “hunt down great dinosaurs in Raid Islands.” Volcanic update added T-Rex “for additional animal raids.” No primary mechanical writeup found (entry fee, lockout, instance vs shared).

**Confidence.** Low as a distinct system; may be branded hunts on unstable/volcanic islands.

### 1.8 Creative Island (post-shutdown)

Offline sandbox based on personal island. Instant build/destroy. Food/materials vanish. No unstable islands. Extra terrains (13). Charlie: “last gift.” Data lost if app deleted. PC Creative Island also shipped. Not part of the live MMO.

**Sources.** NamuWiki main. **Confidence.** High.

---

## 2. Island drifting / connecting / appearing / disappearing

This is the most mythologized system. Split **what shipped** from **what was pitched**.

### 2.1 Appear / disappear (unstable)

**How it worked.** Unstable islands are created by warp energy and later collapse. Official E3 2017: “ecosystems and biomes that will surface and disappear into the sea at a moment’s notice.” In-game Survival Tip #28: “Unstable islands are islands that disappear. They are located in unstable waters.” Durango Note #6: pioneers always secure an escape first; individual island time is short; **opening sea routes** let them stay in the *waters* much longer by hopping, spreading risk across islands. Note #9: warp-affected regions vanish quickly but hold more resources; stable waters are the opposite.

Timer is visible on the sail map before you pay. When it hits zero the island is gone: warps to it fail, it drops off the list, craters/warp holes reset on the replacement.

**Not found:** a primary source that islands **physically drift across the ocean and dock**. “Drifting” in marketing is appear/submerge, not a moving landmass sim.

### 2.2 Connecting: sea-route graph (the real “connecting” system)

**NDC 2015 (design, largely shipped as harbor travel).**
- Move island-to-island along **routes** built from harbors.
- Travel is **almost instant teleport** (not a sailing minigame).
- **Exploration** (design): leave **without a route, by boat**, discover an island, then **open a new route**.
- First-to-island gets the resources; colonize/occupy for smoother play; faction contests expected.
- Explorers open useful routes; gatherers live near harbors → emergent lobby–dungeon.
- **Logical links replace physical location.** Maintain few routes to stay quiet; open many to “grow” the island’s geography.
- Whole-base **move** to another island if you hate your neighbors (with constraints).

**Shipped travel UI (2018–19).** Go to harbor → Sail (or map “To Harbor”) → tap raft → pick a listed island (permanent vs temporary/red) → pay **T-stones** → confirm. Unstable harbor only returns you to the port you came from (NamuWiki). Fee scales with distance and island level; usually cheaper than one quest. Clan perk can reduce warp/sail cost (status wiki). Random sail from personal/city harbors can visit someone else’s personal island (Survival Tip #51). Favorite islands exist (#55). Distinguish waters when using routes (#78).

**Visible neighbors (beta).** Stable islands show surrounding islands; you hop the chain. 2016 Reddit: 40+ island clusters; 1 hour+ of hopping to a clan base; **cannot travel unstable-to-unstable**. Warm Welcome spawn-on-friend required a character restart.

**Connecting islands + pioneer missions (2019 global, Reddit).** A party member’s island “doesn’t exist for you” until you: (a) use **Follow party leader route** at harbor, (b) finish **pioneer missions** for islands that **connect to the mainland**, (c) unlock the **index**. Different parties cannot see each other’s path. Survival Tip #212: party up to travel the same unstable island.

**Unstable Archipelago (2018+).** NamuWiki: Feb week-2 rework. Secondary text: “strings of unstable islands.” Survival Tips #208–210: lv.60 archipelagos have a higher **instability index**. This is the closest shipped analog to “islands connecting into a chain,” still via sail routes, not land bridges.

### 2.3 Portals / warp holes (섬 내부 + cargo)

Warp holes are a crater type present on all islands (NamuWiki). Warp energy that created the island leaves holes that exchange matter — and can move people (Durango Note #7). Survival Tips:
- #23 warp energy makes warp holes
- #30 use them to save time
- #33 need **two or more** discovered to use
- #34 harbor has a nearby warp hole
- #46 death can revive near a discovered warp hole
- #77 prefer warp holes for intra-island travel
- Detect crater/warp direction **from water** (#57)

Fee: T-stones by distance and island level. Cargo warp hole on your domain + camp warp hole to **stabilize** Unstable-tagged modern loot from warp ruins / lawless island. Neutral warp holes on savage islands are PvP-safe.

Hot-air balloon at harbor later: floats **15 minutes**, used to raid “tax evasion” fenced land (NamuWiki).

### 2.4 Rafts / boats / ocean travel

- **Live UI:** raft is the sail-map vehicle; crossing is a loading teleport, not open-ocean gameplay (NDC 2015 “almost instant”; QuartzMountain / Reddit how-to).
- **Lore:** Durango Note #2 rafts from Ancora wreck in currents. Note #5 pioneers used radios in water to triangulate warp.
- **Design (2015) not confirmed shipped:** boat exploration with no route to *discover* islands.
- **Tutorial vehicle:** K’s balloon, not a player-built boat.
- No primary source for player-steered ocean sailing, naval combat, or swimming between islands.

### Sources (section 2)
- E3 2017 Nexon/What! Studio release via Inven: https://www.invenglobal.com/articles/2111/nexon-prepares-durango-the-next-evolution-of-persistent-open-world-mmorpgs
- NDC 2015 tistory + Game Donga (URLs in §0)
- NamuWiki island: https://en.namu.wiki/w/%EC%95%BC%EC%83%9D%EC%9D%98%20%EB%95%85:%20%EB%93%80%EB%9E%91%EA%B3%A0/%EC%84%AC
- Survival Tips / Durango Notes: NamuWiki memo URL in §0
- Reddit map 2016: https://www.reddit.com/r/DurangoWildLands/comments/5m0ss5/the_map_of_durango/
- Reddit huge world: https://www.reddit.com/r/DurangoWildLands/comments/5jest5/durango_is_a_huge_world/
- Reddit party follow 2019: https://www.reddit.com/r/DurangoWildLands/comments/ddf0yx/how_to_go_to_an_island_your_party_member_is_on/
- QuartzMountain travel (secondary): https://quartzmountain.org/article/how-to-travel-to-a-specific-island-durango-wildlands

### Confidence
High: appear/disappear, harbor+T-stone sail, warp-hole rules, logical routes, no confirmed physical drift. Medium: archipelago strings, pioneer-mission gates. Low: 2015 boat-discovery loop in live; 500/island; exact disappear hours.

### Open questions
- Did 2015 “sail with no route to discover” ever ship, even in alpha?
- Exact unstable lifetime distribution (hours vs days) by era.
- Whether archipelago islands were one instance with internal loading, or separate instances with auto-listed routes.
- Whether you could see another island’s shoreline and walk a land bridge (no source found).

---

## 3. Map size, generation, instancing, shards

### Map size
**NDC 2015 prototype target:** 8 km × 8 km continent, hundreds of thousands of plants, tens of thousands of animals, hundreds concurrent. Phone-screen metaphor: “taped-together phone screens ≈ soccer pitch” vs programmer panic. This is a **design/test number**, not a measured shipped island.

**No primary source** for shipped island size in km, tiles, or hectares. Personal domain starts 4×4 then expands by adjacent (not diagonal) tiles; that is claim size, not island size.

Fandom Islands page lists many named stable islands (Helen Espiritu Santo, Tike Macau, …) — naming pattern **mythic/person + real-world place**. Useful as evidence of many distinct generated maps, not as a complete atlas (many rows are `?????`).

Durango Maps web viewer announced for KR launch so players could inspect the world they built (Lee, Inven Jan 2018). Survival Tip #97: a site to watch city-island development over time. Official sites closed at EOS.

### Procedural generation
E3 2017: “revolutionary procedurally generated world building system” / “infinite number of locations.”

NDC 2015 plant talk (Byeon Sumin, NDC2015_0063): ecosystem simulator places plants and minerals by **terrain, climate, geology**. Prototype runtime **>30 minutes → 12 seconds** via OpenCL, parallelization, complexity cuts.

NDC 2018: continent-scale **fertility** sim (trees suck nutrients, soil browns; food chain). Land area changed food-chain speed. Full extinction of a resource would soft-lock the game → **craters** added as guaranteed resource spots. Sim was **compromised but partially shipped**.

NDC 2015 AI LOD:
- Individual AI: real-time, skipped if no player watching.
- Herd AI: need-based, minutes.
- Macro AI: distribution stats, 1–2×/day.
- Unoccupied island: frozen (“T-rex herd and three triceratops herds at A,B,C,D until someone activates the island”).
- Carnivores do not attack humans without a reason (design claim).

### Instancing vs shards
- **Not** dungeon instances (director).
- **Yes** island-as-instance: load a space, local chat, local population.
- Unstable islands are **per-route / per-party visible** in 2019 (friend’s island “doesn’t exist”).
- Housing is on the shared stable island, not a house instance.
- Dormant craters are a paid, timed resource event inside the same island, not a separate dungeon.

### Server shards
See §0. Identity is character + island claims; 2018 five-Asia merge kept all islands, characters, property; added character slots.

### Sources
- NDC 2015_0073 and 2015_0063 session pages
- Tistory NDC 2015 notes
- Appliv / Famitsu NDC18
- Inven E3 + launch preview
- https://durango.fandom.com/wiki/Islands (stub, 403 for some fetches)

### Confidence
High on procedural intent, crater-as-compromise, sim LOD, shard history. Low on 8 km applying to live islands.

---

## 4. Biomes / climates (not seasons)

### System name
Climate (기후). Ten climates. One climate per island. Drives flora, fauna, crater tables, and **body resistance** (생존 능력: heat, cold, humidity, scorching sun, strong wind, volcanic heat).

### How it worked
Not a rotating season calendar. Climate is a **fixed island property**. Clothing / resistance matching climate reduces fatigue. Same status effect can help or hurt depending on climate (Survival Tip #7, #11). Shade blocks heat; indoor walls −100% fatigue-from-environment; camp −50% fatigue gain.

NamuWiki island intro once says “five ecosystems” then lists **ten** climates — leftover from an older version.

**Ten climates:** Savannah, Temperate, Tropical, Grassland, Tundra, Desert, Swamp, Snowfield, Blue Tropical, Volcanic.

Grassland is the personal-island default. Temperate is the popular city-island climate (easy farming; wetness is tolerable). Volcanic added 2019 (lv.56+, lava, ash storms, hot springs, black iron, lava resource, T-Rex, large iguanas).

### Numbers (resistance vs climate)
See unstable table in §1.5. Character sheet has per-climate body resistance (Tip #209). High-index archipelagos need pioneer level + resistance (#210); both start at character 60 (#211).

### Notable design
- Climate is the biome system. **No evidence of spring/summer/autumn/winter cycles** as a world sim. Event copy mentions real-world seasons and Korean boknal heat as *letters*, not mechanics.
- “Playground of biomes” was the Jan 2018 pitch vs theme-park MMO.

### Sources
- NamuWiki island climate section
- Survival Tips #7, #11, #209–211
- Volcano developer note (Reddit): https://www.reddit.com/r/DurangoWildLands/comments/c3csd2/developer_note_combat_changes_warp_rush_and/
- Gaming Cypher volcanic launch: https://gamingcypher.com/durango-wild-lands-launches-massive-content-update-volcanic-islands/

### Confidence
High on ten climates, per-island assignment, resistance coupling. High that seasons as a cycle were **not** a shipped system.

---

## 5. Weather

### How it worked
Weather is a **status-effect layer** on top of climate, not a named global forecast UI in the sources found.

**Rain.** Applies **Wet**. Wet lasts for the whole rain, or 2 minutes after leaving water/rain. Wet: heat-fatigue rate **−20%**, cold-fatigue **+30%**, humidity-fatigue **+30%**. Does **not** affect scorching-sun fatigue. Entering water 5 seconds also wets you (fandom Status Effects).

**Bonfire.** Clears wet; heat-fatigue **+20%**, cold-fatigue **−20%** while sitting.

**Volcanic.** Official 2019 notes: lava pits and **storms** / **ash storms**. Hot spring lakes as a survival tool. No numeric storm table found.

**Desert / heat.** Juice from cactus flesh reduces desert fatigue (NamuWiki tips). Shade (barracks) blocks heat. Drinking fresh water reduces heat fatigue.

**Other environment statuses (fatigue economy, not “weather” but the same survival layer).** Partial list; the complete table with every duration is in [bestiary §4](./durango-wild-lands-bestiary-combat.md#4-status-effects--the-full-table):
- Filthy +20% fatigue until wash; Very filthy +50%
- Exhaustion at 100% fatigue: −80% auto-evade/accuracy, no gathering, until fatigue to “tired” band
- Tired visual at 80% fatigue; map edges redden
- Washed: −20% base fatigue 6 min
- Thirst +20% from seawater
- Home (inside walled house): −100% environment fatigue
- Pleasant fragrance (clan censer, 2h): ignore climate fatigue (not base fatigue)
- Discover crater: large fatigue drop, 15s (“joy of discovery”); stronger on higher-level islands
- Island–character level gap affects fatigue (Tip #6)
- Ingested / environmental damage-over-time: 복통 stomachache −0.2 HP/s for 5 min; 열독 heat poison −1 HP/s for 6m30s; 파상풍 tetanus −1 energy/s for 30s; 똥독 fecal toxin +18 fatigue/min for 60s
- Animal-applied: 침범벅 drool-soaked +5.4 fatigue/min for 30s. **This is the only status wild animals inflict** besides stun/knockdown — there is no combat bleed or poison in Durango

Mastersheet (player spreadsheet, not official): latent attributes “in the Rain: Crafting / Gathering” — implies rain was a first-class condition for bonuses. Treat as **player-datamined**, medium-low.

### Day / night
- Exists. Durango Note letter 7 Mar 2018: “Even here, as time passes the day ends and a new morning begins.”
- Survival Tip #174: **animal vision differs by day and night.**
- No source found for cycle length (e.g. 20 min day / 10 min night), whether time is global or per island, or whether night changes spawn tables.

### Seasons
No mechanical season cycle found. Climates are static per island.

### Sources
- NamuWiki / namu.moe status: https://namu.wiki/w/%EC%95%BC%EC%83%9D%EC%9D%98%20%EB%95%85:%20%EB%93%80%EB%9E%91%EA%B3%A0/%EC%83%81%ED%83%9C and https://namu.moe/w/%EC%95%BC%EC%83%9D%EC%9D%98%20%EB%95%85:%20%EB%93%80%EB%9E%91%EA%B3%A0/%EC%83%81%ED%83%9C
- Fandom Status Effects: https://durango.fandom.com/wiki/Status_Effects
- Survival Tips #6, #174; Durango letters on memo page
- Volcanic press (ash storms)

### Confidence
High on wet/rain/bonfire/fatigue numbers from status wiki. High that day/night exists and affects animal vision. Low on cycle length. High that seasons are not a system.

---

## 6. Resource nodes, craters, landmarks, ruins, nests, caves

### Ordinary nodes
Trees, bushes, rocks, water, fish traps, beach clams, etc. spawn on empty land. Survival Tips:
- #68 some naturals despawn when a product is exhausted (tree falls when logs gone)
- #69 if the natural remains, products regenerate over time
- #8 / Durango Note #4: **resources concentrate around craters**; crater resources are lore-wise **warped in**, not grown in place
- #79 crater-adjacent naturals regen **fast** even if they despawn
- Stable islands spawn some trees/rocks but are kept emptier for building
- Ancora: infinite regen at a fixed count
- Level of node vs tool/skill gates success (#65, #85)
- Personal/tamed regen is disputed (see §1.2)

### Craters (the landmark system)

Craters are the game’s POIs. Three parts: the crater, special plants around it, and **guard animals** (even normally non-aggressive species aggro inside). Discovering one dumps fatigue and can start a faction examine/kill/harvest mission.

**Types (NamuWiki lists; climate-locked):**
- **Plant craters** — flax, bamboo, baobab, mango, saguaro, rubber, etc.
- **Animal craters / nests** — Dinosaur Egg Nest (savanna 15/45), Oviraptor Nest (temperate 20/35), Saurolophus Nest (tropical 25), Centrosaurus Nest (tropical 40), Animal Bone Grave (tropical/desert/blue tropical)
- **Mineral craters** — mud pit (all), rock mine, mines, obsidian, marble, zinc, silver, gem, ice floor
- **Warp holes** — see §2.3
- **Warp ruins** — see below
- **Closed / dormant craters** — bury T-stones, wait, opens with resources (#37, #100–#106). Stays open a while then closes. Factions know how to keep them open longer. Clan or individual can open. Open crater “causes a warp” that summons resources; type guessable from surrounding terrain. Reddit: ~13k–19k T-stones to activate; player reports of ~2h windows and rotation among ore/marble/gem; possible population-scaled regen (**unofficial**).

**Nests are crater subtypes**, not a separate “Nest Island” type. No primary source for an island classification called Nest Island.

### Warp ruins
Earth land punched in by warp. High-volume modern goods/furniture. Loot is **Unstable**: disappears if taken to a stable island without cargo-warp stabilization. On island birth, ruins are vacuumed immediately; rebar stripped from concrete is a running joke. Slow respawn — usually better to wait for a new island. Fresh islands also rain **delivery boxes** (mis-warped parcels); mostly junk, some rare seeds only from boxes (Tip #38, #82, #110).

### Caves
**No primary source found** for a cave/dungeon system (no namu section, no store bullet, no NDC mention). If caves existed they were not documented as a named feature in the sources below. Do not invent them.

### Other landmarks
- Harbor / port (every island)
- Camp + communication post + camp shed (unstable)
- Fresh water / rivers / beaches / unremovable boulders
- Hot springs (volcanic)
- Lava pits (volcanic)
- Clan outpost / occupied warp hole (lawless)
- Harbor balloon (15 min, later patch)

Map icons mark specific points (Tip #15); map dots distinguish animals (#14).

### Sources
- NamuWiki island crater lists
- Survival Tips #8, #35–#38, #57, #79, #100–#107
- Durango Notes #4, #7
- Reddit crater threads: https://www.reddit.com/r/DurangoWildLands/comments/c1yhu6/questions_about_craters/ and https://www.reddit.com/r/DurangoWildLands/comments/cxesf6/crater_and_resource_reset_time/
- Scribd mastersheet (player): https://www.scribd.com/document/501357601/Durango-Wildlands-Mastersheet

### Confidence
High on crater taxonomy, warp ruins + unstable tag, nests as craters. Medium on dormant-crater costs/timers (player reports). High that dedicated cave/dungeon content is **undocumented / likely absent**.

---

## 7. Time (world clock vs player timers)

| Timer | What it is | Source | Confidence |
|---|---|---|---|
| Day/night | Exists; animal vision changes | Tip #174, letters | High exists / low duration |
| Unstable island lifetime | Hours to a few days; UI countdown | NamuWiki, Reddit, Note #6 | Medium |
| Crater open/close | Opens after T-stone bury; later closes | Tips #100–#106 | High exists / low hours |
| Domain upkeep | Daily; week prepay; grace then release | NamuWiki | Medium |
| Personal domain reset | 1/day | Tip #67 | High |
| Pioneer level | Raise a bit each day | Tip #194 | High |
| Quest faction cooldown | After accept/stop | NamuWiki camp | Medium |
| Clan war (beta) | Starts 1 min after declare; lasts 24h | Official Reddit patch | High for beta |
| Lawless defense/attack windows | Exist; lengths not in Game Donga | Game Donga, NamuWiki | Medium |
| Harbor balloon | 15 min | NamuWiki | Medium |
| Resurrection dizziness | 25s | Status wiki | High |
| Resurrection aftermath | 10 min, stacks | Status wiki | High |
| Exhaustion | Until fatigue ≤ “tired” | Status wiki | High |
| Wet after rain/water | 2 min dry | Status wiki | High |
| Macro AI | 1–2 evaluations/day (design) | NDC 2015 | Medium (design) |
| Skill research | 20 min at 20→21 up to 3 days at 59→60 | NamuWiki skills (out of scope but shows daily cadence) | Medium |

No evidence of a shared “season year.” World time-of-day is real enough for lighting and AI vision.

---

## 8. Simulation / environment (living world)

**Pitched:** animals with needs (water, food, sleep), pack travel, plants that breed, player actions persist and have causal results, fertility, food chain (NDC 2015, E3: dinos travel in packs seeking water).

**Shipped compromise (NDC 2018):** full extinction sim was unsafe for a live game → craters as resource anchors. Fertility sim existed in prototypes (soil browning). LOD sim: don’t simulate individuals when no player is present; freeze inactive islands.

**Fatigue replaced** hunger/thirst/body-temp gauges after mobile-UI failure (NDC 2018). Survival “feel” remains via climate, wet, dirty, shade, water.

**Persistence:** buildings, claims, and terraforming on stable islands persist. Unstable islands wipe. Warp-ruin loot is persist-gated by cargo warp.

---

## 9. Official naming (store / press) vs live Korean names

RAWG copy of the Play Store / App Store listing (official community links, TOS, permissions — this is the player-facing store text):

- Settle **Personal, Tamed and Civilized Islands**
- Explore **Unstable Islands** (resources, tameable dinos, secrets)
- **Raid Islands** for great dinosaurs
- **Savage Islands** for better resources and clan PvP (“coming soon” in the May 2019 worldwide press, already live in KR as 무법섬)

E3 2017: **stable continents** vs **unstable islands**.

2015 Massively Overpowered / Yi interview: **one permanent central continent** surrounded by **temporary archipelagos** — **superseded**.

---

## 10. Contradiction log (do not silently resolve)

1. **Shutdown date.** Wikipedia Nexon: 16 Oct 2019. Official: IAP 16 Oct, servers **18 Dec 2019**. https://en.wikipedia.org/wiki/Nexon vs https://www.androidpolice.com/2019/10/16/durango-wild-lands-shut-down-android/
2. **Central continent (2015) vs many stable islands (2018).** Yi 2015 via Massively: https://massivelyop.com/2015/12/07/durango-is-pioneering-a-new-mobile-mmo-genre/ vs NDC18 stable/unstable split.
3. **Five ecosystems vs ten climates.** Same NamuWiki island page.
4. **Village islands vs personal islands.** Village deleted after personal island added.
5. **No channels/instances vs island shards + 500 cap.** Director vs Reddit beta.
6. **Unstable-to-unstable travel.** Forbidden in 2016 Reddit; archipelago / connecting islands / party routes in 2018–19.
7. **Boat discovery (2015) vs harbor list + T-stone (live).**
8. **Tamed resource regen.** BlueStacks no vs NamuWiki/Reddit yes.
9. **City unlock 36 vs civilized lvl 40.** NamuWiki vs Reddit ELI5.
10. **Jobs 7 vs 8.** BlueStacks 7, NamuWiki 8 occupations × 16 gendered characters.
11. **Outpost lv.26 (beta) vs Lawless lv.56 (live).**
12. **8 km continent.** Prototype, not verified live.
13. **Physical island drift.** Not evidenced. Appear/disappear + logical routes + later archipelago chains.
14. **Caves.** No source.
15. **Season cycle.** No source.
16. **Day/night length.** No source.
17. **Raid Islands as a separate instance type.** Store only.
18. **Single global server.** Goal, never fully true.
19. **GDC talks.** None found; NDC only.
20. **Official site** https://durango.nexon.com/En is dead with the game.

---

## 11. Source catalog

### Official / first-party
- NDC 2015 session (Yang, island model / sim): https://ndcreplay.nexon.com/NDC2015/sessions/NDC2015_0073.html
- NDC 2015 session (Byeon, plant ecosystem / OpenCL): https://ndcreplay.nexon.com/NDC2015/sessions/NDC2015_0063.html
- NDC 2018 session (Yang, design history): https://ndcreplay.nexon.com/NDC2018/sessions/NDC2018_0012.html
- E3 2017 press (Nexon / What! Studio, via Inven reprint of Reverb): https://www.invenglobal.com/articles/2111/nexon-prepares-durango-the-next-evolution-of-persistent-open-world-mmorpgs
- KR launch preview with Lee quotes: https://www.invenglobal.com/articles/3977/durango-expected-to-be-released-in-korea-first-on-january-25-we-will-make-it-a-global-success
- Korea Herald 9 Jan 2018: https://www.koreaherald.com/article/1555097
- Korea Herald 25 Jan 2018 launch: https://www.koreaherald.com/article/1572754
- Worldwide launch press (Android Police reprint of Business Wire): https://www.androidpolice.com/2019/05/15/durango-wild-lands-is-an-open-world-sandbox-mmo-from-nexon-now-available-on-android/
- Store-listing text (RAWG capture): https://rawg.io/games/durango-wild-lands
- KR official patch coverage, Lawless + clan war: https://game.donga.com/89060/
- Volcanic Islands content update: https://gamingcypher.com/durango-wild-lands-launches-massive-content-update-volcanic-islands/
- Developer note (West / Warp Rush / Volcano preview, posted on official Reddit): https://www.reddit.com/r/DurangoWildLands/comments/c3csd2/developer_note_combat_changes_warp_rush_and/
- Official beta Clan War / Outpost patch: https://www.reddit.com/r/DurangoWildLands/comments/5m7dim/official_new_patch_notes_and_clan_war_info/
- EOS coverage quoting official Facebook letter (Yi + Yang): https://www.androidpolice.com/2019/10/16/durango-wild-lands-shut-down-android/

### Developer-talk reports (not transcripts, but session-based)
- Game Donga NDC 2015: https://game.donga.com/79518/
- Tistory NDC 2015 slide notes: https://dreamrugi.tistory.com/entry/NDC2015-%EC%95%BC%EC%83%9D%EC%9D%98-%EB%95%85-%EB%93%80%EB%9E%91%EA%B3%A0%EC%9D%98-%EC%8B%9C%EB%AE%AC%EB%A0%88%EC%9D%B4%EC%85%98-MMO-%EC%83%8C%EB%93%9C%EB%B0%95%EC%8A%A4-%EB%A7%8C%EB%93%A4%EA%B8%B0
- Appliv NDC18: https://games.app-liv.jp/archives/355374
- Famitsu NDC18: https://app.famitsu.com/20180429_1287201/
- Massively 2015 (Yi interview summary): https://massivelyop.com/2015/12/07/durango-is-pioneering-a-new-mobile-mmo-genre/

### In-game systems transcribed
- NamuWiki island: https://namu.wiki/w/%EC%95%BC%EC%83%9D%EC%9D%98%20%EB%95%85:%20%EB%93%80%EB%9E%91%EA%B3%A0/%EC%84%AC (EN: https://en.namu.wiki/w/%EC%95%BC%EC%83%9D%EC%9D%98%20%EB%95%85:%20%EB%93%80%EB%9E%91%EA%B3%A0/%EC%84%AC)
- NamuWiki main: https://en.namu.wiki/w/%EC%95%BC%EC%83%9D%EC%9D%98%20%EB%95%85:%20%EB%93%80%EB%9E%91%EA%B3%A0
- Survival Tips + Durango Notes (in-game): https://namu.wiki/w/%EC%95%BC%EC%83%9D%EC%9D%98%20%EB%95%85:%20%EB%93%80%EB%9E%91%EA%B3%A0/%EB%A9%94%EB%AA%A8
- Status effects: https://namu.wiki/w/%EC%95%BC%EC%83%9D%EC%9D%98%20%EB%95%85:%20%EB%93%80%EB%9E%91%EA%B3%A0/%EC%83%81%ED%83%9C
- Fandom (thin, often stub): https://durango.fandom.com/wiki/Islands , https://durango.fandom.com/wiki/Status_Effects

### Player-facing but unofficial
- BlueStacks getting started: https://www.bluestacks.com/blog/game-guides/durango-wild-lands/getting-started-en.html
- Reddit ELI5 island types, map hopping, party routes, crater timers (URLs inline above)

### Wikipedia (high-level only; check citations)
- https://en.wikipedia.org/wiki/Nexon — lists the game; **incorrect EOS date**
- https://en.wikipedia.org/wiki/Dunia:_Into_a_New_World — variety show tied to Durango IP

---

## 12. Still open (research gaps)

- Official patch-note archive (durango.nexon.com and Facebook are gone). Wayback not fetched in this pass.
- NDC slide PDFs / video transcripts (session pages exist; “script coming soon”).
- Measured live island dimensions.
- Exact unstable TTL formula.
- Whether connecting-archipelago islands shared one physics space.
- Cave content: probably none; confirm via surviving video.
- Day/night period.
- **Closed since this file was written:** complete animal roster, capture-skill species gating, bonded-animal cap, full status table. See [`durango-wild-lands-bestiary-combat.md`](./durango-wild-lands-bestiary-combat.md).
- GDC: none found under Durango / What! Studio / Yang / Yi.
- App Store / Google Play live listings are gone; RAWG + press are the remaining store text.
- Japanese NDC18 interviews mention resource distribution retune with volcano; full KR patch notes for that retune not retrieved.
