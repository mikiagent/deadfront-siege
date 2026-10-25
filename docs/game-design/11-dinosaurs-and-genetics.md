# 11 | Dinosaur taxonomy, defensive vulnerabilities and attack-mode builds

**Status:** DRAFT, 2026-10-25. Species catalog and existing stats/archetypes are **observed from current `game/data/creatures/*.json`**. Proposed matchup assignments, new attack modes, training rules and damage coefficients are **NOT IMPLEMENTED OR FULLY CONFIRMED**. Owner confirmed only the direction that dinosaur attacks and weaknesses should be easily categorized using the final **Dexterity / Might** intrinsic IVs and **Impact / Pierce / Slash** damage verbs. Owner gave the specific future Brontosaurus example: massive HP, low defense, Slash-vulnerable; tail whip **DS**, stomp **MI**.
**Related:** [Combat and pack AI](15-pve-exploration-and-combat.md), [Character IVs](02-characters-levels-and-age.md), [Decision register](decisions.md), [Existing creature counter table](../../game/data/combat_counters.json), [Existing creature genetics](../../game/scripts/creatures/creature_genetics.gd).

## 1. Three defensive families: visually recognize the correct tool

**Recommended owner-reviewable gameplay taxonomy:**

| Defensive weakness | Defender body profile | Why the player would pick it | Archetypal example |
|---|---|---|---|
| **Slash (S)** | **Huge/sluggish, exposed flesh**, very high HP, relatively low *effective protection* despite physical mass | Frequent cutting attacks and sustained damage can whittle away a soft giant | Future Brontosaurus with high HP and little armor |
| **Impact (I)** | **Hardened armor / plating / shells / frills**, OR **tiny clustered swarms** when using a *wide-area* impact | Hard hits/stagger challenge protective plates; broad knockback/area control disrupts swarms | Ankylosaurus; cluster of Compsognathus |
| **Pierce (P)** | **Fast, evasive and/or narrow-bodied**, lightly armored enemies whose main defense is movement | Reach, interception, accurate weak-point strikes counter elusive targets; give appropriate attacks tracking/aim/commit advantages | Velociraptor, Gallimimus |

**Necessary exception rules, to avoid contradictory auto-tags:**
1. **Low armor alone is not Pierce.** Slow, large, unarmored HP sponges should be **Slash-weak**; fast low-armor runners should be **Pierce-weak**.
2. **Small alone is not Impact.** One tiny fast animal is often susceptible to aimed Pierce; a **clustered swarm** is particularly vulnerable to **wide-area Impact**. The AoE tag or hit shape, not blunt nominal damage alone, is what counters crowded small bodies. Direct narrow hammer attacks should not somehow auto-hit tiny fast targets.
3. **Armor overrides apparent size.** A large plated Ankylosaurus remains **Impact-weak**, not Slash-weak. A small armored ceratopsian can be Impact-weak.
4. **Pierce is not automatically anti-armor.** In this game its **mobility/precision matchup** is a deliberate gameplay choice; true armor weak-spot penetration can be a separately learned/aimed move mechanic if desired.
5. **Defensive weakness is not the animal's own attack channel.** Stegosaurus can be **Impact-weak defensively** while attacking using **Might/Pierce tail spikes**.
6. **Anatomy + attack hit box + status are separate:** Spike tips entering flesh -> Pierce; a grazing sharp edge -> Slash; a club, stomp or flat tail-base strike -> Impact. **Bleed, poison, fracture, knockdown** remain status effects rather than new attack archetypes.
7. **One clear MAIN weakness, optional secondary resistances** for UI. Do not automatically give all three damage types an unrelated percentage just because one is selected. Species/boss attacks may telegraph phase-dependent counters, but the first iteration should be readable.

These three families are **counter identities**, not literally an automatically cyclic rock-paper-scissors 3×3 formula. To form interesting decisions, the attack must trade **damage/recovery, stamina/energy, reach, area coverage, status, accuracy and counterplay**. Resistances and armor must not erase the player's equipment-level gate or differences in skill/IV.

