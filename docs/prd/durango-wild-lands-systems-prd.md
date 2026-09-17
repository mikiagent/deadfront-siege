# Durango: Wild Lands — Systems PRD

**Status:** Research reconstruction, v0.3  
**Product reconstructed:** *Durango: Wild Lands* (Korean title: 야생의 땅: 듀랑고)  
**Developer / publisher:** What! Studio / Nexon  
**Shipped platform:** iOS, Android (Unity, isometric 2.5D)  
**Live window:** Korea 2018-01-25 → worldwide 2019-05-15 (Japan and China excluded) → IAP off 2019-10-16 → servers off 2019-12-18  
**This document specifies:** the systems of the live MMO as they existed in late service (private islands, unstable archipelagos, volcanic content), plus earlier variants where they changed the design.

This is a product requirements document for those systems, not a wiki dump. Numbers and names that players reported but that were never published in a first-party spec are marked **[player]** with confidence.

**v0.2** folds in cited research notes: [`research/durango-wild-lands-world-environment.md`](../../research/durango-wild-lands-world-environment.md), [`research/durango-wild-lands-systems.md`](../../research/durango-wild-lands-systems.md). Main corrections: islands do not physically drift; travel is a harbor sea-route teleport; hunger/thirst are fatigue modifiers; food restores Energy not Health; PvP and taming are era-dependent; global Savage islands were removed July 2019.

**v0.3** folds in [`research/durango-wild-lands-bestiary-combat.md`](../../research/durango-wild-lands-bestiary-combat.md), which reached the NamuWiki animal / status / survival-tree pages through the **namu.moe mirror** (en.namu.wiki 403s automated fetches). Main corrections: the capture ladder is five 포획기술 tiers and Protoceratops is tier III, not tier I; the bonded-animal cap question resolves at four +1 ranks; **combat bleed and poison never shipped** — every DoT in Durango is environmental or ingested; tamed stats were cut to a fraction of wild and that is why taming failed. Sections touched: 6.4, 11.3, 11.5, 12.1, 12.2, 18, 22.

---

## 0. How to read this document

| Marker | Meaning |
|---|---|
| **MUST / SHALL** | Core shipped behavior. Recreate this if the goal is Durango. |
| **SHOULD** | Strong design intent, shipped but later patched or region-dependent. |
| **MAY** | Optional, late, or cosmetic. |
| **ANTI** | Documented failure. Do not copy blindly. |
| **[dev]** | Developer statement (NDC18, press, interviews). |
| **[player]** | Player-facing wiki / guide / community. Treat as high-fidelity unless contradicted. |

**Canonical sources used**

- Nexon / What! Studio E3 2017 press release (Inven Global reprint)
- NDC18 developer talk + Famitsu interview (Yang Seung-myung, Lee Eun-seok)
- Korea Herald (director, one-world ambition)
- Newsis / Massively Overpowered (EOS, scale claims)
- NamuWiki systems pages (islands, skills, animals, items, status, factions)
- BlueStacks official-adjacent guides (combat, taming, survival, skills)
- Community: r/DurangoWildLands, LevelWinner, TV Tropes

**Version fork (read before implementing anything)**

Durango is era-dependent. Mixing 2018 KR launch with 2019 global produces false systems.

