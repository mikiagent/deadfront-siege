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
- `comfortable_load` (species/size/endurance-derived): denominator for **encumbrance = carried_mass / comfortable_load**; distinguish *load handling cost* from mass available to a collision. Gear adds some effective physical mass but should not scale stomping power linearly without control.
- `body_profile` plus **zones** (`head, torso/flanks, neck, legs, tail` as actually available by model/rig), with each worn piece specifying supported slot, covered zones, protection class, durability and weight.
- `mass_class` may be a player-facing shorthand (Tiny / Small / Medium / Large / Giant / Titan) if needed, but rules should use **relative mass and actual contact geometry**, rather than brittle fixed tags that ignore growth, unusual body builds and equipment.
- Character **Might/Dexterity IVs** are separate from *physiological body mass*. A very strong small raptor can grapple above its expected size somewhat but cannot automatically pin an entire Triceratops. Learned wrestling/training, balance, current stamina and momentum influence control. Body mass is not a third combat damage type or replacement IV.

**Practical accuracy:** Do not run full simulated rigid-body mass/weight physics for every creature. Use data-driven mass, stamina, load ratio, body contact and predictable checks; preserve existing movement and animation reliability.

## 2. Trample / Pin / Pounce / Gore are *move mechanics*, not a fourth damage type

| Move | Who may use it | Contact requirement | Outcome | Counterplay |
|---|---|---|---|---|
| **Trample** | Giant feet, heavy Charger/large animals when animation supports it | Animated foot/body sweep **overlaps actual grounded hurtboxes** | Contact **Impact** damage and potentially hits **multiple tiny enemies** in one footprint | Feet telegraphed, run out of indicated footprint, avoid crowded lanes |
| **Heavy Pin** | Attacker substantially outweighs defender and can physically restrain it | Foot/limb anchored on grounded target, species attack clip supports hold | Short **Pinned** restraint, follow-up **Impact stomp** or anatomy-compatible **Pierce gore / bite** if in reach | Dodge onset, resistance/struggle by size/Stamina, ally stagger/distraction, release on lifted foot |
| **Pounce / Tackle** | Raptor, feline, agile predator with leap animation | Trajectory intersects target and size ratio plausibly allows purchase | **Knockdown**, then **Pin** if target small enough and attacker stays engaged | Side-step leap, brace/counter, fight back, recover after predator commits |
| **Maul** | Raptor/feline with jaws and raking claws | Predator holds or repositions near target, real bite/claw contact | **Pierce bite** or **Slash rake**, maybe Bleed and Berserker Frenzy; not a free separate universal damage type | Escape pin, interrupt creature, punish attack recovery |
| **Gore** | Horn, spike, tusk, beak or penetrating jaw move when anatomy supports | Penetrating point actually reaches target or pinned body | **Pierce** damage with possible injury; enhanced follow-up from target's restrained state | Avoid weapon point, defend protected body zone, escape target restraint |

**Terminology:** Raptor's iconic sequence is **Pounce -> Pin -> Maul/Rake**, where the claw rake is **Slash** and penetrating bite is **Pierce**; horned dinosaur **Gore** uses **Pierce**. If the UI wants `Gore` for a raptor's teeth, label it a bite/maul variant, not a universal animation shared with horns. A **Brontosaurus is not a carnivorous goring animal**: it tramples/stomps and maybe keeps a target underfoot; don't invent teeth/horns for a gore finisher it cannot perform. A **T. rex** can use its actual jaw geometry to follow a pin with **MP bite** if its head and the target position really meet.

**Relative-size results (qualitative, no universal threshold yet):**

| Contact matchup | Likely possibility | Special cases |
|---|---|---|
| Giant vs many **tiny** enemies | One footstep can **hit many** tiny bodies actually within its footprint; high Impact and possible instant incapacitation in severe mismatch | Giant must plant that foot, not execute a full-circle area attack when merely walking |
| Giant vs **medium** animal | Target may be **knocked down and pinned**, threatened by next foot or compatible follow-up attack | Body parts/weight distribution matter; a giant's mere proximity does not always pin |
| Raptor vs **smaller** prey | Strong chance to tackle, pin and maul after proper leap/contact | Counterplay and finisher recovery, no infinite lock |
| Raptor vs **similar-sized** prey | Contested brief grapple/knockdown; resistance, Might and stamina matter | Strong defender can shove off or survive; neither guaranteed |
| Raptor vs **much larger** prey | Can latch on or rake exposed tissue in a precise window, **but cannot pin the entire giant** | Large prey can shake, roll, whip or dislodge the attacker |

