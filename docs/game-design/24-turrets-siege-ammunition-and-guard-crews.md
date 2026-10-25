# 24 | Defensive Turrets, Autonomous Sentries, Tribe Crews and Ammunition

**Status: OWNER-DIRECTED REQUIREMENT (2026-10-25), system spec PROPOSED and not implemented.** Owner: **"We will want different types of turrets, some are automatic, some require a tribe member to man it and ammo."** The owner also supplies a longer prefab-building design: buildings are **actual manufactured instances** which may be **packaged, transported, sold and redeployed** with original maker identity, traits, health, and upgrades intact. This chapter gives turrets that same eventual lifecycle while distinguishing confirmed earlier home/migration rules and conflicting unstable-island reset text. Exact turret types, crafting quantities, range, ammo, manpower, trigger technology, permissions and math remain **review proposals**.

**References:** [08 Blueprints/Worksites/Modular Building](08-blueprints-worksites-and-building.md), [15 Combat Classes](15-pve-exploration-and-combat.md), [23 Processed Weapons/Ammunition](23-weapons-and-material-crafting-progression.md), [05 Material Traits](05-material-level-traits-and-loot.md), [22 Body Mass/Armor](22-dinosaur-mass-armor-and-grappling.md), [03 Paid Private Home Migration](03-private-islands-and-upgrade-migration.md), [Tribe and Workers](../design/tribe-lineage-domain-and-labor.md), [PvPvE siege fairness](../design/pvp-raiding-local-alphas-and-siege-fairness.md). Existing implementation: [FieldCatapult](../../game/scripts/world/field_catapult.gd), [SiegeProjectile](../../game/scripts/combat/siege_projectile.gd), [BuildGrid](../../game/scripts/world/build_grid.gd), [item IDs](../../game/data/items.json), [recipes](../../game/data/recipes.json), [placed building](../../game/scripts/world/placed_building.gd). 

## 1. The combat fantasy and two operating categories

**Crewed siege platforms:** Require an active real **human tribe member** assigned to their turret operator slot in range/with physical access, or direct player operation. Stronger precision, range, heavy weapon control, priority changes and alternate ammunition. A human has individual Dexterity/Might aptitude, learned ranged/Weapon & Tools skill, equipment, stamina/exhaustion, food and safety, and therefore a meaningful specialist role. A dedicated operator can be wounded, captured or killed at exposed outposts; do not give players a free invisible NPC in a tower. A turret requiring two operators may have distinct **gunner vs loader** roles; without a loader it may fire slowly but cannot fire infinitely. If no eligible operator, it remains idle rather than animating autonomously. The existing manual Field Catapult currently requires a **Player** and does not run AI humans; crew assignment will require changes.

**Automatic defenses:** Detect or trigger within a *defined defended lane/sector* and fire **without a human continuously operating** them, but require material to construct, **finite magazines/charges**, reload/rearm time, maintenance, and possibly worker resupply. Proposed early technology is **mechanical** (tripwire, pressure plate, spring/tension, counterweight, one-shot traps). Mid technology can use mechanically sector-triggered torsion launches. Late **repeating clockwork sentries** have mechanical trigger/servo limitations and expensive metal gears and ammunition, not unexplained radar/AI, electronics or magic that the mostly primitive civilization does not otherwise possess. If true 360° tracking/recognition is later desired, it needs a separate owner-approved technology and power/sensing branch rather than sneaking modern guns into the game. **Automatic** here means no continuous operator; a nearby worker may still need to replenish ammunition and reset tension.

**Common rules:**
- Turrets are **structures**, not equipable handheld weapons, and use the existing `BuildGrid` and future **Crafting > blueprints > placed worksite > delivered processed components > construction labor** pipeline; portable field siege platforms may remain a constrained kit exception during migration.
- Both categories must consume **real projectile ammunition or an explicitly defined finite shot/rearm charge**. Melee swinging sentries consume blade integrity/tension/charge and have reset downtime rather than magically spending stone bullets to swing a physical blade. **A loaded tower without ammo cannot shoot.**
- **Unraidable/private home** never faces enemy/player attack; towers there may be displayed, used in legal practice scenarios, packaged/traded, but should not fabricate hostiles as a defense trigger. Remote **PvE** settlements defend against dinos; only optional **PvPvE** settlements engage legitimate opposing player forces.
- Single-player can model PvE raids and operator combat now/future; **true offline PvP is server-authoritative and NOT delivered by a local Godot scene**. Turrets must not claim to protect a settlement on an offline authoritative server that does not exist.

