<!-- Owner's file: 14_domain_land_claiming_and_territories.md (2026-10-21). Filed as 29 because 14 is the Island Market UI. Screenshots: docs/reference/durango-domain-*.webp -->

# 14. Durango: Wild Lands — Domains, Land Claiming, and Territorial Progression

## Mission
Implement a land-ownership and domain-management system inspired by **Durango: Wild Lands (2019)** in the existing dinosaur survival game. **Inspect the repository first**: locate the world grid, islands, building placement, structure ownership, clans, economy, permissions, persistence, UI, and networking. Extend those systems rather than creating parallel ownership logic. Implement functional gameplay, not just mockups.

The central loop is **choose a home island → declare a Domain → claim connected plots → construct within owned land → progress to expand → establish shared settlements → optionally compete for strategic outposts**.

## 1. Historical types of territory

| Territory | Ownership | Purpose | Key behavior |
|---|---|---|---|
| **Tamed Island Domain** | Individual | Permanent home and workshop | No periodic territory rent; ordinary building deterioration was absent on personal islands |
| **Civilized Island Domain** | Individual in shared world | Public settlement near players and resources | Claim upkeep/renewal and building deterioration; abandoned/expired land could become claimable |
| **Clan Enclave** | Clan | Communal village and facilities | Unlocked through clan advancement; size grows with clan level; role-based access |
| **Savage Island Outpost** | Clan | Strategic contested territory | Linked to eligible Courier Warp Holes, extraction logistics, and competitive control |

Do not conflate the four ownership scopes. A visitor entering a domain does **not** automatically gain access to every structure or storage chest inside it.

**Historical accuracy convention:** Preserve well-documented mechanics, label community-reported numerical limits as provisional, and make uncertain rules configurable. Never describe a modern restoration formula as verified 2019 server code.

## 2. The Domain UI and navigation

Implement **Gameplay HUD → Main Menu → Domain**, with sections matching the original concepts:
- Tamed Island
- Civilized Island
- Clan
- Outpost

Show current island, ownership, domain location, current plots/max plots, available expansion opportunities, upkeep state (only where relevant), permissions, and buttons for **Declare**, **Expand**, **Manage**, **Renew**, or **Release** when legal. Connect every button to authoritative gameplay logic.

When declaring or expanding, enter a ground-grid preview: claimed cells distinguished from eligible cells, with invalid cells shown clearly. Show candidate plot count and cost/requirements. Allow confirm/cancel and camera movement. Ensure clear touch controls in landscape and mouse controls on desktop. The original game used a visually explicit ground claim/placement interface; recreate that experience in the existing UI style.

## 3. Plot/cell model

Use a consistent coordinate system tied to the project's existing world grid. A historical restoration describes one claim cell as a **4×4 block of world tiles**; use this as a configurable initial scale, not a guaranteed universal original constant.

A domain contains a unique ID, territory type, owner ID or clan ID, island ID, set of plot coordinates, cap, permissions, status, and any renewal timestamps. Separate **plot ownership** from the identity and ownership of **structures and stored items**.

Suggested logical record (adapt to existing engine/database):

```json
{
  "domain_id": "domain_001",
  "kind": "tamed_island",
  "island_id": "island_001",
  "owner_player_id": "player_01",
  "owner_clan_id": null,
  "claimed_cells": [[10, 12], [10, 13]],
  "max_cells": 13,
  "status": "active",
  "renewal_deadline": null,
  "permissions_profile_id": "permissions_001"
}
```

Validate terrain suitability, island restrictions, plot collisions, required distance from protected features, claim cap, and adjacency/contiguity where appropriate. Default to **contiguous expansion** and configure exceptions only when confirmed or intentionally designed. Claims must be atomic in multiplayer; two players cannot own the same cell.

## 4. Personal Tamed Island Domain

Give a player access to a private home island early in progression. Durango let players choose among **five island shapes**; if the game has island templates, expose five where practical, otherwise keep template selection modular.

Core rules:
- Starting claim limit: **13 plots**, a historical reference value.
- No recurring land tax on a Tamed Island.
- No ordinary environmental structure decay on a Tamed Island.
- Builds inside this domain can include homes, storage, workshops, gardens, and taming pens when unlocked.
- Player can invite visitors and grant narrow usage permissions; ownership remains with the player.
- Persist claimed terrain, placed buildings, crops, storage contents, and animals across saves/restarts.

### Private island expansion
Use a domain **Expand** interaction. The owner chooses eligible adjacent cells, sees new territory outlines, and confirms. Validate the cap and persist the claim before allowing new construction.

### Island progression / Personal Communications Center
Historically, late-game progression used a **Personal Communications Center** to increase island Pioneer rank and plot capacity via resource contributions. It was associated with level-60 progression. Implement a contribution-driven upgrade track connected to existing inventory/construction/progression.

