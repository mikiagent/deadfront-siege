# WildLands MMO | Combat, Armor, Mass and Siege Math

> **Status:** WORKSHOP PROPOSAL. Balance coefficients, curves, ratios and examples are **not approved gameplay**.  
> **Established direction:** Dexterity (D) and Might (M) are intrinsic aptitudes. Impact (I), Pierce (P), Slash (S) are contact channels. Six attack archetypes DI/DP/DS/MI/MP/MS; damage is affected by actual reach, hit area, armor class, animation timing and mass. Heavy intact armor deflects an ordinary raptor pounce pin. Mass influences both offensive contact power and a defender's resistance.  
> **Related:** [Game Vision](WildLandsMMO_Game_Vision.md), [Existing armor proposal](06-inventory-equipment-and-storage.md), [Mass and grappling](22-dinosaur-mass-armor-and-grappling.md), [Mounting and combat](12-expedition-mounts-and-command.md).

## Combat should reward contact, not spreadsheets

A giant dinosaur has a dangerous footprint and telegraphed attacks. A spear can be effective because it reaches a vulnerable part of the target. A heavy animal's stomp feels heavy because the body has mass; fitted armor helps but also burdens movement. Weapon level alone is not enough to guarantee a safe victory.

Dexterity and Might describe **how** an attack is controlled or powered, not melee vs ranged. Impact disrupts, Pierce concentrates force, Slash cuts exposed material. Delivery (melee, projectile, mounted, siege) is independent.

| Attack family | Example character fantasy |
|---|---|
| DI | Well-aimed sling impact, controlled stone shot |
| DP | Bow, crossbow, aimed piercing projectiles |
| DS | Accurate whip, thrown cutting blade |
| MI | Heavy mace, fist, stomp or crushing club |
| MP | Braced spear, javelin, horn drive |
| MS | Heavy axe, blade or broad cleave |

## Proposed readable damage model

`Damage_HP = Base_weapon_damage × Level_factor × Aptitude_factor × Learned_skill_factor × Move_factor × Contact_quality × Material_factor × Channel_factor × Armor_mitigation × Condition_factor × Specialized_mass_or_momentum_factor`.

This is a candidate *interpretation* of combat factors, not a requirement to multiply arbitrarily many invisible buffs. Each role is bounded, visually meaningful and should be shown through relevant tooltips/indicators.

Candidate factors:

| Factor | Example | Guardrail |
|---|---|---|
| `Aptitude_factor = 1 + 0.25×normalized_D_or_M` | 1.0–1.25 | Inherited stats matter, not instant invincibility |
| `Learned_skill_factor` | 1.0–1.20 | Skill has its own payoff, separate from IV |
| `Level_factor` | Weapon-versus-target progression scaling | Level gate is strict, not bypassed by cash |
| `Contact_quality` | 0.5–1.1 based on real hit location | Misses do 0; nearby visual effects are not phantom hits |
| `Material_factor` | e.g. 0.85–1.15 | Apply compatible named trait effects, respect caps |
| `Condition_factor` | e.g. 0.6–1.0 | Broken/worn gear should visibly degrade |
| `Channel_factor` | 1.12 favored, 1.0 ordinary | Armor matchup is a *relative* preference |
| `Armor_mitigation = 100/(100+Effective_armor)` | Armor 150 gives 0.40 | Heavy protection remains real against its favored counter |

### Proposed armor matchups

| Defender type | Favorable incoming attacks | Relative identity |
|---|---|---|
| Exposed | Slash | Soft unarmored targets can bleed or be cut effectively |
| Light | Slash, Pierce | Mobile, easier to penetrate if hit |
| Medium | Pierce, Impact | Reliable protection and some flexibility |
| Heavy | Impact | Highest base protection, slow and stamina-demanding |

A heavy-plated target should not take more raw HP damage than an unarmored target from the same mallet just because Impact has a favorable matchup. **Example with 100 pre-defense damage:** against Light with 25 armor and Pierce favored, `100×1.12×100/125 = 89.6`; against Heavy with 150 armor and Impact favored, `100×1.12×100/250 = 44.8`. Different weapon channels have different status, aim, stagger and guard consequences; not all balance should be done through HP damage.

### Status is not raw damage

