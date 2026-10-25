# 22 | Dinosaur body mass, protective barding, pinning and trampling

**Status: OWNER'S PROPOSED DESIGN DIRECTION, 2026-10-25; numbers, equipment implementation and per-species moves unapproved.** User requests a physical **dinosaur weight system**, **dinosaur armor/barding** with meaningful speed-versus-protection trade-offs, and **size-relative restraining combat**: a huge animal can tread on several tiny animals, a moderately smaller dinosaur can be trapped under its foot and subject to a follow-up attack, and **raptor pounce/pin/maul or gore** should be defining moves. The showcase fantasy is **a heavily armored Brontosaurus**. No gameplay code or creature stats were changed in this design pass.

**Related chapters:** [12 Expedition Mounts and Commands](12-expedition-mounts-and-command.md); [06 Equipment and Armor](06-inventory-equipment-and-storage.md); [11 Dinosaur Taxonomy and Genetics](11-dinosaurs-and-genetics.md); [15 Combat](15-pve-exploration-and-combat.md). **Current relevant code:** [Creature definitions](../../game/scripts/creatures/creature_def.gd), [Creature collision](../../game/scripts/creatures/creature.gd), [Combat status logic](../../game/scripts/combat/status_effects.gd), [Status definitions](../../game/data/statuses.json), [Creature Attack](../../game/scripts/combat/creature_attack.gd), [Player mount movement](../../game/scripts/player/player.gd), [Human equipment](../../game/scripts/items/inventory.gd).

## 1. Four axes, not one giant 'weight = power' stat

| Axis | Definition | Example | What must NOT happen |
|---|---|---|---|
| **Body mass** (innate natural mass estimate) | Creature physiology: size, muscular/bone mass, growth stage if used later, inherited condition/physique where appropriate | A big Brontosaurus outweighs a raptor irrespective of armor | Equipping metal cannot turn a small dinosaur into a giant whose jaw pins everything |
| **Added carried mass** (loadout) | Harness, saddle, fitted barding, pack cargo and rider(s) | A plated Brontosaurus carries an enormous amount of armor | Free protection without load cost |
| **Handling capacity / encumbrance** | What fraction of comfortable carrying/mobility ability the load represents, tied to species, anatomy and endurance | Big mount safely carries more absolute kg than a Compy; a long tail is not a suitable cargo rack | One universal kg weight threshold for animals with wildly different sizes |
| **Protection profile and coverage** | Anatomy (natural plating/hide), plus wearable armor class, material, body coverage, integrity | Exposed leg, armored flank, exposed tail root | Global heavy tag makes head, underside, tail and every leg equally protected |

**Optional core data model, proposal only:**
- `natural_mass`: per-species body mass baseline used for size/control checks; do not infer reliable kg from the game's current model scaling alone.
- `carried_mass = armor + saddle + cargo + rider`.
- `comfortable_load` (species/size/endurance-derived): denominator for **encumbrance = carried_mass / comfortable_load**; distinguish *load handling cost* from mass available to a collision. **Owner-confirmed new direction:** gear adds some real effective physical mass and SHOULD increase the power of stomps, body slams and tackles when they land. Scale with diminishing returns and valid contact/velocity rather than giving uncapped damage per extra kilogram.
- `body_profile` plus **zones** (`head, torso/flanks, neck, legs, tail` as actually available by model/rig), with each worn piece specifying supported slot, covered zones, protection class, durability and weight.
- `mass_class` may be a player-facing shorthand (Tiny / Small / Medium / Large / Giant / Titan) if needed, but rules should use **relative mass and actual contact geometry**, rather than brittle fixed tags that ignore growth, unusual body builds and equipment.
- Character **Might/Dexterity IVs** are separate from *physiological body mass*. A very strong small raptor can grapple above its expected size somewhat but cannot automatically pin an entire Triceratops. Learned wrestling/training, balance, current stamina and momentum influence control. Body mass is not a third combat damage type or replacement IV.

**Practical accuracy:** Do not run full simulated rigid-body mass/weight physics for every creature. Use data-driven mass, stamina, load ratio, body contact and predictable checks; preserve existing movement and animation reliability.

## 2. Trample / Pin / Pounce / Gore are *move mechanics*, not a fourth damage type

