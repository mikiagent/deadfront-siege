# Crafting recipes — game data catalog

> Generated 2026-10-30 by `tools/docs_wiki/gen_game_data.py` from the build's own data. Never hand-edit; re-run after any balance pass.

`196 recipes` from `game/data/recipes.json`; station-only workflow times from `game/data/processing.json`.

These rows describe game data; a row alone does not prove that its output is playable. `min skill` is the recipe's minimum level gate when greater than zero; the gate also checks the resulting item level. Other gates may apply. `ability target` affects success chance rather than imposing a hard gate. `recipe max_level` is the configured output-level cap; the actual result also depends on materials, skill, and runtime bounds. Absent values use the defaults in `game/scripts/items/crafting.gd`: minimum 0, ability 0, and output cap 60.

## Cook roles (COOKROLES)

A cooking recipe's slots can carry a **role**, and a recipe that opts in (`"inherit": true`) carries
traits from the exact ingredient instance it consumed. Data: `game/data/cook_roles.json` (the six
roles, their accepted and excluded categories, per-role default inheritance flags, the trait →
FOODFX effect table, the role bonuses). Code: `game/scripts/items/cook_roles.gd` (`CookRoles`),
called from two seams in `game/scripts/items/crafting.gd` — `CookRoles.role_accepts` inside the
slot check and `CookRoles.apply_to_output` at the tail of the output build — plus
`game/scripts/items/food_effects.gd` for the dish's FOODFX bundle.

| role | accepts (item categories) | inherits by default |
|---|---|---|
| main | meat, fruit, crop, mushroom, cooked, vegetable (never spice) | traits, processed, flags |
| topping | fruit, herb, crop, mushroom, berry_crop | nothing (adds its role bonus) |
| sauce | juice, sauce, drink | nothing (adds its role bonus) |
| broth | water, broth | nothing (adds its role bonus) |
| spice | spice | nothing (adds its role bonus) |
| support | any | nothing |

- A role narrows a slot on top of the slot's own category check; it never replaces it, so a spice
  cannot fill a main slot.
- Inheritance is per slot, from that instance: `traits` (all non-rare, or a list of keys),
  `processed` (in-place cooking history), `flags`, and `rare` (the green attributes, off unless the
  slot says so). First carrier of a trait key wins in slot order; nothing stacks or averages, and a
  later duplicate is recorded as dropped.
- The dish stores what it inherited in `attributes.cooked_roles` and its role bonuses in
  `attributes.cooked_buffs`; `FoodEffects` evaluates the dish from that stored state, so a save and
  reload keep it.
- The six roled recipes in the tables below are `roled_grilled_meat` (main), `roled_berry_glazed_meat`
  (main + topping), `roled_broth_soup` (main + broth), `roled_spiced_stew` (main + spice + broth),
  `roled_herb_roast` (main + topping + support) and `roled_salad` (two topping slots, no inheritance).
  Test: `game/tests/t_cookroles.gd`.

## Outputs by primary material (OUTPUTS)

**Mechanism only, no recipe uses it yet.** Which families get keyed outputs, and whether a keyed output
needs its own cost and requirements, is an open question (Open Questions, 2026-10-28, A6).

One recipe can make a different item depending on the instance in its primary (slot 1) slot
(docs/design/durango-informed-improvements.md §7). A recipe adds `outputs_by_primary`, a map from a key
to an output row (`{"id", "count"}`); `output` stays as the fallback.

- Lookup: `Crafting.output_for(recipe, slot1_instance)` in `game/scripts/items/crafting.gd`. It tries the
  primary's declared tier (a `tier_<t>` category), then its item categories in def order, then its computed
  material tier (`ProgressionScaling.material_tier`, which reads untagged metal_shard as flint by hardness),
  and falls back to `output` when nothing matches or slot 1 is empty.
- Everything reads the output through that function: `build_output` (so the preview, the offline craft,
  `plan_fits`, `bag_preview` and the server `act.craft` op), and the craft screens through
  `CraftUI.output_row` (D1 list and detail, D3 result card, the station radial).
- Each output keeps its own item def (icon, mesh, stats). Slot-1 traits, `material_tier`, cook roles and
  rare-attribute carry work as before.
- `Data._load_recipes` logs an error when a keyed row names no item.
- A keyed row has no cost or requirements of its own: it uses the recipe's slots, station, skill node and gates.
- Test: `game/tests/t_outputs.gd` (builds keyed copies of the work knife/axe/pick recipes in memory).

## Hand crafting

