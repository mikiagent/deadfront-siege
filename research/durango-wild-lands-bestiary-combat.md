# Durango: Wild Lands — Bestiary, Capture/Taming Tables, Status Effects

**Companion to** [`durango-wild-lands-systems.md`](./durango-wild-lands-systems.md) and [`durango-wild-lands-world-environment.md`](./durango-wild-lands-world-environment.md). Those two cover survival, progression, crafting, world and travel. This one covers the part neither reached: **the animal roster, the capture/taming skill tables, tamed-pet stats, and the full status-effect table with numbers.**

**This file is research notes, not a PRD.** Same tagging convention as the sibling files.

| Tag | Meaning |
| --- | --- |
| **P** | Primary: in-game Survival Guide / Durango Notes, official press |
| **NP** | Near-primary: community transcription of in-game UI (NamuWiki animal / status / skill tables) |
| **S** | Secondary: player guides, journalism, Reddit |

Confidence: **high** = multiple independent sources or verbatim in-game text; **medium** = one strong transcription; **low** = single secondary source or patch-dependent.

**Source note.** `en.namu.wiki` returns 403 to automated fetches, which is why the sibling docs have gaps here. The **`namu.moe` mirror serves the same pages and does respond.** Every **NP** row below came through that mirror. Use it for any further NamuWiki pull:

- Animals: `https://namu.moe/w/야생의 땅: 듀랑고/동물`
- Status: `https://namu.moe/w/야생의 땅: 듀랑고/상태`
- Survival tree: `https://namu.moe/w/야생의 땅: 듀랑고/생존`

Korean names are kept verbatim because the English community names are inconsistent and several species are original to the game with no real-world referent.

---

## 1. Capture and taming skill tables

This corrects the sibling PRD, which had the first capture tier wrong.

### 1.1 Capture techniques (포획기술), Survival tree

| Skill | Survival lv | SP | Species unlocked |
| --- | --- | --- | --- |
| 포획기술 I | 15 | 2 | 제브라케라톱스 (Zebraceratops), 마크라우케니아 (Macrauchenia) |
| 포획기술 II | 25 | 3 | 픽타랍토르 (Pictaraptor), 메갈로케로스 (Megaloceros) |
| 포획기술 III | 35 | 4 | 프로토케라톱스 (Protoceratops), 데이노니쿠스 (Deinonychus) |
| 포획기술 IV | 45 | 5 | 스컹코두스 (Skunkodous), 흰배메갈로케로스 (white-bellied Megaloceros) |
| 포획기술 V | 55 | 6 | 센트로사우루스 (Centrosaurus), 파보미무스 (Pavomimus), 랩터 (Velociraptor) |

Source: NamuWiki 생존 tree via namu.moe **NP**. Confidence **high** as a UI transcription.

**Correction to the PRD.** The PRD's §12.1 and Appendix B say the first capture node is "Capture Quadrupeds I at character 15 — Zebraceratops, Protoceratops, pink Protoceratops." Two errors: the skill line is **포획기술 (capture technique), not a quadruped-specific node**, and **Protoceratops is tier III at Survival 35**, not tier I. Zebraceratops + Macrauchenia is the correct tier I pair. The five-tier ladder also means **species gating is a ladder of five nodes costing 20 SP total**, which is a much cleaner design fact than "species gated by specific capture skills."

### 1.2 Bonded-animal cap (동물 관리)

| Skill | Survival lv | SP | Effect |
| --- | --- | --- | --- |
| 동물 관리 I | 35 | 4 | Bonded capacity +1 |
| 동물 관리 II | 45 | 5 | Bonded capacity +1 |
| 동물 관리 III | 55 | (not in dump) | Bonded capacity +1 |
| 동물 관리 IV | 60 | 6 | Bonded capacity +1 |

**This resolves the sibling docs' open question.** Both files flag "3 → 6, some sources say 7, unresolved." There are **four** +1 ranks. Base 3 gives a cap of **7**; base 2 gives 6. The "6 vs 7" disagreement in secondary sources is almost certainly people counting a different base, not a different table. Confidence **medium-high**.

