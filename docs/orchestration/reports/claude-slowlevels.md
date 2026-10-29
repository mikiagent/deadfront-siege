# SLOWLEVELS (Claude agent): everything levels up slower

Owner 2026-10-28: "make it so everything levels up slower (skills, player level, etc)".

## What shipped
- `game/data/progression.json`: one knob per XP track, each multiplies the XP a level **costs**
  (XP grants, curve shapes and the 100-XP bar segment stay as they were):
  `player_xp_cost_mult`, `skill_xp_cost_mult`, `pet_xp_cost_mult`, `tribe_xp_cost_mult`, all **2.5**.
- `game/scripts/core/progression.gd` (`Progression.mult(key)`, static, 1.0 when a key is missing).
- Applied at the single curve function of each track:
  - player level: `World.xp_for_level` = round(110 x 1.12^n x 2.5)
  - skill trees: `SkillState.xp_to_next` = (20 + 8 n) x 2.5 (the server `CharacterState.add_xp`, skills
    sheet, yield card and save sanitizer bound all read it)
  - pets: `PetRecord.xp_to_next` = (30 + 15 n) x 2.5 (asset validator reads it)
  - tribe members: `TribeRecord.add_skill_xp` per-level cost 40 x 2.5
- SP come from character levels, so skill points slow with the player level automatically.
  Wild creature levels are spawn data, not XP; untouched. No combat/HP/damage numbers changed.

## Why costs, not grants
Raising costs keeps every grant an integer (no fractional carry on `World.add_xp(int)`), toasts keep
their numbers, and old saves only gain room in the current level (nobody loses a level).

## Factor (ASSUMPTION)
The docs pin no slower pace: islands-and-loop-plan §3.2 targets Lv 10 at ~47 min and Lv 11-13 at
hour one, which the owner's request supersedes. Default **2.5x** on every track; logged as SL1 in
`docs/vision/WildLandsMMO_Open_Questions.md`.

## Time to reach (arithmetic)
Rate: ~35 character XP/min of mixed play, the pace the §3.2 human beat sheet implies (Lv 10 = 1,625
XP at ~47 min). Gather passes pay 2-4, first builds 30, crafts 6+, Orders 20-100. A tree cannot pass
the character level, so the first skill level-up waits for character Lv 2 (its 28 / 70 XP comes in
1-2 min of gathering).

| milestone | XP before | min before | XP after | min after |
|---|---|---|---|---|
| Character Lv 2 | 110 | 3 | 275 | 8 |
| Character Lv 3 | 233 | 7 | 583 | 17 |
| Character Lv 5 | 526 | 15 | 1,314 | 38 |
| Character Lv 10 | 1,625 | 46 | 4,064 | 116 |
| Level at 60 min | — | Lv 11 | — | Lv 6 |
| First skill level-up (e.g. Gathering 2) | 28 | ~3 (gated by Lv 2) | 70 | ~8 (gated by Lv 2) |
| Skill 2 -> 3 | 36 more | ~7 | 90 more | ~17 |
| Pet Lv 1 -> 2 | 45 | — | 112.5 | — |
| Tribe skill 1 -> 2 | 40 | — | 100 | — |

Not measured with the bot; a constant-rate estimate. Later levels pay more per pass, so deep-level
times are overstated by this model.

## Tests and docs
- `t_xpecon`: curve check now Lv 1 275, Lv 10 763, Lv 11 854, Lv 1-10 sum 4,827.
- Other tests read the curve functions, so they follow the knob.
- Docs: `docs/current/{economy-trading,hud,creatures-capture-taming,tribe,skills}.md`, Open Questions SL1.

## Next agent
- Tune pace in `game/data/progression.json` only; 1.0 restores the old pace.
- `docs/design/islands-and-loop-plan.md` §3.2 hour-one targets are stale against this pace (not edited:
  design doc, owner call).