**Updated overlapping armor design (owner 2026-10-25):** [Armor chapter](06-inventory-equipment-and-storage.md) now uses **four defense bands:** **Exposed** is favored by **Slash**, **Light** by **Slash + Pierce**, **Medium** by **Pierce + Impact**, **Heavy** by **Impact**. Each verb covers two neighboring tiers. This supersedes the earlier **Light -> Pierce only, Medium -> general neutrality** proposal. Natural animals may map to a silhouette/body defense band, while player-created Light/Medium/Heavy armor is wearable and affects speed/fatigue. This is an **owner's preferred relationship**, not a shipped numerical balance table. An agile Light raptor can be **vulnerable to both Pierce and Slash**, with Pierce still better at *landing attacks* through reach/targeting; a soft unarmored giant strongly favors Slash. Existing `combat_counters.json` does not yet implement these two-favored tiers.

**Armor and anatomy clarification:** [06 Equipment and Armor](06-inventory-equipment-and-storage.md) proposes **Light / Medium / Heavy worn protective gear** separately from a species' **natural** exposed/mobile/plated body profile and independently of **DI/DP/DS/MI/MP/MS offense**. A mobile raptor may be *analogous to* Light armor but does not literally have a crafted Light equip piece; an Ankylosaurus has innate plates and might later also wear compatible barding with costs. Heavy armor is **relatively** vulnerable to Impact via shock/guard, yet retains better baseline protection than being unarmored. The new armor weight system is still owner-reviewable and **not implemented**.

## 2. Offensive framework: inherited aptitude × contact verb

| Intrinsic inherited IV | Impact (I) | Pierce (P) | Slash (S) |
|---|---|---|---|
| **Dexterity (D)** | **DI:** slingshot, catapult aiming, placed-impact strike, controlled boulder throw | **DP:** bow, crossbow, aimed bite/spike strike, gun, blowdart | **DS:** whip, throwing axe, accurate claw rake, sauropod tail whip |
| **Might (M)** | **MI:** hammer, stomp, head shove, club-tail drive, body slam | **MP:** spear/javelin thrust, heavy horn charge, spiked-tail punch, crushing jaw puncture | **MS:** melee sword/axe, forceful raking claw or chopping attack |

**Owner-approved names and attribute roles:** Dexterity/Might are inherited IV potentials; Impact/Pierce/Slash classify attack modes, **not** three more IVs. Every individual inherits both IVs even if its anatomy allows only some move combinations. A species can have **multiple modes** and individual breeding/training can favor some of them.

**OPEN:** Which secondary IV influences any given attack; whether training EVs augment expression without changing inherited IV; which moves become selectable; thresholds/cooldowns/attack clip assets; whether all dinosaur species have breeding at every progression stage. Keep existing individual identity, levels and genetic pedigree.

**Owner correction about T. rex (2026-10-25):** **Tyrannosaurus rex is tameable and rideable in intended game design** and naturally belongs to the **Tyrant** mount role; the present species JSON still says `tameable: false`, `capture_tier: 0`, `tamed_role: []`, so current shipped capture eligibility **must be changed in a separate implementation task**, preserving wild tier-60 raid-boss challenge. Huge rider saddle height means human swords/spears cannot auto-hit little prey far below; mount bites/stomps are distinct from rider weapons. **Berserker** (e.g. Utahraptor/Smilodon) is different, with an owner's proposed **Frenzy** damage ramp for successive direct melee Slash hits, capped and resettable. [Full mounted reach/Frenzy design](12-expedition-mounts-and-command.md).