### 1.3 The capture sequence

Fight → weaken → **stun** → **knockdown** → net. Blunt weapons raise the stun chance; Body Tackle is the named melee skill players used for it. Stun and knockdown are described as random per hit, with specific skills carrying a high proc chance. Hitting a stunned animal again has a high chance to knock it down, leaving it "helpless on the ground," which is the capture window. **Tapping the net fast after the stun raises capture chance** — the window is short and the roll is not guaranteed.

Sources: BlueStacks combat overview, MrGuider, PlayerAssist 61-tips **S**; Survival Guide #94, #225 **P**. Confidence **high** on the sequence, **medium** on "faster tap = better chance" being a real timing term rather than just a closing window.

### 1.4 Taming pen, grades, aging

| Claim | Numbers | Source | Conf. |
| --- | --- | --- | --- |
| Capture → pen → time + chance → S–C grade (from 2018-12-13 overhaul) | S/A/B/C | NamuWiki **NP** | high |
| Tamed animals hold normal stats for **30 days**, then enter **aged** (노화): cannot fight, stats collapse | 30 d | NamuWiki 동물 **NP** | high |
| **Cash-shop animals last 60 days** before aging | 60 d | Same **NP** | medium-high |
| Animal elixir (회춘약) restores youth; **8,000–10,000 T-stones** on the market, or workshop gems | 8,000–10,000 | Same **NP** | medium |
| Pets gain XP with the player; Attack/Defense/Accuracy rise per level | n/a | TouchTapPlay **S** | medium |
| **Milestone buffs at pet level 20, 40, 60**: one of Attack / Speed / Bag Capacity, **randomly assigned, rerollable for payment** | 20/40/60 | TouchTapPlay **S** | medium |
| Smilodon was originally **uncapturable**; became capturable when the **Advanced Research Institute** shipped | n/a | NamuWiki 동물 **NP** | medium |

The milestone-buff reroll is a monetization hook the sibling PRD's §18 does not list. Add it there if the shop section is meant to be complete.

---

## 2. The balance failure that broke taming

This is the single most important design lesson in the bestiary and it is absent from the sibling docs.

NamuWiki's animal page states plainly: **"길들인 동물들의 능력치가 야생 개체에 비해 심각하게 낮다"** — tamed animals' stats are critically lower than their wild counterparts. The nerf history:

| Species | Wild HP | Tamed HP | Notes |
| --- | --- | --- | --- |
| Centrosaurus | 5,000+ | 5,000 → 2,900 → **2,300** | Nerfed twice |
| Ankylosaurus | ~8,000 | **2,963** | ATK 185, DEF 360 |
| Tarbosaurus | 60,000+ | **2,500** | Hunger **16,000**, effectively unusable |
| Smilodon | 17,000 | — | ATK 500, speed 700 |

A final balance patch was **never shipped**; service ended first. Source: NamuWiki 동물 via namu.moe **NP**, confidence **medium-high** (single transcription, but internally consistent and matched by the Reddit complaint record).

**Why it matters.** The whole taming fantasy is "beat the terrifying thing, then it is yours." When the tamed version is 4% of the wild version's HP and eats 16,000 hunger a day, the reward for the hardest capture in the game is a worse pet than a mid-tier one. Players responded by treating pets as **bags and mounts only**, which is why the sibling PRD's pet-role list is so storage-heavy. Combine that with the 30-day aging clock and an 8,000–10,000 T-stone youth potion and taming reads as a rental, not an achievement.

This belongs in the PRD's §22 anti-requirements list. See §5 below.

---

## 3. Full species roster

Transcribed from the NamuWiki 동물 page via namu.moe **NP**. Confidence **high** on names and grouping, **medium** on level/climate for entries where the page gives a range. Fictional = original to Durango, no real-world species.

### 3.1 Carnivores

**Raptor family**

