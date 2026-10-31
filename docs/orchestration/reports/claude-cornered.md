# claude-cornered: fleeing animals fight back when chased

Branch `claude/mmo-cornered` (from `claude/mmo-overhaul`). Owner rule: "Animals that run away from you should get
territorial and attack you if you chase them".

## Shipped

- `game/scripts/creatures/brains/brain_cornered.gd` (new, `BrainCornered`): chase pressure, owned by every
  `CreatureBrain` as `brain.cornered` (ticked in `_pre_think`, fed by `note_damage`). While the animal is in `flee`,
  a threat within `radius_m` moving at it at `pursuit_mps` or more adds pressure per second; a hit adds `hit_s`;
  otherwise pressure decays. At `pressure_s` (or `chase_m` metres of pursuit) it stops, plays the first display clip
  it has (roar, crest_flare, stomp, alert), then is provoked for `fight_s` and fights with its own attacks
  (TacticalBrain moves or CreatureBrain primary/heavy). Under `weak_frac` HP the fight ends and it flees again.
  TacticalBrain emits `tactic("cornered")`.
- `tactical_brain.gd _provoked`: a cornered fight holds past `guard_m` and past the flee-nature rule.
- `ai.json default.cornered`: the thresholds. Per species/archetype override: a `"cornered"` block in the tactics
  profile (merged key by key; `{"enabled": false}` turns it off).
- Test `game/tests/t_cornered.gd`: zebraceratops (TacticalBrain) and stegosaurus (CreatureBrain) chased at 7 m/s turn
  in 4.0 s / 3.2 s and hit the survivor; an unchased zebraceratops only flees and grazes; at 20 % HP it runs again;
  a tactics override replaces one threshold and keeps the rest.
- Docs: `docs/current/fight-lab.md` (Cornered section + species table), open questions CN1-CN5.

## Thresholds (ASSUMPTION, all in ai.json)

radius_m 10, pursuit_mps 1.5, pressure_s 3, chase_m 20, hit_s 1.5, decay 0.5, fight_s 12, weak_frac 0.3,
display_s 0.8.

## Species affected

Every brain that enters `flee`: skittish grazers on sight (zebraceratops, pachycephalosaurus, protoceratops,
gallimimus, megaloceros), defensive/territorial grazers after a big hit (stegosaurus, triceratops, styracosaurus,
woolly rhino, brachiosaurus, ankylosaurus if it ever flees) and any Timid-nature animal. Exempt: tactical flights that
return on their own (`_flee_left`: swarm hurt runs, mate-death scatter) and a Timid rage (enrage_flee).

## Tests

t_cornered, t_ai, t_tactical, t_combat, t_noboxes, t_canim, t_coelomoves, t_natures PASS; run_all `[tests] PASS`
(its SCRIPT ERROR lines are the old save/fatigue checks, not this change); tools/smoke.sh SMOKE PASS.

## Not done / for the next agent

- No rig has a roar/stomp clip; the display is `alert` everywhere.
- The existing skittish-territorial rule (gallimimus, megaloceros: turn after one 3 s flight) is kept as is; the two
  overlap harmlessly. Unify them if the owner wants only the chase rule.
- Not checked in a windowed fight lab. Credits spent: 0.
