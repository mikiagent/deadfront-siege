# TRIBE M1 — Claude report (2026-10-28)

Branch `claude/mmo-tribe`, cut from `origin/claude/mmo-overhaul` at `bcb1751b`. Not merged or pushed.
Owner asks: "tribe members are like pals in palworld who can mine and fight" and, mid-task, "keep the
recruit in the harbor, we have to manually accept or deny them". The design follows vision §5 and
`WildLandsMMO_Loss_Recruitment_Revival.md`; facts in `docs/current/tribe.md`.

## What shipped

- **TribeRecord / Tribe** (`game/scripts/tribe/`): a persistent person with name, random character-creation body, innate potential (mostly weak or mediocre, 0.5 % exceptional), level, Gathering and Melee, health/energy/fatigue/fullness, the seven survivor gear slots (`EntityEquipment.HUMAN_SLOTS`), carried items, order, one job, home position.
- **Dock recruits**: a boat brings one about once per in-game day. They **wait at the home dock** (cap 3) for the player to tap them or open the Tribe tab and **Accept** (joins, refused with a reason when housing is full) or **Deny** (leaves on the boat). An ignored recruit leaves after a day. A starter recruit waits on the first home load. Waiting recruits badge MENU and the nav menu's Animals entry until answered.
- **Housing**: 2 + 1 per tent / canvas tent / straw roll / bed at home.
- **TribeMember** body: the survivor GLB, rig and clips with the member's look, tool or weapon in hand (`HeldModel`). Orders follow / guard / heel / attack / stay, using PetBrain's follow slots after the summoned pets. Guard engages what attacks the survivor, her pets or the member. Swings follow Hunt's damage rules with the attack clips; the corpse stays the world's (members never loot). Creatures can hit members back (`CreatureAttack` branch); a member at 0 HP is knocked out and gets up at half HP.
- **Jobs**: Mine / Chop / Gather here, radius 12 m, into the storage building nearest the spot. One item per pass at `GatherService.unit_seconds_for` with the member's tool and Gathering level, tool wear, tier gate; carries 5 then deposits; eats from that chest when hungry; rests when exhausted. One job at a time; a follow order ends the job.
- **Tribe tab** (`TribeScreen`, SheetChrome): from the Animals header, or by tapping a member or recruit. Lists dock and members; Accept/Deny; orders; jobs; Rename; equip from bag / unequip into the seven slots.
- **Saves**: new `tribe` key (members, pending, boat timer, starter flag). Old saves load with no members. Sanitizer validates gear and carried items; `from_dict` coerces the rest.
- **M2 hook**: `Tribe.take_control(rec)` (refuses), `TribeRecord.controlled`.

Touched outside `scripts/tribe`: `player.gd` (director child), `player_input.gd` (tap a member), `creature_attack.gd` + `creature_brain.gd` (members as targets), `entity_equipment.gd` (tools go in the hand slot), `harvest_node.gd` (`visual_radius()`), `save_game.gd`, `save_sanitizer.gd`, `hud_field.gd` (badge count), `hunt_hud.gd` (`open_tribe`), `animal_screen.gd` (Tribe tab). Data: `game/data/tribe.json`.

## Gates

| Gate | Result |
|---|---|
| `t_tribe` (dock wait/cap/expire/accept/deny/housing, rarity, save/load + forged rows + old save, equip, follow slot, guard damages a raptor attacking the survivor, mining 1 per pass at the pick's time into the basket + tool wear, eats from the chest, rests, one job, Tribe screen Accept + badge) | PASS (9/9 sections) |
| t_petfollow, t_tame, t_gather, t_onegather, t_combat, t_saddles, t_save, t_uinav, t_uianimals | PASS |
| run_all | `[tests] PASS` |
| `bash tools/smoke.sh --no-import` | SMOKE PASS |
| t_perfgates | PASS (home build 2174 ms alone; one run under 7 parallel Godots read 2593 ms and failed, rerun alone passed). No tribe body spawns in those islands; heap overages are pre-existing and not enforced. |

## Screenshots (`docs/orchestration/reports/tribe/`)

- `tribe_mining_1600x900.png` — Wren mining a rock near camp with the pick, basket beside; survivor watching.
- `tribe_fight_1600x900.png` — Joss (guard) swinging a knife at a raptor beside the survivor.
- `tribe_mining_844x390.png`, `tribe_fight_844x390.png` — the same at phone landscape. The phone fight shot hides the HUD: the combat hexes cover the centre of the screen there.
- The two 1600x900 captures were shrunk to 920 px wide (80-colour PNG) to fit 300 KB; the 844x390 ones are full size (192 colours).

Looked at: miner stands at the rock's edge in the mine clip (an earlier run had him inside the boulder card; fixed with `visual_radius`); fight reads as two humans on one raptor but is crowded; phone fight is small at the phone camera distance. The member has no name plate over its head yet.

## Assumptions

T1-T15 in `docs/vision/WildLandsMMO_Open_Questions.md` (2026-10-28, TRIBE M1 block); every number in `game/data/tribe.json`. The ones most worth an owner look: T1 boat rate (1 per in-game day vs the doc's 1 per 3-5 real days), T4 housing (2 + beds), T8 knock-out instead of death, T11 no rare finds for workers, T14 no limit on followers away from home.

## Risks / next

- Following members are not capped by the vision's three expedition slots; several followers plus three pets crowd the slot fan.
- Members are not prey for wild AI on their own (`_nearest_live_prey` only sees the survivor and pets); they draw aggro only by hitting.
- Workers use the survivor's learned techniques for skill-locked materials (`HarvestNode.can_gather` reads the local survivor).
- The arrival and departure timers count physics seconds, not `Game.time_of_day`: anything that jumps the clock forward does not move boats, and offline time is not caught up.
- No world name plate or HUD indicator for members yet; jobs centre on the survivor's position (no "pick a spot" mode).
- Credits spent: none (no paid generation). No Codex.
