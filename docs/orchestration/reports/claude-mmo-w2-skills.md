# W2-SKILLS (claude/mmo-w2-skills): Durango 1-60 skill trees

Scope (HANDOFF §4): durango-prompts 03 + 09 + 11 + 12. Durango 1-60 levels, Lv1 AUTO nodes, Animal Handling I-IV,
the Processing tree, the 918-node table imported as data with each node marked functional / partial / defined,
recipe-gated progression, and survivors that start at Lv. 1.

## What shipped

- **Trees start at Lv. 1.** `SkillState.MIN_LEVEL = 1`. A new survivor reads Lv. 1 in every tree (it showed Lv. 0 before).
  The player badge and XP line already read Lv. 1 on the base through `LevelDisplay`.
- **Character level 1-60 caps the trees (spec 03).** `character_level()` is now the one player level
  (`LevelDisplay.player_level()`, fed by every skill XP grant). Before, it was the average of the tree levels.
  A tree cannot level past the character level. At the cap the XP bar fills and waits. `World.pioneer_changed`
  releases it. The occupation's Lv. 20 head start is exempt (ASSUMPTION). The cap can be switched off with
  `category_cap` in trees.json.
- **Lv1 AUTO nodes.** `"auto": true` nodes (0 SP) are learned once their level is reached: at creation, on
  level-up, on occupation, and on load. They cannot be refunded. Examples: Rope (Basic Processing), Stone Blade,
  Leaf, Branch, Bush, Fruit I, Log I, Bug I, Pebble, Mud I, Stalk, Bone I, Roll, Leaf Outfit, Footwraps, Leaf Hat,
  Corn and Apple Tree.
