# Combat counters: source audit and proposed implementation

Base0823b9bcecc23f68ad48ea1e8137eabaaa74881b. Milan's October6 direction:
bulky/tanky dinosaurs reward blunt force and poison; fast/deadly dinosaurs reward
traps and bleed. A tool for every job, varied resistance, loot feeds combinations.
This is a proposed design, not a shipped feature or a beatability claim.

## What already exists

Hunt maps weapon damage_type into ai.json weak_to/resists (1.5/0.6 multipliers).
Knife/axe are slashing, club/raid_maul blunt; no playable ranged delivery found.
Slashing has25% chance to apply bleeding_target. Unlike its displayed0 flat DPS,
it already has1% maxHP/second. That universally scaling DOT needs matchup rules,
not a second unrelated bleed system. poisoned_target is0.5 DPS/30s and declares meat_inedible, but corpse loot does not enforce it.
Food poison_chance is not weapon coating. Player bleed/deep_bleed/venom are separate
small fixed-DPS injury statuses and must retain those semantics.

snared already stops action8s; groggy, knockdown, fracture, pinned and deafened exist.
A single universal eight-second action lock against a boss would be a cheese loop.
CreatureBrain stops actions for cannot_act. Existing contact damage floor is5% ATK;
full raid armor gives298HP and still dies in4-6 contacts. The raid needs readable
counter-earned openings as well as damage matchups. No flatHP/ATK nerf proposed.

## Proposed type chart

Physical channels: blunt, pierce, cut. Preserve data token slashing as cut alias.
Do not relabel knives as pierce merely to shrink the chart. Future spear is pierce.
DOT channels: poison, bleed. Trap is control, not a damage channel.
Numbers below are starting design targets, pending real-AI tests.

| Counter family | Blunt | Pierce | Cut | Poison | Bleed | Trap control |
| --- | ---: | ---: | ---: | ---: | ---: | --- |
| Armored/bulky |1.5|0.75|0.6|1.5|0.25|short slow, no stun |
| Fast hunter |0.75|1.0|1.25|0.5|1.5|4s root, attack still works |
| Runner |0.75|1.25|1.0|0.75|1.25|6s root, attack still works |
| Venom hunter |1.25|1.25|1.0|0.25|1.0|3s root |
| Antlered charger |1.0|1.25|0.75|1.0|1.0|3s root |
| Tyrant/titan |1.5|0.75|0.5|1.5|0.1|no root; heavy snare slows briefly |

Apply physical matchup after defense and before crit. DOT matchup scales damage,
not duration; hostile poison/bleed never inherits player injury scaling. Proposed
creature DOT bases: poison0.15% maxHP/s for20s, one stack, refresh only.
Milan's9:57pm steering supersedes percentage bleed: bleed is fixed damage with
escalating stacks. Base4DPS times n(n+1)/2 at1-5 stacks gives4/12/24/40/60DPS
before archetype resistance,12s shared refresh timer. No health-percentage bleed.
These are starting targets, not proved balance. Do not apply
percentHP damage to players. Cap persistent DPS against raid bosses at0.3%/s per
channel; mixed poison/bleed does not bypass resistances. Successful poison kill
will enforce the existing meat_inedible flag; bone/hide/counter materials remain recoverable.

## Catalogue matrix and reason

| Species | Existing archetype | Counter family | Grounding in current stats/behavior |
| --- | --- | --- | --- |
| compy |swarm|Fast hunter|90HP/10DEF/650speed, short-leash swarm |
| velociraptor |pack_raptor|Fast hunter|640HP/40DEF/700speed, pack flank/pounce |
| deinonychus |pack_flanker|Fast hunter|1450HP/70DEF/660speed, flank |
| utahraptor |apex_raptor|Fast hunter|4200HP/120DEF/620speed, pack flank |
| allosaurus |apex_raptor|Fast hunter|9000HP/180DEF/520speed, existing flank behavior |
| coelophysis |flock_harass|Fast hunter|420HP/30DEF/720speed |
| smilodon |saber_cat|Fast hunter|3800HP/140DEF/720speed |
| gallimimus |runner|Runner|1400HP/50DEF/900speed, fleeing herbivore |
| megaloceros |antlered|Antlered charger|1800HP/80DEF/760speed, mobile herbivore |
| dilophosaurus |venom_ranged|Venom hunter|2600HP/80DEF/560speed, venom role |
| zebra/protoceratops |pack_mule|Armored/bulky|720/980HP,80/110DEF,400/420speed |
| stegosaurus |spiked_tail|Armored/bulky|8500HP/300DEF/400speed |
| ankylosaurus |club_tail|Armored/bulky|12000HP/520DEF/380speed |
| styraco/triceratops |horned_charger|Armored/bulky|5200/14000HP,220/380DEF,470/450speed |
| brachiosaurus |titan|Tyrant/titan|90000HP/500DEF/300speed |
| tarbosaurus |tyrant|Tyrant/titan|24000HP/260DEF/480speed |
| T-rex |tyrant|Tyrant/titan|200000HP/400DEF/450speed, raid |