## Added scope 1: Defense trains only on an avoided attack (owner 2026-10-28)
- Removed the +1 Defense XP every hit taken paid (`Player.receive_creature_hit`).
- Defense XP now comes only from `Player.roll_dodge`, which already paid only when the roll's i-frames
  took an attack that would have landed (`lands`). There is no block/parry mechanic in the build; when
  one lands it should pay Defense the same way, from its "stopped damage" branch.
- Server side (`intent_handlers.gd`) never paid Defense XP; unchanged.
- Test `t_roll`: dodged bite -> Defense XP once (existing), three rolls with nothing incoming -> 0
  (existing), a bite that lands after the window -> 0 (new). Doc: `docs/current/controls.md`.

## Added scope 2: batched skill XP bars (owner 2026-10-28)
- The skill progress popup on this branch is the left XP feed under the vitals (`YieldCard.draw_feed`
  over `HudEventState.skill_toasts`), not TopFeed; TopFeed only shows level-ups and item gains. The
  batching is on the feed.
- `HudEventState`: one bar per tree takes every gain while it shows (no 1 s merge window). Each entry
  keeps `pending` (level units after the gain, from `HudEventState.progress_of`) and `shown`. The
  light-green ghost jumps to `pending` at once; after 0.6 s without a gain the real fill eases up
  (2.5 x gap per second, floor 0.15/s); crossing a level flashes the bar white for 0.45 s and the fill
  restarts at the new level; once caught up the bar lingers 2.5 s (fading over the last 40 %).
- `hunt_hud.gd`: one line, the skill_xp_gained hook passes `HudEventState.progress_of(sk, tree)`.
- Test `t_skillfeel._test_batch`: three gains -> one "+30 Gathering XP" bar; ghost leads the fill
  mid-batch; fill catches up, bar lingers, then goes; a gain past a level fills the ghost and the fill
  rolls over to Lv. 2 with a flash. `_test_merge` updated (a gain 1.1 s later now joins the bar).
- Shot: `docs/orchestration/reports/slowlevels/skillbatch_midbatch_1600x900.png` (+ `_crop.png`),
  from `skillfeel_lab` (new `_shot_batch`, windowed at `--position 6000,3000`): one Gathering bar
  "+60 XP", ghost at 86 %, real fill not moved yet.
- Not done: the same ghost fill on the bottom player XP bar (`HuntHud._draw_xp_bar`); another agent
  is editing hunt_hud.gd's bars, so it was left alone.
- `skillfeel_lab` still exits 1 on "no skillpulse block: the halo was not drawn" (the MENU/Skills hex
  halo, untouched here); its other results pass, including `batch_one_bar=1`.

## Added scope 3: Skills sheet opening sweep (owner 2026-10-28)
- `skills_sheet.gd`: a gold `SkillsLevelTrack` under the XP bar (the tree's level over its highest node
  level). On open it sweeps from 0 to the level in 0.8 s (cubic ease-out); each node that can be
  unlocked flashes gold as the track passes its level (lowest first, `sweep_flashed`); the free skill
  points count up. A reopen within 4 s skips it. No reduced-motion setting exists (ASSUMPTION), so
  none is read. A node that can be unlocked gets a gold ▲.
- Not done: Durango's per-level column layout and the arrow tip; the sheet stays a list.
- Test `t_skillfeel._test_sweep`. Shot `slowlevels/skillsweep_midsweep_1600x900.png`.

## Added scope 4: skill research (owner 2026-10-28)
- A full bar no longer levels a tree (all but Survival, which spec 03 exempts). The card and detail
  read "Research ready"; the player presses Start Research; the level arrives when the countdown ends.
  Nothing starts by itself. One research at a time. XP past a full bar keeps banking.
- `SkillState.research` = {tree, from, end (unix s)}, saved as an optional `skills_v2.research` key
  (no rev bump; old saves load with none; `save_sanitizer` drops a malformed one and clamps the end to
  at most one research from now). A research that ended while the game was closed lands on load.
  shortcut: an end forged into the past is not caught (no start is stored).
