# 12 | Mounted combat, dinosaur threat zones and primitive weapon progression

**Status: OWNER DIRECTION + GAMEPLAY PROPOSALS, 2026-10-25.** This design records the owner's latest goals (not an approved final combat formula, tech cap or implementation): **Might matters most in early primitive survival**, **Dexterity gains a wider toolset later**, the civilization may **remain substantially primitive**, and **mounted human/dinosaur pairs should make close-range dinosaur combat desirable and viable** rather than forcing all high-tier encounters into ranged-only play. A huge sauropod should remain terrifying because of **size, attack reach and high-damage tail-whip and stomp zones**. Do NOT infer permission to implement powered exosuits, automatic guns, launchers or a futuristic tech tree from the earlier thought experiments.

**Owner-approved existing foundations (independent of new proposals):** **Dexterity D = control; Might M = force**, both inherited IVs. **Impact I = disrupt; Pierce P = penetrate; Slash S = shred** as attack categories (DI, DP, DS, MI, MP, MS). Delivery mode and attack speed are independent. Defense-band proposal **Exposed -> Slash; Light -> Slash/Pierce; Medium -> Pierce/Impact; Heavy -> Impact**. Expedition has **three shared companion slots**; a **human+dinosaur mounted pair occupies one slot** and trades away some autonomous dinosaur offense for rider-directed tactics. Existing owner's heuristic **1+1 feels about 1.5**, not a literal multiplier. See [Tribe and mounted expedition](../design/tribe-lineage-domain-and-labor.md) and [decision register](decisions.md).

## 1. Progression by social/technological capability, not modern gun escalation

The **civilization's possible primitive ceiling** should allow exceptional genetics, knowledge, refined materials, training, breeding and rider-dinosaur coordination to provide powerful *late-game progression even without industrial firearms*. Specific age-of-technology ceiling is **OPEN**.

| Phase | Might character strengths | Dexterity character strengths | What makes the next phase feel earned |
|---|---|---|---|
| **Early, improvised survival** | Clubs **MI**, axes **MS**, sturdy spear **MP**, heavy tool use and powerful unaided strikes | Sling **DI**, thrown weapons **DS/DP depending contact**, basic bow **DP**, accurate positioning | Build tools, understand dinosaur threats, tame first practical companion |
| **Middle, refined weapons and first coordinated mounts** | Metal maul **MI**, steel spear/pike **MP**, battleaxe **MS**, shielded/frontline control; ride for controlled lance/impact | Improved/compound bow **DP**, reinforced slings, crossbow **DP**, whip or precision thrown blade **DS**, mobile shooting | Specialized tailoring/smithing and riding; one pair fights as a coordinated unit |
| **Late, primitive-or-advanced-medieval specialist mastery** | Masterwork heavy polearms/halberds, armored mounted charge **MP**, crushing mount-assisted strike **MI**, cleaving heavy blade **MS** | Strong crossbows, repeaters **DP** (with handling/capacity constraints), compact accurate weapons, specialized ranged control/suppression (not arbitrary bullet Slash) | Superior breeding/IV aptitudes, trained mounts, material traits, teamwork, timing and learned combat skill |
| **Optional industrial future** | Carried siege tools/early hand cannon if eventual world tech supports them | Firearms, mechanical launchers if later approved | **Not an approved endgame assumption.** Prior Gatling/rocket/minigun/exosuit experiments are exploratory only |

**Important:** The game should not automatically make Might strictly numerically stronger at every early level or Dexterity numerically stronger at every late level. Instead give Might more immediately accessible low-tech *effective* equipment and survival actions, while Dexterity earns varied ranged control and specialized weapon modes as infrastructure and skills unlock. Might **continues** to improve through forged materials, training, riding, armor, strong beasts and team timing. Do not nerf raw genetics at level 60 or force all Might builds into obsolete melee.

**Core anti-ranged-dominance constraints to evaluate** (all proposed): stamina/ammo/resource logistics, safe firing lanes, reload and aim while moving, line-of-sight blocked by foliage/animals, late boss attack reach and agility, distraction by allies, danger of poor shot placement, defense windows vs counterattack recovery. Don't globally give melee inexplicable extra damage; make its successful close-range play rewarding in coverage, stagger, anti-armor and sustained hit uptime when tactically earned.

## 2. Brontosaurus as a multi-range threat, not a stationary HP sponge

**Owner-described design fantasy, for a FUTURE separate Brontosaurus species:** huge HP, low natural armor/defense (relative to size), Slash-friendly contact, but **enormous reach** and dangerous huge hit volumes. **DS long tail whip** and **MI stomp** are offensive move archetypes; their reach/coverage and damage matter more than HP alone. This creature is NOT existing Brachiosaurus, which currently has `titan` protection, stomp animations and a different Slash resistance.

**Suggested telegraphed attack/positioning space, not approved numbers:**

| Position/range | Threat | Response for a skilled foot player | Response for a skilled mounted pair |
|---|---|---|---|
| **Outside visible tail/leg reach** | Infrequent direct contact, but terrain and advance still require choices | Observe windup, seek an opening or coordinate ally distraction; ranged remains useful | Approach at a chosen angle and speed, watch for tail telegraph |
| **Rear/side tail arc (long reach)** | **DS tail whip**, wide sweeping arc, heavy damage/knockdown risk even at range | Read tail windup, break line/duck behind defensible terrain if allowed by collision, dodge at correct timing rather than just running straight in | Change heading using mount acceleration and lateral distance; some mount sizes/speeds dodge the arc better; mounted rider still at risk of being hit/dismounted |
| **Under body / near legs (close)** | **MI stomp**, concentrated high damage, danger to both mount and rider | Footstep telegraph, dash from the indicated footprint and exploit recovery; riskier to maintain damage uptime | Larger/tougher ride can reposition between legs or cover an exit lane faster; must still respect huge hoof-foot collision and splash; mount legs are **not** immune |
| **Flank after missed whip/stomp** | Short **attack opportunity** if giant has recoverable commitment | Heavy polearm/Slash specialist reaches soft leg/flank; team staggers aggression | Rider can deliver mounted **MP spear/lance**, **MS cleaving strike**, or mount-assisted slam while movement maintains line and safe window |