## 2. Candidate turret lineup by tech era and tactical job

**CONVENTION REMAINS LOCKED:** **Dexterity (D)** and **Might (M)** describe the attack's intended control/force identity, and **Impact (I), Pierce (P), Slash (S)** describe the **contact damage**. Do NOT confuse I/P/S with automatic/crewed, attack frequency, or ammunition rate. A machine whose D/M designation reflects its engineered attack style does not acquire imaginary hereditary human IVs just because it is automatic. A crewed weapon's real operator may contribute skills/IVs appropriately. Some large siege platforms need a Might-focused loader but a Dexterity-focused primary gunner; the attack still has **one primary published code**.

| Era (proposal) | Candidate defensive weapon | Operation | Attack code | Real expendable/charge | Natural purpose |
|---|---|---|---|---|---|
| **Early** | **Sling Watchpost** | **Crews: 1 human** | **DI** | Existing `stone_shot` | Affordable accuracy/aimed Impact against small packs at reach, good raised sightline |
| **Early** | **Stake Trip-Sentry** | **Automatic**, fixed trip lane, few shots then rearm | **DP** | New `sharpened_stake_bundle` (prepared branch/bone spikes) | Pierces rushing lightly armored predators; easily flanked/triggered |
| **Early** | **Weighted Log Deadfall** | **Automatic** single triggered drop, manually rearm | **MI** | Loaded heavy log/weighted-charge item or rearm service; no fictional projectile | Mass-based Impact and knockdown vs creatures actually under the falling log |
| **Mid** | **Raptor-Bone Ballista** | **Crews: one gunner; second trained loader optional** | **MP** | New `bone_ballista_bolt` (processed `carved_bone_rib` + treated shaft/sinew) | Heavy piercing point, Brontosaurus/large predator interception; Might affects heavy bracing/reload |
| **Mid** | **Honed Talon Sweep Guard** | **Automatic**, trip line with finite wound spring | **DS** | Installed `honed_talon_set` blade pack loses durability + finite wound trigger/cycle, needs reset | Sweeping actual sharp edges across a close lane to punish light rushers; cannot reach giant shoulders |
| **Mid** | **High Watchbow** | **Crews: 1 human marksman** | **DP** | New `stone_arrows` / `bone_bolts` from Weapon chapter23 | Precision and target weak points, good versus fast light dinosaurs |
| **Late** | **Siege Catapult / Longshot Stonecaster** | **Crews: 1 gunner, optionally 1 loader** | **DI** | **Existing** `stone_shot` and `toxin_pot`, future `shaped_siege_stone` | Long arcing Impact; slow reload and telegraph. This grows the existing manual Field Catapult, not a second incompatible damage system |
| **Late** | **Iron Heavy Harpoon Tower** | **Crews: 1 gunner + 1 loader** | **MP** | New `iron_harpoon_bolt` (forged head+long shaft) | Heavy Pierce vs large exposed anatomical targets; cannot simply pin/capture a Titan on hit |
| **Late** | **Iron Repeating Bolt Sentry** | **Automatic** **sector-triggered** mechanically wound | **DP** | New `iron_bolt_bundle` and stored wound tension/fuel/rearm if required | Finite high-quality rapid defensive volley; great vs light/medium, expensive to run |
| **Late** | **Counterweight Ram Turret** | **Crews: Might-focused winch crew**, fixed impact line | **MI** | Reusable `weighted_ram_head` with wear plus labor/rearm time | High-mass **Impact** at a gate or entrance, particularly against heavy armor, counters charged melee |
| **Late** | **Great Scythe Gate** | **Crews: Might-focused operator**; automatic trip variant only after funded trigger module | **MS** | Forged scythe-blade assembly with wear, rearm energy/crew work | Heavy **Slash** sweep across exposed large flank/leg at gate range; distinct from fast finesse DS guard |

