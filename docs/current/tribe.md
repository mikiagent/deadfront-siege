# Tribe members and dock recruits (TRIBE M1)

What the build does today. Numbers come from `game/data/tribe.json`; each is an assumption logged as
T1-T15 in `docs/vision/WildLandsMMO_Open_Questions.md`.

## Code

| Part | File |
|---|---|
| Roster, rules, save row | `game/scripts/tribe/tribe.gd` (`Tribe`, static) |
| One person | `game/scripts/tribe/tribe_record.gd` (`TribeRecord`) |
| Live body and brain | `game/scripts/tribe/tribe_member.gd` (`TribeMember`, CharacterBody3D) |
| Boat timer and bodies in the world | `game/scripts/tribe/tribe_director.gd` (`TribeDirector`, child `Tribe` of the Player) |
| Tribe tab | `game/scripts/ui/tribe_screen.gd` (`TribeScreen`), opened by `HuntHud.open_tribe(rec)` |
| Test | `game/tests/t_tribe.gd` |
| Capture lab | `game/scripts/dev/tribe_lab.gd` (`-- --lab=tribe_lab --shot-dir=DIR`) |

## Recruits at the dock

- A boat brings one recruit every in-game day (`arrivals.every_days` 1.0 × `Game.day_length_seconds` 720 s). The timer ticks wherever the survivor is.
- The recruit waits at the home dock (spawned beside `IslandRuntime._harbour_pos`). It never joins on its own.
- At most 3 wait (`pending_cap`); a boat that finds 3 waiting brings nobody. A recruit ignored for 1 in-game day (`wait_days`) leaves; the player gets a notice.
- The first home load of a world (or of an old save) offers one starter recruit (`starter_recruit`, flag `seeded`).
- A recruit has a name (24-name list), a random character-creation body (`CharacterLook.randomized`), level 1, Gathering 1, Melee 1, and an innate potential: weak 45 %, mediocre 40 %, capable 14.5 %, exceptional 0.5 %. Potential multiplies skill XP (×0.8 / 1.0 / 1.2 / 1.5) and never changes.
- **Accept** (`Tribe.accept`) moves the recruit into the tribe, order Stay. Refused while members ≥ housing: "No room: housing for N (build a bed or tent)".
- **Deny** (`Tribe.deny`) sends them away.
- Housing = 2 + 1 per tent, canvas tent, straw roll or bed at home (`Tribe.housing_cap`).
- Waiting recruits count on the MENU hex and on the nav menu's Animals entry (`HudField.count`) until accepted or denied.

## Members

- Seven gear slots, the survivor's (`EntityEquipment.HUMAN_SLOTS`: weapon, head, body, arms, legs, accessory1, accessory2). A work tool (pick, axe, knife, hoe) goes in the weapon hand. Equip moves the exact item out of the survivor's bag; unequip puts it back (refused when the bag is full).
- Needs: health (80 + 4 per level), energy 0-100, fatigue 0-100, fullness 0-100.
- Skills Gathering and Melee level at 40 × level XP; 2 XP per harvest or landed hit, times potential. Level = average of the two.
- At 0 HP a member is knocked out: it lies down, recovers HP ×3 faster, and stands at half HP. Nobody dies in M1.
- At home every member and waiting recruit has a body. Away, only members on a follow order come along.

### Orders (Tribe screen, `Tribe.set_order`)

| Order | Does |
|---|---|
| Follow | Walks to a follow slot after the survivor's summoned pets (`PetBrain.slot_for`); walks past 4 m from it, settles inside 1.5 m, runs past 8 m. Fights only what is attacking it. |
| Guard | As Follow, and also fights what attacks the survivor or her pets, and her hunt target, within 9 m. |
| Heel | Follows, never fights. |
| Attack | Fights the survivor's hunt target. |
| Stay | Stands where it is. |

Fights are leashed to 20 m from the survivor. A swing uses the worn weapon (a work tool hits at 45 %) or fists (6), minus the target's defence, +1 % per Melee level, at the weapon's rate (at least 1.1 s apart), with the survivor's attack clips. The damage source is the member: the kill leaves the normal corpse, and the member never butchers or loots. A creature hit by a member can turn on it (`CreatureAttack` deals it damage through `TribeMember.take_creature_hit`).

### Jobs (one at a time)

- Mine here / Chop here / Gather here sets the job at the survivor's position, radius 12 m, chest = the storage building nearest her (within 30 m). A new job replaces the old one; any follow or stay order ends the job.
- Loop: nearest node of that kind (`HarvestNode.gather_kind`: rock = mine, trees = chop, the rest = gather) inside the radius that its tool can work (`HarvestNode.can_gather`), walk to its visible edge (`HarvestNode.visual_radius` + 0.3 m), work it with `gather_mine` / `gather_chop` / `gather` and the tool in hand.
- Each pass lands exactly one item, taking `GatherService.unit_seconds_for(tool, node, Gathering)` seconds; the required tool wears per pass, a helper tool wears too, the item level is capped at max(Gathering, 5). Workers roll no rare finds or green traits.
- After 5 units it walks to the chest and deposits. No chest near the job: it holds what it carries and stands.
- Fullness drains 60 per in-game day. Below 30 it walks to the chest and eats one food item (+ its energy value, at least 15). No food: keeps working, looks again in 30 s.
- Each pass adds 2.5 fatigue and costs 3 energy. At 75 fatigue (or out of energy) it rests in place (sleep clip) until fatigue ≤ 10 and energy ≥ 50.

## Tribe screen

The Animals screen header gains a **Tribe** tab (after Pack and Taming Pen); the Tribe screen's own header reads Pack · Tribe and a counter "Tribe n / housing". Left: "At the dock (n / 3)" with time left, then members with level and what they are doing. Right: potential, level, skills, needs, current activity; Accept / Deny for a recruit; for a member the five orders, the three jobs, Rename (the character-name rule), the seven gear slots (tap to unequip) and every bag item it can wear (tap to equip). Refusals show in red under the actions. Tapping a member or recruit in the world opens the screen on them.

## Saves

Save key `tribe`: `{members: [...], pending: [...], arrival_left, seeded}`; each row is `TribeRecord.to_dict()` (identity, look, potential, level and skills, needs, gear, carried items, order, job, home position, wait left). An old save has no row and loads with no members. `SaveSanitizer` validates gear and carried items like bag slots; `TribeRecord.from_dict` clamps the rest and drops unknown orders and jobs.

## Not built (M2 and later)

Direct control of a member (`Tribe.take_control` refuses), expedition slot limits, permadeath and revival, training and education, families, food and healthcare caps, worker rare-find odds, recruits at outposts.
