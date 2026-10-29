# dsc — ALPHATAG (alpha animals per Milan's rules)

Owner, verbatim: "Alpha should be a tag in front of the name (prefix tag). The alpha animals are larger, not
tamable/capturable, and drop better loot (and special loot pools specific to alpha animals)".

## What shipped

**1. Prefix tag.** New `class_name AlphaChip` in `game/scripts/ui/alpha_chip.gd`: a solid gold chip with
`ALPHA` in caps, 14 px tall, 4 px before the name. Node form for the world plate, `draw_at` for the HUD's
drawn target plate, `rect_at`/`prefix_width` for layout and tests. A *genetic* alpha
(`CreatureGenetics.alpha`) wears it; a plain pack leader keeps the word "Alpha" inside its name (unchanged
acceptance in `t_natures`).

- World plate `ui/creature_plates.gd`: the chip sits at (8,1); the name label starts after it and its
  ellipsis budget shrinks by the same width.
- Target plate `ui/hunt_hud.gd` `_draw_target_plate`: the chip is drawn at the name's left, the name starts
  after it, and `target_rows["alpha"]` carries its rect.
- Plain-text surfaces draw no chip and use the bracket form: `CreatureNatures.tagged()`/`tagged_title()` →
  "[ALPHA] Deinonychus". Wired into `CreatureNatures.display_title`, `Corpse.species_display_name` /
  `species_lower_name` (carcass world pill, `Loot · …` chest title, "Nothing left on the …" notice).

**2. Larger.** No new number: `ai.json alpha.size_range` [1.24, 1.32], above every normal roll (species top
1.15 via `genetics.size_range`). `t_alphas` already pins "bigger than any normal roll".

**3. Not tamable / not capturable.** `FieldTame.ALPHA_REFUSAL` = "Alphas can't be tamed." Refused, with that
message, at every entry point:

| path | where |
|---|---|
| capture window / plate hint / feed | `FieldTame.capture_window`, `can_attempt`, `begin_window`, `apply_feed` |
| net | `Hunt.use_net`, `CaptureSystem.attempt` |
| field-tame tap | `PlayerActions.begin_field_tame` |
| pen | `TamingPen.refuse_stack` / `alpha_refusal` (refuses a cage whose stored genome is alpha, e.g. an old save) |
| capture flag | `Creature.capturable()` |
| server | `intent_handlers._tame` / `_capture` (creature record `alpha`) |

**4. Better loot + alpha-only pool.** `game/data/loot_tables.json` gains `"alpha"`: `pool` (default, all
species) = 1–2 `alpha_hide`, 1 `alpha_fang`; `by_species` overrides for `tyrannosaurus`, `tarbosaurus`,
`allosaurus`. `LootTables.alpha_pool(species)` / `alpha_pool_ids()` read it, `LootRoller.roll_alpha_pool`
rolls one instance per unit at the carcass level, and only `ButcherLoot.alpha_extras` (alpha carcass only)
calls it — before the guaranteed-trait pass, so pool parts carry a rare trait like the rest. Two new items in
`items.json` (`alpha_hide`, `alpha_fang`, both rare, `source_pending`), mirrored in `item_rarity.json` and
`icons_manifest.json` (each borrows a raptor icon).

## Assumptions (all logged in `docs/vision/WildLandsMMO_Open_Questions.md`, section ALPHATAG / AT1-AT7)
- AT1 tag text is caps `ALPHA`, chip only for genetic alphas (G12 stays open).
- AT2 bracket form `[ALPHA]` for plain-text surfaces.
- AT3 size stays 1.24-1.32x.
- AT4 one refusal sentence, owner's words.
- AT5 the pool contents and the three per-species overrides.
- AT6 item names, rarities and borrowed icons.
- AT7 pool parts get the ordinary guaranteed rare trait.

## Verified
`t_alphas` (9 sections, PASS): tag text and rect for alpha vs normal, plate chip visible and in front of
the name, no "Alpha" word in the name, plain-text bracket form, refusals on every capture path including a
forced-success net (nothing bagged, animal not freed), pen stack refusal, pool drops over 60 seeded rolls,
`alpha_extras` adding pool stacks, and normal carcasses never yielding a pool item (60 + 40 seeded rolls and
every normal butchering table). `t_natures`, `t_capture09`, `t_tame`, `t_genetics`, `t_fieldhud`,
`t_uiworld`, `t_butcher`, `t_gather`, `t_data`, `run_all` and `tools/smoke.sh` (`SMOKE PASS`) all pass.

## What the next agent needs
- G12 (rename the pack leader so "Alpha" means one thing) is still open; if it lands, drop the
  `_is_pack_alpha` exception in `CreatureNatures.display_title` and the pack-leader assertions in
  `t_natures`.
- Alpha item art: both new items borrow a raptor icon (`icons_manifest.json` aliases).
- No recipe uses `alpha_hide` / `alpha_fang`; they are `source_pending` so `t_data`'s reachability walk stays
  honest. The alpha pool is per species in data, so adding a species override needs no code.
- Purse: no Meshy credits spent (none needed).