**Important tactical counterbalance:** Attack family counters the **struck armor zone**: **Slash** is best against **Exposed/Light**, **Pierce** against **Light/Medium**, **Impact** against **Medium/Heavy**. Tower emplacement height, line of sight, minimum/maximum engagement range, projectile flight and actual target body/leg location must apply. A giant Brontosaurus's plate-covered torso isn't automatically vulnerable to a low-mounted blade guard; open legs and valid reach still count. **Heavy armor blocks ordinary raptor Pounce pin attempts** at covered regions; turret bolts/stones are independent collision attacks.

**Never classify DI vs MI by cadence alone**: catapult DI reflects aim/trajectory/long-distance reward; counterweight ram MI reflects physical heavy impaction. The high watchbow DP tracks accuracy/weak point, whereas a heavy mechanical ballista MP prioritizes heavy impulse/bracing/crew effort.

## 3. Ammo economy, magazine, reloading and manufacturing

### 3.1 Verified shipped assets (not hypothetical)

- `game/data/items.json` includes **`stone_shot`**, **`toxin_pot`**, **`catapult_kit`**. `game/data/recipes.json` has the same outputs including `stone_shot` (`stone` input, yields 5 shots), `toxin_pot` and `catapult_kit`.
- `game/scripts/world/field_catapult.gd` is currently a **manually fired, destructible** platform, ~200 HP, 3-second reload, near-player interaction, consumes **one `stone_shot` or `toxin_pot` from the actual PLAYER inventory per activation**, and can shoot a specified creature at range ~8–24m. Its `operator: Player` is not a worker AI. It serializes HP and reload timer, and has a 3×3 footprint in `props_manifest`.
- `game/scripts/combat/siege_projectile.gd` handles non-homing fixed-landing arcing stone flight, visible marker, line-of-sight and area damage/status. It is tied to the source `Player`; AI tribe operators, structure ammo bins, autonomous triggers, ownership/targets and the new turret types do NOT yet work.
- Other specific bolts/stakes/blade charge components listed above are **MISSING NEW ITEM/RECIPE/PROJECTILE DEFINITIONS**. The earlier [23 weapon progression](23-weapons-and-material-crafting-progression.md) already tracks `stone_arrows`, `bone_bolts`, `iron_bolt_magazine` and shaped/processed wood, bone, sinew, copper/iron parts, but these new items are also still design-only.

### 3.2 Proposed ammo and supply model

Every turret instance defines:
`ammo_accepted_ids`, `magazine_capacity`, `ammo_loaded`, `ammo_reserve`, `shots_per_activation`, `reload_duration`, `arming_cost`, `requires_loader`, `durability`, `base_range`, `minimum_range`, `fire_arc`, `line_of_sight`, `valid_target_factions`, `operator_id`, `priority_mode`.

- **Personal operation:** The gunner fires loaded ammo or, for the existing Field Catapult during migration, existing direct-inventory ammo. Do not consume both personal ammo and reserve ammo in one shot.
- **Crewed resupply:** Tribe members physically carry `stone_shot`, `bone_ballista_bolt`, `iron_bolt_bundle`, `toxin_pot` or other accepted ammo to a turret bin/magazine. Reload requires operator/loader labor and viable pathing. If crew is on another job or absent, the turret does not keep firing. Ammo is **finite**, each projectile has an instance/stack debit recorded exactly once.
- **Automatic resupply:** Auto triggers and fires from installed **finite magazine** with no operator; no manual daily aim needed. Refill/rearm requires hauling worker or player replenishment and some time, plus springs/gear wear or energy source. `Not manned` does NOT mean infinite ammunition, indefinite firing speed, or workers teleporting supplies.
- **Ammo as real material:** early stone shots use stone; wooden stakes use cut/tied wood/bone; mid bolts use carved dinosaur bones, tendons and treated planks; late iron bolts or heavy harpoons require true `iron_ore → iron_ingot → refined_iron_bar → forged_head` and treated shaft/bindings. All endgame assembled ammo and turret parts use **processed components**, not just raw stone+ingot in a final recipe. For toxins, existing `toxin_pot` requires actual ingredient processing.
- **Ammo traits:** crafted ammunition inherits relevant material traits (e.g. dense stone improves Impact but heavier slow launch, straight shaft improves accuracy, barbed tooth improves bleeding if weapon actually Pierce); defects affect breakage/misfires; finite magazines don't independently reroll each shot as rare materials.
- **Siege economy:** forged projectiles and toxic special ammo should be expensive enough that attacks and defensive fire have real costs. Avoid defense-structure spam nullifying the cost of player siege permits / frontier risk. Rare dino parts create tradable ammunition-specialist professions.

