# 25 | Platform Saddles and Mobile Dinosaur Siege

**Status: OWNER REQUEST, 2026-10-25, DESIGN ONLY.** Owner wants very large/heavy tamed dinosaurs to carry a platform saddle supporting **at most 1 crewed siege weapon, 2 automatic turrets and 1 shared ammunition box**. Either **player drives + tribe member mans siege**, OR **tribe member drives + player mans siege**. Treat the 1/2/1 maximums and both role arrangements as explicit owner requirements. Species eligibility, exact weight/capacity, weapon balancing, ammo box size, crew skills, controller behavior and deployment conditions remain to be tested. None of this is implemented yet.

**Related specs:** [24 Turrets, Crew and Ammunition](24-turrets-siege-ammunition-and-guard-crews.md); [12 Mounts and Companion Slots](12-expedition-mounts-and-command.md); [22 Weight, Armor and Stagger](22-dinosaur-mass-armor-and-grappling.md); [08 Building, Manufacturing and Packable Assets](08-blueprints-worksites-and-building.md); [23 Weapon Manufacturing](23-weapons-and-material-crafting-progression.md); [11 Species and Genetics](11-dinosaurs-and-genetics.md); [Tribe and Labor](../design/tribe-lineage-domain-and-labor.md).

## 1. North-star gameplay

The owner can turn a huge dinosaur into a **living siege platform** by taming, equipping a real manufactured platform saddle, fitting independently manufactured turrets, supplying real ammunition and physically staffing human seats. It is a **mobile fortress**, not an automatically powerful creature unlocked by adding a cosmetic saddle. The dinosaur keeps its own bite, stomp, tail and huge hitbox; the human(s) have separately valid ranged trajectories from the upper deck. Heavy gear increases mass and makes landable stomps/body tackles more powerful while burdening steering, acceleration and stamina. Equipped turrets require maintenance, ammo, trained operators where relevant, valid arcs and reload time.

The two fully supported command arrangements are:
- **Player at helm / actual tribe human at main turret**: player steers the dinosaur and commands legal natural moves; assigned tribe gunner aims, chooses targets and reloads with physical presence and proper skills. Both automatic turrets independently operate while armed and stocked.
- **Actual tribe human at helm / player at main turret**: tribe AI drives via realistic commands (advance, hold, turn/face, retreat, navigate marker), respecting real speed, turning, stamina and telegraphs; player manually aims, fires and chooses ammo in the crewed siege weapon. Two automatic turrets operate independently.
- **No main gunner**: main crewed turret cannot fire. Autos can still operate if eligible, loaded, trigger-valid and not interrupted.
- **No driver**: mount holds or obeys a deliberately trained safe movement order; no invisible human steering. Sole human cannot drive and man a separate siege gun at once without changing stations and relinquishing steering to genuine trained mount autonomy.

## 2. Hardpoint and seat contract

| Component | Count/upper limit | Owner and use |
|---|---:|---|
| Main CREWED siege hardpoint | **1** | Compact fitted ballista, catapult/stonecaster, harpoon or comparable approved siege weapon, requires exactly one actual gunner for first implementation |
| AUTO hardpoints | **2** | Two smaller sector-limited automatic weapons with independent arc, cooldown, magazine and recoil/trigger behavior; no humans need continuously aim these |
| Single shared ammo box socket | **1** | One physical finite-capacity inventory supplying compatible rounds to main + both autos. NO duplicated boxes or hidden per-turret infinite reserves |
| Dinosaur helm / driver seat | **1** | One real player-controlled survivor OR one real available/qualified tribe human |
| Main gunner seat | **1** | One real player-controlled survivor OR an available/qualified tribe human other than driver |

The chosen maximum topology is **1 crewed + 2 auto + 1 shared box**, not permission for additional dedicated loader, second siege tower, four independent ammo inventories or a free human gunner. A real second human needs to be part of the actual tribe roster and expedition deployment, with mortality, equipment and inventory. A main weapon may be left empty; it never fires while unstaffed. The automatic turrets are EQUIPMENT, not extra expedition companion slots.

**Species/geometry eligibility:** Large/heavy classification alone is not enough. Require a species-specific stable back socket/deck shape, actual length/width/height, saddle fitting technology, tame/mount permission, usable load capacity, balance and unobstructed weapon arcs. Tiny raptors/Cavalry cannot receive a three-gun deck. **Future Brontosaurus** is the ideal Titan/Siege Beast candidate but has no JSON/model. **T. rex is owner-confirmed TAMEABLE AND RIDEABLE in intended design**, a prospective Tyrant option, yet its live JSON still marks it not tameable and lacks mount role: code/data discrepancy to fix separately. T. rex's pitched/narrow high back may justify fewer usable hardpoints or accuracy constraints at safe loads; DO NOT falsely claim a three-gun full-sized world catapult fits it. Existing Brachiosaurus is non-tameable, so no immediate platform entitlement. No silent substitution Bronto=Brachio.

