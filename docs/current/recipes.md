# Crafting recipes — the full implemented catalog

> Generated 2026-10-27 by `tools/docs_wiki/gen_game_data.py` from the build's own data. Never hand-edit; re-run after any balance pass.

`168 recipes` from `game/data/recipes.json`; station-only workflow times from `game/data/processing.json`.

## Hand crafting

| recipe | output | inputs | skill | time (s) | process |
|---|---|---|---|---|---|
| `improvised_stone_knife` | Stone Work Knife x1 | blade_mat x1 (primary); handle x1; lashing x1 | weapon_tools ≤ 60 | 2.0 | bind +1 |
| `club` | Wooden Club x1 | handle x1 (primary); lashing x1 | weapon_tools ≤ 60 | 1.5 | bind +1 |
| `bandage` | Bandage x1 | herb x1 (primary); cloth x1 | tailoring ≤ 60 | 1.0 | bind +1 |
| `pressure_dressing` | Pressure Dressing x1 | herb x1 (primary); cloth x2 | tailoring ≤ 60 | 1.5 | bind +1 |
| `splint` | Splint x1 | wood x1 (primary); cloth x1 | tailoring ≤ 60 | 1.5 | bind +1 |
| `capture_net_i` | Capture Net I x1 | lashing x2 (primary); handle x1 | weapon_tools ≤ 60 | 2.0 | twist +1 |
| `twine` | Twine x1 | fibre x2 (primary) | processing ≤ 60 | 1.0 | twist +1 |
| `thread` | Thread x1 | fibre x2 (primary) | tailoring ≤ 60 | 1.0 | twist +1 |
| `charcoal` | Charcoal x1 | burnable x2 (primary) | processing ≤ 60 | 3.0 | bake +1 |
| `campfire_kit` | Campfire Kit x1 | wood x2 (primary); tinder x1 | construction ≤ 60 | 1.5 | bind +1 |
| `bonfire_kit` | Bonfire Kit x1 | wood x2 (primary); fibre x1 | construction ≤ 60 | 1.5 | bind +1 |
| `stone_fire_pit_kit` | Stone Fire Pit Kit x1 | stone x6 (primary); wood x2 | construction ≤ 60 | 2.5 | stack +1 |
| `stone_grill_kit` | Flat Stone Grill Kit x1 | stone x4 (primary); wood x2 | construction ≤ 60 | 3.0 | bind +1 |
| `makeshift_taming_pen_kit` | Makeshift Taming Pen x1 | wood x4 (primary); lashing x2 | construction ≤ 60 | 2.5 | bind +1 |
| `workbench_kit` | Workbench Kit x1 | wood x4 (primary); lashing x2 | construction ≤ 60 | 2.0 | bind +1 |
| `mortar_kit` | Mortar Kit x1 | stone x3 (primary); wood x1 | construction ≤ 60 | 3.0 | bind +1 |
| `well_kit` | Simple Well Kit x1 | stone x6 (primary); wood x4; lashing x2 | construction ≤ 60 | 3.0 | bind +1 |
| `drying_rack_kit` | Drying Rack Kit x1 | wood x4 (primary); lashing x2 | construction ≤ 60 | 1.5 | bind +1 |
| `smoker_kit` | Smoker Kit x1 | wood x6 (primary); stone x3; lashing x2 | construction ≤ 60 | 4.0 | bind +1 |
| `crock_pot_kit` | Crock Pot Kit x1 | pot_clay x4 (primary); stone x2; wood x2 | construction ≤ 60 | 3.0 | shape +1 |
| `straw_roll_kit` | Straw Roll x1 | fibre x3 (primary); lashing x1 | construction ≤ 60 | 1.5 | bind +1 |
| `tent_kit` | Tent Kit x1 | cured_hide x2 (primary); wood x2; lashing x1 | tailoring ≤ 60 | 2.0 | bind +1 |
| `canvas_tent_kit` | Canvas Tent Kit x1 | fibre x6 (primary); wood x3; lashing x2 | tailoring ≤ 60 | 3.0 | bind +1 |
| `log_shelter_kit` | Log Shelter Kit (Planned) x1 | log x8 (primary); fibre x6; lashing x3 | construction ≤ 60 | 4.0 | bind +1 |
| `cabin_bed_kit` | Cabin Bed Kit (Planned) x1 | plank x6 (primary); fibre x4; cured_hide x2 | construction ≤ 60 | 4.0 | bind +1 |
| `basket_kit` | Basket Kit x1 | fibre x4 (primary); wood x1 | construction ≤ 60 | 1.5 | twist +1 |
| `fence_kit` | Fence Segment x1 | wood x2 (primary) | construction ≤ 60 | 1.0 | bind +1 |
| `gate_kit` | Gate x1 | wood x3 (primary); lashing x1 | construction ≤ 60 | 1.5 | bind +1 |
| `sign_kit` | Sign x1 | wood x1 (primary) | construction ≤ 60 | 1.0 | hammer +1 |
| `herbivore_feed` | Herbivore Feed x2 | fruit x1 (primary); stalk x1 | cooking ≤ 60 | 1.5 | mix +0 |
| `field_small` | Small Field Kit x1 | earth x2 (primary) | farming ≤ 1 | 2.0 | till +0 |
| `field_large` | Large Field Kit x1 | earth x4 (primary) | farming ≤ 1 | 3.0 | till +0 |
| `toxin_coating` | Toxin Coating (3 Hits) x1 | herb x4 (primary) | processing ≤ 60 | 4 | bind +1 |
| `venom_coating` | Toxin Coating (3 Hits) x3 | venom x1 (primary); herb x1 | processing ≤ 60 | 4 | mix +1 |
| `rope_snare` | Rope Snare x1 | tendon x1 (primary); lashing x2; handle x1 | weapon_tools ≤ 60 | 4 | bind +1 |
| `slingshot` | Bone Slingshot x1 | bone x1 (primary); handle x1; lashing x2 | weapon_tools ≤ 60 | 3 | bind +1 |
| `stone_shot` | Stone Shot x5 | stone x1 (primary) | weapon_tools ≤ 60 | 1 | bind +1 |
| `forge_kit` | Forge x1 | stone x10 (primary); pot_clay x4; fuel x2 | construction ≤ 60 | 8.0 | bind +1 |
| `steamer_kit` | Steamer Kit x1 | wood x3 (primary); lashing x2; pot_clay x1 | construction ≤ 60 | 5.0 | bind +1 |
| `hoe` | Hoe x1 | blade_mat x1 (primary); handle x1; lashing x1 | weapon_tools ≤ 60 | 3.0 | bind +1 |
| `cloth_scrap` | Cloth Scrap x1 | fibre x2 (primary) | tailoring ≤ 60 | 2.0 | bind +1 |
| `claim_stake` | Claim Stake x1 | wood x2 (primary); lashing x1 | construction ≤ 60 | 3.0 | bind +1 |
| `seeds_flax` | Flax Seed x2 | flax_crop x1 (primary) | farming ≤ 60 | 2.0 | extract +1 |
| `seeds_corn` | Corn Seed x2 | corn_crop x1 (primary) | farming ≤ 60 | 2.0 | extract +1 |
| `seeds_wheat` | Wheat Seed x2 | wheat_crop x1 (primary) | farming ≤ 60 | 2.0 | extract +1 |
| `seeds_berry` | Berry Seed x2 | berry_crop x1 (primary) | farming ≤ 60 | 2.0 | extract +1 |
| `basic_bag` | Basic Bag x1 | dried_hide x2 (primary); fibre x3; lashing x1 | tailoring ≤ 60 | 3.0 | sew +1 |
| `small_pouch` | Small Pouch x1 | dried_hide x1 (primary); fibre x2 | tailoring ≤ 60 | 2.0 | sew +1 |
| `plank_shape` | Plank Shape x1 | log x1 (primary) | construction ≤ 60 | 1.5 | shape +1 |
| `pillar_shape` | Pillar Shape x1 | log x2 (primary) | construction ≤ 60 | 2.0 | shape +1 |
| `strap` | Strap x1 | strap_material x1 (primary) | construction ≤ 60 | 0.5 | twist +1 |