| Korean | Species | Where | Tameable |
| --- | --- | --- | --- |
| 오비랍토르 | Oviraptor | Temperate / desert, early | yes |
| 알비랍토르 | Albiraptor *(fictional, snow recolor)* | Tundra, high | yes |
| 픽타랍토르 | Pictaraptor *(fictional)* | Tropical, early-mid | yes (포획 II) |
| 랩터 / 벨로키랍토르 | Velociraptor | Many, early-mid | yes (포획 V) |
| 겁쟁이 랩터 | "Cowardly Raptor" *(variant)* | Tutorial | — |
| 데이노니쿠스 | Deinonychus | Tropical, mid | yes (포획 III) |
| 아케니쿠스 | Achenicus *(fictional)* | Savannah, early | — |
| 유타랍토르 | Utahraptor | Desert, mid-late | yes |
| 검은머리 유타랍토르 | Black-headed Utahraptor *(variant)* | Volcanic | yes |
| 딜로포사우루스 | Dilophosaurus | Lawless 60, temperate | — |

**Small / swarm**

| Korean | Species | Where |
| --- | --- | --- |
| 콤프소그나투스 | Compsognathus | Many, tutorial onward |
| 줄무늬 콤프소그나투스 | Striped Compsognathus | Tropical |
| 광대 콤프소그나투스 | Clown Compsognathus *(fictional)* | Beaches |
| 엘리펀툴루스 | Elephantulus (elephant shrew) | Savannah |
| 축제 엘리펀툴루스 | Festival Elephantulus | Cash shop |
| 거대쥐 | Giant rat | Swamp |
| 투구게 | Horseshoe crab | Volcanic coast |

**Ornithomimid / runner**

| Korean | Species | Where | Notes |
| --- | --- | --- | --- |
| 파보미무스 | Pavomimus *(fictional)* | Temperate, mid | 포획 V |
| 가스토르니스 | Gastornis | **Cash shop** | Premium speed mount |
| 오르니토미무스 | Ornithomimus | Tundra 55 | + young variant |
| 갈리미무스 | Gallimimus | Desert / lawless | Speed 680, + young |
| 코엘로피시스 | Coelophysis | Many, mid | Speed 570, flock AI |
| 설원 코엘로피시스 | Snowfield Coelophysis | Tundra | |
| 도도피시스 | Dodophysis *(fictional)* | Tundra | |

**Mammal / pack predator**

| Korean | Species | Where | Notes |
| --- | --- | --- | --- |
| 다이어울프 | Dire wolf | Tundra 30 | Speed 600 (nerfed from 700), **DEF 300**, 2–3× Megaloceros HP, poor ride feel |
| 흰털 다이어울프 | White dire wolf | Story reward | |
| 앤드루사르쿠스 | Andrewsarchus | Volcanic | ~9,000 HP |
| 스밀로돈 | Smilodon | Many, mid | 17,000 HP, ATK 500, speed 700, two-hit knockback swipe |
| 래브라도 리트리버 | Labrador | Cash shop | + black event variant with heal/wash/fatigue emotes |

**Reptile / synapsid**

| Korean | Species | Where |
| --- | --- | --- |
| 도마뱀 / 모래 도마뱀 / 붉은점도마뱀 | Monitor lizards | Savannah / desert / blue tropical 55 |
| 디메트로돈 | Dimetrodon *(Permian)* | Swamp |
| 흰줄무늬·불점박이·오색비늘 이구아나 | Iguanas *(fictional)* | Volcanic; one is shop-only |

**Apex / raid**

| Korean | Species | Where | Notes |
| --- | --- | --- | --- |
| 설원 타르보사우루스 | Tarbosaurus (tundra) | Lawless 60 | First raid boss, ~60,000 HP late |
| 열대 타르보사우루스 | Tarbosaurus (tropical) | Tropical | |
| 티라노사우루스 | **Tyrannosaurus** | Volcanic boss | **~200,000 HP, 3 phases**, grants *Apex Predator* title |
| 알로사우루스 | Allosaurus | Ancient island story boss | ~28,000 HP |

### 3.2 Herbivores

**Ceratopsians** — the pack-mule family

