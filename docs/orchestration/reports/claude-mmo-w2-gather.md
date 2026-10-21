# W2-GATHER report (claude/mmo-w2-gather)

## What shipped
- `game/data/loot_tables.json`:
  - `rare_trait`: the documented rare result. Each gathered item has a 5% chance of one green rare trait: world-design.md:55 "5% chance of a rare extra (green pip)", PRD:541 "Rare extra attributes = green pip, low chance". The six traits are spec 04:11's (Black Sheen, Low Vibration, Wide Serration, Narrow Hook, Split Easily, Vivid Inspiration). The keys are the ones INVUI's `inv_ui.json` lists as class `rare`, so INVUI's inspect panel draws them green and its slots get the rare corner mark.
  - `gather_rare`: finds, meaning a node's secondary materials (spec 12:38 "material drop tables"; 12:39 "a tree may yield leaf, branch, log, fruit, sap, or specialized material"). Each row is gated by the climates whose materials list it, and it never rolls on a node whose own harvest has that item. Rows: resin on tundra trees and logs, bone-pick-gated flint on temperate rock (W2-DATA's FlintNode gate), obsidian-pick-gated copper_ore on desert rock, pearl on coral, copper-pick-gated silver_ore on black iron. The home grassland has no finds.
  - Butcher part gates by knife tier and butcher count/rare scaling.
- `game/data/gather_rules.json`: role tool affinity (axe on trees, pick on rock, knife on bushes and plants), bare hands 1.35x slower, rare XP bonuses.
- `game/scripts/gather/`:
  - `LootTables` reads the data.
  - `LootRoller` is the pure roll math with an injected RNG: finds, the trait roll and the carcass.
  - `GatherService` picks the effective tool and the seconds and yield per unit. Its `after_unit` wears the helper tool, rolls a trait per item, rolls the finds and pays the rare XP. It also shows "+n Item" with green trait lines and gold find lines; a stack with a rare line lands with a pop and a flash. `stamp_traits`, `add_finds` and `wear_role_tool` are shared with the server.
  - `ButcherLoot` builds the carcass from butchering.json. Rare parts are announced only when the kill is in the survivor's view, and pay their XP at the take.
  - `GatherFeedback` draws the yield stack. It stays off the ring, other harvest nodes, pills, HUD text and zones, plates and the radial. Its nearest edge stays within 120 px of the ring on both axes. A tinted HUD notice says the rare results only when the stack cannot be drawn.
  - `GatherXp` is the one place this package pays bonus XP: `SkillState.add_xp`, or player XP when the survivor has no skill tree.
- `game/tests/t_gather.gd` (15 groups, 9 of them live on a real `player.tscn` survivor) and `--lab=gather_lab`.

## Hooks patch (integrator applies at merge)
`docs/orchestration/reports/claude-mmo-w2-gather-hooks.patch`, regenerated after the sync 3 base merge and `git apply --check` clean on claude/mmo-overhaul ddaab662 and on the branch head:
- `player_actions.gd`:
  - `_scaled_gather_seconds` and `_gather_yield_multiplier` call `GatherService.unit_seconds` and `GatherService.yield_multiplier`.
  - `GatherService.after_unit(p, gt, stack, gained)` runs after `gt.consume_unit()`. It now passes the landed stack, not its id.
  - New: `ButcherLoot.on_take(corpse, p)` in `loot()`, the radial corpse take, right after WATER's `WaterAccess.soil(p, &"butcher")`. Before this, only the chest screen's take paid rare part XP.
- `corpse.gd`:
  - `_roll_loot()` calls `ButcherLoot.roll_into(self, _owner)`.
  - `_on_take_from_loot()` calls `ButcherLoot.on_take(self, p)` when units moved.
- `hunt_hud.gd`:
  - The signature is `notice(text, tint := Color(0,0,0,0))`. A tinted notice is a rare result, drawn in its colour on ink.
  - `GatherFeedback` owns its life:
    - `stamp_notice` starts its clock at `NOTICE_T0`, so it lives as long as the yield stack it stands in for, and records when it was raised and the survivor's work target.
    - `notice_stale` drops it once the survivor works another node or opens the bag or a loot screen.
    - `hold_notice` lets it wait up to 2 s for room instead of being dropped.
