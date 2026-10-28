# Claude implementation prompt: Durango Wild Lands Combat and Animal Capture

Implement a combat system inspired by the original *Durango: Wild Lands* (2019), including **semi-automatic basic attacks, manual timing of skills and defensive reactions, attack telegraphs, weapon styles, combat stances, status effects, and stun-based dinosaur capture**. Integrate with the existing dinosaur AI, progression, equipment, survival and taming systems. This file is the authoritative detailed combat/capture specification; **reuse the capture subsystem from `02_dinosaur_taming_and_companions.md` rather than building it twice.**

## 1. Combat was semi-automatic, not turn-based
Historical guides describe selecting a creature and choosing **Attack**, after which the player performs repeated basic attacks according to weapon speed, with manual special skills used between those attacks. Combat occurred in near-real-time. Aggressive animals could engage automatically when the player got too close; some initially peaceful animals became hostile if crowded. Build explicit target selection, attack range, approach/positioning, auto-attack cadence, cancel/retarget, combat exit and safe interruption. Do not turn this into a purely idle auto-battler: defense and special actions require player timing.

## 2. Dinosaur tells and defensive timing
A **yellow glow/ground warning** telegraphed an incoming enemy attack in contemporary descriptions. Telegraph danger zones (single target, cone, arc, radius, charge) and appropriate windup, active hit and recovery windows. Expose a timed **Roll** or other defense skill; successful timing avoids/mitigates the attack and may award Defense experience. Roll has stamina/energy/cooldown constraints and skill-tree upgrades. Don't award Defense XP merely for pressing Roll without narrowly avoiding a real attack. The historical combat system received a significant July 2019 update, so exact auto-evasion, ranged-roll compatibility, and action timing are **version-dependent**. Make these configurable and choose one consistent gameplay model.

## 3. Weapons and tactical niches
Support one-handed melee (fast, accessible early), two-handed weapons (slower/stronger), lances (reach/penetration/charge), and ranged bow/crossbow (range, repositioning, projectile timing). Historical player descriptions associate axes with area attacks, maces with stun, and swords/lances with penetration. Map weapon family stats: attack speed, range, attack/impact damage, accuracy, lethality, penetration, stun buildup/odds, wound effects and durability. Equipment properties must come from the previously implemented materials/crafting system (Firm → attack, Full → stun rate, Lightweight → accuracy, Pointy → penetration, etc.). Combat must use actual stats, not decorative item rarity.

## 4. Combat stances and learnable actions
Original player guides list melee **Attack, Defense, Berserk and Blitz** stance families, with a distinct **Counter** reference in Defense discussion; ranged **Shooting** and **Sniper**. Documented examples: one-handed Strike (multiple stances), Smash (Attack), Backstab (Defense); two-handed Crush (multiple), Cleave (Defense/Berserk), Sunder (Attack/Berserk); lance Impale, Charge (Blitz); ranged Shooting's Barrage and Sniper's Aimed Shot. Historical players described Shooting as faster/mobile and Sniper as stronger/slow, with stance-dependent mobility. Build data-driven action definitions, valid weapon/stance requirements, skill prerequisite/unlock, costs, cooldown, cast/windup/recovery, animation and actual on-hit effects. Avoid claiming unverified universal stance compatibility; use explicit configurable tables and note values requiring playtest.

## 5. Damage, avoidance and combat states
Calculate outcomes from attacker weapon attack/accuracy/penetration/lethality/crit and target defense/evasion/resistances and buffs, with deterministic tested order of operations. Exact historical damage formula is not established, so expose tunable coefficients. Implement enemy threat/aggro, disengagement, death and loot hooks. Damage types and status effects may include stun, knockdown, Bleeding, Distracted/accuracy reduction, and temporary health regeneration. Integrate item-derived rare effects (e.g. Vital Strike, Sadism, Throw Dirt) with cooldown/proc rules; do not apply twice per attack. Companion dinosaurs participate via existing AI; allow tanky pets to draw aggro while a ranged player attacks.

## 6. Capture is an intentional nonlethal combat outcome
Capture eligibility requires (a) learnable Survival → Animal Taming capture skill for that species/category; (b) an eligible **living wild creature**; (c) valid proximity/inventory room; (d) target is **stunned or incapacitated**; (e) health sufficiently reduced. Historical guide example: around **50% HP**, a 'losing strength' message appeared and Shoulder Tackle or a stun move was effective. Maces/hammers were desirable for stunning without killing. When eligibility is satisfied, show the **net-shaped Capture action** on/near the target. Player presses Capture, gameplay validates again, and one probabilistic attempt resolves. Capture chance should generally improve as target HP falls and player Capture Ability rises relative to target difficulty; exact server formula and thresholds aren't verified, so make them configurable. Failed captures leave target alive, recovering or resisting; successful capture despawns exactly one wild actor and generates exactly one captured-dinosaur inventory item retaining species, level and individual traits. This captured item then goes to a physical **taming pen** as defined in file 02; capture must **not** instantly produce a bonded mount.