Archetype assignment is game logic based on existing behavior, not a claim about
real paleontology. Species overrides can distinguish same-family enemies later.
Do not alter existing AI profiles just to assign damage channels.

## Tools, delivery and loot loop

- Existing club/raid_maul: close blunt. A dedicated mid-tier hammer bridges the
  large gap between28-base club and220-base raid weapon.
- Slingshot: player-visible aim/fire, blunt stone ammunition, range12m,1 shot/s.
  Limited by bag ammunition, line of sight, windup and short kite range. No silent
  hits through walls and no longer-range unchallenged boss kill.
- Catapult: placed3x3 structure, build validation/payment, destructible200HP,
  manual fire3s reload, ballistic aim with visible landing circle, range8-24m.
  Stone shot blunt; toxin pot poison delivery; ammunition consumed. No auto-fire.
  Boss attacks it when used; range does not disable retaliation. Art is Fable work.
- Barbed knife/spear: cut/pierce with deterministic bleed after consecutive valid
  hits, replacing reliance on lucky25% procs for counter identity.
- Toxin coating: consumable preparation,3 landed hits per dose, applies poison
  without inventing a global venom weapon stat. Save doses; never apply on dodge.
- Rope snare: one-use ground placement, visible trigger radius, roots mobile prey
  without disabling bites. Heavy cable snare: brief slow for large targets.
 10s post-release control immunity prevents chaining; bosses never hard-rooted.
- Loot: tendon from mobile predators feeds snares; serrated talon feeds barbed
  tools; dense bone/armor scute from bulky herbivores feeds hammer/stone-shot
  upgrades; venom gland from dilophosaurus feeds coatings/toxin pots. Guaranteed
  modest base yields for progression; rare quality variants improve crafting.
- Early toxin precursor from existing bitter herbs allows first bulky kill before
  needing venom glands. No circular requirement to kill poisoned prey for poison.
  Scarce raid doses require hunting/crafting, not unlimited refresh or free items.

## Raid counter loop and fight-feel targets

Correct kit: reinforced armor, raid blunt weapon, toxin doses, heavy slow snare
or catapult support. Wrong kit: ordinary cut weapon with no counter supplies.
T-rex retains200000HP/1100ATK/400DEF. Poison lowers stagger threshold; blunt hits
build visible stagger during punish openings, not on invulnerable windup.
Starting targets: three landed blunt counters with poison active trigger3s stagger,
then20s stagger immunity. No permanent knockdown, no stacking stun.

Primary/heavy attacks get readable windup and fixed recovery: provisional0.7s
primary windup/1.0s recovery,1.2s heavy windup/2.0s recovery. Damage only at impact,
range checked then; escaped targets are missed. Poison does not simply suppress
all enemy damage. Heavy slow helps reposition, not create an untouchable edge.
Telegraphs must survive roar/deafened: sound suppression must not remove all visual
information. Ordinary swing finishes within current0.65/rate budget; preserve roll
cost and no-walk-during-swing unless actual testing justifies a separately reviewed
change. Initial target remains a skillful roughly5-minute raid, not a damage sponge
or automatic poison kite win. These timing changes replace the parked no-retune
constraint only within the user's new combat design scope; raw boss stats unchanged.

## Build order and acceptance

1. Central matchup model/data and tests, route existing melee/DOT through it;
   keep player status semantics. Counter descriptions on creature inspect UI.