- `intent_handlers.gd` (`act.gather`):
  - The yield multiplier comes from `GatherService.yield_multiplier_with`.
  - Then `wear_role_tool`, `stamp_traits` and `add_finds` run with the op's `rng`.
  - Finds count as minted. The result carries the new optional lists `rares` and `traits`.

Lab registration: `main.gd` loads `res://scenes/dev/<name>.tscn` for `--lab=<name>`, so `game/scenes/dev/gather_lab.tscn` is the registration. `run_all.gd` needs nothing.

## Sync 3 (2026-10-21): this run's findings, the base merge, gate lines
This run's findings are review round 2's, word for word. All of them were fixed in 0cbec77a..be67836a (next section, item by item). This run re-proved each one on the new head, merged the moved base and adapted to it:
- **Base merge** a8929fd8: claude/mmo-overhaul ddaab662 (W2-DATA, W2-SKILLS and WATER merged since 73527576). No conflicts on the branch.
- **Hooks patch regenerated.** WATER added `WaterAccess.soil(p, &"butcher")` where the `loot()` hunk lands; the hunk now sits after it. The patch's +/- lines are unchanged; only its context moved.
- **W2-DATA's ladder vs the finds.** W2-DATA gates FlintNode's flint behind a bone pick (`min_pick_tier {"flint": "bone"}`). The temperate-rock flint find had no gate, so a stone pick or bare hands could get flint a rung early. The row now has `"min_tool_tier": "bone"`. New t_gather check: no find's gate sits below the `min_pick_tier` any nature node sets for the same item (copper_ore is obsidian on both sides; silver_ore, pearl and resin have no node gate).
  - Without the gate: `[t_gather] FAIL rock/flint find gate 'none' is not below its nodes' min_pick_tier (bone)` and `[t_gather] FAIL flint never drops below the bone pick FlintNode needs (bare 0.0472, stone 0.0472)`.
- **Owner 2026-10-21 "make it flashy"** (STATUS: feedback moments, rare finds among them, get "light, motion and punch"). A yield stack with a rare line (green trait or gold find) now starts at 1.35x scale and 1.8x brightness, then eases back to normal over 0.28 s (TRANS_BACK) and 0.45 s. It is a tween, so it never snaps. Plain "+n Item" stacks do not pop.
  - Check: `[t_gather] rare punch: scale 1.35 -> 1.00, flash 1.80 -> 1.00, plain pops false`. Without the pop: `[t_gather] FAIL a rare stack pops and flashes, then eases to normal; a plain one does not (scale 1.00 -> 1.00, flash 1.00 -> 1.00, plain false)`.
  - The motion gate (STATUS 2026-10-21, "glitchy movement of UI") still has one known jump: when a HUD block moves onto a drawn stack, the stack moves off in one frame (`follow` in gather_feedback.gd). It was built that way so the stack never sits under a banner. Reviewers measuring frame sequences will see that one move.
- W2-SKILLS changed yields. The live finish_gather case now lands 6 fibre per unit at the home bush, not 1. Its XP check still holds: `finish_gather on a home bush (trait odds forced to 1): fibre 6, traited 6, gathering XP 62.0, knife 40 -> 39` is 2 + 10 per rare item.

### Gate lines (sync 3: scratch trees `w2g6` and `w2g6g` = 1610c3ed + the hooks patch)
Each line below was seen in its run log:
- `--import` (mkscratch, both trees): 0 `SCRIPT ERROR` / `Failed to compile` lines in `.import.log`.
- Every `game/tests/t_*.gd` (23 files now) exited rc=0 with 0 SCRIPT ERROR, except t_save, which prints its 5 deliberate ones, as on base:
  - `[t_ai] PASS`, `[t_build] PASS`, `[t_canim] PASS`, `[t_combat] PASS`, `[t_data] PASS items=223 recipes=155`, `[t_gather] PASS`, `[t_harbour] PASS islands=15`, `[t_iconart] PASS`, `[t_items] PASS`.
  - `[t_light] PASS` (t_light and t_lighting both print it), `[t_occlude] PASS`, `[t_player] PASS`, `[t_save] PASS`, `[t_server_domain] PASS`, `[t_srvdom] PASS`, `[t_structart] PASS`, `[t_tame] PASS`, `[t_ui] PASS`.
  - `[t_uiicons] PASS ids=177 ...`, `[t_w2_skills] PASS`, `[t_water] PASS`, `[t_web] PASS`.
