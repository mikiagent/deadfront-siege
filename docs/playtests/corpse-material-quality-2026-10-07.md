# Corpse material quality, October 7

## Earned-path audit

Actual volcanic60 runtime offers black iron ore, branches, fibre and stone at levels55-60. Player gathering downranks those stacks to max(Gathering,5), so Survival55 alone cannot earn high-level inputs. Ingot needs two ore per metal unit and workbench; lashing can come from fibre->twine. Processing skill caps the ingot quality. These are source/audit findings, not an earned journey.

## Blocking bug

Corpse.setup records creature.level, but _roll_loot previously omitted that value when creating stacks. All standard hides defaulted to level1 even from a high-level animal. Raid armor averages every consumed material unit. With hide1 and all other inputs60, each armor recipe produced at most level36, below its quality55 gate. No alternative hide upgrade raises material quality.

Fix passes source creature quality into ItemStack.make and stamps the same level attribute. No quantities, rarity unlocks, poison meat rules, armor/weapon stats, raid gates or progression formulas changed. This also restores source quality on meat/bone drops; their existing scaled food values now follow creature level.

## Evidence and limits

Run Godot4.7 --path game -- --new-game --loot-level-probe. It selects the actual generated volcanic boss then makes seeded corpse fixtures at levels1/55/60. Baseline had12 failures; patched probe has0. All drops preserve source level, hide participates at the same quality, and poisoned corpse excludes meat. Helm with other inputs60 is36 at hide1,58 at hide55,60 at hide60. Full regression suite PASS.

Inspected960x600 local inventory pixels show the fixture hide in bag/storage. Existing selected-item tooltip is clipped after its first line at this size; level60 is verified by the probe, not that clipped screenshot. This is a seeded corpse/inventory view, not a killed boss or an earned journey. No production deployment or raid-clear claim.