**Latest user idea: mass, armor and trap combat:** Dinosaur **natural mass** should determine whether a creature can trample multiple tiny foes within its planted foot footprint, pin an intermediate-sized animal under a limb, or (for raptors) **Pounce -> Pin -> Slash claw Maul / Pierce bite/Gore** against prey small enough to physically grapple. **Raptors cannot pin an entire giant** merely through a knockdown token. Natural mass is independent of a new **fitted dinosaur armor/load** system. A Brontosaurus could wear **Heavy plate** across back/flanks (Impact relatively favorable there), retain **exposed lower legs** (Slash favorable) and suffer slower turning/whip recovery/carry capacity costs. Mass, per-foot geometry, load ratios and body zones aren't implemented. [Dinosaur Mass, Armor and Grappling](22-dinosaur-mass-armor-and-grappling.md).

## 3. Proposed first-pass catalog of all 19 existing animal/creature JSON species

**Status of this entire table: PROPOSED NEW DESIGN except the current species and present move descriptions.** The proposed vulnerability assignment deliberately does *not* yet match the current combat-counter family for every species. **Attack-mode labels are draft interpretations**, not proof that code presently uses DI/DP/DS/MI/MP/MS.

| Existing species | Proposed primary weakness | Reason | Attack identities to classify | Existing data baseline / conflict |
|---|---|---|---|---|
| **Allosaurus** | **Slash** | Large exposed predator; wounds accumulate on fleshy body | **MP** forceful hatchet-style bite; possible **MS** heavy rake | `apex_raptor` -> current `fast_hunter` family, whose **Cut** weakness already supports Slash |
| **Ankylosaurus** | **Impact** | Thick armor plates/club-shell body | **MI** heavy armored tail club | `club_tail` -> `armored`; current **Blunt/Impact** weakness agrees |
| **Brachiosaurus** | **Impact (KEEP CURRENT), or special-case pending** | Current boss-like tank has major base defense and `titan` protections, not the soft Brontosaurus fantasy | **MI** heavy front-leg stomp; tail **DS** would be a future new mode | Current `titan` -> `giant` **Impact-weak and Slash-resistant**. Do **not** silently convert it into Brontosaurus |
| **Coelophysis** | **Pierce** | Small, fast darting hunter best checked at reach | **DP** controlled darting bite; **DS** leaping claw rake | `flock_harass` -> current `fast_hunter` **Slash** weakness: **design change** |
| **Compsognathus** | **Impact (AOE ONLY)** | Tiny numerous swarms; broad knockback/area-control counters clusters | **DP** darting nip; optional **DS** claw scrape | `swarm` -> current `fast_hunter` **Slash** weakness. Solitary compy should remain fragile to all hits, not magically resist small projectiles |
| **Deinonychus** | **Pierce** | Fast flanking predator, low armor | **DS** sickle-claw rake, **DP** controlled snap | `pack_flanker` -> current `fast_hunter` **Slash** weakness: **design change** |
| **Dilophosaurus** | **Pierce** | Mobile, low-protection predator | **DP** targeted jaw bite; **DI** *spit contact* only if a direct channel is required; venom remains separate **status** | `venom_ranged` -> `venom_hunter`, currently **Impact AND Pierce** vulnerability; choose Pierce to make one signature weakness |
| **Gallimimus** | **Pierce** | Extremely fast runner with little natural armor | **MI** rear kick/charging body strike | `runner` already **Pierce-weak** |
| **Megaloceros** | **Pierce** | Fast, exposed antlered runner | **MP** horn/antler gore; **MI** shove/rear stomp | `antlered` already **Pierce-weak** |
| **Protoceratops** | **Impact** | Stocky protective beak/frill, defense-oriented | **MI** shove/head bump | `pack_mule` -> `armored`, currently **Impact-weak** |
| **Smilodon** | **Pierce** | Fast exposed felid rather than a plated tank | **DS** forepaw swipe, **MP** forceful sabertooth bite | `saber_cat` -> `fast_hunter` currently **Slash-weak**: **design change** |
| **Stegosaurus** | **Impact** | Dorsal plates, armored defensive profile | **MP** forceful thagomizer puncture; **DP** controlled spike targeting; **DS** optional glancing rake | `spiked_tail` -> `armored` currently **Impact-weak**; present tail sweep causes `deep_bleed`, which is independent |
| **Styracosaurus** | **Impact** | Hard skull/frill/horns; solid protective front | **MP** horn charge, **MI** blunt head sweep | `horned_charger` -> `armored` **Impact-weak** |
| **Tarbosaurus** | **Slash (PROPOSED CHANGE)** | Large fleshy theropod with high HP relative to its protection | **MP** clamp-and-shake teeth, **MI** body strike | Current `tyrant` -> `giant` **Impact-weak, strongly Slash-resistant**: major balance change |
| **Triceratops** | **Impact** | Armored frill/head and horn defense | **MP** horn charge, **MI** head toss | `horned_charger` -> `armored` **Impact-weak** |
| **Tyrannosaurus rex** | **Slash (BOSS-SPECIFIC PROPOSAL)** | Vast flesh/HP pool, more compelling prolonged cutting than generic armored defense; could have phases | **MP** giant bite, **MI** stomp | Current `tyrant` -> `giant` **Impact-weak, Slash-resistant**; 200,000 HP raid boss needs separate validation, not blanket flip |
| **Utahraptor** | **Pierce** | Agile ambush hunter, low plates/armor despite size | **MS** devastating downstroke/rake, **DP** quick targeted bite | Current `apex_raptor` -> `fast_hunter` **Slash-weak**: design change |
| **Velociraptor** | **Pierce** | Fast small pack predator, important reach/interception matchup | **DS** claw slash, **DP** aimed bite | Current `pack_raptor` -> `fast_hunter` **Slash-weak**: design change |
| **Zebraceratops** | **Impact** | Small armored/stocky proto-ceratopsian with protected head | **MI** protective head shove | `pack_mule` -> `armored` **Impact-weak** |

