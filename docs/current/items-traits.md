# Items & traits — the full catalog

> Generated 2026-10-27 by `tools/docs_wiki/gen_game_data.py` from the build's own data. Never hand-edit; re-run after any balance pass.

`240 items` from `game/data/items.json`; per-item consumption effects from `game/data/foods.json`; rarity palette from `game/data/item_rarity.json`.

Rarity: **common** `#a8adb3`, **uncommon** `#5cc864`, **rare** `#3c8cff`, **epic** `#b45cff`, **legendary** `#ffa424`.

Item *traits* are the attribute keys stamped on an instance: a def's `default_attributes` (its baseline), a gather material's latent attr (the yellow pip), an inherited attribute carried through crafting, or a butcher/gather roll. The pip/stacking rules live in `game/data/inventory.json`; bag specials in `game/data/bags.json`.

## Appearance is not a trait (spec 35 package 1)

A gathered wood instance may carry `look` = `{species, color, family, grain}`: the natural colour and
grain of the tree it came from (`game/data/materials/wood_species.json`, `game/scripts/items/material_look.gd`).
It is a dimension of its own, deliberately outside this page's trait rules:

- It is **not** an attribute, so it never appears in the attributes column, never becomes a trait
  pip, and never ranks an instance in a default pick (`Inventory.traits`, `Inventory.spend_key`).
- Rarity, level and traits never choose a colour and a colour never changes them (spec 35 §3).
- Per-log variation is a small hue/value jitter inside the species range; the species itself is
  fixed by the tree kind (pine, snow pine, birch, oak/common, acacia, palm, willow).

> This section is hand-written inside a generated file: `tools/docs_wiki/gen_game_data.py` must
> learn to emit it (or keep it) on its next run.

## Categories with counts