2. Earnable hammer/barbed/coating/snare items and species loot/recipes, saved
   state and consumed supplies; visible normal player actions. Test early tools.
3. Slingshot projectile then catapult structure as separate reviewed patches.
4. Tyrant counter buildup, telegraphs/recovery, UI meter; actual correct/wrong kit
   bot attempts on volcanic terrain, not only seeded damage formula fixtures.
5. Fable pixels: weapons/traps/poison/bleed identification, impact radius, stagger,
   aim and attack anticipation. Render/inspect before gameplay completion claim.

Require all19 species resolve to exactly one documented counter family; alias and
neutral fallback tests; physical/DOT math; save/reload charges; no damage on dodge;
no player percentHP spill; control immunity and boss root rejection; loot/recipe
non-circularity. Correct kit must actually survive and win, wrong kit must remain
measurably worse. Repeat with neutral and varied genetics. Seeded kits are fixtures,
not earned runs. Formula TTK and sparse poses are not proof of real-time feel.

## Phase1 implementation evidence

Central combat_counters.json now owns all19 species' archetype families and type
multipliers. Melee and creature counter DOT use it. Poison percentage and fixed
escalating bleed follow Milan's9:57pm steering. Player counter-status applications
are rejected; ordinary bleed/deep_bleed/venom remain unchanged. No new delivery,
traps, loot, AI timings or boss stats in this patch. Chart/alias/fallback/stack math
and player-injury separation tests are included. Raid completion remainsPARTIAL.

## Phase2a counter supplies

Basea0eb7f1. Dense Bone Hammer65base blunt/0.9Hz; Barbed Talon Knife40base cut/1.3Hz,
one fixed bleed stack every third landed hit. Both scale damage2%/level. Existing
animations/icons are reused explicitly; new weapon models are not claimed.
Hammer:2dense bone+handle+2lashing, workbench5s. Knife:talon+handle+lashing, bench4s.
Herb toxin:4herb-category units, handcraft4s,1dose. Venom alternative:1gland+1herb,
4s,3doses. No skill gates for this first pass; balance remains provisional.

Mobile predator base loot adds1-2tendons; bulky/giant base loot1-2dense bone+1scute;
dilophosaurus1-2venom glands. Existing drops retained. Talon category extends the
existing raptor talon; its original butchering gate remains. Tendon/scute are stocked
for the next trap/ranged phase, not silently used in nonexistent recipes.

Normal context Coat action consumes1dose, sets3saved weapon hit charges; preparation
refused in combat/busy and active coating cannot be overwritten. Charges spend only
on landed melee hits, not dodge or range refusal. Charge and barbed hit count live
in saved ItemStack attributes. Poisoned corpses now exclude meat, keep bone/hide and
counter materials. Poison must already be active at death; a lethal physical strike
is not retroactively poisoned. No corpse flag persistence needed because loot is
rolled at creation; normal saved loot still holds the resulting stacks.

Tests cover real ingredient allocation/consumption, coating/dose/charge reload,
three-hit toxin spend and deterministic bleed, tendon sources and meat exclusion
with bone/tendon retained. Godot4.7 regression suitePASS without script errors.
Inspected960x600 rendered context before/after coating: Coat0/3->3/3 and toxin notice
readable. Seeded UI fixture uses production-imported survivor privately, no rig edit.
No pointer coverage, actual fight balance, fresh earned crafting or raidwin claim.
Trap/control, slingshot/catapult and raid timing are separate unfinished phases.

## Phase2b spatial snares

Base81f1cbf. Rope snare recipe:tendon+2lashing+handle, handcraft4s. Heavy cable:
2scute+2metal+2lashing, workbench4s. Normal HUD action places2m ahead on dry ground;
checks reserved/occupied build cells, nearby harvest/static geometry and other
snares before consuming one item. Radius1.25m, arms1s, expires120s, single-use.
Green rope/amber heavy rings and labels use simple geometry; no new trap art claimed.