**Deck placement:** Model a single equippable saddle/deck with three real turret HARDPOINT SOCKETS, one box mount and two distinct actor seats. The stationary Field Catapult footprint is 3x3 GRID and cannot simply be parented whole to an animated Rex without a separately balanced **compact MOBILE VARIANT**. Include armor plate, driver rail, recoil clearance, min firing range, sightline over dinosaur neck/tail, muzzle origin, pitch/roll sway and actual actor collision. Do not use infinite-height rider sword hitboxes from a high saddle.

## 3. Shared ammunition and operating rules

A single **ammo-box object** contains actual item stacks (shot, bolts, harpoons, toxin pots as compatible). All three mounted weapons request compatible ammo from the same source ledger. A weapon may have a very small loaded chamber/magazine whose contents were ALREADY deducted from the box upon load; the sum of loaded rounds plus box rounds stays invariant until fired/looted/transferred. The box is finite in mass and/or slots. Users choose which turret/ammo is allowed to draw priority if supply is low; important siege bolts should not be automatically stolen by a little point-defense repeater.

- **Crewed**: human aims and starts an attack only with valid actual loaded shot, available skill/stamina, valid weapon yaw/elevation, recoil clearance, line of sight and reload. Main weapon is OFF with no qualified assigned gunner.
- **Automatic**: turret can trigger/fire within its defined limited arc **without a gunner**, but consumes material ammunition or a specifically defined winding/charge, cooldown and wear. Primitive-world moving auto triggers need explicit plausible mechanisms (near-deck anti-pounce contact, sector sweeping clockwork/wound repeater); do not pretend a stationary ground tripwire works on a moving dinosaur or give an Iron Age turret magic electronic 360-degree tracking.
- **Resupply**: a player/crew physically loads the single box; a tribe hauler must actually reach the saddle when safely stopped. No worker magically transfers ammo across islands while moving. Two simultaneous auto shots cannot debit the same final stack twice. Empty compatible ammo → out of ammo and no shot.
- **Ammo class and role** use existing I/P/S damage taxonomy, distinct from automatic/manned behavior and cadence. Catapult/stonecaster DI Impact, precision bolts DP Pierce, huge ballista/harpoon MP Pierce by its primary operating mode, claw scythe DS/MS Slash if fitted as genuine close defense.
- **No free double weapon damage**: each shot is an expenditure and has reload, sightline, recoil, stability and contact checks; fast moving platforms should normally have less stable siege aim. Loaded and fired shells spawn independent WORLD projectiles with launch origin/world velocity snapshot, not projectiles permanently parented to the moving back.
- **Safety**: validate actual hostile faction and island raid/settlement permissions. Player's home remains unraidable, even if a siege platform is there. PvE settlements can face dino raids, optional PvPvE settlements player raids; single-player code cannot pretend to support authoritative offline human PvP. Turrets cannot shoot invisibly through own saddle, dino neck, friendly rider or terrain.
- **Visibility**: show one shared box with ammo quantities by ID, current load weight, each weapon ready/empty/cooldown, main gunner name, driver name, sector coverage, Hold Fire and resupply priority.

## 4. Driver / gunner role switch, seating and companion budget

A physical seated human is a real persistent actor. Driver and gunner must be different real humans if simultaneously occupied; the **player can inhabit either seat**. Switching seats causes explicit action, animation/short pause or transition with interruption semantics; never teleport/clone a second player. If controlling gun while tribe drives, the player gets simple driver orders and turret view; if controlling helm while tribe guns, player gets mount movement and dinosaur natural attacks while the gunner's actual skill and behavior resolve the shots.

**Fallback**: if crew gunner is stunned, dead, prisoner, dismounted or missing, the main gun idles; autos continue only if mount/saddle functional. If driver is absent or injured, the mount receives Hold or safe trained AI fallback; no phantom second driver. If dinosaur dies or is incapacitated, guns stop according to stability rules and actual onboard people can fall/take injury or dismount safely per eventual escape design. Siege gunner remains at risk of attacks and capture despite elevation and Heavy armor.

