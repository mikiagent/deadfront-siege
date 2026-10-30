# Controls

Deadfront plays with touch, mouse and keyboard, or a gamepad. The action names are the same on every
device, so a new input only needs a binding in `game/scripts/core/input_setup.gd`.

## Gamepad

Xbox naming. PlayStation and Switch pads map to the same positions.

| Input | Action |
|---|---|
| Left stick | Move |
| A | Interact: the HUD INTERACT hex's pick (dismount, bed, station, fire, corpse, water, else gather the nearest resource within 12 m); with a selection on screen, fight it |
| X | Attack: the fight's target, else the selection on screen, else the nearest creature |
| B | Roll |
| Y | Crafting |
| Left stick click | Sprint |
| LB | Tackle |
| RB | Kick |
| Right trigger | Tactic 3 |
| Left trigger | Net |
| D-pad up | Hold or chase toggle |
| D-pad down | Bandage |
| Back | Bag |
| Start | Pause |
| Right stick click | Map |

While placing a building: A confirms, B cancels, RB rotates.

A notice appears when a controller connects. In the browser, press any button once first, because
browsers hide a controller until it is used.

## Keyboard and mouse

| Key | Action |
|---|---|
| W A S D or arrows | Move |
| Shift | Sprint while held (the HUD SPRINT hex is a tap toggle). While riding, Shift or the toggle runs the mount on its own energy; otherwise it walks |
| Q | Roll |
| Space | Gather the nearest resource |
| E | Interact (the INTERACT hex's pick); with a selection on screen, fight it |
| F | Attack |
| X | Rest |
| 1 2 3 4 | Tactics |
| I | Bag |
| C | Crafting |
| B | Bandage |
| H | Hold or chase toggle |
| M | Map |
| Esc | Pause |
| R, Enter | Rotate and confirm while placing |
| F11 | Full screen |

Mouse or touch taps gather, attack and place directly. On the HUD: INTERACT (E, pad A) and ATTACK
NEAREST (F, pad X) bottom-right, SPRINT beside them (tap toggles), MENU / BUILD / BAG (I) bottom-left.
There is no HANDS hex (removed 2026-10-28): INTERACT or Space gathers the nearest resource, and the held
tool changes in the bag (select a tool: Equip tool, or Unequip tool on the one held) or on the Character
sheet's tool slot (each tap cycles to the next tool).
Desktop hexes show their key in a small box. No new InputMap action was needed: `interact` (E, A)
and `attack` (F, X) already existed and keep their keys.

Targets (owner 2026-10-28): out of combat a tap on a wild animal selects it; the swords hex, ATTACK
NEAREST, E or F start the fight. In combat a tap on another enemy retargets at once and ATTACK
NEAREST retargets to the nearest enemy.

Move orders and interacting (owner 2026-10-28): a tap on the ground is a **move order** and outranks
combat. While she is walking to that point the hunt does not auto-chase or auto-swing, even with a
target in reach; a tap on an enemy still selects or retargets, it just does not cancel the move.
Taking real damage (a creature hit, not a bleed/DoT tick) ends the move after the hurt stun: she turns
on the attacker if it is within attack range (28 m), otherwise on the nearest hostile. A ground tap
also cancels an interact errand she was walking to — sleep at a tent, gather, loot, craft at a station
— so the intent and the path both drop and she never finishes it; the same happens the moment you
steer with the keys or the stick. Keys and stick keep driving her directly with no move order, which
leaves today's combat behaviour (auto-attack, auto-chase) in place. A craft already started at the
bench keeps running; only a queued-but-unstarted recipe is dropped.
## Facing and walking away from a fight

Owner 2026-10-28: "player has the turn speed glitch too" and "if i'm in combat and i try to walk away,
my player glitches out... pathfind to where I want to walk and then re-engage".

- One writer turns the survivor: `PlayerSim.face_tick`, every physics frame. While she moves (stick or
  a tap route) she faces the move direction. Standing still in a fight she faces her target. Nothing
  sets her facing from `_process` any more, because the hunt's per-render snap fought the walk's turn.
- She turns at most 720 deg/s (`Player.turn_rate_deg`), so a 180 deg turn takes 0.25 s, or about
  0.28 s from a run. The move heading is smoothed over 0.04 s. Below 0.3 of full stick, for example
  when the stick flips through the centre, she keeps her facing. She only turns once she is more than
  3 deg off the heading, so stick noise and path wobble do not shake her. All of these numbers are
  ASSUMPTIONS.
- The roll still snaps her to its direction, and the tackle and kick still face the target at once.
- Mounted, the mount steers by its own `turn_rate`, on a heading smoothed over 0.15 s with the same
  3 deg slack (`Creature.face_heading`).
- A ground tap during a fight keeps the target. While she walks there, the hunt does not chase,
  swing or turn her. When she arrives she re-engages that target. If it died, left, or is more than
  28 m away, she engages the nearest animal instead, or the fight ends if there is none. A bite on the
  way cancels the walk and turns her on the biter (move priority).
- While the stick moves her, the hunt pauses in the same way. When the stick is released she fights
  again.
- Labs: LabKit now bakes its navmesh from static colliders, crates included. It used to bake from the
  render mesh, which is empty in a headless run. Off an island, the survivor follows the navmesh route
  with the same waypoint follower as the island tile path. The NavigationAgent's own follower never
  advanced for her: it measured from her capsule centre, 0.5 m above the mesh, so a ground tap in
  the creature lab rocked her in place. A re-plan also no longer sends her back to her start tile or
  her own tile's centre.
- `game/tests/t_playerturn.gd` measures all of this.

## AUTO-ABILITY (2026-10-29)

The AUTO-ABILITY hex sits beside AUTO in the combat layer (64 px, same style; on desktop under
TACKLE's caption, centred on TACKLE between KICK and AUTO since NORTHFOLLOW 2026-10-30, so it no longer
covers the caption (`HudLayout.place_desktop`, `t_fieldhud`); between FEED and AUTO on phones). It is **on by default** for new and loaded games (the flag lives on
`Hunt.auto_ability`, not in the save, so an older save gets the same default). While a fight runs and
the toggle is on, the hunt casts the strongest **auto-castable** ability that is off cooldown, in
body-edge reach, line of sight and affordable (stamina) **instead of the next basic attack** — owner:
"uses the player's most powerful ability off cooldown and prioritizes that over basic attacks".

- "Most powerful" = highest expected damage per cast (the ability row's damage x the weapon's damage),
  tie-break the longer cooldown. # ASSUMPTION (docs/vision/WildLandsMMO_Open_Questions.md AUTOABILITY):
  the rows are flat ability damage today (tackle 6, kick 4), so the rank is the row damage.
- Only Tackle and Kick are auto-castable by default; Roll (a dodge) and Net (a capture tool) stay
  manual. Which abilities the auto-cast may use is data:
  `game/data/combat_tuning.json auto_ability.abilities` (a row with `auto: true` joins the rotation).
- The cast runs the same gates as the manual press (reach, line of sight, stamina, the tactic lock, a
  hurt stun) and never spams a refusal notice; when nothing qualifies the basic attack takes over.
- A click-to-move order, the movement stick, a roll or a hurt stun still outrank everything, exactly
  as with the auto-attack. Toggling the AUTO hex off stops the auto-attack entirely; toggling
  AUTO-ABILITY off keeps the auto-attack but only ever basic-attacks.

## Chase sprint (auto-sprint after a fleeing target)

Owner: "when chasing a fleeing enemy, when it leaves a certain radius around the player, toggle
sprint to chase it". While the hunt has a live target, the survivor sprints by herself once it is
**farther than 7 m**, and drops back to a walk once it is **within 4 m** — the two radii are a
hysteresis band, so a target hovering at the edge cannot make her stutter. Both numbers are
`# ASSUMPTION` defaults (`Player.CHASE_SPRINT_ON_M` / `CHASE_SPRINT_OFF_M`).

- It uses its own flag (`Player.chase_sprint`), never the HUD SPRINT latch: a sprint the player
  tapped on stays on, and chase-sprint turning off never turns their latch off.
- It ends with the chase: target dead or cleared, End Combat, or a ground-tap move order (a move
  order outranks combat, so she stops sprinting after the target too). The hunt keeps its target
  through the move order, so the sprint comes back when the order ends.
- Energy is respected: a winded survivor (empty stamina or the Exhausted tier) is never forced to
  sprint, and the forced sprint only returns once the bar is back to a quarter.
- Mounted, the same flag asks the mount to run, on **its own** energy pool; a winded mount walks.
- The HUD SPRINT hex tracks the player's own latch only, so it stays unlit while chase sprint is
  running her; the hex is the manual override, not the auto state.
- `game/tests/t_chasesprint.gd` measures the radii, the hysteresis, the manual latch, the winded
  case, the move order, the chase ending and the mounted case.
- Open questions CS1-CS4 in `docs/vision/WildLandsMMO_Open_Questions.md` hold the numbers as
  ASSUMPTIONs for the owner to tune.

## Full screen

F11 toggles full screen on desktop and in the browser. The pause menu also has a Full screen button,
which is the reliable route on a phone or tablet browser because browsers only allow full screen from
a tap or key press.

## Roll

Space (keyboard) or B (gamepad) rolls; the ROLL hex in the hunt row does the same on touch. The roll is
directional: it goes the way the stick or keys point, and with no direction held it is a **backward
roll**, away from where she faces — she keeps facing forward (no turn), because there is no separate
back-roll clip. The numbers live in `game/data/combat_tuning.json` `roll` and are timed by
`scripts/combat/roll_rules.gd`:

| | today |
|---|---|
| dash | 0.56 s, 39 m/s at the press decaying to 0.2 of it, ~10.9 m on open ground |
| invulnerable | the first 0.32 s: a creature hit that would land then is dodged — no damage, no stagger, a "Dodged" line, Defense XP once. Defense trains only through `CombatAvoid.avoided(..., earned)`: this roll, or stepping out of a telegraphed attack, when the attack would have landed; a hit taken, an accuracy miss or a roll with nothing to avoid pays none (owner 2026-10-28) |
| cost | 12 stamina |
| cooldown | 0.9 s from the press; a press inside it is refused ("Roll on cooldown") |

A wall, fence or building stops the roll where a walk would. `tests/t_roll.gd` measures all of it
(distance, wall, left vs backward direction, the 0.15 s dodge and the 0.5 s hit, cost, cooldown, no XP
for spamming, and the server's `act.roll` window).

## Not yet on the gamepad

The HUD hexes (MENU, BUILD, BAG, INTERACT, ATTACK, SPRINT) cannot take pad focus. INTERACT, ATTACK,
Bag, crafting, map and pause have direct buttons. MENU (and Skills / Animals inside it) and BUILD still
need a pad shortcut or a focus ring.

## What has been verified

Verified in the web build, served locally and driven in a browser pane:

- F11 reaches the game and requests full screen. The pane itself refuses the browser's full screen
  permission, so the screen change was not observed there.
- A simulated controller is detected and shows "Controller connected".
- The left stick moves the survivor and Start opens the pause menu, which shows the Full screen button.
- Unit tests cover the bindings, including stick directions and the dead zone.

Not verified: a physical controller, and the actual full screen switch in a real desktop or phone browser.
Both need a person with the hardware.