| recipe | output | inputs | skill | min skill | ability target | recipe max_level | time (s) | process |
|---|---|---|---|---|---|---|---|---|
| `improvised_stone_knife` | Stone Work Knife x1 | blade_mat x1 (primary); handle x1; lashing x1 | weapon_tools | 0 | 0 | 60 | 2.0 | bind +1 |
| `club` | Wooden Club x1 | handle x1 (primary); lashing x1 | weapon_tools | 0 | 0 | 60 | 1.5 | bind +1 |
| `bandage` | Bandage x1 | herb x1 (primary); cloth x1 | tailoring | 0 | 0 | 60 | 1.0 | bind +1 |
| `pressure_dressing` | Pressure Dressing x1 | herb x1 (primary); cloth x2 | tailoring | 0 | 0 | 60 | 1.5 | bind +1 |
| `splint` | Splint x1 | wood x1 (primary); cloth x1 | tailoring | 0 | 0 | 60 | 1.5 | bind +1 |
| `capture_net_i` | Capture Net I x1 | lashing x2 (primary); handle x1 | weapon_tools | 0 | 0 | 60 | 2.0 | twist +1 |
| `twine` | Twine x1 | fibre x2 (primary) | processing | 0 | 0 | 60 | 1.0 | twist +1 |
| `thread` | Thread x1 | fibre x2 (primary) | tailoring | 0 | 0 | 60 | 1.0 | twist +1 |
| `charcoal` | Charcoal x1 | burnable x2 (primary) | processing | 0 | 0 | 60 | 3.0 | bake +1 |
| `campfire_kit` | Campfire Kit x1 | wood x2 (primary); tinder x1 | construction | 0 | 0 | 60 | 1.5 | bind +1 |
| `bonfire_kit` | Bonfire Kit x1 | wood x2 (primary); fibre x1 | construction | 0 | 0 | 60 | 1.5 | bind +1 |
| `stone_fire_pit_kit` | Stone Fire Pit Kit x1 | stone x6 (primary); wood x2 | construction | 0 | 0 | 60 | 2.5 | stack +1 |
| `stone_grill_kit` | Flat Stone Grill Kit x1 | stone x4 (primary); wood x2 | construction | 0 | 0 | 60 | 3.0 | bind +1 |
| `makeshift_taming_pen_kit` | Makeshift Taming Pen x1 | wood x4 (primary); lashing x2 | construction | 0 | 0 | 60 | 2.5 | bind +1 |
| `workbench_kit` | Workbench Kit x1 | wood x4 (primary); lashing x2 | construction | 0 | 0 | 60 | 2.0 | bind +1 |
| `mortar_kit` | Mortar Kit x1 | stone x3 (primary); wood x1 | construction | 0 | 0 | 60 | 3.0 | bind +1 |
| `well_kit` | Simple Well Kit x1 | stone x6 (primary); wood x4; lashing x2 | construction | 0 | 0 | 60 | 3.0 | bind +1 |
| `drying_rack_kit` | Drying Rack Kit x1 | wood x4 (primary); lashing x2 | construction | 0 | 0 | 60 | 1.5 | bind +1 |
| `smoker_kit` | Smoker Kit x1 | wood x6 (primary); stone x3; lashing x2 | construction | 0 | 0 | 60 | 4.0 | bind +1 |
| `crock_pot_kit` | Crock Pot Kit x1 | pot_clay x4 (primary); stone x2; wood x2 | construction | 0 | 0 | 60 | 3.0 | shape +1 |
| `straw_roll_kit` | Straw Roll x1 | fibre x3 (primary); lashing x1 | construction | 0 | 0 | 60 | 1.5 | bind +1 |
| `tent_kit` | Tent Kit x1 | cured_hide x2 (primary); wood x2; lashing x1 | tailoring | 0 | 0 | 60 | 2.0 | bind +1 |
| `canvas_tent_kit` | Canvas Tent Kit x1 | fibre x6 (primary); wood x3; lashing x2 | tailoring | 0 | 0 | 60 | 3.0 | bind +1 |
| `log_shelter_kit` | Log Shelter Kit (Planned) x1 | log x8 (primary); fibre x6; lashing x3 | construction | 0 | 0 | 60 | 4.0 | bind +1 |
| `cabin_bed_kit` | Cabin Bed Kit (Planned) x1 | plank x6 (primary); fibre x4; cured_hide x2 | construction | 0 | 0 | 60 | 4.0 | bind +1 |
| `basket_kit` | Basket Kit x1 | fibre x4 (primary); wood x1 | construction | 0 | 0 | 60 | 1.5 | twist +1 |
| `fence_kit` | Fence Segment x1 | wood x2 (primary) | construction | 0 | 0 | 60 | 1.0 | bind +1 |
| `gate_kit` | Gate x1 | wood x3 (primary); lashing x1 | construction | 0 | 0 | 60 | 1.5 | bind +1 |
| `sign_kit` | Sign x1 | wood x1 (primary) | construction | 0 | 0 | 60 | 1.0 | hammer +1 |
| `herbivore_feed` | Herbivore Feed x2 | fruit x1 (primary); stalk x1 | cooking | 0 | 0 | 60 | 1.5 | mix +0 |
| `field_small` | Small Field Kit x1 | earth x2 (primary) | farming | 0 | 0 | 1 | 2.0 | till +0 |
| `field_large` | Large Field Kit x1 | earth x4 (primary) | farming | 0 | 0 | 1 | 3.0 | till +0 |
| `toxin_coating` | Toxin Coating (3 Hits) x1 | herb x4 (primary) | processing | 0 | 0 | 60 | 4 | bind +1 |
| `venom_coating` | Toxin Coating (3 Hits) x3 | venom x1 (primary); herb x1 | processing | 0 | 0 | 60 | 4 | mix +1 |
| `rope_snare` | Rope Snare x1 | tendon x1 (primary); lashing x2; handle x1 | weapon_tools | 0 | 0 | 60 | 4 | bind +1 |
| `slingshot` | Bone Slingshot x1 | bone x1 (primary); handle x1; lashing x2 | weapon_tools | 0 | 0 | 60 | 3 | bind +1 |
| `stone_shot` | Stone Shot x5 | stone x1 (primary) | weapon_tools | 0 | 0 | 60 | 1 | bind +1 |
| `forge_kit` | Forge x1 | stone x10 (primary); pot_clay x4; fuel x2 | construction | 0 | 0 | 60 | 8.0 | bind +1 |
| `steamer_kit` | Steamer Kit x1 | wood x3 (primary); lashing x2; pot_clay x1 | construction | 0 | 0 | 60 | 5.0 | bind +1 |
| `hoe` | Hoe x1 | blade_mat x1 (primary); handle x1; lashing x1 | weapon_tools | 0 | 0 | 60 | 3.0 | bind +1 |
| `cloth_scrap` | Cloth Scrap x1 | fibre x2 (primary) | tailoring | 0 | 0 | 60 | 2.0 | bind +1 |
| `claim_stake` | Claim Stake x1 | wood x2 (primary); lashing x1 | construction | 0 | 0 | 60 | 3.0 | bind +1 |
| `seeds_flax` | Flax Seed x2 | flax_crop x1 (primary) | farming | 0 | 0 | 60 | 2.0 | extract +1 |
| `seeds_corn` | Corn Seed x2 | corn_crop x1 (primary) | farming | 0 | 0 | 60 | 2.0 | extract +1 |
| `seeds_wheat` | Wheat Seed x2 | wheat_crop x1 (primary) | farming | 0 | 0 | 60 | 2.0 | extract +1 |
| `seeds_berry` | Berry Seed x2 | berry_crop x1 (primary) | farming | 0 | 0 | 60 | 2.0 | extract +1 |
| `basic_bag` | Basic Bag x1 | dried_hide x2 (primary); fibre x3; lashing x1 | tailoring | 1 | 0 | 60 | 3.0 | sew +1 |
| `small_pouch` | Small Pouch x1 | dried_hide x1 (primary); fibre x2 | tailoring | 1 | 0 | 60 | 2.0 | sew +1 |
| `plank_shape` | Plank Shape x1 | log x1 (primary) | construction | 0 | 0 | 60 | 1.5 | shape +1 |
| `pillar_shape` | Pillar Shape x1 | log x2 (primary) | construction | 0 | 0 | 60 | 2.0 | shape +1 |
| `bowstring` | Bowstring x1 | strap x1 (primary) | construction | 0 | 0 | 60 | 1.0 | twist +1 |
| `strap` | Strap x1 | strap_material x1 (primary) | construction | 0 | 0 | 60 | 0.5 | twist +1 |
| `saddle_small` | Small Saddle x1 | dried_hide x3 (primary); fibre x3; lashing x2 | tailoring | 1 | 0 | 60 | 6.0 | sew +1 |
| `sedative` | Sedative x1 | spoiled_meat x1 (primary); narcoberry x2 | processing | 0 | 0 | 60 | 4 | mix +1 |
| `tranquilizer_dart` | Tranquilizer Dart x3 | sedative x1 (primary); bone x1 | weapon_tools | 0 | 0 | 60 | 4 | bind +1 |