**One way to make large reach honest:** The whip may threaten a large outside annulus; simply 'stay at range and shoot' should not be perfectly safe. Simultaneously, walking into melee should not instantly kill a skillful player with an unavoidable stomp. Both whip and stomp need legible distinct telegraphs, collision footprints/arcs, commitment and recovery. Design a real window to exploit, not an arbitrary invulnerability pocket. A large mount reduces some *mobility/height* limitations but does not nullify stomp damage; the mount's body can be a larger hitbox and tail whips might clip rider and mount.

**No guaranteed safe zone:** Giant has variable animation direction, tail sweep and multiple leg attacks, but must not have an instant untelegraphed 360-degree punish; fair play requires anticipation and angle control.

## 3. Why a mount makes melee competitive

**Preferred design logic:** A mounted human gains **positioning, movement, attack reach/elevation and weapon uptime** in ways a foot fighter can't, not a simple '+50% weapon damage while riding'. Specific mechanics for testing:

- **Approach/survival:** can cover lateral distance or disengage from stomp footprint faster; riding may put the human above some ground-level hazards, *subject to mount's actual height and hitboxes*. Dinosaur and rider remain independently damageable.
- **Reach/access:** a rider with a spear/long blade can strike weak flanks/upper legs from a steadier height, while a foot user must choose risky near-leg attack windows. Does NOT imply a medium mount magically reaches Brontosaurus' neck or back.
- **Momentum (Might matters):** spear/lance **MP** controlled charge can use mount forward momentum/acceleration to reward commitment, *without a forced global charge multiplier*; heavy mounted axe **MS** uses passing sweeps, and **MI** mount/body hammer benefits from braced force/impact. A good Mount and good Rider develop synergy rather than overriding their intrinsic IVs.
- **Attack uptime:** move past vulnerable areas and land a timed strike on a recovery beat, exit before next whip/stomp; faster evasion, not free continuous melee DPS.
- **Combined tactical AI:** a mounted pair travels and attacks as one tactical entity; saddle, rider command proficiency and animal intelligence improve directional compliance and attack scheduling. **Reduce independent mount auto-attacks**, prevent extra full rider + animal DPS accumulation. Preserve owner's **1+1 feels ~1.5**, not 3 heuristic.
- **Might scaling:** an early-Might warrior on a sturdy mount can carry/braced-control polearms and heavy cutting tools, hold ground in guard or strike on pass; strong Might IV matters without assuming guns or powered exosuits.
- **Dexterity scaling:** a Dexterity archer can shoot while riding with training and turn to target; mounted DPS is possible but shooting/aiming during high acceleration has drawbacks, so the choice between close physical hits and riding ranged shots remains meaningful.

**Mount drawbacks** are as important as benefits: large mount collision footprint makes near-leg stomps harder to avoid, legs/trunks risk damage, tail sweep may dismount rider, saddle/barding burden slows turns, charges need run-up and clear exit lane, stamina and morale/obedience limits, smaller mounts expose riders differently, injuries/taming costs are real, and losing a prize dinosaur matters economically. A dismounted human still has readable dodge/attack opportunities; **mounts should improve close combat, not become compulsory for any late boss**.

**Companion party rule:** Rider + animal consumes **ONE of the three expedition slots** when deployed as companion pair. Switching mount/dismount must preserve the two constituent inventories, genes, levels, HP, equipment and death states, and avoid double-counting strength. Status KO/rider knockoff and retreat return are still design questions.

## 4. Proposed mounted attack classes in primitive world

| Type | Foot examples | Mounted example | Core reason to use |
|---|---|---|---|
| **MI Might / Impact** | Warhammer, heavy club, shield bash | Heavy cudgel from stable saddle, coordinated mount shoulder check | Plate disruption, knockback at controlled range |
| **MP Might / Pierce** | Long spear, pike, javelin | Braced lance/spear thrust on timed ride-by | Momentum + reach for charges, precision opening against agile targets as appropriate |
| **MS Might / Slash** | Great axe, heavy blade | Ride-by cleaving axe, polearm with blade, larger swinging weapon on sturdy mount | Soft exposed targets; Slash favored vs Exposed/Light |
| **DI Dexterity / Impact** | Slingshot, aimed thrown blunt projectile | Accurate sling/throw from mount (if trained) | Mobility and controlled impact placement |
| **DP Dexterity / Pierce** | Bow, crossbow | Mounted bow/crossbow used on stable motion windows | Controlled ranged target selection |
| **DS Dexterity / Slash** | Whip, thrown cutting tool, light sword swipe | Accurate slashing strike while passing, throwing axe | Soft/exposed/Light targets requiring timing/control |

**DO NOT mandate** that all attacks from horseback/dinosaurback have an invented damage modifier or always use Might. Mode classification stays tied to **what the human is doing**, not their positional stance. If mount itself stomps, that's separate **MI mount move**; thagomizer spike belongs **MP/DP species move**, not the rider's weapon.

**Illustrative mounted counter encounter:** A good Might **MS** armored polearm rider approaches Brontosaurus across the side, dodges the wide whip based on telegraph, enters soft flank during tail recovery, cuts, exits before foot stomp. Simultaneously a Dexterity **DP** human ally draws attention/cover with arrows, and unmounted spear fighter can still exploit stagger. No close-range immunity, no arbitrary flat damage boost; opportunity comes from **rider + mount movement and attack windows**.

## 5. Existing game implementation vs future work

**Verified:** `game/scripts/player/player.gd` has basic `mount(c)`, `dismount()` and `_mounted_move(delta)`; eligibility checks species' `tamed_role` for `mount`, reparents survivor to creature's mount socket, then moves creature based on input. **That does not establish rider weapon attacks, special saddle combat, momentum scaling, per-body incoming hitboxes, cavalry AI or Brontosaurus**. Do not claim these exist.

