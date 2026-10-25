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

**Verified mount-eligible tamed-role species in current JSON:** Zebraceratops, Coelophysis, Protoceratops, Velociraptor, Gallimimus, Megaloceros, Deinonychus, Smilodon, Styracosaurus, Utahraptor, Triceratops. Larger **Stegosaurus and Ankylosaurus** currently have `bag/combat` roles **without** `mount`, and Brachiosaurus and T. rex are **non-tameable**. This is current data, not a final balanced rideable-animal list. Avoid arbitrarily resizing miniature animals to hold humans; animation/ride eligibility and realistic relative scale require review.

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

## 7. Owner decisions remaining OPEN

- **Tech ceiling:** stone/bronze/iron/steel, advanced bows and crossbows; any firearms at all? No hard ceiling locked.
- **Mounted damage reward:** mostly positional uptime/reach and timed windows (preferred) vs explicit limited charge bonus?
- **Mount classes:** different usable weapons, permitted sizes and saddle coverage by species, which current `mount` role flags are realistic?
- **Brontosaurus move geometry:** how far tail whip extends, which angles, damage and stagger, separate stomp target markers, status, stamina, readable telegraph duration.
- **Foot melee play:** parries/dodges against which giant limb moves, climb/terrain mechanics, possible coordinated distraction by three companions?
- **Cavalry momentum:** distinguish Might MP lance from Dexterity DS rider slashes without unfair auto-hit/kill.
- **Late-game diversity:** ensure Might-derived heavy mounted weapons and Dexterity bows/crossbows both clear hard enemies with different resource/risk profiles.
- **Mount availability:** rider and mount gear slots, species roles, capacity/height, training, breeding/IV influence and separate death/capture costs.

**No game code, item data, counters, creature species JSON, breeding, armor numbers or skill unlock levels changed in this design pass.**