### 3.3 Example new ammo and turret component recipes, all PRELIMINARY

| Item ID [ADD] | Proposed manufactured recipe | Station & other dependency |
|---|---|---|
| `sharpened_stake_bundle` ×4 | `plank ×1 + carved_bone_rib ×1 + twine ×1` | Workbench; `carved_bone_rib` [ADD in chapter23] |
| `bone_ballista_bolt` ×2 | `carved_bone_rib ×1 + treated_plank ×1 + sinew_cord ×1` | Workbench, material processing chain in chapter23 |
| `iron_bolt_bundle` ×4 | `forged_spearhead ×1 + treated_plank ×1 + cured_hide_binding ×1` | Forge + metal shaping, source iron required |
| `iron_harpoon_bolt` ×1 | `forged_spearhead ×1 + long_lance_shaft ×1 + cured_hide_binding ×1` | Forge and weapon assembly; advanced larger projectile |
| `shaped_siege_stone` ×3 | `cut_stone_block ×1` | Stoneworking station and cut stone processing [ADD] |
| `weighted_ram_head` ×1 | `reinforced_bone_block ×1 + shaped_scute_plate ×1 + forged_iron_fittings ×1` | Forge/Carpentry, final high-mass head retains mass trait |
| `great_scythe_blade` ×1 | `forged_greatblade ×1 + reinforced_haft ×1 + iron_chain_links ×1` | Forge, role-specific shaped part |

**Ammo recipe precision note:** An iron bolt bundle shaped from one large `forged_spearhead` is a **gameplay resource simplification**, not a claim every bolt uses a lance-sized head. If needed, add a proper `forged_bolt_points` intermediate with strict per-metal source before implementation. Likewise stone shape/weight controls should reflect the physical launcher.

### 3.4 Turret material and worksite blueprint bill

Do not merely `wood ×8 → magical late automatic turret`. New structures need processed `reinforced_stock`, `reinforced_bone_block`, `treated_plank`, `forged_iron_fittings`, `braided_sinew_cable`, `support_pillar`, `iron_trigger_mechanism`, assembled engine `windlass_winch` [ADD], and mounted firing mechanism appropriate to their construction era.

**Illustrative automatic mid DP sentry `torsion_stake_turret` blueprint:**
- *Blueprint crafting cost:* modest paper/twine/frame planning item, **separate** from material investment.
- *Site deliveries:* `support_pillar ×2`, `carved_bone_rib ×2`, `sinew_cord ×2`, `treated_plank ×2`, `cured_hide_binding ×2`, `tripline_trigger ×1 [ADD]`.
- *Construction labor:* Construction skill to initiate, manually built site over stages.
- *Ammo:* `sharpened_stake_bundle` loaded **after** completed building is available, not treated as permanent included infinite ammunition.

**Illustrative heavy crewed MP harpoon tower `heavy_harpoon_tower`:**
- Site deliveries: `reinforced_beam ×2`, `reinforced_stock ×1`, `braided_sinew_cable ×2`, `iron_trigger_mechanism ×1`, `forged_iron_fittings ×3`, `cured_hide_binding ×2`.
- Requires qualified Construction + Processing/Metalwork supply chain; **ammo loaded separately**, only fires if appropriate crewmembers physically assigned and available.

**No turrets or ammo above were added to actual `items.json` or `recipes.json` by this document.**

## 4. Operators, team orders, targeting and online/offline behavior

### 4.1 Human operator assignment

