# W1-ITEMS report (claude/mmo-w1-items)

Item identity, tier and level that matter, tool-gated gathering, no lost items.

## What shipped

- **Identity.** `ItemStack` has `uid`, `origin`, `creator` and `created_at`. Stacks with a uid never merge. Fungible stacks and old save rows keep their exact shape. Climate no longer splits gathered stacks.
- **Scaling.** Damage, armour and durability are base x `level_multiplier(level, 0.08)` x `tier_multiplier(material_tier)`, computed inside `ItemStack` and `ProgressionScaling`. `item_def.gd` is untouched.
- **Gathering.** `nature_manifest.json` has a per-family `min_pick_tier`: flint needs stone, obsidian needs flint, copper_ore needs obsidian, black_iron needs copper. Loose stone stays bare-handed. A held pick's power speeds up rock nodes. Manifest yield ranges are honoured. Rock colliders take their size from the manifest. A node waits to regrow while someone stands on it.
- **Crafting.** A craft is refused when the output cannot fit. The inputs stay in the bag until the craft finishes. Consuming the inputs and adding the output then happen in one step (`StationCraft._finish_one`). A cancel, a recipe switch, a save taken mid-craft, a campfire that burns out, island travel or a demolished station therefore cannot strand any items, because nothing was taken. If the bag fills up while the craft runs, the finished craft waits at 100 % with its inputs untouched. It tells the player once to make room and retries every second. The earlier version parked refunds in node metadata that was never saved; that store is gone (review blocker). The crafted level cap rises monotonically with skill (skill 0 caps at 1, no fallback to 60). `preview_level` returns -1 for invalid picks.
- **Cooking.** Burn chance is exposed, falls as cooking skill rises, and takes an injectable RNG. Cancelling a meal past 50 % rolls the raw/poison risk.
- **Weapon in hand.** While a hunt target is set, the hand shows the equipped weapon from props_manifest `weapons`, otherwise the gather tool. Both go through the new `game/scripts/items/held_model.gd` (`HeldModel`), which replaces the instantiate and grip code that StationCraft had copied from PropVisuals. The grip comes from the hand bone's frame, measured in a running scene: +Y runs from the wrist to the fingers, +Z leaves the palm, +X points out of the thumb side. The handle runs across the palm and out of the thumb side, the head points forward and the blade points down. HeldModel also undoes the bone's cm scale (about 0.012), which had made held models draw at 1 % size.
- **Item fields.** `ItemStack.from_dict` loads a null uid, origin or creator as an empty string, never as `'<null>'`. It blanks an origin outside `ItemStack.ORIGINS` and a non-numeric or negative `created_at`.
- **Pick swap.** `HarvestNode.can_gather` swaps picks only when the equipped pick is below the node's minimum tier. A held pick that meets the tier stays in hand, even when a better one is in the bag.
- **Raid probes.** Retuned to the new scaling (maul and kit armour derived from the formula). The boss uses `CreatureGenetics.neutral()` in both raid_gear_probe and raid_fight_probe.

## Commits

- ffd5779 Items: instance identity, level x tier scaling, pick-tier gates, no lost crafts
- 87812db Track t_items.gd.uid
- 7fbe2ab craft_lab and kitchen_lab assert, print PASS and exit 1 on failure
- 3a14389 WIP items (probe retune, shot framing)
- 306ea01 Held tools undo the hand bone's cm scale; untrack uid churn outside W1-ITEMS
- 02e2a61 W1-ITEMS report
- 61ca331 Crafts keep their inputs in the bag until they finish; grip held models in the fist (review fixes)
- (this report update)

## Acceptance checklist (lines copied from runs on 61ca331)

