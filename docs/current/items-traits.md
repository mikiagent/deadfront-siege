# Items & traits — the full catalog

> Generated 2026-10-27 by `tools/docs_wiki/gen_game_data.py` from the build's own data. Never hand-edit; re-run after any balance pass.

`246 items` from `game/data/items.json`; per-item consumption effects from `game/data/foods.json`; rarity palette from `game/data/item_rarity.json`.

Rarity: **common** `#a8adb3`, **uncommon** `#5cc864`, **rare** `#3c8cff`, **epic** `#b45cff`, **legendary** `#ffa424`.

Item *traits* are the attribute keys stamped on an instance: a def's `default_attributes` (its baseline), a gather material's latent attr (the yellow pip), an inherited attribute carried through crafting, or a butcher/gather roll. The pip/stacking rules live in `game/data/inventory.json`; bag specials in `game/data/bags.json`.

## Categories with counts

**food** (39) · **tool** (35) · **weapon** (29) · **building** (27) · **meat** (15) · **wood** (14) · **cooked** (13) · **fibre** (10) · **lashing** (9) · **blade** (9) · **armor_body** (9) · **armor_legs** (9) · **drink** (9) · **herb** (8) · **armor_head** (8) · **armor_arms** (8) · **metal** (7) · **medicine** (7) · **strap_material** (6) · **stone** (6) · **blade_mat** (6) · **ingot** (6) · **accessory** (6) · **bag** (6) · **ore** (5) · **bone** (5) · **fruit** (5) · **earth** (5) · **buff_food** (5) · **burnable** (4) · **log** (4) · **cloth** (4) · **hide** (4) · **tinder** (4) · **seed** (4) · **handle** (3) · **stalk** (3) · **raw_meat** (3) · **meal** (3) · **tier_bone** (3) · **uncut_hide** (3) · **water** (3) · **crop** (3) · **counter_supply** (3) · **clothing** (3) · **component** (3) · **brew** (3) · **fuel** (2) · **preserved** (2) · **green_hide** (2) · **berry_crop** (2) · **treasure** (2) · **dye** (2) · **bucket** (2) · **flax** (2) · **pet_feed** (2) · **juice** (2) · **split** (1) · **plank** (1) · **pillar** (1) · **tier_stone** (1) · **rough_ore** (1) · **tier_copper** (1) · **tier_bronze** (1) · **tier_iron** (1) · **tier_steel** (1) · **twine** (1) · **rope** (1) · **thread** (1) · **talon** (1) · **dried_hide** (1) · **cured_hide** (1) · **pot_clay** (1) · **tier_flint** (1) · **tier_obsidian** (1) · **ice** (1) · **cactus** (1) · **needle** (1) · **copper_ore_mat** (1) · **seasoning** (1) · **bait** (1) · **coral** (1) · **iron_ore** (1) · **mushroom** (1) · **spice** (1) · **raw** (1) · **steamed** (1) · **burnt** (1) · **corn** (1) · **wheat** (1) · **berry** (1) · **flax_crop** (1) · **corn_crop** (1) · **wheat_crop** (1) · **fertilizer** (1) · **tendon** (1) · **scute** (1) · **dense_bone** (1) · **venom** (1) · **ammunition** (1) · **siege_ammunition** (1) · **tin_ore** (1) · **tin** (1) · **plank_shape** (1) · **pillar_shape** (1) · **strap** (1) · **trimmed_plank** (1) · **fine_plank** (1) · **broth** (1) · **cold_food** (1)

## Every item