A turret has `gunner_slot` and optionally `loader_slot`, referencing a **persistent tribe human ID** and validated current alive/present/authorized state. The player can manually operate a crewed device. Workers must leave other jobs or allocate per-job work time and physically reach the workstation. Construction skill builds the turret; **Weapon/Tools and Ranged proficiency** operate it, distinct career roles. **Might** favors heavy crank/tension work, recoil/physical emplacement, or operator strength in MP/MI devices; **Dexterity** favors aimed shots/lead calculations, DI/DP precision and tracking. A learned operator's actual control skill can apply to the compatible turret mode, never make every turret use both IVs as equal arbitrary damage multipliers.

**Proposed UI priority modes:** Hold Fire; Creatures Only; Hostiles Only (only if valid PvPvE target); Closest; Threat to Workers/Structures; Large/Armored Priority; Focus Marked Target; Save Special Ammo. Priority cannot override home-safe, faction, ceasefire, target validation or line of fire.

**Failure/recovery:**
- Human out of ammo, eating, tired, injured, stunned, assigned a different work order, on boat, captive or dead: turret **idles** or decreases operation depending its approved staffing rule.
- Off-hours shifts are deliberate; permanently stationing a master carpenter as a tower gunner carries real opportunity cost. Multiple guard crews could rotate and consume food/shelter while stationed remotely.
- Autoturrets have no crew slot but may accept a paid **resupply job** and sensible remote disable/rearm commands.

### 4.2 Automatic acquisition, line of fire and safety

- Sensor/trigger has clear game explanation: tripwire/pressure/sector mechanical linkage in early/mid; clockwork winding and linked trigger sectors in late. **No free omniscient detection through forests, walls or islands.**
- **Owned tamed dinosaurs, player's tribe members, friendly/allied humans/structures, and neutral nonthreats** are excluded by faction/territory rules where possible. Triggered physical traps can still be risky to friendlies if their detection type cannot identify friend from foe; provide owner warning/arming zones, disarm controls and guard lanes, and never pretend a tripwire possesses faction recognition when it doesn't. Fully automatic discriminatory targeting beyond credible sensors is a separate tech decision.
- Aim must use *actual projectile trajectory*, LOS, muzzle clearance, ballistic travel and hitbox contact. Fixed arrows can be dodged; planted heavy turret footprints and tall platform firing angles can make near-range blind spots. A tower doesn't fire through its own wall/roof.
- Prioritize threats the turret can really reach. Heavy Brontosaurus vs low tripline or blades: hit leg only if strike geometry intersects; no tabletop auto damage to armored torso. Attack type/resistance is local. Do not have stationary traps apply a universal nongeometric `Pinned` status.
- Ammo expiry: common stones/metal bolts are nonperishable under food system; `toxin_pot` may have its own perishability/chemical stability if later designed, NOT assume food spoilage timer on every projectile.
- Siege placement must have min spacing, firing arcs, occupation/worksite land costs and no magical nested placement to defeat raids; drones/pet units occupy real simulation budgets.

### 4.3 Raid balance and performance

**Decision protection:** Private home islands cannot be attacked by dinosaurs or other players; turrets defend voluntary remote **PvE** outposts against dinosaur attacks and optional level-gated **PvPvE** settlements against player raids. An attacker should be able to scout, approach from blind arcs, disrupt supply, destroy vulnerable turret components, exhaust ammo, distract/disable crew, use armored dinosaurs, or invest in costly siege. Operators are exposed, valuable actual humans with death/capture stakes, so keep warnings and rescue possibilities to avoid oppressive unavoidable permadeath.

**Proposed constraint model:**
- Automatic turret expected DPS (given real targets) **lower** than skillful crewed turret of comparable cost, especially when firing down a fixed lane. Its strategic edge is continuous vigilance and lower labor commitment.
- Crewed turret improves with human investment, but availability under exhausted/absent crew and ammo hauling makes it vulnerable. Expensive two-person harpoons hit giants harder but are sluggish versus fast swarms.
- Automatic defense min interval/ammo reserve and max active units depend on structure footprint, tech, upkeep, guard area and server simulation budget. Avoid simple hard cap if sensible economic pressure is enough, but prevent infinite turret carpet.
- Once a hostile raid starts, packing/dismantling a defensive turret is restricted by combat state and territory rules; a protected boat that **departs during a raid** can still carry **already-packaged** prior cargo, without enabling mid-raid instant defensive removal.
- Multiple turrets cannot all shoot through same cover/crew to kill players without line of sight; performance throttle AI evaluation and projectile counts on mobile.
- **Offline single-player:** only simulate what existing world/raid systems genuinely simulate; do not run unfounded live multiplayer claims. **Future true PvPvE** requires server-authoritative target validation, projectiles, ammunition spending, damage, ownership and log timestamps, including persistent loaded magazines.