**Expedition slot compatibility (UNRESOLVED exact avatar accounting):** Existing design says **three shared companion slots** and a normal human+dino rider pair counts as **one composite slot**. Mount+primary driver remains that composite unit; the **extra real tribe gunner** consumes another appropriate human companion slot if deployed rather than spawning free bodies. If the player sits at gun and the tribe member drives, the tribe human remains real; whether controlled avatar counts among the 3 is an existing open decision and MUST NOT be settled silently. Auto turret hardpoints do not cost separate party slots. Never give one saddle 2 free humans, 3 turrets, full mount attack cadence and 3 additional unrelated companions.

## 5. Mass, engineering fit and gameplay counters

Dinosaur carried mass includes **platform saddle + structural reinforcement + main crewed device + both autos + box empty mass + every loaded ammo round + seated humans + remaining cargo/barding**. Compute load ratio to **species comfortable capacity**. More mass contributes to physically valid MI stomp/tackle force and defending against incoming stomp stagger per accepted mass rules, BUT worsens acceleration, turn control, stamina, pathing, reaction windows and potential aim sway. Gun recoil can affect saddle stability and recovery; stable broad-backed Titan excels at accurate mobile fortification while a narrower Tyrant is less reliable on the move. Avoid double counting turret recoil as stomp damage or a full creature mass effect from only a tiny arm.

**Signature armored Brontosaurus fantasy**: trained tribe driver moves a plate-clad Brontosaurus with an elevated player-operated ballista and two small auto defense units; rider can target a second giant's exposed hide from the deck; small Compys underfoot need the mount's actual MI stomp, not a magically extended human sword. Heavy plate zones reject ordinary raptor pounce pins, yet the deck crew and exposed body regions are attackable; no universal invincibility. A Brontosaurus under turret fire and full armor is heavy and expensive, but slower to turn/reposition/dodge its enemy's weapons. No infinite-ammo raid steamroller.

**Protect primitive aesthetic**: combine *treated planks, reinforced bone blocks, cured bindings, braided sinew, shaped scutes, forge-made iron fittings and torsion arms*. Avoid modern targeting sensors, motorized cannons or powered mechs without a later separately approved technology stage.

## 6. Building/packaging and item manufacture

Saddle, ammo box and turrets are **individually manufactured owned physical objects**. Forge/carpentry/saddlery creates parts via processed-material recipes described in [23], then eligible saddle/equipment is fitted to a tame while stopped at accessible work zone. The previously supplied prefab-building document expects **completed buildings to pack, trade and redeploy as unique durable objects**. Mounted turret identities must remain coherent with that future feature; unpacking/packing gun may not create a duplicate deployed stationary tower. Saddle, weapons and ammo box can be sold separately once detached, outside combat; human passengers cannot be packaged inside buildings or a dinosaur. Empty/reconcile ammo on packing as defined by the box; don't delete or duplicate loaded reserve. The animal remains its own life/capture/ownership entity, never a container traded with its crew in it.

**Candidate (NOT available yet) manufacturing recipes:**
- Heavy platform saddle: reinforced beams + treated planks + reinforced bone blocks + cured hide bindings + forged fittings, plus species-specific fit requirement.
- One platform ammo box: reinforced stock + planks + iron fittings + hide straps, with actual bounded weight capacity.
- Compact crewed ballista: reinforced stock + long braced frame + braided sinew + shaped trigger; physical bolts from real dinosaur materials and forged iron at advanced tier.
- Two compact automatic side turrets: treated plank/honed bone mounting + spring/torsion/clockwork internals + finite shots/charge. An ancient wind-up sentry requires explicit wound energy and visible fire sector.
New recipe IDs, stations and precise quantities must be source-validated, not assumed available in current item/recipe tables.

## 7. Engine reality, schema and Claude implementation

**Today**, Player.mount/dismount and mounted movement support one rider only; creature JSON lacks true body mass/load/platform sockets. Current [Field Catapult](../../game/scripts/world/field_catapult.gd) is a fixed destructible 3x3 world-placed object with Player-only fire method, consumes stone_shot/toxin_pot from player's inventory and spawns a world SiegeProjectile whose source is also typed Player. It DOES NOT fire from a mount or follow moving platforms, support an NPC operator, shared ammo box or automatic mounted guns. Existing building/packaging lifecycle is a design target, not complete. Do not silently change any creature taming flags or ship turret assets as a result of docs.