| Move | Who may use it | Contact requirement | Outcome | Counterplay |
|---|---|---|---|---|
| **Trample** | Giant feet, heavy Charger/large animals when animation supports it | Animated foot/body sweep **overlaps actual grounded hurtboxes** | Contact **Impact** damage and potentially hits **multiple tiny enemies** in one footprint | Feet telegraphed, run out of indicated footprint, avoid crowded lanes |
| **Heavy Pin** | Attacker substantially outweighs defender and can physically restrain it | Foot/limb anchored on grounded target, species attack clip supports hold | Short **Pinned** restraint, follow-up **Impact stomp** or anatomy-compatible **Pierce gore / bite** if in reach | Dodge onset, resistance/struggle by size/Stamina, ally stagger/distraction, release on lifted foot |
| **Pounce / Tackle** | Raptor, feline, agile predator with leap animation | Trajectory intersects target; landing zone and mass ratio permit hold; **Heavy armor at the struck zone rejects pounce pins** | **Knockdown**, then **Pin** if target small enough and **NOT properly Heavy-protected**; against covered Heavy, **pounce fails and attacker recoils/disengages** | Side-step, armor counters, force attacker off, exploit recoiling raptor |
| **Maul** | Raptor/feline with jaws and raking claws | Predator holds or repositions near target, real bite/claw contact | **Pierce bite** or **Slash rake**, maybe Bleed and Berserker Frenzy; not a free separate universal damage type | Escape pin, interrupt creature, punish attack recovery |
| **Gore** | Horn, spike, tusk, beak or penetrating jaw move when anatomy supports | Penetrating point actually reaches target or pinned body | **Pierce** damage with possible injury; enhanced follow-up from target's restrained state | Avoid weapon point, defend protected body zone, escape target restraint |

**Terminology:** Raptor's iconic sequence is **Pounce -> Pin -> Maul/Rake**, where the claw rake is **Slash** and penetrating bite is **Pierce**; horned dinosaur **Gore** uses **Pierce**. If the UI wants `Gore` for a raptor's teeth, label it a bite/maul variant, not a universal animation shared with horns. A **Brontosaurus is not a carnivorous goring animal**: it tramples/stomps and maybe keeps a target underfoot; don't invent teeth/horns for a gore finisher it cannot perform. A **T. rex** can use its actual jaw geometry to follow a pin with **MP bite** if its head and the target position really meet.

**Relative-size results (qualitative, no universal threshold yet):**

| Contact matchup | Likely possibility | Special cases |
|---|---|---|
| Giant vs many **tiny** enemies | One footstep can **hit many** tiny bodies actually within its footprint; high Impact and possible instant incapacitation in severe mismatch | Giant must plant that foot, not execute a full-circle area attack when merely walking |
| Giant vs **medium** animal | Target may be **knocked down and pinned**, threatened by next foot or compatible follow-up attack | Body parts/weight distribution matter; a giant's mere proximity does not always pin |
| Raptor vs **smaller** prey | Pounce -> Pin -> Maul **if target isn't Heavy-armored at impact zone** and contact is valid | **Heavy armor BLOCKS pounce pin and forces attacker back**, even when an unarmored victim would be pinned; other crushing/tackle moves may still matter depending size |
| Raptor vs **similar-sized** prey | Contested brief grapple/knockdown; resistance, Might and stamina matter | Strong defender can shove off or survive; neither guaranteed |
| Raptor vs **much larger** prey | Can latch on or rake exposed tissue in a precise window, **but cannot pin the entire giant** | Large prey can shake, roll, whip or dislodge the attacker |

**Three status states:** **Knockdown** = knocked off balance or prone; **Pinned** = mechanically restrained by a **specific physically valid hold**; **Exposed** (optional follow-up vulnerability modifier, not necessarily a new status slot) = certain attacks can more effectively contact a vulnerable local body part. Existing status `pinned` already exists with `cannot_act` and `move_mult=0`, and `knockdown` exists. This **does not mean** the engine currently tests attacker-vs-defender mass, keeps a foot anchored, applies multiple footprint hits, or exposes finisher positions. Avoid just spamming `pinned` for every heavyweight encounter.

**Owner anti-pounce armor rule:** **Any sufficiently intact Heavy protective coverage on the target's pounce-contact zone prevents the normal raptor Pounce -> Knockdown/Pin -> Maul hold sequence**. The pouncer hits/deflects and must **back off or visibly recoil**, with appropriate recovery; it may still inflict a mitigated first Impact/Slash contact hit or damage armor durability, but it cannot keep pinning or immediately re-pouncing. If the contact zone is unprotected, a pounce may still work after mass/contact checks. An extremely massive attacker can still restrain the protected target through an **anatomically distinct** grapple, jaw clamp or body-weight crush, but do not relabel an ordinary blocked raptor pounce to bypass the armor rule. Heavy armor does not grant blanket damage immunity or immunity to giant crushing stomp. **Protection is zone-based rather than a mere equipped-any-heavy-piece flag.**