## 5. Finished turrets are manufactured buildings with a lifecycle (OWNER-SUPPLIED NEW BUILDING CONTEXT)

**The attached prefab-building source, in the user's own design context, explicitly requests ALL completed buildings be packable and tradable**, retaining the **same unique persistent structure instance** across world placement, inventory, marketplace sale and redeployment. A turret follows that future rule, with combat-specific restrictions:

1. **Build** via learned/crafted blueprint, real manufactured worksite components, construction labor, owner/maker mark.
2. **Install and operate**: activate only after completed; fit targeting/trigger mechanisms and load ammunition; store structure's current HP/condition, traits, appearance and upgrades.
3. **Pack** after ownership validation, only outside active combat/raid. Operator and loader **disembark/unassign**. **Empty all ammunition and supply bins** into valid owner inventory/storage or require manual unloading; no ammo hidden in a packed turret. Require no prisoner/stored humans, dinosaurs or nesting storage. No damaged-structure magical repair.
4. **Atomically convert** deployed `building_instance_id` into **ONE** packaged item with same owner, maker, variant, crafted material-level/trait provenance, base/max HP, upgrades and visible condition. Grid footprint vacated once. Package is a genuine tradable asset, not just the blueprint knowledge.
5. **Trade, transport and resell** while honoring package mass/size and boat+harbor capacity. Keep creator's mark and acquired ownership, no skill requirement to operate/deploy a correctly made turret unless a true runtime crew skill applies. Distinguish **builder skill needed to manufacture** vs **operator skill needed to fire**.
6. **Deploy** valid placement from package. Restore original HP, improvements, cosmetic choices, current reload/condition rules, **zero hidden ammo** and the same instance ID. No new construction payment, although large heavy towers may require a proposed **separate assembly time and crews**. No simultaneously live inventory package and world building.
7. **Salvage/dismantle** is distinct, destroying the unique built structure and recovering materials according to the applicable island, cancellation or owner migration policy. Do not get BOTH a fully intact packaged turret AND a full component refund.

**Critical data entity distinction:**
`TurretDefinition` static recipe/model/footprint/caliber/class;
`BuildingInstance` persistent manufactured unique object, maker+owner+level+trait/quality+durability+upgrade+decor;
`TurretRuntime` transient aiming/reload/operator/loaded ammo/targeting and attack state, serialized as needed;
`PackagedBuildingItem` holds one reference/snapshot of unique `BuildingInstance` (no duplicate serialization paths).

**Conflict explicitly left OPEN:** The attached supplied BUILDING SYSTEM DESIGN says unstable island reset **destroys everything left behind** with no resource refund, whereas the established Deadfront `WORLD-01` decision and [03 island migration](03-private-islands-and-upgrade-migration.md) say unstable island reset **auto-dismantles placed bases into the special recovery vault** (refund percentage open). Do **NOT** silently implement both or overwrite the owner decision: pending explicit owner reconciliation. The confirmed paid **private-home upgrade** is separate and refunds **100% of invested materials** to a special vault, not a second intact packaged building.

## 6. Implementation gap register for Claude

**TURRET-01** Define typed `turret_definitions.json` or extend `props_manifest` with operator mode (auto/crewed), six-class combat code, ammunition IDs, trigger mode, target constraints, ownership, size, range, arc, damage, recoil, reload, magazine, station, materials/skill tier and durability.

**TURRET-02** Preserve/manual-convert the existing **Field Catapult** `Player`-only operator and physical `stone_shot/toxin_pot` ammo into an interface that also handles **real tribe humans** with the same shot physics and authorized target selection. Keep its current functionality and old save compatibility.

