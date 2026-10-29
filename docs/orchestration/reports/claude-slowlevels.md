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