**Three status states:** **Knockdown** = knocked off balance or prone; **Pinned** = mechanically restrained by a **specific physically valid hold**; **Exposed** (optional follow-up vulnerability modifier, not necessarily a new status slot) = certain attacks can more effectively contact a vulnerable local body part. Existing status `pinned` already exists with `cannot_act` and `move_mult=0`, and `knockdown` exists. This **does not mean** the engine currently tests attacker-vs-defender mass, keeps a foot anchored, applies multiple footprint hits, or exposes finisher positions. Avoid just spamming `pinned` for every heavyweight encounter.

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
| **Heavy barding** | High durability and resistance over fitted zones | Slower **acceleration and turning** and/or higher **stamina usage**; reduces sprint/reposition and cargo or rider load headroom | Bulwark, Tyrant, armored Titan |

**Do not penalize too many mobility stats at once.** A single load ratio can impact a small number of primary knobs (e.g., turn/acceleration and sprint stamina consumption); long list of stacked speed/turn/dodge/regen penalties may make heavy armor useless. A naturally slow Titan may have minimal sprint to begin with, so **turn recovery, time to rotate the body/tail, stamina exertion, and logistical material cost** are better knobs than only reducing top movement speed.

**Weight and trampling:** more carried mass can increase impact slightly when a proper footstep actually lands, but a heavy, exhausted loadout may make that step **easier to escape**. It should never give unlimited +HP +armor +crushing damage while retaining agility. Trampling depends on **footprint contact, relative mass, stance and animation**, not a global passive collision murder aura. A fast lighter mount can still evade and outrun giant footfalls.

## 5. Showcase: heavily armored Brontosaurus

**User's design fantasy:** a future **distinct Brontosaurus** (not current Brachiosaurus) is naturally an **Exposed/Slash-weak enormous-HP soft giant**, uses **DS long-reach tail whip** and **MI close stomps**, can trample groups of Compys and pin medium-sized dinosaurs under a properly landed footstep. With fabricated plate armor, it becomes a formidable **slow mobile fortress**, but no universal best build.

**Three comparable builds (qualitative):**

| Brontosaurus outfitting | Where defenses are strong | What it sacrifices | Who/what counters it |
|---|---|---|---|
| **Barehide / Unarmored** | Massive inherent HP, huge reach | Flesh exposed along torso/legs | **Slash**, especially controlled sustained attacks or rider hit-and-run during recovery |
| **Light harness / partial leather** | Selected flank/saddle/pad coverage | Some speed/stamina/cargo headroom; still vulnerable | **Slash or Pierce** at Light-protected locations; exposed legs still **Slash** |
| **Heavy plate war barding** | Plate-covered back/flanks/shoulders become **Heavy**, strongly mitigating Slash/Pierce; shielded rider platforms | High metal/scute resource costs, fitting/repair needs, reduced rotation/acceleration and tail recovery if weight loads moving segments; likely more noticeable stomp/tail tells and less ability to escape | **Impact** against plated parts; **Slash** at uncovered/exposed lower legs, underside, tail joint, or neck if reachable; riders can break material components, exploit recovery and position |

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

## 8. OPEN for owner refinement

- Is player-visible **weight** best shown as **Mass + Carry Load + Encumbrance%**, or only **Load** to keep UI compact? Recommended visible `Load x/y`, show mass details in Codex.
- Which animals have anatomy that **actually permits pinning**, and when is footpin a ground control move versus crushing trample? No species-wide universal foot aura.
- Does a **medium-size victim escape** through individual stamina/Might/struggle, a combat skill, ally rescue or all three, with no arbitrary full four-second helplessness?
- Armor zones: simplified **Front/Side/Legs/Tail** hit regions versus precise anatomical mesh collider coverage, and whether the rider can target weak leg locations in a full mobile fight.
- Should heavy load improve **trample force slightly** through physical mass, or should it always only hinder mobility and burden, relying on innate mass for stomp strength? Avoid making plate both maximum offense and defense for free.
- Exact weight class thresholds, acceleration penalty, turn rate, whip tail recovery, endurance, terrain/heat and fatigue cost caps remain undecided and require playtesting.
- Future Brontosaurus's capture/taming/saddle sizes, armoring restrictions and availability are separate unimplemented questions.

**This is game-system design only. No runtime file was altered.**