**Verified mount-eligible tamed-role species in current JSON:** Zebraceratops, Coelophysis, Protoceratops, Velociraptor, Gallimimus, Megaloceros, Deinonychus, Smilodon, Styracosaurus, Utahraptor, Triceratops. Larger **Stegosaurus and Ankylosaurus** currently have `bag/combat` roles **without** `mount`. **The owner explicitly confirms T. rex IS intended to be tameable and rideable**; the current `tyrannosaurus.json` still has `tameable: false`, `capture_tier: 0` and `tamed_role: []`, so the game data is **out of sync with the intended design**, not a valid future design restriction. Existing Brachiosaurus remains non-tameable. This is current data, not a final balanced rideable-animal list. Avoid arbitrarily resizing miniature animals to hold humans; animation/ride eligibility and realistic relative scale require review.

**Implemented species conflict:** [Brachiosaurus data](../../game/data/creatures/brachiosaurus.json) currently supplies giant stomp animation, 90k HP, 500 DEF, `titan` with a strong **Slash resistance** under existing `giant` combat counters. Future **Brontosaurus** must be a distinct soft-bodied sauropod with tail-whip clips and explicit weakness, or designers must explicitly approve changing the current giant rule. Keep the two examples separate.

**Future implementation steps only after owner choices:** choose creature sizes/rideability and attack slots; prototype giant attack telegraphs plus hitboxes and windows; implement mounted rider aim/hit detection and saddle weapon animation; create variable-mass mounted momentum for **MP** if desired; implement rider/mount damage and KO; tune melee/ranged/mounted success over equal time-to-kill and survivability; add animal rider progression/training; save/profile compatibility and 3 companion slot compositing.

## 6. Concrete combat tests, not speculative 'melee bonus'

1. **Brontosaurus vs foot Might/Slash:** riskier but **feasible** via visible side attacks and recovery windows; not perpetual unavoidable stomp.
2. **Brontosaurus vs mounted Might/Slash or Might/Pierce:** significantly **more safe attack opportunities, reach and repositioning** at cost of animal risk, but not guaranteed immunity or universally higher max raw DPS.
3. **Brontosaurus vs bow team:** range isn't a permanent safe refuge from **long wide tail whip**; ammo and positioning are meaningful; ranged tactics remain useful as support or alternative.
4. **Brontosaurus vs mounted Dexterity archer:** mobile accuracy and firing timing tradeoffs; rider height doesn't turn mount into a perfect firing platform.
5. **Early-game balance:** Might club/spear/axe should be accessible before many sophisticated Dexterity weapons without guaranteeing Might defeats a well-played early archer.
6. **Late-game balance:** trained riders and masterwork heavy melee/polearms stay competitive with crossbows/bows in their correct armor matchups; both stats remain useful and relevant.
7. **Three slot rule and composite unit:** a mounted pair **counts as one party slot** while its shared AI and controlled weapon attacks do **not** duplicate full independent dinosaur attacks. Rider KO/dismount and mount HP, status, stamina persist independently.
8. **Species size realism:** a small mount need not resist giant stomp and may expose rider to tail strikes; large mount trades reach and ability to withstand stress for slower turning/bigger target.
9. **Era constraint:** tests succeed with **no firearms, rocket launchers, Gatling guns, exosuits or giant mechanized vehicles**. They may remain optional unrelated future technologies, only on subsequent owner approval.

## 7. Mount battlefield archetypes (2026-10-25 role names accepted; species assignments and abilities proposed)

**New user request:** picture **fast cavalry, tank, berserker** and ask "what would a T. rex be?" Recommended answer: **Tyrant / Apex Dominator** (not an ordinary Tank or Berserker). The mount classes below are **battlefield roles** determined by anatomy/behavior/training, **not** another competing weapon damage matrix; each individual and rider still has **D/M IV × Impact/Pierce/Slash** modes.

| Mount role | Example species | Combat promise | Weakness and tradeoff | Preferred rider synergy |
|---|---|---|---|---|
| **Cavalry / Courser** | Gallimimus, Megaloceros | Highest traversal/repositioning; repeat drive-by attacks, evades giant stomps by leaving danger footprint | Fragile and little protection when caught; poor sustained brawling | **MP** lance passing attack; **DP** mounted archery if trained |
| **Skirmisher / Flanker** | Velociraptor, Deinonychus | Tight turns, side attack, pack pursuit, feints, chase down isolated prey | Loses stand-up fights with large targets; rider must manage attack range and high-speed control | **DS** timed cutter/throwing axe; **DP** accurately placed bow; **MP** light spears |
| **Charger / Breaker** | Styracosaurus, Triceratops | Frontloaded mass and horn charge, knocks targets out of position, commits to lane | Requires approach space, vulnerable while turning/recovering and to side attacks | **MP** lance timed with mount charge; **MI** heavy head/shoulder disruption |
| **Bulwark / Tank** | Ankylosaurus, Stegosaurus | Plates absorb ordinary hits, control narrow approach, protect foot followers, strong body blocking | Slow, big hitbox, poor stomp evasion, Impact susceptibility; meaningful turn/recovery | **MI** hard strike/shield protection; **DP** bow for rider if armor blocks close reach |
| **Berserker / Ravager** | Utahraptor, Smilodon; **Allosaurus only if later made tameable** | High attack frequency, pounce/bleed combos, damage while aggressively pursuing prey | High stamina cost, thin protection, self-exposure if interrupted | **MS** heavy cleave to follow pin/bleed; **MP** timed finishing thrust |
| **Tyrant / Apex Dominator** | **Tyrannosaurus rex (OWNER-CONFIRMED tameable and rideable in intended game)**, Tarbosaurus candidate | **Commanding threat radius**, huge deliberate **MP** bite, **MI** stomp, roar or intimidation; single devastating committed grabs/finishes if later animated | Huge collision footprint, slow pivots/recovery, food/maintenance burden, poor precision against tiny prey; **not** agile and **not** automatically invincible because of HP | Rider acts like tactical commander, setting target facing, bite windows, rally; limited reach with hand weapons due to high rider position |
| **Titan / Siege Beast** | Future Brontosaurus; existing Brachiosaurus only if exceptional future mount system | Very long-range limb/tail attack arcs, mass pressure, huge-area access denial | Extremely slow, vulnerable to planned counters, obstructed by tight terrain, near-leg danger zones; ordinarily a boss/environmental-scale role rather than standard horse-like mount | Command and support rather than ordinary lance/sword swings; saddle/platform weapon details remain open |

