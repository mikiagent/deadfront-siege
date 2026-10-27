# dsc-skillfeel: skills say what they did

Feedback for the skill systems (spec 25 §7, spec 03:7, islands-and-loop-plan §3.3 "Skills"). The
numbers (XP amounts, costs, levels) are untouched: balance is a separate owner decision.

## What shipped

- **Skill XP toast.** `SkillState` now emits `skill_xp_gained(tree, amount, level)` on every gain that
  is not the mirrored Survival route proficiency and not at Lv. 60; `skill_leveled(tree, level)` fires
  per tree level. `HuntHud.bind()` wires both into `HudEventState`:
  `add_skill_xp` merges gains of one tree inside 1 s ("+7 Gathering XP"), `add_skill_level` is the
  bigger gold line ("▲ Survival Lv. 6"), and repeated level-ups of one tree fold into one line with the
  newest level. At most 4 lines are on screen (`SKILL_MAX`); XP lines live 1.6 s, level-up lines 3 s.
  The HUD draws them after the level-up banner, before pickups and notices, each through
  `UiTokens.free_spot`, so they never cover the vitals, the map, the quest card, the target plate or the
  survivor; on a landscape phone they take the left column under the vitals.
- **FULL at the cap.** `SkillsSheet`'s overview row marks a tree at the character-level cap with a gold
  `SkillFull_<tree>` label, "FULL · N XP banked" (desktop) / "FULL · N XP" (compact canvas, where the
  longer line was clipped), the "N / N XP" rung under it and a full bar even when the bank is short of
  the next rung. The bank is what the character level-up spends (`_on_character_level`), so it is the
  number the player needs; the label clears as soon as the tree is under the cap again.
- **SKILLS hex pulse.** `SkillRules.affordable_now(sk)` asks `node_state` for any buyable
  (SkillRules.buyable) node that is `available` with the SP held, so level, prerequisite and cost all
  count and a purchase turns it off by itself. `HuntHud` recounts every 0.25 s and on `skill_changed`,
  and draws a breathing gold halo around the hex (a heptagon 4 px outside the hex outline, 25-80 %
  alpha on a 1.6 s sine) — a glow, not a jump, so the touch target and the caption never move. It is
  off while the sheet is open.
- `game/tests/t_skillfeel.gd` (7 sections) and `game/scripts/dev/skillfeel_lab.gd` + scene.

## Before / after (measured)

| | Before | After |
|---|---|---|
| A skill gain | silent (nothing listened to `skill_changed`) | "+4 Gathering XP", merged under 1 s; gold level-up line |
| Tree at the character-level cap | "28 / 28 XP" only | "FULL · 121 XP banked", full bar |
| Affordable node with SP held | nothing on the HUD | gold halo on SKILLS, off when nothing is affordable |
| Lab RESULT (both resolutions) | — | `toast_shown=1 level_toast_shown=1 full_shown=1 pulse_when_affordable=1 no_pulse_when_not=1 first_hour_trees=7 first_hour_trees_ok=1 ui_min_px=64` |

`[t_skillfeel] PASS`, no SCRIPT ERROR. `ui_min_px` is the SKILLS hex the pulse sits on (64 x 64).

## Shots looked at (all under /tmp/skillfeel_shots and /tmp/skillfeel_shots_phone)

- `skilltoast_1600x900` / `_844x390`: four lines max, clear of every block and the survivor.
- `skillsfull_1600x900` / `_844x390`: FULL with the banked XP; the phone line shortened to fit.
- `skillspulse_1600x900` / `_844x390`: halo on the hex, level-ups clear.
- `skillsnopulse_1600x900` / `_844x390`: no halo after the SP are spent — the pulse follows
  affordability, not "has SP".
Fixes made from the shots: level-ups stacked one per level (9 lines from a 200 XP grant) -> folded and
capped at 4; the FULL line was clipped on the phone -> compact wording.

## First hour: the gap (owner decision, nothing invented)

Measured at character Lv. 13, the end of the first hour by the loop plan ("hour-one targets: Lv 11-13");
`SkillRules.buyable` on the real `trees.json` + `recipes.json`, 1-5 SP each, tree level <= 13:

| Tree | Buys at 1-5 SP | What it sells |
|---|---|---|
| Survival | 2 | Island Access 15 (5 SP) and Stealth I (2 SP): the cheap rungs the functional belly-fat / capture-technique / companion chain needs |
| Cooking | 1 | Skewer (5 SP, gates the campfire skewer recipe) |
| Weapon / Tools | 1 | Makeshift Shovel / Hoe (1 SP, gates `stone_knife`) |
| Construction | 1 | Bonfire (5 SP), the cheap rung below the functional Workbench / Fence / Drying Rack nodes |
| Melee | 1 | Attack Stance (1 SP, gates the club) |
| Gathering | 0 | Boulder (1 SP) and Long Branch (5 SP) are inert: no system reads them; the first functional node, Thickets, costs 6 SP |
| Butchering | 0 | Leather I, Feather, Skull I, Slaughter I-IV (2-5 SP) are inert; the one cheap functional node, Bone II (2 SP), needs Butchering 15 |

**1 of 7 trees meets "at least 2 useful buys at 1-5 SP".** This is not a level assumption: no level
fixes it either — of *every* 1-5 SP node in a tree, regardless of level, only these are functional:

| Tree | 1-5 SP nodes | of which functional | cheapest functional node |
|---|---|---|---|
| Gathering | 2 | 0 | Thickets, 6 SP, Lv. 5 |
| Butchering | 12 | 1 | Bone II, 2 SP, Lv. 15 |
| Cooking | 1 | 1 | Skewer, 5 SP, Lv. 1 |
| Weapon / Tools | 9 | 2 | Makeshift Shovel / Hoe, 1 SP, Lv. 1 |
| Construction | 1 | 0 | Workbench, 6 SP, Lv. 5 |
| Survival | 14 | 3 | Animal Management I, 4 SP, Lv. 35 |
| Melee | 1 | 1 | Attack Stance, 1 SP, Lv. 1 |

The cause is data, not code: 92 of 213 nodes are "not in the game yet" (SKILLBUY's `SkillRules.buyable`),
and in these seven trees the cheap nodes are exactly the inert ones while the functional nodes are
priced 6-8 SP. Making `buyable` accept them would be selling effects the game does not run — the one
thing spec 12:215 forbids and SKILLBUY deliberately fixed.

A data-only fix that reaches 7/7, measured by simulation on a copy of `trees.json` (**not applied** —
`game/data/skills/trees.json` is in this job's scope, but the brief forbids cost/level changes):

| Tree | Node | now | change to |
|---|---|---|---|
| Gathering | Thickets | 6 SP, Lv. 5 | 5 SP |
| Gathering | Mining 1 | 8 SP, Lv. 10 | 5 SP |
| Butchering | Organs | 6 SP, Lv. 10 | 5 SP |
| Butchering | Bone II | 2 SP, Lv. 15 | Lv. 13 |
| Cooking | Meatball | 6 SP, Lv. 10 | 5 SP |
| Weapon / Tools | Work Pick | 6 SP, Lv. 5 | 5 SP |
| Construction | Workbench | 6 SP, Lv. 5 | 5 SP |
| Melee | Body Tackle | 6 SP, Lv. 5 | 5 SP |

Every one of those nodes is already functional, so no effect is invented. Simulated result: 2 buys in
each of the 7 trees (`gathering:2 butchering:2 cooking:2 weapon_tools:2 construction:2 survival:2 melee:2`).
The test and the lab read the data, so `first_hour_trees_ok` rises by itself once that is applied.

**Gate conflict.** This job's stage-2 gate asserts `first_hour_trees_ok == first_hour_trees` (7 of 7).
That cannot pass with the data as it stands without either that price edit or selling inert nodes, so
the gate is blocked on the same owner decision and its stage-2 run reports this line.

## Assumptions

- The first hour ends at character Lv. 13 (`FIRST_HOUR_LEVEL` in the test and the lab): the loop
  plan's "hour-one targets: Lv 11-13", and a tree cannot pass the character level.
- "Buyable" is `SkillRules.buyable` (SKILLBUY's definition: the game runs the effect); "useful" is
  therefore "its effect is enforced", not "the data has an `unlocks` line".
- Toast lifetimes (1.6 s small, 3 s level-up, 1 s merge, 4 lines) and the 0.25 s pulse recount are
  `# ASSUMPTION`: no doc gives them.
- A tree reading FULL means level == character level (`SkillState.level_cap`), including an
  occupation's Lv. 20 head start.

## What the integrator needs

- Nothing outside the scope regex changed; `game/override.cfg` untouched.
- `SkillState` has two new signals; save shape is unchanged.
- If the owner lowers costs or wires effects for the first-hour gap, `first_hour_trees_ok` in the test
  and lab rises by itself (both read the data), and the gate's `first_hour_trees_ok==first_hour_trees`
  will start to hold.