- `--script res://tests/run_all.gd`: `[tests] PASS`. `tools/smoke.sh --no-import` (through gslot): `SMOKE PASS`.
- `--lab=gather_lab` headless: `[gather_lab] PASS`, 0 SCRIPT ERROR.
- Windowed, one at a time on a quiet slot: `[gather_lab] PASS` with 0 SCRIPT ERROR on gl_compatibility 1600x900, Forward+ 1600x900, gl_compatibility 844x390 and Forward+ 844x390. Last round's two load flakes did not recur.
- 0 "couldn't resolve track" in every gate and lab log. No new `~/Library/Logs/DiagnosticReports/Godot-*.ips` (the newest is still Godot-2026-10-20-232613.ips, from before this run).
- Mutation suite on 1610c3ed (scratchpad `w2g6m/mutate.py`, round 2's 18 mutations of package and hook code plus `Mflint_gate` and `Mpunch_none`; output `w2g6m/mutate.out`): all 20 exit rc=1. The reviewer's acceptance lines, on the new head:
  - M-a (GatherXp fallback off): `[t_gather] FAIL finish_gather pays 2 + 10 per rare item into Gathering (got 2.0, want 62.0)`, plus `FAIL the talon pays its 8 XP once, at the take (got 0.0)` and both take-path XP checks.
  - M-c (corpse hook -> `pass`): `[t_gather] FAIL the chest-screen take (_on_take_from_loot) pays 3 + 8 for the talon (got 3.0)`.
  - M-c2 (actions loot hook -> `pass`): `[t_gather] FAIL the radial take (PlayerActions.loot) pays 3 + 8 for the talon (got 3.0)`.
  - Own-yield filter removed: `[t_gather] FAIL no find is the node's own yield (["PineTree/tundra/resin", ...])`.
  - Helper wear removed: `[t_gather] FAIL a knife helping on a bush wears 1 per unit, a required one is not worn twice (40 -> 40)`.
  - The other 13 print the lines quoted in round 2 below, with the new counts (for example `(0 of 4)` traited).

### Screenshots looked at (scratchpad `w2g6/shots`, not in the repo)
- **1600x900 gl_compatibility `-rare`:** a green "Low Vibration Fibre Stalk" over a cream "+3 Fibre Stalk", left of the ring hex. It is clear of the Bush, Bush Berries, Common Tree and Rock pills and of the raptor. The shot is taken 0.35 s after the unit, so the pop has already eased back to normal size.
- **1600x900 Forward+ `-rare_radial`:** the same stack in the same place, clear of every pill.
- **844x390 gl_compatibility `-rare`:** the stack is skipped (`yield stack skipped: no free spot by the node`), and the green notice "Rare trait: Low Vibration Fibre Stalk" on ink sits under "Survivor".
- **844x390 gl_compatibility `-butcher`:** loot toasts on the left. No rare notice is left over from the gathers.
- **844x390 gl_compatibility `-tools`:** "+2 Log" is down-left of the work-axe ring and clear of the Bush, Bush Berries and Rock pills.
- **Not this package, still seen (W1-UI):**
  - At 844x390 the level-up banner pushes the pet plate onto the Bush pill.
  - The "Loot · Velociraptor" label crosses the "Survivor" nameplate in the butcher shot.

## Review round 2 (2026-10-20 night): findings, fixes, checks
Each mutation ran the full t_gather against the mutated file (scratchpad `w2g5/mutate.py`, logs `w2g5/mut/`). Each one exited rc=1 with the quoted line. The unmutated run prints `[t_gather] PASS`.

1. **Major: the docs set gathering rarity, and home finds were the nodes' own yield.**
   - Fixed. The documented rare result is now in: `rare_trait` (5% per item, one of spec 04:11's six green traits) on every gathered material, home included.
   - The ASSUMPTION text in `loot_tables.json` now quotes world-design.md:55 and PRD:541 instead of saying the PRDs give no odds.
   - Finds stay as secondary materials, citing spec 12:38-39. Two changes:
     - `roll_gather_rares` skips any row whose item is in the node's own `harvest` (PineTree's resin, FlintNode's flint, CopperOreNode's copper).
     - The bush, plant and ground rows (berries, herb_leaf) are deleted. Every home material is some home node's own yield, so home grassland rolls no finds.
   - Checks: "the rare trait chance is world-design.md:55's 5%", "the green traits are spec 04:11's six", a 4000-item rate test (`rare trait rate 0.0465`), "no find is the node's own yield" (every family x every climate), and "the home grassland rolls no finds".
   - Old data: `[t_gather] FAIL the home grassland rolls no finds (["Bush/berries", ...])`. Filter removed: `[t_gather] FAIL no find is the node's own yield (["PineTree/tundra/resin", ...])`.
2. **Major: nothing tested GatherXp's live path.**
   - Removed the sink (see 9). A new live case calls `PlayerActions.finish_gather` on a real survivor at a home bush, with the trait odds forced to 1.
   - Result: `finish_gather on a home bush (trait odds forced to 1): fibre 1, traited 1, gathering XP 12.0, knife 40 -> 39`. That is 2 + 10 per rare item.
   - M-a (`if player.skills:` -> `if false:`): `[t_gather] FAIL finish_gather pays 2 + 10 per rare item into Gathering (got 2.0, want 22.0)`, plus the three butcher XP checks.
   - Hook removed from finish_gather: `[t_gather] FAIL every gathered item took a trait with the odds forced to 1 (0 of 2)` and `FAIL the helper knife wore once for the unit (40 -> 40)`.
3. **Major: the corpse hook was untested.**
   - New live case: a real velociraptor is spawned and killed, so `Creature._on_died` -> `Corpse.setup` -> `_roll_loot` -> `roll_into` all run. Its talon is forced through the data.
   - The test then found a real gap: the radial take, `PlayerActions.loot`, never reached `ButcherLoot.on_take`, so a talon taken from the radial paid no rare XP. The new hooks hunk fixes that.
   - Both take paths are now tested: `PlayerActions.loot talon: moved 1, butchering XP 11.0` and `Corpse.take_slot talon: raptor_talon, butchering XP 11.0` (3 + 8).
   - M-c (corpse hook -> `pass`): `[t_gather] FAIL the chest-screen take (_on_take_from_loot) pays 3 + 8 for the talon (got 3.0)`. M-c2 (actions hook -> `pass`): `[t_gather] FAIL the radial take (PlayerActions.loot) pays 3 + 8 for the talon (got 3.0)`.
4. **Major: helper tools never wore.**
   - `GatherService.wear_role_tool` wears the exact stack `effective_tool` used (best pick on loose stone, knife on a bush), with `Inventory.wear_gather_tool`'s cost: 1 for a work tool, 3 for a weapon.
   - It only runs when the node requires no tool. A required tool is already worn in PlayerActions and is not worn twice.
   - It runs from `after_unit` on the client and from `act.gather` on the server. gather_lab also checks the knife wears on the bush.
   - M-w: `[t_gather] FAIL a knife helping on a bush wears 1 per unit, a required one is not worn twice (40 -> 40)` and `FAIL the helper knife wore once for the unit (40 -> 40)`.
5. **Minor: a stack sat on another node at 844x390.**
   - Other harvest nodes within 16 m are now taken rects, covering their base to their anchor height, grown 28 px (`GatherFeedback.node_rects`).
   - A spot is refused when its nearest edge is more than MAX_SHIFT from the ring on either axis.
   - Checks: a second rock placed where the stack would rise sends it beside the ring (`gap (44.0, 0.0), on the other rock false`). A column slid 100 px ends 144 px off and is refused.
   - M-n: `[t_gather] FAIL the stack keeps off the other rock ([P: (979.7, 741.5), S: (92.0, 46.0)])`. M-gap: `[t_gather] FAIL a spot whose nearest edge ends past MAX_SHIFT from the ring is refused`.
6. **Minor: kills nobody saw were announced.**
   - `roll_into` announces only when the carcass is on the survivor's screen (`ButcherLoot.in_view`). Otherwise it rolls silently.
   - There is no stored killer to credit: Health emits its source only once, and creature.gd is another package's file. View covers both "the survivor's kill" and "in reach".
   - M-v: `[t_gather] FAIL a kill out of view rolls its talon silently (notices [["Rare find: Raptor Talon on the velociraptor", ...]])`.
   - The knife used is still the local survivor's: single-player ASSUMPTION, kept.
7. **Minor: a misspelt tier was read as stone.**
   - t_gather asserts that every `min_tool_tier` and `part_min_tier` is in `ProgressionScaling.TOOL_TIERS`.
   - The roller now skips an unknown-tier find row, and keeps a part with an unknown gate on the carcass.
   - M-t: `[t_gather] FAIL bad rows and a misspelt tier are skipped, the good rows still roll (104 of 200 seeds differ)`. M-gt: `[t_gather] FAIL a misspelt part_min_tier keeps the scute on the carcass`.
8. **Minor: colour language, and the dropped fallback notice.**
   - Traits are green (spec 13:50/291, PRD:541). They use `GatherFeedback.GREEN` = INVUI's `InvTheme.RARE` #67B84E, in the yield stack and in the fallback notice "Rare trait: Black Sheen Fibre Stalk".
   - Finds stay gold, as the package scope said ("announced in gold"). A find is a material, not an attribute, so spec 13's "green rare attributes" does not cover it. **Question for the orchestrator:** keep finds gold, or make every rare result green. It is one constant either way.
   - The HUD now holds a tinted notice while there is no room, instead of dropping it. That hold is draw-only code in hunt_hud, so there is no headless check; it was read and seen in the lab.
9. **Minor: the sink only saw bonus XP.**
   - Removed `GatherXp.set_sink`. W2-SKILLS (`5e77eb8c`) never calls it and keeps `SkillState.add_xp` as the door.
   - `GatherXp.award(player, category, amount)` pays this package's bonus XP the same way the base +2/+3 is paid. A check covers it without a skill tree (player XP).
10. **Minor: an old gold notice lingered into the butcher stage, and banners pushed the plate.**
    - Both of the reviewer's fixes are in. The notice's life is tied to the stack's: it starts at `NOTICE_T0` = 1.0 s into the HUD's 3.2 s life, stays full for the yield stack's LIFE (1.4 s), then fades.
    - The notice also goes as soon as the survivor works another node or a bag/loot screen opens over it.
    - With no room it waits at most 2 s (`NOTICE_WAIT_MS`), so the hold from item 8 cannot keep it alive into a later scene.
    - The first 844x390 rerun showed exactly that bug: with an unbounded hold, the gather's green notice still sat beside the raptor carcass in the butcher shot. The final shots have no rare notice in the butcher stage at either renderer.
    - Checks on the real `hunt_hud.gd`, plus a real survivor for the target change: after LIFE + 0.9 s the rare notice is gone and a plain one stays; with no room a fresh rare notice waits and a stale one ages; the notice goes when the survivor works another node or a loot screen opens.
    - Mutation lines:
      - MT0: `[t_gather] FAIL after the stack's life the rare notice is gone, a plain one stays (["Rare find: Flint", "Too far."])`.
      - Mstale (check off): `[t_gather] FAIL a rare notice goes when the survivor works another node, not before (same false, moved false, plain false)`.
      - Mscreen: `[t_gather] FAIL a rare notice goes when a bag or loot screen opens (closed false, open false)`.
      - Mhold unbounded: `[t_gather] FAIL with no room a fresh rare notice waits, a stale or plain one ages (1.0 1.0 1.8)`.
    - Home berries no longer exist, so the lab's rare stage is now a trait.
    - **For W1-UI:** at 844x390 the level-up banner pushes the pet plate down onto the nearest node pill and its text (creature_plates). This package's bonus XP makes that level-up more likely. It does not cause the overlap.
11. **Other checks added:**
    - A full bag keeps a hit item plain and whole: `with no free slot the item stays plain and whole`. With the revert removed: `[t_gather] FAIL ... (stamped [], stone 4)`.
    - A trait swap keeps every unit (4000 of 4000), and an item carries at most one trait.
    - Traits removed from after_unit: `[t_gather] FAIL every gathered item took a trait with the odds forced to 1 (0 of 5)`.

## Round 2 gate lines (scratch trees `w2g5` and `w2g5g` = 0cbec77a + the hooks patch), superseded by sync 3 above
Final code commit be67836a. The branch tip merges claude/mmo-overhaul 73527576, which changed docs only (`git diff be67836a HEAD -- game` is empty). The hooks patch is `git apply --check` clean there. Each line below was seen in the run log:
- `--import` (mkscratch, both trees): 0 `SCRIPT ERROR` / `Failed to compile` lines in `.import.log`.
- Every `game/tests/t_*.gd` exited rc=0 with 0 SCRIPT ERROR, except t_save, which prints its 5 deliberate ones, as on base. `[t_ai] PASS`, `[t_build] PASS`, `[t_canim] PASS`, `[t_combat] PASS`, `[t_gather] PASS`, `[t_harbour] PASS islands=15`, `[t_iconart] PASS`, `[t_items] PASS`, `[t_light] PASS` (both t_light and t_lighting print this), `[t_occlude] PASS`, `[t_player] PASS`, `[t_save] PASS`, `[t_server_domain] PASS`, `[t_srvdom] PASS`, `[t_structart] PASS`, `[t_tame] PASS`, `[t_ui] PASS`, `[t_uiicons] PASS ids=169 ...`, `[t_web] PASS`.
- `--script res://tests/run_all.gd`: `[tests] PASS`.
- `tools/smoke.sh --no-import` (through gslot): `SMOKE PASS`.
- `--lab=gather_lab` headless: `[gather_lab] PASS`, 0 SCRIPT ERROR.
- Windowed `[gather_lab] PASS` with 0 SCRIPT ERROR on all four configs: gl_compatibility 1600x900, Forward+ 1600x900, gl_compatibility 844x390 and Forward+ 844x390.
- **Flake:** in the last round two windowed runs failed while the full test suite ran beside them on the same machine:
  - gl_compatibility 1600x900: `FAIL gathered 0/2 stone`. The survivor re-pathed to the rock (`[path] len=2` repeating) for 30 s.
  - Forward+ 844x390: `FAIL branch is faster with the stone tool (2.46 < 2.16)`. That is a wall-clock timing compare.
  - Both passed when rerun alone (`glc 1600x900 rc=0 [gather_lab] PASS`, `fwd 844x390 rc=0 [gather_lab] PASS`), and the three earlier rounds of all four configs passed.
  - The path loop is PlayerActions/navigation, not this package. Reviewers should run the windowed lab on a quiet machine.
- 0 "couldn't resolve track" in every gate and lab log. No new `~/Library/Logs/DiagnosticReports/Godot-*.ips` (directory listing compared with the one taken before the first run).
- Mutation suite on be67836a (scratchpad `w2g5/mutate.py`, 18 mutations of package and hook code, output `w2g5/mutate_be67.out`): every one exits rc=1 with the lines quoted above.

## Round 2 screenshots looked at (scratchpad `w2g5/shots2`, not in the repo)
Final runs are `w2g5/shots6` and `w2g5/shots6b`; `shots3` to `shots5` are the earlier rounds of this pass.
- **1600x900 gl_compatibility `-rare`:**
  - A green "Low Vibration Fibre Stalk" sits over a cream "+3 Fibre Stalk", left of the ring hex.
  - It is clear of the Bush pill, the raptor and its plate, and the Common Tree and Rock pills. It reads on the grass thanks to the dark outline.
  - The HUD toast "+3 Fibre Stalk" is at top centre. No notice is shown, because the stack was drawn.
- **1600x900 Forward+ `-rare_radial`:** the same stack, above the bush and under the toast. The level-up stat list is on the left, clear of it.
- **1600x900 `-tools`:** "+1 Log" sits right of the ring hex, clear of the Common Tree and Rock pills and of the rock itself.
- **844x390 `-rare` and `-rare_radial`, both renderers:**
  - The stack is skipped: the gather hexes, pills and orders leave no free spot within 120 px.
  - The green notice "Rare trait: Low Vibration Fibre Stalk" on ink says it, under "Survivor", and the "+3 Fibre Stalk" toast is on the left.
  - In the gl_compatibility radial shot of the loaded run, the notice had already gone: an autosave stall happened between the check and the capture.
- **844x390 `-butcher`, both renderers:** loot toasts on the left and the "Loot · Velociraptor" label. No rare notice is left from the gathers; before the notice fixes, two green ones were there.
- **844x390 `-tools`:** "+2 Log" sits beside the work-axe hex, clear of the Bush, Bush Berries, Common Tree and Rock pills.
- **Not this package (W1-UI / INVUI):**
  - The 844x390 level-up banner lies over the orders panel.
  - `-loot_screen` still draws the minimap, pills, HUD hexes and the nameplate over the open loot grid.
  - The pet plate/pill overlap is noted in item 10.

## Review round 1 (2026-10-20 evening), kept for the record
The climate filter, the per-row climate materials check, the live after_unit and full-bag cases, the butcher knife hook, two finds in one frame, the gold fallback notice, rare part XP at the take, finds stamped with climate and level, the server act.gather hunk, and the bad-row guards. The quoted mutation lines are in git history (5c1f1c40). Superseded since then:
- The berries and herb_leaf home rows (item 1 above).
- The GatherXp sink and its quit-crash test (item 9).
- `notice(text, gold)` (item 8).

## Assumptions
- Finds are illustrative odds in loot_tables.json, about one per 20-30 passes. The docs give no numbers for secondary materials. The 5% trait chance is the docs' number.
- Which of the six green traits a material gets is not in the docs, so each is equally likely. Tool tier does not raise the 5%.
- A find does not roll a trait of its own: it is already the rare result of its pass. Carcass parts roll no traits yet; that is W2-BUTCHER's, spec 12:74.
- A traited item swaps into a free slot. With no free slot it stays plain and is never lost.
- An unlocked rare carcass part still rolls its chance (default 0.12), standing in for spec 12 s2's Slaughter Ability roll until W2-BUTCHER. Knife tier stands in for the Butchering part nodes.
- A rare part pays its butchering XP when the last of it is taken, to the taker. The carcass rolls at death for the local survivor's best knife and Butchering level (single player; W3 rolls for the credited killer).
- Kills out of the survivor's view roll silently.
- Bare hands are 1.35x slower than the role's tool. A helper tool wears at Inventory.wear_gather_tool's cost.
- A find needs at least the pick tier a nature node needs for the same item (W2-DATA's ladder), so the flint find needs a bone pick.
- The rare pop's size, brightness and timing (1.35x, 1.8x, 0.28 s) are picked by eye; the owner's "make it flashy" gives no numbers.
- gather_lab hands over the starter tools and picks the seed so the next fibre item rolls a trait. The odds themselves are proven in t_gather.

## What the next agent needs
1. **ECON:** `game/data/economy/limits.json` `attributes` is a whitelist ("Anything else is refused at deposit"). It must list the six trait keys as `bool`, or a traited material cannot be deposited or sold. This is ECON's file, so it is not in this patch.
2. **W2-INV, the sync step:** `stamp_traits` finds the landed unit by `can_merge_with`. With instances (uids, no stacking) that finds nothing, so no trait lands. Stamp the trait on the instance instead. `add_finds` should mint each find with a uid.
3. **W2-BUTCHER / W2-SKILLS:**
   - Per-part Butchering nodes and per-part take refusal.
   - The Slaughter, Mining and Plant Gathering abilities.
   - Flawless and mistake results.
   - Rare traits on carcass parts (spec 12 s1-2, 12:74).
4. **W3-SRVACT:** server nodes need their island climate in `attributes` (WorldFacade.add_node sets only level) before any find can roll there. Traits and helper wear already roll there.
5. **W2-DATA:** review the find items' rarity once it lives in items.json. resin and flint are common/uncommon in item_rarity.json.
6. **GATHERUI** (queued after this merge; STATUS says the hex time "is static and will be wrong after W2-GATHER"): read `GatherService.unit_seconds(p, node)` and `GatherService.yield_multiplier(p, node)` for the hex's time and yield. They are what finish_gather uses.
7. **Not done:** no web export check, and no frame-sequence capture of the rare pop (the motion gate). The pop is a tween from 1.35x to 1x; t_gather checks its start and end values.