**Core taxonomy distinction:** **Tank** survives and guards, **Berserker** commits to high-frequency attacks, **Tyrant** enforces a threatening territory around massive committed single attacks, **Titan** changes the physical scale of the battle, **Charger** wins a run-up, **Cavalry** constantly changes position, **Skirmisher** flanks and hunts down targets. They should **feel different without fixed damage multipliers masquerading as classes**.

**T. rex specifics, OWNER-CONFIRMED rideable/tameable Tyrant role:** huge body/HP does not make it an Ankylosaurus-style plated **Tank**, and it isn't an always-fast-combo **Berserker**. Give it a recognizable **Apex/Tyrant** combat loop: claim attention or cause short disorganization through roar, angle its enormous head to telegraph a decisive bite, bite/clamp (if new animation) or stomp on commitment, then recover while opponents can evade/reposition. The rider primarily **selects targets and controls orientation/spacing**. Because the saddle is high, the rider **may not reach ground targets with ordinary swords or axes**, making its elevated status a tradeoff. Massive animal upkeep and narrow-space access maintain smaller mounts' value. **Current game-data mismatch:** `game/data/creatures/tyrannosaurus.json` still has `tameable: false`, `capture_tier: 0`, `tamed_role: []` despite the owner's **confirmed intended tameable/rideable T. rex**. Preserve raid-boss challenge while designing a legitimate tame/unlock/saddle and size-correct mounted-control progression; do not quietly ship `tameable` change without addressing capture and balancing.

**Important current species eligibility:** `mount` role exists in current JSON for **Gallimimus, Megaloceros, Velociraptor, Deinonychus, Utahraptor, Smilodon, Styracosaurus, Triceratops**, along with some early/small specimens **Zebraceratops, Coelophysis and Protoceratops**. Physically small animals must **not** be assumed to carry human-sized riders without species-size feasibility work. **Ankylosaurus and Stegosaurus** currently have bag/combat roles but no `mount`; their use as rider tanks is **new proposed eligibility**. **Allosaurus and Brachiosaurus** currently remain **non-tameable**. **T. rex is owner-confirmed tameable/rideable** in game intent despite the contradicting current JSON. **Tarbosaurus** is tameable for combat but currently lacks `mount`. Do not alter runtime flags before designing capture eligibility, raid-boss interplay, saddles and safe data migration.

**Building a usable class system:** Creature **anatomy determines baseline mobility, armor, mass, reach and behavior**, not a cosmetic class name; **individual inherited IVs, rider skills/training, traits and tack** specialize within physiological limits. Two Triceratops may have differing Might-focused charge force, obedience and equipment, but neither should outrun an equally developed Gallimimus by reclassifying itself a Courser.

### Prototype encounter roles against a future Brontosaurus

- **Courser:** bait tail windup, sprint out of sweeping arc and move the rider into exposed flank during recovery.
- **Skirmisher:** circle to weak side and trigger timed pounces/bleed windows; susceptible to one giant contact.
- **Charger:** synchronized thrust into soft leg/flank after Brontosaurus has committed to tail whip; must avoid close-range stomp on recovery.
- **Tank:** potentially endure one less-dangerous swipe and hold an approach lane for followers, but cannot ignore a huge stomp merely due to heavy plates.
- **Berserker:** high reward if it remains on exposed flanks during opening, terrible outcome if caught during extended claws/bite animation.
- **Tyrant:** large enough to pressure a giant's flank with jaws and drawing attention, but huge body is a dangerous target for the tail/foot. T. rex is not automatically the perfect Brontosaurus counter.
- **Titan:** if ever tameable, slow huge platform for siege/support and counter-titan fights, not a universally better mount.

**Party fit:** With only **three active expedition companion slots**, players can build a **Courser + Bulwark + Berserker** group or **Charger + Skirmisher + Tyrant** group; every rider+dinosaur counts as **one composite slot**, and rider attack choices trade away some autonomous beast attacks so all slots remain comparable. A rare Tyrant must not erase the strategic reason to deploy a Courser or Bulwark. Rider skills and dinosaur commands should strongly distinguish tactical player agency from a wild Tyrant's own autonomous aggression.

**Test before owner class approval:** is every class best at a distinct task? Does a T. rex have unavoidable superior HP/DPS/reach to all earlier tames, or is its size legitimately burdensome? Do tanks withstand hits without ignoring the massive Brontosaurus stomp? Can both Might and Dexterity riders play effectively? Is an unmounted dinosaur a legitimate choice in a three-slot party?

## 8. Conditional weapon Mastery Bonuses: momentum, distance and skillful execution (2026-10-25 owner direction)

**Owner proposed both examples:** **speed-dependent damage for mounted javelins/spears** and **additional reward for accurate long-distance Dexterity/Impact attacks** (historically described by owner as "Impact/Precision", now **DI Dexterity/Impact** under the locked terminology). Treat these as **conditional move properties**, not more damage types, separate classes or generic rules attaching to every Pierce/Impact action. User accepted the **seven mount role names as good**. Which specific animal inhabits which role, formulas, damage bonuses and attack animations are still subject to design/testing.

### A. Momentum Strike: moving cavalry spear, mounted javelin or charge attack