Historical community-reported reference milestones:

| Progress milestone | Maximum claimed plots |
|---|---:|
| Starting | 13 |
| Pioneer Rank 2 | 17 |
| Pioneer Rank 6 | 23 |
| Pioneer Rank 7 | 30 |
| Later advanced progress | Around 50 reported by players |

The intervening ranks/costs are **not established by these examples**. Put them in progression data rather than fabricating an exact original table. Completing an upgrade increases claim *capacity*; it does not instantly assign land.

### Relocation
If supported, allow Domain relocation/redeclaration with a configurable cooldown; historical players reported approximately **24 hours** for certain private-island domain resets. Design explicit handling for existing buildings, crops, active workbench jobs, pets, and storage. Never silently delete valuable items or let the player clone structures by relocating.

## 5. Civilized Island Domains

Allow individual claims on eligible shared-world Civilized Islands:
1. Travel to a Civilized Island.
2. Find an unclaimed eligible location.
3. Open **Domain → Civilized Island → Declare**.
4. Preview claimable cells and confirm.
5. Build and expand inside owned cells.

**Upkeep:** Civilized Island claims had recurring rent/renewal; historical documentation mentions advance renewals up to **28 days** in a particular version. Do not mistake that for a universal initial claim duration. Set the rent formula, payment currency, reminder timing, expiration grace, and maximum prepaid horizon in configuration; use T-Stones if the existing economy supports them.

**Building condition:** Buildings on Civilized Islands deteriorated and needed repair. Reuse construction durability and repair systems; don't alter unrelated carried-item durability. Distinguish natural decay from damage inflicted by players or creatures.

**Expiration:** Make the claim lifecycle explicit, for example `active → renewal_due → expired/released → eligible_for_reclaim`. Historic reports indicate expired land could be claimed by others, but structure ownership, binding, and salvage rules were more complex. Thus expired plot ownership does not imply all containers/items inside are free loot. Use explicit abandonment/salvage policies with safety against theft and duplication.

Consider a recovery/mailbox system for personal or bound possessions if desired as a modern quality-of-life safeguard, and label it a *new design addition*, not documented original behavior.

## 6. Land ownership, structure ownership, and permissions

Use independently enforced permissions for:
- Visiting / entering an island or domain
- Building or placing structures
- Demolishing or moving structures
- Using workstations
- Depositing into storage
- Withdrawing from storage
- Managing farms
- Managing taming pens
- Inviting others and changing permissions
- Paying rent / expanding land / relinquishing claims

Support owner, explicitly trusted players, friends or guests where implemented, clan roles, and public-access flags. **Permission checks belong in server-authoritative gameplay services**, not solely in disabled UI buttons.

Crucial invariant: `domain.owner != structure.owner != item.owner` can be valid. Releasing or expiring a claim must not silently rewrite item owners. Handle shared containers with separate ACLs.

## 7. Clan Enclaves

Clan Level **5** is the reported historical unlock for Enclave declaration. Connect Enclave eligibility and expansion to existing clan leveling, rank permissions, and resource contributions.

Reference milestones reported in historical guides:

| Clan level | Enclave plot capacity |
|---|---:|
| 5 | Enclave declaration unlocked |
| 18 | 51 |
| 20 | 57 |
| 22 | 63 |
| 25 | 72 |

Do not invent exact sizes for unlisted levels. Store progression in data and confirm any additional milestones separately.

Support clan-owned plots and communal structures, with officer permissions for claiming/releasing, construction projects, donation of materials, storage access, and upgrades. Clan Enclaves are separate from individual members' personal domains.

Handle clan departure, leadership changes, clan dissolution, and permissions migration. Nobody should acquire private items merely because clan ownership changed.

## 8. Savage Island Outposts

Build this after private/Civilized/clan systems are stable. Historically Outposts were tied to **eligible Courier Warp Holes** on Savage Islands and served as resource-logistics and PvP objectives. Some neutral harbor warp holes could not be claimed. Historical summaries also describe a **one-Outpost-per-clan** limit; make this configurable and verify version-specific implementation details.

Implement strategic claim points instead of allowing arbitrary map-wide outpost placement. Include eligibility, clan permissions, contest or takeover rules compatible with existing PvP, cooldowns, and transfer of territorial control. Preserve ownership of individual objects independently of the outpost owner.

Do not invent a full PvP siege system if the game does not have the necessary combat and multiplayer foundations; implement the claim-point model first and clearly identify blocked dependencies.

## 9. Construction integration

Every building placement must resolve the structure footprint into domain grid cells and ask: Is this placement on eligible owned land? Does the acting player have permission? Does the selected territory permit the structure type? Are the cells unobstructed?

Prevent edge/rotation exploits where a building's anchor tile is claimed but the rest of its footprint crosses unowned land. Enforce permissions again when finalizing construction, repairing, moving, demolishing, and managing jobs.