## Crafting (workbench)

Stand-and-craft seconds are the recipe rows below; the station's own **real convergence times finish even while the player is away or offline**: `fine_plank` 12s, `trimmed_plank` 12s.

| recipe | output | inputs | skill | time (s) | process |
|---|---|---|---|---|---|
| `work_axe` | Work Axe x1 | blade_mat x1 (primary); handle x1; lashing x1 | weapon_tools ≤ 60 | 3.0 | bind +1 |
| `work_pick` | Work Pick x1 | blade_mat x1 (primary); handle x1; lashing x1 | weapon_tools ≤ 60 | 3.0 | bind +1 |
| `rope` | Rope x1 | twine x3 (primary) | processing ≤ 60 | 2.0 | twist +1 |
| `cloth` | Cloth x1 | thread x2 (primary) | tailoring ≤ 60 | 2.0 | twist +1 |
| `hide_strap` | Hide Strap x2 | dried_hide x1 (primary) | processing ≤ 60 | 2.0 | split +1 |
| `split_wood` | Split Wood x2 | log x1 (primary) | processing ≤ 60 | 2.0 | split +1 |
| `plank` | Plank x1 | split x2 (primary) | processing ≤ 60 | 2.0 | hammer +1 |
| `empty_bucket` | Empty Bucket x1 | wood x2 (primary); lashing x1 | construction ≤ 60 | 2.0 | bind +1 |
| `raid_maul` | Volcano Raid Maul x1 | tier_steel x4 (primary); handle x2; lashing x4 | weapon_tools ≤ 60 | 12 | bind +1 |
| `raid_helm` | Raid Hide Helm x1 | tier_steel x2 (primary); cured_hide x4; lashing x2 | tailoring ≤ 60 | 12 | bind +1 |
| `raid_cuirass` | Raid Hide Cuirass x1 | tier_steel x4 (primary); cured_hide x8; lashing x4 | tailoring ≤ 60 | 12 | bind +1 |
| `raid_greaves` | Raid Hide Greaves x1 | tier_steel x2 (primary); cured_hide x4; lashing x2 | tailoring ≤ 60 | 12 | bind +1 |
| `bone_hammer` | Dense Bone Hammer x1 | dense_bone x2 (primary); handle x1; lashing x2 | weapon_tools ≤ 60 | 5 | bind +1 |
| `barbed_knife` | Barbed Talon Knife x1 | talon x1 (primary); handle x1; lashing x1 | weapon_tools ≤ 60 | 4 | bind +1 |
| `heavy_snare` | Heavy Cable Snare x1 | scute x2 (primary); metal x2; lashing x2 | weapon_tools ≤ 60 | 4 | bind +1 |
| `catapult_kit` | Field Catapult Kit x1 | wood x8 (primary); dense_bone x2; lashing x6 | weapon_tools ≤ 60 | 8 | bind +1 |
| `toxin_pot` | Toxin Pot x1 | venom x1 (primary); stone x2 | weapon_tools ≤ 60 | 4 | bind +1 |
| `travel_shirt` | Travel Shirt x1 | cloth x4 (primary); fibre x4 | tailoring ≤ 60 | 4 | bind +1 |
| `travel_sleeves` | Travel Sleeves x1 | cloth x2 (primary); fibre x2 | tailoring ≤ 60 | 4 | bind +1 |
| `travel_trousers` | Travel Trousers x1 | cloth x4 (primary); fibre x4 | tailoring ≤ 60 | 4 | bind +1 |
| `forager_hood` | Forager Hood x1 | cloth x3 (primary); fibre x3; cured_hide x1 | tailoring ≤ 60 | 8 | bind +1 |
| `forager_vest` | Forager Vest x1 | cloth x6 (primary); fibre x6; cured_hide x2 | tailoring ≤ 60 | 8 | bind +1 |
| `forager_wraps` | Forager Arm Wraps x1 | cloth x3 (primary); fibre x3; cured_hide x1 | tailoring ≤ 60 | 8 | bind +1 |
| `forager_leggings` | Forager Leggings x1 | cloth x6 (primary); fibre x6; cured_hide x2 | tailoring ≤ 60 | 8 | bind +1 |
| `hide_bone_helm` | Hide and Bone Helm x1 | cured_hide x4 (primary); bone x3; lashing x2 | tailoring ≤ 60 | 8 | bind +1 |
| `hide_bone_cuirass` | Hide and Bone Cuirass x1 | cured_hide x8 (primary); bone x6; lashing x4 | tailoring ≤ 60 | 8 | bind +1 |
| `hide_bone_bracers` | Hide and Bone Bracers x1 | cured_hide x4 (primary); bone x3; lashing x2 | tailoring ≤ 60 | 8 | bind +1 |
| `hide_bone_greaves` | Hide and Bone Greaves x1 | cured_hide x8 (primary); bone x6; lashing x4 | tailoring ≤ 60 | 8 | bind +1 |
| `bone_knife` | Bone Knife x1 | tier_bone x1 (primary); handle x1; lashing x1 | weapon_tools ≤ 60 | 4.0 | bind +1 |
| `bone_axe` | Bone Axe x1 | tier_bone x2 (primary); handle x1; lashing x1 | weapon_tools ≤ 60 | 4.0 | bind +1 |
| `bone_pick` | Bone Pick x1 | tier_bone x2 (primary); handle x1; lashing x1 | weapon_tools ≤ 60 | 4.0 | bind +1 |
| `bone_spear` | Bone Spear x1 | tier_bone x3 (primary); handle x1; lashing x2 | weapon_tools ≤ 60 | 4.0 | bind +1 |
| `flint_knife` | Flint Knife x1 | tier_flint x1 (primary); handle x1; lashing x1 | weapon_tools ≤ 60 | 3.0 | bind +1 |
| `flint_axe` | Flint Axe x1 | tier_flint x2 (primary); handle x1; lashing x1 | weapon_tools ≤ 60 | 3.0 | bind +1 |
| `flint_pick` | Flint Pick x1 | tier_flint x2 (primary); handle x1; lashing x1 | weapon_tools ≤ 60 | 3.0 | bind +1 |
| `flint_spear` | Flint Spear x1 | tier_flint x3 (primary); handle x1; lashing x2 | weapon_tools ≤ 60 | 3.0 | bind +1 |
| `obsidian_knife` | Obsidian Knife x1 | tier_obsidian x1 (primary); handle x1; lashing x1 | weapon_tools ≤ 60 | 3.0 | bind +1 |
| `obsidian_axe` | Obsidian Axe x1 | tier_obsidian x2 (primary); handle x1; lashing x1 | weapon_tools ≤ 60 | 3.0 | bind +1 |
| `obsidian_pick` | Obsidian Pick x1 | tier_obsidian x2 (primary); handle x1; lashing x1 | weapon_tools ≤ 60 | 3.0 | bind +1 |
| `obsidian_spear` | Obsidian Spear x1 | tier_obsidian x3 (primary); handle x1; lashing x2 | weapon_tools ≤ 60 | 3.0 | bind +1 |
| `leather_helm` | Leather Helm x1 | cured_hide x3 (primary); lashing x2; thread x1 | tailoring ≤ 60 | 6.0 | bind +1 |
| `leather_cuirass` | Leather Cuirass x1 | cured_hide x6 (primary); lashing x4; thread x2 | tailoring ≤ 60 | 6.0 | bind +1 |
| `leather_bracers` | Leather Bracers x1 | cured_hide x3 (primary); lashing x2; thread x1 | tailoring ≤ 60 | 6.0 | bind +1 |
| `leather_greaves` | Leather Greaves x1 | cured_hide x6 (primary); lashing x4; thread x2 | tailoring ≤ 60 | 6.0 | bind +1 |
| `anvil_kit` | Anvil x1 | stone x6 (primary); ingot x2 | construction ≤ 60 | 8.0 | bind +1 |
| `capture_net_ii` | Capture Net II x1 | rope x2 (primary); handle x1; lashing x1 | weapon_tools ≤ 60 | 4.0 | bind +1 |
| `capture_net_iii` | Capture Net III x1 | rope x3 (primary); tendon x1; handle x1 | weapon_tools ≤ 60 | 5.0 | bind +1 |
| `capture_net_iv` | Capture Net IV x1 | rope x3 (primary); tendon x2; metal x2 | weapon_tools ≤ 60 | 6.0 | bind +1 |
| `capture_net_v` | Capture Net V x1 | rope x4 (primary); tendon x2; scute x2; tier_bronze x1 | weapon_tools ≤ 60 | 8.0 | bind +1 |
| `stone_knife` | Stone Knife x1 | tier_stone x2 (primary); handle x1; lashing x2 | weapon_tools ≤ 60 | 3.0 | bind +1 |
| `pillar` | Pillar x1 | log x2 (primary) | construction ≤ 60 | 4.0 | bind +1 |
| `large_pouch` | Large Pouch x1 | dried_hide x2 (primary); fibre x4; lashing x2 | tailoring ≤ 60 | 4.0 | sew +1 |
| `advanced_backpack` | Advanced Backpack x1 | cured_hide x2 (primary); cloth x2; lashing x2; fibre x2 | tailoring ≤ 60 | 6.0 | sew +1 |
| `specialized_storage_bag` | Specialized Storage Bag x1 | cured_hide x3 (primary); cloth x3; rope x1; fibre x2 | tailoring ≤ 60 | 8.0 | sew +1 |
| `trimmed_plank` | Trimmed Plank x1 | plank_shape x1 (primary) | processing ≤ 60 | 12.0 | trim +1 |
| `fine_plank` | Fine Plank x1 | plank_shape x1 (primary) | processing ≤ 60 | 12.0 | trim +1 |