- Duration `research_s(n)` = min(72 h, 60 s x g^(n-1)), g = 2880^(1/48) so 49->50 = 48 h (owner
  anchor): 1 min, 4.5 min at 10, 23 min at 20, 2 h at 30, 11 h at 40, 48 h at 49, 72 h from 52.
  Knobs in `progression.json skill_research`.
- Sheet: "Researching Lv. N · Remaining Time 23h 59m" live, Start Research (CTA), Instant Completion
  and Decrease Research Time as disabled "coming soon" stubs (no purchases wired), grid card
  "Lv. 49 · 50" in gold while researching.
- Server `CharacterState.add_xp` banks gated trees and never levels them (shortcut: research is
  client-side until W3-SRVACT).
- Character level is untouched.
- Test `t_research`: full bar -> no level, no timer even 10 days later; Survival still levels;
  start -> countdown = research_s(1); second research refused; save/load mid-way keeps the remaining
  time; done one second early -> no, after -> Lv. 2 with one signal, rung spent; offline completion
  on load; 49->50 = 48 h; old save without the key. Shot
  `slowlevels/skillresearch_countdown_1600x900.png`.

### Re-estimated early pace (slowdown x research), ~35 character XP/min
| milestone | before | after slowdown only | after slowdown + research |
|---|---|---|---|
| Character Lv 2 / 5 / 10 | 3 / 15 / 46 min | 8 / 38 / 116 min | same (research never touches it) |
| First tree level (e.g. Gathering 2) | ~3 min | ~8 min | ~9 min: the bar fills by ~2 min, the cap opens at character Lv 2 (8 min), then 1 min of research the player must start |
| A tree at Lv 5 | ~15 min | ~38 min | ~45 min (4 researches, 6 min in all, one at a time across trees) |
| A tree at Lv 10 | ~46 min | ~116 min | ~2 h 25 min (9 researches, 23 min) |
| A tree at Lv 20 | — | — | + 4.5 h of research for that tree alone |
Several trees compete for the single research slot, so a player training three trees waits roughly
three times the research total.

## Added scope 5: recipe nodes and cross-skill gear (owner 2026-10-28)
- Nodes already gate recipes through `effects: [{type: recipe, recipes: [...]}]` (SkillRules); used
  that instead of a new `unlocks_recipes` field.
- `ItemDef.skill_bonus` {tree: levels}, `Inventory.skill_bonus(tree)` over worn, unbroken pieces,
  `SkillRules.effective_level(p, tree)` = tree level + gear, capped at 60. Butchering's cut budget and
  part rolls read it (`corpse.gd`, `carcass_parts.gd`, `butcher_loot.gd`).
- Tailoring node `spiky_armor` (Lv. 30, 4 SP, ASSUMPTION) unlocks `spiky_armor` and
  `spiky_armor_helmet` (workbench; cured hide, dense bone such as tail spikes, lashing). Each worn piece
  +5 Butchering (ASSUMPTION). Placeholder art: the hide-and-bone pieces.
- Sheet rows show the node's description and "Craft: Spiky Armor, Spiky Armor Helmet"; a learned
  node's button reads Unlearn (full SP refund; the existing refund rules block it when a learned node
  depends on it or the day's free refunds are used).
- Test `t_skillgear`: locked before, learn costs 4 SP and unlocks both recipes, wearing both -> 14
  effective Butchering from tree level 4, helmet off -> 9, Unlearn refunds and relocks.
- Follow-up: populate node -> recipe -> skill-bonus for every tree.

## Added scope 6: Durango skill-point workbook
- `docs/reference/durango_skill_point_upgrades.xlsx` + one CSV per sheet (exported with a zipfile XML
  reader; no openpyxl here), summary `docs/reference/skill-upgrades.md`.