- **Example type:** **MP Might/Pierce** lance, long spear on a galloping mount; **MP** thrown heavy javelin *if the weapon design is Might-primary*, with bonus to initial launch velocity when thrown forward. **MI** shoulder/body ram is another move that may justify kinetic charge properties, but does **not** become Pierce merely due to speed.
- **Fantasy:** speed and mass combine with force. The rider has to **build speed, maintain heading and make deliberate contact**, not circle in place waiting for a speed stat.
- **Primary trigger:** measure the **forward closing velocity of attacker relative to target**, projected onto strike direction at attack initiation/contact. Reward an attack which is aligned with the approach and uses **actual sustained movement**, not just high maximum-speed statistics. Optional **short minimum run-up** to make the choice readable; the enemy and terrain must have time to react.
- **Reward:** extra damage or posture/stagger proportional to effective closing velocity, with a capped maximum, rather than a permanent mounted damage multiplier. Rider Might IV contributes to **bracing, holding control and translating momentum**, trained riding skill to timing/accuracy, mount speed/endurance/mass to safe delivery. Species genetics matter; a fast Courser may generate high speed, a heavier Charger may leverage mass but with stricter steering.
- **Counterplay:** tight terrain, forced turn, interrupted charge, enemy sidestep, giant tail swing, or stomping the intended lane removes the opportunity. Attacker can miss, overrun, be stopped, thrown/dismounted or strike a hard defended angle. Impact of running at an immobile stationary dinosaur still uses the mount's own forward component; retreating toward the rider should not create infinite bonus via easily exploitable enemy movement.
- **Thrown javelin caution:** moving forward may improve initial projectile speed, but damage does **not** scale with distance traveled; projectile travel/falloff and launch angle need a consistent ballistic/gameplay rule. Do not automatically award both full mounted thrust bonus **and** full thrown projectile bonus for the same throw.
- **Sample non-final tuning for playtest ONLY:** smooth `bonus = up to +30% damage` after meaningful straight-line run-up and closing-speed threshold; +0 at standstill; faster speed increases toward a cap, with some momentum committed to stagger instead of stacking huge damage. Attack eligibility and approach direction must be validated server-side in competitive settings.

### B. Longshot: difficult long-distance direct hits

- **Example type:** **DI Dexterity/Impact** sling stone or accurate blunt throw; **DP Dexterity/Pierce** aimed arrow is also a plausible longshot weapon, but the **owner's initial example specifically prefers DI**. Players should recognize that the reward tracks **landing a difficult shot**, not kinetic impact power increasing with distance.
- **Trigger:** target acquired and projectile **actually travels** at least a designated fraction of its weapon's **effective range**, with valid line of sight and a live accurate hit. The target should not be trivially hittable by firing at an immobile oversized hitbox; can add a limited **target difficulty factor** (movement, hit-zone size, or aiming time) later, but avoid hidden complexity as a mandatory prerequisite.
- **Reward:** a bounded **precision-hit / weak-point / stagger bonus**, optional small damage bonus and **clear LONGSHOT feedback**. The distance criterion is weapon-relative (a sling and a crossbow should not have identical absolute meters). Make normal-range shots still useful and allow different mastery mechanics for weapons lacking precise fire.
- **Risks and checks:** accuracy, projectile travel time, gravity/drop and moving-target lead make longer hits more challenging. Prevent point-blank shots from receiving longshot damage, don't let firing at permanently stationary oversized bosses become a free max-range DPS exploit, and don't let projectile bounce, teleport, mount motion or artificial distance count multiple times.
- **Sample non-final tuning ONLY:** `+0 to +20% on successful hit` scaling through the final third of effective range, with additional stagger rather than raw damage if boss DPS inflation is a concern. At distance beyond effective range, accuracy is poor and the bonus does not extend infinitely.

### C. Small optional move tags for the six archetypes

