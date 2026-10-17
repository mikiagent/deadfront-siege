# Controls

Deadfront plays with touch, mouse and keyboard, or a gamepad. The action names are the same on every
device, so a new input only needs a binding in `game/scripts/core/input_setup.gd`.

## Gamepad

Xbox naming. PlayStation and Switch pads map to the same positions.

| Input | Action |
|---|---|
| Left stick | Move |
| A | Interact, and gather from the nearest node (opens its option wheel) |
| X | Attack the nearest creature |
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
| Shift | Sprint |
| Space | Roll |
| E | Interact, gather from the nearest node |
| F | Attack |
| 1 2 3 4 | Tactics |
| I | Bag |
| C | Crafting |
| B | Bandage |
| H | Hold or chase toggle |
| M | Map |
| Esc | Pause |
| R, Enter | Rotate and confirm while placing |
| F11 | Full screen |

Mouse or touch taps gather, attack and place directly.

## Full screen

F11 toggles full screen on desktop and in the browser. The pause menu also has a Full screen button,
which is the reliable route on a phone or tablet browser because browsers only allow full screen from
a tap or key press.

## Not yet on the gamepad

The four HUD hexes (Menu, Animals, Build, Skills) are drawn by hand and cannot take pad focus yet.
Bag, crafting, map and pause have direct buttons. Animals, Build and Skills still need a pad shortcut or
a focus ring.

## What has been verified

Verified in the web build, served locally and driven in a browser pane:

- F11 reaches the game and requests full screen. The pane itself refuses the browser's full screen
  permission, so the screen change was not observed there.
- A simulated controller is detected and shows "Controller connected".
- The left stick moves the survivor and Start opens the pause menu, which shows the Full screen button.
- Unit tests cover the bindings, including stick directions and the dead zone.

Not verified: a physical controller, and the actual full screen switch in a real desktop or phone browser.
Both need a person with the hardware.