**Suggested data entity relationships, not final code schema:**
- A **PlatformSaddleDef** defines eligible species/size, sockets [main, auto_left, auto_right, ammo_box], seats [driver,gunner], weight thresholds and compatible compact weapon definitions.
- A persistent **PlatformSaddleInstance** ties creature ID to fitted saddle equipment ID, exactly 0–3 unique weapon component IDs, 0–1 ammo box ID, two optional HUMAN actor IDs, per-socket HP/angle/reload.
- A single **PlatformAmmoInventory** owns finite actual ammo stacks and accounting; local turret magazines contain ammo already withdrawn from the one inventory. All resupply/move/shot/unload operations atomic with save.
- **CrewAssignment** is seat occupancy plus current player/AI role, valid scene presence, selected orders, skill and KO/capture state. No automatic spawn of tribe member from a name field.
- **MovingSiegeWeapon** uses owner/mount transform and valid local socket, separate physical world launch pose and turret instance identity. On fire, shot gets world motion and source actor for XP/threat. In future server PvPvE, authority validates targeting/ammo/fire/ownership.

**PLATFORM-01** Define eligibility whitelist and fitted saddle/hardpoint/socket data, exactly one crewed slot, two auto slots, one ammo box, real driver/gunner seats.
**PLATFORM-02** Craft platform saddle and ammo box from verified processed materials with carried mass, signed traits and saved unique IDs.
**PLATFORM-03** Build rigged deck/socket geometry and camera for a presently eligible *existing* large tameable species first, then expand to Brontosaurus/T. rex only when species have correct tame/mount support.
**PLATFORM-04** Add real tribe human helm/AI driver plus player gunner and inverse setup, safe swap commands, KO/death/capture/dismount handling.
**PLATFORM-05** Refactor FieldCatapult/ballistic interfaces to accept AI human source, mobile sockets and compact platform variants while preserving existing stationary catapult.
**PLATFORM-06** Mount up to two auto turret components with credible limited detection/arc, finite ammo, reload/reset and physics/LOS.
**PLATFORM-07** Implement ONE shared ammo box, per-class accepted rounds, atomic reservations, load, on-device magazines, competing automatic and crewed reload schedules and worker resupply.
**PLATFORM-08** Integrate new load capacity and encumbrance/turn/stamina/aim stability with dinosaur body-weight stomp bonuses and incoming poise; match deck size and recoil.
**PLATFORM-09** Account for driver+gunner under real human identities and three expedition slots without free operators or duplicated actors; clarify player avatar slot open decision.
**PLATFORM-10** Save/capture/die/pack/unpack/owner-transfer transactions, no duplicate equipped + packaged guns, ammo or humans.
**PLATFORM-11** UI for crew assignments, either play mode, Hold/Advance/Retreat orders, aim, all 3 gun status panels, **one shared box**, resupply, ammo priority, load and dismount.
**PLATFORM-12** Vertical slice tests: both seat configurations, 2 auto+1 main maximum, prevent a 2nd box, correct ammo subtraction, rescue/dismount, target LOS/vertical blind spot, moving shots, group damage cost, save/load and raid-safe home.

**Acceptance tests:**
1. Install main + two autos on valid platform, deny second crewed, third auto and second box, without consuming denied items.
2. Player drives; a physically present actual tribe human guns and uses finite bolts; autos operate within arcs. Remove gunner and crewed gun stops immediately.
3. Tribe driver obeys Hold/Advance/Retreat while player aims and fires main gun; mount cannot steer outside real physics.
4. Both autos fire near-simultaneously with only ONE compatible round remaining: exactly one succeeds and no negative ammo. Main gun incompatible ammo cannot fire; others remain usable.
5. Empty box plus empty local magazines means no shot. Worker resupply takes real haul/access time and cannot pull instantly from safe home at distance.
6. Ammo + weapons + driver/gunner are physically counted in load ratio; fully armed large dinosaur handles worse, and landed stomp/defender stability respects bounded new mass rules.
7. Fired projectile travels world trajectory from turret muzzle and cannot shoot through own neck; gun has blind spot at foot of huge dinosaur, but natural stomp still works.
8. Swapping roles never duplicates a human or adds extra allowed Expedition slots. Crewed gun doesn't fire without actual player/tribe gunner. No free loader.
9. Save/load, disconnect and pack/unpack preserve unique manufactured guns and ammo without free restoration, double spending or phantom crew.
10. Safe home remains no-raid; exposed PvE settlements may validly fight dinosaurs, optional PvPvE requires future authoritative server.

**This file is a design spec and backlog only. It does NOT add live saddle scenes, turret attachments, ammo storage logic, recipes, AI crew driving, or change current creature flags.**