## Drying (drying_rack)

Stand-and-craft seconds are the recipe rows below; the station's own **real convergence times finish even while the player is away or offline**: `dried_hide` 600s, `dry_meat` 600s.

| recipe | output | inputs | skill | time (s) | process |
|---|---|---|---|---|---|
| `dried_hide` | Dried Hide x1 | green_hide x1 (primary) | processing ≤ 60 | 4.0 | dry +1 |
| `dry_meat` | Dried Meat x1 | raw_meat x1 (primary) | processing ≤ 60 | 8.0 | dry +1 |

## Smoking (smoker)

Stand-and-craft seconds are the recipe rows below; the station's own **real convergence times finish even while the player is away or offline**: `smoke_meat` 900s.

| recipe | output | inputs | skill | time (s) | process |
|---|---|---|---|---|---|
| `smoke_meat` | Smoked Meat x1 | raw_meat x1 (primary) | processing ≤ 60 | 12.0 | smoke +1 |

## Stewing (crock_pot)

Stand-and-craft seconds are the recipe rows below; the station's own **real convergence times finish even while the player is away or offline**: `camp_stew` 180s.

| recipe | output | inputs | skill | time (s) | process |
|---|---|---|---|---|---|
| `camp_stew` | Camp Stew x1 | raw_meat x1 (primary); herb x1; fruit x1 | cooking ≤ 60 | 6.0 | stew +1 |