| Korean | Species | Where | Bag | Notes |
| --- | --- | --- | --- | --- |
| 제브라케라톱스 | Zebraceratops *(fictional)* | Many, tutorial | 50 | First tame, 포획 I |
| 프로토케라톱스 | Protoceratops | Temperate | 90 | 포획 III |
| 연분홍 프로토케라톱스 | Pink Protoceratops | Tropical | 90 | |
| 센트로사우루스 | Centrosaurus | Tundra | **140** | 포획 V, all attacks knock back |
| 스티라코사우루스 | Styracosaurus | Savannah 45 | — | + young |
| 트리케라톱스 | Triceratops | Swamp 45/55/60 | — | **Untameable despite being a herbivore** |
| 화산재 카스모사우루스 | Ash Chasmosaurus | Volcanic | — | |
| 보누사우루스 | Bonusaurus *(fictional)* | **Cash shop** | **300** | Best bag in the game, paid |

**Armored**

| Korean | Species | Where | Notes |
| --- | --- | --- | --- |
| 안킬로사우루스 | Ankylosaurus | Desert 50 | Bag **150**, DEF **360**, HP 2,963, **hunger 6,000**, club + tail whip, no knockback resist |
| 유오플로케팔루스 | Euoplocephalus | Temperate lawless / city | Tameable |
| 땅거북 안킬로 | "Turtle Anky" *(fictional)* | Cash shop | |
| 스컹코두스 | Skunkodous *(fictional)* | Swamp | 포획 IV, gas attack |
| 유황 스컹코두스 | Sulfur Skunkodous | Volcanic | |
| 파키케팔로사우루스 | Pachycephalosaurus | Autumn event island | ~3,500 HP, head ram |

**Stegosaurs**

| Korean | Species | Where | Notes |
| --- | --- | --- | --- |
| 스테고사우루스 | Stegosaurus | Many, mid | Plate + tail sweep, knockback |
| 켄트로사우루스 | Kentrosaurus | Desert, mid | + young |
| 투오지앙고사우루스 | Tuojiangosaurus | Desert 50 | **Tail swing causes 내출혈 (internal bleeding)** — see §4 |

**Ornithopods**

| Korean | Species | Where | Notes |
| --- | --- | --- | --- |
| 파라사우롤로푸스 | Parasaurolophus | Swamp / temperate | **Made tameable only in the final update**; long-range spit; "light" bone property |
| 사우롤로푸스 | Saurolophus | Tropical | Weak, good tank base |
| 이구아노돈 | Iguanodon | Savannah 45 | Arm swipe, tail |
| 에드몬토사우루스 | Edmontosaurus | Many | Wide tail sweep |
| 용암 하드로사우루스 | Lava Hadrosaur | Volcanic | |
| 돌격전차 하드로사우루스 | "Chariot Hadrosaur" *(fictional)* | Cash shop | |

**Sauropods — untameable HP walls**

| Korean | Species | Where | HP |
| --- | --- | --- | --- |
| 브라키오사우루스 | Brachiosaurus | Many | 75,000 (lv5) – 90,000 (lv8); **instant-cast roll dodge** |
| 아파토사우루스 | Apatosaurus | Swamp 60 raid | **100,000**, heavy regen |
| 아마르가사우루스 | Amargasaurus | Volcanic archipelago 4–5 | ~2× Allosaurus, high DEF |

**Mammals**

| Korean | Species | Where | Notes |
| --- | --- | --- | --- |
| 메갈로케로스 | Megaloceros | Many, mid | Male/female/young split; male speed 600 (nerfed), bag 30, hunger 1,600, oily (기름진) hide |
| 흰 배 메갈로케로스 | White-bellied Megaloceros | Tundra 50 | 포획 IV; males give no milk |
| 마크라우케니아 | Macrauchenia | Many, mid-late | 포획 I, speed 550, high DEF, spit + kick |
| 매머드 | Mammoth | Tundra 50 | Ivory; hide gives wind resist |
| 아랫뿔코끼리 | Deinotherium | Tropical | Ivory, heavy charge |
| 아프리카코끼리 / 흰 코끼리 | Elephants | Cash shop / personal island | |
| 페나코두스 | Phenacodus | Many | Event recolors (Lunar New Year hanbok) |