Poison, bleed, stagger, pin, knockback and fatigue are separate results subject to eligibility, duration, caps, anatomical relevance and prior effects. Heavy protected surfaces can **reject ordinary raptor pounce before any Pin**. A different massive crusher's attack may still affect that target. No universally stackable bleed that deletes a late boss's percentage of maximum HP every second.

## Proposed weight and movement mathematics

`Total_physical_mass = Natural_body_mass + Armor + Saddle + Carried_riders_and_cargo`.  
`Load_ratio = Carried_mass / Comfortable_carry_capacity`.

**Load tradeoff proposal:** Up to a comfortable load ratio `r≤1`, speed remains near normal. Beyond `1`, `Speed_factor = max(0.55, 1 − 0.40×(r−1))`, with sharper turning/stamina penalties and hard overload limit determined by animal anatomy. An animal at 125% comfortable load receives a speed factor of **0.90**; at 175%, **0.70**. This is not a license to stack infinite armored mass for free.

**Impact mass power proposal:** For a species-defined contact-mass reference `M_ref`:

`Stomp_mass_factor = clamp(1 + 0.18×ln(max(1, M_contact/M_ref)), 1.0, 1.35)`.

Carried weight meaningfully increases supported stomp force within a physical cap. **Do not apply full body mass to every claw, arrow or tail-whip action.** A tail strike uses the actual moving tail segment, not all the dinosaur's load.

**Relative defender mass proposal** for giant contact against a body of mass `M_def`:

`Relative_body_factor = clamp((M_contact/M_def)^0.12, 0.72, 1.20)`.

A much heavier defender receives less HP damage from the *same type of properly landed body contact* and is harder to stagger. An extremely light target is vulnerable, within caps. This term is relevant to body contact and not added to all weapons. Reference normalization and whether contact/relative mass should be merged into one curve are **OPEN**; avoid counting the same mass effect twice.

**Separate stagger threshold proposal:**

`Stagger_pressure = Attack_impulse × clamp((M_att/M_def)^0.25, 0.5, 2.0) / Defender_stability`.

Only a completed hit above the defender's stagger threshold applies stagger. A giant armored defender can continue walking into a small attacker while taking HP damage. A plate that rejects a pounce does so before the ordinary pounce's knockdown/pin follow-up.

## Positional mastery

- **Longshot:** Difficult, genuinely accurate DI projectile impacts at distance can gain a bounded bonus (candidate **+0–20%** on eligible confirmed hit, not every distant miss).
- **Momentum:** A real mounted braced MP lance hit depends on aligned approach speed, direction, windup and clear contact (candidate **+0–30%** within safety cap).
- **Frenzy Slash:** Consecutive landed DS/MS **melee** Slash hits can build a temporary bounded follow-up reward (candidate +5% per eligible hit, cap +20%, breaks after miss/stagger/time gap). Ranged Slash does not gain it automatically.
- **Big-creature telegraphs:** Brontosaurus' long DS tail whip threatens a broad area; its MI stomp threatens near-foot positions. Each has visibly readable warning, collision/contact and recovery.
- **Mounted reach:** A rider on an enormous T. rex does not hit a tiny ground enemy with a sword unless the weapon actually reaches them. The dinosaur uses its own bites, stomps and tail actions.

## Crewed turrets and platforms

Stationary and saddle-borne siege consume real ammunition from valid inventories. Some turrets fire automatically through constrained mechanical or primitive technology; some require real tribe members in physical seats.

Owner-established platform maximum on eligible heavy dinosaurs: **one crewed siege weapon, two automatic turrets, one shared finite ammunition box**. Either the player drives and a real member guns, or the member drives while the player guns. Saddles, riders, ammo and mounted tools consume carry capacity.

**Proposed fire economy:** `Sustained_shots_per_minute = min(60 / Reload_seconds, Available_ammo / Planned_minutes, Crew_service_capacity, Line_of_fire_limit)`, with suitable time units. Damage does not continue with empty ammo or absent crew. Reload, positioning, recoil, projectile path and turret arcs must remain meaningful.

## Questions for the balance workshop

1. Should combat feel mostly **deliberate and telegraphed** (soulslike), **quick and accessible** (action RPG), or a hybrid depending on weapon/creature?
2. How much stronger should a masterfully bred dinosaur be than a normal healthy specimen of the same level?
3. Should damage ratios be tuned primarily around **solo player skill** or the **three-slot expedition group**?
4. Is the proposed heavy-armor Impact advantage best expressed as higher **HP damage**, **stagger/guard damage**, or both?
