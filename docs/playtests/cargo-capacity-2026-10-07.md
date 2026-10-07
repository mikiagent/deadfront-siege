# Cargo capacity preservation, October 7

Earned training cargo is60/60slots of surplus. World.cargo_warp removed unstable stacks, ignored cargo_home.add remainder, and charged2T even when the destination accepted nothing. Stop before shipping actual high-quality materials.

Fix offers a stabilized copy first, removes only accepted units from the original unstable stack, and charges2T only if some units shipped. Full cargo leaves all original goods and coins unchanged. Partial cargo leaves rejected units unstable in their original slot. No capacity, loot, price or quality increase. Runtime stack cap is999 for nondurable materials, not the raw catalogue cap; fixture reads live ItemDef.stack_max.

Godot4.7 full suite PASS. --new-game --cargo-capacity-probe seeded fixtures: full destination preserves8ore/no fee; partial space2 ships2and leaves6unstable/charges2T; whole shipment retains6stable/charges2T. Baseline failed full/partial preservation and had no remaining original slot. No actual earned goods were shipped or lost; earned save was backed up/restored around tests. This is data-preservation evidence, not pointer/pixels or earned cargo proof.

Current earned checkpoint Survival60/Gathering57/Processing55/WeaponTools59/Tailoring55/Melee3. High-tier ore/fibre/handles, hide hunt, actual kit crafting and earned raid remain open. Cargo training surplus must be moved through real storage UI before a shipment; do not clear it by fiat. No production deployment.
