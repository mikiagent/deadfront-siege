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
| invulnerable | the first 0.32 s: a creature hit that would land then is dodged — no damage, no stagger, a "Dodged" line, Defense XP once |
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
