# Durango: Wild Lands — Survival / Character / Progression / Craft / Gather / Cook / Farm / Tool Research

**Subject:** *Durango: Wild Lands* (KR: 야생의 땅: 듀랑고; also styled Durango Wildlands)  
**Developer:** What! Studio (Nexon Korea), director Eunseok Yi  
**Publisher:** Nexon  
**Platforms:** iOS / Android (live MMO). Offline “creation island” client after EOS.  
**Live service:** KR launch 2018-01-25; global (ex-JP/CN) 2019-05-09; **EOS 2019-12-18** (IAP stopped 2019-10-16).  
**This file is research notes, not a PRD.** Claims are tagged with source class, URL, and confidence.

**Companion files:** [`durango-wild-lands-world-environment.md`](./durango-wild-lands-world-environment.md) (world, islands, travel, biomes) and [`durango-wild-lands-bestiary-combat.md`](./durango-wild-lands-bestiary-combat.md) (animal roster, capture/taming tables, full status-effect table). Several gaps flagged at the bottom of this file are **closed** in the bestiary file — see §12.

**Fetch tip.** `en.namu.wiki` returns **403** to automated fetches, which is why several NamuWiki tables below are partial. The **`namu.moe` mirror serves the same pages and responds**: `https://namu.moe/w/야생의 땅: 듀랑고/<subpage>`. Use it for any further pull.

---

## How to read this file

| Tag | Meaning |
| --- | --- |
| **P** | Primary: in-game Survival Guide / Durango Notes, official store blurb, official press/Facebook, in-game skill/recipe UI text |
| **NP** | Near-primary: community transcription of in-game UI (NamuWiki skill tables, encyclopedia notes) |
| **S** | Secondary: player guides, journalism, Reddit, BlueStacks, LevelWinner |

Confidence: **high** = multiple independent sources or verbatim in-game text; **medium** = one strong transcription or consistent player reports; **low** = single secondary source, patch-dependent, or internally contradicted.

The live servers are gone. Official site `http://durango.nexon.com` and `https://www.nexonm.com/durango-wild-lands-farming/` are dead. Closest remaining primary dump is the in-game **Survival Guide** (loading-screen tips, 243 Durango Notes + numbered Survival Guide entries), transcribed with line breaks preserved at NamuWiki.

---

## Identity, dates, official framing

| Claim | Numbers | Source | Conf. |
| --- | --- | --- | --- |
| Open-world sandbox MMO: hunt, craft, cook, farm, build, tame dinosaurs after a spacetime warp from a modern train | n/a | Official US launch press, 2019-05-15: https://www.businesswire.com/news/home/20190515005178/en/The-Age-of-Dinosaurs-is-Here-in-Durango-Wild-Lands **P** | high |
| Store blurb: “Hunt and gather both modern and local resources… Explore… cultivate and evolve…”; E3 Game Critics “Best Mobile/Handheld” nominee | n/a | Play Store text archived at https://www.mobygames.com/game/129753/durango-wild-lands/ **P** | high |
| KR open 2018-01-25; West server 2019-04-23; global (except JP/CN) 2019-05-09; Asia II 2019-05-21 | dates above | https://namu.wiki/w/야생의%20땅:%20듀랑고 **NP** + KR press | high |
| EOS announced on official Facebook + in-game notice 2019-10-16; service ended 2019-12-18 11:00 KST; IAP ended 2019-10-16 | 2019-12-18 | Official letter quoted: https://mmos.com/news/nexons-mobile-sandbox-durango-wild-lands-will-be-shutting-down-later-this-year ; KR: https://www.etoday.co.kr/news/view/1810126 **P** | high |
| After EOS, remaining app could enter a preserved private/creation island; delete-app = data gone | n/a | Same EOS letter; NamuWiki **P/NP** | high |

Official Facebook (dead as live ops): https://www.facebook.com/playdurango/  
Community archive wiki: https://durango-archive.fandom.com/wiki/Durango_Wiki  
KR encyclopedia of in-game notes: https://namu.wiki/w/야생의%20땅:%20듀랑고/메모

---

## 1. Survival vitals

Durango does **not** use a classic starve/dehydrate-to-death loop. The live HUD is built around **Health (건강)**, **Energy (에너지)**, and **Fatigue (피로)**. Combat overlays **Life** and **Stamina** as the combat aliases of Health and Energy.

### 1.1 Health / Life

| Claim | Numbers / timers | Source | Conf. |
| --- | --- | --- | --- |
| Health and Energy recover automatically, very slowly, over time | “아주 천천히” (very slowly); no numeric rate published | Survival Guide #11 https://namu.wiki/w/야생의%20땅:%20듀랑고/메모 **P** | high |
| Energy is filled by food. Health is restored by medicine or treatment | n/a | Survival Guide #13 **P** | high |
| Health is restored by decocting flower petals or roots; plant shoots if those are scarce | n/a | Survival Guide #123 **P** | high |
| In combat, Life and Stamina are spent; out of combat they equal Health and Energy | n/a | Survival Guide #17 **P** | high |
| Better toughness (맷집) raises Health and Energy | n/a | Survival Guide #19 **P** | high |
| Death at Health/Life = 0 | n/a | In-game combat tutorial dump: https://www.chaptercheats.com/cheats/android/375405/durango-wild-lands-cheat-codes **NP** | high |
| Defense skill tree is the path for max Health / recovery speed; Survival “belly fat” only raises max Energy | Belly Fat I at Survival Lv.15, 2 SP, **+10 Max Energy**; ranks I–X through Lv.60 | https://en.namu.wiki/w/야생의%20땅:%20듀랑고/생존 **NP** | high |