**New species, NOT in shipped JSON:**

| Proposed species | Proposed primary weakness | Proposed attack kit | Status |
|---|---|---|---|
| **Brontosaurus** | **Slash**: extraordinary HP, relatively low defense, exposed giant body | **DS** long tail whip; **MI** weighty stomp, breeding/training toward either | **Owner-specific illustration**, species data/assets/stats not yet implemented. Do not quietly alias existing Brachiosaurus |

**Need owner review:** Does Tyrannosaurus really belong in Slash despite being a scripted raid boss? Does small-swarm Compsognathus need **Impact AoE** rather than always Impact? Does Stegosaurus remain primarily **Impact-weak defensively** while having Pierce-centric offense? No owner approval yet for individual existing species assignments except Brontosaurus's intended illustration.

## 4. Existing counter logic is not the requested taxonomy yet

Current verified [`game/data/combat_counters.json`](../../game/data/combat_counters.json):

| Current engine family | Internal channel multipliers **blunt / pierce / cut** | New family consequence |
|---|---|---|
| `armored` | **1.5 / 0.75 / 0.6** | **Impact** advantage already |
| `fast_hunter` | **0.75 / 1.0 / 1.25** | Currently **Slash**, not the user's proposed **fast -> Pierce** |
| `runner` | **0.75 / 1.25 / 1.0** | **Pierce** advantage already |
| `venom_hunter` | **1.25 / 1.25 / 1.0** | Dual Impact/Pierce advantages; clean single weakness not achieved |
| `antlered` | **1.0 / 1.25 / 0.75** | **Pierce** advantage already |
| `giant` | **1.5 / 0.75 / 0.5** | Currently **Impact** advantaged and Slash heavily resisted, opposite the owner's soft Brontosaurus |

**Do not just globally rewrite `fast_hunter` and `giant` multipliers**; that would unintentionally alter every raptor, tyrant and boss. **RECOMMENDED** migration: assign a data-driven per-species `defense_profile` tag or explicit channel multipliers that map to clear **armored / agile / soft_giant / swarm** roles, with current family as fallback, and **separate** damage attack-mode IDs. Use a save-safe schema version, transparent enemy codex UI and combat simulations before any change to shipped balancing.