**Important fairness and integration:** Existing `StatusEffects` caps active statuses at **three** and currently exempts T. rex from certain control statuses (including `pinned`). Any new size-based rules and escape controls must preserve raid boss fairness, do not accidentally permit perma-stun/stagger from pack pounces. Suggested non-numeric immunity/recovery windows after release. If `pinned` is maintained only while an actual limb/creature is holding the target, clean up on animator interruption, death, teleport, clip complete and save/load.

## 3. Natural protection + manufactured dinosaur armor

**Keep the user's previously selected global weapon matchup language:**

| Protection on the struck body part | Attacks favored on a successful contact |
|---|---|
| **Exposed** | **Slash** |
| **Light** | **Slash, Pierce** |
| **Medium** | **Pierce, Impact** |
| **Heavy** | **Impact** |

Natural body and added gear should be separately represented, and **covered zones** use whichever coherent effective protection rule the team finally chooses. Do not multiply the full natural armor counter and full barding weakness twice for one hit.

**Primitive wearable dinosaur barding examples:**
- **Light:** stitched hide/fur, fiber harness, leather guards, low burden. Good for Courser/Skirmisher movement.
- **Medium:** layered hide/scale/wood/bone/scute guards with gaps to move and turn. Suitable for versatile cavalry/Charger.
- **Heavy:** large fitted plates of scute, bone, wood, iron or a primitive forged metal; high protection for Tank/Tyrant/Titan at real material cost. Flexible connections essential on joints/long neck/tail. No assumption that primitive society can economically cover every square meter of a Titan.

**Same resource economy as human items:** material lot level, signed traits, Tailoring/smithing specialization, durability and repair, custom fit for species and size, meaningful market price, personal/profession craft gates. Natural scutes exist permanently; leather/plate barding can be removed or broken. A wounded or broken piece stops contributing full protection. Tames are individuals; don't silently replace their biological stats when dressing them.

## 4. Weight as a strategic trade-off

| Load option | Protection | Movement and stamina | Combat identity |
|---|---|---|---|
| **No extra armor** | Innate skin/plates only | Best attainable turning, sprint/recovery; maximum cargo capacity | Mobile, easier to reposition, exposed flanks on soft bodies |
| **Light barding** | Small armor boost, strategic coverage | Minor extra stamina/load cost | Preserves Cavalry, Skirmisher, Berserker movement and Frenzy access |
| **Medium barding** | Better coverage and survivability | Moderate turn/acceleration load cost; less extra cargo | Escort, guard, flanking Charger |
| **Heavy barding** | High durability and resistance over fitted zones; **blocks ordinary raptor Pounce -> Pin when pounce strikes its covered, intact Heavy zone** | Slower **acceleration and turning** and/or higher **stamina usage**; reduces sprint/reposition and cargo or rider load headroom | Bulwark, Tyrant, armored Titan; stronger committed stomp/tackle hits from true mass gain |

**Do not penalize too many mobility stats at once.** A single load ratio can impact a small number of primary knobs (e.g., turn/acceleration and sprint stamina consumption); long list of stacked speed/turn/dodge/regen penalties may make heavy armor useless. A naturally slow Titan may have minimal sprint to begin with, so **turn recovery, time to rotate the body/tail, stamina exertion, and logistical material cost** are better knobs than only reducing top movement speed.

**Updated owner direction: Weight MUST meaningfully scale Impact-type stomp, body-slam, tackle and trampling damage when a physically valid contact lands.** The added mass from worn armor, tack, saddle, rider and cargo is not cosmetic: it can strengthen body-weight attacks, with **diminishing returns or capped multipliers** and contact animation rules. **Tradeoff:** heavier loads reduce acceleration/turning, potentially sprint/recovery and staminal endurance, making an attack easier to sidestep, and limiting other cargo/rider capacity. Thus an armored Brontosaurus **hits harder on foot contact** but becomes **slower to reposition/aim that foot**. A strike only affects bodies the animated foot/shoulder actually intersects, never a passive 'walk close to enemies and everyone dies' aura. A heavy but stationary dinosaur can stomp effectively; a tackle needs closing speed, direction, commitment and mass. This meaningfully distinguishes stomp and tackle without duplicating damage bonuses from momentum/gear. A fast lighter mount can still evade and outrun giant footfalls.

## 5. Showcase: heavily armored Brontosaurus

**User's design fantasy:** a future **distinct Brontosaurus** (not current Brachiosaurus) is naturally an **Exposed/Slash-weak enormous-HP soft giant**, uses **DS long-reach tail whip** and **MI close stomps**, can trample groups of Compys and pin medium-sized dinosaurs under a properly landed footstep. With fabricated plate armor, it becomes a formidable **slow mobile fortress**, but no universal best build.

**Three comparable builds (qualitative):**

