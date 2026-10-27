# dsc-skillbuy: skill nodes can be bought

Playtest defect (shot 11-desk-skilltree-notingame.jpg): every Skills row read "not in the game yet"
while SP piled up (SP 20 at character Lv. 3). Fixed by making the *game* decide which nodes are for
sale: a node is buyable when a system reads its effect, not because a data field says so.

## What was wrong

`SkillRules.buyable()` sold a node only when `trees.json` said `"status": "functional"` or a recipe
named it in `requires_node`. 18 nodes were functional and 38 recipes named a node, so most of the
213-node table was inert: whole trees (Gathering, Butchering, Melee, Ranged, Defense) had **no**
row a player could buy, and the sheet showed every one of them as "not in the game yet".

Reproduced on the code before the fix, with the new test (`[t_skillbuy]` lines, character Lv. 3 =
the playtest state; Lv. 20 printed the same):

```
character Lv. 3: buyable=62 unavailable=133
  survival 17/10  gathering 0/12  butchering 0/21  processing 8/29  melee 0/10  ranged 0/13
  defense 0/11    weapon_tools 10/11  tailoring 9/3  construction 9/3  cooking 6/5  farming 3/5
occupations: every one bought only bonfire, skewer and small_field; melee, ranged, weapon_tools,
gathering and defense had nothing at all.  `effect: max_health ability 0 -> 0`
```

## What shipped

- **`SkillRules.has_effect()`** (`game/scripts/skills/skill_rules.gd`): a node is for sale when it
  carries an effect type a system reads (`recipe`, `bonded_slots`, `capture_tier`, `climate`, plus the
  two new `gather`/`butcher`), or an `ability` the game adds up (`max_health`, `max_energy`). `buyable()`
  uses that instead of `status`, and still adds the prerequisite chain. `status` in `trees.json` is
  bookkeeping for the node; nothing is flipped to `functional` to make it sellable.
  `# ASSUMPTION:` `handicraft`, `metal_processing`, `slaughter` and `stealth` stay unsold because no
  system consumes them yet (W2-PROCESS / W2-BUTCHER / W3-SRVACT).
- **Gathering techniques are real** (`data/skills/trees.json` + `harvest_node.can_gather`): Thickets,
  Mining 1-4, Herbs 1, Insects and Rare Plants carry `{"type": "gather", "items": [...]}` (clay;
  copper/sandstone; flint/obsidian/silver; black iron/pearl; herb/marsh herb; leech; bamboo/mango).
  `SkillRules.gather_block()` refuses the yield with "Needs Mining 1 (Gathering Lv. 10, 8 SP)" and
  `PlayerActions` puts that on the HUD through its existing `notice(why)`.
- **Butchering parts are real** (`corpse._roll_loot`): Organs (venom gland), Tendons, Rare Parts
  (talon), Scutes (armour scute) and Bone II (dense bone) carry `{"type": "butcher", ...}`;
  `Data.butcher_row_open()` drops a row until its node is learned. `Data.butchering_level()` now reads
  the local survivor's Butchering tree (it used to read a mirror of `survival.json` that no tree node
  could ever set).
- **34 recipes now name the node their own "unlocks" text names** (`data/recipes.json`): bonfire,
  workbench, fence, taming pen, drying rack, well, skewer, meatball, stone grill, sashimi, boiling,
  pet food, flax, fertilizer, split wood, thread/cloth, mortar, cooking utensils, barrage,
  one-hand/two-hand mastery, Makeshift Shovel / Hoe (`stone_knife`, which is the tool that recipe line
  is about). Recipe gates ride the existing `Crafting.progression_block` -> craft card lock text.
  Left ungated on purpose: `bonfire_kit`, `campfire_kit`, `stone_fire_pit_kit`, `club`,
  `workbench_kit`, `anvil_kit`, `hoe` — the first-hour path and the tool ladder `t_data` measures.