### 3.3 Human enemies

징병관 (Conscript) and 징병대장 (Conscript Captain), story quests only. Worth noting because the sibling PRD implies the game has no humanoid combatants.

### 3.4 Cut and never-implemented

New material, and useful as scope evidence:

- **Spinosaurus** — concept art only, never modeled.
- **Pterosaurs** — shadow graphics on the ground only; flying creatures were never implemented.
- **Sarcosuchus** — animations were produced; zero game files shipped.
- **Coelacanth / aquatic species** — the underwater system was never developed.
- **Ceratosaurus** — beta only, cut from live.

Source: NamuWiki 동물 **NP**, confidence **medium**. A five-and-a-half-year AAA production with a dedicated art team still could not land flying or swimming creatures. Price any "and you can ride a pterosaur" idea accordingly.

---

## 4. Status effects — the full table

Transcribed from NamuWiki 상태 via namu.moe **NP**. Confidence **high** as a UI transcription. The sibling world doc has roughly a third of these; this is the complete set with numbers.

### 4.1 Buffs

| Korean | English | Duration | Effect |
| --- | --- | --- | --- |
| 아늑함 | Coziness | while in camp | Fatigue gain **−50%** |
| 집 | Home | while indoors | Fatigue gain **−100%** |
| 그늘 | Shade | under barracks | Blocks heat effects |
| 발견의 기쁨 | Joy of Discovery | **15 s** | Fatigue drop, scales with island level |
| 휴식 | Rest | while resting | Health up, fatigue down |
| 활력 | Vitality | **60 s** | Energy consumption **−50%** |
| 씻음 | Cleanliness | **6 min** | Fatigue gain **−20%** |
| 맛있음 | Delicious | **5 min** | Experience **+3%** |
| 응원 받음 | Encouraged | **4 min** | Fatigue gain **−10%** |
| 기분 좋은 향기 | Pleasant Aroma | **2 h** | Climate-fatigue immunity (clan censer) |
| 능력치 향상 | Stat Enhancement | by food | Varies |
| 부족 혜택 | Clan Benefit | while in clan | XP, warp cost, etc. |

### 4.2 Debuffs

| Korean | English | Duration | Effect |
| --- | --- | --- | --- |
| 더러움 | Dirty | until washed | Fatigue **+20%** |
| 매우 더러움 | Very dirty | until washed | Fatigue **+50%** |
| 탈진 | Exhaustion | until fatigue ≤ 지침 | Evasion/accuracy **−80%**, gathering disabled |
| 지침 | Tired | fatigue ≥ 80% | Warning band, map edges redden |
| 갈증 | Thirst | until fresh water | Fatigue **+20%** |
| 맛없음 | Tasteless | varies | Fatigue **+20%** |
| 배부름 | Full | by food | Cannot eat |
| 복통 | Stomachache | **5 min** | Health **−0.2/s** |
| 열독 | Heat poison | **6 min 30 s** | Health **−1/s** |
| 파상풍 | Tetanus | **30 s** | Energy **−1/s** |
| 똥독 | Fecal toxin | **60 s** | Fatigue **+18/min** |
| 침범벅 | Drool-soaked | **30 s** | Fatigue **+5.4/min** |
| 벌레 물림 | Bug bite | **1 min 15 s** | Accuracy **−20%** |
| 벌 쏘임 | Bee sting | **1 min 45 s** | Crit chance **−20%** |
| 어지러움 | Dizziness | **25 s** | Evasion **−40**, accuracy **−20%** |
| 부활 후유증 | Resurrection aftereffect | **10 min** | Recovery reduction, **stacks per death** |
| 좌절 | Frustration | **15 s** | Energy consumption **+50%** |
| 응원 불가 | Cannot encourage | **60 s** | Encourage on cooldown |

### 4.3 Context-flipping