| Brontosaurus outfitting | Where defenses are strong | What it sacrifices | Who/what counters it |
|---|---|---|---|
| **Barehide / Unarmored** | Massive inherent HP, huge reach | Flesh exposed along torso/legs | **Slash**, especially controlled sustained attacks or rider hit-and-run during recovery |
| **Light harness / partial leather** | Selected flank/saddle/pad coverage | Some speed/stamina/cargo headroom; still vulnerable | **Slash or Pierce** at Light-protected locations; exposed legs still **Slash** |
| **Heavy plate war barding** | Plate-covered back/flanks/shoulders become **Heavy**, strongly mitigating Slash/Pierce and **rejecting pounce-based pins at those zones**; real added mass enhances connected **MI stomps/body impacts** | High material/fitting/repair burden, reduced rotation/acceleration and tail recovery, larger stamina cost, less cargo headroom and easier-to-avoid committed footfalls | **Impact** against plates; **Slash** at uncovered/exposed lower legs/underside/tail joints if reachable; evade and punish slower stomps, break material components |

**Combat example:** A heavily plated Brontosaurus advances slowly across open ground. The giant **still** has huge **DS whip reach** and lethal **MI footprints**. Small enemies could be trampled if they cluster and fail to evade; a medium dinosaur that is actually caught under a descending foot may be knocked down and temporarily **Pinned**, then threatened by the next physically valid stomp. Its heavy armor makes casual close Slash less effective on covered flanks, but its lower legs are exposed and need careful protection; attackers bring **MI/DI Impact** on plated torso or **MS/DS Slash** at exposed zones. A lightly equipped Gallimimus with a rider may dodge tail whip, score a timed strike to the soft lower flank, then exit before another stomp. The armored sauropod protects its rider from some side attacks, but sacrifices turning speed, mobile retreat, transport capacity and material investment. It feels more like a **siege fortress** than a faster, invincible version of the bare giant.

**Main balance tension:** Should a slow armored Brontosaurus still be the ideal anti-armored-titan guard in open flat terrain while a bare one is better at mobile tail-whip defense and travel? The trade-off must be tangible at reasonable relative levels and not rely solely on rare ammunition/repair fees. Material traits should reward carefully chosen armor locations, e.g., armored back with intentionally flexible lower leg/tail zones to preserve a whip's reach and recovery.

**Avoid a biology mistake:** adding gear doesn't change the dinosaur's natural species classification; it changes local effective protection at covered parts. The effective damage family **can differ by hit location**. Natural mass remains high, while carried load incurs meaningful handling costs.

## 6. Archetype implications, including raptor signature pounce

- **Cavalry / Courser:** light armor allows speed and **MP Momentum Strike**; heavy armor risks losing its main reason to exist. Enemy giant's stomp can crush the mount, so speed remains protection.
- **Skirmisher / Flanker:** agile light gear, **Pounce -> brief control -> aimed rake**, especially against weakly defended prey, but no free size-dominant pins.
- **Charger / Breaker:** natural large mass, heavy commitment and Impact/Pierce charge; medium armor may be optimal due to run-up and recovery. Truly heavy plated Charger hits hard but becomes steerable by opponent's sidesteps.
- **Bulwark / Tank:** natural heavy plates + crafted layered protection can hold space, but encumbrance reduces escape/pursuit; Impact remains preferred plated counter, vulnerability to huge Titan's stomp remains.
- **Berserker / Ravager:** raptor/cat **Pounce -> Pin -> Maul**, direct melee Slash contact enables **Frenzy** consecutive-hit damage cap. Heavy armor might reduce speed/leap height, interrupt or limit sustained Frenzy exposure, increasing the trade-off between armor and offensive aggression.
- **Tyrant / Apex Dominator:** **owner-confirmed tameable/rideable T. rex** has massive bites and stomps, can pin substantially smaller creatures via a valid foot contact. Still slow-turning, rider high above small ground prey, and not an unstoppable auto-crush aura. T. rex's current species JSON still contradicts owner tamed/mount intent; later code migration required.
- **Titan / Siege Beast:** Brontosaurus/Brachiosaurus-sized enormous body, tail sweep and footprint AoE create a distinct **scale-dependent** combat role. A Heavy plated Brontosaurus trades away some agility and stamina for serious protection, without becoming an invulnerable permanent wall.

**Rider geometry rule maintained:** on a huge T. rex or Titan saddle, a rider's ordinary sword can be too high to reach small ground enemies. Dinosaur stomp/maul is a **separate natural move**, not the rider's invisible melee extension; both use own valid range/hitboxes.

## 7. Engine reality, risks and minimum implementation order