Simple **illustrative, unapproved** scalar recipe (not mandatory):
- weak matchup **1.25×** damage **after** defense;
- neutral **1.00×**;
- resisted **0.85×**;
- boss status/bleed caps separate from ordinary dinosaurs.
Do **not** assign a single multiplier to tiny swarm targets without checking **splash radius**; also avoid percent-of-max-HP Slash damage that trivializes a 200k-HP boss. Current bleed DOT is fixed DPS, not a percent-health Slash bonus.

A more interesting first prototype may be **one weakness** and **two neutral channels**, rather than giving each creature a weakness **and** an extreme resistance by default. Armor protects through defense value separately; counter mechanics must be visible but not the only determinant of fight success.

## 5. Defensive identity vs combat-role identity, UI

**Recommended Creature Codex card mock content** (only relevant information on discovery, with IVs potentially hidden until capture):
- **Name:** Stegosaurus
- **Body:** Armored / Medium-heavy / Slow
- **Weak to:** **I Impact** (hammer icon)
- **Attack moves:** **MP Heavy Spike Sweep** (Pierce + bleed); **DP Accurate Tail Jab** (unlock/variation, proposed)
- **Traits:** Protected back, exposed underside (if weak-point system exists)
- **Build aptitude:** Might IV / Dexterity IV when legally visible; training skill/EV and selected moves separately
- **Counter hint:** Heavy hammer / broad impact vs plated back. Keep distance from spike arc.
- **Tooltip:** 'Pierce' on tail attack does not mean Stegosaurus itself is vulnerable to Pierce.

**Don't leak wild genetics:** the current game presents hidden wild IVs until tame. Defensives, silhouettes and telegraphed attack types can be readable without revealing exact inherited IV rolls.

## 6. Balance/playtest checks before approval

1. Given three same-level weapons at equal material quality, the anti-armor Impact build performs best **versus Ankylosaurus** without instantly outperforming all other builds in normal PvE.
2. Pierce is a useful **interception/reach/aim** solution for a Velociraptor, not simply 'more single-target damage' with no reason.
3. Slash produces meaningful sustained damage against a Slash-weak **new Brontosaurus** despite giant HP, without proportional-max-HP bleed making an apex raid boss trivial.
4. A slow axe or heavy hammer does not become perfect anti-Compy just because Compy was tagged 'Impact weak'; it needs **splash/area**, a separate crowd-control strength, or deliberate positioning.
5. **Stegosaurus:** Impact is its defensive counter; primary thagomizer contact Pierces and can cause Bleed. Its defense tag does not change when trained for DP versus MP.
6. Species with multiple moves actually vary timing, reach, target shape and IV weights. A Stegosaurus MP spike and DP spike must have distinct play patterns; both use Pierce damage.
7. Current creature stats and damage channel enums remain stable while testing the new taxonomy. Upgraded saves do not lose genetic IV/EV/level data or switch existing tamed creatures to different species.
8. In the Codex, a beginner can tell 'large soft -> Slash', 'plated -> Impact', 'fast -> Pierce' from a glance with a few obvious exceptions.

## 7. Prioritized owner choices

1. **Keep or change fast raptors:** Existing fast-hunter family is **Slash-weak**. Should Velociraptor, Deinonychus and Utahraptor move to **Pierce-weak** as the new rule suggests?
2. **Tiny swarms:** Is Compsognathus specifically **weak to Impact area attacks**, while still vulnerable to individually aimed projectiles, rather than globally weak to every Impact hit?
3. **Bosses:** Do big Tyrannosaurus/Tarbosaurus become **Slash-weak** with Brontosaurus, or remain **Impact-weak** because of special heavy protection/raid mechanics?
4. **Stegosaurus:** Defensive **Impact weakness** and offensive **Pierce (MP/DP)** sounds anatomically coherent. Should the optional Slash rake be a separate future move?
5. **User-facing numbers:** Should Codex show only **Weak / Neutral / Resistant** icons, or exact percentages for experienced players? A toggle may fit accessibility, with transparent combat floats regardless.

Do not confuse owner-approved global naming with these still-open species balance assignments.