| Item | Output line |
|---|---|
| t_items PASS: uid stacks never merge and round-trip; stone merges; temperate and tropical fibre merge | `[t_items] PASS` (the assertions are in `_test_identity` and `_test_merging` in game/tests/t_items.gd) |
| work_axe L5/L1 >= 1.30 | `[t_items] work_axe L5/L1 = 1.320 (dmg 22.00 -> 29.04)` |
| Copper knife beats stone knife by the tier ratio | `[t_items] copper/stone knife L10 = 1.620 (tier ratio 1.620)` |
| Ores refuse bare hands | `[t_items] bare hands: copper_ore='needs obsidian pick' black_iron='needs copper pick'` |
| Flint pick beats the minimum tier on flint | `[t_items] flint node seconds: stone pick (minimum tier) 3.00, flint pick 2.40, base 3.00` |
| 200 Rock rolls in [2,4], mean > 2.4 | `[t_items] 200 Rock rolls mean=3.06 in_range=true` |
| Full-bag craft refused, inputs unchanged, notice shown | `[craft_lab] PASS full bag: craft refused, inputs unchanged` / `[craft_lab] PASS full bag: refusal notice shown` |
| Station cancel with a full bag loses nothing | `[craft_lab] PASS a running craft leaves its inputs in the bag` / `[craft_lab] PASS station cancel with a full bag loses nothing (inputs never left the bag)`. The spec's wording ("keeps the refund in the station") is superseded: the review showed that store was never saved, and with no refund there is nothing to hold. |
| Recipe switch gives the first recipe's inputs back | `[craft_lab] PASS switching recipe mid-craft keeps the first recipe's inputs` |
| (review) Save and reload mid-craft | `[craft_lab] PASS a save taken mid-craft reloads with the craft's inputs` |
| (review) Campfire burns out mid-craft | `[craft_lab] PASS a campfire burning out mid-craft loses nothing` |
| (review) Bag fills during the craft | `[craft_lab] PASS a finished craft with a full bag waits, inputs untouched` / `[craft_lab] PASS the wait tells the player to make room` / `[craft_lab] PASS it finishes once a slot frees up` |
| (review) No volatile held-item store comes back | asserted in t_items `_test_no_lost_items`; covered by `[t_items] PASS` |
| crafted_level skill 0 <= skill 1 | `[t_items] crafted level mats40 skill0=1 skill1=1 skill20=20 skill60=40` |
| preview_level -1 for invalid picks | asserted in t_items `_test_crafted_level`; covered by `[t_items] PASS` |
| Burn chance monotonic and seeded | `[t_items] burn chance skill0=0.200 skill60=0.050`; `[kitchen_lab] PASS cooking skill lowers the grill burn chance` |
| Raw meal cancel at 60 % applies the risk (now checks the status itself) | `[food] poisoned raw meal cancelled at 60% stomachache=true` / `[kitchen_lab] PASS raw meal cancel at 60% applies a stomachache`; `[food] poisoned raw meal cancelled at 40% stomachache=false` / `[kitchen_lab] PASS raw meal cancel at 40% skips a stomachache`; `[t_items] poisoned raw meal cancelled: at 60% risk='stomachache', at 40% risk=''` |
| (review) Hostile provenance | `[t_items] hostile provenance uid='12345' origin='' creator='' created=0; forged origin='' created=0` |
| (review) A held pick that qualifies is not swapped | `[t_items] copper node with obsidian pick held, copper pick in bag: why='' held=obsidian` |
| --raid-gear-probe 10 of 10 | Not rerun after this fix, because this fix does not touch combat or scaling. From 306ea01: `run1..run10 rc=0`, each with `[gear] PARTIAL ... failures=0` (logs: scratchpad/w1/items/gearR_{1..10}.log) |
| craft_lab and kitchen_lab print PASS and exit 1 on failure | `[craft_lab] PASS` (rc=0), `[kitchen_lab] PASS` (rc=0). An intermediate run of this fix printed `[craft_lab] FAIL count=1` and exited rc=1, which shows the failure path still works. |
| Hand shows the weapon while hunting | `[craft_lab] hand hunting=club calm=work_axe` / `[craft_lab] PASS the hand shows the club while hunting and the axe otherwise`; screenshots below |
| Existing suite | `[tests] PASS` (run_all.gd, rc=0) |
| Smoke | `SMOKE PASS` (tools/smoke.sh --no-import through gslot, rc=0) |

## Raid fight probe (pc-raid-01)

`--raid-fight-probe` still loses. My run (scratchpad/w1/items/fight.log): `[raidfight] PARTIAL t=21.5 bossHP=190483 playerHP=0 rolls=7 contacts=6; seeded L60 gear/melee, home terrain, not earned volcanic raid`. The reviewer's run: `[raidfight] PARTIAL t=37.8 bossHP=187945 playerHP=0`. The probe now uses neutral boss genetics, so its result is reproducible, but the fight cannot be won with seeded L60 melee. **pc-raid-01 stays open.** Its register row routes it to an owner decision on raid winnability (boss HP or the gear curve). This package does not close it.

## Screenshots inspected

Taken windowed at 1600x900, Forward+, `--lab=craft_lab`. The "close" shots follow the right hand at camera size 1.1 and turn the survivor into profile, so a held tool points across the screen:

- `/private/tmp/claude-501/-Users-milankinzy-Documents-deadfront-siege/1899b1df-f06b-4b94-91be-9e3f3c22081d/scratchpad/w1/items/gathertool_close5.png` (crop `gathertool_close5_crop.png`), calm: the work axe's handle runs across the palm under the thumb, the head points forward and the blade points down.
- `.../w1/items/weapon_close5.png` (crop `weapon_close5_crop.png`), hunting: the club stand-in (Kenney hammer) is gripped the same way, with the head forward of the fist.
- `.../w1/items/weapon_close3.png` and `gathertool_close3.png` show the first try at the new grip, taken from the iso angle, where "forward" reads as "down" on screen. `gathertool_close4.png` and `weapon_close4.png` show the grip 2.5 cm too close to the wrist, which PALM.y = 0.11 fixed.
- `.../w1/items/weapon_hand2_crop.png` and `gathertool_hand2_crop.png` show the old grip as the reviewer saw it: head beside an open fist, handle at the wrist.

## Assumptions