**Contradiction — food vs health.** LevelWinner crafting guide says a meal “will restore your health as well as boost your stamina and reduce fatigue” (https://www.levelwinner.com/durango-wild-lands-crafting-guide-tips-tricks-on-how-to-craft-new-items-and-equipment/). That contradicts Survival Guide #13. Treat LevelWinner as **wrong on health**; food → Energy, medicine → Health. **S vs P.** Confidence in the in-game split: **high**.

**Contradiction — rest vs health.** BlueStacks says tent rest gradually restores Health, Life, and Fatigue but **not** Energy (https://www.bluestacks.com/blog/game-guides/durango-wild-lands/basics-survival-en.html). In-game #11 says Health **and** Energy slowly auto-recover; #10 says rest clears fatigue; #86 says rest helps but need not be long. BlueStacks is plausible for *tent sleep as a fatigue/health recovery action* but overstates a unique Health restore and understates Energy regen. **S vs P.** Confidence in “sleep is not the Energy refill”: **medium-high**.

### 1.2 Energy / Stamina (the food bar)

| Claim | Numbers / timers | Source | Conf. |
| --- | --- | --- | --- |
| Energy is the action/combat resource refilled by eating | n/a | Survival Guide #13, #17 **P** | high |
| Mood can change Energy consumption | n/a | Survival Guide #39 **P** | high |
| Invigorated: Energy consumption decreases after successive successful processing | n/a | https://durango.fandom.com/wiki/Status_Effects **NP**; ChapterCheats tooltip **NP** | high |
| Dejection: Energy consumption increases after failure | n/a | ChapterCheats status dump **NP** | high |
| “Full” after eating blocks further eating for a short window | Player reports **~10 seconds** | Reddit: https://www.reddit.com/r/DurangoWildLands/comments/bxroe4/questions_about_stamina/ **S** | medium |
| Early cooked foods ~15–40 Energy; later ~70–100; bread cited as 150 (about half a bar) | 15–40 / 70–100 / 150 | Same Reddit thread **S** | low–medium |
| Combat stamina regenerates quickly but is **capped** by how well the character is maintained; eat to restore the cap | n/a | Reddit 61-tips: https://www.reddit.com/r/DurangoWildLands/comments/bp60bc/61_tips_and_tricks_for_durango_wild_lands_english/ **S** | medium |
| Survival Belly Fat I–X: +10 max Energy per rank (ranks at 15/20/25/30/35/40/45/50/55/60) | +10 per rank, 10 ranks | NamuWiki Survival skill table **NP** | high |

English sources freely swap the words **stamina / energy / MP**. In-game KR HUD: 에너지 = the blue food-fed bar; 스태미나 = combat spend of that bar.

### 1.3 Hunger and thirst

**There is no separate starve-to-death hunger meter.** Hungry / Thirsty / Full / Quenched are **status effects that change fatigue rate**.

| Claim | Numbers / timers | Source | Conf. |
| --- | --- | --- | --- |
| Balancing Energy and satiety (포만감) is called out as important | n/a | Survival Guide #12 **P** | high |
| Quench Thirst and Full: lessens fatigue | n/a | ChapterCheats / Fandom status tooltips **NP** | high |
| Thirsty and Hungry: increases fatigue rate | n/a | Same **NP** | high |
| Fresh water (river/puddle, not sea): drink, wash, or fill a container | contextual actions | BlueStacks beginner guide https://www.bluestacks.com/blog/game-guides/durango-wild-lands/lands-first-impressions-beginners-guide-en.html **S**; NamuWiki island page **NP** | high |
| Canteen water helps endure heat | n/a | Survival Guide #148 **P** | high |
| Seawater is harmful and increases fatigue; river water is drinkable | n/a | ChapterCheats walkthrough **S**; NamuWiki island notes **NP** | medium-high |
| Early water containers: seashell ~2–3 fills then breaks; later earthenware pot holds 3 water per use | 2–3 / 3 | Reddit farming (2016 beta): https://www.reddit.com/r/DurangoWildLands/comments/5k8qbz/farming/ **S** | medium (patch-dependent) |

### 1.4 Fatigue (the real session limiter)

| Claim | Numbers / timers | Source | Conf. |
| --- | --- | --- | --- |
| Status effects can increase fatigue | n/a | Survival Guide #0 **P** | high |
| Rest clears fatigue | n/a | Survival Guide #10 **P** | high |
| Island vs character level gap affects fatigue (higher-level islands fatigue you faster) | n/a | Survival Guide #6 **P** | high |
| Same status effect can flip with climate | n/a | Survival Guide #7 **P** | high |
| First discovery of a crater rapidly reduces fatigue | n/a | Survival Guide #151 **P** | high |
| Old Survival Guide #20 (pre-personal-island patch): “raise Will if you want to manage fatigue” | n/a | NamuWiki notes footnote of old #20 **P** (superseded) | high that the old tip existed; **medium** that Will still maps to fatigue |
| Durango Survival I auto-learned at Lv.5; footnote: **base fatigue reduced** | Lv.5 auto | https://en.namu.wiki/w/야생의%20땅:%20듀랑고/생존 footnote [1] **NP** | medium |
| Exhausted / Danger: too tired to do anything | n/a | ChapterCheats “Danger” tooltip **NP**; BlueStacks **S** | high |
| Dirt / smell increases fatigue; wash in water fixes it and helps heat | n/a | MMORPG.com review (PR copy): https://www.mmorpg.com/columns/durango-wild-lands-review-big-things-do-come-in-small-packages-2000108364 **S**; status “Smelly” / “Wash” **NP** | high |
| Rain → cold → fatigue | n/a | MMORPG.com **S** | medium |
| Fatigue potions exist (crafted and RMT shop) | n/a | MMORPG.com **S** | medium |
| Riding an animal still lets you move when fatigue is full | n/a | NamuWiki main page tips **NP** | medium |

### 1.5 Temperature / climate

No numeric body-temperature bar is documented. Climate is modeled as **resistances + wet/dry statuses + clothing**.

| Claim | Numbers / timers | Source | Conf. |
| --- | --- | --- | --- |
| Wet: body temperature dropping because soaked. Fatigue is bearable in heat, overwhelming in cold. Trigger: standing in water **5 seconds** (Fandom) | 5 s | https://durango.fandom.com/wiki/Status_Effects **NP**; ChapterCheats **NP** | high (effect); medium (5 s) |
| Too much Dry: inverse of Wet | n/a | ChapterCheats **NP** | high |
| Survival resistances listed as stats: strong-wind, heat, blazing-sun, humidity, cold | n/a | NamuWiki 능력치 https://namu.wiki/w/야생의%20땅:%20듀랑고 **NP** | high |
| Character → Physical Resistance Levels tab shows per-climate body resistance; starts at character Lv.60 | Lv.60+ | Survival Guide #209–#211 **P** | high |
| Clothing is required in desert/snow or fatigue fills quickly; leaf clothes help heat; straw hat helps blazing sun; pocket wool / winter fur hat help cold / wind; waterproof boots help moisture; canteens help heat | n/a | NamuWiki Tailoring + Survival Guide #148 **NP/P** | high |
| Juice (e.g. cactus flesh) cited as reducing desert fatigue gain | n/a | NamuWiki tips **NP** | medium |
| Soup/boil cooking raises cold resistance; frying raises preservation and buff duration | n/a | GameDongA (hands-on): https://game.donga.com/89020/ **S** | medium |

### 1.6 Status effects (non-combat)

| Effect | Mechanical role | Source | Conf. |
| --- | --- | --- | --- |
| Well Rested | EXP up after long rest in tent or under bonfire | Fandom Status Effects **NP** | medium-high |
| Rest | Taking a break reduces Fatigue | Fandom / ChapterCheats **NP** | high |
| Robust | Food-type stat buffs | Fandom **NP** | medium |
| Invigorated / Dejection | Energy cost down / up | ChapterCheats **NP** | high |
| Wash | Clean + heat more bearable + less fatigue | ChapterCheats **NP** | high |
| Smelly | Heat more bearable, fatigue rate up | ChapterCheats **NP** | high |
| Very Dirty (매우 더러움) | Debuff list on NamuWiki status page | https://namu.wiki/w/야생의%20땅:%20듀랑고/상태 **NP** | medium (page fetch incomplete) |
| Resurrection aftereffects (부활 후유증) | Debuff after revive | NamuWiki status TOC **NP** | medium |
| Dizziness (어지러움) | Combat/status | NamuWiki status TOC **NP** | medium |
| Received Encouragement / Cannot Encourage | Social fatigue relief with cooldown | ChapterCheats **NP** | medium |
| Bad taste / fishy mouth from poor skewer (e.g. clams) | Fatigue faster | NamuWiki Cooking **NP** | medium |
| Poop-poison from gathering dung | High chance of fatigue-up debuff | NamuWiki Gathering Mud I notes **NP** | medium |
| Some island statuses flip buff↔debuff by location | n/a | NamuWiki status page intro **NP** | medium |

### 1.7 Disease

**No dedicated disease / infection / immunity system found** in Survival Guide, skill trees, or status catalogs. Closest analogues:

- Harmful ingestion: raw meat, seawater, poisonous cactus, dung-gathering poison, “bad taste” food.
- Cooking skill also unlocks herbal medicine (BlueStacks skills overview **S**).
- Pet “animal medicine” is a crafted sale item (GameDongA **S**).

Confidence that a full disease sim did **not** exist: **medium-high** (absence across primary tips). Do not invent a plague system.

### 1.8 Injury

**No limb/wound sim found** (no bleed-out, no broken-leg locomotion). Injury is:

| Claim | Numbers | Source | Conf. |
| --- | --- | --- | --- |
| Combat HP damage; 0 = death | n/a | ChapterCheats combat tips **NP** | high |
| Medicine / decoctions restore Health | n/a | Survival Guide #13, #123 **P** | high |
| CPR minigame: in-game CPR music tempo matches real recommended compression rate | n/a | Survival Guide #158 **P** | high that CPR exists as a revive interaction |
| Resurrection aftereffects debuff | n/a | NamuWiki status **NP** | medium |
| Other players can be paid to rescue a corpse | n/a | Survival Guide #49 **P** | high |

### 1.9 Death / respawn

| Claim | Numbers | Source | Conf. |
| --- | --- | --- | --- |
| On death: equipped-gear **durability decreases** and you **lose items** | n/a | Survival Guide #48 **P** | high |
| You may revive near a **discovered warp hole** | n/a | Survival Guide #46 **P** | high |
| You can post a rescue bounty | n/a | Survival Guide #49 **P** | high |
| Player report (global): backpack drops; **equipped items stay**; corpse loot is personal (others cannot steal) | n/a | Reddit 61-tips **S** | medium — **partially contradicts** #48’s “lose items” wording. Likely: unequipped bag drops as a recoverable corpse pile; equipped stays on body; durability still ticks. |
| Clan benefit: decreased death penalty | n/a | Reddit wiki https://redlib.vanillax.me/r/DurangoWildLands/wiki/gamefaq **S** | medium |
| Bug (unfixed to EOS): dead character could still “return to waypoint” | n/a | NamuWiki bugs **NP** | medium |

### 1.10 Inventory and weight

**No carry-weight / kg system found.** Capacity is **slot count**, raised by worn bags and by placed containers.

| Claim | Numbers | Source | Conf. |
| --- | --- | --- | --- |
| Equipping a bag increases max quantity you can hold | n/a | Survival Guide #159 **P** | high |
| Lock icon in bag prevents an item from being auto-used as a gathering tool | n/a | Survival Guide #128, #162 **P** | high |
| Long-press multi-select; filter by type/attribute | n/a | Survival Guide #129, #156, #219, #221 **P** | high |
| Discarded items despawn after some time | unspecified timer | Survival Guide #135 **P** | high (timer unknown) |
| Placed baskets as domain storage; BlueStacks: 3 leaves/stalks, **100 slots**, ~1 minute craft | 100 slots | BlueStacks survival basics **S** | medium |
| Item **level** of a basket raises storage vs a Lv.1 basket; items have a max level | n/a | Reddit 61-tips **S** | medium |
| Tutorial grants a free necklace and backpack expansion to equip at **Lv.10 then Lv.15** | Lv.10 / 15 | Reddit 61-tips **S** | medium |
| Tailoring bags: leaf bag Lv.5; cloth bag Lv.20; small bag Lv.25 (attachable); auxiliary bag Lv.35; back bag Lv.55 | levels above | NamuWiki Tailoring **NP** | high |
| Tamed animals can haul extra goods | n/a | Survival Guide #83 **P** | high |
| Cargo warphole (exit) capacity **80 compartments** | 80 | NamuWiki Construction **NP** | medium |
| Clan warehouse: 2000 slots in 200-slot sections | 2000 / 200 | Namu.moe buildings page **NP** | medium |

**Weight:** not attested. Confidence **high** that inventory is slot-based, not mass-based.

### 1.11 Durability

| Claim | Numbers / timers | Source | Conf. |
| --- | --- | --- | --- |
| Items and buildings have durability | n/a | Survival Guide #117 **P** | high |
| You cannot repair forever (max durability decays with repairs) | n/a | Survival Guide #137 **P** | high |
| Tools listed as “tool” in a recipe are not consumed; they lose durability instead | n/a | Survival Guide #62 **P** | high |
| Buildings at 0 durability turn black and become unusable | n/a | Survival Guide #152 **P** | high |
| Cosmetic/appearance equipment does not wear | n/a | Survival Guide #222 **P** | high |
| Two durability clocks: some items decay even while idle; others only on use. Weapons/tools/armor historically took **both** time and use | buildings: **1 durability per day** idle (no use-durability) | NamuWiki Items + Construction **NP** | medium-high |
| Personal island: building durability does not decay | n/a | Survival Guide #20 **P**; Nexon Second Wave press 2019-01-24 https://www.fomos.kr/esports/news_view?entry_id=69878 **P** | high |
| Death reduces equipped durability | n/a | Survival Guide #48 **P** | high |
| Using a combat weapon as a gathering tool burns durability faster | n/a | Survival Guide #153 **P** | high |
| Starting modern clothes can be repaired/modified — don’t throw them away | n/a | Survival Guide #81 **P** | high |
| Repair kits: cheap/practical/advanced for weapons-tools and separately for costumes | skill gates ~tailoring/weapon-tool trees | NamuWiki **NP** | high |

---

## 2. Character creation, appearance, “tribes/races”

**No fantasy races or ethnic tribes.** “Tribe” in KR sources is **clan** (부족), a player guild.

| Claim | Numbers | Source | Conf. |
| --- | --- | --- | --- |
| Pick 1 of **8 occupations × 2 genders = 16** named survivors; each gender has a unique backstory | 8 / 16 | NamuWiki 직업 https://namu.wiki/w/야생의%20땅:%20듀랑고 **NP**; BlueStacks classes https://www.bluestacks.com/blog/game-guides/durango-wild-lands/different-survivors-en.html **S** | high |
| Chosen occupation starts that skill line at **Lv.20** | 20 | NamuWiki; BlueStacks; Fandom Characters https://durango.fandom.com/wiki/Characters **NP/S** | high |
| Appearance (hair, facial hair, skin, height, clothing color) is customized **after the tutorial** | n/a | NamuWiki; Reddit wiki **S** | high |
| Paid Appearance Change Card can change appearance/gender later | n/a | Reddit: https://www.reddit.com/r/DurangoWildLands/comments/bpd39p/can_we_fix_our_characters_later/ **S** | medium |
| No occupation for Survival, Processing, Butchering, or Ranged | n/a | NamuWiki **NP** | high |
| Earth-life difference exists but “is not a big difference” | n/a | Survival Guide #32 **P** | high |
| Account: 2 character slots default; purchase up to 8; extra-slot sales stopped 2019-04-24 | 2→8 | NamuWiki **NP** | medium-high |

### Starting occupations (skill at 20)

| Occupation (EN / KR) | Skill | Source |
| --- | --- | --- |
| Soldier / 군인 | Melee | NamuWiki + BlueStacks |
| Job Seeker / 취업준비생 | Defense | same |
| Office Worker / 사무직 | Construction | same |
| Engineer / 기술자 | Weapon/Tools | same |
| Attendant / 승무원 | Tailoring (clothes) | same |
| Student / 학생 | Gathering | same |
| Homemaker / 주부 | Cooking | same |
| Farmer / 농부 | Farming | same |

**Contradiction — starting skill 20 vs 10.** Reddit wiki: “chosen specialty will start at level 10” (https://redlib.vanillax.me/r/DurangoWildLands/wiki/gamefaq). That is **wrong for live/global** or describes an old beta. Old Survival Guide #83 was “choose a job at level 10” and was later rewritten to animal taming. Prefer **Lv.20**. Confidence **high**.

---

## 3. Core stats (not the same as skill levels)

Eight base stats. They are **buffed by food, titles, and gear**, not permanently trained like skills.

| KR | EN (community) | Documented influences | Source | Conf. |
| --- | --- | --- | --- | --- |
| 힘 | STR | Attack, weapon craft, defense penetration | NamuWiki 능력치 **NP**; Reddit 2017 https://www.reddit.com/r/DurangoWildLands/comments/72k7mr/what_is_dexwilagi_and_cha/ **S** | high |
| 민첩 | AGI | Accuracy, evasion | NamuWiki **NP** | high |
| 맷집 | END / Toughness | Furniture craft, Health, construction, Energy | NamuWiki **NP**; Survival Guide #19 **P** | high |
| 매력 | CHA | Farming, tailoring, cooking, sewing | NamuWiki **NP** | high |
| 지능 | INT | Furniture, construction, craft, metal process, dismantle, plant gather, cooking, mining | NamuWiki **NP** | medium (Namu-only mapping) |
| 솜씨 | DEX | Weapon craft, plant gather, tailoring, sewing, crit, mining | NamuWiki **NP** | high |
| 의지 | WIL | Craft, metal process, farming, butchering, Energy; old tip linked Will to fatigue | NamuWiki **NP**; old Survival Guide #20 **P** | medium-high |
| 눈치 | PER / Sense | Butchering, dismantle, stealth; cooking spices: salt/sugar raise 눈치 | NamuWiki **NP**; GameDongA **S** | medium-high |

Derived stat groups (NamuWiki): tame cap, stealth, max Health, max Energy, capture ability; gather/butcher/dismantle/mine; craft/metal/sew; combat offense/defense; production abilities; climate resistances.

**Contradiction.** 2017 Reddit mapper put PER on leather/meat/bone gather and WIL on max Energy; NamuWiki live mapping puts 눈치 on butcher/dismantle/stealth and 의지 on Energy/farming/butcher. Treat NamuWiki as later. **S vs NP.**

Career titles example: Basic Hunting Tactics → STR +5, END +5, Max Health +40 (TouchTapPlay careers **S**). Confidence **medium**.

---

## 4. Progression: character level vs skills vs careers vs research

Durango is **both** a character-level MMO **and** a skill-point specialization game. It is **not** a pure skill-up-by-use sandbox like the original *RuneScape* with no cap, and **not** a single-class level-only MMO.

### 4.1 Character level

| Claim | Numbers | Source | Conf. |
| --- | --- | --- | --- |
| Character level cap **60** | 60 | Google Play achievement “정복하다 = reach Lv.60”; NamuWiki **P/NP** | high |
| Level-up grants T-stones; also granted for discovering warp holes | n/a | Survival Guide #80 **P** | high |
| Skill **line** level cannot exceed character level | n/a | NamuWiki Skills intro **NP**; Survival Guide #41, #64, #126 **P** | high |
| Other level tracks: Tamed Island Pioneer, Physical Resistance (60+), Clan | n/a | Archive wiki TOC https://durango-archive.fandom.com/wiki/Durango_Wiki **NP**; Survival Guide #209–#211 **P** | high |
| Wearing gear above character level **lowers its performance by the difference** | n/a | Survival Guide #140 **P** | high |

### 4.2 Skill lines (12)

Survival, Gathering, Butchering (Slaughter), Processing, Melee, Ranged, Defense, Weapon/Tools, Tailoring, Construction, Cooking, Farming.

Some skills unlock by **doing the action** (proficiency); unlocking a **recipe/technique** costs **SP**. Survival is unique: it **tracks character level automatically** and needs **no research**.

| Claim | Numbers / timers | Source | Conf. |
| --- | --- | --- | --- |
| SP is spent to learn skills; arrow-gated trees | n/a | Survival Guide #73, #31 **P** | high |
| At cap 60: **827 SP** from levels; career guides +3 each; milestones ~+70 → **~900 SP** | 827 / ~900 | NamuWiki Skills intro **NP** | medium-high |
| Maxing Survival+Gathering+Construction+Processing alone is **829 SP** vs 827 from levels — you cannot max everything | 829 vs 827 | NamuWiki footnote [1] **NP** | medium-high |
| Learned skills can be unlearned **10 times/day** for **30 warp gems** each; cash **skill reset ticket = 900 warp gems** | 10/day, 30 gems, 900 gems | NamuWiki Skills **NP**; Survival Guide #178 **P** | high |
| After a skill line exceeds **20**, **research** is required every 5 levels to keep leveling | Research times: 20→21 **20 min**; 25→26 **40 min**; 30→31 **1 h**; 35→36 **2 h**; 40→41 **4 h**; 45→46 **12 h**; 50→51 **1 day**; 55→56 **2 days**; 59→60 **3 days** | NamuWiki Skills intro **NP** | high (widely repeated; treat as live-era values) |
| Doing the related action raises that line’s proficiency | n/a | Survival Guide #126 **P** | high |
| Skill ranks change the power of a technique | n/a | Survival Guide #91 **P** | high |
| One character cannot learn everything; specialize or trade | n/a | Survival Guide #179, #180 **P** | high |

### 4.3 Career guides / titles

| Claim | Numbers | Source | Conf. |
| --- | --- | --- | --- |
| Career Guide under Skills; one career at a time; completion grants a **title** with stat bonuses | n/a | MMORPG.com review **S**; TouchTapPlay https://www.touchtapplay.com/durango-wild-lands-careers-guide/ **S**; Survival Guide #16, #96, #120 **P** | high |
| Titles are equipped on the Character screen | n/a | TouchTapPlay **S** | medium |

### 4.4 Knowledge / recipes / discovery

| Claim | Numbers | Source | Conf. |
| --- | --- | --- | --- |
| Recipes are **attribute-based**, not fixed item IDs. Example: improvised 1H axe handle = bone **or** branch; lashing = reeds **or** roots | n/a | BlueStacks beginner **S**; Survival Guide #66, #70 **P** | high |
| Higher-level materials → higher-level output | n/a | Survival Guide #63 **P** | high |
| Rarer materials → rarer effects on the result | n/a | Survival Guide #138 **P** | high |
| Each item has a **processing count**; bleaching spends 1 count, dyeing does not | n/a | Survival Guide #115, #116 **P** | high |
| Finished gear inherits **only main-material attributes**; majority of main-material pieces sets the pattern | n/a | Survival Guide #160, #161, #163 **P** | high |
| Hidden recipes are listed under Character → **Crafting Power (제작력)** | n/a | Survival Guide #202, #203 **P** | high |
| Crafting Power also comes from titles, practice skills, labs | n/a | Survival Guide #205 **P** | high |
| Preview shows expected result **and great-success rate**; great success raises related attribute levels | n/a | Survival Guide #204, #223 **P** | high |
| Rare attributes must be **expressed** before they do anything; one rare-attribute ingredient is enough | n/a | Survival Guide #215, #224, #226 **P** | high |
| Construction **blueprints** let you place a building you have not learned, if you bring materials | n/a | Survival Guide #21 **P** | high |
| Farming encyclopedia only records crops **you** planted and harvested | n/a | Survival Guide #213 **P** | high |
| Encyclopedia stores Durango Notes / Survival Guide after first view | 243 notes | NamuWiki 메모 intro **NP** | high |

---

## 5. Clothing, armor, equipment slots

Durango uses **clothing as armor** (plus climate), not plate-mail classes.

Documented wearable types (from Tailoring tree + player UI talk):

| Slot / type | Examples | Source | Conf. |
| --- | --- | --- | --- |
| Outfit / body | Leaf, straw, leather clothes; bark armor; hunting / settler / exploration outfit lines | NamuWiki Tailoring **NP**; Reddit armor thread https://www.reddit.com/r/DurangoWildLands/comments/bv3qfk/armor/ **S** | high |
| Head | Straw hat, pocket wool hat, winter fur hat, bark mask | NamuWiki **NP** | high |
| Feet | Footwraps, leather boots, waterproof boots, bone boots | NamuWiki **NP** | high |
| Hands | Half gloves, finger gloves, winter fur gloves, bone gloves | NamuWiki **NP** | high |
| Bag | Leaf / cloth / small / auxiliary / back bags | NamuWiki; Survival Guide #159 **P** | high |
| Canteen | Simple / horn / cloth canteen (heat) | NamuWiki; Survival Guide #148 **P** | high |
| Jewelry | Flower, feather, pearl, gem necklaces | NamuWiki jewelry **NP** | high |
| Weapon | Must be **equipped**; tools in bag auto-select | Survival Guide #93, #142; Survival Memo #1, #6 **P** | high |
| Appearance overlay | Does not lose durability | Survival Guide #222 **P** | high |

Quick swap: clothing icon, lower-right (Survival Guide #98 **P**).

Outfit branches (player UI, not fully transcribed): **Hunting Gear** (combat), **Settlers Gear** (crafting), **Exploration Gear** (gather/explore). Confidence **medium**.

---

## 6. Tools and gathering

### 6.1 Tool use

| Claim | Numbers | Source | Conf. |
| --- | --- | --- | --- |
| Tools in the bag are auto-chosen for the node; you do not equip an axe to chop | n/a | BlueStacks beginner **S**; Survival Memo #6 **P** | high |
| Axe → trees; knife → thickets; pickaxe → rock; shovel → soil/mud; hoe → till; harpoon → fish | n/a | BlueStacks survival basics **S**; NamuWiki Weapon/Tools **NP** | high |
| Failed actions: check tool and related skill level | n/a | Survival Guide #54 **P** | high |
| Higher node level needs both higher **tool level** and matching **skill** | n/a | Survival Guide #65, #85 **P** | high |
| Work time and success rate depend on stats + tool/station level | n/a | Survival Guide #166, #167 **P** | high |
| Gathering skill = max material level you can extract; underleveled gathering **downranks** loot (Lv.55 island + Gathering 30 → Lv.30 mats) | n/a | NamuWiki Gathering **NP** | high |
| Long-press queues full remaining gathers; multi-tap queues N times | n/a | Survival Guide #99, #130 **P** | high |
| Some nodes vanish when a key product is exhausted (tree falls when logs are gone); others regenerate over time; crater-adjacent nodes regen fast | n/a | Survival Guide #68, #69, #79 **P** | high |
| Personal island: removed naturals **do not** return | n/a | Survival Guide #193 **P** | high |
| Tamed/main-island resources: 61-tips says they **do not regenerate**; Ancora tutorial island **does** infinite-regen at fixed counts | n/a | Reddit 61-tips **S** vs NamuWiki tips **NP** | **contradiction** — depends on island type. Ancora = regen; claimed tamed-island depletion = player report. Confidence **medium**. |

### 6.2 Gathering skill tree (selected)

Source for all rows: https://en.namu.wiki/w/야생의%20땅:%20듀랑고/스킬 **NP**. Confidence **high** as UI transcription.

**Minerals / soil**

| Technique | Skill lv | SP | Notes |
| --- | --- | --- | --- |
| Mud I (dung) | 1 | auto | Dung = dirt + fertilizer; dung-poison fatigue debuff |
| Mud II (mud pits) | 10 | 2 | Also trains Farming |
| Pebbles | 1 | auto | |
| Rock | 5 | (low) | |
| Obsidian | 35 | 4 | |
| Marble | 40 | | |
| Alum | 45 | 5 | Dyeing |
| Metal I–IV: tin 40, zinc 45, copper 50, iron 60 | 40–60 | 4–6 | |
| Precious: silver 50, gold 60 | 50/60 | 5/6 | |
| Gems: pearl 40, ruby 50, sapphire 55, emerald 60 | 40–60 | 4–6 | |

**Trees**

| Technique | Skill lv | Notes |
| --- | --- | --- |
| Log I thin | 1 auto | |
| Log II hardwood | 25, 3 SP | |
| Log III conifer | 40, 4 SP | |
| Log IV advanced conifer | 60, 6 SP | |
| Sap I / sticky II | 30 / 45 | |
| Leaf, branch, bush | 1 auto | Long twig 45 |

**Plants**

| Technique | Skill lv | Notes |
| --- | --- | --- |
| Fruit I / II | 1 / 25 | |
| Fiber flax / cotton | 20 / 30 | Tailoring |
| Stem | 1 auto | |
| Insects: larvae, bees; swamp snails/aphids/termites | various | |
| Wild seeds: onion, flax, rose, mushroom, sugarcane, cotton, lavender, tea/tulip, fig, agave, banana, pepper, coffee | gated | |

Practice passives: Axing I–V logging +2; Pickaxing mining +2; Shoveling mud +2; Stalk Cutting plant +2 (Fandom Gather page **NP**).

### 6.3 Animals / butchering

| Claim | Numbers | Source | Conf. |
| --- | --- | --- | --- |
| Kill then harvest meat, hide, bone, fat, guts, specials, sinew | Meat I auto; fat 40; guts; specials 50; sinew 55 | NamuWiki Slaughter **NP** | high |
| Corpses can be stolen by wildlife if you walk away | n/a | MMORPG.com **S** | medium |
| Plants can yield multiple products (e.g. raspberry bush: leaves **or** berries **or** branches) | n/a | MMORPG.com **S** | high |

### 6.4 Fishing

| Claim | Numbers | Source | Conf. |
| --- | --- | --- | --- |
| Wooden / bone / metal **harpoon** (Weapon/Tools) used to catch fish | wood early; metal later | NamuWiki Weapon/Tools **NP** | high |
| Placed **fish trap** (Construction / installation) | n/a | NamuWiki; LevelWinner **NP/S** | high |
| Trap loot: fish, reed, leaf, or tin; take 1 → respawns; take 2 → trap gone | 1 vs 2 | Reddit: https://www.reddit.com/r/DurangoWildLands/comments/coahrn/do_fish_spawns_on_tame_island_respawn/ **S** | medium |
| Village-island fish ~Lv.10; city-island ~Lv.40 | 10 / 40 | NamuWiki Island **NP** | medium |
| Harpooning fish can also yield plastic bags (water container) | n/a | NamuWiki Island footnote **NP**; Reddit farming **S** | medium |
| Clams / coconut crabs train butchering without a full hunt | n/a | NamuWiki Slaughter + tips **NP** | medium |

No rod-and-reel minigame is documented. Fishing is harpoon + traps + coastal gather.

---

## 7. Crafting stations, quality, rarity, blueprints

### 7.1 How crafting is invoked

Three entry points (LevelWinner **S**): Menu → Craft/Build; interact with a **Workbench**; interact with a **Bonfire**. Attribute recipes (BlueStacks **S**).

### 7.2 Stations (Construction skill)

Source: NamuWiki Construction **NP**. Confidence **high** for existence/level gates; English names are translations.

| Station | Skill lv | Role |
| --- | --- | --- |
| Bonfire | 1 auto | Rest + simple cooking |
| Indoor brazier | 45 | Indoor rest |
| Furnace / oven | 15 | Cooking |
| Stove | 40 | More dishes |
| Kitchen | 60 | Full cooking |
| Basic kiln | 35 | Smelt / process ore |
| Advanced kiln | 55 | High smelt / metal |
| Small loom | 15 | Yarn / cloth |
| Large loom | 40 | Advanced cloth |
| Dye crafting table | 15 | Make dye |
| Advanced dye table | 45 | More dye at once |
| Dyeing bench | 15 | Dye gear |
| Simple well | 25 | Water |
| Well | 45 | Water |
| Fertilizer workbench | Farming 15 | Fertilizer |
| Makeshift / later workbenches | Construction line (not fully parsed in dump) | General craft; camp workbenches are public (Survival Guide #145 **P**) |
| Medicine table | Cooking (GameDongA **S**) | Pills / animal medicine |

**Camp vs domain:** camp workbenches are public; commission-craft outside your domain can be stolen (Survival Guide #145, #164 **P**). Canceling a queued craft **destroys** the item (Survival Guide #220 **P**).

### 7.3 Quality / rarity (not WoW-style colored drops)

| Lever | Effect | Source | Conf. |
| --- | --- | --- | --- |
| Material **level** | Output level | Survival Guide #63 **P** | high |
| Material **rare attributes** | Rare effects; must be expressed | #138, #215, #224 **P** | high |
| **Processing count** (hammer ×N on the item card) | More processes before the final cook/craft → stronger food; Reddit: meat ×1–×3 from animals | NamuWiki Cooking; Reddit skill guide https://www.reddit.com/r/DurangoWildLands/comments/bn0shk/character_and_skill_leveling_guide/ **NP/S** | high |
| **Great success** | Raises related attribute level | Survival Guide #223 **P** | high |
| **Modification slots** on finished gear (not processing count) | Customize stats | Survival Guide #143, #200, #201 **P** | high |
| Weapon **blade shape** / multi-part weapons | Changes weapon type | Survival Guide #108 **P** | high |
| Undercooked food can be recooked | n/a | Survival Guide #56 **P** | high |
| Burnt stone-grill: huge Energy penalty | n/a | NamuWiki Cooking **NP** | medium |
| Skewer max level later capped at **19** (post-launch nerf vs beta) | 19 | NamuWiki Cooking **NP** | medium |
| Building level clamped by recipe max **and** Construction skill | n/a | Survival Guide #191 **P** | high |
| Work tools (work knife/axe/hammer) are easier to craft than combat equivalents of the same level | n/a | Survival Guide #165 **P** | high |

Blueprints: Survival Guide #21 **P**. Hidden recipes: Crafting Power UI **P**.

---

## 8. Cooking

Flavor text (in-game): “Cooking is taming the raw…” (NamuWiki Cooking **NP**).

| Claim | Numbers | Source | Conf. |
| --- | --- | --- | --- |
| Skewer: food + stick + nearby fire; shortest cook; emergency recipe; auto at Cooking 1 | 1× cook = underdone; 2× = well-done | NamuWiki Cooking **NP**; Survival Guide #84 (skewer can also be a weapon) **P** | high |
| More processing before the final cook → better effect; “food that took more hands is better” | 3+ processes cited | Survival Guide #214 **P**; NamuWiki **NP** | high |
| Methods (skill-gated): grill, boil, steam, stir-fry, fry, stew, rice, broth, rice cake, noodles, roast, seasoning variants, preservation cooking | Grill I at 1; boil 15; steam ~25; stir-fry 40; noodles 60 | NamuWiki tables **NP**; GameDongA **S** | high |
| Meat/fish → STR; fruit → charm; veg → AGI; cheese → 눈치 | n/a | GameDongA **S** | medium |
| Fruit-specific craft buffs: tomato cooking, pepper weapon-craft, grape sewing, pumpkin farming, banana leather process, fig armor | n/a | GameDongA **S** | medium |
| Spices: salt (STR, 눈치), sugar (솜씨, 눈치), herbs (STR, WIL, AGI) | n/a | GameDongA **S** | medium |
| Boil can **raise ingredient level toward water level** (e.g. Lv.30 meat in Lv.60 water → Lv.45) — late-game exploit/feature | example 30/60→45 | NamuWiki Cooking **NP** | medium |
| Boil can make some leather/wood-attribute items edible early; later blocked | n/a | NamuWiki **NP** | low-medium |
| Meatballs: mortar; stone-grill at 20; steam 25; squeeze oil + frying ~40 | 5 min cited for some mass cook | NamuWiki; Reddit skill guide **NP/S** | medium |
| Cooking also crafts dye (via medicine) and herbal/animal medicine | n/a | Survival Guide #114 **P**; BlueStacks skills **S** | high |
| Homemaker starts Cooking 20; cooking SP budget described as ~300 — easy to hybrid | ~300 SP | GameDongA **S** | low-medium |
| Raw meat/seawater harmful | n/a | ChapterCheats **S** | medium-high |

Stations: bonfire → furnace 15 → stove 40 → kitchen 60; utensils (pot, mortar, stone plate, pan, grill, cutting board) from Weapon/Tools.

---

## 9. Farming, ranching, irrigation

### 9.1 Fields and crops

| Claim | Numbers | Source | Conf. |
| --- | --- | --- | --- |
| Till with mud + hoe; plant seeds; water + fertilize | n/a | NamuWiki Farming **NP** | high |
| **Water** → success / survival chance. **Fertilizer** → harvest **count**, not survival | n/a | Survival Guide #109 **P**; NamuWiki Farming **NP**; Reddit https://www.reddit.com/r/DurangoWildLands/comments/btk0x2/farming_useful_or_not/ **S** | high |
| Excess fertilizer carries to the next planting | n/a | NamuWiki Farming **NP** | medium |
| Rotting fertilizer on a ripening table raises fertility | n/a | Survival Guide #111 **P**; Fertilizer Making II at Farming 30 **NP** | high |
| Some seeds are cultivable, some are not | n/a | Survival Guide #42 **P** | high |
| Seeds from delivery crates or wild gather | n/a | Survival Guide #110 **P** | high |
| Don’t plant small-field crops in large fields (waste) | n/a | Survival Guide #112 **P** | high |
| Farming ability raises harvest **speed and success** | n/a | Survival Guide #216 **P** | high |
| Skilled farmers roll rare-attribute crops more often; check farming encyclopedia | n/a | Survival Guide #218 **P** | high |
| Terrain: gravel/sand/seaside fail often; grassland recommended | n/a | NamuWiki Farming; Reddit **NP/S** | medium |
| WIL food buff cited as helping crop survival | n/a | Reddit farming useful? **S** | low-medium |
| Output **level** clamped by **farming skill**, not field level | n/a | NamuWiki Farming **NP** | medium |
| Small field: Farming 1, 1 SP. Large field: Farming 25, 3 SP | 1 / 25 | NamuWiki **NP** | high |
| Bone hoe for large fields; metal hoe text says small fields (translation may be messy) | n/a | NamuWiki Weapon/Tools **NP** | medium |

**Crop table** (NamuWiki Farming **NP**; fertilizer/water are “cost” units, harvest is at full fertilizer). Confidence **medium-high**.

| Crop | Skill lv | Field | Fertilizer | Water | Typical yield (full fert.) |
| --- | --- | --- | --- | --- | --- |
| Corn | 1 auto | small | 10 | 1 | 7 fruit+seed (5–6 fruit, 1–2 seed) |
| Onion | 10, 2 SP | small | (higher than corn; exact not in dump) | more than corn | fertilizer + animal feed |
| Potato | 15, 2 SP | small | 30 | 2 | 10 |
| Pumpkin | 20 | small | | | |
| Wheat | 30, 4 SP | small | 50 | 3 | 15 fruit/stem/seed |
| Flax | 25, 3 SP | small | | | tailoring fiber |
| Rice | 40 | small | 70 | 4 | 16–17 |
| Sugarcane | 40, 4 SP | large | | | |
| Cotton | 45 | small | | | |
| Tomato | 45 | small | | | |
| Tea | 50 | large | | | |
| Grape | 50 | (fruit) | | | |
| Coffee | 60 | large | | | |
| Bell pepper / chili | 60 | small | | | |
| Flowers/trees | various 20–60 | small or large | | | Lincoln rose, damask, ginkgo, oleander, sunflower, maple, plum, wild rose, mushroom, lavender, tulip, poppy, desert agave, banana/fig (gather+farm) |

**Contradiction — water level vs water amount.** Nexon blog commenter (community manager thread): “the **level of water** does not influence crop chance, quality or yield” (https://www.reddit.com/r/DurangoWildLands/comments/c323fo/nexon_blog_farming_guide/). NamuWiki says water (quantity) raises success probability. These can both be true: **amount matters, source level does not**. Official farming article URL is dead (`nexonm.com/durango-wild-lands-farming/`). Confidence **medium**.

Corn is the only crop that **cannot** be animal feed or fertilizer (2016 Reddit farming **S**). Confidence **medium** (may have been patched).

### 9.2 Irrigation, wells, sprinklers

| Claim | Numbers | Source | Conf. |
| --- | --- | --- | --- |
| Manual water from river/lake via container; sea water not used for farming | n/a | Reddit farming **S**; NamuWiki Island (fresh water) **NP** | high |
| Simple well Construction 25; Well Construction 45 | 25 / 45 | NamuWiki Construction **NP** | high |
| **Sprinklers** exist as a farming convenience and are expensive | n/a | BlueStacks skills (“fertilizers and sprinklers”); Reddit “sprinklers help a lot” **S** | medium |
| Sprinkler **does not appear** in the NamuWiki Farming facilities table (fields + fertilizer only) | n/a | NamuWiki Farming 13.1 **NP** | — possible construction furniture, later patch, or translation miss. Confidence **low** on exact gate. |
| No pipe-network irrigation sim documented | n/a | absence | medium-high |

### 9.3 Ranching / taming

| Claim | Numbers / timers | Source | Conf. |
| --- | --- | --- | --- |
| Taming requires Survival line **Lv.15** | 15 | Survival Guide #44 **P** | high |
| Capture tool must be **in the bag**; stun (blunt helps) then net | n/a | Survival Guide #94, #225 **P**; old tip: blunt to groggy **P** | high |
| Place in a taming pen; first Zebraceratops tame **1 hour** | 1 h | ChapterCheats taming guide **S** | medium |
| Capture ladder is **포획기술 I–V** (Survival 15/25/35/45/55, 2/3/4/5/6 SP), two species each, **20 SP total** | see bestiary §1.1 | NamuWiki 생존 via namu.moe **NP** | high |
| **Protoceratops is tier III (Survival 35)**, not a starter species | 35 | Same **NP** | high |
| Animal elixir costs **8,000–10,000 T-stones**; cash pets age at **60 days** vs 30 | 8–10k / 60 d | NamuWiki 동물 via namu.moe **NP** | medium |
| Pets roll a **milestone buff at pet level 20/40/60** (Attack / Speed / Bag), random, **paid reroll** | 20/40/60 | TouchTapPlay **S** | medium |
| **Tamed stats were gutted vs wild**: Centrosaurus 5,000→2,300, Ankylosaurus ~8,000→2,963, Tarbosaurus 60,000+→2,500 | see bestiary §2 | NamuWiki 동물 **NP** | medium-high |
| Manage tamed animals in Menu → Animals; must keep feeding | n/a | Survival Guide #95, #181, #189 **P** | high |
| Default **3** bonded animals; unlearning the skill **keeps** already bonded animals | 3→7 | NamuWiki Survival **NP** | high |
| Cap skill is **동물 관리 I–IV** at Survival 35/45/55/60, **+1 each** → cap **7**. Resolves the long-standing "6 vs 7" ambiguity | 4 ranks | NamuWiki 생존 via namu.moe **NP** | medium-high |
| Barns: simple 15, small 25, medium 45 (6×6 at 60 for max dung/milk) | 15/25/45; 6×6 | NamuWiki Construction **NP** | high |
| Barns produce dung and milk; occupied houses/barns cannot be packed | n/a | NamuWiki Island footnotes **NP** | medium |
| Aged pets cannot fight until given animal elixir | n/a | Survival Guide #190 **P** | high |
| Mounts ignore strong current when crossing rivers | n/a | NamuWiki tips **NP** | medium |
| Wrong pet feed (character eating pet feed) causes self-loathing and **massive fatigue** | n/a | NamuWiki tips **NP** | low-medium |

---

## 10. Processing (feeds every other craft)

In-game: convert raw into useful. Proficiency-to-level is **half** that of other lines (levels faster). NamuWiki Processing **NP**.

Core early recipes: rope (1 auto), nails (5), charcoal (10), leather dry/tan, trim, surface process, smelt. Charcoal is the portable fire input.

---

## 11. Contradictions index

1. **Hunger/thirst as survival fail states** — English marketing/guides talk like a survival game; in-game they only modulate **fatigue**. Food fills **Energy**, not HP. **P wins.**
2. **Stamina vs Energy vs Fatigue** — English guides mash three bars into two. HUD is Health / Energy / Fatigue; combat aliases Life / Stamina.
3. **Food restores health** (LevelWinner, some DongA wording) vs Survival Guide #13. **P wins.**
4. **Sleep restores Energy** — BlueStacks says no; in-game #11 says slow auto-recovery of Energy. Sleep is primarily **fatigue** (and possibly Health). Unresolved numeric rates.
5. **Starting occupation skill 10 vs 20** — Reddit wiki vs NamuWiki/BlueStacks/Fandom. **20 wins.** Old Survival Guide #83 confused this.
6. **Death loot** — #48 “lose items” vs 61-tips “only unequipped bag drops, unstealable.” Likely bag-drop + equipped-stay + durability hit. Treat as **medium** until a screenshot of the death UI is recovered.
7. **Tamed-island resource regen** — 61-tips no regen vs general #69 regen vs Ancora infinite vs personal island never returns. **Island-type dependent.**
8. **Farming water** — quantity/success vs water **item level** irrelevant. Compatible if split that way.
9. **Sprinklers** — player/BlueStacks yes; Farming skill table dump no row. Existence **medium**; recipe level **low**.
10. **Core stat mappings** — 2017 Reddit vs later NamuWiki. Use NamuWiki.
11. **Cooking reduces fatigue directly** (DongA) vs Full status reducing fatigue + Energy refill. DongA collapsed two systems.
12. **Will vs max Energy vs max Fatigue** — Belly Fat skill = max Energy; old tip = Will for fatigue; 2017 Reddit WIL = max fatigue. Do not equate Energy cap with Fatigue cap.
13. **Service length** — some community memory of a long KR twilight; press + NamuWiki agree **EOS 2019-12-18** worldwide, with an offline island client after.

---

## 12. Gaps (not found in primary sources)

| Topic | Status |
| --- | --- |
| Exact Health/Energy numeric regen per minute | unknown |
| Exact fatigue gain per second by island Δlevel | unknown |
| Full status duration (10 s is Reddit only) | unconfirmed |
| Inventory base slot count before bags | unknown (100 is cited for **baskets**, not the worn bag) |
| Weight / encumbrance | **no evidence it exists** |
| Disease sim | **no evidence** |
| Limb injury | **no evidence** |
| Numeric temperature value | **no evidence**; resistances + wet/dry |
| Official English names for every station | translations vary (furnace/oven/stove) |
| Full sprinkler recipe | missing |
| Live Nexon farming blog body | URL dead; Wayback fetch timed out this session |
| ~~Fandom Status Effects full table~~ | **CLOSED** — full table with durations and percentages transcribed in [bestiary §4](./durango-wild-lands-bestiary-combat.md#4-status-effects--the-full-table) via the namu.moe mirror |
| ~~Which capture skill unlocks which species~~ | **CLOSED** — bestiary §1.1 |
| ~~Bonded-animal cap 6 vs 7~~ | **CLOSED** — four +1 ranks, cap 7, bestiary §1.2 |
| ~~Complete animal roster~~ | **CLOSED** — ~90 entries, bestiary §3 |
| Combat bleed / poison DoT | **does not exist.** No 출혈, no combat 중독 in the status table. Every DoT is environmental or ingested. Bestiary §4.4 |
| Exact SP total per tree except the 118/227/331/153 footnote | partial |

---

## 13. Source list (priority order)

**Primary / official**

- In-game Survival Guide + Durango Notes (verbatim KR): https://namu.wiki/w/야생의%20땅:%20듀랑고/메모
- Nexon / What! Studio US launch: https://www.businesswire.com/news/home/20190515005178/en/The-Age-of-Dinosaurs-is-Here-in-Durango-Wild-Lands
- EOS letter (quoted): https://mmos.com/news/nexons-mobile-sandbox-durango-wild-lands-will-be-shutting-down-later-this-year
- KR EOS: https://www.etoday.co.kr/news/view/1810126
- Personal-island / no building decay (Nexon Second Wave): https://www.fomos.kr/esports/news_view?entry_id=69878
- Store blurb: https://www.mobygames.com/game/129753/durango-wild-lands/
- Official Facebook (ops dead): https://www.facebook.com/playdurango/
- Dead official site: http://durango.nexon.com
- Dead official farming guide: https://www.nexonm.com/durango-wild-lands-farming/

**Near-primary (in-game UI transcription)**

- Skills: https://namu.wiki/w/야생의%20땅:%20듀랑고/스킬 and EN https://en.namu.wiki/w/야생의%20땅:%20듀랑고/스킬
- Survival tree: https://en.namu.wiki/w/야생의%20땅:%20듀랑고/생존
- Status: https://namu.wiki/w/야생의%20땅:%20듀랑고/상태
- Items: https://namu.wiki/w/야생의%20땅:%20듀랑고/아이템
- Islands: https://en.namu.wiki/w/야생의%20땅:%20듀랑고/섬
- Main: https://namu.wiki/w/야생의%20땅:%20듀랑고
- Archive wiki home: https://durango-archive.fandom.com/wiki/Durango_Wiki
- Status / Gather / Equipment stubs: https://durango.fandom.com/wiki/Status_Effects https://durango.fandom.com/wiki/Gather https://durango.fandom.com/wiki/Equipment https://durango.fandom.com/wiki/Characters
- Status tooltips dump: https://www.chaptercheats.com/cheats/android/375405/durango-wild-lands-cheat-codes

**Secondary (use only where tagged)**

- https://www.bluestacks.com/blog/game-guides/durango-wild-lands/basics-survival-en.html
- https://www.bluestacks.com/blog/game-guides/durango-wild-lands/different-survivors-en.html
- https://www.bluestacks.com/blog/game-guides/durango-wild-lands/brief-overview-skills-en.html
- https://www.bluestacks.com/blog/game-guides/durango-wild-lands/lands-first-impressions-beginners-guide-en.html
- https://game.donga.com/89020/
- https://www.reddit.com/r/DurangoWildLands/comments/bp60bc/61_tips_and_tricks_for_durango_wild_lands_english/
- https://www.reddit.com/r/DurangoWildLands/comments/bn0shk/character_and_skill_leveling_guide/
- https://www.reddit.com/r/DurangoWildLands/comments/c323fo/nexon_blog_farming_guide/
- https://www.touchtapplay.com/durango-wild-lands-careers-guide/

---

## 14. Design takeaways (facts only, not a PRD)

If this research is used as a reference implementation:

- Three live resources: **Health** (medicine), **Energy** (food, combat/actions), **Fatigue** (rest, climate, hygiene, island Δlevel). Hungry/thirsty are fatigue modifiers, not kill conditions.
- Progression is **character level 1–60** granting SP, plus **12 skill lines** that cannot exceed character level, plus **research time gates** after 20, plus **careers/titles**.
- Crafting is **attribute + processing-count + station level + great-success**, not a fixed ID recipe list.
- Gathering auto-picks bag tools; weapons must be equipped.
- Inventory is **slots + bags + boxes**, not weight.
- Clothing is armor + climate kit; no separate heavy-armor class.
- Farming: water = live/die chance; fertilizer = count; wells exist; sprinklers likely exist but are poorly documented.
- No races. 16 named modern humans. Clans are social, not biological.