## 7. Anti-softlock and failure handling
Do not let incidental auto-attacks kill a player-desired capture target immediately after stun. When Capture becomes available, permit auto-attack pause or an intentional nonlethal/capture mode, as a new usability design choice. If the dinosaur dies, capture is invalidated and normal butcherable loot may spawn; it cannot simultaneously be killed and captured. Validate stun duration, debuff expiration, target despawn, line-of-sight, competing players, full inventory, failed action, repeated button presses and reconnects. Deduct capture costs at the defined commit point and enforce unique actor-to-item transition. High-level dangerous dinosaurs should demand preparation and risk; keep beginners' first Zebraceratops feasible.

## 8. Combat UX and progression integration
UI shows target HP, warnings, effect indicators, current stance, auto-attack state, special moves, defensive roll cooldown/stamina, capture readiness and chance/requirements when appropriate. Melee XP grows from valid melee combat, Ranged XP from ranged fighting, Defense XP from successful timing, Survival/capture XP from appropriate capture activity. Learning/upgrading combat skills must use the shared skill node/SP system; crafting materials determine weapon performance and durability; stamina/energy/fatigue systems impose action costs and expedition endurance.

## 9. Vertical-slice acceptance tests
Create an enemy with a telegraphed attack → select and auto-attack → manually Roll during windup → Defense XP is awarded only on valid defense → use weapon-specific special attack → see status effects → weaken an eligible Zebraceratops → Shoulder Tackle/stun → net Capture appears → attempt fails then retry, or succeeds → wild actor removed and captured instance safely added to inventory → taming pen accepts it. Separately test stun expiration, lethal blow, weapon/stance restrictions, ranged behavior, companion defense, item affix procs, no duplicated capture, no repeated XP, save/load and simultaneous capture requests.

## Reference screenshots — combat HUD details (owner, 2026-10-27)

A pasted in-combat screenshot against a wild quadruped (Acernychus Lv. 15, HP 141/320; not on disk). Reading is the orchestrator's — only details not already in 25 (#5: knife hexes, Attack Stance, End Combat, energy regen) or 23 (target plate, select-then-attack):
- **Auto / Prep.** The bottom-right cluster centres on a two-state hex — Auto (default) with Prep labelled beneath it. Prep is the capture-preparation state of §7: the nonlethal pause made spatial, one button toggling the intent away from lethal auto-attack.
- **Locked stance hexes.** Unowned stance/weapon hexes render dark with a small padlock — visible but unavailable, the same lock language the skill trees use (03; `skills.md` reference).
- **Attack Stance ring.** The stance circle at the right edge carries the active attack stance over a portrait ring; switching stays a ring affordance.
- **Chase hex.** A separate toggle on the mid-left edge ("Chase", runner icon) — the approach/keep-distance control, apart from the attack cluster.
- **"steadied itself."** The target plate emits status prose — here the animal recovering poise. Placeholder for capture-window messaging: when the stun window opens or closes, say so on the plate (09's stun rules).
- Top HUD: dual player bars (HP + a second resource), companion portrait chip with a distance readout (72 m), and a round minimap with "X 759 Y 965".

## Historical sources
- BlueStacks combat guide: https://www.bluestacks.com/blog/game-guides/durango-wild-lands/overview-games-combat-en.html
- BlueStacks first dinosaur/capture guide: https://www.bluestacks.com/blog/game-guides/durango-wild-lands/first-dino-taming-dinosaur-en.html
- MMORPG.com 2019 review of semi-auto combat: https://www.mmorpg.com/columns/durango-wild-lands-review-big-things-do-come-in-small-packages-2000108364
- 2019 player skill/stance discussion: https://www.reddit.com/r/DurangoWildLands/comments/bn0shk
- Ranged stance comparison: https://www.reddit.com/r/DurangoWildLands/comments/c1e5wq
- July 2019 combat-update report: https://www.reddit.com/r/DurangoWildLands/comments/cebrzd

Treat those references as historical guides, not a complete recovered Nexon combat specification.

## Implementation standards
Inspect the existing project and its architecture first. Reuse existing gameplay, inventory, persistence, UI, and network components rather than introducing parallel systems. Implement working code in the project's language and engine, not just pseudocode. Separate definitions/configuration from saved runtime state. Make balancing parameters configurable. Preserve unique instance IDs and enforce atomic ownership/currency transitions. Where multiplayer exists, validate gameplay authoritatively and make retried operations idempotent. Include tests and summarize modified files, verified behavior, assumptions, and remaining limitations.

**Historical fidelity:** Durango: Wild Lands was updated during 2019; published guides can describe different revisions. Distinguish verified original mechanics from contemporary player reports, community reconstruction formulas, and new design choices. Do not claim illustrative values are exact original Nexon server values.

## Owner decision, 2026-10-28 — fighting style by class

Each species fights with an innate style from its CLASS (the `archetype` field in its creature JSON: pack_flanker,
pack_raptor, apex_raptor, tyrant, horned_charger, club_tail, spiked_tail, venom_ranged, saber_cat, swarm,
flock_harass, antlered, runner, pack_mule, titan). Its NATURE (Timid, Brave, Aggressive, Loyal, Stubborn, Docile)
combines with that style; there is no separate "Berserker" class. Attacks have cooldowns for both the player and
creatures, specials cost creature energy, and hits cannot chain-stun.
