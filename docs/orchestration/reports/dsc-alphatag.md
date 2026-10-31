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
the name, no "Alpha" word in the name, plain-text bracket form, `HuntHud.alpha_tag_pos` geometry for the
drawn target plate, the size rule (the alpha floor beats every species' top normal roll, 40 made alphas all
inside the range), refusals on every capture path (window, feeding, `Hunt.use_net` on a live target, a
forced-success net that bags nothing and frees nothing, the field-tame action, the pen stack,
`capturable()`), pool drops over 60 seeded rolls, `alpha_extras` adding pool stacks, a real alpha corpse
(death -> Corpse -> `ButcherLoot.roll_into`) holding pool loot while a normal corpse of the same species
holds none, and no normal butchering table naming a pool item. `t_natures`, `t_capture09`, `t_tame`, `t_genetics`, `t_fieldhud`,
`t_uiworld`, `t_butcher`, `t_gather`, `t_data`, `run_all` and `tools/smoke.sh` (`SMOKE PASS`) all pass.

## What the next agent needs
- G12 (rename the pack leader so "Alpha" means one thing) is still open; if it lands, drop the
  `_is_pack_alpha` exception in `CreatureNatures.display_title` and the pack-leader assertions in
  `t_natures`.
- Alpha item art: both new items borrow a raptor icon (`icons_manifest.json` aliases).
- No recipe uses `alpha_hide` / `alpha_fang`; they are `source_pending` so `t_data`'s reachability walk stays
  honest. The alpha pool is per species in data, so adding a species override needs no code.
- Purse: no Meshy credits spent (none needed).

## Integrator follow-up (2026-10-30): merge onto canon, t_data fixed
Canon `origin/claude/mmo-overhaul` (3d5d84b0) merged in (merge commit; no conflict markers, Open Questions
keeps both canon's TU9/TU10 and ALPHATAG AT1-AT7). Canon alone passed `t_data`; the merged tree failed it on
five recipes (`improvised_stone_knife`, `work_axe`, `work_pick`, `slingshot`, `hoe`): their primary slot is
`blade_mat`/`bone`, which `alpha_fang` fills, and `ProgressionScaling.material_tier` maps an untagged item's
`hardness` through `HARDNESS_TIERS` — hardness 4 is `copper`. So the alpha item made those stone-rate recipes
read as copper-tier primaries with no Lv 30 gate.

Root fix in data, not the test: `alpha_fang` now declares `"material_tier": "bone"` in
`default_attributes` (it is a bone/talon part, and `bone` matches its category tags and the rung it belongs
to), so the tier lookup returns `bone` instead of guessing from hardness. `t_data` is untouched and PASSes
(`items=268 recipes=188`). Also re-ran `--import` afterwards, because the merge brought new `class_name`s
(Tasks, ItemTags, TribeWork, CurrencyBar, TribeAssignPicker) and a stale class cache broke every script.

Gate: `verify_alphatag.sh` -> VERIFY PASS (t_data, t_alphas, t_genetics, t_capture09, t_tame, run_all, smoke,
report). Docs: AT6 in `docs/vision/WildLandsMMO_Open_Questions.md` and the alpha loot pool paragraph in
`docs/current/creatures-capture-taming.md` now record the tier tag and why it exists.

Convention for later data work: a non-metal item whose `hardness` is 4 or more must declare
`default_attributes.material_tier`, otherwise `ProgressionScaling.material_tier` maps it onto the metal half of
the ladder and every recipe slot it fills inherits that tier. `t_data` was not changed.

## Re-merge (2026-10-30 03:01Z): new canon (FOODTORPOR, SLOWLEVELS, CREATURECHIPS, CHASESPRINT)
`origin/claude/mmo-overhaul` moved to 303c122e; merged into `claude/mmo-alphatag` (merge commit a76e2a71,
no conflict markers left). Conflicts and how both intents were kept:
- `game/data/items.json` — the merge had interleaved ALPHATAG's tail rows (`alpha_hide`, `alpha_fang`) with
  FOODTORPOR's (`spoiled_meat`, `rot`, `narcoberry`, `sedative`, `tranquilizer_dart`); resolved by keeping every
  row from both sides (275 items, no duplicate ids, valid JSON).
- `game/scripts/server/world_facade.gd` `add_creature` — kept both `"torpor": 0.0` (FOODTORPOR) and
  `"alpha": false` (ALPHATAG) in the spawned-creature dictionary.
- `game/scripts/ui/hunt_hud.gd` `_draw_target_plate` — kept canon's taller block (`HudBuffRow.CHIP` row) and
  ALPHATAG's gold prefix tag: `block` height is canon's, the ALPHA chip still shifts the name and the ellipsis
  width via `prefix_w`.
- Docs auto-merged; `docs/vision/WildLandsMMO_Open_Questions.md` keeps both the FOODTORPOR section and
  ALPHATAG AT1-AT7.

Test fix the new canon required (not a loosening): FOODTORPOR made the capture window require torpor past the
KO threshold as well as weakness. `t_alphas._test_no_tame` now sets `torpor` past `FieldTame.torpor_ko_frac()`
on both animals before asserting "normal animal is in the window / alpha is not", which is the same rule the
canon's own `t_tame` uses. Alphas are still refused on every path.

Gate: `verify_alphatag.sh` (now includes `t_data`) -> **VERIFY PASS**: t_data, t_alphas, t_genetics,
t_capture09, t_tame, run_all, smoke, report. Nothing pushed.

Gate log for this re-merge: `.dsc/verify_merge.log` (VERIFY PASS, exit 0).

## Re-merge 2026-10-29 (Claude, canon 0ee384b9: TUTTOWN, TUTORIAL ISLAND, LABSPAWN on top of FOODTORPOR)

- Only conflict this time: `docs/vision/WildLandsMMO_Open_Questions.md` — kept ALPHATAG AT1-AT7 and canon's
  TUTTOWN TT1-TT6. `items.json` / `world_facade.gd` were already resolved in the previous re-merge (275 items,
  both `torpor` and `alpha` keys) and merged clean now.
- Torpor knock-out: `Creature.add_torpor` only collapses an animal when `FieldTame.capture_window` is true,
  which is false for an alpha, so an alpha can never be knocked out into capture; the server's `_tame` /
  `_capture` refuse `alpha` before `window_open`. `t_alphas._test_no_tame` now also doses a weak alpha to full
  torpor and asserts no `knockdown`.
- t_data root cause (copper-tier primary on improvised_stone_knife / work_axe / work_pick): `alpha_fang` is
  `blade_mat`+`talon` with `hardness` 4, and `ProgressionScaling.material_tier` maps untagged hardness 4 to
  copper. Fixed at the item (`material_tier: "bone"`), t_data untouched.
- Gate: t_data, t_alphas, t_genetics, t_capture09, t_tame, t_foodtorpor, t_butcher, t_natures, run_all PASS;
  `tools/smoke.sh --no-import` SMOKE PASS.
