# W2-SKILLS (claude/mmo-w2-skills): Durango 1-60 skill trees

Scope (HANDOFF §4): durango-prompts 03 + 09 + 11 + 12. Durango 1-60 levels, Lv1 AUTO nodes, Animal Handling I-IV,
the Processing tree, the 918-node table imported as data with each node marked functional / partial / defined,
recipe-gated progression, and survivors that start at Lv. 1.

## What shipped

- **Trees start at Lv. 1.** `SkillState.MIN_LEVEL = 1`. A new survivor reads Lv. 1 in every tree (it showed Lv. 0 before).
  The player badge and XP line already read Lv. 1 on the base through `LevelDisplay`.
- **Character level 1-60 caps the trees (spec 03).** `character_level()` is now the one player level
  (`LevelDisplay.player_level()`, fed by every skill XP grant). Before, it was the average of the tree levels.
  A tree cannot level past the character level. At the cap the tree keeps (banks) its XP and the bar reads full;
  `World.pioneer_changed` spends the bank (r8; before r8 the XP past a full bar was dropped). The occupation's Lv. 20 head start is exempt: the docs conflict there, so it is an open owner
  decision (Open owner decisions 5). The cap can be switched off with `category_cap` in trees.json.
- **Lv1 AUTO nodes.** `"auto": true` nodes (0 SP) are learned once their level is reached: at creation, on
  level-up, on occupation, and on load. They cannot be refunded. Examples: Rope (Basic Processing), Stone Blade,
  Leaf, Branch, Bush, Fruit I, Log I, Bug I, Pebble, Mud I, Stalk, Bone I, Roll, Leaf Outfit, Footwraps, Leaf Hat,
  Corn and Apple Tree.