## Crafting (workbench)

Stand-and-craft seconds are the recipe rows below; the station's own **real convergence times finish even while the player is away or offline**: `fine_plank` 12s, `trimmed_plank` 12s.

| recipe | output | inputs | skill | min skill | ability target | recipe max_level | time (s) | process |
|---|---|---|---|---|---|---|---|---|
| `work_axe` | Work Axe x1 | blade_mat x1 (primary); handle x1; lashing x1 | weapon_tools | 0 | 0 | 60 | 3.0 | bind +1 |
| `work_pick` | Work Pick x1 | blade_mat x1 (primary); handle x1; lashing x1 | weapon_tools | 0 | 0 | 60 | 3.0 | bind +1 |
| `rope` | Rope x1 | twine x3 (primary) | processing | 0 | 0 | 60 | 2.0 | twist +1 |
| `cloth` | Cloth x1 | thread x2 (primary) | tailoring | 0 | 0 | 60 | 2.0 | twist +1 |
| `hide_strap` | Hide Strap x2 | dried_hide x1 (primary) | processing | 0 | 0 | 60 | 2.0 | split +1 |
| `split_wood` | Split Wood x2 | log x1 (primary) | processing | 0 | 0 | 60 | 2.0 | split +1 |
| `plank` | Plank x1 | thick_pillar x2 (primary) | processing | 0 | 0 | 60 | 2.0 | hammer +1 |
| `taming_pen_medium_kit` | Medium Taming Pen x1 | wood x8 (primary); lashing x4; nails x2 | construction | 0 | 0 | 60 | 4.0 | bind +1 |
| `taming_pen_large_kit` | Large Taming Pen x1 | wood x12 (primary); lashing x6; stone x6; nails x4 | construction | 0 | 0 | 60 | 4.0 | bind +1 |
| `taming_pen_apex_kit` | Apex Taming Pen x1 | log x8 (primary); lashing x8; stone x12; nails x8 | construction | 0 | 0 | 60 | 4.0 | bind +1 |
| `empty_bucket` | Empty Bucket x1 | wood x2 (primary); lashing x1 | construction | 0 | 0 | 60 | 2.0 | bind +1 |
| `raid_maul` | Volcano Raid Maul x1 | tier_steel x4 (primary); handle x2; lashing x4 | weapon_tools | 55 | 95 | 60 | 12 | bind +1 |
| `raid_helm` | Raid Hide Helm x1 | tier_steel x2 (primary); cured_hide x4; lashing x2 | tailoring | 55 | 95 | 60 | 12 | bind +1 |
| `raid_cuirass` | Raid Hide Cuirass x1 | tier_steel x4 (primary); cured_hide x8; lashing x4 | tailoring | 55 | 95 | 60 | 12 | bind +1 |
| `raid_greaves` | Raid Hide Greaves x1 | tier_steel x2 (primary); cured_hide x4; lashing x2 | tailoring | 55 | 95 | 60 | 12 | bind +1 |
| `bone_hammer` | Dense Bone Hammer x1 | dense_bone x2 (primary); handle x1; lashing x2 | weapon_tools | 0 | 0 | 60 | 5 | bind +1 |
| `barbed_knife` | Barbed Talon Knife x1 | talon x1 (primary); handle x1; lashing x1 | weapon_tools | 0 | 0 | 60 | 4 | bind +1 |
| `heavy_snare` | Heavy Cable Snare x1 | scute x2 (primary); metal x2; lashing x2 | weapon_tools | 0 | 0 | 60 | 4 | bind +1 |
| `catapult_kit` | Field Catapult Kit x1 | wood x8 (primary); dense_bone x2; lashing x6 | weapon_tools | 0 | 0 | 60 | 8 | bind +1 |
| `toxin_pot` | Toxin Pot x1 | venom x1 (primary); stone x2 | weapon_tools | 0 | 0 | 60 | 4 | bind +1 |
| `travel_shirt` | Travel Shirt x1 | cloth x4 (primary); fibre x4 | tailoring | 0 | 0 | 60 | 4 | bind +1 |
| `travel_sleeves` | Travel Sleeves x1 | cloth x2 (primary); fibre x2 | tailoring | 0 | 0 | 60 | 4 | bind +1 |
| `travel_trousers` | Travel Trousers x1 | cloth x4 (primary); fibre x4 | tailoring | 0 | 0 | 60 | 4 | bind +1 |
| `forager_hood` | Forager Hood x1 | cloth x3 (primary); fibre x3; cured_hide x1 | tailoring | 10 | 50 | 60 | 8 | bind +1 |
| `forager_vest` | Forager Vest x1 | cloth x6 (primary); fibre x6; cured_hide x2 | tailoring | 10 | 50 | 60 | 8 | bind +1 |
| `forager_wraps` | Forager Arm Wraps x1 | cloth x3 (primary); fibre x3; cured_hide x1 | tailoring | 10 | 50 | 60 | 8 | bind +1 |
| `forager_leggings` | Forager Leggings x1 | cloth x6 (primary); fibre x6; cured_hide x2 | tailoring | 10 | 50 | 60 | 8 | bind +1 |
| `hide_bone_helm` | Hide and Bone Helm x1 | cured_hide x4 (primary); bone x3; lashing x2 | tailoring | 30 | 70 | 60 | 8 | bind +1 |
| `hide_bone_cuirass` | Hide and Bone Cuirass x1 | cured_hide x8 (primary); bone x6; lashing x4 | tailoring | 30 | 70 | 60 | 8 | bind +1 |
| `hide_bone_bracers` | Hide and Bone Bracers x1 | cured_hide x4 (primary); bone x3; lashing x2 | tailoring | 30 | 70 | 60 | 8 | bind +1 |
| `hide_bone_greaves` | Hide and Bone Greaves x1 | cured_hide x8 (primary); bone x6; lashing x4 | tailoring | 30 | 70 | 60 | 8 | bind +1 |
| `bone_knife` | Bone Knife x1 | tier_bone x1 (primary); handle x1; lashing x1 | weapon_tools | 0 | 0 | 60 | 4.0 | bind +1 |
| `bone_axe` | Bone Axe x1 | tier_bone x2 (primary); handle x1; lashing x1 | weapon_tools | 0 | 0 | 60 | 4.0 | bind +1 |
| `bone_pick` | Bone Pick x1 | tier_bone x2 (primary); handle x1; lashing x1 | weapon_tools | 0 | 0 | 60 | 4.0 | bind +1 |
| `bone_spear` | Bone Spear x1 | tier_bone x3 (primary); handle x1; lashing x2 | weapon_tools | 0 | 0 | 60 | 4.0 | bind +1 |
| `flint_knife` | Flint Knife x1 | tier_flint x1 (primary); handle x1; lashing x1 | weapon_tools | 0 | 0 | 60 | 3.0 | bind +1 |
| `flint_axe` | Flint Axe x1 | tier_flint x2 (primary); handle x1; lashing x1 | weapon_tools | 0 | 0 | 60 | 3.0 | bind +1 |
| `flint_pick` | Flint Pick x1 | tier_flint x2 (primary); handle x1; lashing x1 | weapon_tools | 0 | 0 | 60 | 3.0 | bind +1 |
| `flint_spear` | Flint Spear x1 | tier_flint x3 (primary); handle x1; lashing x2 | weapon_tools | 0 | 0 | 60 | 3.0 | bind +1 |
| `obsidian_knife` | Obsidian Knife x1 | tier_obsidian x1 (primary); handle x1; lashing x1 | weapon_tools | 0 | 0 | 60 | 3.0 | bind +1 |
| `obsidian_axe` | Obsidian Axe x1 | tier_obsidian x2 (primary); handle x1; lashing x1 | weapon_tools | 0 | 0 | 60 | 3.0 | bind +1 |
| `obsidian_pick` | Obsidian Pick x1 | tier_obsidian x2 (primary); handle x1; lashing x1 | weapon_tools | 0 | 0 | 60 | 3.0 | bind +1 |
| `obsidian_spear` | Obsidian Spear x1 | tier_obsidian x3 (primary); handle x1; lashing x2 | weapon_tools | 0 | 0 | 60 | 3.0 | bind +1 |
| `leather_helm` | Leather Helm x1 | cured_hide x3 (primary); lashing x2; thread x1 | tailoring | 20 | 60 | 60 | 6.0 | bind +1 |
| `leather_cuirass` | Leather Cuirass x1 | cured_hide x6 (primary); lashing x4; thread x2 | tailoring | 20 | 60 | 60 | 6.0 | bind +1 |
| `leather_bracers` | Leather Bracers x1 | cured_hide x3 (primary); lashing x2; thread x1 | tailoring | 20 | 60 | 60 | 6.0 | bind +1 |
| `leather_greaves` | Leather Greaves x1 | cured_hide x6 (primary); lashing x4; thread x2 | tailoring | 20 | 60 | 60 | 6.0 | bind +1 |
| `anvil_kit` | Anvil x1 | stone x6 (primary); ingot x2 | construction | 0 | 0 | 60 | 8.0 | bind +1 |
| `capture_net_ii` | Capture Net II x1 | rope x2 (primary); handle x1; lashing x1 | weapon_tools | 0 | 0 | 60 | 4.0 | bind +1 |
| `capture_net_iii` | Capture Net III x1 | rope x3 (primary); tendon x1; handle x1 | weapon_tools | 0 | 0 | 60 | 5.0 | bind +1 |
| `capture_net_iv` | Capture Net IV x1 | rope x3 (primary); tendon x2; metal x2 | weapon_tools | 0 | 0 | 60 | 6.0 | bind +1 |
| `capture_net_v` | Capture Net V x1 | rope x4 (primary); tendon x2; scute x2; tier_bronze x1 | weapon_tools | 0 | 0 | 60 | 8.0 | bind +1 |
| `stone_knife` | Stone Knife x1 | tier_stone x2 (primary); handle x1; lashing x2 | weapon_tools | 0 | 0 | 60 | 3.0 | bind +1 |
| `pillar` | Pillar x1 | log x2 (primary) | construction | 0 | 0 | 60 | 4.0 | bind +1 |
| `large_pouch` | Large Pouch x1 | dried_hide x2 (primary); fibre x4; lashing x2 | tailoring | 8 | 48 | 60 | 4.0 | sew +1 |
| `advanced_backpack` | Advanced Backpack x1 | cured_hide x2 (primary); cloth x2; lashing x2; fibre x2 | tailoring | 20 | 60 | 60 | 6.0 | sew +1 |
| `specialized_storage_bag` | Specialized Storage Bag x1 | cured_hide x3 (primary); cloth x3; rope x1; fibre x2 | tailoring | 30 | 70 | 60 | 8.0 | sew +1 |
| `trimmed_plank` | Trimmed Plank x1 | plank_shape x1 (primary) | processing | 0 | 0 | 60 | 12.0 | trim +1 |
| `fine_plank` | Fine Plank x1 | plank_shape x1 (primary) | processing | 0 | 0 | 60 | 12.0 | trim +1 |
| `salad` | Salad x1 | fruit x1 (primary); herb x1 | cooking | 0 | 0 | 60 | 2.0 | mix +0 |
| `roled_salad` | Salad x1 | fruit x1 (primary); herb x1 | cooking | 0 | 0 | 60 | 3.0 | mix +0 |
| `saddle_medium` | Medium Saddle x1 | cured_hide x5 (primary); lashing x3; wood x2 | tailoring | 12 | 55 | 60 | 8.0 | sew +1 |
| `saddle_large` | Large Saddle x1 | cured_hide x8 (primary); lashing x4; wood x3; bone x2 | tailoring | 25 | 65 | 60 | 10.0 | sew +1 |
| `spiky_armor` | Spiky Armor x1 | cured_hide x4 (primary); dense_bone x3; lashing x2 | tailoring | 30 | 60 | 60 | 8 | bind +1 |
| `spiky_armor_helmet` | Spiky Armor Helmet x1 | cured_hide x2 (primary); dense_bone x2; lashing x1 | tailoring | 30 | 60 | 60 | 8 | bind +1 |