## forge (forge)

| recipe | output | inputs | skill | time (s) | process |
|---|---|---|---|---|---|
| `ingot` | Crude Ingot x1 | rough_ore x2 (primary); fuel x1 | processing ≤ 60 | 4.0 | smelt +1 |
| `smelt_tin` | Tin Ingot x1 | tin_ore x2 (primary); fuel x1 | processing ≤ 60 | 8.0 | smelt +1 |
| `smelt_copper` | Copper Ingot x1 | copper_ore_mat x2 (primary); fuel x1 | processing ≤ 60 | 8.0 | smelt +1 |
| `alloy_bronze` | Bronze Ingot x2 | tier_copper x2 (primary); tin x1; fuel x1 | processing ≤ 60 | 10.0 | alloy +1 |
| `smelt_iron` | Iron Ingot x1 | iron_ore x2 (primary); fuel x1 | processing ≤ 60 | 24.0 | smelt +1 |
| `refine_steel` | Steel Ingot x1 | tier_iron x2 (primary); fuel x2 | processing ≤ 60 | 14.0 | alloy +1 |

## campfire (campfire)

| recipe | output | inputs | skill | time (s) | process |
|---|---|---|---|---|---|
| `campfire_skewer` | Skewer x1 | raw_meat x1 (primary); handle x1 | cooking ≤ 19 | 3.0 | cook +1 |