| id | name | lvl | stack | rarity | tool class | categories | attributes |
|---|---|---|---|---|---|---|---|
| `acacia_wood` | Acacia Wood | 1 | 10 | common | none | wood · log |  |
| `advanced_backpack` | Advanced Backpack | 1 | 1 | rare | none | accessory · bag |  |
| `antibiotic` | Antibiotic | 1 |  | uncommon | none | medicine |  |
| `antivenom` | Antivenom | 1 |  | uncommon | none | medicine |  |
| `anvil_kit` | Anvil | 1 | 1 | uncommon | none | building |  |
| `armor_scute` | Armor Scute | 1 | 999 | rare | none | scute · bone |  |
| `ash` | Ash | 1 | 20 | common | none | earth |  |
| `bamboo` | Bamboo | 1 | 20 | common | none | wood |  |
| `bandage` | Bandage | 1 | 10 | uncommon | none | medicine · cloth |  |
| `barbed_knife` | Barbed Talon Knife | 1 |  | rare | knife | weapon |  |
| `bark_strip` | Bark Strip | 1 | 20 | common | none | fibre · lashing · strap_material |  |
| `basic_bag` | Basic Bag | 1 | 1 | common | none | accessory · bag |  |
| `basket_kit` | Basket Kit | 1 | 2 | common | none | building |  |
| `berries` | Berries | 1 | 20 | common | none | food · herb · fruit · berry_crop |  |
| `berry` | Berry | 1 | 20 | common | none | food · herb · fruit · berry_crop |  |
| `berry_seed` | Berry Seed | 1 | 50 | common | none | seed · berry |  |
| `black_iron` | Black Iron | 1 | 10 | rare | none | ore · iron_ore | material_tier=iron |
| `blue_dye` | Blue Dye | 1 | 20 | uncommon | none | dye |  |
| `boiled_meat` | Boiled Meat | 1 | 20 | uncommon | none | food · cooked · meat |  |
| `bone` | Bone | 1 | 20 | common | none | bone · blade_mat · tier_bone | material_tier=bone |
| `bone_axe` | Bone Axe | 1 | 1 | common | axe | tool · weapon |  |
| `bone_hammer` | Dense Bone Hammer | 1 |  | rare | none | weapon |  |
| `bone_knife` | Bone Knife | 1 | 1 | common | knife | tool · blade · weapon |  |
| `bone_pick` | Bone Pick | 1 | 1 | common | pick | tool |  |
| `bone_spear` | Bone Spear | 1 | 1 | common | none | weapon |  |
| `bonfire_kit` | Bonfire Kit | 1 | 5 | common | none | building |  |
| `branch` | Branch | 1 | 20 | common | none | wood · handle · burnable | tint=#7a5a32 |
| `bronze_axe` | Bronze Axe | 1 | 1 | rare | axe | tool · weapon |  |
| `bronze_bracers` | Bronze Bracers | 1 | 1 | rare | none | armor_arms |  |
| `bronze_cuirass` | Bronze Cuirass | 1 | 1 | rare | none | armor_body |  |
| `bronze_greaves` | Bronze Greaves | 1 | 1 | rare | none | armor_legs |  |
| `bronze_helm` | Bronze Helm | 1 | 1 | rare | none | armor_head |  |
| `bronze_ingot` | Bronze Ingot | 1 | 999 | rare | none | metal · ingot · tier_bronze | material_tier=bronze, tint=#cd7f32, hardness=5 |
| `bronze_knife` | Bronze Knife | 1 | 1 | rare | knife | tool · blade · weapon |  |
| `bronze_pick` | Bronze Pick | 1 | 1 | rare | pick | tool |  |
| `bronze_sword` | Bronze Sword | 1 | 1 | rare | none | weapon |  |
| `burnt_food` | Burnt Food | 1 | 20 | common | none | food · burnt |  |
| `cabin_bed_kit` | Cabin Bed Kit (Planned) | 1 | 1 | rare | none | building |  |
| `cactus_flesh` | Cactus Flesh | 1 | 10 | common | none | food · cactus |  |
| `cactus_flower` | Cactus Flower | 1 |  | uncommon | none | herb · dye |  |
| `cactus_juice` | Cactus Juice | 1 | 20 | uncommon | none | drink · food · juice |  |
| `cactus_spine` | Cactus Spine | 1 | 20 | common | none | needle |  |
| `camp_stew` | Camp Stew | 1 | 20 | uncommon | none | food · cooked · meal |  |
| `campfire_kit` | Campfire Kit | 1 | 1 | common | none | building |  |
| `canvas_tent_kit` | Canvas Tent Kit | 1 | 1 | uncommon | none | building |  |
| `capture_net_i` | Capture Net I | 1 | 5 | uncommon | none | tool |  |
| `capture_net_ii` | Capture Net II | 1 | 5 | rare | none | tool |  |
| `capture_net_iii` | Capture Net III | 1 |  | rare | none | tool |  |
| `capture_net_iv` | Capture Net IV | 1 |  | epic | none | tool |  |
| `capture_net_v` | Capture Net V | 1 |  | epic | none | tool |  |
| `captured_animal` | Captured Animal | 1 | 1 | common | none | tool |  |
| `carnivore_feed` | Carnivore Feed | 1 | 30 | common | none | pet_feed · meat · food |  |
| `catapult_kit` | Field Catapult Kit | 1 | 1 | epic | none | building |  |
| `charcoal` | Charcoal | 1 | 20 | uncommon | none | fuel · burnable | tint=#2a2a2a |
| `claim_stake` | Claim Stake | 1 | 5 | common | none | building |  |
| `clay` | Clay | 1 | 20 | common | none | earth · pot_clay |  |
| `cloth` | Cloth | 1 | 10 | uncommon | none | cloth |  |
| `cloth_scrap` | Cloth Scrap | 1 | 20 | common | none | cloth |  |
| `club` | Wooden Club | 1 | 1 | common | none | weapon · handle |  |
| `coconut` | Coconut | 1 | 10 | common | none | food · fruit |  |
| `copper_axe` | Copper Axe | 1 | 1 | uncommon | axe | tool · weapon |  |
| `copper_bracers` | Copper Bracers | 1 | 1 | uncommon | none | armor_arms |  |
| `copper_cuirass` | Copper Cuirass | 1 | 1 | uncommon | none | armor_body |  |
| `copper_greaves` | Copper Greaves | 1 | 1 | uncommon | none | armor_legs |  |
| `copper_helm` | Copper Helm | 1 | 1 | uncommon | none | armor_head |  |
| `copper_ingot` | Copper Ingot | 1 | 999 | uncommon | none | metal · ingot · tier_copper | material_tier=copper, tint=#b87333, hardness=4 |
| `copper_knife` | Copper Knife | 1 | 1 | uncommon | knife | tool · blade · weapon |  |
| `copper_ore` | Copper Ore | 1 | 20 | uncommon | none | ore · copper_ore_mat | material_tier=copper |
| `copper_pick` | Copper Pick | 1 | 1 | uncommon | pick | tool |  |
| `copper_sword` | Copper Sword | 1 | 1 | uncommon | none | weapon |  |
| `coral` | Coral | 1 | 10 | rare | none | treasure · coral |  |
| `corn` | Corn | 1 | 30 | common | none | food · crop · fruit · stalk · corn_crop |  |
| `corn_seed` | Corn Seed | 1 | 50 | common | none | seed · corn |  |
| `crafters_meal` | Crafter's Meal | 1 | 20 | rare | none | food · cooked · meal · buff_food |  |
| `crock_pot_kit` | Crock Pot Kit | 1 | 1 | uncommon | none | building |  |
| `dense_bone` | Dense Bone | 1 | 999 | rare | none | dense_bone · bone · blade_mat · tier_bone |  |
| `dried_hide` | Dried Hide | 1 | 10 | uncommon | none | hide · uncut_hide · dried_hide · cured_hide |  |
| `dried_meat` | Dried Meat | 1 | 20 | uncommon | none | food · meat · preserved |  |
| `drip_coffee` | Drip Coffee | 1 | 20 | uncommon | none | drink · food · brew |  |
| `dry_grass` | Dry Grass | 1 | 30 | common | none | fibre · tinder |  |
| `drying_rack_kit` | Drying Rack Kit | 1 | 1 | uncommon | none | building |  |
| `dutch_coffee` | Dutch Coffee | 1 | 20 | rare | none | drink · food · brew · buff_food |  |
| `empty_bucket` | Empty Bucket | 1 | 5 | uncommon | none | tool · bucket |  |
| `fatigue_tonic` | Fatigue Restorative | 1 | 20 | uncommon | none | drink · medicine · food |  |
| `fence_kit` | Fence Segment | 1 | 20 | common | none | building |  |
| `fibre_stalk` | Fibre Stalk | 1 | 30 | common | none | fibre · stalk · strap_material |  |
| `field_large_kit` | Large Field Kit | 1 | 3 | common | none | building |  |
| `field_small_kit` | Small Field Kit | 1 | 5 | common | none | building |  |
| `fine_plank` | Fine Plank | 1 | 1 | common | none | wood · fine_plank |  |
| `fish` | Fish | 1 | 20 | common | none | meat · food · raw_meat |  |
| `flax` | Flax | 1 | 30 | common | none | fibre · crop · flax · flax_crop |  |
| `flax_seed` | Flax Seed | 1 | 50 | common | none | seed · flax |  |
| `flint` | Flint | 1 | 20 | uncommon | none | stone · tier_flint | material_tier=flint |
| `flint_axe` | Flint Axe | 1 | 1 | uncommon | axe | tool · weapon |  |
| `flint_knife` | Flint Knife | 1 | 1 | uncommon | knife | tool · blade · weapon |  |
| `flint_pick` | Flint Pick | 1 | 1 | uncommon | pick | tool |  |
| `flint_spear` | Flint Spear | 1 | 1 | uncommon | none | weapon |  |
| `forager_hood` | Forager Hood | 1 | 1 | uncommon | none | armor_head |  |
| `forager_leggings` | Forager Leggings | 1 | 1 | uncommon | none | armor_legs |  |
| `forager_vest` | Forager Vest | 1 | 1 | uncommon | none | armor_body |  |
| `forager_wraps` | Forager Arm Wraps | 1 | 1 | uncommon | none | armor_arms |  |
| `forge_kit` | Forge | 1 | 1 | uncommon | none | building |  |
| `fruit_fertilizer` | Fruit Fertilizer | 1 | 20 | common | none | fertilizer |  |
| `fruit_juice` | Fruit Juice | 1 | 20 | uncommon | none | drink · food · juice |  |
| `gate_kit` | Gate | 1 | 5 | uncommon | none | building |  |
| `grilled_meat` | Grilled Meat | 1 | 20 | uncommon | none | food · cooked · meat |  |
| `heavy_snare` | Heavy Cable Snare | 1 | 999 | epic | none | counter_supply |  |
| `herb_buff_meal` | Herbed Meal | 1 | 10 | rare | none | food · cooked · buff_food |  |
| `herb_leaf` | Herb Leaf | 1 | 20 | common | none | herb |  |
| `herbal_tea` | Herbal Tea | 1 | 20 | uncommon | none | drink · food · medicine |  |
| `herbivore_feed` | Herbivore Feed | 1 | 30 | common | none | pet_feed · food |  |
| `hide_bone_bracers` | Hide and Bone Bracers | 1 | 1 | rare | none | armor_arms |  |
| `hide_bone_cuirass` | Hide and Bone Cuirass | 1 | 1 | rare | none | armor_body |  |
| `hide_bone_greaves` | Hide and Bone Greaves | 1 | 1 | rare | none | armor_legs |  |
| `hide_bone_helm` | Hide and Bone Helm | 1 | 1 | rare | none | armor_head |  |
| `hide_strap` | Hide Strap | 1 | 20 | uncommon | none | lashing · hide |  |
| `hoe` | Hoe | 1 | 1 | uncommon | hoe | tool |  |
| `ice` | Ice | 1 | 10 | rare | none | water · ice |  |
| `ingot` | Crude Ingot | 1 | 10 | uncommon | none | metal · ingot | tint=#c0c4cc, hardness=4 |
| `iron_axe` | Iron Axe | 1 | 1 | rare | axe | tool · weapon |  |
| `iron_bracers` | Iron Bracers | 1 | 1 | rare | none | armor_arms |  |
| `iron_cuirass` | Iron Cuirass | 1 | 1 | rare | none | armor_body |  |
| `iron_greaves` | Iron Greaves | 1 | 1 | rare | none | armor_legs |  |
| `iron_helm` | Iron Helm | 1 | 1 | rare | none | armor_head |  |
| `iron_ingot` | Iron Ingot | 1 | 999 | rare | none | metal · ingot · tier_iron | material_tier=iron, tint=#9a9b9d, hardness=6 |
| `iron_knife` | Iron Knife | 1 | 1 | rare | knife | tool · blade · weapon |  |
| `iron_pick` | Iron Pick | 1 | 1 | rare | pick | tool |  |
| `iron_sword` | Iron Sword | 1 | 1 | rare | none | weapon |  |
| `large_pouch` | Large Pouch | 1 | 1 | uncommon | none | accessory · bag |  |
| `lava` | Lava Rock | 1 | 10 | rare | none | stone |  |
| `leather_bracers` | Leather Bracers | 1 | 1 | uncommon | none | armor_arms |  |
| `leather_cuirass` | Leather Cuirass | 1 | 1 | uncommon | none | armor_body |  |
| `leather_greaves` | Leather Greaves | 1 | 1 | uncommon | none | armor_legs |  |
| `leather_helm` | Leather Helm | 1 | 1 | uncommon | none | armor_head |  |
| `leech` | Leech | 1 | 10 | common | none | bait |  |
| `log_shelter_kit` | Log Shelter Kit (Planned) | 1 | 1 | rare | none | building |  |
| `makeshift_taming_pen` | Makeshift Taming Pen | 1 | 1 | common | none | building |  |
| `mango` | Mango | 1 | 10 | common | none | food · fruit |  |
| `marsh_herb` | Marsh Herb | 1 | 20 | common | none | herb |  |
| `meat_broth` | Meat Broth | 1 | 20 | uncommon | none | drink · food · broth |  |
| `meatball` | Meatball | 1 | 20 | uncommon | none | food · cooked · meat |  |
| `meatball_mix` | Meatball Mix | 1 | 20 | common | none | food · meat · raw |  |
| `metal_shard` | Metal Shard | 1 | 10 | uncommon | none | metal · blade_mat | tint=#b0b8c0, hardness=3 |
| `mortar_kit` | Mortar Kit | 1 | 1 | uncommon | none | building |  |
| `moss` | Moss | 1 |  | common | none | fibre · tinder |  |
| `mud` | Mud | 1 | 20 | common | none | earth |  |
| `mushroom` | Mushroom | 1 | 20 | common | none | food · mushroom · herb |  |
| `obsidian` | Obsidian | 1 | 10 | rare | none | stone · tier_obsidian | material_tier=obsidian |
| `obsidian_axe` | Obsidian Axe | 1 | 1 | uncommon | axe | tool · weapon |  |
| `obsidian_knife` | Obsidian Knife | 1 | 1 | uncommon | knife | tool · blade · weapon |  |
| `obsidian_pick` | Obsidian Pick | 1 | 1 | uncommon | pick | tool |  |
| `obsidian_spear` | Obsidian Spear | 1 | 1 | uncommon | none | weapon |  |
| `ochre` | Ochre | 1 | 20 | uncommon | none | earth |  |
| `ore` | Rough Ore | 1 | 10 | uncommon | none | ore · stone · rough_ore | tint=#6a5a4a |
| `palm_frond` | Palm Frond | 1 | 20 | common | none | fibre · strap_material |  |
| `pearl` | Pearl | 1 | 10 | rare | none | treasure |  |
| `peat` | Peat | 1 | 20 | common | none | tinder · fuel |  |
| `petals` | Petals | 1 | 20 | common | none | herb |  |
| `pillar` | Pillar | 1 | 5 | common | none | wood · pillar |  |
| `pillar_shape` | Pillar Shape | 1 | 1 | common | none | component · pillar_shape · wood |  |
| `pine_log` | Pine Log | 1 | 10 | common | none | wood · log |  |
| `plank` | Plank | 1 | 10 | common | none | wood · plank |  |
| `plank_shape` | Plank Shape | 1 | 1 | common | none | component · plank_shape · wood |  |
| `predator_tendon` | Predator Tendon | 1 | 999 | rare | none | tendon · lashing |  |
| `pressure_dressing` | Pressure Dressing | 1 | 5 | uncommon | none | medicine · cloth |  |
| `raid_cuirass` | Raid Hide Cuirass | 1 | 1 | epic | none | armor_body |  |
| `raid_greaves` | Raid Hide Greaves | 1 | 1 | epic | none | armor_legs |  |
| `raid_helm` | Raid Hide Helm | 1 | 1 | epic | none | armor_head |  |
| `raid_maul` | Volcano Raid Maul | 1 | 1 | legendary | none | weapon |  |
| `raptor_bone` | Raptor Bone | 1 | 10 | uncommon | none | bone · blade_mat · handle · tier_bone | hardness=2, tint=#d4c4a8, material_tier=bone |
| `raptor_hide` | Raptor Hide | 1 | 10 | uncommon | none | hide · uncut_hide · green_hide | feathered=1, tint=#6b5a3e |
| `raptor_meat` | Raptor Meat | 1 | 10 | uncommon | none | meat · food · raw_meat |  |
| `raptor_talon` | Raptor Talon | 1 | 5 | uncommon | none | bone · blade_mat · talon | hardness=3, tint=#c9b48a |
| `raw_hide` | Raw Hide | 1 | 10 | common | none | hide · uncut_hide · green_hide |  |
| `raw_meat` | Raw Meat | 1 | 20 | common | none | meat · food · raw_meat |  |
| `reed` | Reed | 1 | 30 | common | none | fibre · lashing · strap_material | tint=#8a9a4a |
| `resin` | Resin | 1 | 20 | uncommon | none | tinder |  |
| `roast` | Roast | 1 | 10 | uncommon | none | food · cooked · meat |  |
| `root` | Root | 1 | 20 | common | none | lashing · strap_material | tint=#5a4030 |
| `rope` | Rope | 1 | 10 | uncommon | none | lashing · rope |  |
| `rope_snare` | Rope Snare | 1 | 999 | uncommon | none | counter_supply |  |
| `salad` | Salad | 1 | 20 | uncommon | none | food · cooked · meal |  |
| `salt` | Salt | 1 | 20 | uncommon | none | seasoning |  |
| `sandstone` | Sandstone | 1 | 20 | uncommon | none | stone |  |
| `sashimi` | Sashimi | 1 | 30 | uncommon | none | food · cooked · meat |  |
| `seasoned_roast` | Seasoned Roast | 1 | 10 | rare | none | food · cooked · meat · buff_food |  |
| `shaved_ice` | Shaved Ice | 1 | 20 | uncommon | none | food · cold_food |  |
| `sign_kit` | Sign | 1 | 5 | common | none | building |  |
| `silver_ore` | Silver Ore | 1 | 20 | uncommon | none | ore |  |
| `skewer` | Skewer | 1 | 20 | uncommon | none | food · cooked · meat |  |
| `slingshot` | Bone Slingshot | 1 |  | uncommon | none | weapon |  |
| `small_pouch` | Small Pouch | 1 | 1 | common | none | accessory · bag |  |
| `smoked_meat` | Smoked Meat | 1 | 20 | uncommon | none | food · meat · preserved |  |
| `smoker_kit` | Smoker Kit | 1 | 1 | uncommon | none | building |  |
| `snow_pine` | Snow Pine | 1 | 10 | common | none | wood · log |  |
| `specialized_storage_bag` | Specialized Storage Bag | 1 | 1 | epic | none | accessory · bag |  |
| `spice_herb` | Spice Herb | 1 | 20 | common | none | herb · spice |  |
| `spiced_skewer` | Spiced Skewer | 1 | 20 | rare | none | food · cooked · buff_food · meat |  |
| `splint` | Splint | 1 | 5 | uncommon | none | medicine |  |
| `split_wood` | Split Wood | 1 | 20 | common | none | wood · split · burnable |  |
| `spring_water` | Spring Water | 1 | 20 | common | none | water · drink · food |  |
| `steamed_food` | Steamed Dish | 1 | 20 | uncommon | none | food · cooked · steamed |  |
| `steamer_kit` | Steamer Kit | 1 | 1 | common | none | building |  |
| `steel_axe` | Steel Axe | 1 | 1 | epic | axe | tool · weapon |  |
| `steel_bracers` | Steel Bracers | 1 | 1 | epic | none | armor_arms |  |
| `steel_cuirass` | Steel Cuirass | 1 | 1 | epic | none | armor_body |  |
| `steel_greaves` | Steel Greaves | 1 | 1 | epic | none | armor_legs |  |
| `steel_helm` | Steel Helm | 1 | 1 | epic | none | armor_head |  |
| `steel_ingot` | Steel Ingot | 1 | 999 | rare | none | metal · ingot · tier_steel | material_tier=steel, tint=#b8c2cc, hardness=7 |
| `steel_knife` | Steel Knife | 1 | 1 | epic | knife | tool · blade · weapon |  |
| `steel_pick` | Steel Pick | 1 | 1 | epic | pick | tool |  |
| `steel_sword` | Steel Sword | 1 | 1 | epic | none | weapon |  |
| `stone` | Stone | 1 | 20 | common | none | stone · blade_mat · tier_stone | tint=#8a8a8a, material_tier=stone |
| `stone_fire_pit_kit` | Stone Fire Pit Kit | 1 | 1 | uncommon | none | building |  |
| `stone_grill_kit` | Flat Stone Grill Kit | 1 | 1 | uncommon | none | building |  |
| `stone_knife` | Stone Knife | 1 | 1 | common | knife | weapon · blade · tool |  |
| `stone_knife_work` | Stone Work Knife | 1 | 1 | uncommon | knife | tool · blade · weapon |  |
| `stone_shot` | Stone Shot | 1 | 999 | uncommon | none | ammunition |  |
| `strap` | Strap | 1 | 1 | common | none | component · strap · lashing |  |
| `straw_roll_kit` | Straw Roll | 1 | 3 | common | none | building |  |
| `sulphur` | Sulphur | 1 | 20 | uncommon | none | earth |  |
| `tamed_animal` | Tamed Animal | 1 | 1 | rare | none | tool |  |
| `tea` | Tea | 1 | 20 | uncommon | none | drink · food · brew |  |
| `tent_kit` | Tent Kit | 1 | 1 | common | none | building |  |
| `thread` | Thread | 1 | 20 | uncommon | none | thread · fibre |  |
| `tin_ingot` | Tin Ingot | 1 |  | uncommon | none | metal · ingot · tin |  |
| `tin_ore` | Tin Ore | 1 |  | uncommon | none | ore · tin_ore |  |
| `toxin_coating` | Toxin Coating (3 Hits) | 1 | 999 | rare | none | counter_supply |  |
| `toxin_pot` | Toxin Pot | 1 | 999 | epic | none | siege_ammunition |  |
| `travel_shirt` | Travel Shirt | 1 | 1 | common | none | armor_body · clothing |  |
| `travel_sleeves` | Travel Sleeves | 1 | 1 | common | none | armor_arms · clothing |  |
| `travel_trousers` | Travel Trousers | 1 | 1 | common | none | armor_legs · clothing |  |
| `trimmed_plank` | Trimmed Plank | 1 | 1 | common | none | wood · trimmed_plank |  |
| `twine` | Twine | 1 | 20 | common | none | lashing · fibre · twine |  |
| `venom_gland` | Venom Gland | 1 | 999 | rare | none | venom |  |
| `vine` | Vine | 1 | 20 | common | none | fibre · lashing · strap_material |  |
| `water_bucket` | Water Bucket | 1 | 5 | uncommon | none | water · bucket · tool |  |
| `well_kit` | Simple Well Kit | 1 | 1 | rare | none | building |  |
| `wheat` | Wheat | 1 | 30 | common | none | crop · stalk · wheat_crop |  |
| `wheat_seed` | Wheat Seed | 1 | 50 | common | none | seed · wheat |  |
| `willow_wood` | Willow Wood | 1 | 10 | common | none | wood |  |
| `wood_log` | Log | 1 | 10 | common | none | wood · log · burnable | tint=#6b4a28 |
| `work_axe` | Work Axe | 1 | 1 | common | axe | tool · weapon |  |
| `work_pick` | Work Pick | 1 | 1 | common | pick | tool |  |
| `workbench_kit` | Workbench Kit | 1 | 1 | common | none | building |  |
| `woven_bag` | Woven Bag | 1 | 1 | uncommon | none | accessory · bag |  |