## Drying (drying_rack)

Stand-and-craft seconds are the recipe rows below; the station's own **real convergence times finish even while the player is away or offline**: `dried_hide` 600s, `dry_meat` 600s.

| recipe | output | inputs | skill | min skill | ability target | recipe max_level | time (s) | process |
|---|---|---|---|---|---|---|---|---|
| `dried_hide` | Dried Hide x1 | green_hide x1 (primary) | processing | 0 | 0 | 60 | 4.0 | dry +1 |
| `dry_meat` | Dried Meat x1 | raw_meat x1 (primary) | processing | 0 | 0 | 60 | 8.0 | dry +1 |

## Smoking (smoker)

Stand-and-craft seconds are the recipe rows below; the station's own **real convergence times finish even while the player is away or offline**: `smoke_meat` 900s.

| recipe | output | inputs | skill | min skill | ability target | recipe max_level | time (s) | process |
|---|---|---|---|---|---|---|---|---|
| `smoke_meat` | Smoked Meat x1 | raw_meat x1 (primary) | processing | 0 | 0 | 60 | 12.0 | smoke +1 |

## Stewing (crock_pot)

Stand-and-craft seconds are the recipe rows below; the station's own **real convergence times finish even while the player is away or offline**: `camp_stew` 180s.

| recipe | output | inputs | skill | min skill | ability target | recipe max_level | time (s) | process |
|---|---|---|---|---|---|---|---|---|
| `camp_stew` | Camp Stew x1 | raw_meat x1 (primary); herb x1; fruit x1 | cooking | 0 | 0 | 60 | 6.0 | stew +1 |
| `roled_broth_soup` | Meat Broth x1 | meat x1 (primary); water x1 | cooking | 0 | 0 | 60 | 6.0 | brew +1 |
| `roled_spiced_stew` | Camp Stew x1 | meat x1 (primary); spice x1; water x1 | cooking | 0 | 0 | 60 | 7.0 | stew +1 |

