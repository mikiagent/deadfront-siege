# Tribe members and dock recruits (TRIBE M1, M2a hand-off)

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
| Work orders (M2a hand-off) | `game/scripts/tribe/tribe_work.gd` (`TribeWork`, static) |
| Member picker | `game/scripts/ui/tribe_assign_picker.gd` (`TribeAssignPicker`), opened from `CraftPlace` |
| Test | `game/tests/t_tribe.gd`, `game/tests/t_tribework.gd` (M2a) |
| M2a capture lab | `game/scripts/dev/tribework_lab.gd` (`-- --lab=tribework_lab --shot-dir=DIR`) |
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

## Work orders: hand-off (TRIBE M2a)

The survivor hands the labour of one craft or one construction site to a member and is free at once
(memo `docs/design/hunger-and-tribe-automation.md` §2.2). Numbers: `tribe.json` `work`, Open Questions T16-T24.

**Craft.** Station radial → **ASSIGN** (top-right hex; a CraftStation whose recipes a member can take, while
the tribe has members) opens the station's recipes. In the place-materials view the survivor places her
picks as for her own craft; **Assign…** beside Craft opens the member picker: one 64 px row per member,
"Joss · Weapon Tools 1 · 100% · 3s", or the member greyed out with the reason. Tapping a row:

- refusals (`TribeWork.craft_offer`): "Joss is busy (Crafting Plank 40%)", "Needs a workbench", "The smoker
  runs this by itself", "Kit already works here" (one worker per station), "Craft it once yourself first"
  (teach by doing), "Needs Tailoring 10" (the recipe's min level vs the member's skill), "Missing materials",
  "62% success, needs Tailoring 14" (below the 80 % minimum);
- accepted (`TribeWork.assign_craft`): the exact planned instances leave the bag into the member's escrow
  (`TribeRecord.escrow`), and the outcome (success, flawless, rare, burn) and output level are decided now at
  the member's skill and never re-rolled. Hand recipes stay the survivor's.

The member walks to the station (its reach, 2 m), plays the station's work loop (`work_anim` in
`station_state.json`: `work_hammer` with the hammer prop at the workbench, `work_stir` at the grill…) and
works for recipe seconds × max(0.5, 1 − 0.01 × skill). A plate over its head reads "Joss / Crafting Work Axe 40%".
On success the output goes to the storage building nearest the station within 6 m, else the survivor's bag
("Joss made the Work Axe (in the basket)"); what fits nowhere waits ("ready · no room") and is retried. XP
(6 + recipe seconds) goes to the member's skill for the recipe's tree, never to the survivor. A failed craft
spends the materials, as hers would. While an order runs, the radial shows **STOP JOSS** in the same slot.

**Build.** In the Construction panel, once every material is placed, **Assign builder** opens the same picker
(row adds the predicted station level: the builder's Construction caps it). The site's own timer stops; the
builder walks to the plot's edge, hammers, runs the work timer at its own speed and finishes the site itself
(`BuildFlow.complete(player, site, builder)`: level capped by the builder's Construction, XP to the builder).
Refused: "Missing materials" (not filled), "Already built: tap Finish", "Kit is already building it", busy.
The panel's button then reads **Stop Joss**.

**Cancel.** STOP on the radial, Stop in the Construction panel, or any other order (Stay, Follow, a gather
job) ends it and hands the whole escrow back to the bag, all or nothing; a full bag keeps the order and says
so. Escrow left without an order (bag was full, or a saved order no longer loads) goes back to the bag as soon
as it fits (`TribeDirector.sync`). A station that is gone pauses a craft; a site that is gone ends a build.

**Needs.** The M1 rules, unchanged (members keep their own fullness; the survivor's Digestion model is not
used): 0.25 fatigue and 0.15 energy per second of work; the member rests at fatigue 75 and eats from storage
near the station below 30 fullness, then goes back to work.

## Tribe screen

The Animals screen header gains a **Tribe** tab (after Pack and Taming Pen); the Tribe screen's own header reads Pack · Tribe and a counter "Tribe n / housing". Left: "At the dock (n / 3)" with time left, then members with level and what they are doing. Right: potential, level, skills, needs, current activity; Accept / Deny for a recruit; for a member the five orders, the three jobs, Rename (the character-name rule), the seven gear slots (tap to unequip) and every bag item it can wear (tap to equip). Refusals show in red under the actions. Tapping a member or recruit in the world opens the screen on them.

## Saves

Save key `tribe`: `{members: [...], pending: [...], arrival_left, seeded}`; each row is `TribeRecord.to_dict()` (identity, look, potential, level and skills, needs, gear, carried items, order, job, home position, wait left, and since M2a `escrow`).

M2a (2026-10-29, backward compatible): a member row may carry `escrow` (item rows, validated by `SaveSanitizer` like `carry`), a `job` of kind `craft` (`station` [x, z], `station_id`, `recipe`, `picks`, `level`, `burnt`, `outcome`, `seconds`, `progress`, `made`) or `build` (`site` id), and skills beyond Gathering and Melee. An old save has none of these and loads as before. A save written by this build and opened by an older one drops the craft order but keeps nothing of its escrow (old builds ignore the key): don't downgrade with an order running. An old save has no row and loads with no members. `SaveSanitizer` validates gear and carried items like bag slots; `TribeRecord.from_dict` clamps the rest and drops unknown orders and jobs.

## Not built (M2 and later)

Standing orders, hauling, pantry and cook orders (M2c), the full skill set and research caps (M2b), the Monitoring Stand (M2d), offline work catch-up, a Work tab on the Tribe screen. Direct control of a member (`Tribe.take_control` refuses), expedition slot limits, permadeath and revival, training and education, families, food and healthcare caps, worker rare-find odds, recruits at outposts.
