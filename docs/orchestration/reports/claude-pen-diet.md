# PEN-DIET: taming pen feeds from the species' diet

Branch `claude/mmo-pen-diet` (on `claude/mmo-studio-doc` → `claude/mmo-overhaul@fc08395e`). Pilot of
the studio workflow (`docs/orchestration/reports/claude-studio-workflow.md` section 8). Approved by
Milan 2026-10-30 17:15. Built in the cloud thread; push only, the build thread merges.

## What shipped

- `TamingPen.feed` eats one item of the occupant's taming diet: first preferred food found in the bag
  (wait x0.6, unchanged rate), else first accepted food (x0.8, `# ASSUMPTION`, Open Questions P7).
  Off-diet food, `spoiled_meat` and `rot` are refused before anything is eaten.
- One shared picker: `FieldTame.diet_food_in_bag(inv, def)`; `FieldTame.food_in_bag` now calls it
  after its lock check (field behaviour unchanged). The pen skips the capture-technique lock
  (`# ASSUMPTION`: the animal is already caught).
- Bug fixed: the 5 s floor no longer lengthens a nearly finished wait (0.15 s fed used to become 5 s).
  At 5 s or less left the pen now refuses food and eats nothing ("Almost tamed: it does not need more food.").
- Pen screen: button "Feed" (was "Feed meat"); a refusal shows `TamingPen.feed_hint`, e.g.
  "Needs berry or herb leaf (or fibre stalk) in your bag."
- Docs: `docs/current/creatures-capture-taming.md`, `docs/current/ui-screens.md` (E2 row), Open
  Questions P7 appended. Brief and design review in `docs/orchestration/briefs/`.

Player-visible change: a zebraceratops (first tame) can now be pen-fed berries / herb leaves; raptor
meat no longer works on herbivores. Carnivores prefer raw meat; raptor meat still works at x0.8.

## Gate (cloud x86 box, Godot 4.7.1 Linux)

- `t_pen_diet` PASS on the branch; on the base it FAILS (herbivore ate raptor meat, no x0.8, no raw-meat
  preference, floor, plus the missing refusal property).
- `t_w2_skills t_tame t_stationstate t_uiworld t_tamingodds t_foodtorpor` PASS; `t_save` PASS (run
  before the final edits; the pen save format did not change). No SCRIPT ERROR / Parse Error in any log.
- `tools/smoke.sh --no-import` SMOKE PASS.
- Not run here: the full suite (integrator runs it on the Mac per `merge-gate`), `capture_lab`
  (windowed; its feed at 0.15 s left is now refused, the pen still finishes on its own).

## Reviews

- Design (goldfish round 1): 5 Major, 4 Nit, all resolved; see `briefs/pen-diet.review.md`.
- Branch (goldfish round 1): 2 Major (report not committed; a feed under 5 s ate food for nothing),
  1 Major (refusal text compared case-insensitively), 5 Nit (missing fish / no-diet / berry-count
  cases, loose `Array` param, commit wording). All fixed in the follow-up commit; `capture_lab`'s
  0.15 s feed is now simply refused (it never checked the result).

## Known gaps (not in scope)

- Compsognathus eats berries but its `swarm` archetype makes the pen screen's diet tile say Carnivore
  (`CreatureDef.is_herbivore_diet`). Spec 02 names an omnivore group with no data field yet.
- Food quality/perks don't change the feed effect. Feeding affects the wait only, not success odds.

## HUMAN

Milan: open a pen with a captured zebraceratops and press Feed with no berries in the bag; the line
should read clearly. Merged is not verified until then.

## Pilot notes on the workflow

- Brief + design review cost one lead pass and one subagent; the review caught a parallel system,
  a latent bug, a stale doc and four tests that could not fail. Worth it.
- Mistake: the first code went in before the design review finished. Next time, review first.
- The x86 box is fine for logic tests (t_save took 464 s here).
