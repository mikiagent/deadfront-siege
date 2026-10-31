# claude-fieldhud: field HUD to the owner's layout (2026-10-28)

Branch `claude/mmo-fieldhud`, cut from `claude/mmo-overhaul` at 4d3fbb5c, with `claude/mmo-overhaul` (51a8c46b) merged in.
No credits spent. Nothing pushed, merged upstream or deployed.

## What changed

- **Rail (bottom-left): MENU, BUILD, BAG.** The ANIMALS and SKILLS rail hexes are gone. Skills and Animals are now entries in the MENU sheet. Neither had a hotkey before, so there were none to keep. BAG moved here from above HANDS, and the `I` key still opens the bag.
- **INTERACT (bottom-right, large)** is in `game/scripts/ui/hud_field.gd`. It shows and runs `PlayerInput.interact_choice()`. The E key and pad A use the same pick, so there is one interact path. Order: dismount, then bed (sleep), pen, OPEN station, field, fire, butcher corpse, harbour, warp, OPEN basket, GATHER a node within arm's reach, your pet, DRINK at fresh water, and finally GATHER the nearest resource within 12 m. The last step reuses the Space gather path, so there is no second gather system. The icon and caption follow the pick, rescanned every 0.2 s. When nothing is near, the hex is disabled. The context row leaves out whatever INTERACT already shows.
- **ATTACK NEAREST** sits above INTERACT and runs `PlayerInput.attack_nearest()` through `PlayerActions.attack`. Out of combat it fights the selection, else the nearest wild animal. It is disabled when no animal is in range, and it never swings at scenery.
- **SPRINT** is a tap toggle on the HUD.
- **MENU badge.** It uses `HexButton.badge` plus a new `badge_ink`. It shows a count, or "9+" above nine. It is GOLD with ink text, and LIFE red when any notice is urgent. Two things feed it, both under `skills`:
  - a skill level-up
  - SP starting to afford a node
  
  Opening Skills clears the `skills` notices. The MENU sheet shows the count as "Skills (n)". There is also a market hook, `HuntHud.notify_menu(&"market")`, but nothing calls it yet. This replaces the SKILLS hex's gold halo.
- **Owner combat rule (added mid-task).** Out of combat, a tap only selects an animal, and the swords hex or ATTACK starts the fight. In combat:
  - a tap on another enemy retargets at once through `PlayerActions.attack`
  - the swords hex is hidden
  - ATTACK NEAREST retargets to the nearest enemy
  
  The rule is recorded in spec §11.
- **Sizes and look.** Sizes follow spec §2 (`HudField.PX`). Desktop: rail 100, INTERACT 150, ATTACK 100, SPRINT 100, quick slot 80, whistle 66, CLAIM 52. Compact canvases use 64/96/72/64/64/64/64. All hexes are flat-top with `HUD_RIM` rims.
- **CLAIM** is a gold-rim hex, right-aligned under the minimap's X/Y line.
- **HANDS** moved to the quick row's fourth slot (`HuntHud.hands_spot`) and now draws flat-top.
- **Desktop pet whistle row** moved beside the rail. Combat hexes were re-placed so they clear the new cluster on both canvases (`hud_layout.gd`). Bottom rows now sit above the XP line.
- `UiTokens.hud_reserved` desktop zones were updated for the bigger rail and the INTERACT cluster.

## Key bindings
There are no new InputMap actions. `interact` (E, pad A) and `attack` (F, pad X) already existed and keep their keys. Space still gathers the nearest resource, Q still rolls, and I opens the bag.

- **E:** if a selection's swords hex is on screen, E fights it, as before. Otherwise it runs INTERACT's pick, which now also drinks and gathers up to 12 m away.
- **Shift:** on the keyboard it still sprints while held. The HUD SPRINT hex is a toggle.

Desktop hexes show their key in a small box: E, F, Shift and I. The box is hidden on compact canvases.

## ASSUMPTIONs
1. Hex sizes switch on `UiTokens.is_compact` rather than `is_phone`. `is_phone` means a canvas under 720 px wide, so it would give 844x390 the 150 px desktop hexes.
2. CLAIM is 64 px on phones instead of 52, to meet the 64 px tap rule. On a landscape phone it has no caption, because there is only 60 px between the map text and INTERACT.
3. On a landscape phone, ATTACK NEAREST stands up and to the left of INTERACT, above SPRINT. The minimap column leaves no height above INTERACT.
4. INTERACT has no Talk or Pick up entry, because no NPCs or loose ground items exist. A nearby pet gets "Pet", which opens its radial (Ride is in there).
5. The MENU badge is gold for normal notices and red for urgent ones, as spec §11 says. Nothing is urgent yet. Market notices are a hook only.
6. The SP notice counts once each time SP starts to afford a node. It does not stay on permanently while SP is unspent.
7. Landscape-phone combat placement (skill row along the bottom, End Combat above INTERACT) is our own call; no reference image covers it.

## Gates (after the merge, fresh import)
- `[t_fieldhud] PASS`. Rect checks: `844x390 idle: 35 rects, 0 overlaps`, `844x390 combat: 45 rects, 0 overlaps`, `1600x900 idle: 36 rects, 0 overlaps`, `1600x900 combat: 45 rects, 0 overlaps`. Every rect is on screen, and every tap target at 844x390 is 64 px or more.
- `[t_ui] PASS`, `[t_controls] PASS`, `[t_targetui] PASS`, `[t_petradial] PASS`, `[t_gatherglide] PASS`, `[t_rest] PASS`, `[t_invscreens] PASS`, `[t_uitokens] PASS`, `[t_uiicons] PASS ids=196 ...`, `[t_player] PASS`, `[t_skillfeel] PASS ...`, `[t_claimfix] PASS`, `[t_daynight] PASS`
- `tools/smoke.sh --no-import`: `SMOKE PASS`. run_all: `[tests] PASS`, with only the known 3 TouchControls compile-order errors and the deliberate econ fault errors.
- Asserts changed because the owner's layout changed them:
  - **t_controls:** CombatToggle became AttackNearest. Its second tap now keeps the fight instead of disengaging, and End Combat disengages. The Bag button moved from above HANDS to the rail, so the assert now checks a rail BAG hex in the bottom-left.
  - **t_ui:** the HANDS rect is now quick-row slot 4 instead of over the old rail's fourth hex. The zone check itself is unchanged.

## Look at on screen (headless only so far)
- INTERACT, ATTACK and SPRINT at 844x390: the up-left ATTACK placement, and how the icon and caption swap between GATHER, DRINK and OPEN.
- MENU badge legibility. The circle is about 16 px on a 64 px hex.
- Icon-only CLAIM on a landscape phone.
- Desktop at 1600x900 with the 100 px rail and 150 px INTERACT: check the size feel against the spec's B1 shot.
- Portrait (390x844) was laid out but not gated.
- `docs/current/screens/*.webp` are now stale. Rerun `tools/ui_screens.sh` (windowed).