## Food effects (FOODFX)

Channels name what an item does; every number carries its `provenance` (`extracted-client` = the Durango:0 reconstruction, `restoration-evaluated` = evaluated but unverified, `new-design` = this build's own placeholder).

| item | provenance | channels | energy | digest (s) | thirst | fullness | eat (s) | taste |
|---|---|---|---|---|---|---|---|---|
| `berries` | restoration-evaluated | energy · fullness | digest_seconds=300.0 instant_release_ratio=0.6 | 300.0 |  | 10 |  |  |
| `berry` | restoration-evaluated | energy · taste · fullness | digest_seconds=240.0 instant_release_ratio=0.6 | 240.0 |  | 10 |  | 58 |
| `boiled_meat` | restoration-evaluated | energy · fullness · status · attribute | digest_seconds=300.0 instant_release_ratio=0.65 | 300.0 |  | 10 |  |  |
| `cactus_flesh` | restoration-evaluated | energy · fullness | digest_seconds=300.0 instant_release_ratio=0.5 | 300.0 |  | 15 |  |  |
| `cactus_juice` | restoration-evaluated | energy · fullness · thirst | digest_seconds=300.0 instant_release_ratio=0.7 | 300.0 | 20 | 7 |  |  |
| `camp_stew` | restoration-evaluated | energy · fullness · health · status · attribute | digest_seconds=300.0 instant_release_ratio=0.7 | 300.0 |  | 7 |  | 62 |
| `carnivore_feed` | restoration-evaluated | energy · fullness · fatigue | digest_seconds=300.0 instant_release_ratio=0.9 | 300.0 |  | 30 |  |  |
| `coconut` | restoration-evaluated | energy · fullness | digest_seconds=300.0 instant_release_ratio=0.6 | 300.0 |  | 10 |  |  |
| `corn` | restoration-evaluated | energy · fullness | digest_seconds=300.0 instant_release_ratio=0.5 | 300.0 |  | 10 |  |  |
| `crafters_meal` | restoration-evaluated | energy · fullness · ability · taste | digest_seconds=300.0 instant_release_ratio=0.8 | 300.0 |  | 10 | 3.0 | 70 |
| `drip_coffee` | restoration-evaluated | energy · fatigue · status · taste · fullness | digest_seconds=300.0 instant_release_ratio=0.851 | 300.0 |  | 5 | 2.5 | 56 |
| `dutch_coffee` | restoration-evaluated | energy · status · taste · max_fatigue · fullness | digest_seconds=300.0 instant_release_ratio=0.851 | 300.0 |  | 5 | 2.5 | 56 |
| `fatigue_tonic` | restoration-evaluated | fatigue · taste · fullness · thirst |  |  | 20 | 5 | 1.5 | 30 |
| `fish` | restoration-evaluated | energy · fullness | digest_seconds=300.0 instant_release_ratio=0.3 | 300.0 |  | 10 |  |  |
| `fruit_juice` | restoration-evaluated | energy · fullness · thirst · attribute | digest_seconds=300.0 instant_release_ratio=0.7 | 300.0 | 20 | 7 |  |  |
| `grilled_meat` | restoration-evaluated | energy · fullness · taste | digest_seconds=300.0 instant_release_ratio=0.6 | 300.0 |  | 12 |  | 66 |
| `herb_buff_meal` | restoration-evaluated | energy · fullness | digest_seconds=300.0 instant_release_ratio=0.6 | 300.0 |  | 12 |  | 60 |
| `herbal_tea` | restoration-evaluated | energy · fullness · health | digest_seconds=300.0 instant_release_ratio=0.5 | 300.0 |  | 30 |  |  |
| `herbivore_feed` | restoration-evaluated | energy · fullness · fatigue | digest_seconds=300.0 instant_release_ratio=0.9 | 300.0 |  | 30 |  |  |
| `mango` | restoration-evaluated | energy · fullness | digest_seconds=300.0 instant_release_ratio=0.6 | 300.0 |  | 10 |  |  |
| `meat_broth` | restoration-evaluated | energy · fullness · thirst | digest_seconds=300.0 instant_release_ratio=0.8 | 300.0 | 20 | 5 |  |  |
| `meatball` | restoration-evaluated | energy · fullness · attribute | digest_seconds=300.0 instant_release_ratio=0.35 | 300.0 |  | 10 |  |  |
| `meatball_mix` | restoration-evaluated | energy · fullness | digest_seconds=300.0 instant_release_ratio=0.25 | 300.0 |  | 20 |  |  |
| `mushroom` | restoration-evaluated | energy · fullness · status | digest_seconds=300.0 instant_release_ratio=0.5 | 300.0 |  | 30 |  |  |
| `raptor_meat` | restoration-evaluated | energy · fullness | digest_seconds=300.0 instant_release_ratio=0.45 | 300.0 |  | 20 |  |  |
| `raw_meat` | restoration-evaluated | energy · fullness | digest_seconds=300.0 instant_release_ratio=0.25 | 300.0 |  | 20 |  | 20 |
| `roast` | restoration-evaluated | energy · fullness · status · attribute · combat | digest_seconds=300.0 instant_release_ratio=0.7 | 300.0 |  | 50 |  |  |
| `salad` | restoration-evaluated | energy · fullness · attribute | digest_seconds=300.0 instant_release_ratio=0.7 | 300.0 |  | 10 |  |  |
| `sashimi` | restoration-evaluated | energy · fullness | digest_seconds=300.0 instant_release_ratio=0.6 | 300.0 |  | 15 |  |  |
| `seasoned_roast` | restoration-evaluated | energy · fullness · status · attribute · combat | digest_seconds=300.0 instant_release_ratio=0.7 | 300.0 |  | 50 |  |  |
| `shaved_ice` | restoration-evaluated | energy · fullness · status | digest_seconds=300.0 instant_release_ratio=0.6 | 300.0 |  | 10 |  |  |
| `skewer` | restoration-evaluated | energy · fullness | digest_seconds=300.0 instant_release_ratio=0.6 | 300.0 |  | 12 |  | 58 |
| `spiced_skewer` | restoration-evaluated | energy · fullness | digest_seconds=300.0 instant_release_ratio=0.6 | 300.0 |  | 12 |  |  |
| `spring_water` | new-design | energy · thirst | digest_seconds=0.0 instant_release_ratio=1.0 | 0.0 | 35.0 |  | 1.5 | 40 |
| `tea` | restoration-evaluated | energy · thirst · taste · fullness | digest_seconds=300.0 instant_release_ratio=0.5 | 300.0 | 20.0 | 5 | 2.5 | 62 |

## Per-food flavour, status & assumption notes

- **Berries** — catalog `wildberry` Raspberry (L60: 29.7 + 19.8 Energy, fullness 10.0)
  > *assumption:* FOODCAT # ASSUMPTION: mapped to catalog row wildberry (Raspberry). Energy: item food_energy = (29.7 + 19.8) / 1.6 x catalog_scale.energy_k (0.110791): the catalog sets relative values only, and the existing level rule x(1 + 0.01 x level) makes level 60 = catalog total x energy_k; instant ratio = 29.7 / 49.5. Fullness is the catalog's.
- **Wild Berry** — flavors sweet=30, salty=0, sour=14, bitter=2, greasy=0, umami=0, astringent=8 — catalog `wildberry` Raspberry (L60: 29.7 + 19.8 Energy, fullness 10.0)
  > *assumption:* A raw berry can upset the stomach (spec 32 s9 'some raw food may inflict Stomach Pain'); the 12% chance and 4 min digestion are ASSUMPTION, not the item def's (which had no risk). FOODCAT # ASSUMPTION: mapped to catalog row wildberry (Raspberry). Energy: item food_energy = (29.7 + 19.8) / 1.6 x catalog_scale.energy_k (0.110791): the catalog sets relative values only, and the existing level rule x(1 + 0.01 x level) makes level 60 = catalog total x energy_k; instant ratio = 29.7 / 49.5. Fullness is the catalog's.
- **Boiled Meat** — temperature hot Lv1 — catalog `boiled_meat` Boiled Meat (L60: 119.5 + 64.3 Energy, fullness 10.0, Strength +20.9, Hot Food Lv1)
  > *assumption:* FOODCAT # ASSUMPTION: mapped to catalog row boiled_meat (Boiled Meat). Energy: item food_energy = (119.5 + 64.3) / 1.6 x catalog_scale.energy_k (0.110791): the catalog sets relative values only, and the existing level rule x(1 + 0.01 x level) makes level 60 = catalog total x energy_k; instant ratio = 119.5 / 183.8. Fullness is the catalog's. Hot Food Lv1 -> temperature hot level 1.
- **Cactus Flesh** — catalog `cactus` Cactus Pulp (L60: 18.9 + 18.9 Energy, fullness 15.0)
  > *assumption:* FOODCAT # ASSUMPTION: mapped to catalog row cactus (Cactus Pulp). Energy: item food_energy = (18.9 + 18.9) / 1.6 x catalog_scale.energy_k (0.110791): the catalog sets relative values only, and the existing level rule x(1 + 0.01 x level) makes level 60 = catalog total x energy_k; instant ratio = 18.9 / 37.8. Fullness is the catalog's.
- **Cactus Juice** — catalog `juice_cactus` Cactus Juice (L60: 89.9 + 38.6 Energy, fullness 7.0, Quenches thirst, Quenched (Cactus) Lv60)
  > *assumption:* FOODCAT # ASSUMPTION: mapped to catalog row juice_cactus (Cactus Juice). Energy: item food_energy = (89.9 + 38.6) / 1.6 x catalog_scale.energy_k (0.110791): the catalog sets relative values only, and the existing level rule x(1 + 0.01 x level) makes level 60 = catalog total x energy_k; instant ratio = 89.9 / 128.5. Fullness is the catalog's. 'Quenches thirst, Quenched (Cactus) Lv60' -> thirst 20.0 (any value > 0 clears Thirsty and grants Quenched; the number is tea's existing 20).
- **Camp Stew** — flavors sweet=10, salty=18, sour=4, bitter=2, greasy=14, umami=26, astringent=0 — temperature hot Lv2 — health 5.0 — catalog `stew_01` Stew (L60: 138.2 + 59.2 Energy, fullness 7.0, Perception +20.9, Hot Food Lv2)
  > *assumption:* Fullness 30 and Health +5 are ASSUMPTION; spec 32 s1 lists Health as a channel but gives no stew figure. FOODCAT # ASSUMPTION: mapped to catalog row stew_01 (Stew). Energy (NOT applied, see catalog.energy_kept; the item keeps its old Energy) would be food_energy = (138.2 + 59.2) / 1.6 x catalog_scale.energy_k (0.110791): the catalog sets relative values only, and the existing level rule x(1 + 0.01 x level) makes level 60 = catalog total x energy_k; instant ratio = 138.2 / 197.4. Fullness is the catalog's. Hot Food Lv2 -> temperature hot level 2.
- **Carnivore Feed** — fatigue 86.67 — catalog `feed_carni_02` Carnivore Feed (L60: 169.7 + 18.8 Energy, fullness 30.0, Fatigue +130, Strange Eats Lv1)
  > *assumption:* FOODCAT # ASSUMPTION: mapped to catalog row feed_carni_02 (Carnivore Feed). Energy: item food_energy = (169.7 + 18.8) / 1.6 x catalog_scale.energy_k (0.110791): the catalog sets relative values only, and the existing level rule x(1 + 0.01 x level) makes level 60 = catalog total x energy_k; instant ratio = 169.7 / 188.5. Fullness is the catalog's. catalog Fatigue +130 x catalog_scale.fatigue_k = +86.67; 'Strange Eats Lv1' has no status here (open question).
- **Coconut** — catalog `coconut` Coconut (L60: 40.4 + 26.9 Energy, fullness 10.0)
  > *assumption:* FOODCAT # ASSUMPTION: mapped to catalog row coconut (Coconut). Energy: item food_energy = (40.4 + 26.9) / 1.6 x catalog_scale.energy_k (0.110791): the catalog sets relative values only, and the existing level rule x(1 + 0.01 x level) makes level 60 = catalog total x energy_k; instant ratio = 40.4 / 67.3. Fullness is the catalog's.
- **Corn** — catalog `corn_infertility` Corn (Food) (L60: 44.5 + 44.5 Energy, fullness 10.0)
  > *assumption:* FOODCAT # ASSUMPTION: mapped to catalog row corn_infertility (Corn (Food)). Energy: item food_energy = (44.5 + 44.5) / 1.6 x catalog_scale.energy_k (0.110791): the catalog sets relative values only, and the existing level rule x(1 + 0.01 x level) makes level 60 = catalog total x energy_k; instant ratio = 44.5 / 89.0. Fullness is the catalog's.
- **Crafter's Meal** — flavors sweet=8, salty=20, sour=2, bitter=2, greasy=18, umami=24, astringent=0 — catalog `fruit_sandwich_weapon` Fruit Sandwich: Weapon Crafting Flavor (L60: 110.8 + 27.7 Energy, fullness 10.0, Weapon Crafting Ability +33)
  > *assumption:* FOODCAT # ASSUMPTION: mapped to catalog row fruit_sandwich_weapon (Fruit Sandwich: Weapon Crafting Flavor). Energy: item food_energy = (110.8 + 27.7) / 1.6 x catalog_scale.energy_k (0.110791): the catalog sets relative values only, and the existing level rule x(1 + 0.01 x level) makes level 60 = catalog total x energy_k; instant ratio = 110.8 / 138.5. Fullness is the catalog's. the catalog buff (Weapon Crafting Ability +33) is NOT applied: the existing spec-32 buff row stays (t_foodfx fixture). The +20 Weapon Crafting Ability and 20 min are spec 32 s3's own example.
- **Drip Coffee** — flavors sweet=0, salty=0, sour=6, bitter=40, greasy=0, umami=8, astringent=20 — statuses {'id': 'caffeinated', 'duration': 600.0} — catalog `coffee_drip` Drip Coffee (L60: 47.9 + 8.4 Energy, fullness 5.0, Caffeinated Lv60)
  > *assumption:* 47.9 immediate + 8.4 delayed Energy at level 60 (spec 32 s5), restoration-evaluated. Caffeinated's 10 min is ASSUMPTION (status length only, no effect invented). FOODCAT # ASSUMPTION: mapped to catalog row coffee_drip (Drip Coffee). Energy: item food_energy = (47.9 + 8.4) / 1.6 x catalog_scale.energy_k (0.110791): the catalog sets relative values only, and the existing level rule x(1 + 0.01 x level) makes level 60 = catalog total x energy_k; instant ratio = 47.9 / 56.3. Fullness is the catalog's.
- **Dutch Coffee** — flavors sweet=0, salty=0, sour=6, bitter=44, greasy=0, umami=8, astringent=24 — statuses {'id': 'caffeinated', 'duration': 900.0} — catalog `coffee_dutch` Dutch Coffee (L60: 47.9 + 8.4 Energy, fullness 5.0, Max Fatigue +132.8, Caffeinated Lv60)
  > *assumption:* Energy values follow Drip Coffee (spec 32 s5 says 'same Energy values'). FOODCAT # ASSUMPTION: mapped to catalog row coffee_dutch (Dutch Coffee). Energy: item food_energy = (47.9 + 8.4) / 1.6 x catalog_scale.energy_k (0.110791): the catalog sets relative values only, and the existing level rule x(1 + 0.01 x level) makes level 60 = catalog total x energy_k; instant ratio = 47.9 / 56.3. Fullness is the catalog's. the catalog buff (Max Fatigue +132.8) is NOT applied: the existing spec-32 buff row stays (t_foodfx fixture).
- **Fatigue Restorative** — flavors sweet=4, salty=0, sour=10, bitter=30, greasy=0, umami=2, astringent=12 — fatigue -200 — catalog `fatigue_drug` Fatigue Restorative (L60: 0.0 + 0.0 Energy, fullness 5.0, Fatigue -300, Water Lv1)
  > *assumption:* Fatigue -200 follows the reconstruction's Dunia Warp Mineral Water row (spec 32 s5, no Energy recovery); this build's drink is a craftable restorative, not the event item. restoration-evaluated. FOODCAT # ASSUMPTION: mapped to catalog row fatigue_drug (Fatigue Restorative): no Energy; fullness is the catalog's. 'Fatigue -300, Water Lv1' -> thirst 20.0 (any value > 0 clears Thirsty and grants Quenched; the number is tea's existing 20); catalog Fatigue -300 x catalog_scale.fatigue_k = -200.
- **Fish** — raw-bite status stomachache Lv1 — catalog `fish` Minnow (L60: 38.0 + 88.7 Energy, fullness 10.0, Stomach Pain Lv1)
  > *assumption:* FOODCAT # ASSUMPTION: mapped to catalog row fish (Minnow). Energy: item food_energy = (38.0 + 88.7) / 1.6 x catalog_scale.energy_k (0.110791): the catalog sets relative values only, and the existing level rule x(1 + 0.01 x level) makes level 60 = catalog total x energy_k; instant ratio = 38.0 / 126.7. Fullness is the catalog's. 'Stomach Pain Lv1' -> the existing raw-food roll applies stomachache at level 1 (chance unchanged, item def's).
- **Fruit Juice** — catalog `juice_fruit` Fruit Juice (L60: 96.9 + 41.6 Energy, fullness 7.0, Charisma +20.9, Quenches thirst, Water Lv1)
  > *assumption:* FOODCAT # ASSUMPTION: mapped to catalog row juice_fruit (Fruit Juice). Energy: item food_energy = (96.9 + 41.6) / 1.6 x catalog_scale.energy_k (0.110791): the catalog sets relative values only, and the existing level rule x(1 + 0.01 x level) makes level 60 = catalog total x energy_k; instant ratio = 96.9 / 138.5. Fullness is the catalog's. 'Quenches thirst, Water Lv1' -> thirst 20.0 (any value > 0 clears Thirsty and grants Quenched; the number is tea's existing 20).
- **Grilled Meat** — flavors sweet=6, salty=16, sour=0, bitter=4, greasy=30, umami=34, astringent=0 — catalog `skewer_meat_mart` Meat (L60: 98.0 + 65.3 Energy, fullness 12.0)
  > *assumption:* Fullness +25 follows spec 32 s6's Bacon row; the ratio and taste score are ASSUMPTION. FOODCAT # ASSUMPTION: mapped to catalog row skewer_meat_mart (Meat). Energy: item food_energy = (98.0 + 65.3) / 1.6 x catalog_scale.energy_k (0.110791): the catalog sets relative values only, and the existing level rule x(1 + 0.01 x level) makes level 60 = catalog total x energy_k; instant ratio = 98.0 / 163.3. Fullness is the catalog's.
- **Herbed Meal** — flavors sweet=4, salty=10, sour=2, bitter=12, greasy=12, umami=18, astringent=6 — catalog `skewer_meat_mart` Meat (L60: 98.0 + 65.3 Energy, fullness 12.0)
  > *assumption:* The meal keeps its existing food_buffs.json 'defense' row (dried herb secondary slot, PRD 9.3); the bundle only adds fullness and taste, both ASSUMPTION. FOODCAT # ASSUMPTION: mapped to catalog row skewer_meat_mart (Meat). Energy: item food_energy = (98.0 + 65.3) / 1.6 x catalog_scale.energy_k (0.110791): the catalog sets relative values only, and the existing level rule x(1 + 0.01 x level) makes level 60 = catalog total x energy_k; instant ratio = 98.0 / 163.3. Fullness is the catalog's.
- **Herbal Tea** — health 5 — catalog `medicine_tea_01` Herbal Tea (L60: 5.0 + 5.0 Energy, fullness 30.0, Health +50.4)
  > *assumption:* FOODCAT # ASSUMPTION: mapped to catalog row medicine_tea_01 (Herbal Tea). Energy: item food_energy = (5.0 + 5.0) / 1.6 x catalog_scale.energy_k (0.110791): the catalog sets relative values only, and the existing level rule x(1 + 0.01 x level) makes level 60 = catalog total x energy_k; instant ratio = 5.0 / 10.0. Fullness is the catalog's. catalog Health +50.4 x catalog_scale.health_k = +5, flat (no level rule for Health).
- **Herbivore Feed** — fatigue 86.67 — catalog `feed_herb_02` Herbivore Feed (L60: 169.7 + 18.8 Energy, fullness 30.0, Fatigue +130, Strange Eats Lv1)
  > *assumption:* FOODCAT # ASSUMPTION: mapped to catalog row feed_herb_02 (Herbivore Feed). Energy: item food_energy = (169.7 + 18.8) / 1.6 x catalog_scale.energy_k (0.110791): the catalog sets relative values only, and the existing level rule x(1 + 0.01 x level) makes level 60 = catalog total x energy_k; instant ratio = 169.7 / 188.5. Fullness is the catalog's. catalog Fatigue +130 x catalog_scale.fatigue_k = +86.67; 'Strange Eats Lv1' has no status here (open question).
- **Mango** — catalog `fruit_tropical` Tropical Fruit (L60: 40.4 + 26.9 Energy, fullness 10.0)
  > *assumption:* FOODCAT # ASSUMPTION: mapped to catalog row fruit_tropical (Tropical Fruit). Energy: item food_energy = (40.4 + 26.9) / 1.6 x catalog_scale.energy_k (0.110791): the catalog sets relative values only, and the existing level rule x(1 + 0.01 x level) makes level 60 = catalog total x energy_k; instant ratio = 40.4 / 67.3. Fullness is the catalog's.
- **Meat Broth** — catalog `broth_meat` Meat Broth (L60: 38.0 + 9.5 Energy, fullness 5.0, Water Lv1)
  > *assumption:* FOODCAT # ASSUMPTION: mapped to catalog row broth_meat (Meat Broth). Energy: item food_energy = (38.0 + 9.5) / 1.6 x catalog_scale.energy_k (0.110791): the catalog sets relative values only, and the existing level rule x(1 + 0.01 x level) makes level 60 = catalog total x energy_k; instant ratio = 38.0 / 47.5. Fullness is the catalog's. 'Water Lv1' -> thirst 20.0 (any value > 0 clears Thirsty and grants Quenched; the number is tea's existing 20).
- **Meatball** — catalog `meatball_01` Meat Dumpling (L60: 71.5 + 132.9 Energy, fullness 10.0, Strength +20.9)
  > *assumption:* FOODCAT # ASSUMPTION: mapped to catalog row meatball_01 (Meat Dumpling). Energy: item food_energy = (71.5 + 132.9) / 1.6 x catalog_scale.energy_k (0.110791): the catalog sets relative values only, and the existing level rule x(1 + 0.01 x level) makes level 60 = catalog total x energy_k; instant ratio = 71.5 / 204.4. Fullness is the catalog's.
- **Meatball Mix** — raw-bite status stomachache Lv1 — catalog `meat` Meat (L60: 40.8 + 122.5 Energy, fullness 20.0, Stomach Pain Lv1)
  > *assumption:* FOODCAT # ASSUMPTION: mapped to catalog row meat (Meat). Energy: item food_energy = (40.8 + 122.5) / 1.6 x catalog_scale.energy_k (0.110791): the catalog sets relative values only, and the existing level rule x(1 + 0.01 x level) makes level 60 = catalog total x energy_k; instant ratio = 40.8 / 163.3. Fullness is the catalog's. 'Stomach Pain Lv1' -> the existing raw-food roll applies stomachache at level 1 (chance unchanged, item def's).
- **Mushroom** — raw-bite status poisoned Lv4 — catalog `mushroom` Mushroom (L60: 14.4 + 14.4 Energy, fullness 30.0, Poisoned Lv4)
  > *assumption:* FOODCAT # ASSUMPTION: mapped to catalog row mushroom (Mushroom). Energy: item food_energy = (14.4 + 14.4) / 1.6 x catalog_scale.energy_k (0.110791): the catalog sets relative values only, and the existing level rule x(1 + 0.01 x level) makes level 60 = catalog total x energy_k; instant ratio = 14.4 / 28.8. Fullness is the catalog's. 'Poisoned Lv4' -> the existing raw-food roll applies poisoned at level 4 (chance unchanged, item def's).
- **Raptor Meat** — raw-bite status stomachache Lv1 — catalog `meat_lizard` Lizard Carcass (L60: 73.5 + 89.8 Energy, fullness 20.0, Stomach Pain Lv1)
  > *assumption:* FOODCAT # ASSUMPTION: mapped to catalog row meat_lizard (Lizard Carcass). Energy: item food_energy = (73.5 + 89.8) / 1.6 x catalog_scale.energy_k (0.110791): the catalog sets relative values only, and the existing level rule x(1 + 0.01 x level) makes level 60 = catalog total x energy_k; instant ratio = 73.5 / 163.3. Fullness is the catalog's. 'Stomach Pain Lv1' -> the existing raw-food roll applies stomachache at level 1 (chance unchanged, item def's).
- **Raw Meat** — flavors sweet=0, salty=4, sour=2, bitter=0, greasy=20, umami=30, astringent=0 — raw-bite status stomachache Lv1 — catalog `meat` Meat (L60: 40.8 + 122.5 Energy, fullness 20.0, Stomach Pain Lv1)
  > *assumption:* FOODCAT # ASSUMPTION: mapped to catalog row meat (Meat). Energy: item food_energy = (40.8 + 122.5) / 1.6 x catalog_scale.energy_k (0.110791): the catalog sets relative values only, and the existing level rule x(1 + 0.01 x level) makes level 60 = catalog total x energy_k; instant ratio = 40.8 / 163.3. Fullness is the catalog's. 'Stomach Pain Lv1' -> the existing raw-food roll applies stomachache at level 1 (chance unchanged, item def's).
- **Roast** — temperature hot Lv3 — catalog `sirloin_steak` Sirloin Steak (L60: 62.3 + 26.7 Energy, fullness 50.0, Strength +30, Defense +4.6, Hot Food Lv3)
  > *assumption:* FOODCAT # ASSUMPTION: mapped to catalog row sirloin_steak (Sirloin Steak). Energy: item food_energy = (62.3 + 26.7) / 1.6 x catalog_scale.energy_k (0.110791): the catalog sets relative values only, and the existing level rule x(1 + 0.01 x level) makes level 60 = catalog total x energy_k; instant ratio = 62.3 / 89.0. Fullness is the catalog's. Hot Food Lv3 -> temperature hot level 3.
- **Salad** — catalog `salad_01` Salad (L60: 123.7 + 53.0 Energy, fullness 10.0, Dexterity +20.9)
  > *assumption:* FOODCAT # ASSUMPTION: mapped to catalog row salad_01 (Salad). Energy: item food_energy = (123.7 + 53.0) / 1.6 x catalog_scale.energy_k (0.110791): the catalog sets relative values only, and the existing level rule x(1 + 0.01 x level) makes level 60 = catalog total x energy_k; instant ratio = 123.7 / 176.7. Fullness is the catalog's.
- **Sashimi** — catalog `sashimi` Sashimi (L60: 119.1 + 79.4 Energy, fullness 15.0)
  > *assumption:* FOODCAT # ASSUMPTION: mapped to catalog row sashimi (Sashimi). Energy: item food_energy = (119.1 + 79.4) / 1.6 x catalog_scale.energy_k (0.110791): the catalog sets relative values only, and the existing level rule x(1 + 0.01 x level) makes level 60 = catalog total x energy_k; instant ratio = 119.1 / 198.5. Fullness is the catalog's.
- **Seasoned Roast** — temperature hot Lv3 — catalog `tenderloin_steak` Tenderloin Steak (L60: 62.3 + 26.7 Energy, fullness 50.0, Strength +30, Attack +6.6, Hot Food Lv3)
  > *assumption:* FOODCAT # ASSUMPTION: mapped to catalog row tenderloin_steak (Tenderloin Steak). Energy: item food_energy = (62.3 + 26.7) / 1.6 x catalog_scale.energy_k (0.110791): the catalog sets relative values only, and the existing level rule x(1 + 0.01 x level) makes level 60 = catalog total x energy_k; instant ratio = 62.3 / 89.0. Fullness is the catalog's. Hot Food Lv3 -> temperature hot level 3.
- **Shaved Ice** — temperature cold Lv1 — catalog `shaved_ice` Shaved Ice (L60: 29.7 + 19.8 Energy, fullness 10.0, Cold Food Lv60)
  > *assumption:* FOODCAT # ASSUMPTION: mapped to catalog row shaved_ice (Shaved Ice). Energy: item food_energy = (29.7 + 19.8) / 1.6 x catalog_scale.energy_k (0.110791): the catalog sets relative values only, and the existing level rule x(1 + 0.01 x level) makes level 60 = catalog total x energy_k; instant ratio = 29.7 / 49.5. Fullness is the catalog's. Cold Food Lv60 -> temperature cold level 1.
- **Skewer** — flavors sweet=4, salty=12, sour=0, bitter=6, greasy=26, umami=30, astringent=0 — catalog `meat_skewers` Meat Kebab (L60: 98.0 + 65.3 Energy, fullness 12.0)
  > *assumption:* FOODCAT # ASSUMPTION: mapped to catalog row meat_skewers (Meat Kebab). Energy: item food_energy = (98.0 + 65.3) / 1.6 x catalog_scale.energy_k (0.110791): the catalog sets relative values only, and the existing level rule x(1 + 0.01 x level) makes level 60 = catalog total x energy_k; instant ratio = 98.0 / 163.3. Fullness is the catalog's.
- **Spiced Skewer** — catalog `meat_skewers` Meat Kebab (L60: 98.0 + 65.3 Energy, fullness 12.0)
  > *assumption:* FOODCAT # ASSUMPTION: mapped to catalog row meat_skewers (Meat Kebab). Energy: item food_energy = (98.0 + 65.3) / 1.6 x catalog_scale.energy_k (0.110791): the catalog sets relative values only, and the existing level rule x(1 + 0.01 x level) makes level 60 = catalog total x energy_k; instant ratio = 98.0 / 163.3. Fullness is the catalog's.
- **Spring Water** — flavors sweet=0, salty=0, sour=2, bitter=0, greasy=0, umami=0, astringent=2
  > *assumption:* Spec 32 s5 only says water quenches thirst and carries minor Energy/Fullness in the reconstruction; 4 Energy, +35 thirst and the 1.5 s drink are ASSUMPTION.
- **Tea** — flavors sweet=8, salty=0, sour=4, bitter=18, greasy=0, umami=6, astringent=14 — catalog `tea_01_green` Green Tea (L60: 22.4 + 22.4 Energy, fullness 5.0, Enhanced Ability Lv60)
  > *assumption:* 22.4 immediate + 22.4 delayed Energy is the reconstruction's level-60 Tea figure (spec 32 s5), tagged restoration-evaluated, not a 2019 constant; thirst and the taste score are ASSUMPTION. FOODCAT # ASSUMPTION: mapped to catalog row tea_01_green (Green Tea). Energy: item food_energy = (22.4 + 22.4) / 1.6 x catalog_scale.energy_k (0.110791): the catalog sets relative values only, and the existing level rule x(1 + 0.01 x level) makes level 60 = catalog total x energy_k; instant ratio = 22.4 / 44.8. Fullness is the catalog's. 'Enhanced Ability Lv60' has no stat to map (open question); tea keeps its WATER thirst.


## Rare material attributes (RAREATTR)

Hand-written section (not from `gen_game_data.py`); re-add it after a regeneration until the generator emits it.

**As shipped today** (measured in `game/tests/t_rareattr.gd`): 52 of the gatherable ids have their own
`by_material` list and none names a key outside the six; 0 of 20 000 seeded gathers drew an off-list
trait and none drew two; 180 of 180 recipes mark slot 1 `primary`, so a slot-1 rare attribute reaches
the output and a slot-2 or slot-3 one never does.

**The roll.** Every gathered unit rolls once at gather (`game/scripts/gather/gather_service.gd` `stamp_traits` →
`loot_roller.gd` `roll_trait`): a **5 %** chance of **one** rare attribute (`game/data/loot_tables.json`
`rare_trait.chance`, world-design.md:55, PRD:541). There is no bonus from Gathering level (spec 12:42) or tool tier.
Since RAREATTR the attribute comes from **that material's own list**, `rare_trait.by_material[<item id>]`, not one pool
for everything: a stone rolls Black Sheen / Low Vibration / Vivid Inspiration, a log rolls Wide Serration / Split Easily
/ Vivid Inspiration, a fibre rolls Narrow Hook / Wide Serration / Vivid Inspiration. The six-trait pool
(`rare_trait.traits`) stays the fallback for an item with no row. The full six are spec 04:11's: Black Sheen, Low
Vibration, Wide Serration, Narrow Hook, Split Easily, Vivid Inspiration; all six are class `rare` in `inv_ui.json` and
`rules.json` `crafting.rare_attributes`.

*ASSUMPTION:* spec 04:25 documents conversions for five of the six but no per-material table. The shipped mapping groups
materials by what they are for — combat materials (stone, ore, metal, crystal, ice, pearl) → Black Sheen / Low Vibration
(Vital Strike / Throw Dirt, Sadism / Pain Averse); tool-shaping materials (timber, fibre, cordage) → Wide Serration /
Narrow Hook (gathering effects); workpieces (timber, earth, clay, resin) also → Split Easily (workstation effects);
Vivid Inspiration has no documented conversion, so every material can roll it. It is data; retune without code.

**The green pip.** `InvAttributes.sections` puts the attribute in its `rare` class, drawn `#67B84E` (spec 13:50/291,
INVUI's `InvTheme.RARE`); the item card shows it as a green row, the bag grid draws the green corner mark on the cell.

**Carry into crafts (spec 04:33).** A rare attribute passes from a single **primary** material only. Every shipped
recipe (`game/data/recipes.json`) marks slot 1 `primary: true`; `Crafting.build_output` copies that instance's
attributes onto the output, so the rare attribute carries into the crafted item and shows the same green pip there. An
equal attribute on a secondary material (slot 2 or later) never transfers: a knife's handle's rare attribute does not
reach the blade. `Crafting.preview_quality` lists the primary's traits as `inherited`, so the preview cannot disagree
with the result.

A craft also has its own luck roll for a rare attribute (`rules.json` `crafting.rare_attribute_chance`, 5 %,
`Crafting.roll_outcome_for` → `apply_outcome`); it draws from the full six and is unrelated to the instance's own
attribute. The first one the result already has is kept as it is.

**Instances.** Units never stack (owner rule), so each keeps its own attribute; it survives save/load with the
instance's uid and is not re-rolled on transfer (`t_rareattr.gd`).