## bonfire (bonfire)

| recipe | output | inputs | skill | time (s) | process |
|---|---|---|---|---|---|
| `skewer` | Skewer x1 | meat x1 (primary); handle x1 | cooking ≤ 19 | 3.0 | cook +1 |
| `cook_meatball` | Meatball x1 | meat x1 (primary) | cooking ≤ 60 | 2.5 | cook +1 |
| `sashimi` | Sashimi x3 | raw_meat x1 (primary) | cooking ≤ 60 | 2.0 | sashimi +0 |
| `boil` | Boiled Meat x1 | meat x1 (primary); water x1 | cooking ≤ 60 | 3.0 | boil +1 |
| `herbed_meal` | Herbed Meal x1 | meat x1 (primary); herb x1 | cooking ≤ 60 | 3.0 | cook +1 |
| `spiced_skewer` | Spiced Skewer x1 | meat x1 (primary); handle x1; spice x1 | cooking ≤ 19 | 3.0 | cook +1 |

## mortar (mortar)

| recipe | output | inputs | skill | time (s) | process |
|---|---|---|---|---|---|
| `meatball_mix` | Meatball Mix x1 | raw_meat x1 (primary) | cooking ≤ 60 | 1.5 | mince +1 |
| `carnivore_feed` | Carnivore Feed x2 | raw_meat x1 (primary); water x1 | cooking ≤ 60 | 2.0 | mix +0 |
| `blue_dye` | Blue Dye x2 | coral x1 (primary) | processing ≤ 60 | 3.0 | grind +1 |
| `fruit_fertilizer` | Fruit Fertilizer x1 | fruit x2 (primary); earth x1 | farming ≤ 60 | 3.0 | grind +1 |
| `antivenom` | Antivenom x1 | venom x1 (primary); herb x2 | cooking ≤ 60 | 4.0 | grind +1 |
| `antibiotic` | Antibiotic x1 | herb x3 (primary); mushroom x1 | cooking ≤ 60 | 4.0 | grind +1 |