| Weapon attack/mode | Primary class | Mastery trigger | Player-readable reward | Tradeoff |
|---|---|---|---|---|
| **Mounted lance / thrusting spear** | **MP** | Closing speed + approach alignment | **Momentum Strike**, heavier burst/posture | Run-up, hit commitment, mount collision/dismount risk |
| **Forward-thrown heavy javelin** | **MP** (owner's heavy-javelin concept) | Clean forward throw while traveling | **Running Throw**, modest initial throw force / contact effect | Limited ammo, windup, actual projectile accuracy |
| **Sling stone** | **DI** | Long-distance accurate hit | **Longshot**, improved precision damage or stagger | Projectile travel/drop, aims harder at range |
| **Bow/crossbow** | **DP** | Distant aimed weak-point hit, optional separate weapon property | **Sharpshot**, accurate opening hit | Aim time/reload, moving targets |
| **Heavy mounted club / body shoulder strike** | **MI** | Committed charge + real contact | **Collision Break**, extra stagger or guard pressure | Slower recovery, heavier mount hitbox |
| **Heavy cleaving axe** | **MS** | Timed strike across exposed flank or several valid close targets | **Follow-through/Cleave**, sustained Slash damage | Close exposure and stamina |
| **Accurate whip or passed slicing blade** | **DS** | Good lateral movement timing + arc contact | **Passing Cut**, controlled sweep | Short hit window, less raw hit force |
| **Mounted aimed stone throw** | **DI** | Well-timed thrown shot while moving | **Ride-by Aim**, separate optional precision skill | Aim stability and smaller accuracy window |

**Do NOT introduce eight distinct player-facing skill trees.** These are optional **weapon/attack-mode mastery tags**, possibly surfaced on item tooltips or in combat feedback while continuing to use existing skills, genetics and move animations. Most weapons might have **no special bonus**, one bonus, or a custom special. Avoid universal stacked damage multipliers or selling traits that trivialize defense classes.

### D. Animal-role synergy without making class a flat buff

- **Cavalry/Courser:** excellent **MP Momentum Strike** with a rider; superior approach speed, escape and room to run, but fragile when contacted.
- **Charger/Breaker:** great **MP lance thrust** or **MI collision** through mass/commitment; less able to correct direction at the last instant than a Courser.
- **Skirmisher/Flanker:** gains **DS passing cuts / DP moving aim** through lateral accuracy and flank access rather than the largest impact-force bonus.
- **Bulwark/Tank:** better at **bracing** a spear against an incoming charge, resisting posture break and enabling allies to take shots; do not pretend it is as fast as Cavalry.
- **Berserker/Ravager:** signature **Frenzy** rewards consecutive direct hits, especially repeated melee Slash/claw contact; capped streak increases follow-up damage until miss, disruption or timeout; mistakes expose the attacker to retaliation. Both rider and mount cannot stack full separate hit-rate buffs for free.
- **Tyrant/Apex Dominator:** benefits from a large **single committed bite or body impact** at a close controlled range; **does not** automatically get a huge horseback-like lance damage bonus and isn't the fastest mount.
- **Titan/Siege Beast:** primarily exploits **reach, space and mass**; enormous threat zones/telegraphs, not an invitation to easy giant-sized critical multipliers.

### E. Brontosaurus test

**Suggested coordinated sequence (gameplay example):** A Gallimimus cavalry rider starts well outside the Brontosaurus's tail arc with **MP** spear. A DI sling ally lands a skillful **Longshot**, drawing the giant's head/attention. As the Brontosaurus winds up its **DS long tail whip**, the rider avoids the committed sweep, builds approach speed into the opening behind the moving tail, lands **MP Momentum Strike** on exposed flank/leg and escapes the near-leg **MI stomp** window. Another slower heavy mount may hold a braced zone while a foot Might/Slash fighter exploits recovery. This rewards **the right preparation and position**, not merely owning faster mounts or firing from farther away.

**Key failure case to test:** Spear rider spams tight circles around a stationary Brontosaurus and obtains full charge bonus every second without a real approach, while the Longshot user stays at maximal range against a giant stationary target and receives a free damage multiplier on every shot. Neither should dominate ordinary play or make foot melee irrelevant.

**Balance sign-off required:** user chose the overall concept; max percentages, falloff, trigger distance, minimum run-up, relative velocity rules, precision difficulty and how rewards are split between raw damage versus stagger remain **proposed**. The current Godot game does **not** implement these mastery tags or rider attack bonuses.

## 9. Giant mount rider reach + Berserker Frenzy (owner corrections and new direction, 2026-10-25)

### A. IMPORTANT: T. rex is tameable and rideable in owner's intended game

The owner explicitly corrected the earlier tentative statement: **Tyrannosaurus rex IS a tameable, rideable species**, a **Tyrant / Apex Dominator** mount, not permanently wild-only. **Existing runtime data contradicts this intent:** [`tyrannosaurus.json`](../../game/data/creatures/tyrannosaurus.json) still sets `tameable: false`, `capture_tier: 0`, `tamed_role: []`. These are **implementation debt / owner-approved design vs current-game discrepancy**. The T. rex's existing raid boss configuration (tier 60, `tyrant`, high HP, multi-phase attacks) must be preserved as a formidable wild encounter while eventual acquisition, saddle capability, progression gates, captured individual stats and player safety are designed. **No runtime changes were requested in this workshop**, so do not silently change the monster's current capture settings here.

### B. Reach and physical weapon legality depend on saddle geometry

**Owner spotted a genuine physical problem:** Riding atop a huge T. rex can position the human **too high above small ground animals for a sword, axe or ordinary spear to hit**. A rider's melee swing must not magically connect with a target just because it is within the DINOSAUR's attack radius. Apply geometry to both foot/mounted moves:

1. **Two separate reachable envelopes:** **(i) rider weapon reach**, based on actual rider pose/socket height, attack animation arc, horizontal distance, weapon length and target hurtbox; **(ii) dinosaur natural attack reach**, based on jaws, limbs, horn, feet, tail and its own attack animation. A T. rex can bite or stomp a Compy while its rider's sword cannot touch that same Compy from the saddle.
2. **No free downward melee targeting from giant saddles.** Ordinary swords/short axes on T. rex are good only versus elevated targets the rider can physically reach, and are useless against many ground-level foes. Long spears/polearms only count if their actual modeled hit arc can touch the chosen weak point or another giant's flank. Don't auto-convert a sword into a 10-meter invisible stabbing volume.
3. **Rider-controlled natural combat:** On a giant Tyrant, the player focuses on **commanding the mount's bite (MP), stomp (MI), roar, facing and positioning**. These attacks scale from the **dinosaur's own genetics/learned ability and move properties**, not automatically from the **human rider's Might**. Rider skill/intelligence/handling affects timing, control, targeting and coordination.
4. **Rider-usable alternatives:** **DP** bow/crossbow or **DI** sling/thrown blunt weapon work at downward angles given aiming/collision constraints; thrown javelin requires true physical trajectory and can be classed **MP** if the human's heavy throw is Might-based. A large target at rider height may be vulnerable to a rider-held polearm. A tail/neck platform saddle can change origins only if explicitly modeled and balanced.
5. **Mount sizes have different weapon roles:** **Low/mid Courser or Skirmisher** enables practical **MS/MP/DS** ride-by melee; **big Charger** can carry a mounted lance and allow hits on larger foes, but not tiny targets directly under the rider; **huge Tyrant/Titan** is primarily a natural-weapon combat platform and ranged observation/command platform for rider, except against appropriately elevated targets. A higher saddle is not automatically a better melee position.
6. **No duplicated attack economy:** Rider commands mount-bite/stomp as a composite attack schedule, not free T. rex bite **plus** an out-of-reach sword swing every cycle. Limit attack concurrency/animations while maintaining one human+dinosaur expedition slot.

**Simple example:** A Compy is within T. rex stomp range, but 6+ meters below a seated rider. The Rex's stomp can connect; a rider's greatsword should whiff or be disabled as out of reach. Versus the flank/upper leg of another gigantic sauropod, a long polearm could connect only after validating real collision and pose.

**Implementation tests:** Use model and weapon reach/hurtbox geometry at attack frames (or a deliberately conservative swept-volume approximation), visible hit feedback, and consistent animation cancel/aim limits. Saddle height, tilt, creature scaling, rider elevation and air targets matter. No invisible global distance check shared between mounted human and dinosaur.

### C. Berserker signature: **Frenzy**, consecutive successful melee Slash pressure

**New owner idea:** **Consecutive landed attacks should increase damage** to make melee **Slash (MS/DS)** appealing, particularly for **Berserker / Ravager** mounts. This is a strong fit for Berserker's identity without turning all fast attacks into an unconditional strongest build.

**Proposed distinction:**
- **Slash weapon capability: Combo/Rend**: eligible **melee Slash** weapon/attack modes can build a **short per-attacker, per-target hit streak** (direct hits only) that modestly improves successive hit damage or deepens pressure. **MS** heavy axe/long cutter or **DS** quick precise close slash may use the mechanic; **ranged shred guns** do not inherit it simply from `S`. Other damage verbs can have their own distinct mastery triggers (Momentum Strike, Longshot, Collision Break).
- **Berserker role signature: Frenzy**: Utahraptor/Smilodon-like **Berserker** specializes in maintaining and exploiting **consecutive claw/bite/Slash melee** hits, possibly with a higher cap or longer continuation window **but not unrestricted runaway stacking**. A bite labeled Pierce does not automatically become Slash; it might continue a role-specific aggression sequence only if a deliberately defined compatible move/role rule allows it.
- **Build on contact:** Only a **confirmed direct successful strike on an actual eligible target** counts. Misses, parries/blocks (decision pending), knockdown/stagger or sufficient time without a contact end the chain. Bleed ticks, poison ticks, area hit counting 8 separate Compys, environmental damage, and a mount's background autonomous hits **cannot** give an attacker multiple consecutive-hit stacks.
- **Single target and sequence scope:** A simple safe baseline is **per actor+target chain**, with at most **one stack increment per attack action**. Target switching resets streak (could preserve short class-specific Berserker grace later, not default). This avoids Slash sweep hitting a herd and instantly filling the meter.
- **Cap and cadence:** A prototype **+5% damage for each qualifying consecutive follow-up**, capped at **+20%** (hit1 100, hit2 105, hit3 110, hit4 115, hit5+ 120 when base hit=100), is **ILLUSTRATIVE ONLY**. Attack frequency matters for how quickly a streak builds, but should not determine **type**. A greatsword needs enough chain grace to finish its slower animation, so a fixed very short global timeout would unfairly favor small blades; normalize by expected attack cadence or committed animation/recovery.
- **Opportunity cost:** Staying close for high uptime increases exposure to **stomp, tail whip, knockdown or counterattack**. The large bonus is earned by continuing to land hits; no permanent passive uptime advantage. The user can choose to disengage and lose streak rather than die.
- **Rider vs mount stacks:** Each actor has one validated chain on a target; if the rider attacks with melee Slash and the dinosaur also attacks with natural Slash, do not quietly grant independent full-power Frenzy stacks to both for one composite party slot. Prefer one *designated attack sequence at a time* when mounted (mount-led Berserker or rider-led Slash), respecting existing `1 + 1 feels ~1.5`, not 2×. This remains a design/AI tuning choice.
- **Tyrant counterexample:** A rideable **T. rex** is primarily **Tyrant**. Its expensive massive **MP bite**/**MI stomp** use commitment, intimidation and major hit impact, **not** Frenzy ramp from rapid hits. If a rider has an MS blade on a T. rex, it only gets a combo bonus when the blade physically reaches and directly hits a suitable **elevated target**; no role cross-over or phantom melee hit on ground enemies.

**Recommended UI:** A compact `FRENZY x2/x3` progress tick and limited `COMBO` feedback on damage, with visible fade when chain will expire. Do not create a new inherited IV or globally replace existing Melee/Ranged learned skills.

### D. How these mechanics reinforce the seven mount roles

| Role | Most important reward | Main difficulty |
|---|---|---|
| **Cavalry** | **Momentum Strike**: forward speed + spear alignment | Line-up and safe exit |
| **Skirmisher** | **Passing Cut**: flank timing/controlled blade contact | Avoid prolonged trade |
| **Charger** | **Collision Break**: committed charge and stagger | Run-up and turn recovery |
| **Bulwark/Tank** | **Brace**: hold a defensive line/receive a charge | Slow pursuit and area escape |
| **Berserker** | **Frenzy**: consecutive actual melee Slash hits | Streak risk, close exposure, control |
| **Tyrant** | **Crushing Opening**: deliberate bite/stomp to control territory | Slow recovery, rider reach limits |
| **Titan** | **Sweeping Reach**: huge threatened arc | Telegraphs, slow motion, massive hitbox |

**No damage coefficients, actor stat changes, rider reach overrides, T. rex capture gates or Frenzy runtime systems were changed by these documentation updates.**

## 10. Owner decisions remaining OPEN

- **Tech ceiling:** stone/bronze/iron/steel, advanced bows and crossbows; any firearms at all? No hard ceiling locked.
- **Mounted damage reward:** mostly positional uptime/reach and timed windows (preferred) vs explicit limited charge bonus?
- **Mount classes:** different usable weapons, permitted sizes and saddle coverage by species, which current `mount` role flags are realistic?
- **Brontosaurus move geometry:** how far tail whip extends, which angles, damage and stagger, separate stomp target markers, status, stamina, readable telegraph duration.
- **Foot melee play:** parries/dodges against which giant limb moves, climb/terrain mechanics, possible coordinated distraction by three companions?
- **Cavalry momentum:** distinguish Might MP lance from Dexterity DS rider slashes without unfair auto-hit/kill.
- **Late-game diversity:** ensure Might-derived heavy mounted weapons and Dexterity bows/crossbows both clear hard enemies with different resource/risk profiles.
- **Mount availability:** rider and mount gear slots, species roles, capacity/height, training, breeding/IV influence and separate death/capture costs.

**No game code, item data, counters, creature species JSON, breeding, armor numbers or skill unlock levels changed in this design pass.**

## 11. Dinosaur mass, trapped prey and armor load (newest owner direction, 2026-10-25)

The owner wants meaningful **size- and mass-dependent physical combat**: a giant planted foot can **trample multiple tiny dinosaurs** actually standing inside its footprint; a medium-sized target physically caught by a far larger dinosaur can become **Pinned** and threatened by a subsequent anatomy-compatible follow-up (another stomp, a true horn/spike **Gore**, or a jaw bite that can geometrically reach); a raptor's **Pounce -> Pin -> Maul/Rake** is a signature predatory play pattern and ties to Berserker **Frenzy**. An animal must be able to contact and physically overpower the target. A raptor cannot globally Pin a sauropod; a Brontosaurus shouldn't acquire a carnivore's gore animation.

**There should also be dinosaur armor with weight trade-offs**, not only natural anatomy. A heavily armored **Brontosaurus** could have a protected Heavy torso yet exposed Slash-weak legs, with the extra plate/saddle/cargo mass burdening **acceleration, turning, stamina, tail-whip recovery and transport capacity**. Huge baseline mass still provides dangerous impact, but slower motion and telegraphs give faster Cavalry or foot fighters real counterplay. Armor class on the struck body part determines relative **I/P/S** matchup; added load and natural mass are separate; rider+saddle height retains physical attack-reach rules. Pinned is an existing status, but mass checks, per-foot multi-hit and extra barding aren't implemented.

Full canonical mechanics, qualitative matchups, distinct animal roles, load formulas/geometry risks and code migration: [22 Dinosaur Mass, Armor and Grappling](22-dinosaur-mass-armor-and-grappling.md). **No stats/formulas/capture eligibility approved here.**

**Important owner refinement of mass and mount protection (2026-10-25):** Armored dinosaurs' **actual carried physical mass should directly strengthen properly connected MI stomp, body slam, tackle and trample actions**, with diminishing returns and meaningful mobility/stamina penalties. **Heavy armor contact blocks ordinary raptor Pounce -> Pin entirely**, with the raptor **bouncing off/backing away** rather than staying attached. A Heavy target may still take appropriate on-hit damage, and huge predators may still grapple/crush through **different actual anatomy-based attack moves**. This synergizes with a Berserker's pounce weakness against Bulwark, but doesn't nullify its ordinary Slash or Pierce contact attacks. The class counter works only for actual covered, intact parts and must resolve before heavy pounce applies Knockdown. [Full mass/body armor spec](22-dinosaur-mass-armor-and-grappling.md).

**Owner 2026-10-25 refinement, defensive mass and stomp poise:** Body weight is a **two-sided contest** for connected stomps/tackles, not just an offensive damage multiplier. A defender's added barding mass and stable stance **reduce received stomp damage and can prevent normal stagger/knockback** when attacker and defender masses are sufficiently comparable. Thus a Heavy **Bulwark** can maintain forward contact through lighter foes' stomps where a fast **Courser** would evade the footprint instead; the Tank is slower and spends more stamina but is **less interrupted**, not faster in meters per second. A full-size Brontosaurus can still crush a small Heavy animal despite its plate. Heavy armor still **deflects ordinary raptor Pounce -> Pin** on covered intact zones; unlike stomp poise, it is a distinct hard pounce-contact counter. Impact remains a useful general counter against Heavy plates; mass specifically protects against body-weight attacks, not all Impact weapons. [Precise proposal](22-dinosaur-mass-armor-and-grappling.md).

**Proposed 18-weapon economy and cavalry implications (2026-10-25):** [23 Crafting Progression](23-weapons-and-material-crafting-progression.md) assigns **six DI/DP/DS/MI/MP/MS signature weapons at each of early/mid/late**, uses real early/mid Compy/Zebraceratops/raptor resources, and deliberately keeps civilization stone/bone/composite/copper/iron rather than modern automatic firearms. **MP Bone Spear -> Talon War Lance -> Forged War Lance** is a key Might mounted Momentum path. **MS Stone Axe -> Obsidian Great Axe -> Iron Talon Greatblade** preserves heavy melee Slash/Frenzy. **DP Sinew Shortbow -> Copper Crossbow -> Iron Repeating Crossbow** represents later Dexterity engineered variety. Any saddle attack remains limited by rider reach; giant T. rex rider commands natural bite/stomp instead of free point-blank sword strikes. Exact weapon kits are **proposed only**; smelter/iron resources not implemented.

## 12. OWNER: platform saddles on huge animals with siege crews and automatic guns (2026-10-25)

Owner specifically requires a fitted **platform saddle for sufficiently large/heavy eligible tameable dinosaurs**, providing **up to ONE crewed siege gun, TWO small automatic turret hardpoints and exactly ONE common ammo box**. Player can either **steer dinosaur while a physically present tribe member operates the main gun**, OR **operate the main gun personally while a physically present tribe member drives** using real AI driver orders. Two automatic turrets run with physically stocked shots and valid arcs without separate gunners. The mount with crew and armament must NOT bypass existing Expedition three-companion slots or mint humans out of nowhere; the exact counting of the active avatar remains OPEN, but any extra deployed tribe gunner is a real person. Saddle + weapons + shared ammunition + occupants count toward animal's real load/carry mass, movement/turn/stamina and body-weight stomp/poise. The main gun must fit the back socket and have genuine muzzle/line-of-sight/blind angles, not grant rider swords unlimited reach. **Future Brontosaurus ideal; rideable intended T. rex prospective but live non-tameable JSON conflicts; existing Brachiosaurus is non-tameable.** These are not yet in mounted gameplay.

**Canonical full specification, atomics, crew modes and twelve backlog tasks:** [25 Platform Saddles and Mobile Siege](25-platform-saddles-and-mobile-siege.md). Existing stationary siege weapon/auto turret definitions: [24](24-turrets-siege-ammunition-and-guard-crews.md). Fixed gun + two auto + box max is specifically for platforms; ground defense emplacements are governed by their normal limits. **No game code changed.**