**Observed now, not future promises:**
- `CreatureDef` includes species `real_length_m` and `height_meters`, but has **no explicit body mass / carrying capacity**. `Creature._size_collision()` creates a **single capsule** from length/height; this is **not** separate foot, limb, neck and saddle weapon hit detection.
- `game/data/creatures/velociraptor.json` already animates a heavy pounce that lands claw first and includes `knockdown`/bleed tokens. `CreatureAttack` restricts Velociraptor's knockdown/bleed status to heavy attack. Existing pounce does not yet explicitly use mass ratio, anchored grapple, precise claw contact or physical prey pinning.
- `game/data/statuses.json` already has `pinned` **4 s, `cannot_act`, move multiplier zero, strugglable/pet-assisted**, and `knockdown` **4 s `cannot_act`**; **neither provides a connected foot/contact hold yet**. Existing status engine caps active debuffs at **three** and protects the wild `tyrannosaurus` boss from many control effects. Implement size-based pin carefully so 4-second holds don't become permanent chained locks.
- `Inventory.equipped_armor()` supports flat **human** Head/Body/Legs defense only; currently no reptile barding slots, carried-gear mass, body-zone protection or armor mobility penalty. `Creature` already computes movement from creature speed and status multipliers, which provides a seam for load-based modifiers without renaming IVs.
- `Player.mount()/dismount()/_mounted_move()` has basic ride controls, but rider+mount pair damage, mounted lance momentum and weight interplay described here are **not implemented**.
- The separate future **Brontosaurus** has **no creature JSON and no tail whip animation**; it must remain distinct from the current Brachiosaurus `titan`, which has 90k HP, 500 defense and stronger-than-flesh Slash resistance from `giant` counters.

**Recommended staged implementation:**
1. Define **mass estimates** and **comfortable carried-load capacity** for selected existing species without affecting combat, save safely with defaults, and test speed/carry load calculations.
2. Prototype **true per-foot hit volumes + telegraphed stomp** on an existing large creature, including Compy swarm contact vs medium target short pin and clean release/escape.
3. Extend one existing raptor heavy pounce to an explicit **size-relative pounce/knockdown/pin -> bite/rake** with a limited control window and defenses; protect raid bosses and avoid instant infinite pins.
4. Prototype **two barding weights (Light and Heavy)** on one realistically rideable dinosaur, with visible coverage, durability and fewer load-controlled mobility knobs. Then consider Medium and per-material traits.
5. Only after success, author an explicitly **new Brontosaurus** with long **DS whip**, **MI stomps**, soft unarmored hide and fitted heavy plate variant; tune two-counter hit zones and loss/repair economics.
6. Measure interactions with **Melee Slash Frenzy**, MP Momentum, DI Longshot, three companion composite slots, mount size/rider reach, AI and rider targeting. Test standing under a foot, multiple Compys within footprint, rescue/disruption, and heavy-load exploit cases.

**Acceptance criteria before calling this complete:** A raptor cannot perma-pin a T. rex; a planted Titan foot can hit multiple Compys only if inside its footprint; a medium animal pinned under a foot is released on valid release actions; full plate on Brontosaurus measurably increases protection **and** decreases some maneuverability/available load; heavy armor has correct relative counter vs Impact and exposed sections still reward Slash; boss fights retain possible evasions/recovery rather than inevitable one-shot crush; rider+mount remains one composite expedition unit; old JSON saves, statuses and capture permissions still work.

## 8. Owner refinement: MASS DAMAGE and HEAVY POUNCE DEFLECTION (2026-10-25)

**Strong owner decisions on qualitative behavior:**
1. **Weight is an offensive asset.** Body mass plus fitted carried gear **must scale** real **MI stomp, tackle, body slam and trample** damage on successful contact. Do not treat weight only as carrying penalty. More plate on an otherwise identical Brontosaurus makes the landing foot/body blow more devastating, while adding vulnerability to poor maneuvering, stamina drain and inability to run down evasive targets.
2. **Heavy armor hard-counters ordinary pounce pins.** A properly covered intact Heavy target can still be pounced **at**, but the pouncing raptor **bounces/deflects and backs off**, unable to knock it down and pin it into the normal maul/gore follow-up. This is a distinct behavior, animation and positioning counter, not a numeric chance-to-resist only.
3. **Mechanics depend on what really contacts.** A Heavy plate at the pounce-contact surface blocks the hold. A missing/failed plate doesn't magically protect the rest of the creature. A far heavier predator can still use a *distinct* jaw/body stomp/crush after telegraph/collision checks; don't grant ordinary raptor pounce the ability to ignore Heavy armor by mass alone.

### A. Proposed effective-mass attack model (NOT a locked formula)

`total_physical_mass = natural_body_mass + physically_carried_armor + saddle + carried_rider/cargo`, measured from the current equipment and species data; no "fake weight" trait with no actual load. **Physical mass** is distinct from `load_ratio = carried_load / comfortable_capacity`.