## forge (forge)

| recipe | output | inputs | skill | min skill | ability target | recipe max_level | time (s) | process |
|---|---|---|---|---|---|---|---|---|
| `ingot` | Crude Ingot x1 | rough_ore x2 (primary); fuel x1 | processing | 0 | 0 | 60 | 4.0 | smelt +1 |
| `smelt_tin` | Tin Ingot x1 | tin_ore x2 (primary); fuel x1 | processing | 0 | 0 | 60 | 8.0 | smelt +1 |
| `smelt_copper` | Copper Ingot x1 | copper_ore_mat x2 (primary); fuel x1 | processing | 0 | 0 | 60 | 8.0 | smelt +1 |
| `alloy_bronze` | Bronze Ingot x2 | tier_copper x2 (primary); tin x1; fuel x1 | processing | 0 | 0 | 60 | 10.0 | alloy +1 |
| `smelt_iron` | Iron Ingot x1 | iron_ore x2 (primary); fuel x1 | processing | 0 | 0 | 60 | 24.0 | smelt +1 |
| `refine_steel` | Steel Ingot x1 | tier_iron x2 (primary); fuel x2 | processing | 0 | 0 | 60 | 14.0 | alloy +1 |
| `metal_nails` | Metal Nails x4 | ingot x1 (primary); fuel x1 | processing | 0 | 0 | 60 | 6.0 | smelt +1 |
| `silver_chunk` | Silver Chunk x1 | ore x2 (primary) | processing | 0 | 0 | 60 | 30.0 | smelt +1 |