- **Animal Handling I-IV (spec 09).** These reuse the save ids `animal_management_1..4`. The values follow the
  spec: Survival 35/45/55/60, SP 4/5/5/6, chain I->II->III->IV, and I requires Capture Technique I ("Animal
  Taming"; ASSUMPTION). `SkillRules.bonded_capacity()` = 3 + one per learned node, up to 7.
  `SkillRules.can_bond(count)` blocks a new bond at the cap. A reset keeps existing pets.
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
  `sp_earned = paid_for_level(character level)` and `sp_available = max(0, sp_earned - cost of learned nodes at
  today's prices)`. They are recomputed on load, on every `World.pioneer_changed`, and for saves with no skills
  block. A saved `sp_earned` is never trusted.
- **Catalog.** `trees.json.reference` holds the spec-12 counts: 13 categories that sum to 918 nodes, plus the
  Toxic Oil Islands unlock list as an optional, defined-only entry. **212 of 918 nodes are imported: 18
  functional, 19 partial, 175 defined.** (Dry Leather moved from defined to functional in r2: it gates the
  existing `dried_hide` recipe.) Every node has `status`, `source` (spec09/11/12 or prd7), `effects` and
  `sp_assumed` where the pack gives no SP.
- **Skills sheet (hook H8; skills_sheet.gd is W1-UI's file, so the change lives in the hooks patch since r5):**
  node rows show the Durango name and "AUTO" in place of "0 SP". Owned auto nodes collapse into one "Learned
  automatically: Leaf, Branch, ..." line, and nodes the game reads nothing from yet into one "11 more nodes come
  with later updates" line, so a tree opens on rows the player can act on. A description that only repeats the
  node name is not shown. A refused refund shows its reason in red on the row.
- **Bonded cap on screen (hooks H9, H10):** at the cap the field-tame plate reads "Bonded roster full (3 / 3)"
  instead of "Tame", the feed is refused with the notice "... Animal Handling (Survival) adds slots." and the
  food is kept; the pets screen title reads "BONDED n / cap" (spec 09:50).

Files on the branch: `game/data/skills/trees.json`, `game/scripts/skills/skill_state.gd`, new
`game/scripts/skills/skill_rules.gd`, new `game/tests/t_w2_skills.gd`, `game/tests/t_save.gd`, new
`game/tests/fixtures/save_v3_skills_rev2.json`, and `game/scripts/world/taming_pen.gd` (orchestrator grant).
Everything else is in the hooks patch (H1-H10).
The rev-1 goldens `save_v3_golden.json` and `save_v3_away_golden.json` are byte-identical to the base.

## Review r5 findings (fixed in this round)

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
- **Unspent SP are kept** (r1 minor 1): what the character level does not cover becomes `sp_extra`, a one-time
  extra (spec 03:14 "award extra SP via appropriate one-time career tasks"). H6 caps `sp_extra` at what the
  save's own tree levels paid under the old award, so a forged save cannot mint SP.
- AUTO nodes are learned.
- Nothing is deleted.

r4 adds two optional fields with no rev bump: `refund_day` (the UTC day the counter belongs to, -1 when no
refund has happened) and `refunds_today`. A save without them loads with no refunds used; H6 makes both
numbers.

The rev-1 goldens are untouched inputs again (r1 major). t_save loads each one through SaveGame and
SaveSanitizer and compares the result with `save_v3_skills_rev2.json`, field for field in both directions.
`_test_rev1_skills` loads a rev-1 golden that bought 19 nodes under the old award (old prices, Survival 55),
then saves and loads it again. Both passes assert: levels kept, 0 reads Lv. 1, rev 2, the Lv1 AUTO nodes
learned, every bought node kept, the 539 unspent SP kept, the SP budget = character Lv. 5 + `sp_extra`, and
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

- **H1** `game/scripts/items/crafting.gd` `progression_block()`: check `SkillRules.recipe_block` first. This makes
  the recipe gates real. station_craft and craft_ui already route through `progression_block`.
- **H2** `game/scripts/core/data.gd` `bonded_cap()`: `SkillRules.bonded_capacity(PlayerRegistry.local().skills)`,
  or 3 with no player. This replaces "unlimited", per spec 09. It is the one bonded-cap function. It reaches
  field_tame.apply_feed, player_pets.bond_from_inventory and (on the branch) taming_pen. The market's caged-pet
  unpack should call it too.
- **H3** `game/scripts/server/character_state.gd`: a missing tree defaults to `SkillState.MIN_LEVEL`, not 0.
- **H4** `game/scripts/combat/hunt.gd` (melee and ranged) and `game/scripts/server/intent_handlers.gd` (melee):
  per-level damage and crit bonuses count from Lv. 1 (`level - SkillState.MIN_LEVEL`), so balance is unchanged.
- **H5** `game/scripts/dev/ui_family_lab.gd`: it asserted an unlimited roster. It now expects 3.
- **H7** `game/scripts/ui/craft_ui.gd` `_show_detail`: a gated recipe's detail shows what unlocks it, in red,
  above the ingredients.
- **H8** `game/scripts/ui/skills_sheet.gd` (W1-UI) `_build_tree`: Durango names, "AUTO", the learned-auto
  line, the not-in-game count line and the red refund refusal on its row.
- **H9** `game/scripts/pets/field_tame.gd` (W1-TAME): `roster_full(player)`; `plate_hint` shows it for the
  local survivor; `apply_feed` gives the notice before refusing.
- **H10** `game/scripts/ui/animal_screen.gd`: the title reads "ANIMALS · BONDED n / cap · GROWTH".
- **H6** `game/scripts/core/save_sanitizer.gd` `_skills(sv, pioneer_level)`:
  - The node-purchase budget is the SP the character level paid.
  - For a rev-1 save, the budget is what its tree levels paid under the old award, so the migration never drops
    a learned node.
  - `sp_available` is clamped to `max(0, character SP - spent)`.
  - The caller passes the clamped `pioneer_level`.
  - `rev` is written back as the number the sanitizer used (r5), so a hand-edited rev cannot split the two readers.
  - Known gap: a forged rev-1 save can keep nodes up to the old per-tree budget. It still gets 0 extra SP,
    because SkillState derives SP.

Wanted from other packages:
- W2-PROCESS reads `SkillRules.ability(sk, "handicraft" | "metal_processing")`. That turns Handicraft and
  Metalworking from partial to functional.
- (Done in H10: the pets screen shows "n / cap".) Other bond paths (the market's caged-pet unpack, W2-BREED's
  hatching) should call `Data.bonded_cap()` and `FieldTame.roster_full()` for the same text.

## Assumptions (`# ASSUMPTION` in code or data)

- The occupation's Lv. 20 is exempt from the character-level cap.
- XP over the cap is dropped once the bar is full.
- Animal Handling I requires Capture Technique I.
- SP values marked `sp_assumed`: Stealth II-V, Slaughter I-V, Barrage Damage I-III, Handicraft II-V,
  Metalworking I-IV, level 45/50/60 Processing nodes, the makeshift shovel/hoe and Standard Bow.
- The occupation's Lv. 20 grants no SP.
- A migrated save that is over budget keeps its nodes with 0 SP available.
- The refund day is a UTC calendar day; with no Warp Gems in the game, refunds past the free count are refused.

## Open owner decisions

1. ~~Source of SP~~. Decided: per character level, per spec 03. Implemented, with H6.
2. **The 918-node table is still missing (decided: keep the 212 nodes).** The source table (kghj76138.github.io/durango-homecoming-guide/en/skills.html) returned 404 on
   2026-10-20, and the Wayback Machine was offline. Only the nodes the pack names are imported; the counts are
   recorded. Supply the table (or another copy) to finish the import.
3. ~~The save rev 2 bump~~. Approved as built.
4. **Pacing: when does cured hide open?** Spec 11:34 puts Dry Leather at Processing Lv. 15, and this package
   gates the `dried_hide` recipe on it (H1). After W2-DATA lands, that holds the tent kit and every armour band
   (32 live recipes) until character Lv. 15. Options: keep it (spec value); have W2-DATA let the bed and the
   first armour band take uncut hide; or move the gate. Not a merge blocker: nothing is a dead end
   (canvas_tent_kit and log_shelter_kit give early shelter), and the value follows the spec. Docs searched first: spec 11 gives only the level, spec 03 says nothing about
   which recipes need cured hide, and docs/reference holds two screenshots (the skill categories and a gather
   radial), no node table.

## Left (not done)

- Research timers (spec 03 table).
- Career Guides.
- Attribute service.
- Server-side recipe gates and node purchases online: CharacterState keeps levels only (W3-SRVACT).
- Gathering, butchering and tailoring effects of the defined nodes, owned by W2-GATHER, W2-BUTCHER, W2-TAILOR,
  W2-ACTION and W2-CRAFT.
- Stealth Ability in the AI detection service.
- skills_lab still prints a level-1 gathering, because the cap holds it at character Lv. 1. The lab only
  prints and asserts nothing.

No labs to register. No dsc worker was used: the import was a single scripted transform, and per the owner's
2026-10-20 note dsc is off unless asked.