- **Stomp, grounded crush, planted-foot trample (MI):** Attacking foot's supported body weight / force transfer, contact area and state determine damage and whether a target of smaller relative mass is knocked down/pinned. More total mass makes the same properly landed stomp stronger; **mass-based scaling uses a soft curve and hard cap** rather than linear unbounded weight stacking. Track attack foot/collision geometry; actual load distribution and foot contact matter.
- **Tackle/body slam/shoulder check (MI):** Scale by **effective body mass + forward closing velocity + aligned shoulder/body impact**. A nearly stationary body check still hurts if huge, but a charging heavy animal may hit dramatically harder. A heavy suit reduces speed and maneuvering, so heavy can't automatically max damage and accuracy at once.
- **Mounted spear/lance (MP):** Existing momentum condition uses mount velocity, bracing and controlled impact; **don't double-add every kilogram already accounted for in the mass-based charge** when rider and mount strike in same synced action. The lance is Pierce, whereas dinosaur shoulder tackle is Impact.
- **Tail whip (DS) and other appendages:** Not **full dinosaur mass**; relevant moving tail/limb mass, tail speed, control and accuracy. Adding plate to torso shouldn't triple the tail's force unless the actual tail segment's mass/effects change.
- **Pin eligibility:** Compare **natural/physical relative mass**, limb leverage and valid animations, then check defender **Heavy plate deflection** for **pounce**; the mass ratio cannot silently bypass pounce protection for a normal pounce move.

**UI:** show creature `Body Mass`, `Load` and `Impact Power` (or concise derived tag) rather than force players to infer changes from invisible raw mass. The weight increase should visibly raise the stomp/body-impact attack tooltip while reducing e.g. Turning/Charge handling under encumbrance.

### B. Pounce resolution state machine

1. Raptor telegraphs and leaps with a valid **Pounce** move. Use real landing position and hit geometry. A miss or dodge leads to a committed recovery.
2. On connection, inspect target hit region and **effective protection**. If **Heavy** with sufficient durability/coverage, emit **DEFLECTED POUNCE**: no grapple, no `pinned`, no Pounce-caused `knockdown` that would feed the same free maul sequence. Optional mitigated contact chip damage/durability wear can still resolve.
3. Force **Recoil -> Back-off / Reposition** on the pouncer, with limited re-engage timing so it cannot spam permanent bounce attempts. The target can counterattack or use the window to escape. Must have a visible/reliable animation and AI response, not a silent failed status proc.
4. If the struck location is **not Heavy protected**, resolve the usual size/leverage/stamina check; successful Pounce can **Knockdown -> Pin -> Maul/Slash rake or Pierce bite**, including compatible Berserker Frenzy only for actual landed melee Slash strikes.
5. If **Heavy armor becomes broken** or the target presents an uncovered flank, subsequent pounces may work, but only via actual contact with the now-vulnerable region. **Tackle/ram/crushing/jaw-grapple** are separate moves which should have their own collision and control rules, not a loophole that gives ordinary pounce guaranteed pin.
6. For wild/pet pack AI, avoid feeding endless Pounce attempts into a Heavy target. Raptor should **recognize failed grabs**, withdraw/seek exposed weak area, use alternate Slash/Pierce strikes, switch targets or let a heavier ally handle armor. Otherwise Heavy armor nullifies the encounter with boring AI.

**Practical game impact:** a **lightly armored Frenzy Berserker** still excels at chaining slashes and leaping onto exposed prey; a **Heavy armored Bulwark** is a natural defensive counter against that signature attack, but is slower and susceptible to **Impact**. Thus armor protects and creates tactical interactions, not just percentage damage reductions.

### C. Armored Brontosaurus with offensive weight reward

**Bare Brontosaurus:** easier to attack with Slash, more agile (relative to a loaded Titan), lower contact force but still devastating via natural body mass, easier tail repositioning.

**Heavy-plated Brontosaurus:** plate covered flank ignores raptor pins, covered parts resist Slash/Pierce, **added armor mass increases MI stomp and aligned body tackle power**, and can trample a group of tiny dinosaurs whose hurtboxes overlap the planted foot. Costs are slower steering/acceleration, longer commitment/recovery and expensive gear plus repairs. Tail whip depends on actual tail properties rather than all armor mass. An agile Cavalry rider exploits slow repositioning, approaches exposed leg/underside and escapes before the high-damage foot impact; a DI/MI Impact weapon punishes plate.