**tool** (35) · **food** (33) · **weapon** (29) · **building** (27) · **meat** (15) · **wood** (14) · **cooked** (12) · **fibre** (10) · **lashing** (9) · **blade** (9) · **armor_body** (9) · **armor_legs** (9) · **herb** (8) · **armor_head** (8) · **armor_arms** (8) · **metal** (7) · **strap_material** (6) · **stone** (6) · **blade_mat** (6) · **ingot** (6) · **medicine** (6) · **accessory** (6) · **bag** (6) · **ore** (5) · **bone** (5) · **fruit** (5) · **earth** (5) · **buff_food** (5) · **drink** (5) · **burnable** (4) · **log** (4) · **cloth** (4) · **hide** (4) · **tinder** (4) · **seed** (4) · **handle** (3) · **stalk** (3) · **raw_meat** (3) · **tier_bone** (3) · **uncut_hide** (3) · **water** (3) · **crop** (3) · **counter_supply** (3) · **clothing** (3) · **component** (3) · **brew** (3) · **fuel** (2) · **preserved** (2) · **meal** (2) · **green_hide** (2) · **berry_crop** (2) · **treasure** (2) · **dye** (2) · **bucket** (2) · **flax** (2) · **pet_feed** (2) · **split** (1) · **plank** (1) · **pillar** (1) · **tier_stone** (1) · **rough_ore** (1) · **tier_copper** (1) · **tier_bronze** (1) · **tier_iron** (1) · **tier_steel** (1) · **twine** (1) · **rope** (1) · **thread** (1) · **talon** (1) · **dried_hide** (1) · **cured_hide** (1) · **pot_clay** (1) · **tier_flint** (1) · **tier_obsidian** (1) · **needle** (1) · **copper_ore_mat** (1) · **seasoning** (1) · **bait** (1) · **coral** (1) · **iron_ore** (1) · **mushroom** (1) · **spice** (1) · **raw** (1) · **steamed** (1) · **burnt** (1) · **corn** (1) · **wheat** (1) · **berry** (1) · **flax_crop** (1) · **corn_crop** (1) · **wheat_crop** (1) · **fertilizer** (1) · **tendon** (1) · **scute** (1) · **dense_bone** (1) · **venom** (1) · **ammunition** (1) · **siege_ammunition** (1) · **tin_ore** (1) · **tin** (1) · **plank_shape** (1) · **pillar_shape** (1) · **strap** (1) · **trimmed_plank** (1) · **fine_plank** (1)

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
| `cactus_flesh` | Cactus Flesh | 1 | 10 | common | none | food |  |
| `cactus_flower` | Cactus Flower | 1 |  | uncommon | none | herb · dye |  |
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
| `gate_kit` | Gate | 1 | 5 | uncommon | none | building |  |
| `grilled_meat` | Grilled Meat | 1 | 20 | uncommon | none | food · cooked · meat |  |
| `heavy_snare` | Heavy Cable Snare | 1 | 999 | epic | none | counter_supply |  |
| `herb_buff_meal` | Herbed Meal | 1 | 10 | rare | none | food · cooked · buff_food |  |
| `herb_leaf` | Herb Leaf | 1 | 20 | common | none | herb |  |
| `herbivore_feed` | Herbivore Feed | 1 | 30 | common | none | pet_feed · food |  |
| `hide_bone_bracers` | Hide and Bone Bracers | 1 | 1 | rare | none | armor_arms |  |
| `hide_bone_cuirass` | Hide and Bone Cuirass | 1 | 1 | rare | none | armor_body |  |
| `hide_bone_greaves` | Hide and Bone Greaves | 1 | 1 | rare | none | armor_legs |  |
| `hide_bone_helm` | Hide and Bone Helm | 1 | 1 | rare | none | armor_head |  |
| `hide_strap` | Hide Strap | 1 | 20 | uncommon | none | lashing · hide |  |
| `hoe` | Hoe | 1 | 1 | uncommon | hoe | tool |  |
| `ice` | Ice | 1 | 10 | rare | none | water |  |
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
| `salt` | Salt | 1 | 20 | uncommon | none | seasoning |  |
| `sandstone` | Sandstone | 1 | 20 | uncommon | none | stone |  |
| `sashimi` | Sashimi | 1 | 30 | uncommon | none | food · cooked · meat |  |
| `seasoned_roast` | Seasoned Roast | 1 | 10 | rare | none | food · cooked · meat · buff_food |  |
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
| `berry` | new-design | energy · taste | digest_seconds=240.0 instant_release_ratio=0.6 | 240.0 |  |  |  | 58 |
| `camp_stew` | new-design | energy · fullness · health | instant_release_ratio=0.5 |  |  | 30.0 |  | 62 |
| `crafters_meal` | new-design | energy · fullness · ability · taste | instant_release_ratio=0.5 |  |  | 25.0 | 3.0 | 70 |
| `drip_coffee` | restoration-evaluated | energy · fatigue · status · taste | digest_seconds=300.0 instant_release_ratio=0.851 | 300.0 |  |  | 2.5 | 56 |
| `dutch_coffee` | restoration-evaluated | energy · status · taste · max_fatigue | digest_seconds=300.0 instant_release_ratio=0.851 | 300.0 |  |  | 2.5 | 56 |
| `fatigue_tonic` | restoration-evaluated | fatigue · taste |  |  |  |  | 1.5 | 30 |
| `grilled_meat` | new-design | energy · fullness · taste | digest_seconds=300.0 instant_release_ratio=0.7 | 300.0 |  | 25.0 |  | 66 |
| `herb_buff_meal` | new-design | energy · fullness | instant_release_ratio=0.5 |  |  | 20.0 |  | 60 |
| `raw_meat` | restoration-evaluated | energy | digest_seconds=300.0 instant_release_ratio=0.25 | 300.0 |  |  |  | 20 |
| `skewer` | new-design | energy · fullness | instant_release_ratio=0.6 |  |  | 20.0 |  | 58 |
| `spring_water` | new-design | energy · thirst | digest_seconds=0.0 instant_release_ratio=1.0 | 0.0 | 35.0 |  | 1.5 | 40 |
| `tea` | restoration-evaluated | energy · thirst · taste | digest_seconds=300.0 instant_release_ratio=0.5 | 300.0 | 20.0 |  | 2.5 | 62 |