| Korean | Effect |
| --- | --- |
| 젖음 (Wet) | Heat fatigue **−20%**, cold **+30%**, humidity **+30%**. 2 min after leaving water/rain |
| 모닥불 (Bonfire) | Heat **+20%**, cold **−20%**, clears Wet, while seated |

### 4.4 The finding that matters most

**Durango shipped no combat bleed or poison damage-over-time system.**

The status table has no 출혈 (bleeding) and no combat 중독 (poisoning). Every damage-over-time effect in the game is **environmental or ingested**: stomachache from raw meat, heat poison from climate, tetanus from rusted modern debris, fecal toxin from gathering dung, bug and bee stings from foraging. The only animal-applied statuses are **침범벅** (drool-soaked, a fatigue tax from being chewed on) and the stun/knockdown pair, which are control effects and not DoT.

One near-exception: the NamuWiki animal page describes **Tuojiangosaurus's tail swing as causing 내출혈 (internal bleeding)**. That is a single species with a single flavored attack, not a status system. Confidence **medium**.

**This corrects the sibling PRD.** Its §6.4 lists "insect venom, poison, stomach ache from raw meat, dirt, bleeding, knockdown" as negative statuses, which reads as though combat bleed shipped. It did not. Anything bleed-shaped in this project is a **deliberate addition**, not a recreation — which is exactly what [`docs/prd/dinosaur-roster-and-3d-pipeline.md`](../docs/prd/dinosaur-roster-and-3d-pipeline.md) specifies.

---

## 5. Additions for the sibling PRD

Concrete changes, applied in this pass:

1. **§12.1 capture pipeline** — replace "Capture Quadrupeds I" with the five-tier 포획기술 ladder in §1.1 above. Protoceratops is tier III, not tier I.
2. **§12.2 caps** — the 6-vs-7 question resolves: four +1 ranks exist.
3. **§6.4 statuses** — remove "bleeding" from the shipped list; use the full table in §4.
4. **§11.5 aging** — add elixir cost (8,000–10,000 T-stones) and the pet milestone-buff reroll.
5. **§18 monetization** — add milestone-buff rerolls and the 60-day cash-pet aging advantage.
6. **§22 anti-requirements** — add the tamed-vs-wild stat collapse as a named failure (§2 above).
7. **§11.3 taxonomy** — the real roster is ~90 entries built from roughly **18 rigs** plus recolors and juvenile scales. That ratio is the reusable production fact.

---

## 6. Gaps still open

| Topic | Status |
| --- | --- |
| Per-species capture success rates | not published |
| Pen duration per species (30 min vs 1 h for Zebraceratops) | still contradicted |
| Full wild stat block for most species | page gives examples only |
| Whether stun/knockdown had published proc percentages | not found |
| Exact 내출혈 mechanics (damage, duration) | single mention, no numbers |
| Day/night effect on spawn tables | not found (animal *vision* differs per Tip #174) |

---

## 7. Sources added by this pass

- NamuWiki 동물 (animals) via mirror: https://namu.moe/w/야생의%20땅:%20듀랑고/동물 **NP**
- NamuWiki 상태 (status) via mirror: https://namu.moe/w/야생의%20땅:%20듀랑고/상태 **NP**
- NamuWiki 생존 (survival tree) via mirror: https://namu.moe/w/야생의%20땅:%20듀랑고/생존 **NP**
- BlueStacks combat overview: https://www.bluestacks.com/blog/game-guides/durango-wild-lands/overview-games-combat-en.html **S**
- BlueStacks first tame: https://www.bluestacks.com/blog/game-guides/durango-wild-lands/first-dino-taming-dinosaur-en.html **S**
- TouchTapPlay dinosaur/pet guide: https://www.touchtapplay.com/durango-wild-lands-dinosaurs-guide-pet-guide-everything-you-need-to-know/ **S**
- PlayerAssist 61 tips: https://playerassist.com/61-tips-and-tricks-for-durango-wild-lands-beginners-guide/ **S**
- MrGuider guide: https://www.mrguider.org/cheats/durango-wild-lands-guide-tips-cheats-strategies/ **S**