- Imported: Stealth I-V SP/levels now cite the sheet (Stealth IV 5 -> 4 SP); Animal Handling I-IV
  already matched.
- Not imported (listed in skill-upgrades.md, Open Questions SL4): Stealth VI, Exploration I-III,
  Bulk Up I-X, Surviving Durango I-VII (new nodes; rename "Surviving Durango" when added), the
  per-family capture nodes (conflict with our Capture Technique ladder), and all 144 records of the other
  11 categories (no SP in the source).

## Defense XP through CombatAvoid (after claude/mmo-dodgetext landed)
- Merged origin/claude/mmo-overhaul (with DODGETEXT). `CombatAvoid.avoided(defender, attacker, how,
  earned := true)` now pays Defense XP when the defender is the survivor and `earned` is true;
  `Player.roll_dodge` passes `lands` and no longer pays its own. `CreatureAttack` passes
  `lands and Telegraph.player_dodged(attacker)`: stepping out of a telegraphed attack that would have
  landed trains Defense, a plain accuracy miss does not. Creature defenders never get XP. A block passes
  the default (earned) — no block mechanic exists yet; when one lands it should call
  `avoided(player, attacker, &"block")` from its "stopped damage" branch.
- `t_roll`: an accuracy miss pays no Defense XP (new), beside the three existing checks.

## Other test fixes
- `market_harness.gd`: the viewer now earns 40 T before listing (was 25). The two new tradeable
  items shift the Settlers' rotating demand, so the viewer ended at 11 tradable against a 12 T
  cheapest listing (`t_uimarket`). Verified: canon passes; canon + this branch's items.json fails;
  with the harness fix it passes.
- `t_skilltrees`: 214 nodes, `spiky_armor` in the Tailoring baseline. `t_levelfx`, `t_skillfeel`,
  `t_w2_skills`: level-ups of gated trees go through a research run out on a test clock
  (`clock_override`). `t_data` / `t_iconart`: rarity and armour icon aliases for the new items.

## Verification (2026-10-29)
- `tools/all_tests.sh`: 134 tests. Full run: 128 pass. The 6 failures were rerun one at a time:
  t_rest, t_save, t_uigather, t_dismount and t_eyetrails pass (they share user:// or measure frame time,
  and the box was running ~180 Godot processes). **t_buildspeed still fails on load:** home island
  build 2571 ms against a 2500 ms budget. The same test failed at 3454 ms before any change of mine.
  Nothing here touches island building.
- `tools/smoke.sh --no-import`: SMOKE PASS.
- `skillfeel_lab` (windowed, `--position 6000,3000`): batch, sweep and research shots taken. It exits 1
  on "no skillpulse block" (the MENU hex halo; not touched here).

## Landing merge (2026-10-29)
- Merged origin/claude/mmo-overhaul through BAGUI (02362ad2) and the roadmap refresh (d0c649fa).
  Conflicts resolved:
  - `items.json` / `recipes.json`: kept both sides' new rows.
  - `market_harness.gd`: took canon's earn(40).
  - `combat_avoid.gd`: canon's &"miss" plus this branch's `earned`. Defense XP is paid only for
    &"dodge" or &"block", and only when earned.
  - `creature_attack.gd`: canon's hit/miss split. A telegraph sidestep passes `lands`; a miss or
    passive dodge passes `earned = false`.
  - Open Questions: kept both.
- Tests after the BAGUI merge: `tools/all_tests.sh` 141 tests, 140 pass. t_tutorial failed once under
  load (bot's carcass despawned) and passes alone (355 s). The pre-BAGUI run had only t_buildspeed /
  t_perfgates over the island build budget on a loaded box. Targeted runs pass: t_skilltrees,
  t_levelbar, t_dodgetext, t_uimarket, t_research, t_skillgear, t_skillfeel, t_roll, t_w2_skills,
  t_levelfx, t_xpecon, t_data, t_iconart. t_save passes with its own HOME. SMOKE PASS.