Fast hunters root4s; runners6s; venom/antlered3s. Attacks/AI remain active.
Armored targets reject rope, heavy slows50% for3s. Giants reject rope, heavy slows
35% for2s, never roots. Control cannot refresh while active;10s immunity starts
at release. These are independent movement timers, not existing cannot_act snared.
No player/pet trigger, direct trap damage, boss stat or attack timing changes.

Placed trap snapshots save position/type/arming/lifetime on current island; offline
elapsed time subtracts lifetime on load. Travel abandons placed traps, no refunds.
Wild creatures themselves regenerate on load as before, so active wild control/
immunity is not persistent across world reload; no save-reload combat proof claimed.
Old saves without ground_snares load with none. No inventory seed in normal placement.

Godot4.7 testsPASS: root action-live, duration/immunity/no refresh, tyrant rope reject,
heavy slow, snapshot/expiry and ingredient payment. Real scene fixture pays one,
rejects duplicate, actual save/load restores armed trap, proximity triggers root
and destroys trap. Seeded nearby raptor still damages survivor to28HP: trapping
is movement control, not a free stun. Inspected960x600 ring/label and ROOTED pixels
using production imported survivor privately. Pointer/spatial corner coverage and
actual correct-vs-wrong-kit fight/earned trap grind remain unverified.

## Early actual-AI matchup audit, not a balance pass

Base39d3a42. --counter-matchup-probe --match-species=velociraptor|protoceratops
with --correct-kit optional uses seededL25 weapon/melee, sharedL25 raid armor,
neutral enemy genetics, realAI and terrain. Same starting seed41, not identical
random streams after divergent combat actions. Correct fast kit barbed+rope;
correct bulky hammer+one toxin; wrong kit swaps weapon and omits supplies.
Normal action placement/coating, attacks and navigation; no flat damage/immortality.

Protoceratops correct won31.6s/214HP; wrong cut won73.1s/163HP. This is an
advantage, not proof early wrong-kit players must lose. Raptor initial policies
varied: correct30.1s vs wrong40.6s; later correct90s timeout/wrong37.2s.
Diagnostics: fleeing prey, exhausted chase and occasional regen. Out-of-range
rolls wasted stamina. Bounded in-range rolls gave correct26.5s win and wrong90s
timeout at4x, but normal-speed correct still timed out90s with44enemyHP remaining.
Thus counter advantage is not yet reliable completion. Anky tier50 killed both
L25 kits; that mismatched-tier fixture is not a reason to retune its stats.

Probe preserves this audit for policy refinement. No pointer/pixel/earned fight
coverage or raidwin claim. Counting health decreases includes DOT ticks, not
attack contacts. Need normal-speed repeats and pursuit/finish reliability before
publishing an early fight pass. Ranged and tyrant punish windows remain unfinished.

### Pursuit refinement on681609b

Probe-only: reserve35stamina for rolls, stop out-of-range tap-run below15stamina
and recover to55 before resuming chase. No direct stamina grants or AI callbacks.
Normal-speed correct raptor repeats now win19.1/20.0s; wrong hammer/no trap wins
23.7s. Both retain190-ishHP under the shared seeded raid armor. This is a modest
counter advantage, not proof wrongkit must lose or earned early progression.
Fixture intentionally isolates offense but its protection is not normal early gear.

## Phase3a slingshot delivery

Baseff00f377. Bone Slingshot45base blunt/1Hz/+2%damage per level,12m range.
Recipe bone+handle+2lashing, handcraft3s. One stone produces5stone shots in1s.
Normal hunt FIRE/ammo hex replaces NET while equipped, Auto uses same action.
No new weapon mesh/clip: existing swing and club icon reused pending Fable art.

Fire snapshots aim, checks target/range/LOS/ammo/busy,0.25s windup. Weapon change,
roll/death/interrupted clip or world change cancels before ammo payment. One shot
then travels straight18m/s, visible sphere; per-tick segment ray catches terrain,
geometry or intervening creature. No homing/through-wall/instant damage. Impact
uses ranged defense/skill and central blunt chart, dodge, ranged XP and existing
coating charges only on landed hit. Target death/regeneration semantics unchanged.
Autochase can approach range, not silently fire across the island. Wall refusal
leaves ammo untouched; miss in flight spends ammo. Normal ammo stacks save asbefore.