## Fires and cooking

`bonfire`, `campfire` and `stone_fire_pit` all cook (their kits and rules are in
`docs/current/building.md` → "Fires"). The two temporary fires are on from placement; the permanent
stone fire pit cooks only after wood is loaded into it (`LOAD WOOD` hex: one branch buys 120 s of
burning), and every fire refuses cooking once it is out. Fires take their recipes from
`recipes_for_station(bonfire)` / `(campfire)`: the pit shares the bonfire list.

## campfire (campfire)

| recipe | output | inputs | skill | min skill | ability target | recipe max_level | time (s) | process |
|---|---|---|---|---|---|---|---|---|
| `campfire_skewer` | Skewer x1 | raw_meat x1 (primary); handle x1 | cooking | 0 | 0 | 19 | 3.0 | cook +1 |

## bonfire (bonfire)

| recipe | output | inputs | skill | min skill | ability target | recipe max_level | time (s) | process |
|---|---|---|---|---|---|---|---|---|
| `skewer` | Skewer x1 | meat x1 (primary); handle x1 | cooking | 0 | 0 | 19 | 3.0 | cook +1 |
| `cook_meatball` | Meatball x1 | meat x1 (primary) | cooking | 0 | 0 | 60 | 2.5 | cook +1 |
| `sashimi` | Sashimi x3 | raw_meat x1 (primary) | cooking | 0 | 0 | 60 | 2.0 | sashimi +0 |
| `boil` | Boiled Meat x1 | meat x1 (primary); water x1 | cooking | 0 | 0 | 60 | 3.0 | boil +1 |
| `herbed_meal` | Herbed Meal x1 | meat x1 (primary); herb x1 | cooking | 0 | 0 | 60 | 3.0 | cook +1 |
| `spiced_skewer` | Spiced Skewer x1 | meat x1 (primary); handle x1; spice x1 | cooking | 0 | 0 | 19 | 3.0 | cook +1 |
| `meat_broth` | Meat Broth x1 | raw_meat x1 (primary); water x1 | cooking | 0 | 0 | 60 | 3.0 | brew +0 |
| `herbal_tea` | Herbal Tea x1 | herb x1 (primary); water x1 | cooking | 0 | 0 | 60 | 2.5 | brew +0 |
| `roled_herb_roast` | Herbed Meal x1 | meat x1 (primary); herb x1; handle x1 | cooking | 0 | 0 | 60 | 4.0 | cook +1 |

## mortar (mortar)

