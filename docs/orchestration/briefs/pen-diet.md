# PEN-DIET: a penned animal eats its own diet, not raptor meat

Roadmap: `taming-pen` (next; this is the feeding slice only)   Branch: `claude/mmo-pen-diet`
Base: `claude/mmo-overhaul@fc08395e` (+ `claude/mmo-studio-doc`)   Approved: Milan 2026-10-30 17:15
("taming pen changes sound good"). Pilot of the studio workflow
(`docs/orchestration/reports/claude-studio-workflow.md` section 8).
Risk: FABLE-CRITICAL-adjacent (taming touches inventory consumption) but narrow: no save format
change, no new mechanic, no balance beyond the feed multiplier below. One goldfish reviewer + save check.

## Binding sources

- Spec 02 (`docs/design/durango-prompts/02_dinosaur_taming_and_companions.md:9`): "offer appropriate
  food to affect duration or chance ... Diet groups herbivore/carnivore/omnivore; validate food items
  and consume them exactly once ... Handle destroyed pen, full output/storage, duplicate completion,
  and reconnect/reload."
- Species data already carries the diet: `game/data/creatures/*.json` `taming.preferred_food` /
  `taming.accepted_food` (e.g. zebraceratops berry, herb_leaf / fibre_stalk; velociraptor raw_meat /
  fish, raptor_meat; compsognathus berry, herb_leaf / fibre_stalk, raw_meat).
- Field feeding already honours it: `FieldTame.food_in_bag` (preferred first, then accepted) and
  `feed_value` (preferred 1.0, accepted 0.5), `game/scripts/pets/field_tame.gd:107-125`.
- Today's pen (`game/scripts/world/taming_pen.gd:199`): `feed` only looks for `raptor_meat`, for any
  species, and cuts `remaining` to 60 % (floor 5 s). UI text: "Needs raptor meat in your bag"
  (`game/scripts/ui/taming_pen_ui.gd:385`). This is the discrepancy (report D3).
- Already true and must stay true: a finished animal waiting for a bonded slot refuses food and
  nothing is eaten (`game/tests/t_w2_skills.gd:459`).

## Open questions (no Milan gate; defaults marked `# ASSUMPTION:` in code)

1. How much an accepted (non-preferred) food helps. Default: half the preferred cut, mirroring
   field feeding's 1.0 / 0.5: preferred x0.6 (unchanged), accepted x0.8.
2. Spoiled food. Spoilage turns meat into `spoiled_meat` and food into `rot`
   (`game/scripts/items/spoilage.gd`); neither is in any diet list, so they are refused. No extra rule.
3. Food quality / perks on the eaten instance: ignored for now (spec 02 is silent).
4. Which item is eaten when several fit: the species' diet list decides (first preferred food
   found in the bag, else first accepted), exactly as `FieldTame.food_in_bag` does. The pen calls a
   shared `FieldTame.diet_food_in_bag(inv, def)` rather than a second picker (spec 02: reuse, no
   parallel systems). The capture-technique lock does not apply in the pen (`# ASSUMPTION`: the
   animal is already caught).
6. The 5 s floor used to lengthen a nearly finished wait (0.15 s fed became 5 s). Fixed: feeding
   never raises `remaining`.
7. Known gap, out of scope: compsognathus eats berries but its `swarm` archetype makes the pen
   screen's diet tile say Carnivore (`CreatureDef.is_herbivore_diet`); spec 02's omnivore group has
   no data field yet. Logged in the package report.
5. Carnivores: raptor meat becomes an accepted food (x0.8) for velociraptor & co, whose preferred
   food is raw meat (x0.6). That is the data's own diet, not a new rule.

## Scope

In: pen feed validates diet, eats exactly one fitting item after every refusal check, effect by
preferred/accepted, refusal text names the right food, Feed button label. Out: bonding, roles, care,
mood slider, store-in-pen, success-chance effects, new foods, UI layout changes.

## Owned files

- `game/scripts/world/taming_pen.gd` (feed, a food picker, refusal text)
- `game/scripts/ui/taming_pen_ui.gd` (button label + message only)
- `game/tests/t_pen_diet.gd` (new)
- `game/scripts/pets/field_tame.gd` (extract `diet_food_in_bag`, behaviour unchanged)
- `docs/current/creatures-capture-taming.md` (pen feeding paragraph), `docs/current/ui-screens.md` (E2 row)
- `docs/vision/WildLandsMMO_Open_Questions.md` (append row P7 for the x0.8 default; hot file, append only)
- `docs/orchestration/reports/claude-pen-diet.md` (new)
Hooks: none (`player_actions.gd` keeps calling `pen.feed(p)`). Hot files touched: none.

## Acceptance

| Item | Proof | Exists? |
|---|---|---|
| Herbivore pen accepts berry/herb leaf, eats exactly one, remaining x0.6 | `t_pen_diet` | new |
| Herbivore accepts fibre stalk at x0.8 when no preferred food is in the bag | `t_pen_diet` | new |
| Herbivore refuses raptor meat; bag unchanged; refusal reads exactly "Needs berry or herb leaf (or fibre stalk) in your bag." | `t_pen_diet` | new |
| Carnivore prefers raw meat (x0.6), takes raptor meat at x0.8 | `t_pen_diet` | new |
| Carnivore refuses berries (regression guard: also true on base) | `t_pen_diet` | new |
| Spoiled meat and rot refused, nothing eaten (regression guard) | `t_pen_diet` | new |
| Feeding never lengthens a wait under the 5 s floor | `t_pen_diet` | new |
| Preferred food picked over accepted when both are in the bag | `t_pen_diet` | new |
| Finished-and-waiting pen refuses food, nothing eaten | `t_w2_skills` | yes |
| Idle pen / empty pen refuses food (regression guard) | `t_pen_diet` | new |
| Pen state survives to_dict/from_dict mid-tame (regression guard) | `t_pen_diet` | new |
| The herbivore, accepted x0.8, raw-meat, refusal-text and floor checks fail on the base commit | `t_pen_diet` against base | — |
| HUMAN: Milan finds the Feed refusal line clear on the pen screen (pass = he does not ask for a rewrite) | Milan | — |

## Gate

`tools/all_tests.sh t_pen_diet t_w2_skills t_tame t_stationstate t_tamingodds t_foodtorpor t_save`,
`tools/smoke.sh --no-import`, then the full suite on the Mac by the integrator. On the x86 cloud box,
build-time budgets are advisory.

## Budget

3 attempts per failing gate, 2 hours total. No asset spend.

## Depends on / conflicts with

Depends on stationstate and foodtorpor (merged). In flight elsewhere: durability packages, town polish,
prop cards: none touch these files.
