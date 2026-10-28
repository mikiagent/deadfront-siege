# dsc-tamingodds — taming odds as an S-curve

Task: replace the "guaranteed-ish" taming feel with a visible odds number. Taming success is now one
logistic curve on (Survival level − creature level) shifted by remaining health and the net tier,
clamped to [0.05, 0.95]; the net hex / creature plate shows "Tame NN%" before the survivor commits, and
the pet's grade improves when the tame is prepared (a bait item in the bag). The capture-open rule is
untouched.

## What shipped
- `game/scripts/pets/taming_odds.gd` (new, `class_name TamingOdds`) + `game/data/taming_odds.json`:
  `level_z / level_odds` (per-side log-odds slopes through the doc's anchors: 50 % at an even gap, 85 %
  ten levels ahead, 10 % ten levels behind), `health_z` (0 at the capture threshold, so the anchors hold
  there; reads `FieldTame.CAPTURE_HEALTH_FRAC`, never a copy), `tier_z`, `odds_for(target, player,
  net_tier)`, `odds_for_values`, `raw_odds`, `succeeds(p, rng)`, `prep_iv_bonus()`, `caption(p)`.
- `game/scripts/pets/capture_system.gd`: `chance_for(creature, net_tier, player = null)` delegates to
  `TamingOdds.odds_for` when a survivor is given (the no-survivor call keeps the spec-09 shape for
  labs); `attempt(player, creature, force_result, rng = null)` rolls `TamingOdds.succeeds(chance, rng)`,
  so the number shown is the number rolled, and a seeded RNG makes a throw repeatable. `force_result`
  still decides the throw.
- `game/scripts/pets/field_tame.gd`: `plate_hint(creature, inv, player = null)` now returns `odds` and
  a `"Tame NN%"` text, resolving the net tier from the bag; `_complete` spends one `bait`-category item
  and adds `bait_iv_bonus` IVs to every stat before `PetRecord.from_def`, so `grade` (=
  `genetics.overall_tier()`) rises without ever being stamped.
- `game/scripts/ui/creature_plates.gd`: `_tick_tame_hint` prints the caption (green ≥ 50 %, amber
  below, with feed progress while feeds are still owed) instead of a bare "Tame".
- `game/tests/t_tamingodds.gd` (new): six sections — doc anchors on the level half, [0.05, 0.95]
  clamp sweep, monotonic in gap and in health plus seeded determinism, the 0.30 / 0.31 capture boundary
  unchanged, shown == rolled (with a real `Player`, bag and net, plus 40 seeded throws and
  `force_result`), and grade by bait. The plate assertion was proven to fail by reverting the label.
- `docs/current/creatures-capture-taming.md`: new "Taming odds" section, the chance step rewritten,
  grade-by-preparation added to the field tame.

## Assumptions
- The odds are rolled at the NET commit (`CaptureSystem.attempt`), not in the field feed loop:
  `FieldTame.apply_feed` is deterministic today and t_natures / t_colors / t_w2_skills finish tames in a
  fixed number of feeds. The field tame is where the bait grade lands; the net is where the S-curve
  rolls.
- Grade by preparation is bait yes / no: one `bait`-category item (`leech`) for +6 IVs on every stat.
  The design doc says the grade improves with preparation but not by how much.
- Every JSON level besides the doc's three anchors (health slope 1.5, tier slope 0.25, the clamp band)
  is a first-pass number picked to be measurable, not balanced. Balance belongs to the owner after
  skills / building.
- The 0.30 figure in `data/taming_odds.json` is a sanity check; the curve reads
  `FieldTame.CAPTURE_HEALTH_FRAC`, and the test compares the two.

## What the next agent needs
- `CaptureSystem`, `FieldTame`, `CreaturePlates` are shared: `plate_hint` gained a third (optional)
  argument and a new `odds` key, `chance_for` gained a third (optional) argument, `attempt` gained a
  fourth (optional) `rng`. All old call sites still work; `t_tame`, `t_natures`, `t_targetui`,
  `t_save` pass in the gate.
- `t_capture09` is outside this task's scope and asserts the old formula shape directly
  (`chance_for(low, 1) == 0.35 × (1.5 − 0.20)`). That call has no player, so the legacy branch keeps it
  green.
- The visual lab (`scripts/dev/pets_lab.gd`) is outside this task's SCOPE and prints no
  `[tamingodds] RESULT` line; stage 2 was deferred by `HEADLESS_ONLY` in the gate dir, so this is not
  visual approval. A windowed pass should look at the plate caption on a knocked-down animal with a net
  in the bag.
- Odds are shown and rolled for the net (hex) path; the field tame shows the same number on the plate
  but still completes deterministically on feeds. If the owner wants the feed path to roll too, that is
  a follow-up that has to move t_natures / t_colors / t_w2_skills with it.