| recipe | output | inputs | skill | min skill | ability target | recipe max_level | time (s) | process |
|---|---|---|---|---|---|---|---|---|
| `meatball_mix` | Meatball Mix x1 | raw_meat x1 (primary) | cooking | 0 | 0 | 60 | 1.5 | mince +1 |
| `carnivore_feed` | Carnivore Feed x2 | raw_meat x1 (primary); water x1 | cooking | 0 | 0 | 60 | 2.0 | mix +0 |
| `blue_dye` | Blue Dye x2 | coral x1 (primary) | processing | 0 | 0 | 60 | 3.0 | grind +1 |
| `fruit_fertilizer` | Fruit Fertilizer x1 | fruit x2 (primary); earth x1 | farming | 0 | 0 | 60 | 3.0 | grind +1 |
| `antivenom` | Antivenom x1 | venom x1 (primary); herb x2 | cooking | 0 | 0 | 60 | 4.0 | grind +1 |
| `antibiotic` | Antibiotic x1 | herb x3 (primary); mushroom x1 | cooking | 0 | 0 | 60 | 4.0 | grind +1 |
| `fruit_juice` | Fruit Juice x1 | fruit x1 (primary); water x1 | cooking | 0 | 0 | 60 | 2.0 | mix +0 |
| `cactus_juice` | Cactus Juice x1 | cactus x1 (primary); water x1 | cooking | 0 | 0 | 60 | 2.0 | mix +0 |
| `shaved_ice` | Shaved Ice x1 | ice x1 (primary) | cooking | 0 | 0 | 60 | 1.5 | mix +0 |
| `rot_compost` | Fruit Fertilizer x1 | rot x3 (primary); earth x1 | farming | 0 | 0 | 60 | 3.0 | grind +1 |

## stone_grill (stone_grill)

| recipe | output | inputs | skill | min skill | ability target | recipe max_level | time (s) | process |
|---|---|---|---|---|---|---|---|---|
| `stone_grill` | Grilled Meat x1 | raw_meat x1 (primary) | cooking | 0 | 0 | 60 | 3.0 | grill +1 |
| `roast` | Roast x1 | raw_meat x1 (primary) | cooking | 0 | 0 | 60 | 4.0 | roast +1 |
| `seasoned_roast` | Seasoned Roast x1 | raw_meat x1 (primary); spice x1 | cooking | 0 | 0 | 60 | 4.5 | roast +1 |
| `roled_grilled_meat` | Grilled Meat x1 | meat x1 (primary) | cooking | 0 | 0 | 60 | 3.0 | grill +1 |
| `roled_berry_glazed_meat` | Seasoned Roast x1 | meat x1 (primary); fruit x1 | cooking | 0 | 0 | 60 | 4.0 | glaze +1 |

## Steaming (steamer)

Stand-and-craft seconds are the recipe rows below; the station's own **real convergence times finish even while the player is away or offline**: `steam` 60s.

| recipe | output | inputs | skill | min skill | ability target | recipe max_level | time (s) | process |
|---|---|---|---|---|---|---|---|---|
| `steam` | Steamed Dish x1 | food x1 (primary) | cooking | 0 | 0 | 60 | 2.5 | steam +1 |

## well (well)

| recipe | output | inputs | skill | min skill | ability target | recipe max_level | time (s) | process |
|---|---|---|---|---|---|---|---|---|
| `fill_bucket` | Water Bucket x1 | bucket x1 (primary) | construction | 0 | 0 | 60 | 1.0 | fill +0 |

## anvil (anvil)

