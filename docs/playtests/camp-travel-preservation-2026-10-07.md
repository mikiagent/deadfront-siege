# Home camp travel preservation, October 7

Earned training built four baskets/stations. Paid volcanic departure/free return discarded them: World.travel neither captured the home camp before replacing its runtime nor restored the cached builds on return. Save loader restored buildings only on full load. The next save overwrote the cache with an empty camp. Earned XP persisted, but that does not establish retained camp/material continuity.

Fix snapshots live home state before departure and restores cached structures on home arrival before saving. Save snapshot filters queued-deletion/noncurrent-runtime buildings so an old island awaiting deletion cannot duplicate or contaminate the new home cache. No travel price, gate, stat, loot or inventory-capacity changes. Previously lost structures are not recreated by this fix.

Godot4.7 full suite PASS. Dedicated --new-game --camp-travel-probe seeds one basket/materials/proficiency/coins, with no predeparture save: baseline4failures; patched two paid sail/free returns preserve exactly one basket, cell(8,8),rotation1,7branchesquality55,correct10Ttotal debit. Explicit seeded fixture, not earned building or journey proof. Existing earned checkpoint was backed up/restored around tests.

Inspected960x600 local return scene shows home harbour/default camp, survivor and cargo basket. Seeded restored test basket is outside this camera view; its pose/count/quality are source-verified, not visually confirmed. No visual completion claim for that basket. Human pointer travel untested. No production deployment.

Current earned chain is Survival60/Gathering37/Processing34/WeaponTools20/Tailoring20. Further training remains open. The earlier earned Survival55/paid5Tvolcanic/free-return button evidence is valid for gates/payment, but camp loss means it is not a clean complete earned journey. Do not silently replace that lost camp with seeded structures.