## Per-food flavour, status & assumption notes

- **Wild Berry** — flavors sweet=30, salty=0, sour=14, bitter=2, greasy=0, umami=0, astringent=8
  > *assumption:* A raw berry can upset the stomach (spec 32 s9 'some raw food may inflict Stomach Pain'); the 12% chance and 4 min digestion are ASSUMPTION, not the item def's (which had no risk).
- **Camp Stew** — flavors sweet=10, salty=18, sour=4, bitter=2, greasy=14, umami=26, astringent=0
  > *assumption:* Fullness 30 and Health +5 are ASSUMPTION; spec 32 s1 lists Health as a channel but gives no stew figure.
- **Crafter's Meal** — flavors sweet=8, salty=20, sour=2, bitter=2, greasy=18, umami=24, astringent=0
  > *assumption:* The 20 min duration follows the reconstruction's 20 min meal buffs (spec 32 s6); Energy 30 comes from the item def.
- **Drip Coffee** — flavors sweet=0, salty=0, sour=6, bitter=40, greasy=0, umami=8, astringent=20 — statuses {'id': 'caffeinated', 'duration': 600.0}
  > *assumption:* 47.9 immediate + 8.4 delayed Energy at level 60 (spec 32 s5), restoration-evaluated. Caffeinated's 10 min is ASSUMPTION (status length only, no effect invented).
- **Dutch Coffee** — flavors sweet=0, salty=0, sour=6, bitter=44, greasy=0, umami=8, astringent=24 — statuses {'id': 'caffeinated', 'duration': 900.0}
  > *assumption:* Energy values follow Drip Coffee (spec 32 s5 says 'same Energy values').
- **Fatigue Restorative** — flavors sweet=4, salty=0, sour=10, bitter=30, greasy=0, umami=2, astringent=12
  > *assumption:* Fatigue -200 follows the reconstruction's Dunia Warp Mineral Water row (spec 32 s5, no Energy recovery); this build's drink is a craftable restorative, not the event item. restoration-evaluated.
- **Grilled Meat** — flavors sweet=6, salty=16, sour=0, bitter=4, greasy=30, umami=34, astringent=0
  > *assumption:* Fullness +25 follows spec 32 s6's Bacon row; the ratio and taste score are ASSUMPTION.
- **Herbed Meal** — flavors sweet=4, salty=10, sour=2, bitter=12, greasy=12, umami=18, astringent=6
  > *assumption:* The meal keeps its existing food_buffs.json 'defense' row (dried herb secondary slot, PRD 9.3); the bundle only adds fullness and taste, both ASSUMPTION.
- **Raw Meat** — flavors sweet=0, salty=4, sour=2, bitter=0, greasy=20, umami=30, astringent=0
  > *assumption:* Spec 32 s6's raw meat example is 40.8 immediate + 122.5 delayed, a 0.25 instant ratio; this build keeps its own lower item Energy and only uses that ratio and the raw-food risk the item def already carries. restoration-evaluated for the ratio.
- **Skewer** — flavors sweet=4, salty=12, sour=0, bitter=6, greasy=26, umami=30, astringent=0
  > *assumption:* Spec 32 s6 gives a skewer's Energy split (58.2/108.1 for its reconstruction); this build keeps its own item Energy and only sets a 0.6 instant ratio and Fullness 20, both ASSUMPTION.
- **Spring Water** — flavors sweet=0, salty=0, sour=2, bitter=0, greasy=0, umami=0, astringent=2
  > *assumption:* Spec 32 s5 only says water quenches thirst and carries minor Energy/Fullness in the reconstruction; 4 Energy, +35 thirst and the 1.5 s drink are ASSUMPTION.
- **Tea** — flavors sweet=8, salty=0, sour=4, bitter=18, greasy=0, umami=6, astringent=14
  > *assumption:* 22.4 immediate + 22.4 delayed Energy is the reconstruction's level-60 Tea figure (spec 32 s5), tagged restoration-evaluated, not a 2019 constant; thirst and the taste score are ASSUMPTION.