## stone_grill (stone_grill)

| recipe | output | inputs | skill | time (s) | process |
|---|---|---|---|---|---|
| `stone_grill` | Grilled Meat x1 | raw_meat x1 (primary) | cooking ≤ 60 | 3.0 | grill +1 |
| `roast` | Roast x1 | raw_meat x1 (primary) | cooking ≤ 60 | 4.0 | roast +1 |
| `seasoned_roast` | Seasoned Roast x1 | raw_meat x1 (primary); spice x1 | cooking ≤ 60 | 4.5 | roast +1 |

## Steaming (steamer)

Stand-and-craft seconds are the recipe rows below; the station's own **real convergence times finish even while the player is away or offline**: `steam` 60s.

| recipe | output | inputs | skill | time (s) | process |
|---|---|---|---|---|---|
| `steam` | Steamed Dish x1 | food x1 (primary) | cooking ≤ 60 | 2.5 | steam +1 |

## well (well)

| recipe | output | inputs | skill | time (s) | process |
|---|---|---|---|---|---|
| `fill_bucket` | Water Bucket x1 | bucket x1 (primary) | construction ≤ 60 | 1.0 | fill +0 |

## anvil (anvil)

| recipe | output | inputs | skill | time (s) | process |
|---|---|---|---|---|---|
| `copper_knife` | Copper Knife x1 | tier_copper x1 (primary); handle x1; lashing x1 | weapon_tools ≤ 60 | 4.0 | bind +1 |
| `copper_axe` | Copper Axe x1 | tier_copper x2 (primary); handle x1; lashing x1 | weapon_tools ≤ 60 | 4.0 | bind +1 |
| `copper_pick` | Copper Pick x1 | tier_copper x2 (primary); handle x1; lashing x1 | weapon_tools ≤ 60 | 4.0 | bind +1 |
| `copper_sword` | Copper Sword x1 | tier_copper x3 (primary); handle x1; lashing x2 | weapon_tools ≤ 60 | 4.0 | bind +1 |
| `bronze_knife` | Bronze Knife x1 | tier_bronze x1 (primary); handle x1; lashing x1 | weapon_tools ≤ 60 | 4.0 | bind +1 |
| `bronze_axe` | Bronze Axe x1 | tier_bronze x2 (primary); handle x1; lashing x1 | weapon_tools ≤ 60 | 4.0 | bind +1 |
| `bronze_pick` | Bronze Pick x1 | tier_bronze x2 (primary); handle x1; lashing x1 | weapon_tools ≤ 60 | 4.0 | bind +1 |
| `bronze_sword` | Bronze Sword x1 | tier_bronze x3 (primary); handle x1; lashing x2 | weapon_tools ≤ 60 | 4.0 | bind +1 |
| `iron_knife` | Iron Knife x1 | tier_iron x1 (primary); handle x1; lashing x1 | weapon_tools ≤ 60 | 4.0 | bind +1 |
| `iron_axe` | Iron Axe x1 | tier_iron x2 (primary); handle x1; lashing x1 | weapon_tools ≤ 60 | 4.0 | bind +1 |
| `iron_pick` | Iron Pick x1 | tier_iron x2 (primary); handle x1; lashing x1 | weapon_tools ≤ 60 | 4.0 | bind +1 |
| `iron_sword` | Iron Sword x1 | tier_iron x3 (primary); handle x1; lashing x2 | weapon_tools ≤ 60 | 4.0 | bind +1 |
| `steel_knife` | Steel Knife x1 | tier_steel x1 (primary); handle x1; lashing x1 | weapon_tools ≤ 60 | 4.0 | bind +1 |
| `steel_axe` | Steel Axe x1 | tier_steel x2 (primary); handle x1; lashing x1 | weapon_tools ≤ 60 | 4.0 | bind +1 |
| `steel_pick` | Steel Pick x1 | tier_steel x2 (primary); handle x1; lashing x1 | weapon_tools ≤ 60 | 4.0 | bind +1 |
| `steel_sword` | Steel Sword x1 | tier_steel x3 (primary); handle x1; lashing x2 | weapon_tools ≤ 60 | 4.0 | bind +1 |
| `copper_helm` | Copper Helm x1 | tier_copper x2 (primary); cured_hide x1; lashing x1 | tailoring ≤ 60 | 6.0 | bind +1 |
| `copper_cuirass` | Copper Cuirass x1 | tier_copper x4 (primary); cured_hide x2; lashing x2 | tailoring ≤ 60 | 6.0 | bind +1 |
| `copper_bracers` | Copper Bracers x1 | tier_copper x2 (primary); cured_hide x1; lashing x1 | tailoring ≤ 60 | 6.0 | bind +1 |
| `copper_greaves` | Copper Greaves x1 | tier_copper x4 (primary); cured_hide x2; lashing x2 | tailoring ≤ 60 | 6.0 | bind +1 |
| `bronze_helm` | Bronze Helm x1 | tier_bronze x2 (primary); cured_hide x1; lashing x1 | tailoring ≤ 60 | 6.0 | bind +1 |
| `bronze_cuirass` | Bronze Cuirass x1 | tier_bronze x4 (primary); cured_hide x2; lashing x2 | tailoring ≤ 60 | 6.0 | bind +1 |
| `bronze_bracers` | Bronze Bracers x1 | tier_bronze x2 (primary); cured_hide x1; lashing x1 | tailoring ≤ 60 | 6.0 | bind +1 |
| `bronze_greaves` | Bronze Greaves x1 | tier_bronze x4 (primary); cured_hide x2; lashing x2 | tailoring ≤ 60 | 6.0 | bind +1 |
| `iron_helm` | Iron Helm x1 | tier_iron x2 (primary); cured_hide x1; lashing x1 | tailoring ≤ 60 | 6.0 | bind +1 |
| `iron_cuirass` | Iron Cuirass x1 | tier_iron x4 (primary); cured_hide x2; lashing x2 | tailoring ≤ 60 | 6.0 | bind +1 |
| `iron_bracers` | Iron Bracers x1 | tier_iron x2 (primary); cured_hide x1; lashing x1 | tailoring ≤ 60 | 6.0 | bind +1 |
| `iron_greaves` | Iron Greaves x1 | tier_iron x4 (primary); cured_hide x2; lashing x2 | tailoring ≤ 60 | 6.0 | bind +1 |
| `steel_helm` | Steel Helm x1 | tier_steel x2 (primary); cured_hide x1; lashing x1 | tailoring ≤ 60 | 6.0 | bind +1 |
| `steel_cuirass` | Steel Cuirass x1 | tier_steel x4 (primary); cured_hide x2; lashing x2 | tailoring ≤ 60 | 6.0 | bind +1 |
| `steel_bracers` | Steel Bracers x1 | tier_steel x2 (primary); cured_hide x1; lashing x1 | tailoring ≤ 60 | 6.0 | bind +1 |
| `steel_greaves` | Steel Greaves x1 | tier_steel x4 (primary); cured_hide x2; lashing x2 | tailoring ≤ 60 | 6.0 | bind +1 |
| `metal_shards` | Metal Shard x2 | ingot x1 (primary) | processing ≤ 60 | 4.0 | hammer +1 |

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