**Balance invariants:**
- `Heavier => stronger actual stomp` must be noticeable for same species/stomp frame while `heavier => worse mobility/energy` must matter for chasing/dodging/aiming; the **expected combat performance is not automatically strictly higher** when more armor is equipped.
- `Heavy pounce rejection` is **reliable**, not a tiny random proc, when plate really protects the pounce hit region and has durability.
- `Heavy` can still take Impact damage, stagger, be legitimately physically displaced or crushed by a **different** much larger attack; this does not turn into permanent pin immunity or body weight immunity.
- No infinite damage from transferring overfull cargo into a heavy mount; mass is capped/normalized and meaningful load encumbrance, not stacking an arbitrary item inventory number with no physically modeled cargo.
- Existing `CreatureAttack` applies status tokens separately from damage, and current Velociraptor pounce heavy applies `knockdown` before damage resolution. **Heavy armor contact rejection must happen BEFORE a pounce-generated knockdown/pin is applied**, not after status already landed. Preserve current T. rex boss control immunity and 3-debuff cap.
- Rider + mount remains **one composite expedition unit**, with no full free simultaneous ram + lance + stomp double-counting the same kinetic event.

**Requested behavior is approved as qualitative design direction; numbers, exact protection regions, mobility losses, AI states, damage/stagger ratios and data migrations remain UNAPPROVED. No runtime files changed.**

## 9. Owner refinement: relative-mass stomp mitigation, stability and armored approach (2026-10-25)

**Qualitative rules from owner, adopted as design direction:**

1. **Stomps/body-weight attacks are two-sided mass contests**, not fixed damage. Heavy **attacker** mass improves the force/damage of a planted stomp, tackle or body slam; heavy **defender** mass lowers **damage received**, the knockback and likelihood of a stagger/knockdown. Calculate the attacking and defending combat masses **at impact**, including meaningful physically carried armor/saddle/rider/cargo, but keep sane damping/caps.
2. **A similarly massive and adequately armored defender should often stand firm** when struck by a stomp that would flatten a tiny/light creature. Heavy gear improves **stability/poise**, preventing ordinary stomp staggers under a sufficient mass/stability threshold (rather than just reducing animation duration). This makes reaching a powerful enemy feasible through **uninterrupted forward pressure**, even as Heavy gear makes turning, sprinting and evasive reactions worse.
3. **Heavy armor still blocks ordinary raptor Pounce -> Pin** at genuinely protected impact zones; this is a distinct **contact/hold deflection**, not identical to the mass-based stomp mitigation or poise mechanics. Ordinary stomps, tackles, piercing attacks and large jaw grabs still have their own rules.

### A. Coherent hit-resolution order

1. **Is there a hit?** A real animated planted foot/shoulder/horn needs target contact; attack telegraph and dodge remain valid.
2. **Which physical move?** Stomp/trample (MI), body tackle/ram (MI) or weapon-based lance/arrow/slash; only **body-weight attacks** receive this specific attack/defense mass contest, not every Impact move. A small handheld hammer still uses the weapon's own force and armor matchup.
3. **Read attacker effective mass and defender effective mass** from natural physiology plus actually supported carried gear, with a carrying/encumbrance burden that scales relative to species. Use a **bounded mass-advantage curve** (e.g. attacker_mass ÷ defender_mass after safe clamping/log compression), not an unbounded raw ratio. When **defender mass increases**, held attacker attack/animation/velocity constant, **received stomp damage decreases**.
4. **Calculate body contact severity** from move, support stance, relative forward velocity for tackles, planted-foot momentum for stomps, and actual foot/shoulder contact location. Don't count full attacker mass and then multiply by the full same mass ratio a second time: double-dipping creates absurd numbers.
5. **Apply covered-zone armor as its own protection layer** on HP damage. The existing **Impact is relatively favored against Heavy plate** combat matchup still applies to **plate destruction, posture or local damage vs Slash/Pierce** where appropriate; it does **not** cancel a heavy defender's separate fundamental **mass advantage against a smaller body's stomp**. Avoid simultaneous full flat armor + whole-body mitigation + percentage reduction making every Heavy enemy immortal.
6. **Resolve stagger/knockback separately from HP.** Compare delivered impact impulse with defender **stability/poise** (body mass, stance/bracing, species behavior, Heavy armor integrity and terrain). Ordinary stomp may damage a well-armored heavy mount yet **not interrupt or push it backward**. An overwhelmingly larger attacker, exposed joint, forced off-balance state or powerful enough committed stomp can still cause stagger. Do not make Heavy universal boss-stomp immunity.
7. **Resolve pin/trap state independently:** only if mass ratio, foot/body hold geometry and escape rules permit; Heavy body armor's **raptor Pounce deflection** occurs before any pounce-related Knockdown or Pin status.
8. **Set counterplay/recovery:** stance/rider-controlled bracing, side-stepping huge feet, aggressive light mount flanking, or target disengaging remain relevant. Wearing too much gear makes chasing, repositioning and fleeing harder.

### B. Armor and body mass roles are intentionally different

