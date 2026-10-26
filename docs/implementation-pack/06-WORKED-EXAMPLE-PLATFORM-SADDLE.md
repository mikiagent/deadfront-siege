# Worked spec example | Platform saddle, crew and ammo

**Purpose:** Demonstrate the granularity required for a Claude-codable system. This is a **DRAFT DESIGN CANDIDATE**, not `BUILD_READY`.

**Owner-confirmed constraints:** A large, eligible animal's saddle can equip up to **1 crewed siege weapon, 2 automatic weapons, 1 shared ammo box**. Either player drives while a real tribe member guns, or player guns while a real tribe member drives. The turret box is physical, finite and shared. Source: `docs/game-design/25-platform-saddles-and-mobile-siege.md`, plus related chapters 12, 22, 24.

**Unapproved here:** species eligibility, comfort load, mass-to-damage curve, ammo capacity, automatic targeting technology, aiming spread, gunner skills, seat swapping times, company AI, companion-slot accounting and constants below. These are candidates to discuss, **not instructions for implementation**.

## Interface proposal

```text
PlatformSaddleInstance
  id: UUID
  animal_id: UUID
  saddle_item_id: UUID
  hardpoints: {main: ItemId?, auto_left: ItemId?, auto_right: ItemId?}
  shared_ammo_inventory_id: UUID?
  seat_driver_human_id: UUID?
  seat_gunner_human_id: UUID?
  operational_state: [STOWED, ACTIVE, DISABLED, BROKEN]
  version: integer

MountedTurretInstance
  id: UUID
  gun_def_id: string
  ammo_type_id: string
  loaded_rounds: integer >= 0
  magazine_capacity: integer > 0
  ready_at_simulation_tick: integer
  durability: integer >= 0
  aim_yaw_degrees: float
  aim_pitch_degrees: float

CrewOrder
  type: [HOLD, MOVE_TO, FACE_TARGET, RETREAT, HOLD_FIRE, ENGAGE_ALLOWED]
  target: WorldPosition? or EntityId?
  issued_by_human_id: UUID
```

All references are unique IDs; no auto-created crew person. One human cannot simultaneously occupy driver and gunner, another saddle, and an expedition ground actor. The player viewpoint/control switches between existing actors/seats; the player is not duplicated.

## Seat transition table

| Event | Allowed when | Atomic effects | Rejected when |
|---|---|---|---|
| Assign tribe driver | Human exists, available, permitted, not assigned elsewhere | Occupy driver seat, actor enters mounted state | Missing/stunned/dead/imprisoned/already seated |
| Assign tribe gunner | Human distinct from driver, available, qualified | Occupy gunner seat; crewed gun may operate | Same human is driver; skills missing |
| Player takes driver | Player survivor available and has legal mount interaction | Player at helm; former driver leaves seat safely | Seat collision, animal unstable, command denied |
| Player takes main gun | Survivor available and legal boarding path | Player at main gun; existing driver persists or trained mount holds | No main gun / inaccessible seat |
| Gunner KO or dismount | Always handled | Vacate main gun, cancel pending gunner fire; retain loaded round | Never create phantom replacement gunner |
| Driver KO or dismount | Always handled | Vacate helm; issue trained Hold/safe fallback; cancel direct steering | Never give gunner simultaneous free helm control |
| Dino dies/falls | Always handled | Disable firing, resolve passengers and equipped item persistence exactly once | Never keep a world-moving platform after mount destruction |

**OPEN:** exact seat-change duration, damage interruption and mounted human vs companion slot costs. This table is an interface proposal.

## Shared ammo authoritative sequence

```text
reload(turret_id, ammo_type, txid):
  reject if txid previously succeeded (idempotent replay)
  reject unless turret belongs to this saddle
  reject unless valid ammo inventory linked and weapon compatible
  begin atomic transaction / local lock of ammo inventory + turret
  n = min(magazine_capacity - loaded_rounds, available_compatible_rounds)
  reject if n == 0
  debit exactly n rounds from shared box
  increment loaded_rounds by n
  record txid and commit
  emit reload event; never spawn projectile

fire(turret_id, shot_id, target):
  reject if shot_id already fired
  reject if unstaffed crewed weapon / invalid authorization
  reject if invalid arc, line of sight, cooldown, or no loaded round
  atomically decrement loaded_rounds by 1 and record shot_id
  spawn exactly one world-space projectile with snapshot launch velocity
  record fired round; no projectile remains parented to animated saddle
```