**TURRET-03** Implement turret **ammo bin/magazine**, strict accepted ammo IDs, ammo consumption exactly once per shot, optional loader crew, worker physical resupply, no shooting empty, persistence through save/load/offline, visible reload and ammo UI.

**TURRET-04** Implement **automatic trigger/sectors**, tripwire/pressure/clockwork wind-up, no omniscient 360° tracking or through-wall targeting, finite charges/rewinding and crewless operation. Friendly-trigger semantics and lane warnings must be clear.

**TURRET-05** Implement **crewed tower assignments**, persistent gunner+loader IDs, pathfinding to station, manual player override, Energy/skill/Might/Dexterity stats, available/injured/captive/absent worker state, rotation and hold-fire/priority orders.

**TURRET-06** Add early/mid/late turret blueprint items+**worked** construction recipes, new ammunition item IDs/recipes with real source/butchery/gather pipelines (WPN chapter23), upgrade/mount parts, visual art, animations and damage-type/status/armor interactions. Prototype one automatic and one crewed first.

**TURRET-07** Simulate real ballistic/melee hit geometry, line-of-sight, range + minimum blind spot, turret height, Impact/Pierce/Slash counter mapping, heavy animal armor and foot/stagger consistency, correct enemy and allied targeting, threat/aggro response.

**TURRET-08** Implement safe home versus exposed PvE/PvPvE raid permissions, anti-targeting-through-protected territory, no hostile fire at safe home, and **server authority** requirements for any real offline PvPvE.

**TURRET-09** Save loaded ammo, reload timer, turret damage, maintenance/wear/repair, crew assignment, target policy, operator shift and offline states; enforce finite ammo and no ghost workers/auto-resupply.

**TURRET-10** Implement the new **completed building pack/trade/deploy identity lifecycle** (in collaboration with **BUILD-13** in 08): persistent maker+owner ID, condition/traits/upgrade, unload ammo+crew, raid packing restriction, atomic item↔world switch, buyer deployment without original construction skill, boat/harbor cargo and unique ownership.

**TURRET-11** UI: turret inspector showing **Automatic / Crewed**, code, loaded/total ammo, valid firing arc and dead zone, target priority, operator/loader, repair state, refill requests, free crew vacancy, target/shot history and trait bonuses. Display defense preview vs representative dinosaurs (small pack vs Brontosaurus armored/soft leg).

**TURRET-12** Tests: manual existing catapult preserved; empty auto turret never shoots; loaded auto turret fires exactly once per trigger; crewed without available human does nothing; operator with low Energy/restricted skill appropriately penalized; a pounce cannot jump into a player-only turret collision exploit; magazine debited once; friendly not fired on by discriminator/physical traps clearly marked; LOS and vertical geometry valid; automatic no radar tracking; tower saves reload with same HP/rounds; pack unload/crew clear; trade retains maker/ID; safe home cannot be raided; reset behavior flags open conflict rather than lost vault migration; no turret duplicated on any partial transaction.

## 7. Recommended first game-playable vertical slice

**First implement:** (A) current **crewed Field Catapult** supports an assigned tribe human and dedicated ammo bin (stone shot) while keeping player-fired legacy behavior, then (B) one **automatic fixed-lane Torsion Stake Sentry** with stone/bone ammunition, trip trigger, magazine and worker refill.

**Demonstration:** Put the manned catapult atop an actual worksite-built watchtower at an exposed PvE outpost and assign a real tribe member. Load `stone_shot×6`. Place an auto stake sentry at gate with `sharpened_stake_bundle×2`. Spawn a legitimate approaching raptor pack: the automatic weapon fires on a triggered lane until empty and requires resupply; the staffed catapult accepts the human command, spends one shot and deals actual area Impact. Remove gunner -> catapult stops; resupply stake ammo -> sentry can rearm; save/load -> no ammo refills; build and pack after noncombat -> unique condition, materials, maker mark and empty ammo maintained. **Then** expand to heavy Iron Harpoon, late mechanically triggered Repeating Bolt, scythe and counterweight Impact turret using same architecture.

**This chapter adds SPECIFICATION only.** No live turret definitions beyond the existing Field Catapult, no crew staffing of its shots, and no new ammo, automatic sentry code or packaged turret entities have been implemented.