Godot4.7 regressions/recipe-payment testsPASS. Physics stationary/liveAI probe:
paid1of5shots,18.4damage on protoceratops, cooldown/wall/range refusals. Interruption
by weapon switch spends noammo; emptyammo refuses. Inspected960x600 FIRE5 and
visible shot pixels with production imported survivor privately. Pointer timing,
continuous ranged animation feel and actual ranged fight balance remain unverified.
No claim this supplies raid DPS or beats fleeing prey. Catapult/tyrant windows open.

## Phase 3b: field catapult (2026-10-06)

Reviewable implementation, not deployed. Manual selected-target aim: tap a creature,
stand within3m of the platform, press SIEGE or TOXIN. The shot locks that creature's
current ground position, never homes, and draws a2m landing circle in flight.
This is target-snapshot aim, not free-ground aiming or leading by dragging a reticle.
8-24m range,1.2s visible5m arc,3s reload. Auto does not fire or chase while attending
an adjacent platform; firing stops navigation and selects Hold/manual. Moving away
restores ordinary weapon controls. Rolls/status action locks refuse without payment.
A missed or blocked launched shot spends ammo. Arc segment raycasts hit geometry;
burst LOS prevents through-wall damage. A directly hit giant receives the impact
rather than failing the2m centre-distance check.

Workbench kit:8wood +2dense bone +6lashing. Toxin pot:1venom gland +2stone.
Stone shot is shared with the slingshot,1stone makes5. Stone damage240 before
ranged defense and blunt matchup, minimum12 before matchup. Toxin applies the
existing percentage poison, with its one-stack/refresh rules. No new raid stats,
flat HP nerf, armor, rig, skeleton, scale, deployment or generated asset changes.

Platform200HP, nine occupied grid cells. Normal BuildPlacer validates claim,
water, slope, overlap, distance and kit payment. Firing alerts even a missed-shot
victim to the destructible platform. Herbivores are provoked; siege threat gets
at least26m aggro radius and no short-distance disengage while advancing on it.
Regular player chase/leash is unchanged. Creature clip contact attacks damage
it, destruction releases footprint and restores normal controls. Stones attribute
damage to the platform and raid kill credit to its operator; poison retains operator
source plus a weak siege origin for retaliation. Destroyed saved rows are skipped.
HP/reload/grid pose persist as ordinary home building state. Away-island platforms
are expedition-local, lost on travel/reload like other ordinary away buildings.

Evidence:
- Godot4.7 full regression suite PASS with no script errors in final runs.
  Added paid kit/toxin recipes,3x3 footprint, damage/reload/pose serialization and
  rejection of destroyed-row restoration.
- Seeded actual home-island probe through BuildPlacer and HUD action handlers:
  kit1->0, stone5->4, reload refusal,277.1blunt damage to deterministic proto,
  toxin2->1 and poison tick retention on platform, operator/min/max-range refusals.
  Restored save dispatch reports matching platform state. Real AI was then released
  from10m without forced contact/attack events: walked to1.9m, five real attack
  impacts reduced200->154.8->109.6->64.3->19.1->destroyed; footprint released.
  Last normal-speed home run destruction11s after release. Seeded inventory,
  frozen target during delivery checks, not earned progression or a full ranged fight.
- Separate actual physics probe: Auto did not fire/navigate, moving target escaped
  fixed aim (0damage,1ammo spent),12m-high wall blocked arc (0damage), empty ammo,
  rolling and destroyed-platform refusals. No pointer timing claim.
- Inspected960x600 flat visual lab: attended wheeled placeholder, SIEGE5/TOXIN2,
  visible airborne sphere/yellow landing circle on selected proto, then animal at
  platform and platform gone with NET/TACKLE restored. Normal1x flat visual run
  destruction17s after AI release; this fixture lacks island art/pathing. Exact
  production-imported survivor used privately for visual fidelity, not patched.

Art caveat: simple procedural timber boxes/wheels and shared inventory icons,
no authored catapult animation. World HP/reload label is small at phone-scale;
HUD disables both fire actions during reload. Free-ground reticle, pointer feel,
earned deployment/raid balance and tyrant openings remain unverified/unbuilt.

## Phase 4a: tyrant counter windows (2026-10-06)