| Snapshot | When | World path | Combat / PvP / taming |
|---|---|---|---|
| **A. KR launch** | Jan–mid 2018 | Ancora → village islands → city islands → unstable. No personal island. | Capture could resolve to an immediate tame. Beta Outpost wars (lv.26+, 24h flag). Lawless/Savage later at lv.56+. |
| **B. Mid live** | Dec 2018–Jun 2019 | Personal islands added; village islands deleted. Unstable Archipelago. | **Taming pen** (time + chance, S–C grades) from **2018-12-13**. Lawless loot needs cargo warp. |
| **C. Global late (this PRD's default)** | Jul–Dec 2019 | Personal island → city → unstable/volcanic. | Combat switched toward **joystick**; skill reservation removed. **Savage removed on global**. Sunset **Combat Island** (battle-royale) as PvP leftover. |
| **D. Post-EOS** | After 2019-12-18 | Creative Island only. | Offline souvenir, not a relaunch. |

Unless the product owner says otherwise, **snapshot C is canonical**, with A/B called out where a system only existed then.

There is no English Wikipedia article worth using. Wikipedia’s Nexon list is **wrong** on shutdown (it cites 16 Oct; that was IAP off, servers 18 Dec). No GDC talk exists; developer talks are **NDC 2015** and **NDC 2018**.

---

## 1. Product identity

### 1.1 One-sentence pitch

A mobile open-world survival MMORPG in which modern people, warped into a prehistoric archipelago of independently simulated islands, survive by gathering, processing, cooking, building, taming dinosaurs, and forming communities — not by a single combat grind.

### 1.2 Fantasy

A passenger train is torn by a dimensional warp. Survivors from many centuries wash up on Durango, a land of dinosaurs, extinct mammals, and fragments of Earth (warp ruins, courier boxes, modern debris). They radio one another through support organizations, claim land, and try to make a society before the islands themselves disappear.

The Basque word *durango* ("land of water") is the name's origin. Working title during development was **Project K**.

### 1.3 Design pillars **[dev]**

1. **One world, not channels.** Players of a shard share persistent stable land. Houses sit on that land, not in housing instances. Islands themselves are still separate load spaces (local chat, local population).
2. **Stable vs unstable land.** Permanent land for building and community; regenerating land that **appears and sinks on a timer**. This split was chosen after a single continent filled up in a ~300-person internal test, and extra continents created old-vs-new inequality. Islands do **not** physically drift and dock; travel is a **logical sea-route graph** (harbor raft UI → almost instant teleport). **[dev, NDC 2015 + 2018]**
3. **Combination, not meters.** Hunger / thirst / body-temperature meters were prototyped and cut because they dominated the mobile HUD and crowded out other play. Survival became: limited resources + combinatorial crafting + fatigue as session governor.
4. **Horizontal expansion over vertical caps.** Level cap 60 was treated as a ceiling, not a treadmill to raise. New play was supposed to spread sideways (islands, clans, cooking experiments, PvP).
5. **Occupations, not only combat.** A cook, farmer, or tailor can reach max level without being a hunter. Specialization is forced by scarce skill points; trade and clans fill the gaps.
6. **Attribute crafting, not loot RNG.** Finished items inherit properties from *which* material was processed *how*, not from a random roll on craft complete.

### 1.4 What the game is not

- Not a starve-to-death sim. Hungry/Thirsty only raise fatigue. Food fills **Energy**; medicine fills **Health**. English guides that say meals restore HP are wrong. **[Survival Guide #13]**
- Not a theme-park MMO with a quest highway as the main loop.
- Not a full physics 3D world. Terrain is a 2.5D isometric plane with 3D characters, animals, and some props.
- Not pay-to-win *as stated*. Director framed the shop as convenience/cosmetics; live shop still sold speed pets, bag animals, and age elixirs. Treat as **soft P2W**.
- Not Haven & Hearth's full crime sim. Domain interiors cannot be stolen from. Theft and grief exist at the *edges* of claims.
- Not a drifting-continent sim. Marketing said biomes "surface and disappear into the sea"; shipped travel is harbor teleport + unstable timers. No caves, no season cycle.

### 1.5 Success metrics the original product used (inferred)

- Time spent exploring unstable islands vs sitting on a domain
- Unique crafted item combinations (cooking especially)
- Clan formation and land coverage
- Trust rank with support organizations
- Retention without combat as the only XP source

Shipped commercial result: 12M cumulative downloads at global launch claims; Korean Game Awards Excellence (Prime Minister's Award) 2018; EOS after ~23 months on low ARPU vs high server cost. Treat commercial failure as a constraint, not a reason to discard the systems.

---

## 2. Platform, presentation, controls

### 2.1 Presentation

- Isometric / quarter-view 2.5D.
- Portrait or landscape. Landscape is the intended "serious" layout; portrait is one-hand mobile.
- Character always camera-centered.
- Contextual prompts appear when standing on/near interactables (water: drink / wash / fill container).
- Tools auto-equip for the clicked resource (axe for trees, knife for thickets, pick for rock). Equipped *combat* weapon still matters in hunts.

### 2.2 Input

- Virtual stick / drag to move; WASD and arrow keys supported (emulator / bluetooth keyboard).
- Tap resource → gather. Tap animal → Attack / other verbs.
- Roll button for dodge / terrain.
- Combat HUD is a separate overlay of tactic icons (see §10). **Jul 2019 global:** movement toward **joystick**; **skill reservation deleted**. Snapshot C combat is simpler than KR 2018 hunts.
- Keyboard shortcuts **[player]:** C craft/build, I inventory, Esc back.

### 2.3 Session model (mobile)

Fatigue is the anti-AFK / session-length governor. Resting in a residence is the main fatigue dump and can run while logged off. Health and Energy also **slowly auto-recover** over time **[Survival Guide #11]**. Food is still the real Energy refill; medicine is the real Health refill. BlueStacks' "sleep does not restore Energy" is only half-true: sleep is not the Energy *engine*, but Energy is not frozen at zero without food.

**ANTI:** Durability + domain tax + skill-point scarcity turned the mobile session into chores. If this product is rebuilt, either reduce upkeep or move the heavy loop to a platform people sit at.

---

## 3. Core loop

```
Explore (unstable / savage island)
  → Gather / Hunt / Discover crater or warp ruin
  → Process materials (attributes persist)
  → Craft tools, clothes, food, buildings
  → Deposit on domain / sell on island market / turn in faction mission
  → Rest, eat, wash, manage fatigue
  → Specialize skills OR trade with others
  → Unlock higher-level climates
  → Repeat, with clan land and PvP as late-game branches
```

Daily heartbeat:

1. Rest / eat / wash.
2. Sail or warp to the highest-level unstable island you can survive.
3. Take 1–4 Communications Center missions.
4. Scan for craters and warp holes (radar / sense).
5. Gather, hunt, or buy the turn-in items.
6. Drop off at camp shed → T-stones, XP, faction trust.
7. Warp cargo home, craft, farm, tend animals, list on market.
8. Pay domain tax, repair buildings, log off Resting.

---

## 4. World architecture

This is the load-bearing system. Everything else hangs off island type.

### 4.1 Design problem **[dev]**

A single continent cannot absorb population spikes. Cloning continents (channels) breaks "one world." Adding new continents over time splits new players onto empty maps and old players onto developed ones. **Solution:** two land classes.

| Class | Persistence | Purpose | Claim land? | Resource regen | PvP |
|---|---|---|---|---|---|
| **Stable** | Permanent | Home, city, community | Yes | Sparse; personal vs city regen is **version-dependent** (see open Q) | No |
| **Unstable** | Appears and sinks on a visible timer (hours–days) | Exploration, rare mats, missions | No | Yes; crater-adjacent is fast | No |
| **Savage / Lawless** | KR 2018–mid 2019 PvP frontier | Clan war, max-tier mats | Clan warp-hole holds | High, but mats are *Unstable* until cargo-warped | Yes, except harbor / neutral warps |
| **Combat Island** | Jul 2019 global sunset | Battle-royale PvP leftover after Savage removal | n/a | n/a | Yes (instanced) |

New islands spawn as a function of population. Unoccupied islands **freeze** their animal sim until a player loads them. **[dev, NDC 2015]** Individual animal AI only runs when watched; herd AI on minutes; macro AI 1–2×/day.

### 4.2 Island types (late live)

#### Tutorial: Ancora + Company safehouse

- Linear onboarding. After leaving, the player **cannot return**.
- Ecology is level 1. Infinite regen of tutorial resources, used by some players to pre-level gathering / processing / tools.
- Skip-prologue exists.

#### Private tamed island (personal island)

- Granted after tutorial (replaced village islands).
- Level-10 grassland ecology. Player picks **one of five terrains, permanently**.
- Building durability does **not** decay if construction is completed. Unfinished buildings still decay.
- Resource regen is **disputed** (BlueStacks: never; NamuWiki/Reddit: respawn unless uprooted). Treat as island-type dependent until the owner picks a rule.
- Free warp-home. Domain can be **reset once per day**.
- Pioneer level / "개척도" tracks development. At character **60**, raising Pioneer Level expands the domain **without T-stones**.
- High Pioneer Level unlocks a research lab. **[Survival Tips #87, #194–211]**

#### City islands (civilized / stable shared)

- Unlock at character **level 36** (NamuWiki). Reddit "lvl 40" is the **resource/water cap**, not the unlock.
- Shared persistent land. Players and **clans** claim domains / enclaves.
- Domain tiles cost T-stones to expand and a **daily maintenance tax**.
- Climate is one of the ten biomes (see §4.4).
- Predators exist. Dense player settlement suppresses mob spawns — cities become safe and meat-poor.
- Required transit hub to reach unstable islands of level 40+.
- Each city island has its own **Island Market** (later live: markets were also grouped into **four regional markets**). **[player]**
- City fish/water max **level 40**; past that, fetch high-level water from unstable islands.

#### Village islands (early only)

- Post-tutorial shared beginner land, ~level 10 ecology.
- Crowded, low-tier, later deleted when private islands shipped.
- **Do not implement unless targeting snapshot A.**

#### Unstable islands / Unstable archipelagos

- Level-gated (15–60). Sail cost from a port.
- Last hours to a few days (map shows remaining time; a 16 Mar 2018 snapshot had a tundra island with **19 hours** left). Then sink; a replacement of that climate/level appears.
- In 2019, a friend's unstable island **does not exist for you** until you **Follow party leader route**, finish connecting **pioneer missions**, and unlock the index. Different parties cannot see each other's path.
- Camp: **−50% fatigue gain**, free return-to-camp, shared furnace / kiln / loom / workbench. Animals can still aggro into camp.
- Walled house interior: **−100%** environment fatigue.
- Communications Center + camp shed for missions.
- Craters (plant / animal / mineral) and warp ruins are the reason to go. Nests are **animal craters**, not a separate island type. They are harvest nodes, not a breeding system.
- Discovering a crater **reduces fatigue**. Discovering warp holes enables paid fast-travel between them.
- Lv.60 archipelagos add an **instability index** (harder gather, better attributes; needs Pioneer Level + body resistance).
- Furniture *can* be placed but is wasted because the island will vanish.
- Courier boxes (warped Earth packages) scatter on a fresh island: modern junk plus rare seeds.
- **2016 beta:** could not travel unstable → unstable. **2018–19:** archipelago + follow-route contradict that. Era split.

#### Savage / Lawless / Outpost islands

PvP was **never open-world**. It was always a named island type, and it kept being replaced.

- **Beta Outpost (2016–17):** lv.26+, declare war → 1 min delay → **24h** fight, safe in own territory.
- **KR live Lawless (2018):** unlock **lv.56** via city port (official Feb 2018 patch billed it as lv.60 PvP). Full-island PvP except harbor and **neutral warp holes**. All loot is **Unstable** until cargo-warped. One warp-hole base per clan; defense window (build towers / catapults / lab) then attack window. Beta defense reward: Smilodon / Direwolf / Tarbosaurus; live reward often **one flag**.
- **Global Jul 2019:** Savage **removed**. Replaced at sunset by instanced **Combat Island** (battle-royale). **ANTI** if the product needs a living PvP frontier — the unique loot was already duplicated on PvE lv.60 archipelagos, then the island type itself was deleted.

Store "Raid Islands" has **no mechanical writeup**. Do not invent a raid-instance product; volcanic T. rex hunts are the evidenced raid.

#### Volcanic islands (late 2019)

- Unlock lv.56+ / ecology 60, requires volcanic heat resistance.
- Lava, **ash storms**, hot springs, black iron, lava resource.
- T. rex as a multi-phase raid boss (~200,000 HP reported). Kill grants title **Apex Predator**. **[player]**
- Horseshoe crabs; lava gathered with shells. Some iguanas only surface during storms.

#### Creative island (post-EOS, out of scope for live MMO)

- Offline. Instant place/destroy. No economy. Friends' islands only. Data is local and deleted with the app.

### 4.3 Travel

**MUST:** island-to-island travel is a **harbor sea-route graph**, not open-ocean sailing and not landmasses that drift into each other. The raft is a map vehicle; the crossing is a load-screen teleport. **[dev, NDC 2015]**

| Method | From | To | Cost | Notes |
|---|---|---|---|---|
| Hot air balloon | Ancora | First home | Fuel (leaves/branches) tutorial | Live tutorial vehicle. Lore says rafts wrecked — flavor only. |
| Port sail (raft UI) | Harbor | Listed island | T-stones (distance × island level, usually < one quest) | Permanent vs temporary/red on the list. Cannot return to Ancora. Random sail from personal/city harbor can land on someone else's personal island. |
| Unstable return | Unstable harbor | The port you arrived from | Free | 2016: no unstable→unstable. 2019: follow-route / archipelago. |
| Follow party leader route | Harbor | Party member's unstable | Pioneer missions + index | Required in 2019 or the island "doesn't exist." |
| Warp hole | Discovered hole A | Discovered hole B | T-stones | Need **two** discovered. Harbor has a nearby hole. Prefer for intra-island travel. Death can revive at a discovered hole. |
| Domain warp | Anywhere | Own domain | Free | |
| Camp recall | Unstable interior | That island's camp | Free | |
| Cargo warp | Camp warp hole | Domain cargo warp hole | Required to **stabilize** Unstable/modern goods | Without this, warp-ruin / lawless loot vanishes on return to stable land |
| Harbor balloon (late) | Port | Aerial **15 min** | Anti-grief vs doughnut claims | Lets players land inside fenced voids |

No primary source for player-steered ocean sailing, naval combat, swimming between islands, **caves**, or islands that physically dock.

**Map size:** 8 km × 8 km is an NDC 2015 **prototype continent target**, not a measured live island. Domain 4×4 is claim size, not island size.

### 4.4 Climates / biomes

Ten climates. Each island has one. Flora, fauna, craters, and **required resistances** change.

| Climate | Typical unstable levels **[player]** | Resistances needed |
|---|---|---|
| Savannah | 15, 45 | Weak heat (15) |
| Temperate | 20, 35 | Weak cold |
| Tropical | 25, 40 | High heat |
| Tundra | 30, 40, 55 | High cold |
| Desert | 35, 50 | Heat + scorching sun |
| Swamp | 45, 55, 60 | Heat + humidity |
| Snowfield | 50, 60 | Cold + strong wind |
| Blue Tropical | 55 | Heat + humidity |
| Volcanic | 60 | Heat |
| Grassland | Private island default | Mild |

Temperate is the default "good place to live": easy farming, water, population, markets. Swamp / desert / snow are specialist.

Climate is a **fixed island property**, not a season cycle. Event letters mention real-world seasons; that is copy, not a sim. NamuWiki once says "five ecosystems" then lists ten — leftover text.

### 4.4.1 Weather and time

Weather is a **status layer** on climate, not a forecast UI.

- **Rain / standing in water 5s** → Wet. While raining or in water: indefinite. After leaving: **2 minutes**. Wet: heat fatigue **−20%**, cold **+30%**, humidity **+30%**. Does **not** affect scorching-sun fatigue.
- **Bonfire:** clears Wet; while sitting, heat **+20%**, cold **−20%**.
- **Volcanic ash storms** (2019). Hot springs as a survival tool. No numeric table found.
- Shade blocks heat.

**Day/night exists** (animal vision differs; letters mention mornings). **Cycle length was not found.** Do not invent a 24-minute day.

**No caves.** No namu section, store bullet, or NDC mention. Do not add a cave dungeon as "Durango."

### 4.5 Craters

Craters are the unstable-island POI.

Each crater has three parts:

1. The crater node itself (often opened by burying T-stones — in-game memo: energy opens a closed crater; an open crater warps resources in).
2. Unique plants / minerals around it.
3. Guardian animals, **level ≈ island+1** (Reddit) or **+3** (NamuWiki). Always aggressive (even herbivores). Aggro radius increased. Treat +1 vs +3 as unresolved.

Types:

- **Plant colonies** — flax, bamboo, baobab, cotton, tea, mango, cactus, mushrooms, etc. Climate-specific.
- **Animal** — nests (dinosaur eggs, oviraptor, saurolophus, centrosaurus), bone graves.
- **Mineral** — mud pits (all climates), rock, ore, obsidian, marble, zinc, silver, gems, ice.
- **Warp ruins** — chunks of Earth. High-value modern goods. Loot is unstable until cargo-warped. Contested the instant a new island spawns; respawn is slow.

Scan / Sense radar points to the nearest undiscovered crater or warp hole. Finding them pays T-stones and cuts fatigue.

### 4.6 Water and terrain rules

- Fresh water: drink (cuts heat fatigue), wash (clears dirty), fill containers, cook, dye, medicine, fish traps, reeds for cordage.
- Seawater: salt, some recipes; city-island seawater becomes under-level later.
- Current in rivers: mounts ignore current; swimming characters do not.
- Farmable tiles exclude sand, gravel, swamp muck, irremovable boulders. Planting on bad soil can fail or (bug) delete seeds.
- Public land on stable islands: anyone may place or destroy furniture. Paving costs T-stones. Only claimed domain tiles are protected.

---

## 5. Character, identity, stats

### 5.1 Creation

- 8 occupations × 2 genders = 16 authored faces/stories. Occupation is **not a class lock**.
- Each occupation starts with **skill proficiency 20** in one tree:

| Occupation | Starting skill |
|---|---|
| Soldier | Melee |
| Job seeker | Defense |
| Office worker | Construction |
| Technician | Weapon / tools |
| Flight attendant | Tailoring |
| Student | Gathering |
| Homemaker | Cooking |
| Farmer | Farming |

There is **no** occupation that starts in Survival, Processing, Butchering, or Ranged.

- Appearance (body, modern clothes, dye) is chosen after the prologue. Modern clothes start torn and can be repaired later.
- Starting bonus is irrelevant by mid-game. Tailor is the convenience pick (bags + cloth weaving at 20).

### 5.2 Base attributes (8)

| Stat | Feeds |
|---|---|
| Strength | Attack, weapon crafting, armor penetration |
| Agility | Accuracy, evasion |
| Constitution (맷집) | Furniture crafting, health, construction, energy |
| Charm | Farming, tailoring, cooking |
| Intelligence | Furniture, construction, craft, metalwork, disassembly, plant gathering, cooking, mining |
| Dexterity (솜씨) | Weapon crafting, plant gathering, tailoring, crit, mining |
| Will | Craft, metalwork, farming, butchering, energy |
| Wits (눈치) | Butchering, disassembly, stealth |

Derived groups: taming cap, stealth, max health, max energy, capture power; gathering/butcher/mine; craft/metal/tailor; combat (atk, pen, def, acc, crit, eva); production (furniture, build, farm, weapons, clothes, cook); climate resists (heat, scorch, humidity, cold, wind).

Food, titles, gear, and clan perks further modify these.

### 5.3 Levels

| Track | What it is |
|---|---|
| Character level | Cap 60. Gates island access, skill cap (a skill cannot exceed character level), some recipes. |
| Skill levels | 12 trees. See §7. |
| Tamed-island pioneer level | Development of private island. |
| Physical resistance levels | Climate adaptation from time spent in biomes + gear. |
| Clan level | Guild progression. |
| Faction trust | 10 ranks per support organization. |

XP sources: missions, gathering, hunts, crafting, exploration, dailies, milestones. Combat is not required to 60. **[dev]**

Research gates: after skill level 20, every 5 levels requires a timed **research** before the next level (20m → 3 days at 59→60). Survival is the exception: no research, always tracks character level.

### 5.4 Titles

Career titles and support-organization titles. Example late title: **Apex Predator** (T. rex kill) — large global bonuses. **[player]**

### 5.5 Accounts

- Soft launch / KR: multiple named shards (Asia Alpha…Echo), later merged.
- May 2018 merge introduced **multi-character** (2 slots default, up to 8 via purchase; extra slot sales later stopped).
- Global: Asia / West / Asia II. Recommended by region, not forced.
- Ambition **[dev]:** eventually one worldwide shard. Never fully realized.

---

## 6. Survival vitals

Durango uses **three** primary bars, not classic hunger/thirst/temp. There is **no weight/encumbrance, no disease sim, and no limb-injury sim** in remaining sources.

### 6.1 Health / Life

- **Health** = current HP in and out of combat.
- **Life** = combat alias of Health, and also the *cap* current health can reach after wear. Medicine / decocted petals and roots restore Health. **Food does not restore Health.** **[Survival Guide #13]**
- In combat, Life and Stamina are spent; out of combat they equal Health and Energy. **[Survival Guide #17]**
- Defense tree raises max Health / recovery. Survival "Belly Fat" ranks raise **max Energy only** (+10 per rank, 10 ranks).

### 6.2 Energy / Stamina (blue bar)

- Spent on gathering, crafting, combat skills, sprinting.
- Restored by **eating**. Cooked food >> raw. Health/Energy also **slowly auto-recover**. Sleep is the fatigue dump, not the Energy engine.
- Full / stuffed status blocks further eating for a short window (~10s is Reddit-only). **[player, medium]**
- Moving while eating cancels remaining restore and still applies fullness. **ANTI-gotcha — MUST show clearly in UI.**
- English guides mash Energy / Stamina / Fatigue. KR HUD: 에너지 = food-fed bar; 스태미나 = combat spend of that bar.

### 6.3 Hunger and thirst

Hungry / Thirsty / Full / Quenched are **status effects that change fatigue rate**. They are not kill conditions. Do not re-add a starve meter unless the product owner explicitly wants the prototype Durango cut.

### 6.4 Fatigue (session governor)

- Rises from: walking, gathering, being on a higher-level island, being dirty, hungry/thirsty, wrong climate clothing, rain/cold/heat, failed actions (dejection).
- Falls from: rest, wash, drink, appropriate clothes, discovering craters, encouragement from other players, fatigue potions (crafted or cash shop), some juices (desert).
- Map UI shows a **fatigue breakdown**.
- At max fatigue: **Danger** — too tired to act until rest.

Wet and over-dry are context-flipped: wet helps in heat, wrecks you in cold, and vice versa.

### 6.4 Other statuses **[NP, transcribed UI]**

Full table with durations and percentages: [bestiary/combat research §4](../../research/durango-wild-lands-bestiary-combat.md#4-status-effects--the-full-table). Highlights:

| Status | Duration | Effect |
|---|---|---|
| 아늑함 Coziness (camp) | while in camp | Fatigue gain −50% |
| 집 Home (walled interior) | while indoors | Fatigue gain −100% |
| 발견의 기쁨 Joy of Discovery | 15 s | Fatigue drop, scales with island level |
| 활력 Vitality | 60 s | Energy consumption −50% |
| 씻음 Cleanliness | 6 min | Fatigue gain −20% |
| 탈진 Exhaustion | until fatigue ≤ Tired | Evasion/accuracy −80%, gathering disabled |
| 매우 더러움 Very dirty | until washed | Fatigue +20% / +50% |
| 복통 Stomachache | 5 min | Health −0.2/s |
| 열독 Heat poison | 6 min 30 s | Health −1/s |
| 파상풍 Tetanus | 30 s | Energy −1/s |
| 똥독 Fecal toxin | 60 s | Fatigue +18/min |
| 침범벅 Drool-soaked | 30 s | Fatigue +5.4/min |
| 벌레 물림 / 벌 쏘임 | 1:15 / 1:45 | Accuracy −20% / crit −20% |
| 어지러움 Dizziness | 25 s | Evasion −40, accuracy −20% |
| 부활 후유증 Resurrection aftereffect | 10 min | Recovery down, **stacks per death** |
| 좌절 Frustration | 15 s | Energy consumption +50% |

**MUST NOT claim Durango had combat bleed or poison.** There is no 출혈 and no combat 중독 in the status table. Every damage-over-time effect is **environmental or ingested** — raw meat, climate heat, rusted debris, dung, insects. The only animal-applied statuses are **침범벅** (a fatigue tax from being chewed on) and the **stun / knockdown** control pair. The single near-exception is Tuojiangosaurus, whose tail swing is described as causing 내출혈 (internal bleeding): one flavored attack, not a system.

Dirt is not cosmetic: it increases heat fatigue. Wash in water.

### 6.5 Death

- Can revive near a **discovered warp hole**, or post a rescue bounty. **[Survival Guide]**
- Loot rule is **disputed**: in-game "lose items" vs player reports that **unequipped bag drops**, equipped stays, durability ticks. Pet inventory is not dropped and does not take death durability hits. Treat as **medium** until a death UI screenshot is recovered.
- Equipped weapons lose ~3 durability on death. **[player]**
- Long stacking debuffs. Dying twice in a row is a spiral.
- Corpses attract scavengers. If a feeding animal is threatened, **the corpse and its items can be destroyed**.
- On savage islands (when they existed), other players loot you.

Inventory is **slot-based** (worn bags + placed baskets). 100 slots is cited for **baskets**, not the worn bag. No weight stat.

### 6.6 Climate resistance

Clothing + time in biome + cooking/drink buffs. Entering a climate without the listed resists is possible but fatigue-punished. This, not a hard lock, is how islands are gated besides Survival rank and character level.

---

## 7. Skills

### 7.1 Economy of points

- 12 trees. Skills are either **unlocks** (new actions/recipes) or **success-rate** nodes. Unlocks are the valuable ones.
- Trees are chained; you must buy from the root.
- ~**827 SP at level 60**, plus ~70 from milestones / career guides → ~900. **[player]**
- Survival + Gathering + Construction + Processing alone can consume ~800. A solo player **cannot** be complete. This is intentional specialization. **ANTI if you want a solo game; MUST if you want Durango's social pressure.**
- Refund: 5 free unlearns/day, then 30 Warp Gems each, max 10/day. Full reset ticket = 900 Warp Gems (widely considered overpriced).
- Auto-learned skills cost 0 SP and cannot be refunded.
- Gathering / butchering / construction nodes are required for some faction quests — even non-specialists dip.

### 7.2 The twelve trees

| Tree | How it levels | What it unlocks |
|---|---|---|
| **Survival** | Passively, with almost any play. No research. | Island-level access, constitution/energy, stealth, **taming/capture**, capture tools, max bonded animals (3→6) |
| **Gathering** | Foraging. Skill level = max material level you can harvest (higher nodes downrank to your skill). | Plants, insects, herbs, **mining**, mud/dung |
| **Butchering** | Skinning carcasses | More yield, rare parts (organs, tendons, armor scutes, quality bones) |
| **Processing** | Turning raw → parts. Half XP-to-level vs others. | Cordage, nails, charcoal, drying hides, smelting, milling, intermediate parts |
| **Melee** | Fighting with close weapons | Stances (Attack, Onslaught), weapon-type mastery, knockdowns, capture-adjacent crowd control |
| **Ranged** | Fighting with bow/crossbow | Draw power, fire rate, kiting. Standard for raids. |
| **Defense** | Fighting, especially taking hits | Max health/life, roll, parry, counter, anti-knockdown |
| **Weapon / Tools** | Crafting weapons and tools | Knives, axes, picks, spears, hammers, one-hand vs two-hand, work vs combat variants, cooking utensils |
| **Tailoring** | Crafting clothes | Climate resist, armor, **bags** (inventory), cloth from fiber |
| **Construction** | Building | Workstations, storage, residences, fences, traps, clan structures, signs |
| **Cooking** | Cooking and herbalism | Energy density, buff food, medicine, the combinatorial food meta |
| **Farming** | Tilling, planting, harvesting | Fields, fertilizer, wells (Construction 25 / 45), seeds. Sprinklers are player-attested but **missing from the dumped farming skill table**. |

### 7.3 Requirement: specialization

The product **MUST** make it economically rational to:

- Main 2–3 production trees + Survival + enough Gathering to not downrank loot.
- Buy the rest on the Island Market or from clanmates.
- Run an alt character for the missing trees (late-live design embraced this).

If a rebuild gives enough SP to max everything, the market, clans, and "occupation" fantasy collapse.

---

## 8. Gathering, hunting yield, processing

### 8.1 Contextual gathering

Tap node → character uses the correct tool. Combat weapons *can* gather but burn durability. **MUST** support a **lock** flag on combat weapons so they are never auto-used for chores.

Tool classes: knife (plants/thickets/butcher), axe (wood), pick (stone/ore), harpoon (fish), containers (water).

Great-success gathers can add extra **process counts** on the item, which cooking later exploits.

### 8.2 Butchering

Default carcass: meat + bone + hide. Then specialized:

- Meat: generic, loin, organs, fat, tendon
- Bone: horn, leg, rib, skull, tooth (large leg bones double as **pillars**)
- Hide: leather, fur, feathers, osteoderms / scutes

Butchering skill gates rare parts. Species carry **innate latent attributes** on specific parts (e.g. Smilodon skull/leg → Hardness; mammoth hide → wind resist). Those attributes are why you hunt *that* animal, not a generic "leather node."

### 8.3 Processing (the industrial layer)

Raw resources are rarely finished goods. Processing creates the graph:

- Stalks / reeds → twine → rope
- Logs → split wood → nails / planks / pillars
- Hide → dried hide → straps
- Ore → smelt → ingot → metal parts
- Clay / mud → ceramics via kiln
- Fiber → thread → cloth (tailor + processing overlap)
- Charcoal from burnables (fuel for stations)

**Rule:** when crafting a finished item, **only the primary (first-slot) ingredient's attributes inherit.** Secondary slots are bulk. Players who "match" every slot's attributes are wasting mats. **MUST** teach this in the craft UI, not hide it.

Latent attributes = yellow pip. Rare extra attributes = green pip, low chance. Great-success crafts can add extras.

### 8.4 Item level

Materials have levels tied to island / node. Gathering skill below that level **downranks** the take. Finished goods have levels that gate effectiveness. Boiling in high-level water can **uprank** some ingredients toward the water's level (cooking exploit; see §9).

Unstable-island and savage-island materials may be tagged **Unstable** until cargo-warped.

---

## 9. Crafting, cooking, farming

### 9.1 Flexible recipes (crown-jewel system)

Recipes ask for **slots with categories**, not SKUs.

Example: Improvised one-hand axe =

- Blade: stone *or* bone *or* metal shard
- Handle: branch *or* bone
- Lashing: reed *or* root *or* twine

The output's stats come from (a) recipe, (b) primary ingredient attributes, (c) how many processing steps were applied (bake, boil, dry, hammer, mince, …). Same "work knife" is a different item if the blade bone is Smilodon vs Protoceratops.

**MUST NOT** roll affixes independently of inputs. That is the opposite of Durango.

Color of a crafted object follows material color (Haven & Hearth lineage, praised).

### 9.2 Stations vs hand craft

Early recipes are hand-crafted. Unlocks add:

- Workbench, technical workbench
- Bonfire, hearth, kitchen, kiln, furnace
- Loom, drying rack
- Mortar (meatballs, instant)
- Taming pen, barns, fields, sprinklers, fertilizer piles
- Storage: baskets (~100 slots early) → boxes → large boxes (pillar requirements)

Camp on unstable islands has a public subset. Long crafts belong on a domain because public stations are contested and domain buildings on *private* islands do not decay.

Late quality-of-life: auto-continue on production. **[dev]** Originally no auto; added after launch complaints.

### 9.3 Cooking

Cooking is both survival (energy) and the deepest combo minigame.

Baseline path:

1. Skewer (Lv1, needs stick + fire). Two cooks: underdone → well-done. Cap later nerfed to **item level 19**. Emergency food only.
2. Meatballs (mortar, then cook) and stone-plate grilling (~20). Burnt on fail = energy crash.
3. Steam (~25). Dumping all process counts into steam ("steam-steam") explodes energy.
4. Sashimi (~40): 1 meat → 3 sashimi, process count forced to 2. **Sashimi-steam-steam** was the famous player-discovered energy engine, including on clam meat. **[dev confirmed they did not design this; they celebrated it.]**
5. Higher: roast, seasoned roast, grill, etc.

Boiling ("life-or-death + alchemy"): boiled goods take on water level. Lv30 meat boiled in Lv60 water → ~Lv45. Leather/wood-tagged equipment can be boiled into edible items early; later recipes drop the tag and cannot.

Rules:

- Raw meat/fish/mushrooms can poison or apply "tastes bad" (fatigue). Cook first.
- Poison can persist through cooking. Players used this to grief-feed. **MAY keep as social hazard; MUST allow inspecting food attributes before eating.**
- Food grants combat and gathering stat buffs. A production player with buff food + tank pet can hunt.

### 9.4 Farming

- Hoe + mud → field (small at 1, large at 25).
- Water **amount** raises **success chance**. Fertilizer raises **yield** (overflow carries to next plant). Official comment: water **item level** does not change chance/quality/yield. Both can be true if split that way.
- Output level is capped by **farming skill**, not field tile level.
- Wells exist (Construction 25 simple, 45 well). Sprinklers: BlueStacks/Reddit yes, skill-table dump no — existence **medium**, recipe **low**.
- No pipe-network irrigation sim.
- Flax is the recommended early crop (seeds + thread + fish traps, levels tailor/construction together). Corn can be grown with almost no SP.
- Advanced fertilizer (~40+) is ~3× fruit fertilizer.
- Ranching: mammals in barns produce milk (post-launch: not from male white-bellied Megaloceros). Dung is fertilizer/mud-adjacent. Medium barn is 6×6 — solo tax-inefficient; clan-scale.

### 9.5 Equipment slots and dual-use

- Clothing: climate + armor + bags.
- Weapons: one-hand (fast, few targets) vs two-hand (slow, AoE). Spears are the exception (no 1H/2H split).
- Work variants of knife/axe exist — cheap, weak in combat, spare combat-weapon durability. Metal work-weapons are not a thing.
- Demolishing buildings requires a melee weapon equipped.
- Ranged is safer, lower DPS than a good melee setup, default for group hunts/raids.

---

## 10. Combat ("Hunts")

### 10.1 Why it looks like this **[dev]**

Combat was not the original pillar. Vindictus veterans on the team refused "just auto-swing." Result: a hybrid hunt that is neither tab-target MMO nor full action.

### 10.2 Entering a hunt

- Aggressive animals pull on proximity / scent (high-level carnivores from off-screen).
- Passive animals: tap → Attack.
- Long-press a target starts combat immediately. **[memo]**
- Pets you have summoned join.

### 10.3 During a hunt

- Auto-attack on by default, rate from weapon.
- Skill icons appear for learned tactics: body slam, kick, sweeps, rolls, parries, stances, capture net, etc. Weave them between autos.
- **Chase vs Hold:** chase a fleeing/knocked target or hold position.
- Yellow telegraph circles on heavy enemy skills; timed **roll** (defense tree) is the skill-up and the survival check.
- Directional engagement: front / back / left / right change the fight. **[memo]**
- Retreat is not a panic button; you change tactics to disengage. **[memo]**
- Pets tank, DPS, or body-block. Invisible-pet bug made this miserable — **ANTI, fix if rebuilt.**

### 10.4 Stances (melee)

Attack stance from tutorial. Onslaught stance (~20) for two-hand burst. Higher ranks. Defense tree is the counterpart (max HP, counters).

### 10.5 Capture in combat

See §12. Stun (often shoulder tackle) at low HP → net. Failures are expected.

### 10.6 PvP combat **ANTI (late)**

PvP was never "the open world." It was Outpost → Lawless/Savage → deleted on global → Combat Island BR.

When Savage still existed:

- High-friction armor prevented knockdown, deleting the melee combo identity.
- Agility stacking could dodge all power-stat attacks; then neither side could kill through food regen.
- Emulator clients could open bags mid-fight; phones could not.
- Siege windows could fall at 3am local. Pike charge deleted walls in two hits.

If PvP is in scope, it needs a **separate ruleset**, not the PvE hunt with players swapped in, and unique loot that PvE islands cannot duplicate.

### 10.7 Raid-scale animals

Tarbosaurus (first raid, ~60k HP later), Allosaurus (story pack ~28k then more), Brachiosaurus (beta "true boss" vs T. rex), volcanic T. rex (~200k, 3 phases). Groups, ranged, and tank pets are required. Tarbosaurus roar pulls off-screen wildlife, which then dogpiles the boss — keep or cut as a spectacle.

---

## 11. Ecology and animals

### 11.1 Setting rule

Permian through late Cenozoic species coexist because of the warp. People from Rome, the Crusades, Sengoku Japan, and the 21st century coexist too. Over time, in-world writing treats dinosaurs as livestock.

### 11.2 AI **[dev + player]**

Shipped (partial food-web):

- Drink at water, sleep at night (some predators don't).
- Carnivores hunt herbivores; scavengers swarm carcasses (including player corpses) and will fight you for them.
- Herds, especially with juveniles, have **solidarity AI** — hitting one pulls the group. Isolate or bring numbers.
- Some species flank.
- Emotes: anger, sleep, thirst, joy, surprise, fear. Readable tells.
- Crater aura: +level and forced aggro, reverts when crater closes.

Not shipped: full habitat migration, player-driven desertification (forests logged → animals gone). Prototyped, cut as too fragile for progression. **[dev]**

### 11.3 Role taxonomy (implement as archetypes, not 200 unique brains)

**Carnivore archetypes**

| Archetype | Examples | Combat | Tame role |
|---|---|---|---|
| Raptor pack | Raptor, Deinonychus, Utahraptor, Dilophosaurus, Pictaraptor | Leap (knockdown), off-screen gap close | Fast mount, offtank small game |
| Saber cat | Smilodon | Paw slam (knockback, double hit), huge aggro, mine guardians | Top combat pet late |
| Tiny swarm | Compsognathus, lizards, giant rats | Weak, many, defense-XP fodder | Cosmetic / bait |
| Long-neck runner | Pavomimus, Ornithomimus, Gallimimus, Coelophysis | Charge, peck combos | Fast mount / glass cannon |
| Wolf pack | Dire wolf | Group hunt, high defense when tamed | Tank + mount (ride quality poor) |
| Tyrant | Tarbosaurus, T. rex | Stomp, roar, tail, phases | Trophy / raid |

Carnivore food: items with **water + meat + edible**. Meatballs are efficient. Hunger fill ≈ food energy × 10.

**Herbivore archetypes**

| Archetype | Examples | Combat | Tame role |
|---|---|---|---|
| Ceratopsian pack mule | Zebraceratops, Protoceratops, Centrosaurus, Styracosaurus, Triceratops | Charge, horn sweep, knockback | Inventory (50–140+ slots) and HP sponge |
| Deer / megafauna | Megaloceros | Decent all-rounder | Milk (mammals), combat |
| Ankylosaur | Ankylosaurus | Armor | Best tank/storage, hunger 6000 **ANTI-economy** |
| Titan | Brachiosaurus, elephants | HP walls, crater guards | Rare, dangerous |
| Utility oddities | Skunkodous (gas), horseshoe crab (lava tool) | Niche | Niche |

Herbivore food: fruit/veg/leaf/stalk. Nuts are ~2× energy.

Herd herbivores are often *less* cooperative than carnivores unless crater-buffed. Size and pack size ≈ threat.

### 11.4 Palette swaps

Many "species" are biome recolors (snow Oviraptor → Alviraptor, pink Protoceratops, etc.). Implement as **one rig + material + drop table + tame flag**, not unique code.

Fantasy/original species (Zebraceratops, Pavomimus, Bonusaurus, Skunkodous, Albiraptor, Achenicus, Dodophysis, …) are first-class, not second-class.

**Production ratio.** The shipped roster is roughly **90 catalog entries built from about 18 distinct rigs**, multiplied out by recolors, juvenile scales, and male/female splits. That 5:1 ratio is the reusable fact for any rebuild — budget rigs, not species. Full roster: [bestiary research §3](../../research/durango-wild-lands-bestiary-combat.md#3-full-species-roster).

**Never shipped, despite a 5.5-year AAA production:** Spinosaurus (concept art only), pterosaurs (ground shadows only — no flying creatures ever existed), Sarcosuchus (animations made, zero game files), aquatic species (system never developed), Ceratosaurus (beta only). Price flying and swimming creatures accordingly.

### 11.5 Aging

Tamed **wild** animals perform for **30 days**, then **Aged**: no combat, collapsed stats, ugly mesh. **Cash-shop animals last 60 days.** Fix with animal elixir (회춘약), **8,000–10,000 T-stones** on the market, or replace. **[NP]**

Pets level with the player (Attack / Defense / Accuracy per level) and roll a **milestone buff at pet level 20, 40 and 60** — one of Attack, Speed, or Bag Capacity, **randomly assigned and rerollable for money**. **[S, medium]**

Capture-to-**instant-tame** is real for **early KR**. From **2018-12-13** the live path is capture → **taming pen** (time + chance, **S–C grades**).

**ANTI — the nerf that killed taming.** NamuWiki states it flatly: 길들인 동물들의 능력치가 야생 개체에 비해 심각하게 낮다. Centrosaurus went 5,000 → 2,900 → 2,300 HP. Ankylosaurus went ~8,000 → 2,963. Tarbosaurus is 60,000+ wild and **2,500 tamed on a 16,000 hunger budget**. A final balance patch was never shipped. The reward for the hardest capture in the game was a worse pet than a mid-tier one, so players demoted pets to bags and mounts — which is why §12.3 reads storage-first. See §22.9.

Player breeding / "generation" UI was teased and **never went live**. Crater nests are harvest nodes, not breeding. Do not implement breeding as shipped Durango.

---

## 12. Capture, taming, pets

### 12.1 Pipeline

1. Learn the matching **포획기술 (capture technique)** node in the Survival tree. Five tiers, 20 SP total, each unlocking two species:

   | Skill | Survival lv | SP | Unlocks |
   |---|---|---|---|
   | 포획기술 I | 15 | 2 | Zebraceratops, Macrauchenia |
   | 포획기술 II | 25 | 3 | Pictaraptor, Megaloceros |
   | 포획기술 III | 35 | 4 | **Protoceratops**, Deinonychus |
   | 포획기술 IV | 45 | 5 | Skunkodous, white-bellied Megaloceros |
   | 포획기술 V | 55 | 6 | Centrosaurus, Pavomimus, Velociraptor |

   Earlier drafts of this PRD called tier I "Capture Quadrupeds I" and put Protoceratops in it. Both were wrong — Protoceratops is tier III.
2. Craft / carry a capture tool of sufficient tier (I/II/III).
3. Fight → weaken (~50% HP shows "losing strength") → **stun** → **knockdown** → net. Blunt weapons raise stun chance; Body Tackle is the named melee proc. A stunned target hit again has a high chance to be knocked down, and the downed window is the capture window. Chance can fail.
4. Captured animal occupies a **large inventory chunk**.
5. Place in a **Taming Pen** on a domain (tutorial gives a Makeshift pen). Optional feeding shortens the wait. First Zebraceratops: BlueStacks **~30 min**, ChapterCheats **1 hour** — unresolved. Success chance is <100%. Failure = animal escapes.
6. On success the animal has a **grade (S–C)** after the Dec 2018 overhaul. Use the animal item to **bond**. Bonded animals can be summoned anywhere.
7. Summoned pet: combat ally + mount + extra inventory.

### 12.2 Caps

- Base 3 bonded animals. **동물 관리 I–IV** (Survival 35 / 45 / 55 / 60) each add **+1**, so the cap is **7**. The long-running "6 vs 7" disagreement in secondary sources is people counting a different base, not a different table — there are unambiguously four ranks. **[NP, resolved]**
- **Exploit (shipped):** max the cap, bond them, unlearn the nodes — animals remain. **ANTI or MUST decide.**
- Species gated by specific capture skills, not a generic "taming level." Valuable species (Raptor, Centrosaurus, Pavomimus, late Utahraptor / Smilodon / Anky) sit behind expensive nodes. Many players **buy tames on the market** instead.

### 12.3 Pet functions

- **Mount:** speed 450 (ceratopsian walk) to 700 (early raptors / premium Gastornis). Raptors were later nerfed below 600. River current ignored while mounted.
- **Bag:** Zebraceratops 50, Protoceratops 90, Centrosaurus 140, cash Bonusaurus 300.
- **Tank:** high HP / def species hold aggro so crafters can hunt.
- **Death bank:** items on the pet do not drop.
- Premium cosmetic pets (Labrador) may have no combat/mount; a black Labrador event pet had heal / wash / fatigue emotes.

### 12.4 Hunger

Each species has a hunger budget (Raptor cheap, Tarbosaurus infamously 16,000 after a patch — unusable). Combat availability depends on feeding. Pet food ≠ player food; eating pet feed as a human applies a shame/fatigue debuff. **[player]**

---

## 13. Building, domains, clans

### 13.1 Domain claim (stable / city)

- First claim: 4×4. One additional same-size expansion free. Further expansions cost T-stones, **orthogonal only** (no diagonal).
- Daily tax scales with tiles. Deposit up to 7 days early; later patch capped prepaid tax at **28 days**.
- Empty deposit → grace period → claim released. Abandoned storage becomes lootable ("junk shop" meta).
- Free warp to domain.
- Permissions: outsiders vs friends (use stations, drop items, etc.).
- Furniture **fully inside** the claim is protected and free to place. Overhanging the border is taxable / stealable / destroyable.
- Houses: comfort from furniture, complexity penalty if overcrowded. Rest bonuses. Tents: shade + rain, no furniture, cheap fatigue management in hot biomes.

Private island: no tax, no decay (completed buildings).

### 13.2 Public vs private

Public land is a commons. Players will:

- Fence doughnut shapes to enclose untaxed interior ("tax evasion").
- Balloon-drop into the hole and grief (official anti-exploit).
- Block roads, speculatively claim whole islands as a clan.

**MUST** assume this behavior. Either tax the interior, or provide the balloon, or both.

### 13.3 Building catalog (construction tree)

- Signs (text, images, animated billboards — player art culture)
- Fences, gates, walls, wall-houses
- Residences, tents, barracks
- Workstations (see §9.2)
- Storage
- Traps / snares / fish traps
- Roads / paving (T-stone cost on public land)
- Clan structures, clan warp holes, defensive towers (savage)

Buildings have **natural durability** (about 1/day) even unused. Use-durability was relaxed after launch. **[dev]** Repair kits are a production line. Private-island completed buildings skip decay.

Pack-up: most furniture can be packed free **on your domain**. Occupied houses/barns cannot.

Preview exists; committing materials then discovering the footprint is wrong is a common waste. **SHOULD** preview before consume.

### 13.4 Clans

- Create / join. Shared enclaves on city islands (clans uniquely can declare those).
- Perks **[player/wiki]:** extra T-stones, extra XP, cheaper warp and sail, reduced death penalty.
- Ranks, clan XP, clan battles, alliances, friend ACLs.
- Savage-island warp-hole ownership was the PvP endgame **until global Jul 2019 removed Savage**. After that, Combat Island is a disconnected BR, not a land-control loop.
- Skill-point scarcity + tax + durability **force** clan play for a "full" village. Private islands + second character later made solo viable-but-worse.

---

## 14. Economy

### 14.1 Currencies

| Currency | Role |
|---|---|
| **T-stones** (티스톤 / T-coins) | Soft money. Sail, warp, domain tax/expansion, market, some crafts, opening craters. Primary sink and faucet. |
| **Warp Gems** | Premium-adjacent but also earned. Warp-related spends, mission rerolls (30), skill unlearn (30), some pets/elixirs. |
| **Durango Coins** | Cash shop. Cosmetics, houses, premium pets (Gastornis, Bonusaurus, Labrador, festival packs), fatigue items, convenience. |

Naming is inconsistent across English sources (T-stone vs T-coin vs Tea stone). **Use T-stone in-game.**

### 14.2 Faucets

- Faction missions (main). ~10 missions/day recommended; 5 and 10 clear dailies give fatigue meds. High-level islands pay more. Lv55 tundra hunt missions were an XP/gold farm until nerfed. **[player]**
- Dailies / weeklies / achievements (task points → Warp Gems at thresholds).
- Island Market sales.
- Crater / warp-hole discovery.
- Clan buffs, level-up grants.
- Support packages from factions (trust rank, timed refresh).
- Aid requests every 8 hours — free mats, including annoying ones like bowstrings.

### 14.3 Sinks

- Sailing to unstable islands.
- Warp hole travel.
- Domain tax (1,500–2,000 T-stones/day at ~11 tiles reported).
- Market listings / purchases.
- Opening closed craters.
- Public paving.

### 14.4 Island Market

- Per stable island. Player-to-player. Equipment, mats, food, **animals**.
- Specialization makes this mandatory, not optional.
- Camp discard piles are a grey market of full-bag dumps.

### 14.5 Unstable goods

Warp-ruin and savage mats **MUST** require a cargo-warp stabilize step. This is both lore (dimensional instability) and the PvP objective (control the hole).

---

## 15. Factions, missions, narrative

### 15.1 Support organizations

They never meet in person; they radio. Trust ranks (10) unlock better **support crates** (3 items per rank band, some guaranteed, some RNG, refresh after days) and lore logs.

| Org | Unlock | Fantasy | Player use |
|---|---|---|---|
| **The Company** | Tutorial | Humanitarian, callsigns not names (K, Charlie, …) | First missions: herbs, pillars, fish, fuel, meatballs, shoes/hats |
| **Chlorophyll Forum** | Tutorial-adjacent | Conservation, sustainability | Opposed to Pioneer Council |
| **Pioneer Council** (Frontier Coalition / 개척회의) | ~16 | Industry and science | Opposed to Chlorophyll |
| **The Committee** | ~20 | Authoritarian, high pay, contemptuous | Hard missions, best rewards |
| **Radio University** | After Company, ~20 | Dr. Lamar, one-man university | **No crates, no fetch quests.** Career guides only |

Mission rules:

- Taken at Communications Center on unstable (and tutorial) islands.
- Multiple active (up to 4 around level 20).
- 3 free rerolls, then Warp Gems.
- Cooldown after accept/abandon before that faction offers again.
- Turn-in at camp shed. You must **visit the objective pin** even if you already have the items, but the items themselves can be gathered elsewhere, crafted, or **bought**.
- Rewards: XP, T-stones, ~50 trust. **[player]**

Career guides (Radio University): checklist of skills practiced. Completing them is the only reputation path for that org and a source of extra SP.

### 15.2 Story delivery

- Prologue on the train (raptor, T. rex, K, dog to safehouse).
- In-world memos / survival guidelines.
- Radio logs that unlock with trust.
- NPC behind-the-scenes fiction on official socials.
- Late "journal" quests finally put the player in the plot; EOS shipped an ending.
- Tone: competent Korean literary text, poorly coupled to verbs. **SHOULD** bind more story to systems if rebuilt.

Cast to preserve if narrative is in scope: **K**, **Charlie**, **Dr. Lamar**, Company callsign culture.

### 15.3 Onboarding beat sheet

1. Train warp → Ancora.
2. K first aid, gather, wash, craft first knife, cut thickets.
3. Company camp, Communications Center, first hunts and gathers.
4. Leaf outfit.
5. Fuel the balloon, leave Ancora forever.
6. Choose private-island terrain.
7. Build tent waypoint.
8. First unstable island (Lv15 savannah), first missions, first tame at 15.

---

## 16. Social systems beyond clans

- Nearby / island chat (island population visible; "<50" used as a "new island" signal).
- Friends list, domain guest perms.
- Encouragement emote: reduces ally fatigue, has a cooldown.
- Signs as a social art layer.
- Trading via market more than face-to-face.
- Grief vectors that shipped: public-land destruction, tax-evasion wars, poisoned food, corpse camping, savage backstabs, market fraud (wrong craft on commission).

Durango is *lighter* than Haven & Hearth: no full murder-justice loop, no stealing from inside a valid claim. **MUST** keep claims actually safe or the mobile audience dumps.

---

## 17. Progression geography (level band)

| Level | Content |
|---|---|
| 1–10 | Ancora, Company, private island, tent, baskets, bonfire, workbench |
| 10–15 | First unstable savannah, missions, climate resist starts |
| 15 | Capture Quadrupeds I, first pen, Zebraceratops |
| 16–20 | Pioneer Council, more missions, first city-adjacent goals |
| 20 | Committee, Radio University, Attack→Onslaught, cooking grill/meatball |
| 25–35 | Tropical / tundra / desert unlocks, steam cooking, larger fields |
| 36 | City islands, serious domains, clan enclaves |
| 40 | Sashimi, cargo-warp lifestyle, high unstable |
| 45–55 | Swamp / snow / blue tropical, Committee hunts |
| 56–60 | Savage islands, volcanic, raid fauna, endgame titles |

---

## 18. Monetization (as shipped)

**Design intent:** low P2W. **[reviewers]**

Cash / Warp Gem products:

- Cosmetics (outfits, houses, sign flair)
- Premium animals (Gastornis speed mount, Bonusaurus 300-slot, Labradors, festival recolors)
- Fatigue restoration
- Skill reset
- Character slots (then withdrawn)
- Signal-boost packages for private-island pioneer XP
- Animal age elixirs (also buyable with T-stones at 8,000–10,000)
- **Pet milestone-buff rerolls** at pet level 20 / 40 / 60 — the buff (Attack / Speed / Bag) is randomly assigned and paid rerolls exist
- **Cash pets age at 60 days vs 30 for wild tames** — a paid durability advantage, not a cosmetic one

**ANTI:** Gastornis / Bonusaurus / black Labrador are stronger than tameable alternatives. If "not P2W" is a requirement, premium animals must be cosmetic or strictly sidegrade.

IAP froze at EOS announce (2019-10-16). Irrelevant to a new product except as: do not depend on live ops if you cannot staff them.

---

## 19. Live content that existed

- Seasonal events (Lunar New Year hanbok Phenacodus, watermelon Tarbosaurus, magpie Gastornis).
- Story pack: **Operation Red Phenacodus** → Allosaurus.
- Burger King and snack collabs (real-world item → in-game). Japanese food, katanas, ninja clothes as global content rather than region locks. **[dev]**
- Instruments / music system in the finale patch.
- MBC reality show *Dunia*; children's comics. Out of game.

---

## 20. Technical requirements (from how it actually ran)

- Unity, mobile min ~Android 4.4 / 2GB RAM, comfortable on Galaxy S7-class.
- **One persistent world per shard**, not instanced continents. Animal AI + player building + crater state is the cost center. Launch week queues and month-long instability are part of the historical record.
- Private islands are the scalable part (closer to instances). Unstable islands are instanced-by-timer, many players per island.
- Procedural / generated island layouts were marketed; in practice climates, crater tables, and tile biomes are data-driven more than true procgen continents.
- Cross-save: post-EOS Creative Island was **local only**. A new product MUST have server-authoritative domains.

---

## 21. UX requirements unique to this game

1. Craft UI shows **category slots** and **which slot is primary for attributes**.
2. Fatigue inspector with per-source breakdown.
3. Food inspector before eat (poison, raw, energy, buffs).
4. Weapon lock vs work tools.
5. Scan radar for craters / warp holes.
6. Mission pins that do not lie about "must visit" vs "may buy items."
7. Domain tax and durability visible on the HUD before eviction.
8. Pet hunger, age timer, and inventory as first-class, not nested afterthoughts.
9. Combat: Chase/Hold, telegraphs, roll window, capture prompt when stunned.
10. Portrait and landscape layouts.

---

## 22. Anti-requirements (do not copy)

1. **Chore triangle:** fast durability + high domain tax + not enough SP. This is why people quit.
2. **Savage island without unique loot.** When Lv60 unstable had the same mats without PvP, PvP died.
3. **PvE hunt used as PvP.** Knockdown immunity, agility caps, emulator bagging.
4. **Siege clocks at 3am.**
5. **Mobile-only for a systems MMO this dense.** The audience asked for PC; the team stayed mobile. A rebuild should decide platform first.
6. **Meters-for-meters survival.** Already cut in development. Do not re-add hunger/thirst/temp unless the HUD is PC and the loop is slower.
7. **Full ecosystem sim** that can dead-end a biome. Already cut.
8. **Story that never touches verbs** until the shutdown patch.
9. **Tamed stats far below wild stats.** Centrosaurus 5,000 → 2,300 HP, Ankylosaurus ~8,000 → 2,963, Tarbosaurus 60,000+ → 2,500 on a 16,000 hunger budget. If the fantasy is "defeat the monster and it becomes yours," the tamed version must stay recognisably the same animal. Balance it by **upkeep, cooldown and cap**, never by gutting the stat block. This is the reason the shipped pet meta is bags and mounts instead of companions.
10. **Rental taming.** A 30-day aging clock plus an 8,000–10,000 T-stone youth potion turns a hard-won capture into a lease. Keep a decay mechanic only if the renewal is earned in play, not bought.
11. **Paid power in the pet line.** Bonusaurus (300 bag vs 140 for the best tameable) and Gastornis (top speed) are strictly better than anything you can catch. That contradicts the stated "not P2W" pillar in §1.4.

---

## 23. Systems map (dependencies)

```
Climate ──► Clothing/Cooking ──► Fatigue ──► Session length
Island type ──► Resources/PvP/Claims
Gathering skill ──► Material level
Processing ──► Almost every craft
Primary-slot attributes ──► Item identity
SP budget ──► Specialization ──► Market + Clans
Survival capture ──► Pets ──► Inventory/Tank/Mount ──► Who can hunt
Cargo warp ──► Whether unstable loot exists
Domain tax ──► Who can afford a full village
Factions ──► XP + T-stones + lore
```

---

## 24. Acceptance tests (if this is the product)

A build is "Durango" only if all of the following are true:

1. A cook with almost no combat skills can hit the level cap via missions, processing, and market food.
2. Two players can craft the "same" recipe and get different items because they used different primary bones.
3. A player who maxes Survival+Gathering+Processing+Construction cannot also max combat and cooking on one character without milestones-level extra SP.
4. Unstable islands disappear and a new layout of the same climate appears; claimed land never exists there.
5. Warp-ruin loot vanishes if taken to a stable island without cargo warp.
6. A Zebraceratops can be stunned, netted, penned, failed, retried, bonded, ridden, and used as a bag.
7. Fatigue has multiple simultaneous sources and a rest building that recovers it offline.
8. City-island claims are safe inside the rectangle and unsafe one tile outside it.
9. At least four radio factions exist, and one of them only offers career guides.
10. Combat is a hunt overlay with auto-attack plus weavable tactics, not a separate instance with a loading screen *and* not a full action brawler.

---

## 25. Open questions for the product owner

These are the ambiguities I cannot resolve from sources. Answers change the PRD.

### Product intent

1. **What is this PRD for?**  
   A) Faithful recreation of Durango.  
   B) Design bible to steal systems from for Deadfront Siege.  
   C) A new game that is "Durango, but we fix the anti-requirements."

2. **Canonical snapshot?** A (KR launch), B (pen taming + Savage), **C late global (recommended)**, or D Creative Island. Snapshot C has **no Savage islands**.

3. **Platform?** Mobile isometric, PC isometric, or a different camera (Deadfront is already isometric siege).

### Scope cuts

4. Keep **forced specialization** (scarce SP, market, alts), or let one character complete the tech tree?

5. Keep **domain tax + building decay**, or only use them on shared city land?

6. Keep **unstable islands that sink**, or make all resource land persistent?

7. Is **PvP / savage islands / clan siege** in v1, later, or never?

8. Is **MMO persistence** required, or is a session/co-op island enough?

### Systems that were inconsistent in sources

9. **Tamed-island resource regen:** BlueStacks says tamed-island resources do not replenish; NamuWiki says they respawn unless uprooted, and that empty stable land grows new trees/rocks. Which rule do you want?

10. **Currencies:** keep the three-currency split (T-stone / Warp Gem / cash coin), or simplify?

11. **Premium pets:** sidegrade cosmetics, or allow paid power (Gastornis 1000 speed, Bonusaurus 300 slots)?

12. **Capture exploit** (unlearn cap skill, keep extra pets) — patch it?

13. **Sashimi-steam-steam** and **boil-to-uprank** — preserve as intended mastery, or nerf as exploits?

14. **Combat:** keep hunt-tactics, or replace with Deadfront-style real-time siege combat and only steal the *economy / world / crafting*?

15. **Tone:** prehistoric warp comedy (hamburger soup, radio university) or Deadfront's darker siege tone?

16. **Animal list:** full Durango bestiary, or a smaller set of archetypes with original creatures?

17. **Travel graph:** logical harbor routes + appear/sink (what shipped), or a physical drifting-continent fantasy (what marketing implied and did **not** ship)?

18. **Combat era:** KR 2018 hunt overlay with skill reservation, or Jul 2019 joystick with reservation removed?

19. **Taming era:** instant tame (early KR) or pen + S–C grades (from 2018-12-13)?

20. **Death loot:** bag-drop + equipped-stay, or a harder drop table?

---

## Appendix A — Skill research times **[player]**

| Crossing | Time |
|---|---|
| 20 → 21 | 20 min |
| 25 → 26 | 40 min |
| 30 → 31 | 1 h |
| 35 → 36 | 2 h |
| 40 → 41 | 4 h |
| 45 → 46 | 12 h |
| 50 → 51 | 1 day |
| 55 → 56 | 2 days |
| 59 → 60 | 3 days |

## Appendix B — First-tame numbers **[player]**

- Capture Quadrupeds I: character 15, 2 SP.
- Capture tool I: character 15, 1 SP. Tool must be **in the bag**; blunt weapons help groggy. **[Survival Guide #94, #225]**
- Zebraceratops wild level ~13 on first unstable island.
- Pen time: **30 min or 1 hour** depending on source; food shortens; success not guaranteed; S–C grade after Dec 2018.
- Bonded Zebraceratops: slow mount, light combat, inventory **50** (often described as more than doubling early bag space).

## Appendix C — Lifecycle (context only)

- ~2011–2012 conception (Project K), originally a web/PC direction, pivoted to mobile.
- NDC 2015: sea-route graph, sim LOD, 8 km prototype continent. NDC 2018: stable/unstable split after the single-continent test failed.
- KR launch 2018-01-25; shards Alpha–Echo; merge 24 May 2018.
- Taming-pen overhaul **2018-12-13**. Personal islands **Jan 2019**; village islands deleted.
- West server 23 Apr 2019. Global **15 May 2019** (Japan and China excluded, despite earlier "all countries" talk). Asia II 21 May 2019.
- Volcanic islands + combat joystick pass **Jul 2019**; Savage removed on global.
- EOS announced 2019-10-16 (IAP off that day), servers 2019-12-18 11:00 KST; Creative Island leftover.
- Project DX / Durango World announced 2022, cancelled 2026-09.
- MapleStory Worlds spin-off *Durango: Lost Island* launched 2025-02 (different product).

## Appendix D — Source list

**Cited research notes (this repo)**

- [`research/durango-wild-lands-world-environment.md`](../../research/durango-wild-lands-world-environment.md)
- [`research/durango-wild-lands-systems.md`](../../research/durango-wild-lands-systems.md)

**Primary / near-primary**

- NDC 2015 island/sim: https://ndcreplay.nexon.com/NDC2015/sessions/NDC2015_0073.html
- NDC 2015 plant ecosystem: https://ndcreplay.nexon.com/NDC2015/sessions/NDC2015_0063.html
- NDC 2018 design history: https://ndcreplay.nexon.com/NDC2018/sessions/NDC2018_0012.html
- https://www.invenglobal.com/articles/2111/nexon-prepares-durango-the-next-evolution-of-persistent-open-world-mmorpgs
- https://www.invenglobal.com/articles/3977/durango-expected-to-be-released-in-korea-first-on-january-25-we-will-make-it-a-global-success
- https://app.famitsu.com/20180429_1287201/ (NDC18)
- https://www.koreaherald.com/article/1555097
- https://game.donga.com/89060/ (Lawless official patch)
- https://www.businesswire.com/news/home/20190515005178/en/The-Age-of-Dinosaurs-is-Here-in-Durango-Wild-Lands
- In-game Survival Guide / Durango Notes: https://namu.wiki/w/야생의_땅:_듀랑고/메모
- https://namu.wiki/w/야생의_땅:_듀랑고 and child pages (섬, 스킬, 동물, 아이템, 상태, 지원_단체)

**Secondary**

- https://www.bluestacks.com/blog/game-guides/durango-wild-lands/
- https://www.reddit.com/r/DurangoWildLands/
- https://www.newsis.com/view/NISX20191017_0000802189
- https://massivelyop.com/2019/10/16/nexon-is-sunsetting-mobile-survival-mmo-durango-wild-lands-already/
- https://durango-archive.fandom.com/wiki/Durango_Wiki