If projectile spawning fails after consumption, transaction recovery must either finish spawning the same `shot_id` once or roll back the shot safely. Save/load and future server replay require deterministic idempotency. The shared box is the **only reserve inventory**, although loaded chambers count as physical outstanding rounds.

**Hard conservation invariant for each ammo type over an accounting interval:**

```text
initial_rounds + incoming_resupply =
   current_box_rounds
 + currently_loaded_rounds
 + fired_rounds
 + discarded_or_destroyed_rounds
 + transferred_out_rounds
```

Destroying/packing the saddle must move or account for every still-loaded round. A unit test must assert this across any legal operation sequence.

## Candidate load math to REVIEW, not ship yet

Do not ask Claude to invent these coefficients in code. These example constants are explicitly **PROPOSED** to illustrate how a future balance pack would work:

```text
carried_mass_kg = saddle_mass_kg
  + main_turret_mass_kg + auto_left_mass_kg + auto_right_mass_kg
  + box_empty_mass_kg + rounds_mass_kg
  + driver_mass_kg + gunner_mass_kg
  + armor_mass_kg + other_cargo_kg

ratio = carried_mass_kg / species_comfort_capacity_kg
# capacity must be a positive approved per-species constant

if ratio > 1.20:
    reject boarding/equipping the additional load (candidate rule)

strain = clamp((ratio - 0.70) / 0.50, 0, 1)
speed_multiplier = 1.00 - 0.40 * strain
# [1.00 at <=70% comfort load, 0.60 at 120% comfort load]
```

Actual final gameplay may prefer gentler curves, excess-load hard stops or different species-specific shapes. The confirmed idea is **loaded mass has meaningful mobility and impact consequences**; the precise curve and species comfort capacities are still OPEN.

**Worked arithmetic fixture (proposed):**

| Component | kg |
|---|---:|
| Saddle | 300 |
| Crewed siege weapon | 180 |
| Two autos | 90 + 90 |
| Empty ammo box | 40 |
| Ammo | 50 |
| Two humans | 80 + 70 |
| Other cargo | 30 |
| **Total load** | **930** |

For a hypothetical 1,000 kg comfort capacity, ratio = 0.93. Then strain = (0.93 - 0.70) / 0.50 = 0.46, multiplier = 1 - 0.40 * 0.46 = **0.816**. A hypothetical 6.0 m/s unloaded speed would become **4.896 m/s**. Exact arithmetic is useful for tests **only after** the design owner approves the model and constants.

## Mandatory deterministic acceptance cases

1. With one real player driver and one available tribe gunner, the driver can steer and the AI gunner fires only when a legal shot, ammo, range, line of sight and reload allow it.
2. With the same humans swapped, player aim controls the manned gun and tribe AI controls legal dinosaur motion through real orders. No avatar clone is created.
3. With no gunner, the main cannon never fires; eligible autos still fire from physical loaded ammo.
4. Two simultaneous reload requests against one remaining round permit exactly one success; the other correctly reports empty.
5. With six rounds, loading one into each weapon leaves three in box; firing one leaves two loaded, three in box and one fired. Total remains six.
6. After saving while two rounds are chambered, reload restores exactly two, not zero or four.
7. A KO/death/dismount invalidates only the affected human role, and the mount follows its trained fallback. Stolen, duplicated or free crew is impossible.
8. Rounds fired from a moving mount have a frozen initial world launch pose/velocity and travel independently.
9. Home island immunity is checked at shot authorization, even if all physical turret conditions allow firing.
10. Species lacking a compatible back socket cannot equip the three-gun deck, regardless of inventory or visual mesh trickery.

## Stop conditions for implementation

Do not mark this example BUILD_READY until the owner approves concrete eligible animal data, comfort capacity, mass/recoil formulas, ammo priority, actual primitive automatic mechanism, seat actions, companion-slot accounting and launch/aim behavior. See `05-READINESS-GAPS.md` and chapters 12, 22, 24, 25.

The distinction is intentional: **complete algorithms and numerical fixtures are the destination**, but a plausible worked proposal is not silently elevated to an owner's design choice.
