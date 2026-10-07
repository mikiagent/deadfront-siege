# Declared crafting skill XP, October 7

Crafting used the recipe skill for timing/quality/gates but ignored it for XP, unless a separate tree field existed. Output-category inference sent thread/cloth/bandage/dressings/splints to Processing despite Tailoring labels. Ten real thread crafts in the fresh12-minute accelerated training run left Tailoring0.

Fix precedence: explicit tree, declared skill, legacy output category fallback. Amount is unchanged at6+integer recipe seconds. This changes15 currently mismatched recipes: Tailoring for bandage/pressure_dressing/splint/thread/cloth/tent_kit/canvas_tent_kit; Processing for dry_meat/smoke_meat; Construction for empty_bucket; WeaponTools for rope_snare/heavy_snare/stone_shot/catapult_kit/toxin_pot. This is an XP routing correction with progression impact, not a cosmetic edit.

Godot4.7 full regression suite PASS. Tests cover all declared recipe skills, explicit tree precedence and legacy club inference. Fresh interaction-driven12-minute rerun,10x clock, no inventory/XP/vital seeds or occupation: earned Survival11/Gathering6/Processing3/WeaponTools3/Tailoring3,0deaths. Before fix a comparable run had Survival10/Gathering6/Processing4/WeaponTools3/Tailoring0. Gather/AI variation means these are not a controlled timing benchmark. Both use real player gather/craft entrypoints and headless validated building placement, not pointer/pixels or normal-speed acceptance.

Still open: high-level training gates, bag/storage handling, actual high-tier hide kills, high-quality ingots/twine, paid harbour, crafted raid kit and earned raid victory. Bag approached18/20 in the short run. No production deployment or raid clear claimed.
