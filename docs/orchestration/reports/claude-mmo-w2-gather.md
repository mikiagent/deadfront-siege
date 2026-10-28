# W2-GATHER report (claude/mmo-w2-gather)

## What shipped (state at the head of review round 4)
- `game/data/loot_tables.json`:
  - `rare_trait`: the documented rare result. Each gathered item has a 5% chance of one green rare trait: world-design.md:55 "5% chance of a rare extra (green pip)", PRD:541 "Rare extra attributes = green pip, low chance". The six traits are spec 04:11's (Black Sheen, Low Vibration, Wide Serration, Narrow Hook, Split Easily, Vivid Inspiration). The keys are the ones INVUI's `inv_ui.json` lists as class `rare`, so INVUI's inspect panel draws them green and its slots get the rare corner mark.
  - `gather_rare`: finds, meaning a node's secondary materials (spec 12:38 "material drop tables"; 12:39 "a tree may yield leaf, branch, log, fruit, sap, or specialized material"). Each row is gated by the climates whose materials list it, and it never rolls on a node whose own harvest has that item. Rows:
    - resin on tundra trees (PineTree_Snow) and tundra logs (WoodLog_Snow);
    - bone-pick-gated flint on temperate rock (Rock, Rock_Moss, GraniteBoulder, TinOreNode; W2-DATA's FlintNode gate);
    - obsidian-pick-gated copper_ore on desert rock (Rock, SaltNode, SandstoneNode);
    - copper-pick-gated silver_ore on snowfield rock (Rock_Snow, IceNode);
    - pearl on coral (CoralNode, blue_tropical).
    - The home grassland has no finds.
  - **Dormant rows:** no island in islands.json is snowfield or blue_tropical yet, so the silver_ore and pearl rows cannot roll in the shipped world until those islands exist. t_gather checks every row has a family that grows in one of its climates and does not yield the item itself.
  - `butcher`: part gates by knife tier, the rare part chance, and the part counts. Each knife tier above stone adds 15% to the base parts and each Butchering level 1% (`count_bonus_per_tier`, `count_bonus_per_skill_level`); a carcass cut with no knife gives 0.75x (`no_knife_count_mult`). All three are ASSUMPTIONs, noted in the data.
- `game/data/gather_rules.json`: role tool affinity (axe on trees, pick on rock, knife on bushes and plants) and bare hands 1.35x slower. **No XP:** rare results pay no bonus XP since round 4 (below).
- `game/scripts/gather/`:
  - `LootTables` reads the data.
  - `LootRoller` is the pure roll math with an injected RNG: finds, the trait roll and the carcass.
  - `GatherService` picks the effective tool and the seconds and yield per unit. Its `after_unit` wears the helper tool (`Inventory.wear_tool`), rolls a trait per item, rolls the finds (level downranked like the main yield) and shows the yield stack. `stamp_traits`, `add_finds` and `wear_role_tool` are shared with the server.
  - `ButcherLoot.roll_into` builds the carcass from butchering.json. Rare parts are announced in gold only when the kill is in the survivor's view. Taking them pays the base Butchering XP only.
  - `GatherFeedback` draws the yield stack:
    - "+n Item" with green trait lines and gold find lines. A stack with a rare line lands with a pop and a flash that ease back.
    - It keeps off the ring, other harvest nodes, the survivor and their ring, pills, HUD text and zones, plates and the radial. Its nearest edge stays within 120 px of the ring on both axes.
    - It never jumps or vanishes between frames. When something lands on it, or a newer stack replaces it, it fades out where it is over 0.15 s (`LEAVE_S`).
    - On a landscape phone (844x390) a rare result is one slim line, the trait alone at 18 px ("Low Vibration"; the HUD toast says "+n Item"). It is placed above the ring, beside it, or under the ring and the survivor. A plain "+n Item" shows only above the ring; anywhere else it read as the next node's yield, and the toast already says it.
  - The HUD rare notice: a tinted notice says a rare result only when its stack cannot be drawn. On a phone that means the gather radial is open, which leaves no spot by the node.
    - `notice_box` places it off the HUD's blocks, the open radial's labels, title and hexes, the creature plates and the survivor with their ring. It goes to the left or right edge when the centre column is full. Once drawn it keeps that side, clamped on screen.
    - It lands with the stack's pop and flash (`notice_punch`), in its tint on ink (`notice_colors`).
    - `tick_notices` runs from the HUD's `_process`, so its life never depends on drawing. It drops a notice once the survivor works another node or opens the bag or a loot screen, holds one with no room for up to 2 s, and records its side.
    - A repeat reads "x2" in the same notice.
- `game/tests/t_gather.gd` (17 groups: 5 on data and roll math, 12 in a live scene with a real `player.tscn` survivor, the real `hunt_hud.gd` and the server's act.gather) and `--lab=gather_lab`. The lab also samples a drawn rare notice's pixels and follows each rare stack frame by frame.

## Hooks patch (integrator applies at merge)
`docs/orchestration/reports/claude-mmo-w2-gather-hooks.patch`, regenerated in review round 4 after merging claude/mmo-overhaul acc684a6 (W2-DATA sync, docs only). `git apply --check` is clean on acc684a6 (checked against a temporary index read from that tree) and the patch applies cleanly in the round 4 scratch trees. Five files:
- `player_actions.gd`:
  - `_scaled_gather_seconds` and `_gather_yield_multiplier` call `GatherService.unit_seconds` and `GatherService.yield_multiplier`.
  - `GatherService.after_unit(p, gt, stack, gained)` runs after `gt.consume_unit()`.
  - Round 4: the `ButcherLoot.on_take` line in `loot()` is gone, because no rare XP is paid.
- `corpse.gd`: `_roll_loot()` calls `ButcherLoot.roll_into(self, _owner)`. Round 4: the `_on_take_from_loot` hunk is gone.
- `hunt_hud.gd`:
  - `notice(text, tint := Color(0,0,0,0))`. A tinted notice is a rare result: `GatherFeedback.add_notice` adds it (a repeat counts up, "x2").
  - `_process` calls `GatherFeedback.tick_notices(_events.notices, player, drawn_blocks)` before `_events.tick` (round 4: the notice's state moved off `_draw`).
  - `_draw` places a tinted notice with `GatherFeedback.notice_box` instead of `UiTokens.free_spot`. It draws it scaled by `notice_punch` and coloured by `notice_colors`. Plain notices are unchanged.
- `intent_handlers.gd` (`act.gather`): the yield multiplier comes from `GatherService.yield_multiplier_with`; then `wear_role_tool`, `stamp_traits` and `add_finds` run with the op's `rng`. Finds count as minted; the result carries the new optional lists `rares` and `traits`.
- `inventory.gd` (round 4, W2-INV's file): `wear_gather_tool` now calls a new `wear_tool(s)`, which holds the cost rule (1 for a work tool, 3 for a weapon) and the "broke" print. `GatherService.wear_role_tool` calls `wear_tool` on the exact stack its role picked (the best pick on rock), instead of keeping its own copy of the rule.

Lab registration: `main.gd` loads `res://scenes/dev/<name>.tscn` for `--lab=<name>`, so `--lab=gather_lab` runs today. `tools/labs.txt` does not exist on claude/mmo-overhaul yet; see "What the next agent needs" 7.

## Review round 4 (2026-10-21): findings, fixes, checks
Code commits 4cad106f..b530bebf on top of the base merge 27ab0c5a (claude/mmo-overhaul acc684a6). Every new check was run against a mutation of the code it guards (scratchpad `w2g7/mutate.py`, logs `w2g7/mut/`). The FAIL line each mutation printed is quoted below; the unmutated tree prints `[t_gather] PASS`.

1. **Major: the rare bonus XP was invented.** Dropped. Spec 03 awards XP for completed activities and says to scale it against difficulty; a lucky roll is not difficulty, and no doc pays XP for a rare result. XP pacing stays with W2-SKILLS: the base +2 Gathering and +3 Butchering that PlayerActions pays are the whole award.
   - Removed: `gather_rules.json` `xp`, the XP loop in `after_unit`, `GatherXp` (its only callers were these bonuses), `ButcherLoot.on_take` and its two hook hunks.
   - Checks: the live finish_gather with every item traited pays exactly 2 (`finish_gather on a home bush (trait odds forced to 1): fibre 4, traited 4, gathering XP 2.0`). Both talon take paths pay exactly 3 (`PlayerActions.loot talon: moved 1, butchering XP 3.0`, `Corpse.take_slot talon: raptor_talon, butchering XP 3.0`).
   - Mutation (the old gather bonus put back): `[t_gather] FAIL finish_gather pays only the base 2 Gathering XP, however many items are traited (got 32.0)`. The old butcher bonus put back in `loot()`: `[t_gather] FAIL the radial take (PlayerActions.loot) of the talon pays only the base 3 (got 11.0)`.
2. **Major: on a phone every rare result fell back to the static notice.** At 844x390 the HUD's top band (112 px) sits right above the ring, and each side has about 140 px before the pet row, the rail rows or the right column. The two-line stack fit nowhere. Even shortened to "Low Vibration" over "+1 Fibre Stalk" it measured 154x74 px, and the free spot under the ring, between the neighbouring tree and rock, was 144 px wide. Measured with a temporary dump of each candidate column in the lab.
   - A phone's rare stack is now one slim line: the trait alone ("Low Vibration") at 18 px with 6 px ink margins, 133x38 px. A find stays "RARE  Flint". There is no "+n" line, since the HUD toast beside it says "+2 Fibre Stalk".
   - A rare stack may also go under the ring. Stacks now keep off the survivor and their ground ring (`survivor_rect`), so under the ring means under the survivor.
   - With the radial open, a phone has no spot by the node at all (its hexes and labels fill the space under and right of the ring). The same goes for a trait rolled at a tall tree, whose ring sits high, near the top band (lab, hands stage: `popup skipped over CommonTree (no room by the node); HUD toast true, rare notice true`). There the notice is the rare show, and it now lands with the same pop and flash (`notice_punch`, drawn by the HUD hunk with `draw_set_transform`).
   - Lab, gl_compatibility 844x390 (`w2g7/labs2`): `[gather_lab] popup ["Low Vibration"] at [P: (344.9669, 260.1619), S: (133.0, 38.0)]`, and the rare stage's skip is gone. Forward+ 844x390 draws it at the same spot. A new lab check fails when a phone with the radial closed skips a rare stack.
   - t_gather, both sides taken as on a phone: `844x390, ring at (420.0, 150.0): plain stack drawn false; rare stack ["Low Vibration"] at [P: (353.5, 225.3878), S: (133.0, 38.0)], rare line 18 px` (under the ring at y 150: the stack is caught mid-rise at y 225; it rises to y 194, RING_CLEAR = 44 px under the ring).
   - Mutations:
     - Under-ring column removed: `[t_gather] FAIL with the sides taken a phone's rare stack is drawn under the ring, within reach of it ([P: (0.0, 0.0), S: (0.0, 0.0)], gap (420.0, 150.0))`
     - Old two-line text: `[t_gather] FAIL with the sides taken a phone's rare stack is drawn under the ring, within reach of it ([P: (0.0, 0.0), S: (0.0, 0.0)], gap (420.0, 150.0))`
     - Old font: `[t_gather] FAIL a phone's rare stack is one slim line, the trait alone (["Low Vibration"], 24 px, 172 px wide)`
     - The "+n" line back: `[t_gather] FAIL a phone's rare stack is one slim line, the trait alone (["Low Vibration", "+1 Fibre Stalk"], 18 px, 133 px wide)`
     - Survivor not kept clear: `[t_gather] FAIL a yield stack keeps off the survivor and their ring ([P: (751.5345, 612.6954), S: (96.93091, 187.1974)])`
     - Notice pop off: `[t_gather] FAIL a rare notice pops and flashes, then eases to normal ((1.0, 1.0) -> (1.0, 1.0))`
3. **Major: the report was stale.** Rewritten: "What shipped", the hooks list, the assumptions and the next-agent list describe the head. There is a review 3 section below, and the gate lines are for the round 4 head. Silver is on snowfield rock.
4. **Major: the owner's motion gate.**
   - A stack that something lands on no longer moves to another column in one frame, and is never hidden. It fades out where it is over `LEAVE_S` = 0.15 s (`_leave`). If it had been on screen for under 0.5 s, its rare line goes to the HUD notice.
   - A newer stack replaces the last one the same way, instead of `queue_free` between frames.
   - A rare notice keeps the side it was first drawn on while it lives (`tick_notices` records it). A repeat ("x2") of a notice that is off screen is placed afresh, so no hop is seen. A locked side is clamped on screen: in one phone run, "x2" made the text grow 20 px past the right edge.
   - t_gather puts a HUD block on a drawn stack and measures every frame: `HUD block on a drawn stack: largest per-frame move beyond the rise 0.0 px, hidden false, label alpha down to 0.05, gone after 0.16 s`.
   - The windowed lab follows each rare stack through its life on real frames, relative to its anchor: gl_compatibility 1600x900 `motion: 105 stack frames watched, worst move beyond the rise 0.0 px, slowest frame 658 ms`; Forward+ 1600x900 157 frames, 0.0 px; gl_compatibility 844x390 53 frames, 0.0 px; Forward+ 844x390 55 frames, 0.0 px.
   - Mutations:
     - The reviewer's M35 (no hit check): `[t_gather] FAIL a stack something landed on fades out where it is within LEAVE_S (gone after 1.39 s, alpha down to 1.00)`.
     - The old jump to another column: `[t_gather] FAIL a HUD block on a drawn stack never makes it jump or vanish between frames (moved 88.6 px past its rise, hidden false)`.
     - The old hide: `... (moved 0.0 px past its rise, hidden true)`.
     - Replace by `queue_free`: `[t_gather] FAIL a replaced stack fades out over LEAVE_S instead of vanishing (drawn true, there next frame false, gone after true)`.
     - No side lock: `[t_gather] FAIL a drawn rare notice never hops sides when its column fills ([P: (8.0, 170.0), S: (300.0, 30.0)])`.
     - No clamp: `[t_gather] FAIL a locked rare notice whose text grew stays on screen ([P: (520.0, 330.0), S: (344.0, 30.0)])`.
     - A repeat that keeps a hidden notice's side: `[t_gather] FAIL a repeat keeps a shown notice's side and frees a hidden one's (kept true, freed false)`
   - Still not frame-perfect: a plain HUD notice and the HUD's own blocks slide vertically when something takes their spot (`UiTokens.free_spot`). That is base HUD behaviour (W1-UI), and a rare notice inherits the vertical slide on its locked side.
5. **Minor: the tinted notice's look was untested.** The colours come from `GatherFeedback.notice_colors`, and the HUD hunk draws with them. t_gather checks they are the tint on ink, never the refusal red. Wrong colours: `[t_gather] FAIL a rare notice is drawn in its tint on ink, not the refusal red ([(0.35, 0.08, 0.06, 0.85), (1.0, 0.9, 0.8, 1.0), (1.0, 0.9, 0.8, 1.0)])`. The windowed lab draws a rare notice and samples its real pixels: `[gather_lab] rare notice at [P: (649.5, 170.0), S: (301.0, 30.0)]: edge 67b84e fill 171814` (gl_compatibility 1600x900; the other three configs read edge `67b84e` too). The reviewer's M26 (the HUD's tint branch off, so the refusal box is drawn), run in the windowed lab: `[gather_lab] FAIL the rare notice's edge is its green tint (5a251c)` and `[gather_lab] FAIL the rare notice's fill is ink, not the refusal red (5d2316)` (gl_compatibility 1600x900, `w2g7/mut/M26_lab.log`).
6. **Minor: the find level cap was untested.** New case: a Lv-30 temperate rock gathered at Gathering 1 with the flint odds forced to 1 gives `flint Lv 5 { "material_tier": "flint", "climate": "temperate", "level": 5 }`. M29 (no downrank): `[t_gather] FAIL a find from a Lv-30 rock at Gathering 1 is downranked to Lv 5 like the main yield (Lv 30)`.
7. **Minor: the butcher count bonuses had no ASSUMPTION.** `loot_tables.json` `butcher._count_bonus` now says what they are and that the docs give no numbers. They are listed under Assumptions.
8. **Minor: two copies of the same logic.**
   - `GatherFeedback.radial_rects(p)` and `plate_rects(grow)` are now the one place each list is built. `taken_rects` and `notice_avoid` both call them.
   - `Inventory.wear_tool(s)` (hooks patch) holds the wear cost rule; `wear_gather_tool` and `GatherService.wear_role_tool` both call it.
   - The helper-wear checks still pass, and M13 (no helper wear) still fails: `[t_gather] FAIL a knife helping on a bush wears 1 per unit, a required one is not worn twice (40 -> 40)`, plus the live and server helper-wear checks.
9. **Minor: notice state was changed inside `_draw`.** `notice_box` is read-only now. `tick_notices`, called from the HUD's `_process`, spends a stale notice, holds one the last draw had no room for, and records the drawn side. `_draw` only writes `drawn_blocks`, as before.
   - Check: with the real HUD hidden (no `_draw`), a rare notice from a node the survivor left is still dropped.
   - Check: the real HUD's tick records the side a notice was drawn on.
   - Hook line removed: `[t_gather] FAIL with the HUD hidden its tick still drops a rare notice from a node the survivor left`, `[t_gather] FAIL the real HUD's tick records the side the notice was drawn on (x <null>, ...)` and the stale-notice draw check
   - Stale check removed from the tick: `[t_gather] FAIL the HUD skips a rare notice from a node the survivor left and draws a plain one (drawn ["Rare find: Flint", "Too far."])` and the hidden-HUD check
10. **Minor: tools/labs.txt.** That file does not exist on claude/mmo-overhaul, so gather_lab cannot be listed there. Today `--lab=gather_lab` runs through main.gd's scene lookup. Next agent item 7 asks the integrator or the CI package to add the line when the file lands.
11. **Minor: a phone's plain stack repeated the toast and read as the next rock's yield.** On a phone a plain "+n Item" stack is placed only above the ring. With the top band there, that means a phone shows the HUD toast alone (lab: `popup skipped over CommonTree (no room by the node); HUD toast true`). Plain stacks taking any side again: `[t_gather] FAIL on a phone a plain stack with no room above the ring is not drawn beside it (the toast says it)`.

### Gate lines (round 4)
Trees: the gate tree `trees/w2g7g` = 095a0cfc + the hooks patch (made by mkscratch, which applies the patch and imports), the mutation tree `trees/w2g7m` (same), and this package's work tree (head + the hooks patch). The only commits after 095a0cfc are lab and test changes and a comment fix in gather_feedback.gd, rerun on the head as listed. Logs are in scratchpad `w2g7/gates`, `w2g7/labs2` and `w2g7/mut`. Each line below was seen in its log:
- `--import` (mkscratch, both trees): 0 `SCRIPT ERROR` / `Failed to compile` lines in `.import.log`. The work tree was re-imported after `gather_xp.gd` (a class_name file) was deleted: rc=0, 0 error lines.
- Every `game/tests/t_*.gd` (24 files) exited rc=0 with 0 SCRIPT ERROR, except t_save, which prints its 5 deliberate ones, as on base:
  - `[t_ai] PASS`, `[t_build] PASS`, `[t_canim] PASS`, `[t_combat] PASS`, `[t_data] PASS items=223 recipes=155`, `[t_daynight] PASS` (t_daynight_dial), `[t_gather] PASS`, `[t_harbour] PASS islands=15`, `[t_iconart] PASS`, `[t_items] PASS`.
  - `[t_light] PASS` (t_light and t_lighting both print it), `[t_occlude] PASS`, `[t_player] PASS`, `[t_save] PASS`, `[t_server_domain] PASS`, `[t_srvdom] PASS`, `[t_structart] PASS`, `[t_tame] PASS`, `[t_ui] PASS`.
  - `[t_uiicons] PASS ids=177 files=116 ...`, `[t_w2_skills] PASS`, `[t_water] PASS`, `[t_web] PASS`.
- `--script res://tests/run_all.gd`: `[tests] PASS`. `tools/smoke.sh --no-import` (through gslot): `SMOKE PASS`.
- On the head b530bebf + hooks: t_gather `[t_gather] PASS` (rc=0, 0 SCRIPT ERROR); `--lab=gather_lab` headless `[gather_lab] PASS`, 0 SCRIPT ERROR.
- Windowed `--lab=gather_lab` on 3b2033fb + hooks (the head changes only comments and t_gather since), one config at a time:
  - gl_compatibility 1600x900: rc=0 `[gather_lab] PASS`, `motion: 105 stack frames watched, worst move beyond the rise 0.0 px, slowest frame 658 ms`.
  - Forward+ 1600x900: rc=0 `[gather_lab] PASS`, `motion: 157 stack frames watched, worst move beyond the rise 0.0 px, slowest frame 282 ms`.
  - gl_compatibility 844x390: rc=0 `[gather_lab] PASS`, `motion: 53 stack frames watched, worst move beyond the rise 0.0 px, slowest frame 129 ms`.
  - Forward+ 844x390: rc=0 `[gather_lab] PASS`, `motion: 55 stack frames watched, worst move beyond the rise 0.0 px, slowest frame 96 ms`.
  - All four: 0 SCRIPT ERROR.
- The first windowed round (`w2g7/labs`) failed two lab checks, and both were the lab's own errors:
  - The motion check read the last frame's tween against this frame's interval: 1.8-2.7 px "past the rise" on frames up to 0.8 s long. Fixed in bf896485: each frame is bounded by the tween's own delta. The stack code did not change.
  - The plain-above-the-ring check judged a random "Wide Serration" trait (a real rare stack) as plain by its stage name. Fixed in 3b2033fb: the stack's own flag decides.
- 0 "couldn't resolve track" in every gate and lab log. No new `~/Library/Logs/DiagnosticReports/Godot-*.ips`: the newest is still Godot-2026-10-20-232613.ips, from before this run.
- Hooks patch: `git apply --check` clean on claude/mmo-overhaul acc684a6, checked with a temporary index read from that tree. It applies cleanly (`git apply --3way`) in both scratch trees.

### Screenshots looked at (scratchpad `w2g7/labs2` and `w2g7/shots`, not in the repo)
- **844x390 gl_compatibility and Forward+ `-rare`:** a green "Low Vibration" on ink, under the survivor and centred under the bush's ring, with the "+3 Fibre Stalk" toast on the left. It is clear of the Bush Berries, Rock and Common Tree pills, the WORK AXE hex and the XP line. Before round 4 this stage showed only the static notice.
- **844x390 `-rare_radial_open`, both renderers:** no spot by the node (the Fibre Stalk and Herb Leaf hexes and labels fill it). The rare notice "Rare trait: Low Vibration Fibre Stalk  x2" is at the bottom right, fully on screen. In the first run, before the clamp, "x2" ran 20 px off the right edge.
- **844x390 Forward+ `-tools` (first run):** a random "Wide Serration" trait on a log sits right of the axe ring, clear of the day/night dial and the Common Tree pill.
- **844x390 `-rare_notice`:** the green notice on ink under the survivor. The pixel check reads its edge as `67b84e` (GREEN) and its fill as `151613`/`161813` (ink).
- **1600x900 gl_compatibility `-rare` and `-rare_radial_open`:** "Low Vibration Fibre Stalk" over "+n Fibre Stalk", left of the ring, or above it under the toast when the radial is open. It is clear of the radial's hexes and labels, the pills, the raptor and the survivor.
- **Not this package (W1-UI):** plain HUD notices and toasts still slide vertically when something takes their spot (next agent item 8).

### Mutation suite (round 4)
Script `w2g7/mutate.py`, output `w2g7/mutate.out`, logs `w2g7/mut/`. Each mutation is applied to the mutation tree, t_gather runs, and the file is restored. There are 51 mutations: 24 for round 4's code and checks, and 27 from earlier rounds whose code still stands (the reviewer's M1-M37 that still apply). M5 and M28 tested the removed XP bonus; Mxp_gather and Mxp_butcher replace them. M7, M12, M13, M21, M22, M26, M29 and M35 were rewritten for the new code. Every one exits rc=1 with a `[t_gather] FAIL` line; the round 4 lines are quoted in the section above. Mbelow first survived (the phone set-up let a side column slide clear); b530bebf tightened the set-up, and the rerun prints `[t_gather] FAIL with the sides taken a phone's rare stack is drawn under the ring, within reach of it ([P: (0.0, 0.0), S: (0.0, 0.0)], gap (420.0, 150.0))`. The reviewer's M26 (the HUD's tint branch off) is caught by the windowed lab's pixel check, not by t_gather. A headless run cannot see pixels. The unmutated control prints `control rc=0 [t_gather] PASS`.

## Review round 3 (2026-10-21): what changed (3111aa8f..b02fd2bb)
The round 3 commits landed before a usage limit cut that run, so the report was not updated then. What they changed:
- **Rare notices off what the HUD does not know.** `GatherFeedback.notice_box` replaced `UiTokens.free_spot` for tinted notices in the hunt_hud hunk:
  - `notice_avoid` adds the open radial's labels, title and hexes, the creature plates and `survivor_rect` (head to the PlayerBeacon ring at their feet). The radial's "Herb Leaf" label had covered the notice at 844x390.
  - With no room in the centre column the notice goes to the left edge, then the right; with none at all it waits up to 2 s (`hold_notice`).
  - The same result again while its notice is up reads "x2" in that notice (`add_notice`); two identical green lines had stacked at 844x390.
- **New tests.**
  - `_test_server_gather` runs the server's `act.gather` hunk: helper pick and knife wear, traits with uids, the flint find minted with a uid and counted, and no find on a grassland rock.
  - `_test_hud_draw` drives the real `hunt_hud.gd` `_draw` at 844x390 with the radial open. The test and the lab list what a rare notice must keep off themselves, so a change in GatherFeedback cannot hide itself (2156cfe4). Cases for the survivor and ring (720ae8fa), and for a creature plate and the full centre column (b02fd2bb).
- **Data.**
  - `no_knife_count_mult` 0.75: a carcass cut with no knife gives about 1/1.35 of the stone knife's base parts, mirroring the bare-hands gather rule (ASSUMPTION).
  - The silver_ore row moved from BlackIronNode, which no snowfield grows, to snowfield rock (Rock_Snow, IceNode).
  - The `tree_dead` resin row was dropped: no tree_dead node grows in a climate that lists resin. t_gather now fails any row no node can roll.
  - `GatherService.role_of` was removed (dead code).
- **Base merge** a1f57974: claude/mmo-overhaul 946da955 (HUD-DAYNIGHT, which also edits hunt_hud.gd). The hooks patch was regenerated on it.
- **Gates.** This package did not run gates on b02fd2bb itself; the usage limit hit first. The independent reviewer ran them on b02fd2bb with the hooks patch: every t_*.gd exited 0, `[tests] PASS` and `SMOKE PASS` (scratchpad `review/w2-gather/r2/v3/gates`). The round 4 gate lines below cover all of round 3's code.

## History: sync 3 and rounds 1-2 (superseded where round 4 says so)
Round 4 removed the rare bonus XP, `GatherXp` and `ButcherLoot.on_take`. Every "2 + 10 per rare item", "3 + 8 for the talon" and GatherXp line below is history. The live checks now assert the base 2 and 3 only. The one-frame move-off that sync 3 lists under the motion gate is gone too: since round 4 a stack fades out where it is.

### Sync 3 (2026-10-21): this run's findings, the base merge, gate lines
This run's findings are review round 2's, word for word. All of them were fixed in 0cbec77a..be67836a (next section, item by item). This run re-proved each one on the new head, merged the moved base and adapted to it:
- **Base merge** a8929fd8: claude/mmo-overhaul ddaab662 (W2-DATA, W2-SKILLS and WATER merged since 73527576). No conflicts on the branch.
- **Hooks patch regenerated.** WATER added `WaterAccess.soil(p, &"butcher")` where the `loot()` hunk lands; the hunk now sits after it. The patch's +/- lines are unchanged; only its context moved.
- **W2-DATA's ladder vs the finds.** W2-DATA gates FlintNode's flint behind a bone pick (`min_pick_tier {"flint": "bone"}`). The temperate-rock flint find had no gate, so a stone pick or bare hands could get flint a rung early. The row now has `"min_tool_tier": "bone"`. New t_gather check: no find's gate sits below the `min_pick_tier` any nature node sets for the same item (copper_ore is obsidian on both sides; silver_ore, pearl and resin have no node gate).
  - Without the gate: `[t_gather] FAIL rock/flint find gate 'none' is not below its nodes' min_pick_tier (bone)` and `[t_gather] FAIL flint never drops below the bone pick FlintNode needs (bare 0.0472, stone 0.0472)`.
- **Owner 2026-10-21 "make it flashy"** (STATUS: feedback moments, rare finds among them, get "light, motion and punch"). A yield stack with a rare line (green trait or gold find) now starts at 1.35x scale and 1.8x brightness, then eases back to normal over 0.28 s (TRANS_BACK) and 0.45 s. It is a tween, so it never snaps. Plain "+n Item" stacks do not pop.
  - Check: `[t_gather] rare punch: scale 1.35 -> 1.00, flash 1.80 -> 1.00, plain pops false`. Without the pop: `[t_gather] FAIL a rare stack pops and flashes, then eases to normal; a plain one does not (scale 1.00 -> 1.00, flash 1.00 -> 1.00, plain false)`.
  - The motion gate (STATUS 2026-10-21, "glitchy movement of UI") still has one known jump: when a HUD block moves onto a drawn stack, the stack moves off in one frame (`follow` in gather_feedback.gd). It was built that way so the stack never sits under a banner. Reviewers measuring frame sequences will see that one move.
- W2-SKILLS changed yields. The live finish_gather case now lands 6 fibre per unit at the home bush, not 1. Its XP check still holds: `finish_gather on a home bush (trait odds forced to 1): fibre 6, traited 6, gathering XP 62.0, knife 40 -> 39` is 2 + 10 per rare item.

#### Gate lines (sync 3: scratch trees `w2g6` and `w2g6g` = 1610c3ed + the hooks patch)
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

#### Screenshots looked at (scratchpad `w2g6/shots`, not in the repo)
- **1600x900 gl_compatibility `-rare`:** a green "Low Vibration Fibre Stalk" over a cream "+3 Fibre Stalk", left of the ring hex. It is clear of the Bush, Bush Berries, Common Tree and Rock pills and of the raptor. The shot is taken 0.35 s after the unit, so the pop has already eased back to normal size.
- **1600x900 Forward+ `-rare_radial`:** the same stack in the same place, clear of every pill.
- **844x390 gl_compatibility `-rare`:** the stack is skipped (`yield stack skipped: no free spot by the node`), and the green notice "Rare trait: Low Vibration Fibre Stalk" on ink sits under "Survivor".
- **844x390 gl_compatibility `-butcher`:** loot toasts on the left. No rare notice is left over from the gathers.
- **844x390 gl_compatibility `-tools`:** "+2 Log" is down-left of the work-axe ring and clear of the Bush, Bush Berries and Rock pills.
- **Not this package, still seen (W1-UI):**
  - At 844x390 the level-up banner pushes the pet plate onto the Bush pill.
  - The "Loot · Velociraptor" label crosses the "Survivor" nameplate in the butcher shot.

### Review round 2 (2026-10-20 night): findings, fixes, checks
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

### Round 2 gate lines (scratch trees `w2g5` and `w2g5g` = 0cbec77a + the hooks patch), superseded by sync 3 above
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

### Round 2 screenshots looked at (scratchpad `w2g5/shots2`, not in the repo)
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

### Review round 1 (2026-10-20 evening), kept for the record
The climate filter, the per-row climate materials check, the live after_unit and full-bag cases, the butcher knife hook, two finds in one frame, the gold fallback notice, rare part XP at the take, finds stamped with climate and level, the server act.gather hunk, and the bad-row guards. The quoted mutation lines are in git history (5c1f1c40). Superseded since then:
- The berries and herb_leaf home rows (item 1 above).
- The GatherXp sink and its quit-crash test (item 9).
- `notice(text, gold)` (item 8).

## Assumptions (every value the docs do not set; each is also marked in its data or code)
- Find odds in `loot_tables.json` `gather_rare` (`_assumption`): illustrative, about one find per 20-30 passes, +15% per tool tier (`tool_tier_bonus`), capped at 0.5. The docs give no numbers for secondary materials. The 5% trait chance is the docs' own number (world-design.md:55).
- Which of the six green traits a material gets (`rare_trait._assumption`): each is equally likely; tool tier does not raise the 5%.
- A find does not roll a trait of its own: it is already the rare result of its pass. Carcass parts roll no traits yet; that is W2-BUTCHER's (spec 12:74).
- A traited item swaps into a free slot. With no free slot it stays plain and is never lost.
- Rare carcass parts (`butcher._rare_chance`): an unlocked rare part still rolls its chance (default 0.12, +15% per knife tier, cap 0.6), standing in for spec 12 s2's Slaughter Ability roll until W2-BUTCHER.
- Part gates (`butcher._part_gates`): the knife tier stands in for the Butchering part nodes (dense_bone needs bone, armor_scute and venom_gland need flint).
- Part counts (`butcher._count_bonus`, round 4): each knife tier above stone adds 15% to the base part counts and each Butchering level 1%.
- No knife (`butcher._no_knife`, round 3): a carcass cut with no knife gives 0.75x the base parts, about 1/1.35 like the bare-hands gather rule.
- The carcass rolls when the animal falls, for the local survivor's best knife and Butchering level (single player; W3 rolls for the credited killer). Kills out of the survivor's view roll silently.
- Bare hands are 1.35x slower than the role's tool (`gather_rules.json` `_assumption`). A helper tool wears at `Inventory.wear_tool`'s cost (1 for a work tool, 3 for a weapon; that rule's own ASSUMPTION is in inventory.gd).
- A find needs at least the pick tier a nature node needs for the same item (W2-DATA's ladder), so the flint find needs a bone pick.
- **No rare bonus XP** (round 4). This is not an assumption but the removal of one: rounds 1-3 paid 10 Gathering XP per traited item or find and 8 Butchering XP per rare part. No doc sets that, and spec 03 ties XP to difficulty. W2-SKILLS owns XP pacing.
- The rare pop's size, brightness and timing (1.35x, 1.8x, 0.28 s), the fade-out (0.15 s) and the phone's rare line (18 px, 6 px ink) are picked by eye. The owner's "make it flashy" and motion gate give no numbers.
- On a phone a plain "+n Item" stack shows only above the ring, and a rare stack is the trait alone. The HUD toast carries the count.
- gather_lab hands over the starter tools and picks the seed so the next fibre item rolls a trait. The odds themselves are proven in t_gather.

## What the next agent needs
1. **ECON:** `game/data/economy/limits.json` `attributes` is a whitelist ("Anything else is refused at deposit"). It must list the six trait keys as `bool`, or a traited material cannot be deposited or sold. This is ECON's file, so it is not in this patch.
2. **W2-INV, the sync step:** `stamp_traits` finds the landed unit by `can_merge_with`. With instances (uids, no stacking) that finds nothing, so no trait lands. Stamp the trait on the instance instead. `add_finds` should mint each find with a uid. The hooks patch now also adds `Inventory.wear_tool(s)` (split out of `wear_gather_tool`). Keep it when W2-INV rewrites inventory.gd.
3. **W2-BUTCHER / W2-SKILLS:**
   - Per-part Butchering nodes and per-part take refusal.
   - The Slaughter, Mining and Plant Gathering abilities.
   - Flawless and mistake results.
   - Rare traits on carcass parts (spec 12 s1-2, 12:74).
   - If a doc ever sets XP for rare results, it belongs in SkillState's rules, not here.
4. **W3-SRVACT:** server nodes need their island climate in `attributes` (WorldFacade.add_node sets only level) before any find can roll there. Traits and helper wear already roll there.
5. **W2-DATA:** review the find items' rarity once it lives in items.json. resin and flint are common/uncommon in item_rarity.json.
6. **GATHERUI** (queued after this merge; STATUS says the hex time "is static and will be wrong after W2-GATHER"): read `GatherService.unit_seconds(p, node)` and `GatherService.yield_multiplier(p, node)` for the hex's time and yield. They are what finish_gather uses.
7. **Integrator / the CI package:** when `tools/labs.txt` lands on claude/mmo-overhaul, add `gather_lab` to it. A windowed run is the meaningful one: the headless run skips the placement, pixel and motion checks.
8. **W1-UI:** plain HUD notices and toasts still slide vertically in one frame when something takes their spot (`UiTokens.free_spot`). A rare notice keeps its side but inherits that slide. On a phone with the gather radial open, the rare notice is the only rare show, and it sits at the right edge, away from the node. The radial and HUD leave no closer spot.
9. **Not done:** no web export check. Frame timing was measured on this loaded machine (slowest frames 0.1-0.8 s), not on a phone.
