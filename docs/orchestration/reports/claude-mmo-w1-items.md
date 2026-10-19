# W1-ITEMS report (claude/mmo-w1-items)

Item identity, tier and level that matter, tool-gated gathering, no lost items.

## What shipped

- **Identity.** `ItemStack` has `uid`, `origin`, `creator` and `created_at`. Stacks with a uid never merge. Fungible stacks and old save rows keep their exact shape. Climate no longer splits gathered stacks.
- **Scaling.** Damage, armour and durability are base x `level_multiplier(level, 0.08)` x `tier_multiplier(material_tier)`, computed inside `ItemStack` and `ProgressionScaling`. `item_def.gd` is untouched.
- **Gathering.** `nature_manifest.json` has a per-family `min_pick_tier`: flint needs stone, obsidian needs flint, copper_ore needs obsidian, black_iron needs copper. Loose stone stays bare-handed. A held pick's power speeds up rock nodes. Manifest yield ranges are honoured. Rock colliders take their size from the manifest. A node waits to regrow while someone stands on it.
- **Crafting.** A craft is refused when the output cannot fit. Station refunds and overflow wait at the station instead of being dropped. Switching recipe mid-craft cancels and refunds. The crafted level cap rises monotonically with skill (skill 0 caps at 1, no fallback to 60). `preview_level` returns -1 for invalid picks.
- **Cooking.** Burn chance is exposed, falls as cooking skill rises, and takes an injectable RNG. Cancelling a meal past 50 % rolls the raw/poison risk.
- **Weapon in hand.** While a hunt target is set, the hand shows the equipped weapon from props_manifest `weapons`. Fixed in the final commit: survivor-v2's right-hand anchor has a world scale of about 0.012 (cm armature), so held tools and weapons drew at roughly 1 % size, which made them invisible. `_sync_hand_tool` now divides by the anchor's scale. This also fixes the gather tool, which was invisible in the base branch too.
- **Raid probes.** Retuned to the new scaling (maul and kit armour derived from the formula). The boss uses `CreatureGenetics.neutral()` in both raid_gear_probe and raid_fight_probe.

## Commits

- ffd5779 Items: instance identity, level x tier scaling, pick-tier gates, no lost crafts
- 87812db Track t_items.gd.uid
- 7fbe2ab craft_lab and kitchen_lab assert, print PASS and exit 1 on failure
- 3a14389 WIP items (probe retune, shot framing)
- 306ea01 Held tools undo the hand bone's cm scale; untrack uid churn outside W1-ITEMS
- (this report)

## Acceptance checklist (lines copied from runs on 306ea01)

| Item | Output line |
|---|---|
| t_items PASS: uid stacks never merge and round-trip; stone merges; temperate and tropical fibre merge | `[t_items] PASS` (the assertions are in game/tests/t_items.gd lines 54-82) |
| work_axe L5/L1 >= 1.30 | `[t_items] work_axe L5/L1 = 1.320 (dmg 22.00 -> 29.04)` |
| Copper knife beats stone knife by the tier ratio | `[t_items] copper/stone knife L10 = 1.620 (tier ratio 1.620)` |
| Ores refuse bare hands | `[t_items] bare hands: copper_ore='needs obsidian pick' black_iron='needs copper pick'` |
| Flint pick beats the minimum tier on flint | `[t_items] flint node seconds: stone pick (minimum tier) 3.00, flint pick 2.40, base 3.00` |
| 200 Rock rolls in [2,4], mean > 2.4 | `[t_items] 200 Rock rolls mean=3.06 in_range=true` |
| Full-bag craft refused, inputs unchanged, notice shown | `[craft_lab] PASS full bag: craft refused, inputs unchanged` / `[craft_lab] PASS full bag: refusal notice shown` |
| Station cancel with a full bag keeps the refund at the station | `[craft_lab] PASS station cancel with a full bag keeps the refund in the station` |
| Recipe switch refunds | `[craft_lab] PASS switching recipe mid-craft refunds the first recipe's inputs` |
| crafted_level skill 0 <= skill 1 | `[t_items] crafted level mats40 skill0=1 skill1=1 skill20=20 skill60=40` |
| preview_level -1 for invalid picks | asserted in t_items.gd:182; covered by `[t_items] PASS` |
| Burn chance monotonic and seeded | `[t_items] burn chance skill0=0.200 skill60=0.050`; `[kitchen_lab] PASS cooking skill lowers the grill burn chance` |
| Raw meal cancel at 60 % rolls risk | `[kitchen_lab] PASS raw meal cancel at 60% applies the raw-risk roll` |
| --raid-gear-probe 10 of 10 | `run1..run10 rc=0`, each with `[gear] PARTIAL ... failures=0` (logs: scratchpad/w1/items/gearR_{1..10}.log) |
| craft_lab and kitchen_lab print PASS and exit 1 on failure | `[craft_lab] PASS` (rc=0), `[kitchen_lab] PASS` (rc=0) |
| Hand shows the weapon while hunting | `[craft_lab] PASS the hand shows the club while hunting and the axe otherwise`; screenshot below |
| Existing suite | `[tests] PASS` (run_all.gd, rc=0) |
| Smoke | `SMOKE PASS` (tools/smoke.sh --no-import through gslot) |

## Screenshots inspected

Taken windowed at 1600x900, Forward+, `--lab=craft_lab`:

- `/private/tmp/claude-501/-Users-milankinzy-Documents-deadfront-siege/1899b1df-f06b-4b94-91be-9e3f3c22081d/scratchpad/w1/items/weapon_hand2.png` (crop: `weapon_hand2_crop.png`): while hunting, the club stand-in (the Kenney hammer model) is in the right hand.
- `.../w1/items/gathertool_hand2.png` (crop: `gathertool_hand2_crop.png`): when calm, the work axe is in the hand at full size.
- `.../w1/items/weapon_hand.png` and `gathertool_hand.png` are the earlier shots, taken before the fix. The hand is empty in both.

## Assumptions

- `food.gd`: a master cook (skill 60) burns a quarter as often as a novice.
- `progression_scaling.gd`: untagged materials map their hardness onto the existing tier ladder.
- `station_craft.gd`: the maul and hammer use the club model until they get their own models.

## Integrator hooks

None. Every change sits inside files this package owns.

## Labs to register

None new. `craft_lab` and `kitchen_lab` already exist and now exit 1 on failure.

## Failed or left

- **Grip.** The held club is the Kenney hammer marked `"status": "stand-in"` in props_manifest, and its grip angle is off: the head sits at the fist. This fits the owner's request that low-quality and low-poly assets be marked for replacement. The club's manifest row is already marked stand-in, and the asset replacement register should list it. That register belongs to another package, so it is not edited here.
- **Camera.** The weapon-hand shot crops the survivor's head at camera size 3.0. This affects the shot's framing only.
- **Unused file.** `harvest_yield.gd` is owned but needed no change.
- **uid files.** The WIP commit had tracked .uid files for probes this package does not own. They are untracked again in 306ea01. The owned probe uids (loot_level, progression, raid_gear, raid_fight) stay tracked.