Integrate with:
- Building quality, material attributes, and Building Ability
- Storage inventories and item ownership
- Cooking, Processing, and weapon crafting stations
- Dinosaur taming pens
- Farming and irrigation/plots, where implemented
- Fatigue-restoring furniture and shelters
- Repair/decay behavior specific to island type

## 10. Progression and economy integration

Private island capacity upgrades should consume explicit items or contributions and reward island progression. Civilized Island renewals should deduct currency exactly once. Clan development should use existing clan XP/rank/cost systems. Outpost ownership should matter for logistics, but any bonuses must be supported by an actual travel/resource mechanic.

Create reliable feedback for current/max plots, claim costs, upkeep obligations, expansion locks, and permission denials. Keep all major values data-driven: starting plots, progression caps, rent, prepayment horizon, decay rates, cooldowns, enclave requirements, and outpost limits.

## 11. Reliability and multiplayer correctness

Implement persistent unique IDs and transactional safeguards for:
- Two simultaneous claims of the same cell
- Rapid repeated Expand clicks
- Concurrent rent payments
- Claim expiration during construction
- Moving or destroying a claimed structure
- Clan role changes during claim transactions
- Relocating with occupied boxes or unfinished jobs
- Server restart while renewal/expiration is due
- Disconnect during expansion or release
- Relisting or transferring items from an expired domain

Make domain state authoritative server-side when multiplayer exists. Persist claim grids efficiently and audit changes. Claims, T-Stone deductions, and structure migrations must never duplicate or lose resources.

## 12. UI acceptance criteria

A player should be able to:
- Open **Main Menu → Domain** and switch among Tamed Island, Civilized Island, Clan, and Outpost tabs.
- See plot capacity and owned cells.
- Place a claim preview, identify valid and invalid terrain, and confirm.
- Expand a contiguous domain when capacity permits.
- See why expansion is blocked (cap, terrain, payment, ownership, or permissions).
- Inspect and manage visitor/structure/storage rights separately.
- See rental status and renew a Civilized Island claim.
- Contribute to and unlock personal island plot-cap upgrades.
- As a clan officer, manage Enclave territory and eligible outpost locations.

Match the project's Durango-inspired earthy landscape-mobile styling: dark translucent panels, compact text, muted greens, gold action highlights, and high-contrast claim boundaries. UI should be functional on mouse/keyboard and landscape touchscreens.

## 13. Implementation phases

**Phase A: Domain foundation:** claim cell data, island types, ownership, bounds, persistence, claim preview.

**Phase B: Tamed Island:** 13-plot initial cap, private domain, expansion, permission checking, permanent-home behavior.

**Phase C: Building integration:** placement footprints, structure/item ownership separation, personal workshops, storage, taming, farms.

**Phase D: Private progression:** Personal Communications Center, contribution requirements, Pioneer ranks, increasing plot capacity.

**Phase E: Civilized Islands:** shared-world claims, rent/renewal, decay/repair, expiration, reclamation safeguards.

**Phase F: Clan Enclaves:** clan-owned land, clan rank controls, territory-cap upgrades, shared structures.

**Phase G: Outposts:** fixed strategic claim points, clan limits, logistics, contested control if PvP supports it.

Deliver and test a working vertical slice before expanding to future phases.

## 14. Required tests

Test: initial 13-plot limit; valid and invalid claims; claim adjacency; terrain/overlap rejection; ownership on island travel; repeated/double requests; structure footprint across domain edge; separate use/withdraw/demolish permissions; accurate capacity upgrades; correct contribution consumption; safe relocation; renewal balance deduction exactly once; expiry after restart; decay only where enabled; bound item restrictions on expired claims; clan officer permissions; clan level unlock and capacities; outpost eligibility/limit; and save/load of every affected inventory, structure, and territory.

**End-to-end test:** Create personal island → declare Domain → claim 13 plots → place storage, workbench, and taming pen → invite guest with workshop-use permission but no withdrawal permission → verify access control → upgrade via Communications Center → expand additional plots → save/reload with all structures and items unchanged. Repeat analogous lease-expiration and clan ownership tests once those features are available.

## 15. Final deliverables

Implement the systems in the repository, then report modified files, integrated components, implemented territory rules, config values and which are historical estimates, UI screens/actions, tests performed, results, multiplayer or persistence limitations, and outstanding work. Do not claim unimplemented features are completed.

**Design principle:** Owning territory grants a right to build/manage land under the applicable rules; it does **not** automatically make every object inside the domain yours.

### Historical references for further verification

- Durango:0 / Homecoming reconstruction and guides: https://kghj76138.github.io/durango-homecoming-guide/
- Historical 2019 player reports and guides for Domain expansion, personal island progression, Civilized Island rent, clan Enclaves, and Outposts. Verify exact patch-level values before treating them as fixed.