T-rex only, not all tyrants or the titan. Catalogue remains200000HP/1100ATK/400DEF.
Physics-timed bite0.7s windup/1s recovery; every third attack stomp1.2s/2s.
Fixed target/facing at windup start: contact range and facing checked at impact,
roll active at impact or moving behind/out of reach avoids it. Generic clip timers
and authored hit events cannot deal a duplicate hit for controller-owned attacks.
Animation is retimed to its authored hit fraction, then idle during recovery.

Windup remains damageable but cannot build stagger. Landed blunt melee/stone/siege
hits during recovery build one counter each. Six normally; three if poisoned.
Counters carry across recovery windows. Threshold grants3s no-attack stagger,
then20s immunity that also rejects buildup. No flat damage multiplier or HP nerf.
Random groggy/knockdown and snared/pinned shortcut statuses are rejected on T-rex;
heavy snare's existing physical slow still works. Disengagement/death invalidates
windows; player death resets the meter. Telegraph ring and HUD BITE/STOMP timer
survive deafened; PUNISH counter count and STAGGER timer are visible in top plate.
Ring marks outer reach, not a full360-degree damage area; facing/roll still matters.

Evidence:
- Final Godot4.7 full regression suite PASS, no script errors. Isolated tests verify
  six/three thresholds, windup rejection, immunity, shortcut-status rejection.
- Normal1x home physics probe: primary0.70s,1.00s recovery; actual contact55.3HP
  with raid armor, no second hit during recovery; normal roll active at next impact
  takes0HP. Behind relocation also avoids damage. Deafened does not hide ring.
- Actual seededL60-maul/raid-armor/melee60, three coated hits versus same armor/
  L60barbed knife without poison: real AI correct policy earned one stagger from
  actual attacks, died19.3s at183409bossHP. Wrong died12.8s at199941bossHP with
  no stagger. More conservative punish-only policy earned one stagger and died
 26.3s at179805bossHP. These show a working opening/kit distinction, NOT a raid win
  or earned/tier-matched balance proof. Injury/stamina/policy mistakes remain lethal.
- Inspected960x600 isolated visual lab: visible BITE0.7s ring while deafened,
  PUNISH1.0s BLUNT0/6, STAGGER3.0s. Threshold in this visual fixture was directly
  invoked, not three earned hits; actual-hit stagger evidence is the AI fight log.
  Local T-rex has no imported species asset and renders the existing box fallback.
  This patch changes no creature/survivor art, skeleton or scale. Exact production
  survivor import used privately only, not patched. Stagger freezes without an
  authored stumble clip. Pixel acceptance covers readable cues, not final boss art.

Reproduce actual seeded attempt with --tyrant-window-probe; add --tyrant-wrong-kit
for the knife/no-poison comparison. Raid-win path, volcanic arena, continued scarce
poison supply/earned gear, successful dodging policy and actual human timing remain
open. Do not declare the boss beatable or complete from these failed fixtures.

## Phase 4b: moving-floor carry correction (2026-10-07)

Real walking-evasion diagnosis: during a close fixed-facing windup, boss velocity
was0 and pathing disabled but both bodies moved together, keeping2.28m distance.
CharacterBody treated the survivor as a moving floor and inherited its velocity.
Creature spawn now sets platform_floor_layers/platform_wall_layers to0. Creatures
still collide and walk on static terrain; they do not ride live characters.
No collision exception, teleport, speed, attack/HP/defense/regen or timing change.

Same restedL60maul/raid-armor seed, three coated hits, normal directional walk away
from windup and return for punish: before fix died21.3s at184143bossHP; after fix
survived60s at298HP,0contacts,173849bossHP and one earned stagger. These are seeded
home fixtures, not a raid win, volcanic proof or earned supply path. Prior window
probes inherited saved stamina/fatigue; the new probe explicitly labels its fresh
rested seed. Updating policy is evidence hygiene, not changing stamina mechanics.

Full regression PASS, new assertion on platform inheritance masks. Inspected
960x600 normal walking escape visual: boss moves0.00m through windup while player
separation grows3.55->7.34m, takes0damage, readable PUNISH1.0s. Existing box T-rex
fallback and isolated flat lab caveats remain. Sustained supply/kill proof pending.