| recipe | output | inputs | skill | min skill | ability target | recipe max_level | time (s) | process |
|---|---|---|---|---|---|---|---|---|
| `copper_knife` | Copper Knife x1 | tier_copper x1 (primary); handle x1; lashing x1 | weapon_tools | 0 | 0 | 60 | 4.0 | bind +1 |
| `copper_axe` | Copper Axe x1 | tier_copper x2 (primary); handle x1; lashing x1 | weapon_tools | 0 | 0 | 60 | 4.0 | bind +1 |
| `copper_pick` | Copper Pick x1 | tier_copper x2 (primary); handle x1; lashing x1 | weapon_tools | 0 | 0 | 60 | 4.0 | bind +1 |
| `copper_sword` | Copper Sword x1 | tier_copper x3 (primary); handle x1; lashing x2 | weapon_tools | 0 | 0 | 60 | 4.0 | bind +1 |
| `bronze_knife` | Bronze Knife x1 | tier_bronze x1 (primary); handle x1; lashing x1 | weapon_tools | 0 | 0 | 60 | 4.0 | bind +1 |
| `bronze_axe` | Bronze Axe x1 | tier_bronze x2 (primary); handle x1; lashing x1 | weapon_tools | 0 | 0 | 60 | 4.0 | bind +1 |
| `bronze_pick` | Bronze Pick x1 | tier_bronze x2 (primary); handle x1; lashing x1 | weapon_tools | 0 | 0 | 60 | 4.0 | bind +1 |
| `bronze_sword` | Bronze Sword x1 | tier_bronze x3 (primary); handle x1; lashing x2 | weapon_tools | 0 | 0 | 60 | 4.0 | bind +1 |
| `iron_knife` | Iron Knife x1 | tier_iron x1 (primary); handle x1; lashing x1 | weapon_tools | 0 | 0 | 60 | 4.0 | bind +1 |
| `iron_axe` | Iron Axe x1 | tier_iron x2 (primary); handle x1; lashing x1 | weapon_tools | 0 | 0 | 60 | 4.0 | bind +1 |
| `iron_pick` | Iron Pick x1 | tier_iron x2 (primary); handle x1; lashing x1 | weapon_tools | 0 | 0 | 60 | 4.0 | bind +1 |
| `iron_sword` | Iron Sword x1 | tier_iron x3 (primary); handle x1; lashing x2 | weapon_tools | 0 | 0 | 60 | 4.0 | bind +1 |
| `steel_knife` | Steel Knife x1 | tier_steel x1 (primary); handle x1; lashing x1 | weapon_tools | 0 | 0 | 60 | 4.0 | bind +1 |
| `steel_axe` | Steel Axe x1 | tier_steel x2 (primary); handle x1; lashing x1 | weapon_tools | 0 | 0 | 60 | 4.0 | bind +1 |
| `steel_pick` | Steel Pick x1 | tier_steel x2 (primary); handle x1; lashing x1 | weapon_tools | 0 | 0 | 60 | 4.0 | bind +1 |
| `steel_sword` | Steel Sword x1 | tier_steel x3 (primary); handle x1; lashing x2 | weapon_tools | 0 | 0 | 60 | 4.0 | bind +1 |
| `copper_helm` | Copper Helm x1 | tier_copper x2 (primary); cured_hide x1; lashing x1 | tailoring | 35 | 75 | 60 | 6.0 | bind +1 |
| `copper_cuirass` | Copper Cuirass x1 | tier_copper x4 (primary); cured_hide x2; lashing x2 | tailoring | 35 | 75 | 60 | 6.0 | bind +1 |
| `copper_bracers` | Copper Bracers x1 | tier_copper x2 (primary); cured_hide x1; lashing x1 | tailoring | 35 | 75 | 60 | 6.0 | bind +1 |
| `copper_greaves` | Copper Greaves x1 | tier_copper x4 (primary); cured_hide x2; lashing x2 | tailoring | 35 | 75 | 60 | 6.0 | bind +1 |
| `bronze_helm` | Bronze Helm x1 | tier_bronze x2 (primary); cured_hide x1; lashing x1 | tailoring | 40 | 80 | 60 | 6.0 | bind +1 |
| `bronze_cuirass` | Bronze Cuirass x1 | tier_bronze x4 (primary); cured_hide x2; lashing x2 | tailoring | 40 | 80 | 60 | 6.0 | bind +1 |
| `bronze_bracers` | Bronze Bracers x1 | tier_bronze x2 (primary); cured_hide x1; lashing x1 | tailoring | 40 | 80 | 60 | 6.0 | bind +1 |
| `bronze_greaves` | Bronze Greaves x1 | tier_bronze x4 (primary); cured_hide x2; lashing x2 | tailoring | 40 | 80 | 60 | 6.0 | bind +1 |
| `iron_helm` | Iron Helm x1 | tier_iron x2 (primary); cured_hide x1; lashing x1 | tailoring | 50 | 90 | 60 | 6.0 | bind +1 |
| `iron_cuirass` | Iron Cuirass x1 | tier_iron x4 (primary); cured_hide x2; lashing x2 | tailoring | 50 | 90 | 60 | 6.0 | bind +1 |
| `iron_bracers` | Iron Bracers x1 | tier_iron x2 (primary); cured_hide x1; lashing x1 | tailoring | 50 | 90 | 60 | 6.0 | bind +1 |
| `iron_greaves` | Iron Greaves x1 | tier_iron x4 (primary); cured_hide x2; lashing x2 | tailoring | 50 | 90 | 60 | 6.0 | bind +1 |
| `steel_helm` | Steel Helm x1 | tier_steel x2 (primary); cured_hide x1; lashing x1 | tailoring | 55 | 95 | 60 | 6.0 | bind +1 |
| `steel_cuirass` | Steel Cuirass x1 | tier_steel x4 (primary); cured_hide x2; lashing x2 | tailoring | 55 | 95 | 60 | 6.0 | bind +1 |
| `steel_bracers` | Steel Bracers x1 | tier_steel x2 (primary); cured_hide x1; lashing x1 | tailoring | 55 | 95 | 60 | 6.0 | bind +1 |
| `steel_greaves` | Steel Greaves x1 | tier_steel x4 (primary); cured_hide x2; lashing x2 | tailoring | 55 | 95 | 60 | 6.0 | bind +1 |
| `metal_shards` | Metal Shard x2 | ingot x1 (primary) | processing | 0 | 0 | 60 | 4.0 | hammer +1 |
| `metal_stick` | Metal Stick x2 | chunk x1 (primary) | processing | 0 | 0 | 60 | 600.0 | hammer +1 |
| `metal_nails_from_chunk` | Metal Nails x4 | chunk x1 (primary) | processing | 0 | 0 | 60 | 120.0 | hammer +1 |

## Repairs — per-tier cost

One unit of the tier's material restores `restore_fraction` of max durability at the named station (ASSUMPTION values, W2-PROCESS/W2-CRAFT).

| tier | station | input | restore |
|---|---|---|---|
| `stone` | `workbench` | tier_stone x1 | 0.5 |
| `bone` | `workbench` | bone x1 | 0.5 |
| `flint` | `workbench` | tier_flint x1 | 0.5 |
| `obsidian` | `workbench` | tier_obsidian x1 | 0.5 |
| `copper` | `anvil` | tier_copper x1 | 0.5 |
| `bronze` | `anvil` | tier_bronze x1 | 0.5 |
| `iron` | `anvil` | tier_iron x1 | 0.5 |
| `steel` | `anvil` | tier_steel x1 | 0.5 |