| Defender | Comparable attacker stomp | Attacker much heavier | Tactical identity |
|---|---|---|---|
| **Light fast Courser / raptor** | Higher recoil, stagger and damage than a heavy/braced peer, but can usually escape a telegraphed footprint more readily | Dangerous/crushing direct stomp if caught | Dodge the hit |
| **Medium armored Charger** | Moderate attenuation to HP/stagger with physical mass and brace | Can still be knocked aside/pinned if physically outmatched | Choose timing and committed return charge |
| **Heavy Bulwark/Tank** | Significantly lower received stomp force/damage, high poise; **often no stagger** so it can keep closing | Huge titan foot can still stagger/damage if mass advantage and footprint are sufficient | Endure contact and press forward |
| **Enormous armored Titan** | Great stability and less relative-mass body damage | Counter-titan collisions still threatening; enormous exposed or vulnerable body parts | Slow moving fortress, but poor agility/turning |

**Illustrative comparison, NOT approved percentages:** The SAME stomp landing on a Light Utahraptor versus a substantially heavier plated Triceratops should do **materially less HP damage and often fail to stagger the Triceratops**. If the exact same Triceratops changes from Light load to Heavy plate, **its stomp resistance goes up** and its movement/recovery suffers. If a Brontosaurus stomps a human in Heavy armor, however, the mass mismatch remains so vast that gear usually cannot prevent severe damage just by adding a small amount of weight.

### C. New close-combat fantasy and constraints

- **Tank/Bulwark bonus is 'Unstoppable Approach' (working descriptive name, NOT another damage type):** It doesn't literally move faster. It is **less frequently interrupted by smaller/equal-weight stomp or tackle effects**, so it can maintain *net forward progress* and reach enemy weak zones in a hostile advance.
- **Exposed attack routes remain meaningful:** Heavy Brontosaurus barding on the back/flanks counters Slash there, but Slash against an exposed leg may still work; Impact attacks remain strategically preferred against its covered plating when attacker force and gear allow.
- **Brontosaurus armor load affects both sides:** Heavy armor raises its own stomp force, raises defensive stability and mass mitigating similarly sized stomps, but burdens tail/body turning, accelerations, endurance and cargo. It still cannot sidestep a fast flank attack like an unburdened lighter dinosaur.
- **Armor cannot create infinite mass:** Gear only contributes actual defined physical mass within sane load constraints. A mountain of backpacked rocks cannot indefinitely overpower a larger dinosaur or stack invisible armor/stomp multipliers. A tiny dinosaur in Heavy barding does not become T. rex-sized.
- **Tactical difference:** Courser earns safe contact by avoiding stomp; Bulwark earns safe contact by sometimes withstanding a stomp without stagger. Both can be valid, with very different speed, stamina and resource costs.
- **Visual feedback:** `STAGGER RESISTED`, clear grounded brace/impact animation, `HEAVY POUNCE DEFLECTED`, a damage float that reflects mass matchup, and optionally `Impact Force`/ `Stability` in creature inspection. Do not hide no-stagger outcomes behind animation bugs.

**No numeric formula locked:** body mass estimates, added gear contribution, soft curve, no-stagger thresholds, stance/bracing, damage type interaction, pounce location checks and player/mount controls require prototyping.

## 10. OPEN for owner refinement

- Is player-visible **weight** best shown as **Mass + Carry Load + Encumbrance%**, or only **Load** to keep UI compact? Recommended visible `Load x/y`, show mass details in Codex.
- Which animals have anatomy that **actually permits pinning**, and when is footpin a ground control move versus crushing trample? No species-wide universal foot aura.
- Does a **medium-size victim escape** through individual stamina/Might/struggle, a combat skill, ally rescue or all three, with no arbitrary full four-second helplessness?
- Armor zones: simplified **Front/Side/Legs/Tail** hit regions versus precise anatomical mesh collider coverage, and whether the rider can target weak leg locations in a full mobile fight.
- **Resolved qualitatively by owner:** Added actual mass SHOULD strengthen valid stomps/tackles/other body-weight attacks, not only burden the animal. **Still open:** nonlinear scaling/cap, movement cost, body-part force contribution and meaningful trade-offs.
- Exact weight class thresholds, acceleration penalty, turn rate, whip tail recovery, endurance, terrain/heat and fatigue cost caps remain undecided and require playtesting.
- **Newest owner resolution:** heavier defenders **take less stomp damage and are harder to stagger/knock back**, especially with Heavy plating and bracing. Open are the bounded relative-mass function, stability thresholds and how much armor plate and stance matter versus sheer physiological mass.
- Future Brontosaurus's capture/taming/saddle sizes, armoring restrictions and availability are separate unimplemented questions.

**This is game-system design only. No runtime file was altered.**