- **Animal Handling I-IV (spec 09).** These reuse the save ids `animal_management_1..4`. The values follow the
  spec: Survival 35/45/55/60, SP 4/5/5/6, chain I->II->III->IV, and I requires Capture Technique I ("Animal
  Taming"; ASSUMPTION). `SkillRules.bonded_capacity()` = 3 + one per learned node, up to 7. Every client
  bond path asks `Data.bonded_cap(player)` (hook H2; the bonding survivor's own skills, the local one when no
  player is given), which reads it; `FieldTame.roster_full()` (H9) and the pen
  refuse at the cap without losing the animal or the food. (r6 removed `SkillRules.can_bond`: nothing called it.)
  A reset keeps existing pets.
- **Processing tree (spec 11).** It holds every node the spec documents: Normal Nail, Leather Strap, Charcoal,
  Dry Leather, Peeled Bark, Handicraft I-V (+4 Handicraft each), Trimmed Material, Extended Fabric, Glue, Gem
  Extraction, Cord, Waterproofed Material, Refined Ore, Metalworking I-IV (+4 Metal Processing each), Adhesive
  Accessory, Dry Rubber, Metal Links, Copper Alloy, Fiber-Tanned Material, Compressed Material, Precision
  Processing and Processed Debris. The PRD nodes stay alongside them. `SkillRules.ability(sk, "handicraft" |
  "metal_processing" | "slaughter" | "stealth")` gives the totals.
- **Spec 12 nodes in the other trees:** Stealth I-V, Mud II, Wild Seed I, Obsidian, Marble, Alum, Long Branch,
  Leather I/II, Bone II, Feather, Skull I, Teeth I/II, Horn, Slaughter I-V, Barrage + Barrage Damage I-III, Roll
  Duration I-III, the saw/handle/mortar/bow lines, Straw Shoes, Leather Sandals, Till Small Field (Lv1, 1 SP) and
  Till Large Field (Lv25, 3 SP).
- **Recipe gates.** `SkillRules.recipe_block(sk, recipe_id)` returns "" when the recipe is open. Otherwise it returns
  a message like "learn Charcoal (Processing Lv. 10, 1 SP)". Gated recipes: twine/rope (Rope, AUTO),
  improvised_stone_knife (Stone Blade, AUTO), hide_strap (Leather Strap), charcoal (Charcoal), dried_hide (Dry
  Leather), field_small (Till Small Field) and field_large (Till Large Field). This becomes real once hook H1
  lands; the craft card already shows `progression_block` text as the lock reason.
- **Refunds.** A node another learned node needs cannot be refunded. A refunded survival node clears its Data
  mirror. This fixes a bug: refunding Capture Technique used to leave net capture on. Refunds have a daily
  limit (r4, vision fix 2): 5 free a day from trees.json `refund`, then refused with the reason on the row.
- **SP come from character levels (spec 03; coordinator decision 2026-10-20).** Tree level-ups pay nothing.
  Each character level 2..60 pays `sp_budget` (10/12/14/16 by band, 720 SP at Lv. 60). The occupation's Lv. 20
  grants levels and auto nodes but no SP (ASSUMPTION). SP are always derived:
  `sp_available = max(0, paid_for_level(character level) - cost of learned nodes at today's prices)`, and
  `sp_extra = max(0, that cost - paid_for_level(character level))` is the SP of learned nodes the level has not paid
  for (a migrated rev-1 save's nodes; never spendable, new levels pay it off first; finish-run review r1).
  They are recomputed on load, on every `World.pioneer_changed`, and for saves with no skills block. A saved
  `sp_earned` or `sp_extra` is never trusted.
- **Catalog.** `trees.json.reference` holds the spec-12 counts: 13 categories that sum to 918 nodes, plus the
  Toxic Oil Islands unlock list as an optional, defined-only entry. **213 of 918 nodes are imported: 34
  functional (16 of them gate W2-DATA recipes through `requires_node`), 19 partial, 160 defined**
  (`[t_w2_skills] catalog 213 of 918 nodes: functional 34 (16 of them through requires_node), partial 19,
  defined 160`; the 16 were still marked defined until the finish-run review r1). r8 added Boulder; Surviving
  Durango I-VII are named in `reference.named_only`, see Review r8. All twelve trees cost 2305 SP; character
  levels 2-60 pay 720 (`_totals`). Every node has `status`, `source` (spec09/11/12 or prd7), `effects` and
  `sp_assumed` where the pack gives no SP.
- **Skills sheet (hook H8; skills_sheet.gd is W1-UI's file, so the change lives in the hooks patch since r5):**
  node rows show the Durango name and "AUTO" in place of "0 SP". The rows the player can act on come first,
  then one "Learned automatically: Leaf, Branch, ..." line and the "All skills" button. Below them every node
  the game reads nothing from yet is listed as a muted row with no button: "Thickets  ·  Lv. 5  ·  6 SP  ·  not in
  the game yet", then "cut thickets with a knife  ·  needs Leaf" (spec 12 10.6: lock reason, level, SP, what it
  unlocks, prerequisite; the second line since the finish-run review r1). A description that only repeats the node name is not
  shown. A Refund the player cannot use now (the day's 5 free refunds are used, or a learned node needs it) is
  greyed with "Cannot refund: ..." under the node before the tap (`SkillState.refund_reason`). While a migrated
  save owes SP, the header reads "SP 0 · 223 owed by kept skills" (`SkillState.sp_text`) and a Refund row says
  "Refund pays off 4 of the 23 owed SP, no SP back" (`SkillState.refund_note`, review r2). Locks name their
  prerequisite ("needs Drying Rack"), as the muted rows do.
- **Bonded cap on screen (hooks H9, H10):** at the cap the field-tame plate reads "Bonded roster full (3 / 3)"
  instead of "Tame", the feed is refused with the notice "... Animal Handling (Survival) adds slots." and the
  food is kept; the pets screen title reads "BONDED n / cap" (spec 09:50) and its equip button "EQUIP
  (ACTIVE n / 3)", so the two counters cannot be confused.
- **Level-up banner (hook H11, r6):** "Available Skill Points" shows `SkillState.sp_now()`, the SP the character
  level paid minus what the learned nodes cost. It used to count unbought survival.json nodes.

Files on the branch (r7): `game/data/skills/trees.json` (see Review r7, ownership), `game/scripts/skills/skill_state.gd`,
new `game/scripts/skills/skill_rules.gd`, new `game/tests/t_w2_skills.gd`, and `game/scripts/world/taming_pen.gd`
(orchestrator grant). Everything else is in the hooks patch (H1-H13): since r7 that includes W1-SAVE's
`game/tests/t_save.gd` and the new `game/tests/fixtures/save_v3_skills_rev2.json` (H12) and W1-QA's
`game/scripts/dev/skills_lab.gd` (H13).
The rev-1 goldens `save_v3_golden.json` and `save_v3_away_golden.json` are byte-identical to the base.

## Finish-run review r2 (findings in this run's prompt; base claude/mmo-overhaul @ acc684a6)

The base moved to acc684a6 (STATUS and workflow docs); the branch merged it (8da3f6c0). Branch files changed:
`skill_state.gd` and `t_w2_skills.gd`. The hooks patch is regenerated on acc684a6 with this round's changes
(H2/H6/H8/H14/H16 extended, H17 new); `git apply --cached --check` against acc684a6's tree: rc 0.

| Finding | Fix | Check that would have caught it |
|---|---|---|
| MAJOR: the migration notice is not drawn at 844x390 (+ MAJOR acceptance "notice readable on first load") | `SkillState.migration_notice(owed, available)` returns two short notices: "Skill points now follow your level" and "All skills kept; 147 SP owed" (or "All skills kept; N SP to spend"). The review's one-line text ("Skills kept. SP now come from your level: 51 owed.") is 446 px at the HUD's 17 pt and was still skipped at 844x390. Under the dial, between the vitals and the minimap, the column holds about 366 px, and a notice only slides up or down. The skills sheet's SP readout is `SkillState.sp_text()`: "SP 0 · 147 owed by kept skills" while `sp_extra > 0` (H8), so the number stays on screen after the notices fade. The 3.2 s life and the red notice style are the HUD's (W1-UI's `hud_event_state.gd`, `hunt_hud.gd`) and are unchanged. Two lines of 34 and 28 characters can be read in that time. | ui_real_capture_lab `_migration_notice` (H14): each notice is drawn whole (box width >= the text's width) over the idle HUD at every size, then checked against the HUD blocks and the survivor. With the old text: `[uireal] FAIL the migration notice is drawn whole at 844x390 (box [P: (0.0, 0.0), S: (0.0, 0.0)], needs 1249 px)`. The review's line fails the same way (`... needs 446 px`). Now: `[uireal] migration notice 0 [P: (345.0, 226.0614), S: (292.0, 30.0)] (needs 292 px)` and `notice 1 [P: (369.5, 260.0614), S: (243.0, 30.0)]` at 844x390, and both are drawn at 1600x900. t_w2_skills checks the exact lines, the header and the first load's two notices. |
| MAJOR acceptance + minor: unspent SP dropped on migration | **Not changed; put to the owner (owner_gate).** The rule came from the first run's brief, `docs/orchestration/mmo/handoff/workflows/finish-6.js:84`: "old saves lose unspent SP (keep it unless spec 03 says otherwise)". Spec 03:14 says "players can level many professions but cannot afford all nodes simultaneously", and PRD 7.3 (durango-wild-lands-systems-prd.md:503) says "If a rebuild gives enough SP to max everything, the market, clans, and \"occupation\" fantasy collapse". The finish-run review r1 marked keeping them MAJOR (a Lv. 23 save could buy all 66 nodes); review r2 marks dropping them MAJOR (brief wording, real saves lose 848 and 2036 SP). Two reviews disagree, and real saves are hit, so the owner decides. The STATUS hunk (H16) no longer records it under "Owner decisions" (an agent wrote that entry). It is now an "Owner questions (open)" item with the release note for the merge: "Skill points now come from your character level. Every skill you learned is kept; points left unspent under the old per-skill award are gone, and skills that cost more than your level pays are paid off by your next levels." To keep the SP instead, change the `sp_extra` line in `SkillState._recount_sp` and the write-back in H6. | Evidence: `[t_w2_skills] migrated Lv. 23: earned 226, available 205; at Lv. 60 earned 720 of 922 SP of buyable nodes`. |
| Minor: hooks patch STATUS hunk fails on acc684a6 | Merged acc684a6, then regenerated the patch from scratch tree `trees/w2s-r11` (`git diff HEAD` of the hooked files). The base's STATUS entries are untouched; ours is the new owner question. | `git apply --cached --check` on acc684a6's tree and on the branch: rc 0. |
| Minor: Refund on an owing save gives 0 SP with no warning | `SkillState.refund_note(tree, id)`: while `sp_extra > 0` the Refund row (H8) shows a `RefundNote` line under the node: "Refund pays off 4 of the 23 owed SP, no SP back", or "Refund pays off the N owed SP, then gives M SP" when the node costs more than the debt. | t_w2_skills `while 23 SP are owed the sheet says so (header ...) and what a refund pays (note ...)` and `owing 23 SP: the header says so (...) and the Refund row says what it pays (...)`. With `refund_note` returning "" and `sp_text` returning "SP %d": `FAIL while 23 SP are owed the sheet says so (header 'SP 0') and what a refund pays (note '')`, `FAIL owing 23 SP: the header says so ('Survival  Lv. 40, SP 0') and the Refund row says what it pays ('')`. |
| Minor: the H6 cap of a rev-2 `sp_extra` at the old award is untested (mutant M8 passes) | The finding is right that nothing kills M8, but no forged save can: the cap never binds on the shipped trees.json. For every tree and level L, the nodes up to L cost at most 53 % of the old award for L (worst: Survival Lv. 55, 342 of 650 SP). A forged rev-2 save is stopped by its tree levels before it reaches the cap, so M8 is an equivalent mutant today. The cap stays, because it matters once an import puts more SP into a tree than its old award. | t_w2_skills now pins the reason: `H6: no tree's nodes cost more than the old award of their level, so the sp_extra cap needs a forged case now: [...]`. It fails on the day the data makes the cap matter, which is when a forged case becomes possible. |
| Minor: the pets screen title ignores its player's cap | H17: `Data.bonded_cap(player)` in `animal_screen.gd`. | t_w2_skills `the pets screen opened for the second survivor shows its own cap`. With the old call: `FAIL the pets screen opened for the second survivor shows its own cap (title 'ANIMALS    ·    BONDED 3 / 3    ·    GROWTH')`. |
| Minor: locks show raw ids ("needs taming_pen") | `SkillState.node_name(tree, id)`; `node_state` says "needs <name>", and `refund_reason` uses the same helper. | t_w2_skills `a lock names its prerequisite`: 51 locks checked. With the old line: `FAIL a lock names its prerequisite (51 checked, by id: ["needs island_access_15", "needs belly_fat_1", "needs stealth_1", ...`. |
| Minor: H6 counts spent SP at today's prices | `# shortcut:` in H6: a price rise drops a rev-2 save's last learned nodes there (SkillState would keep them). Store each node's paid price, or bump the rev and migrate, before raising a price. | (comment) |

Gates (scratch tree `trees/w2s-r11`: mkscratch at 8da3f6c0, this patch applied, the branch files of bc21b7e5;
game/ equals bc21b7e5 + the patch):
- `--import` rc 0, 0 SCRIPT ERROR, 0 "Failed to compile".
- All 23 `t_*.gd` rc 0 with PASS. t_server_domain and t_srvdom ran one after the other. Only t_save prints
  SCRIPT ERROR lines, its 5 deliberate ones. Lines: `[t_save] rev-1 skills migrate: 19 nodes kept, SP 0/263`,
  `[t_save] PASS`; `[t_data] PASS items=223 recipes=155`; `[t_w2_skills] catalog 213 of 918 nodes: functional 34 (16 of them
  through requires_node), partial 19, defined 160`, `[t_w2_skills] PASS`; `[t_ui] PASS`. t_w2_skills was run again
  after the pets-title check was added (abcbb6a3): `[t_w2_skills] PASS`.
- run_all `[tests] PASS`; `tools/smoke.sh --no-import` `SMOKE PASS`.
- Labs, 0 SCRIPT ERROR and 0 "couldn't resolve track" each: skills_lab `[skill] PASS level-up pays 10 SP,
  small_field bought`; capture_lab `[capture] PASS bonded+=2`; ui_family_lab `[uifamily] inventory=true
  animals=true unlimited=true active_cap=3`; ui_real_capture_lab on gl_compatibility, windowed: 1600x900 and
  844x390 `[uireal] PASS screens=hud,hud_daynight,craft,skills,...`. At 667x375 the lab draws both migration
  notices whole (`notice 0 [P: (325.0, 257.2302), S: (292.0, 30.0)]`) but fails one check outside this package:
  `[uireal] FAIL radial: hex0 [P: (361.3007, 371.4283), S: (64.0, 64.0)] stays off level [P: (369.5, 433.0), S: (65.0,
  15.0)]` (the HUD's level line is drawn at y 433 on a 375 px canvas). This is for W1-UI or the integrator; 844x390
  is the phone gate.
- No new `~/Library/Logs/DiagnosticReports/Godot-*.ips` (25 before and after; newest 2026-10-20 23:26).

First load of a real rev-1 save, looked at (scratchpad `w2s_r11/load/`). The save is t_save's 19-node variant of
`save_v3_golden.json`: Lv. 5, 539 unspent SP, 263 SP of nodes at today's prices. It was shot through the normal
boot path, using two scratch-only edits that were never committed: `--shot` kept the default save slot, and
`--w2s-sheet` opened the Survival tree after 2 s. Log: `[ui] notice Skill points now follow your level`,
`[ui] notice All skills kept; 223 SP owed`, `[skill] restored 12 trees (rev 1, SP 0/263)`.
- `phone_d1.5.png` and `phone_d2.5.png` (844x390, gl_compatibility): both notices are drawn whole under the
  survivor's name, clear of the camp labels, HANDS and the rail. Before: the reviewer's `after_notice_phone_d1.png`
  had no notice.
- `desk_d1.5.png` (1600x900, gl_compatibility): both notices sit under the top centre.
- `phone_sheet.png` (844x390): the Survival tree header reads "Survival Lv. 55" and "SP 0 · 223 owed by kept
  skills" next to Close.
- Lab shots `w2s_r11/phone/migration_notice_844x390.png` and `w2s_r11/desk/migration_notice_1600x900.png` show the
  same two notices over the idle HUD.

## Finish-run review r1 (`docs/orchestration/mmo/handoff/findings/w2-skills-review-r1.json` findings in this run's prompt; base claude/mmo-overhaul @ 946da955)

W2-SKILLS is merged (dfcf833e, hooks 6f65f615). The base moved to 946da955 (HUD-DAYNIGHT); the branch merged it
(d8b72429). Branch files changed: `trees.json`, `skill_state.gd`, `t_w2_skills.gd`, `taming_pen.gd` (grant).
Everything else is in the regenerated hooks patch, which now holds only this round's changes: `git apply --cached
--check` against 946da955's tree rc 0.

| Finding | Fix | Check that would have caught it |
|---|---|---|
| MAJOR: migrated rev-1 saves keep their old unspent SP (Lv. 23 save: 848 available, could buy all 66 nodes) | Option (b), held as an invariant. `SkillState._recount_sp` derives `sp_extra = max(0, cost of learned nodes - paid_for_level(character level))`, so `sp_available = max(0, paid - cost)`. Every node is kept, the old unspent SP go, and new levels pay the kept nodes off before they add SP. The rev-1 branch of `from_dict` is gone (nothing to compute) and the first load of a rev-1 save with SP or nodes shows one notice through the survivor's `notice`. H6 writes the same `sp_extra` back (`max(0, kept cost - character SP)`). The fixture and t_save expect 40 SP for the goldens (Lv. 5, nothing bought) and 0 SP + extra 223 for the 19-node variant. STATUS records the rule (H16). | t_w2_skills `_test_migration`: a rev-1 Lv. 23 save with 848 unspent SP loads with `earned 226, available 205` and at Lv. 60 has `earned 720 of 922 SP of buyable nodes`; the notice shows once and not on a rev-2 load. `_test_sp_from_character_level`: the over-budget save keeps 4 nodes with 0 SP; Lv. 2 leaves 13 owed, Lv. 4 leaves 7. t_save `_test_rev1_skills` and the fixture comparison. |
| MAJOR: t_w2_skills switched sections off when it thought hooks were missing | `_hooks_applied()`, the `bonded_cap() > 1000` guard and the H6 argument-count skip are deleted; all 15 sections always run. | Mutation M5 (below) now fails 9 lines. |
| Minor: 16 requires_node nodes marked defined; `_about`/`_totals` stale | The 16 nodes are `functional`; `_about` says so; `_totals` reads 2305 SP for all trees, 720 from character levels 2-60 (skills.md:5's ~897 adds milestones and Career Guides, neither in the game), 1035 for the four big trees. The catalog line in "What shipped" is corrected. | t_w2_skills `_test_catalog`: a node a loaded recipe names in `requires_node` must be `functional`, and `_totals` must state the summed cost. The report's counts now come from the data: `functional 34 (16 of them through requires_node), partial 19, defined 160`. |
| Minor: muted rows lost the effect line | H8: a muted row's second line, indented and in the META colour, is the node's `unlocks` text and "needs <prerequisite name>": "Thickets · Lv. 5 · 6 SP · not in the game yet / cut thickets with a knife · needs Leaf". The W2-GATHER follow-up (Thickets and Mining 1-4 functional) stays listed under "Wanted from other packages". | t_w2_skills `_test_sheet_rows`: every muted row carries its `unlocks` (when it differs from the name) and its prerequisite's name. |
| Minor: server `act.tame` has no bonded cap | Kept for W3-SRVACT, spelled out under "Left": check `SkillRules.bonded_capacity` against the CharacterState skills before `ch.d.pets[uid] = ...`, refuse with `roster_full`, food kept. | (W3-SRVACT) |
| Minor: `Data.bonded_cap()` reads the local survivor for any player | H2: `Data.bonded_cap(player: Player = null)`; `FieldTame.roster_full` (H9), `PlayerPets.bond_from_inventory` (H15) and the taming pen pass their player. UI that only knows the local survivor still calls it with no argument. | t_w2_skills `_test_field_tame_cap`: a second survivor with Animal Handling I has room at 3 bonded while the local one is full. |
| Minor: stale NOT_IN_GAME comment | "shown as muted rows with no button (skills_sheet H8)". | (comment) |
| Minor: capture lab levelup shot shows 0 SP at Lv. 5 | H14: `_level_up_banner(stored)` sets `World.pioneer_level` for the `_on_level_up` call, puts it back (read through `LevelDisplay`, as t_ui requires) and recounts SP; it also asserts "Available Skill Points: N" equals what that level holds. | The lab's own check, and the shots: `levelup_1600x900.png` "Available Skill Points: 40", `levelup_844x390.png` "Skill points 40". |

**Why `sp_extra` is derived, not a fixed number with the H6 cap.** The prompt asked for both: set `sp_extra` once on
migration, and cap it in H6 at "cost of kept nodes beyond the SP the character level paid". Together they lose SP:
a save migrated at Lv. 23 with 277 SP of nodes gets extra 51 (277 - 226); at Lv. 24 (+14) it has 14 to spend; on the
next load H6 cuts the extra to 277 - 240 = 37 and the 14 SP vanish, on every level until the nodes are paid off.
Deriving `sp_extra` from the current level and nodes on every recount keeps the runtime and H6 on the same rule,
so a reload never changes SP: t_w2_skills `H6: a migrated save at Lv. 4 keeps its 4 nodes and 7 SP through sanitize
and load` holds. The effect is the docs' rule taken strictly: a migrated save never has more SP than a new character
at its level beyond the nodes it already holds (spec 03:14), at Lv. 60 too, where a fixed extra would let the
reviewer's Lv. 5 variant reach 720 + 223 = 943 SP, more than the 922 every buyable node costs. Trade-offs, both in
the report's Assumptions: while the kept nodes cost more than the level paid, a level-up and a refund of a kept node
give no spendable SP (they pay the debt first); and Career Guides' one-time SP (spec 03:14, not built) will need
their own saved field, since `sp_extra` is now derived (`# shortcut:` in `skill_state.gd`). Older rev-2 saves made
with the inflated extra are corrected the same way on load: their stored `sp_extra` only widens H6's node budget.

Mutation proofs (scratch `trees/w2s-r10mut`, branch adb7c93f + this patch):
- Old code (skill_state, save_sanitizer, skills_sheet, field_tame, data, player_pets, taming_pen and trees.json at
  claude/mmo-overhaul; new tests): t_w2_skills rc=1 with, among 29 FAIL lines,
  `FAIL processing/nails_pillars gates recipes through requires_node, so it must be functional (it is 'defined')`,
  `FAIL _totals says what the trees cost (2305, it says { "all_trees_sp": 2246.0, ...`,
  `FAIL a migrated Lv. 23 drops its 848 unspent SP: earned 869, available 848 (a new Lv. 23 earns 226, these nodes cost 21)`,
  `FAIL at Lv. 60 it has earned 1363 SP like any Lv. 60 and cannot buy all 922 SP of nodes`,
  `FAIL the first load says once that SP were recomputed: []`,
  `FAIL an over-budget migrated save keeps its 4 nodes, drops its 50 unspent SP (spent 23, available 50, extra 73)`,
  `FAIL a second survivor with Animal Handling I has room at 3 bonded while the local one is full ('Bonded roster full (3 / 3)' / 'Bonded roster full (3 / 3)')`,
  `FAIL gathering at Lv. 1: each of the 12 nodes not in the game yet is a row with its level, SP, reason, unlocks and prerequisite and no button (... bad ["Thickets  ·  Lv. 5  ·  6 SP  ·  not in the game yet", ...`
  (the old sanitizer writes no `sp_extra` for rev 1, so the H6 section stops with a SCRIPT ERROR and
  `FAIL only 14 of 15 test sections completed`). t_save rc=1:
  `FAIL save_v3_golden.json skills_v2 migrates to its rev-2 expectation: ["/skills_v2/sp_available: 40.0 vs 270.0", ...`,
  `FAIL first load: the 539 unspent SP are not kept: the nodes cost more than Lv. 5 pays (got 539)`.
- M5 (`Data.bonded_cap()` returns 2147483647) plus the old H6 cap (`sp_extra` clamped to the old award): t_w2_skills
  rc=1, no "skipped" line, 12 FAIL lines including
  `FAIL H6: at character Lv. 1 a rev-2 sp_extra of 99999 is cut to the 23 SP of nodes beyond the level's SP (23, got 440)`,
  `FAIL 3 / 3 bonded: the pen keeps the animal and says why (bonded 4, occupant <null>)`,
  `FAIL 3 / 3 bonded: the plate says the roster is full, not Tame (got tame 'Tame')`,
  `FAIL 3 / 3 bonded: the feed is refused and the berry is kept (fed true, 1 left)`,
  `FAIL the pets screen shows bonded / cap (title 'ANIMALS    ·    BONDED 3 / 2147483647    ·    GROWTH')`.

Gates (package tree = branch + this patch; claude/mmo-overhaul moved to 809be2e8 during the run, docs only, merged
in 4f7b1b0c; the patch regenerated on it, `git apply --cached --check` rc 0):
- `--import` rc 0, 0 SCRIPT ERROR, 0 "Failed to compile".
- All 23 `t_*.gd` rc 0 with PASS. Only t_save prints SCRIPT ERROR lines, its 5 deliberate ones:
  `[t_save] rev-1 skills migrate: 19 nodes kept, SP 0/263`, `[t_save] PASS`; `[t_data] PASS items=223 recipes=155`;
  `[t_w2_skills] catalog 213 of 918 nodes: functional 34 (16 of them through requires_node), partial 19, defined 160`,
  `[t_w2_skills] migrated Lv. 23: earned 226, available 205; at Lv. 60 earned 720 of 922 SP of buyable nodes`,
  `[t_w2_skills] PASS`; `[t_ui] PASS` (first run failed `player level read outside LevelDisplay at
  res://scripts/dev/ui_real_capture_lab.gd:455`; the lab now reads the level through `LevelDisplay`, rerun PASS).
  t_server_domain and t_srvdom were run one after the other (they share `user://t_srvdom_store`): both PASS.
- run_all `[tests] PASS`; `tools/smoke.sh --no-import` `SMOKE PASS` (both rerun after the last sheet and lab edit).
- Labs, 0 SCRIPT ERROR and 0 "couldn't resolve track" each: skills_lab `[skill] PASS level-up pays 10 SP, small_field
  bought`; capture_lab `[capture] PASS bonded+=2`; ui_family_lab `[uifamily] inventory=true animals=true
  unlimited=true active_cap=3`; ui_real_capture_lab on gl_compatibility at 1600x900 and 844x390 `[uireal] PASS
  screens=hud,hud_daynight,craft,skills,...,levelup,...,busy_levelup,...` (it now also asserts the banner's SP).
- No new `~/Library/Logs/DiagnosticReports/Godot-*.ips` (25 before and after; newest 2026-10-20 23:26).

Screenshots, looked at (scratchpad `w2s_r10/`):
- `shots2/tree_desk_glc.png` (1600x900 gl_compatibility, `--lab=home_lab --shot=.../tree_desk_glc.png`, whose name opens
  the Gathering tree): each muted row has its head line and, indented under it, "cut thickets with a knife · needs
  Leaf", "stone and clay with a pick · needs Thickets", ... "black iron, gems · needs Rare Plants". Boulder and Long
  Branch, whose `unlocks` repeat the name and which have no prerequisite, stay one line. Before:
  `r9shots/desk_glc_gathering.png` (head lines only). A first shot with the detail line unindented read as a row of
  its own (31 px under its head, 34 px to the next row); the indent and `line_spacing` 0 group it.
- `shots2/tree_phone_glc.png` (844x390): header, auto line, All skills and the first four rows with their detail
  lines, scroll bar inside the panel.
- `shots/uireal_desk/levelup_1600x900.png`: "Lv. 5", "Available Skill Points: 40"; `shots/uireal_phone/levelup_844x390.png`:
  "Lv. 5 LEVEL UP ... Skill points 40" (before: 0).

## r9: review r6's findings re-sent after the merge (claude/mmo-overhaul @ ddaab662)

The 14 findings in this run's prompt are review r6's (on 52c15c19). Every one was fixed in r7 (5e77eb8c, report
8c2ec045; see Review r7 below), the package passed review r8 and blind A/B, and the integrator merged it:
`dfcf833e Merge W2-SKILLS: ... (review r8 pass, blind A/B pass)`, hooks applied in `6f65f615 Apply W2-SKILLS
integrator hooks`. Nothing in the findings needed new code, so r9 is a check of the merged state.

- Base: claude/mmo-overhaul moved to ddaab662 (WATER, specs 18-24, STATUS). The branch is fast-forwarded to it;
  no package code changed since sync 1.
- Hooks patch: all 15 hooked files are in the base. `git apply --cached --check -R` of the patch against
  ddaab662's tree: rc 0 (the forward check fails, as it should once applied). Nothing is left for the
  integrator. The file is not regenerated: against this base it would be empty. It stays as the record of what
  6f65f615 applied.

| r6 finding | Where it was fixed | On ddaab662 |
|---|---|---|
| MAJOR: not-in-game nodes folded into one count line | r7, H8 | `skills_sheet.gd:289` `row.name = "SkillsLater_" + nid`; t_w2_skills "skills sheet rows" passes (below); shots below |
| MAJOR acceptance: vision fix 1 shown locked | r7, H8 | same rows; `r9shots/desk_glc_gathering.png`, `phone_glc_gathering.png` |
| MAJOR acceptance + minor: report stale for r6 (H11, `can_bond`) | r7 report | Review r6 section and H11 in the hook list; `grep -rn can_bond game/` finds nothing |
| Minor: t_save.gd, fixture, trees.json edited on the branch | r7 (t_save + fixture moved to H12) | the integrator applied H12 and merged trees.json with the package |
| Minor: Refund active after the day's free refunds | r7, `refund_reason` + H8 | `skills_sheet.gd:314-323` greys the button and shows "Cannot refund: ..." |
| Minor: H6 should clamp rev-2 tree levels | declined with evidence (Review r7) | unchanged; the t_save FAIL lines the clamp causes are quoted there |
| Minor: occupation Lv. 20 exemption listed as an assumption | r7, Open owner decisions 5 | still open; r9 adds spec 19:11 to it |
| Minor: H1 vs W2-DATA's `progression_block` hunk | Sync 1 | `crafting.gd:253-257`: one check, `SkillRules.recipe_block`; `_node_block` gone |
| Minor: skills_lab asserted nothing | r7, H13 | lab line below |
| Minor: recipe gates rebuilt per call | r7, `SkillState._rules_cache` | `skill_rules.gd:17-18` returns the cache while the recipe count holds |
| Minor: two "/ 3" counters on the pets screen | r7, H10 | `animal_screen.gd:234` "EQUIP   (ACTIVE n / 3)" |
| Minor: server trees have no character-level cap | r7, recorded | Left: W3-SRVACT |
| Minor: island and capture pacing | r7, Open owner decisions 6 + probe | pacing lines below |

Gates on the merged state (scratch `trees/w2s-r9`, mkscratch at ddaab662, no patch since the hooks are in):
- `--import`: 0 SCRIPT ERROR, 0 "Failed to compile".
- All 22 `t_*.gd` PASS, t_water included. Only t_save prints SCRIPT ERROR lines, its 5 deliberate ones.
  `[t_save] rev-1 skills migrate: 19 nodes kept, SP 539/802`, `[t_save] PASS`;
  `[t_data] PASS items=223 recipes=155`;
  `[t_w2_skills] catalog 213 of 918 nodes: functional 34 (16 of them through requires_node), partial 19, defined 160`,
  `[t_w2_skills] recipes gated by requires_node: 56`,
  `[t_w2_skills] pacing: Survival 15 took 570 gathers before the cap, now 1838 (character Lv. 15 needs 3675 XP)`,
  `[t_w2_skills] PASS` (0 FAIL lines).
  t_srvdom and t_server_domain failed in the first, parallel batch: t_srvdom is t_server_domain under another tag,
  and both use `user://t_srvdom_store`. Each passes when run alone, one after the other: `[t_server_domain] PASS`,
  `[t_srvdom] PASS`. run_all (one process) `[tests] PASS`; `tools/smoke.sh --no-import` `SMOKE PASS`.
- Labs, 0 SCRIPT ERROR and 0 "couldn't resolve track" each: skills_lab `[skill] PASS level-up pays 10 SP,
  small_field bought`; capture_lab `[capture] PASS bonded+=2`; ui_family_lab `[uifamily] inventory=true
  animals=true unlimited=true active_cap=3`; ui_real_capture_lab on gl_compatibility at 1600x900 and 844x390
  `[uireal] PASS screens=hud,craft,skills,...`.
- No new `~/Library/Logs/DiagnosticReports/Godot-*.ips` (25 before and after).

r9 screenshots, looked at (scratchpad `r9shots/`). A scratch-only skills_lab line, never committed, opens the
Gathering tree through the HUD's own `_toggle_skills`:
- `desk_glc_gathering.png` (1600x900 gl_compatibility) and `desk_fwd_gathering.png`: "Gathering Lv. 1", "SP 0",
  the "Learned automatically: Leaf, Branch, ..." line, "All skills", then all 12 muted rows with no button, from
  "Boulder · Lv. 5 · 1 SP · not in the game yet" to "Great Success 2 · Lv. 55 · 34 SP · not in the game yet".
- `phone_glc_gathering.png` (844x390): the same header and the first six rows, with a scroll bar and Close inside
  the view.
- `desk_glc_tree.png` and `phone_glc_tree.png` show the character-creation screen: the main game without
  `--lab` starts a fresh user dir there. They are not evidence for the tree.

## Sync 1 before integration (claude/mmo-overhaul @ 18ef7091, W2-DATA merged; branch merge 89cce919, hooks dbe1e006; the 1ffbc59c merge after it, de3a7854, is docs only and the patch applies clean on it)

- Merge of claude/mmo-overhaul: no conflicts. The hooks patch failed `git apply --check` on the new base only in
  `crafting.gd` (W2-DATA's hooks landed its own `requires_node` check). It was regenerated on 18ef7091 with the
  resolution tried in Review r7: H1's `SkillRules.recipe_block` block kept, W2-DATA's three `requires_node`
  lines and `_node_block()` dropped (no other caller). `git apply --check` on claude/mmo-overhaul: clean. No game code changed on the branch.
- Gates in scratch `trees/sync-w2-skills` (mkscratch at dbe1e006 with the hooks): `--import` 0 SCRIPT ERROR;
  all 21 `t_*.gd` PASS, only t_save prints SCRIPT ERROR (its 5 deliberate ones);
  `[t_data] smelt_copper gate: before 'learn Smelting 1 (Processing Lv. 25, 15 SP)...`, `[t_data] PASS items=223 recipes=155`;
  `[t_w2_skills] catalog 213 of 918 nodes: functional 34 (16 of them through requires_node)...`,
  `[t_w2_skills] recipes gated by requires_node: 56`, `[t_w2_skills] PASS`; `[t_save] rev-1 skills migrate: 19 nodes kept, SP 539/802`;
  run_all `[tests] PASS`; `tools/smoke.sh --no-import` `SMOKE PASS`.
- Labs, 0 SCRIPT ERROR and 0 "couldn't resolve track" each: skills_lab `[skill] PASS level-up pays 10 SP, small_field bought`;
  capture_lab `[capture] PASS bonded+=2`; ui_family_lab `[uifamily] inventory=true animals=true unlimited=true active_cap=3`;
  ui_real_capture_lab on gl_compatibility at 844x390 and 1600x900 `[uireal] PASS screens=hud,craft,skills,...`.
  Looked at craft and skills at 1600x900 and craft at 844x390: render as before, Charcoal reads "Locked".
- No new `~/Library/Logs/DiagnosticReports/Godot-*.ips` (34 before and after).

## Review r8 (findings on r7 @ 8c2ec045; fixed at 99b135aa, hooks 77d54a50, base merged at 2091bc9a)

Base: claude/mmo-overhaul moved to 73527576 (specs 15-17, STATUS and three reference images; no game/ file). It
is merged (2091bc9a; `git diff 77d54a50 2091bc9a -- game` is empty). The hooks patch is unchanged by the merge:
`git apply --check` is clean on the branch and on claude/mmo-overhaul @ 73527576.

- **MAJOR, XP over the cap was dropped, so t_build failed after W2-DATA: fixed (banked).** Spec 03:7: a category
  "cannot exceed character level, even when the player has lots of category XP"; 03:34 "Handle XP at
  gated/capped levels consistently". `SkillState._resolve` now keeps the XP of a tree at the character-level
  cap; the next `World.pioneer_changed` spends it. The only XP cut is what the tree could never use:
  `SkillState.xp_to_max(level)`, the XP from its level to Lv. 60. H6 bounds a saved `xp` by the same
  `xp_to_max(level)` (it was `xp_to_next(level)`, which would have thrown the bank away on load). H8 shows a
  banked tree as a full bar ("28 / 28 XP"), as Durango's own skill screen does (`docs/reference/durango-skill-screen.webp`:
  Survival Lv. 22 with a full bar). Checks, each failing on the r7 code:
  - t_w2_skills, old `_resolve`: `[t_w2_skills] FAIL XP at the cap is banked, not dropped (xp 28 of 200)`,
    `[t_w2_skills] FAIL a character level-up spends the banked XP (melee 2, survival 2, 0 XP left)`,
    `[t_w2_skills] FAIL the bank holds what melee can still use up to Lv. 60, no more (60, want 15180)`.
  - t_w2_skills, r7 hooks: `[t_w2_skills] FAIL H6: banked XP loads (500, got 60.0) and is bounded by what Lv. 5 can still use (15180, got 60.0)`,
    `[t_w2_skills] FAIL melee at the cap with 200 XP banked reads a full bar ('200 / 28 XP')`.
  - The integration itself: see the W2-DATA trial below (`build +8`, `[t_build] PASS`).
- **MAJOR acceptance, integrates in the documented merge order with every gate passing: met.** Trial tree
  `trees/w2s-r8-trial`: claude/mmo-w2-data @ 075e0bbd (its head; the reviewer used 753a3c64) with its hooks
  committed, `git merge claude/mmo-w2-skills` @ 77d54a50 (no conflict), this hooks patch with `--3way`
  (only `crafting.gd` conflicts; resolved as in Review r7: H1's block kept, W2-DATA's three `requires_node`
  lines and `_node_block()` dropped), then `--import`: rc 0, 0 SCRIPT ERROR, 0 "Failed to compile".
  - All 21 `t_*.gd` PASS, t_data included; only t_save prints SCRIPT ERROR lines, its 5 deliberate ones.
  - `[build] place/pack/place xp: build +8 (pioneer +8), repack +0 (pioneer +0), kit flags=[&"repacked"]`, `[t_build] PASS`
    (the reviewer's trial: `build +0 (pioneer +8)`, `[t_build] FAIL a fresh build still pays construction and pioneer XP`).
  - `[t_data] smelt_copper gate: before 'learn Smelting 1 (Processing Lv. 25, 15 SP); you have 0 SP, reach Lv. 2 for +10 SP', after learning smelting_1 ''`,
    `[t_data] PASS items=223 recipes=155`.
  - `[t_w2_skills] catalog 213 of 918 nodes: functional 34 (16 of them through requires_node), partial 19, defined 160`,
    `[t_w2_skills] recipes gated by requires_node: 56`, `[t_w2_skills] PASS`.
  - run_all `[tests] PASS`; `tools/smoke.sh --no-import` `SMOKE PASS`.
- **Minor, rev-1 saves keep a large permanent `sp_extra`: put to the owner** as Open owner decision 7, with the
  reviewer's numbers and three options. Nothing changed: the migration is the owner-approved one.
- **Minor, PRD names in sentence case: fixed.** The 54 `prd7` names in trees.json are Title Case ("Split Wood",
  "Nails Pillars", "Thread Cloth", "Rare Plants", "Great Success 1", "Island Access 15"). New check (every node
  name is Title Case), with one name reverted: `[t_w2_skills] FAIL every node name is in Title Case (not: ["Split wood"])`.
  The `requires_node` lock now reads "learn Work Pick (Weapon / Tools Lv. 5, 6 SP)"; t_w2_skills expects that text.
- **Minor, `SkillState.refused` only read by the test: removed** with `_refuse()`. The test checks
  `refund_reason()`, which is what the sheet shows.
- **Minor, Boulder missing: added.** `gathering/boulder`, Lv. 5 / 1 SP, defined, `level_assumed` and `sp_assumed`
  (spec 12:35 says only "Boulder appears early"; Lv. 5 / 1 SP is what spec 12 gives Barrage, its one Lv. 5 node).
  Checking spec 12's other "Documented examples" lines against trees.json found one more set: "Surviving Durango
  I-VII are category milestones" (12:162), with no level, SP or effect. They are recorded by name in
  `reference.named_only` and not placed in the tree, since a level would be invented. Spec 12:115 "Instrument
  making also appears as a skill line" names no node. docs/reference (now 24 images) holds no node table; the
  skill screen shows category levels only. Check: `catalog has boulder`; without the node:
  `[t_w2_skills] FAIL catalog has boulder`.
- **Minor, a new survivor's Gathering tree has nothing to buy: passed on** to W2-GATHER and the integrator
  ("Wanted from other packages": Thickets and Mining first). Boulder adds a 12th muted row until then.
- **Minor, H6 accepts any reachable node and an `sp_extra` up to the old award: kept for W3-SRVACT.** The optional
  part (drop non-buyable nodes in rev-2 saves the save did not own before migration) is not built: from its
  second load a migrated save is rev 2, so the sanitizer cannot tell "owned before migration" without a new save
  field; the server record W3-SRVACT adds closes both gaps.

## Acceptance r8 (branch @ 77d54a50 + hooks, claude/mmo-overhaul @ cecc936b; the 73527576 merge after it is docs only)

Gate tree `trees/w2s-r8`: mkscratch.sh at 99b135aa with the r7 patch, H6/H8 edited there and the patch
regenerated from it (`git diff --cached HEAD` equals the committed patch). Its game/ equals 77d54a50 + hooks.
- `--import`: 0 SCRIPT ERROR.
- All 20 `t_*.gd` PASS; only t_save prints SCRIPT ERROR lines, its 5 deliberate ones.
- `[t_save] rev-1 skills migrate: 19 nodes kept, SP 539/802`, `[t_save] PASS`.
- `[t_w2_skills] catalog 213 of 918 nodes: functional 18 (0 of them through requires_node), partial 19, defined 176`,
  `[t_w2_skills] PASS`.
- run_all `[tests] PASS`; `tools/smoke.sh --no-import` `SMOKE PASS`.
- Labs, headless, 0 SCRIPT ERROR and 0 "couldn't resolve track" each: skills_lab `[skill] PASS level-up pays 10 SP, small_field bought`;
  capture_lab `[capture] PASS bonded+=2`; ui_family_lab `[uifamily] inventory=true animals=true unlimited=true active_cap=3`.
  ui_real_capture_lab on gl_compatibility at 844x390 and 1600x900: `[uireal] PASS screens=hud,craft,skills,...`, 0 SCRIPT ERROR.
- No "couldn't resolve track" in any gate or trial log. No new `~/Library/Logs/DiagnosticReports/Godot-*.ips` (34 before and after).

r8 screenshots, looked at (scratchpad `r8shots/`; a scratch-only skills_lab edit opens the sheet, never committed):
- `desk_glc_gathering.png` (1600x900 gl_compatibility), `phone_glc_gathering.png` (844x390): "Boulder · Lv. 5 · 1 SP · not in
  the game yet" first among the muted rows, then "Great Success 1", "Rare Plants", "Great Success 2".
- `desk_glc_processing.png`, `phone_glc_processing.png` (Processing Lv. 30, scrolled): "Nails Pillars", "Thread Cloth".
- `desk_glc_overview.png`, `desk_fwd_overview.png`, `phone_glc_overview.png` (character Lv. 1, melee given 200 XP): Melee and
  Survival read "28 / 28 XP" with a full bar; every other tree "0 / 28 XP". The phone layout keeps both columns readable.

## Review r7 (findings on r6 @ 52c15c19; fixed at 5e77eb8c, report and one data name after it)

Base: claude/mmo-overhaul moved to cecc936b (HANDOFF and two workflow files only) and is merged (03364e1a).
The hooks patch was regenerated from a tree with it applied: `git apply --check` is clean on the branch and on
claude/mmo-overhaul @ cecc936b (the hooked files, t_save.gd and the fixture are identical on both).

- **MAJOR, nodes not in the game yet were folded into one count line: fixed (H8).** Every such node is listed
  again, after the rows the player can act on, as a muted row with no button: "Thickets  ·  Lv. 5  ·  6 SP  ·  not
  in the game yet" (spec 12 10.6 "Display lock reason, category level, prerequisites, SP cost"; prerequisites are
  not repeated on these rows because nothing in the chain can be bought yet). "All skills" now sits above that
  list, so a phone does not scroll past 34 rows to leave Processing.
  Check, t_w2_skills "skills sheet rows": every `NOT_IN_GAME` node has a `SkillsLater_<id>` row with its level,
  SP and reason, and no button. With the r6 sheet:
  `[t_w2_skills] FAIL gathering at Lv. 1: each of the 11 nodes not in the game yet is a row with its level, SP and reason and no button (rows 0, buttons 0, bad [])`,
  `[t_w2_skills] FAIL processing at Lv. 1: each of the 34 nodes not in the game yet is a row with its level, SP and reason and no button (rows 0, buttons 0, bad [])`.
- **MAJOR acceptance, vision fix 1 (not buyable, and shown locked "not in the game yet"): met.** Not buyable: the
  r3 mutation proof still holds (`[t_w2_skills] FAIL a partial node cannot be bought: Handicraft I says 'not in the
  game yet'` with the lock line disabled). Shown: `desk_glc_tree.png` (1600x900 gl_compatibility) lists all 11
  Gathering nodes from "Thickets · Lv. 5 · 6 SP · not in the game yet" to "Great success 2 · Lv. 55 · 34 SP · not
  in the game yet"; `desk_glc_refundscroll.png` ends Processing's 34 rows with "Processed Debris · Lv. 60 · 6 SP ·
  not in the game yet". The prerequisite chains of functional nodes stay buyable (Island Access 15, Belly Fat I:
  "defined prerequisites of Capture Technique I stay buyable" passes).
- **MAJOR acceptance, the report is accurate: met.** Review r6 below lists H11 (`hunt_hud.gd`, `sp_now()`) and
  the `can_bond` removal; "What shipped" no longer names `SkillRules.can_bond`; the hook list runs H1-H13.
- **Minor, files of other packages on the branch: t_save.gd and the fixture moved to hooks (H12); trees.json kept,
  for the integrator to confirm.** `git diff --name-only claude/mmo-overhaul...HEAD` no longer lists
  `game/tests/t_save.gd` or `game/tests/fixtures/save_v3_skills_rev2.json` (W1-SAVE's, plan-register:175); the same
  changes are hook H12. trees.json stays: plan-register:621 lists it under W2-DATA, but HANDOFF.md:94 says
  "`requires_node` ids must match W2-SKILLS' trees.json" and HANDOFF.md:104 orders "W2-DATA -> W2-SKILLS (its
  trees.json node ids feed DATA's `requires_node`)", and W2-DATA's branch does not touch it
  (`git diff --stat claude/mmo-overhaul...claude/mmo-w2-data -- game/data/skills/` is empty). taming_pen.gd
  stays as the orchestrator's grant (Review r1).
- **Minor, Refund stayed active after the day's free refunds: fixed (H8 + `SkillState.refund_reason`).**
  `refund_reason(tree, id)` is the one refusal check (learned automatically, a learned node needs it, the daily
  limit); `refund()` refuses with it and the sheet greys the button and shows "Cannot refund: ..." under the node
  before the tap. The red after-the-tap line (`_refused_id`) is gone. Mutation (button not greyed):
  `[t_w2_skills] FAIL the day's 5 refunds used: Charcoal's Refund is greyed and says why before the tap (disabled false, reason 'Cannot refund: the 5 free refunds of the day are used, more tomorrow')`.
  `desk_glc_refund.png` and `phone_glc_refund.png`: the Charcoal row is green with "Cannot refund: the 5 free
  refunds of the day are used, more tomorrow" under it and a greyed Refund; Leather Strap and Dry Leather keep
  white Unlock buttons.
- **Minor, H6 should clamp rev-2 tree levels to the character level: not done; the clamp would take progress
  away.** Every migrated save is rev 2 from its second load on, and real rev-1 saves hold trees above the
  character level: rev 1 fed every skill gain to World XP once and to Survival as well, so 7,040 XP is Survival
  40 (trees from 0, 20 + 8L per level) and character Lv. 21 (100 + 25L). With the proposed clamp in H6 (scratch
  mutation, rev 2 only, max(character level, occupation 20)) t_save prints
  `[t_save] FAIL re-load: every node bought under rev 1 is kept (missing ["island_access_15", "belly_fat_1", "capture_technique_1", "capture_tool_1", "stealth_1", "island_access_25", "capture_technique_2", "climate_body_1", "island_access_35", "capture_technique_3", "animal_management_1", "island_access_45", "capture_technique_4", "animal_management_2"])`,
  `[t_save] FAIL re-load: the 539 unspent SP are kept (got 374)` and
  `[t_save] FAIL re-load: Animal Handling I + II give 5 bonded slots (got 3)`.
  It would also close nothing: a save without `"rev"` is read as rev 1 and keeps any level (t_w2_skills "H6: a
  rev-1 save keeps every node it bought under the old award and its 50 unspent SP", Survival 40 at character
  Lv. 1, passes). Telling a forged save from a migrated one needs the server's record: W3-SRVACT moves levels,
  purchases and the bonded cap to CharacterState (Left, below). The H6 comment keeps the `shortcut:` note.
- **Minor, the occupation's Lv. 20 exemption was listed as an assumption: moved to Open owner decisions 5** as
  a conflict between docs; the code comment in `SkillState.level_cap` says so.
- **Minor, H1 and W2-DATA's progression_block hunk: the integrator's merge is tried and passes.** H1's comment
  now says it is the only `requires_node` check. Trial tree (scratchpad `trees/w2s-r7d`): this branch @ 5e77eb8c,
  `git merge claude/mmo-w2-data` (0554797a, no conflict), W2-DATA's hooks (clean), then this patch with
  `--3way`: only `crafting.gd` conflicts, inside `progression_block`. Resolution: keep H1's block, drop W2-DATA's
  three `requires_node` lines and its `_node_block()` helper (no other caller; `SkillRules.recipe_block` names
  the node, tree, level and SP). After `--import` (rc 0, 0 SCRIPT ERROR):
  `[t_w2_skills] catalog 212 of 918 nodes: functional 34 (16 of them through requires_node), partial 19, defined 159`,
  `[t_w2_skills] recipes gated by requires_node: 56`, `[t_w2_skills] PASS`;
  `[t_data] smelt_copper gate: before 'learn Smelting 1 (Processing Lv. 25, 15 SP); you have 0 SP, reach Lv. 2 for +10 SP', after learning smelting_1 ''`,
  `[t_data] PASS items=223 recipes=155`. Whoever regenerates this patch after the W2-DATA merge applies that
  resolution.
- **Minor, skills_lab asserted nothing: fixed (H13, W1-QA's file).** It earns character Lv. 2 with gathering XP,
  checks the SP, buys Till Small Field and round-trips the save, and exits 1 on failure:
  `[skill] character level 2 gathering level=2 sp=10`, `[skill] PASS level-up pays 10 SP, small_field bought`.
  Mutation (unlock does not recount SP): `[skill] FAIL level-up pays 10 SP, small_field bought`, rc 1.
- **Minor, recipe gates rebuilt per call: fixed.** `SkillRules._index(sk)` builds the gate map and the buyable
  set per tree once per SkillState (`SkillState._rules_cache`, cleared when trees.json loads) and rebuilds only
  when the recipe count changes. `recipe_block`, `buyable` and `node_state` are lookups now. Learning or refunding
  changes none of these maps, so nothing invalidates them. With the r6 skill_rules.gd:
  `[t_w2_skills] FAIL the recipe gate map is built once, not on every recipe_block / buyable call`.
- **Minor, two "/ 3" counters on the pets screen: fixed (H10).** The equip button reads "EQUIP   (ACTIVE 0 / 3)"
  under "ANIMALS · BONDED 2 / 3 · GROWTH" (`desk_glc_pets.png`, `phone_glc_pets.png`, `desk_fwd_pets.png`; the
  button stays inside its 220 px and clear of CLOSE). With the r6 animal_screen.gd:
  `[t_w2_skills] FAIL the equip button names its counter, so it cannot be read as the bonded cap ('EQUIP   (0 / 3)')`.
- **Minor, the server copy of the trees has no character-level cap: recorded for W3-SRVACT** with the bonded cap
  and node purchases (Left, below).
- **Minor, pacing of island travel and capture: added to Open owner decisions 6, with a probe.** t_w2_skills
  prints, asserting nothing:
  `[t_w2_skills] pacing: Survival 10 took 280 gathers before the cap, now 900 (character Lv. 10 needs 1800 XP)`,
  `[t_w2_skills] pacing: Survival 15 took 570 gathers before the cap, now 1838 (character Lv. 15 needs 3675 XP)`.
- Seen in the shots and fixed: Processing's Lv. 55 node read "Great success p" (an id suffix from the PRD
  import); its name is now "Great success".

## Review r6 (fixed in 6d436beb, hooks 52c15c19)

- The level-up banner showed "Available Skill Points" as the count of unbought survival.json nodes. Hook H11
  (`hunt_hud.gd` `_on_level_up`) shows `SkillState.sp_now()`, which recounts first because the HUD's handler on
  `World.pioneer_changed` can run before SkillState's. With the r5 hooks:
  `[t_w2_skills] FAIL character Lv. 2: the level-up banner shows the 10 SP SkillState holds (10): 'Dexterity +6 · other stats +5 · Skill points 0' | Lv. 2, Pioneer XP 0, T-stones 20, Available Skill Points: 0, ...`;
  with `sp_now()` not recounting: `... character Lv. 3: ... (20): 'Agility +6 · other stats +5 · Skill points 10' ...`.
- W2-DATA's `requires_node` recipes now read like every skill gate ("learn Work pick (Weapon / Tools Lv. 5,
  6 SP)"): `SkillRules.recipe_gates` maps them too. With the r5 gates:
  `[t_w2_skills] FAIL a requires_node recipe reads like every skill gate (spec 12:197): ''`.
- The catalog line counts a node a loaded recipe names in `requires_node` as functional.
- `SkillRules.can_bond` was removed: no caller (every bond path asks `Data.bonded_cap()`).
- H7's craft card lock got a check: without H7,
  `[t_w2_skills] FAIL the charcoal craft card says what unlocks it, above the ingredients: ''`.
- r6 gates: the run at 52c15c19 stopped after 10 of the 20 tests (t_ai, t_build, t_canim, t_combat, t_harbour,
  t_iconart, t_items, t_light, t_lighting, t_occlude, all PASS, import rc 0). Every r6 change is in 5e77eb8c, where
  the full set below ran.

## Acceptance r7 (branch @ 5e77eb8c + hooks H1-H13, claude/mmo-overhaul @ cecc936b merged)

Gate tree `trees/w2s-r7g`: mkscratch.sh at 5e77eb8c with this patch (it applied cleanly), imported once. Its
game/ is identical to the authoring tree's (`diff -rq` empty). The trees.json name fix came after; t_w2_skills
and t_save were rerun with it: both PASS.
- `--import`: 0 SCRIPT ERROR.
- All 20 `t_*.gd` PASS: t_ai, t_build, t_canim, t_combat, t_harbour, t_iconart, t_items, t_light, t_lighting,
  t_occlude, t_player, t_save, t_server_domain, t_srvdom, t_structart, t_tame, t_ui, t_uiicons, t_w2_skills,
  t_web. Only t_save prints SCRIPT ERROR lines: its 5 deliberate ones, as on the base.
- `[t_save] rev-1 skills migrate: 19 nodes kept, SP 539/802`, then `[t_save] PASS`.
- `[t_w2_skills] catalog 212 of 918 nodes: functional 18 (0 of them through requires_node), partial 19, defined 175`,
  then `[t_w2_skills] PASS` (15 sections).
- run_all: `[tests] PASS`. `tools/smoke.sh --no-import`: `SMOKE PASS`.
- Labs, 0 SCRIPT ERROR each: skills_lab `[skill] PASS level-up pays 10 SP, small_field bought`; capture_lab
  `[capture] PASS bonded+=2`; ui_family_lab `[uifamily] inventory=true animals=true unlimited=true active_cap=3`
  (H5's cap-3 check); ui_real_capture_lab `[uireal] PASS screens=hud,craft,skills,...` at 844x390 and
  1600x900 on gl_compatibility.
- No "couldn't resolve track" in any log. No new `~/Library/Logs/DiagnosticReports/Godot-*.ips` (34 before and
  after).

r7 screenshots, looked at (scratchpad `r7shots/`; the refund and pets shots use scratch-only skills_lab edits that
are not committed: character Lv. 30 with the 5 refunds spent, and two bonded raptors with none out):
- `desk_glc_tree.png`, `desk_fwd_tree.png` (1600x900), `phone_glc_tree.png` (844x390): "Gathering Lv. 1", "SP
  0", the AUTO line, "All skills", then the 11 muted rows. Readable at phone size; Close inside the view.
- `desk_glc_refund.png`, `phone_glc_refund.png`: Processing Lv. 30, SP 309, the greyed Refund described above.
- `desk_glc_refundscroll.png`, `phone_glc_refundscroll.png`: the end of Processing's 34 muted rows.
- `desk_glc_pets.png`, `phone_glc_pets.png`, `desk_fwd_pets.png`: "BONDED 2 / 3" and "EQUIP (ACTIVE 0 / 3)".
- `uireal_844x390/`, `uireal_1600x900/`: every screen; skills overview at Lv. 1, animals with the pet out
  ("DISMISS").

## Review r5 findings (fixed in r5)

Scope check (the check that would have caught the blocker), run at the r5 head:
`git diff --name-only claude/mmo-overhaul...HEAD | grep -vE '<package files and grants>'` prints nothing
(exit 1). The pattern is the Files list above plus this report, the hooks patch and the review findings file.

- **BLOCKER, skills_sheet.gd edited on the branch: fixed.** The file is back to claude/mmo-overhaul on the branch
  (`git diff claude/mmo-overhaul HEAD -- game/scripts/ui/skills_sheet.gd` is empty). The same diff, plus the
  fold below, is hook H8. `git apply --check` on claude/mmo-overhaul @ 34b6d459: clean.
  t_w2_skills now checks the sheet (section "skills sheet rows"). With the old sheet (hooks H1-H7 only) it prints
  `[t_w2_skills] FAIL gathering at Lv. 1: no 'not in the game yet' rows, one line counts them (11 rows, line '', want 11)`
  and `[t_w2_skills] FAIL gathering at Lv. 1: the learned AUTO nodes share one line ('')`.
- **MAJOR, field tame at the cap was silent: fixed (hook H9, field_tame.gd is W1-TAME's).**
  `FieldTame.roster_full(player)` returns "Bonded roster full (n / cap)". `plate_hint` shows it as a `need`
  hint (no food icon, no bar) for the local survivor, and `apply_feed` calls `player.notice(... + ". Animal
  Handling (Survival) adds slots.")` before it returns false, so the food stays in the bag.
  Hook H10 puts "BONDED n / cap" in the pets screen title (spec 09:50 "Display bonded count and max in the pets
  UI (e.g. `3 / 4`)"); W2-BREED no longer needs to add it.
  Check, t_w2_skills section "field-tame cap" (real Player, a stand-in HUD that records notices). Old hooks:
  `[t_w2_skills] FAIL 3 / 3 bonded: the plate says the roster is full, not Tame (got tame 'Tame')`,
  `[t_w2_skills] FAIL 3 / 3 bonded: the refusal is on screen and names Animal Handling (notices '')`,
  `[t_w2_skills] FAIL the pets screen shows bonded / cap (title 'ANIMALS    ·    GROWTH')`.
  New hooks: `[ui] notice Bonded roster full (3 / 3). Animal Handling (Survival) adds slots.`, then
  `[t_w2_skills] PASS`; the food check ("the feed is refused and the berry is kept") passes in both.
- **Minor, hostile `rev`: fixed (H6).** The sanitizer writes the number it used back:
  `sv["rev"] = _int(sv.get("rev", 1), 1, SkillState.REV)`, so `from_dict` reads the same rev. A hand-edited
  `[2]`, `"2"` or `-3` loads as rev 1 and migrates with its nodes and unspent SP. Old H6:
  `SCRIPT ERROR: Invalid call. Nonexistent 'int' constructor.`,
  `[t_w2_skills] FAIL H6: rev [2] loads as rev [2] with its 4 nodes and 50 SP (got 0 SP)` and
  `[t_w2_skills] FAIL H6: rev "2" loads as rev 2 with its 4 nodes and 50 SP (got 0 SP)`. New H6: PASS, and
  t_w2_skills prints no SCRIPT ERROR.
- **Minor, a fresh tree is a screen of grey rows: fixed (H8).** Nodes locked with `SkillState.NOT_IN_GAME`
  fold into one muted line with the count. Gathering at Lv. 1 now shows the AUTO line and "11 more nodes come
  with later updates"; Processing shows its buyable rows first, then "34 more nodes come with later updates".
  Gathering has no node the game reads yet (all partial or defined until W2-GATHER wires them), so it has no
  Unlock row; that is the honest state (spec 12:215).
- **Minor, Dry Leather paces cured hide: raised, value kept (spec 11:34).** Confirmed on claude/mmo-w2-data @
  f9a66e85: the `cured_hide` category holds only `dried_hide` and `hide_strap`, `hide_strap` is made from
  `dried_hide`, and 32 live recipes take `cured_hide` (tent_kit, every forager, leather, hide_bone, raid, copper,
  bronze, iron and steel armour piece; cabin_bed_kit is staged). With H1 the `dried_hide` recipe waits for Dry
  Leather (Processing 15), so all of them wait for character Lv. 15. canvas_tent_kit and log_shelter_kit still
  give early shelter. This is a pacing call for the owner and the integrator (see Open owner decisions); no
  check is added, because the level a check should assert ("the bed and the first armour band by character
  Lv. N") is that decision.
- **Minor, `refund_block()` changed state; SP adjusted by hand: fixed.** `refund_block()` only reads (a new
  day counts as 0 used); `_roll_day()` runs in `refund()`. `unlock()` and `refund()` call `_recount_sp()`.
  Checks with the old skill_state.gd:
  `[t_w2_skills] FAIL refund_block() is a query: it leaves the day's counter alone (day 20747, used 0)` and
  `[t_w2_skills] FAIL refunding an over-budget node gives back no SP the character level never paid (available 1)`.
- **Acceptance "Bonded cap 3 -> 7, refusal loses no animal": met** for the pen (unchanged) and the field tame
  (above): `[ui] notice Bonded roster full (3 / 3). Animal Handling (Survival) adds slots.`; screenshots below.
- **Acceptance "save round-trips and hostile inputs": met.** `rev 2 round-trips unchanged` holds, and the
  hostile rev cases pass with no SCRIPT ERROR.
- **Acceptance "scope: only the package's files and grants": met** (scope check above).

## Save format change (owner approved: save rev 2 with migration of rev-1 saves)

skills_v2 gains `"rev": 2`, `"sp_earned"` (informational) and `"sp_extra"`. A rev-1 save migrates when it loads:
- A level stored as 0 reads as Lv. 1.
- SP are recomputed from the character level.
- Every learned node is kept and re-priced at today's costs.
- **Unspent SP are not kept** (finish-run review r1; it reverses r1 minor 1 of the first run, which kept them;
  review r2 asks the owner to confirm it: owner_gate, STATUS "Owner questions (open)").
  Spec 03:14 "players can level many professions but cannot afford all nodes simultaneously" and PRD 7.3 settle
  it. `sp_extra` is the SP of the kept nodes beyond what the character level paid; new levels pay it off before
  they add SP, so a migrated save never holds more SP than a new character at its level beyond the nodes it
  keeps. The first load shows two short notices (review r2: one long line was not drawn at 844x390): "Skill
  points now follow your level" and "All skills kept; 223 SP owed" (or "All skills kept; N SP to spend"). While SP
  are owed, the skills sheet's SP readout says "SP 0 · 223 owed by kept skills". H6 writes the same `sp_extra` back, so a forged or older rev-2 `sp_extra` cannot mint SP.
- AUTO nodes are learned.
- Nothing is deleted.

r4 adds two optional fields with no rev bump: `refund_day` (the UTC day the counter belongs to, -1 when no
refund has happened) and `refunds_today`. A save without them loads with no refunds used; H6 makes both
numbers.

r8 widens one field with no rev bump: a tree's `xp` may exceed its bar, because a tree at the character-level
cap banks its XP. Every older save holds `xp` below the bar, which loads unchanged. H6 bounds it by
`SkillState.xp_to_max(level)` (the XP the tree can still use up to Lv. 60) instead of `xp_to_next(level)`. A
save written by r8 and read by older code loses only the bank (the old sanitizer clamps it to the bar).

The rev-1 goldens are untouched inputs again (r1 major). t_save loads each one through SaveGame and
SaveSanitizer and compares the result with `save_v3_skills_rev2.json`, field for field in both directions.
`_test_rev1_skills` loads a rev-1 golden that bought 19 nodes under the old award (old prices, Survival 55),
then saves and loads it again. Both passes assert: levels kept, 0 reads Lv. 1, rev 2, the Lv1 AUTO nodes
learned, every bought node kept, the 539 unspent SP dropped (0 available), `sp_extra` 223 = the 263 SP of nodes at
today's prices beyond character Lv. 5's 40, and
5 bonded slots. In the forged-save check, Stealth I (Survival Lv. 10, no prerequisite, spec 12) is reachable, so
the expectation is `[island_access_15, stealth_1]` with sp_spent 7.

## Review r1 (docs/orchestration/mmo/handoff/findings/w2-skills-review-r1.json)

- **MAJOR, goldens rewritten: fixed** as above. Mutation proof: see Acceptance.
- **Minor, rev-1 saves lose unspent SP: fixed** (`sp_extra`, above). Spec 03 does not say to drop them.
- **Minor, the field kit waits for character Lv. 2: kept, per spec 12:80** "Till Small Field is Lv1/1 SP".
  A Lv. 1 survivor has 0 SP (spec 03: SP come from character levels), so the lock now says where the SP come
  from: "learn Till Small Field (Farming Lv. 1, 1 SP); you have 0 SP, reach Lv. 2 for +10 SP". Hook H7 shows
  it on the craft card above the ingredients, so a phone shows it without scrolling.
- **Minor, Processing gates at Lv. 10: kept, per spec 11:33** "| 10 | Charcoal; Leather Strap | 1–2 |" (Dry
  Leather and Peeled Bark at 15, 11:34). The review found no dead end: every gated output has ungated
  substitutes. Pacing (XP per character level) is an owner call and not part of this package.
- **Minor, taming_pen bonds without the cap: fixed** (orchestrator grant, W2-BREED not running).
  `Data.bonded_cap()` (hook H2) is the one function: 3 + Animal Handling I-IV, at most 7
  (`SkillRules.bonded_capacity`, spec 09:48). Caged animals are items and never count (09:33). At the cap the
  pen keeps the finished animal inside, unbonded, and says "Bonded roster full (n / cap)". It bonds on the
  first frame a slot is free, so nothing is lost or rolled twice. Feeding a finished animal is refused, because
  it would restart the timer. A legacy `tamed_animal` stays in the bag with the same notice. The market's
  caged-pet unpack should call `Data.bonded_cap()`.

## Review r2 (blocker, three minors)

- **BLOCKER, W2-DATA's `requires_node` recipes locked for good: fixed.** W2-DATA gates 52 recipes on 16 nodes
  that are `defined` here (work_pick, combat_knife, copper_tools, blade_shapes, iron_weapons, armor_1,
  scute_armor, furnace_kiln, hammer, smelting_1, smelting_2, nails_pillars, steam, fertilizer, antivenom,
  antibiotic). `SkillRules.buyable()` now treats any node a loaded recipe names in `requires_node` as
  functional (`SkillRules.recipe_nodes()`, read from `Data.recipes`), prerequisites included. This works in
  either merge order, and trees.json keeps its statuses because the effect lives in W2-DATA's data. Staged
  recipes are not loaded, so they unlock nothing.
  - Check: t_w2_skills asserts that every loaded recipe's `requires_node` is a trees.json node that SP can buy.
    It also injects a `requires_node: work_pick` recipe on this branch's data, where no recipe names a node yet.
  - With W2-DATA's recipes.json and items.json checked out over this branch (hooks applied):
    `[t_w2_skills] recipes gated by requires_node: 52`, then `[t_w2_skills] PASS`.
  - The same data with the old `buyable()` prints 53 FAIL lines, among them
    `[t_w2_skills] FAIL recipe flint_knife requires_node work_pick: a trees.json node SP can buy`,
    `... smelt_copper requires_node smelting_1 ...`, `... iron_sword requires_node iron_weapons ...`,
    `... forge_kit requires_node furnace_kiln ...` and `... anvil_kit requires_node hammer ...`.
  - On this branch's data with the old `buyable()`:
    `[t_w2_skills] FAIL a defined node a recipe names in requires_node is buyable with its prerequisite (work_pick)`.
- **Minor, 10 "Learned" rows open the Gathering tree: fixed** (skills sheet, above). `lab_phone_glc_tree.png`
  (844x390, gl_compatibility) now opens on Thickets, Mining 1, Herbs 1 and Insects. `lab_desk_glc_tree.png`
  shows "Long Branch · Lv. 45 · 5 SP" with no repeated "Long Branch" line under it.
- **Minor, two copies of the survival id bridge: fixed.** `unlock()` calls `_mirror_survival(node_id, true)`,
  as `refund()` and `from_dict()` do. The mirror now writes only ids survival.json knows, the same rule loading
  uses (t_save: "an unknown id unlocks nothing").
- **Minor, the daily refund limit:** built in r4 (vision fix 2, below).

## Vision fixes (vision-check.md) and whether they are needed

The owner asked whether the vision check is really necessary. For this package: one of its two items was
needed and the other was not, so only one was built.

1. **Non-functional nodes cannot be bought: built.** Spec 12:215 says "Do not implement a decorative but inert
   918-node UI" (checked). It was needed. 194 of the 212 nodes are partial or defined: the game reads nothing
   from them, so every SP spent on one was lost. `SkillRules.buyable()` allows only functional nodes and the
   prerequisite chain a functional node needs. Island Access 15-55, Belly Fat I and Climate Body I stay
   buyable on the way to Capture Technique and Animal Handling; Cloth Clothes, Small Bag and Bandage stay
   buyable on the way to Heat and Cold Resist. A node a loaded recipe names in `requires_node` (W2-DATA's
   gate) also counts, with its prerequisite chain (review r2 blocker, below). Every other node shows locked:
   "not in the game yet". Nodes a
   save already owns stay owned and can still be refunded. AUTO nodes are still learned free.
   - Checking this showed that Dry Leather was marked defined while it gates the existing `dried_hide` recipe
     (hook H1). With the new rule that would have locked dried hide for good, a dead end once W2-DATA makes
     straps need dried hide. It is now functional, and t_w2_skills asserts that every recipe-gating node is
     functional.
   - The W2-PROCESS hooks should flip Handicraft and Metalworking to functional when they read
     `SkillRules.ability`, and W2-ACTION should do the same for Stealth and Slaughter. Until then those nodes
     are not for sale.
2. **Daily refund limit: built in r4.** The cited lines say it: docs/design/skills.md:9 "Refunds: 5 free
   unlearns a day, then 30 Warp Gems, max 10 a day", and spec 03:37 "keep configurable, do not require
   monetization". (r3 had skipped it; this run's task restated it, so it is built.)
   - `SkillState.refund_block()` reads trees.json `refund` (`free_per_day` 5, `warp_gems_each` 30,
     `max_per_day` 10). The day is a UTC calendar day (ASSUMPTION).
   - Warp Gems do not exist in the game (no hit in game/scripts or game/data), so nothing is charged: past
     the free count `refund()` refuses, keeps the node and leaves the reason in `SkillState.refused`:
     "Cannot refund: the 5 free refunds of the day are used, more tomorrow". A `shortcut:` comment marks
     where the gem charge goes once that currency exists.
   - The skills sheet shows the reason in red on the row the player tapped (a HUD notice would sit under
     the opaque sheet on a phone). Other refusals (learned automatically, a learned node needs it) now show
     there too; before they only printed.
   - The counter is the optional save pair above (no rev bump).
   - Online it is still client-side, like node purchases, until W3-SRVACT moves purchases to the server.

## Acceptance r5 (branch @ e39d8e82 + hooks H1-H10, claude/mmo-overhaul @ 34b6d459 unchanged, so no merge)

Scratch tree `trees/w2s-r5` (mkscratch.sh at e39d8e82 with the r4 patch, then H6/H8/H9/H10 authored there and
the patch regenerated from it with `git diff HEAD`). The r5 commits after e39d8e82 touch only this report and
the patch. `git apply --check` of the new patch: clean on the branch and on claude/mmo-overhaul @ 34b6d459.
- `--import`: rc 0, 0 SCRIPT ERROR.
- All 20 `t_*.gd` print PASS (t_ai, t_build, t_canim, t_combat, t_harbour, t_iconart, t_items, t_light,
  t_lighting, t_occlude, t_player, t_save, t_server_domain, t_srvdom, t_structart, t_tame, t_ui, t_uiicons,
  t_w2_skills, t_web). Only t_save prints SCRIPT ERROR lines: its 5 deliberate ones, as on the base.
- `[t_save] rev-1 skills migrate: 19 nodes kept, SP 539/802`, then `[t_save] PASS`.
- `[t_w2_skills] catalog 212 of 918 nodes: functional 18, partial 19, defined 175`, then `[t_w2_skills] PASS`
  (13 sections; new: field-tame cap, skills sheet rows; extended: H6 hostile rev, refund query and SP drift).
- run_all: `[tests] PASS`. `tools/smoke.sh --no-import`: `SMOKE PASS`.
- Labs, 0 SCRIPT ERROR each: skills_lab `[skill] character level 1`; capture_lab `[capture] PASS bonded+=2`;
  ui_family_lab `[uifamily] inventory=true animals=true unlimited=true active_cap=3` (H5's cap-3 check);
  ui_real_capture_lab `[uireal] PASS screens=hud,craft,skills,...` at 844x390 and 1600x900 on gl_compatibility.
- No "couldn't resolve track" in any log. No new `~/Library/Logs/DiagnosticReports/Godot-*.ips` (27 Godot
  reports before and after).

r5 screenshots, looked at (scratchpad `r5shots/`; the refund and roster-full ones use scratch-only lab edits
that are not committed: skills_lab sets character Lv. 30 and spends the 5 refunds, capture_lab gives 3 bonded
records before the shot):
- `desk_glc_tree.png` (1600x900 gl_compatibility), `desk_fwd_tree.png`, `phone_glc_tree.png` (844x390):
  "Gathering Lv. 1", "SP 0", "Learned automatically: Leaf, Branch, Bush, Fruit I, Log I, Bug I, Pebble, Mud I,
  Stalk", "11 more nodes come with later updates", then "All skills". No grey rows.
- `desk_glc_refund.png`, `phone_glc_refund.png`: "Processing Lv. 30", "SP 309"; rows Leather Strap (Unlock),
  Charcoal in red with "Cannot refund: the 5 free refunds of the day are used, more tomorrow" (Refund), Dry
  Leather (Unlock), then "Learned automatically: Rope" and "34 more nodes come with later updates". Readable at
  844x390.
- `desk_glc_rosterfull.png`, `desk_fwd_rosterfull.png`, `phone_glc_rosterfull.png`: the downed
  Compsognathus's plate reads "Bonded roster full (3 / 3)" in the orange hint colour, with no feed bar.
- `uireal_844x390/animals_844x390.png`, `uireal_1600x900/animals_1600x900.png`: the pets screen title reads
  "ANIMALS · BONDED 1 / 3 · GROWTH".

## Acceptance r4 (branch @ e33c4d75, merged with claude/mmo-overhaul @ 34b6d459, hooks H1-H7 applied)

Scratch tree `trees/w2s-r4` (mkscratch.sh, hooks applied with `git apply --3way`, imported once). The hooks
patch was regenerated after the base merge: H6 gained the refund-counter clamp, nothing else changed. It
applies clean on the branch, and the hooked files are identical on claude/mmo-overhaul @ 34b6d459.
- `--import`: 0 SCRIPT ERROR.
- All 20 `t_*.gd` print PASS (t_ai, t_build, t_canim, t_combat, t_harbour, t_iconart, t_items, t_light,
  t_lighting, t_occlude, t_player, t_save, t_server_domain, t_srvdom, t_structart, t_tame, t_ui, t_uiicons,
  t_w2_skills, t_web). Only t_save prints SCRIPT ERROR lines: its deliberate ones (3 errors and 2
  announcements, 5 matching lines), as on the base.
- `[t_save] rev-1 skills migrate: 19 nodes kept, SP 539/802`, then `[t_save] PASS`.
- `[t_w2_skills] catalog 212 of 918 nodes: functional 18, partial 19, defined 175`, then `[t_w2_skills] PASS`
  (11 sections, including the new refund limit and the H6 refund-counter types).
- run_all: `[tests] PASS`. `tools/smoke.sh --no-import`: `SMOKE PASS`.
- `[uireal] PASS screens=hud,craft,skills,...` at 844x390 on gl_compatibility, 0 SCRIPT ERROR. The headless
  skills_lab: `[skill] character level 1`, 0 SCRIPT ERROR.
- No "couldn't resolve track" in any log. No new `~/Library/Logs/DiagnosticReports/Godot-*.ips` (the list
  is the same before and after the run).

Mutation proofs at this head:
- Refund limit off (`if refunds_today < free:` -> `if true:`):
  `[t_w2_skills] FAIL refund 6 of the day is refused with a reason and keeps the node: ''`,
  `[t_w2_skills] FAIL the day's refund count survives a save and load`.
- Rev-1 unspent-SP line in `SkillState.from_dict` replaced by `sp_extra = 0`:
  `[t_save] FAIL save_v3_golden.json skills_v2 migrates to its rev-2 expectation: ["/skills_v2/sp_available: 270.0 vs 40.0", ...]`,
  `[t_save] FAIL first load: the 539 unspent SP are kept (got 0)`,
  `[t_save] FAIL re-load: every node bought under rev 1 is kept (missing ["island_access_25", ...])`,
  `[t_save] FAIL count=7`.

r4 screenshots, looked at (scratchpad `g4/shots/`). A scratch-only skills_lab edit (never committed) sets
character Lv. 30, buys and refunds Charcoal 5 times, buys it again, opens Processing and taps its Refund:
- `desk_fwd_refund.png` (1600x900 Forward+) and `desk_glc_refund.png` (1600x900 gl_compatibility): the
  Charcoal row is red and reads "Cannot refund: the 5 free refunds of the day are used, more tomorrow"; the
  node stays owned (Refund button still there); "Processing Lv. 30", "SP 309".
- `phone_glc_refund.png` (844x390): the same red line on one row next to its Refund button, readable at
  phone size, Close inside the view.
- `uireal/skills_844x390.png` (fresh survivor): every tree reads Lv. 1, "SP 0", no "Lv. 0".
- `desk_glc_tree.png`, `phone_glc_tree.png`: Gathering at Lv. 1 with "not in the game yet" locks, readable.

## Acceptance r3 (branch merged with claude/mmo-overhaul @ 548059bc, hooks applied in a scratch tree)

Hooks patch: unchanged, `git apply --check` clean on claude/mmo-overhaul @ 548059bc and on the branch. The
base moves since c2b373f3 are docs only (STATUS, workflows, spec 14), and the r2 fixes touch no hooked file. Gates
ran before the 548059bc merge.

Every gate below ran at the r2 fix commit in a scratch tree with hooks H1-H7 applied.
- `--import`: 0 SCRIPT ERROR.
- All 20 `t_*.gd` print PASS: t_ai, t_build, t_canim, t_combat, t_harbour, t_iconart, t_items, t_light,
  t_lighting, t_occlude, t_player, t_save, t_server_domain, t_srvdom, t_structart, t_tame, t_ui, t_uiicons,
  t_w2_skills, t_web.
- Only t_save prints SCRIPT ERRORs: its 5 deliberate ones, as on the base.
- `[t_save] rev-1 skills migrate: 19 nodes kept, SP 539/802`
- `[t_w2_skills] catalog 212 of 918 nodes: functional 18, partial 19, defined 175`,
  `[t_w2_skills] recipes gated by requires_node: 0` (52 with W2-DATA's recipes, above), then `[t_w2_skills] PASS`
- run_all: `[tests] PASS`
- `tools/smoke.sh --no-import`: `SMOKE PASS`
- No new `~/Library/Logs/DiagnosticReports/Godot-*.ips` (the list is the same before and after the run).

The tests fail when the code is wrong:
- **Migration (t_save).** With the rev-1 unspent-SP line in `SkillState.from_dict` replaced by `sp_extra = 0`:
  - `[t_save] FAIL save_v3_golden.json skills_v2 migrates to its rev-2 expectation: ["/skills_v2/sp_available: 270.0 vs 40.0", ...]`
  - `[t_save] FAIL first load: the 539 unspent SP are kept (got 0)`
  - `[t_save] FAIL re-load: every node bought under rev 1 is kept (missing ["island_access_25", ...])`
  - `[t_save] FAIL count=7`
- **No inert purchases.** With the lock line in `node_state` disabled:
  - `[t_w2_skills] FAIL a partial node cannot be bought: Handicraft I says 'not in the game yet'`
  - `[t_w2_skills] FAIL a defined node no functional node needs cannot be bought (Obsidian)`
- **Recipe gates stay buyable.** On the old data:
  - `[t_w2_skills] FAIL processing/dry_leather gates a recipe, so it must be functional (it is 'defined')`
- The earlier proofs still hold:
  - With `bonded_base` set to 4: `FAIL capacity 4, 5, 6, 7 (got [5, 6, 7, 8])`.
  - With the old per-tree SP award restored: `FAIL character Lv. 5 pays levels 2-5 (40 SP), ...`.

Labs, all with 0 SCRIPT ERROR:
- `[uireal] PASS screens=hud,craft,skills,...` at 844x390 on gl_compatibility. It also checks that the skills
  rows fit their columns.
- skills_lab: `[skill] character level 1`, roundtrip with sp=0.

r2 screenshots looked at (scratchpad `trees/w2s-r3-shots/`): `lab_phone_glc_tree.png` and
`lab_desk_glc_tree.png`, described under Review r2.

r1 screenshots looked at (scratchpad `trees/w2skills-shots/`). The skills sheet opened from the HUD in
skills_lab:
- `lab_desk_fwd_tree.png` (1600x900 Forward+) and `lab_desk_glc_tree.png` (1600x900 gl_compatibility):
  - The header reads "Gathering Lv. 1" and "SP 0".
  - The AUTO rows show a disabled "Learned".
  - "Thickets · Lv. 5 · 6 SP" shows a grey, disabled "not in the game yet" that is readable.
  - No "Lv. 0" anywhere.
- `lab_phone_glc_tree.png` (844x390): the same tree, readable at phone size, with Close inside the view.
- `uireal/skills_844x390.png`: the overview shows every tree at Lv. 1.
- The plain main-game shot shows character creation over the sheet, so it was not used.

## Integrator hooks (`docs/orchestration/reports/claude-mmo-w2-skills-hooks.patch`, `git apply` checked)

H1-H13 below were applied in 6f65f615. Since the finish-run review r1 the patch file holds only that round's
changes, against claude/mmo-overhaul (see "Finish-run review r1" for the list): H2 (player argument), H6
(`sp_extra` written back), H8 (muted rows' second line), H9 (`roster_full` per player), H12 (t_save and the
fixture), H14 `game/scripts/dev/ui_real_capture_lab.gd` (W1-UI's lab: the level-up banner shot sets the
character level), H15 `game/scripts/player/player_pets.gd` (`Data.bonded_cap(p)`), H16
`docs/orchestration/mmo/STATUS.md` (the migration rule, settled by the docs).

- **H1** `game/scripts/items/crafting.gd` `progression_block()`: check `SkillRules.recipe_block` first. This makes
  the recipe gates real. station_craft and craft_ui already route through `progression_block`. After the W2-DATA
  merge it is the only `requires_node` check (W2-DATA's lines and `_node_block()` are dropped; the patch is
  regenerated on 18ef7091, which has them, so it applies as is).
- **H2** `game/scripts/core/data.gd` `bonded_cap(player = null)`: `SkillRules.bonded_capacity(player.skills)`,
  the local survivor's when no player is given, or 3 with no player. This replaces "unlimited", per spec 09. It is the one bonded-cap function. It reaches
  field_tame.apply_feed, player_pets.bond_from_inventory and (on the branch) taming_pen. The market's caged-pet
  unpack should call it too.
- **H3** `game/scripts/server/character_state.gd`: a missing tree defaults to `SkillState.MIN_LEVEL`, not 0.
- **H4** `game/scripts/combat/hunt.gd` (melee and ranged) and `game/scripts/server/intent_handlers.gd` (melee):
  per-level damage and crit bonuses count from Lv. 1 (`level - SkillState.MIN_LEVEL`), so balance is unchanged.
- **H5** `game/scripts/dev/ui_family_lab.gd`: it asserted an unlimited roster. It now expects 3.
- **H7** `game/scripts/ui/craft_ui.gd` `_show_detail`: a gated recipe's detail shows what unlocks it, in red,
  above the ingredients.
- **H8** `game/scripts/ui/skills_sheet.gd` (W1-UI) `_build_tree`: Durango names, "AUTO", the learned-auto
  line, "All skills" above a muted row per node not in the game yet, and a greyed Refund with its reason.
  `_build_overview` (r8): XP banked at the cap reads as a full bar ("28 / 28 XP").
- **H9** `game/scripts/pets/field_tame.gd` (W1-TAME): `roster_full(player)`; `plate_hint` shows it for the
  local survivor; `apply_feed` gives the notice before refusing.
- **H10** `game/scripts/ui/animal_screen.gd`: the title reads "ANIMALS · BONDED n / cap · GROWTH" and the equip
  button "EQUIP (ACTIVE n / 3)".
- **H11** `game/scripts/ui/hunt_hud.gd` `_on_level_up`: "Available Skill Points" is `SkillState.sp_now()`.
- **H12** `game/tests/t_save.gd` and new `game/tests/fixtures/save_v3_skills_rev2.json` (W1-SAVE): the rev-1
  goldens load and migrate to the rev-2 expectation (owner-approved save-test fix; moved off the branch in r7).
- **H13** `game/scripts/dev/skills_lab.gd` (W1-QA): a character level-up pays SP, Till Small Field is bought,
  the save round-trips; exit 1 on failure.
- **H6** `game/scripts/core/save_sanitizer.gd` `_skills(sv, pioneer_level)`:
  - The node-purchase budget is the SP the character level paid.
  - For a rev-1 save, the budget is what its tree levels paid under the old award, so the migration never drops
    a learned node.
  - `sp_available` is clamped to `max(0, character SP - spent)`.
  - The caller passes the clamped `pioneer_level`.
  - A tree's `xp` is bounded by `SkillState.xp_to_max(level)`, not `xp_to_next(level)`, so XP banked at the
    character-level cap survives a load (r8).
  - `rev` is written back as the number the sanitizer used (r5), so a hand-edited rev cannot split the two readers.
  - `sp_extra` is written back as `max(0, kept nodes' cost - SP the character level paid)` for every rev, the
    value `SkillState._recount_sp` derives (finish-run review r1); a rev-2 save's stored `sp_extra` only widens
    the node budget, up to the old award.
  - Known gap: a forged save (any rev) can keep tree levels and nodes up to the old per-tree budget. A rev-2 level clamp would not close it and would strip migrated saves (Review
    r7); W3-SRVACT's server record does.

Wanted from other packages:
- W2-GATHER and the integrator (review r8): spec 12:211 lists Gathering first, yet a new survivor's Gathering
  tree has nothing to buy (9 AUTO nodes, 12 muted rows) because no gathering node has an effect the game reads.
  Make Thickets and Mining 1-4 functional first (wire their effects and flip `status` in trees.json), so the
  first tree gives choices.
- W2-PROCESS reads `SkillRules.ability(sk, "handicraft" | "metal_processing")`. That turns Handicraft and
  Metalworking from partial to functional.
- (Done in H10: the pets screen shows "n / cap".) Other bond paths (the market's caged-pet unpack, W2-BREED's
  hatching) should call `Data.bonded_cap()` and `FieldTame.roster_full()` for the same text.

## Assumptions (`# ASSUMPTION` in code or data)

- Boulder (spec 12:35 "appears early"): Lv. 5 / 1 SP, like Barrage, the one Lv. 5 node spec 12 prices
  (`level_assumed`, `sp_assumed`).
- Animal Handling I requires Capture Technique I.
- SP values marked `sp_assumed`: Stealth II-V, Slaughter I-V, Barrage Damage I-III, Handicraft II-V,
  Metalworking I-IV, level 45/50/60 Processing nodes, the makeshift shovel/hoe and Standard Bow.
- The occupation's Lv. 20 grants no SP.
- A migrated save that is over budget keeps its nodes with 0 SP available. While its kept nodes cost more than its
  character level paid, a level-up or a refund of a kept node pays that debt first and gives no spendable SP
  (spec 03:14 read strictly; finish-run review r1). Career Guides' one-time SP will need their own saved field.
- The refund day is a UTC calendar day; with no Warp Gems in the game, refunds past the free count are refused.

## Open owner decisions

1. ~~Source of SP~~. Decided: per character level, per spec 03. Implemented, with H6.
2. **The 918-node table is still missing (decided: keep the 212 nodes).** The source table (kghj76138.github.io/durango-homecoming-guide/en/skills.html) returned 404 on
   2026-10-20, and the Wayback Machine was offline. Only the nodes the pack names are imported; the counts are
   recorded. Supply the table (or another copy) to finish the import. (213 since r8 added Boulder. r9 grepped
   specs 18-24, merged since r8, which describe the ten new docs/reference images: none names a skill node.
   Spec 23:16's "Skill hexes" are the pet radial's action slots.)
3. ~~The save rev 2 bump~~. Approved as built.
4. **Pacing: when does cured hide open?** Spec 11:34 puts Dry Leather at Processing Lv. 15, and this package
   gates the `dried_hide` recipe on it (H1). After W2-DATA lands, that holds the tent kit and every armour band
   (32 live recipes) until character Lv. 15. Options: keep it (spec value); have W2-DATA let the bed and the
   first armour band take uncut hide; or move the gate. Not a merge blocker: nothing is a dead end
   (canvas_tent_kit and log_shelter_kit give early shelter), and the value follows the spec. Docs searched first: spec 11 gives only the level, spec 03 says nothing about
   which recipes need cured hide, and docs/reference holds two screenshots (the skill categories and a gather
   radial), no node table.

5. **Does the occupation's Lv. 20 head start pass the character-level cap? (doc conflict, r7)** Spec 03:7: "A
   category **cannot exceed character level**"; docs/design/skills.md:7: "A skill level never exceeds the
   character level"; PRD 5.1 (durango-wild-lands-systems-prd.md:327): "Each occupation starts with **skill
   proficiency 20** in one tree". Built: the occupation tree may sit at 20 from character Lv. 1 (otherwise the
   head start is worth nothing until character Lv. 20). The other choice is a one-line change in
   `SkillState.level_cap`. r9: the owner's character-creation reference supports the built side. Spec 19:11 reads
   the screen as showing "the starting skill in gold, 'Lv. 20 Melee'" for a survivor who has not played yet.
6. **Pacing: island travel and capture now wait for the character level (r7).** Survival trains on every gain
   but now stops at the character level, and character levels cost 100 + 25L XP. The first sail route
   (`World.route_level`, Survival 10) goes from about 280 gathers to 900; the next route and Capture Technique I
   (Survival 15) from 570 to 1,838 (t_w2_skills pacing lines above, 2 XP per gather; crafting and kills add XP
   too). Together with item 4 (cured hide at character Lv. 15), early play slows. Options: keep (spec 03); lower
   the early character XP curve; or let Survival pass the cap (it "simply tracks play", skills.md:7).

7. **Rev-1 saves drop their unspent SP: reopened for the owner (review r2, the package's owner_gate).** Built as
   option (b) after the finish-run review r1, from spec 03:14 and PRD 7.3 (durango-wild-lands-systems-prd.md:503):
   nodes kept, unspent SP dropped, `sp_extra` = the kept nodes' cost beyond the character level's SP. Review r2
   found that the brief says "unspent SP and unlocks kept" and that real saves lose a lot (Lv. 23 848 -> 0 with
   51 owed; Lv. 60 2036 -> 0 with 147 owed). The STATUS hunk no longer records it as settled: it is an open owner
   question with a release note (H16). Switching to "keep" is the `sp_extra` line in `SkillState._recount_sp` and
   H6's write-back; nothing else changes.
   The original entry:
   **Rev-1 saves keep their old SP as a permanent extra (review r8, numbers from the reviewer's save).** A
   migrated rev-1 save keeps its unspent SP as `sp_extra`, and new character levels pay on top of it (Save format
   change; kept per review r1). The reviewer's real base-made save (character Lv. 22) loads with 1075 SP
   available (earned 1237, of which extra 1023); a new Lv. 22 character has 214 (`paid_for_level(22)`). At
   Lv. 60 that save would hold about 1743 SP against 720 for anyone else, and spec 03 makes scarce SP the core
   mechanic ("cannot afford all nodes"). Options: (a) keep, as built; (b) cap `sp_extra` at what the save's
   learned nodes cost beyond the SP its character level pays (nodes kept, old unspent SP dropped); (c) a
   one-time free respec: every bought node refunded, `sp_extra` 0, SP = what the character level paid. (b) and
   (c) are a few lines in `SkillState.from_dict`'s rev-1 branch and H6.

## Left (not done)

- Research timers (spec 03 table).
- Career Guides.
- Attribute service.
- For W3-SRVACT, server side: recipe gates and node purchases (CharacterState keeps levels only), the bonded cap
  on the tame intent (`intent_handlers.gd` `_tame`: check `SkillRules.bonded_capacity` against the
  CharacterState skills before `ch.d.pets[uid] = ...` and refuse with `roster_full`, food kept), and the character-level cap in `CharacterState.add_xp` (the server copy levels trees past
  the character level, so server gather yield and melee bonuses would use higher levels than the client shows).
- Gathering, butchering and tailoring effects of the defined nodes, owned by W2-GATHER, W2-BUTCHER, W2-TAILOR,
  W2-ACTION and W2-CRAFT.
- Stealth Ability in the AI detection service.

No labs to register. No dsc worker was used: the import was a single scripted transform, and per the owner's
2026-10-20 note dsc is off unless asked.