- **Stat nodes are real** (Defense Max Health 1/2/3 = +10/+20/+30, Survival Belly Fat 1 = +10 energy):
  `Player.refresh_equipment_vitals()` adds `SkillRules.ability("max_health")` to the health bonus and
  sets `Vitals.energy_bonus`; `Vitals.effective_max_energy()` (new) is used by the stamina cap, the
  HUD bar and `eat_session`. The totals are cached by `sp_spent` so the every-frame refresh does not
  walk trees.json.
- **Melee/Ranged first rungs**: `attack_stance` (Melee) and `throw` (Ranged) cost 1 SP instead of the
  PRD's 5 (`sp_assumed`), so a character Lv. 2 survivor can enter either profession; `club` hangs off
  Attack Stance and `stone_shot` off Throw. `# ASSUMPTION:` spec 03:8 says "reaching a level makes a
  node eligible but does not automatically purchase it", so these stay purchases, not AUTO; SP scarcity
  is why the price is 1.

## Numbers after the fix

```
[t_skillbuy] PASS buyable=103 unavailable=92
  survival 17/10  gathering 9/3  butchering 6/15  processing 9/28  melee 7/3  ranged 2/11
  defense 8/3     weapon_tools 12/9  tailoring 9/3  construction 9/3  cooking 11/0  farming 4/4
```

Target (unavailable <= 106 of 213) met: 92. Every occupation at character Lv. 3 buys a node in each
tree it has a node at or under its level, spends exactly its SP, and the row reads learned:

```
soldier: melee body_tackle (SP 20 -> 14), weapon_tools makeshift_shovel_hoe (14 -> 13), construction
bonfire (13 -> 8), cooking skewer (8 -> 3), farming small_field (3 -> 2)
student: gathering thickets (20 -> 14), ...   technician: weapon_tools ...   etc.
effect: max_health ability 0 -> 10, vitals cap 100 -> 110
```

Still "not in the game yet" (all honest: no system reads them): Survival's island/climate lines (the
sail gate is the Survival *level*, not these nodes), Processing's 28 material transformations
(Handicraft/Metalworking ability is read by nothing until W2-PROCESS), Butchering's yield/quality
lines, Gathering's great-success/mining-4 item lines, Ranged's bow/draw/fire-rate lines (bows do not
exist as items yet), Defense's parry/roll-duration/regen lines, Tailoring's bag lines (no bag item
data), Construction's storage/residence/barn lines, Farming's orchard/ranching/sprinkler lines.

## Tests

`game/tests/t_skillbuy.gd` (new): per-tree buyable/unavailable at character Lv. 3 and Lv. 20; a fresh
survivor at Lv. 3 with each of the eight occupations buys at least one node in every tree it has
levels in (SP spent exactly, node reads owned); the sheet lists Max Health 1 as a row with an Unlock
button before the purchase and no Unlock after it; `max_health` ability 0 -> 10 is printed. Fails when
more than 106 nodes are unavailable. Run red before the fix (numbers above, rc 1), green after.

`tools/smoke.sh` needs a writable HOME (Godot makes `user://logs`): under the dsc sandbox run the
verify with `HOME=<scratchpad>/godot-home` set, otherwise Godot exits 134 before boot.

`t_w2_skills` and `t_data` were adjusted only where the wiring changed their subject: t_w2_skills'
`WIRED` list gained `gather`/`butcher`; t_data's tool ladder forced `bone_*` onto `work_pick` (its
first rung's own node) so the rung gates stay monotonic. `tools/smoke.sh` passes.

## Notes / follow-ups

- The online gather path sends an intent and never calls `can_gather`, so the gather technique gate is
  local-only until W3-SRVACT adds it server-side (`harvest_node.can_gather` says so in a comment).
- `Data.butchering_level()` returns the Butchering tree level now; the old `survival.json`
  `butchering_I/II` mirror is still read by nothing (save_sanitizer note unchanged).
- Nodes left unsold can be turned on by adding the effect a system reads and one reader; no schema
  change is needed (`READ_EFFECTS` / `READ_ABILITIES` in `skill_rules.gd`).