- `food.gd`: a master cook (skill 60) burns a quarter as often as a novice.
- `progression_scaling.gd`: untagged materials map their hardness onto the existing tier ladder.
- `held_model.gd`: the maul and hammer use the club model until they get their own models (moved from station_craft.gd).
- `held_model.gd`: every prop's handle runs up its own Y axis through x = z = 0, and the fist closes 12 % of the way up from the butt. This holds for the Kenney tools and the Meshy crossbow. A model that breaks it needs a per-model grip row.
- `held_model.gd` is a new file in `game/scripts/items/`. The package owns six files in that directory, so I treated the directory as owned. If the integrator disagrees, the file can move unchanged.

## Integrator hooks

1. **Merge order with W1-UI (craft_ui).** `Crafting.preview_level` now returns -1 for unmakeable picks. On this branch alone, `craft_ui.gd:266` and `:430` (W1-UI owns them) print `Lv -1 · 3.0s` / `Lv -1 ×1` on every unmakeable recipe card. W1-UI's `Lv —` change must land with or before W1-ITEMS. If W1-UI lands later, the integrator adds the guard at both lines: `"Lv %d" % lvl if lvl > 0 else "Lv —"`. `station_radial` already guards with `level > 0`.
2. **Pick gate notice (player.gd, W2-PLAYER).** `player._begin_gather` (player.gd:818-821) calls `_auto_equip_tool("pick")` first and only prints `need tool pick`. Bare hands at a copper or iron node therefore never reach `can_gather`'s `needs <tier> pick`, and nothing reaches the screen. The fix is to call `node.can_gather(inventory)` before the auto-equip and pass any refusal to `notice(why)`:
   `var why := node.can_gather(inventory)` then `if why != "": notice(why); return` ahead of the auto-equip block.
   W1-UI's gather radial should also show the option row's `min_tier`, which `HarvestNode.options()` already emits and no UI reads.
3. **can_gather side effects (W2-PLAYER).** `can_gather` still primes `gather_seconds` and may equip the qualifying pick. Both carry a `shortcut:` comment, because protected player.gd reads the field and swings the equipped slot. Move them into the caller when PlayerActions exists.
4. **Asset replacement register.** Add these rows to `docs/orchestration/mmo/asset-replacement.md` under "Items and UI", and change the "Held weapons" row from `IN PROGRESS` to `REVIEW` (the hand shows the weapon; pixels are in the screenshot list above):

   | Asset | Problem | Route | Package | Status |
   |---|---|---|---|---|
   | Held club (props_manifest `weapons.club` = `kenney/tool-hammer`, `status: stand-in`); maul and hammer borrow it | Low-poly Kenney hammer stands in for a club; the box head reads as a mallet | Blender MCP or Tripo club, handle on +Y through x = z = 0 so HeldModel's grip fits | W2 art (props) | REPLACE |
   | Held gather tools (Kenney `tool-axe`, `tool-axe-upgraded`, `tool-pickaxe`, `tool-pickaxe-upgraded`, `tool-hammer` as the knife stand-in, `tool-hoe`, `tool-shovel`) | Low-poly flat-colour Kenney kit; no knife model at all | Blender set matching the structure atlas, one model per tool class and tier | W2 art (props) | REPLACE |
   | Survivor-v2 hand | No finger bones, so the fist cannot close round a handle; held tools sit across an open hand | Re-rig with fingers plus a grip pose | W2-RERIG | REPLACE |
5. **Item splits (W1-SRVDOM, W2-INV).** `Inventory.remove_at(i, n)` on a uid'd stack returns a copy that keeps the same uid, so both halves share it (the reviewer's probe: `partial remove uid same=true counts 2/3`). Today only `stack_max == 1` crafts get a uid, so this cannot happen yet. Contract v2 puts a uid on every minted stack and requires every uid to be in exactly one container. When that lands, a split must re-mint the taken part's uid on the server (or clear it offline). The right place is a server-side `split` in W1-SRVDOM's handlers, or `Inventory.remove_at` (W2-INV owns inventory.gd).

## Labs to register

None new. `craft_lab` and `kitchen_lab` already exist and now exit 1 on failure.

## Failed or left

- **Open hand.** survivor-v2 has no finger bones, so the hand cannot close around the handle. The handle runs across the open palm under the thumb (see the close crops). A re-rig with fingers is listed under integrator hook 4.
- **Stand-in models.** The club is still the Kenney hammer and the tools are still the Kenney kit. They are low-poly and are now listed for replacement (integrator hook 4), as the owner asked. That register file belongs to the integrator, so this package does not edit it.
- **pc-raid-01** stays open (see Raid fight probe).
- **Unused file.** `harvest_yield.gd` is owned but needed no change.
- **uid files.** `loot_level_probe.gd.uid` and `progression_probe.gd.uid` are untracked again in 61ca331, because this package never edited those scripts. `raid_gear_probe.gd.uid` and `raid_fight_probe.gd.uid` stay tracked, because both scripts were edited. `held_model.gd.uid` is new and tracked.
- **Not rerun:** `--raid-gear-probe` (this fix changes neither combat nor scaling).
