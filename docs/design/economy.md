# Economy and the Island Market

**Status:** v1, 2026-09-17, owner-directed. Data twin: `game/data/world/market.json`.

## What the research captured, and what it did not

The systems PRD has the Island Market as a system (§14.4), T-stones as the currency it runs on (§14.1), market sales as a faucet and listings as a sink (§14.2–14.3), the rule that specialisation only works because the market exists (§7.3, §23), city islands each having a market and the late-live grouping into **four regional markets** (§4.2), and "list on market" in the daily loop (§3). What it does **not** have is the mechanics that made it fun: how listings worked, what moved prices, and why hauling materials between regions was profitable. That is added here.

## Why it was good

Every island tier and climate had materials only it produced (world design §4), skill points made nobody self-sufficient, and prices differed per market. So a player who specialised in, say, desert salt and copper could sail, gather, cargo-warp home, and list on a market where those were scarce, for T-stones that paid the domain tax and bought the things they could not make. Trade was the connective tissue between occupations, not a vendor.

## Design for this game

### Single-player first, same data model later

There are no other players in v1, so the market is **simulated**: each regional market has settlers with needs, expressed as demand per material category, that the player's sales satisfy. Prices respond to what the player sells and to time. When real players arrive (post-v1), their listings sit in the same order book alongside the simulated ones, and the simulation shrinks as real volume grows.

### Markets

Four regional markets (PRD §4.2), each reachable from the harbour of its region's city island (M9 adds city islands; until then, one market building at the home harbour that represents the nearest region):

| Market | Region climates | Scarce there (pays a premium) | Abundant there (pays little) |
|---|---|---|---|
| **Temperate Exchange** | temperate, grassland, savannah | salt, copper, obsidian, ice, fur, pearl | fibre, wood, berries, clay, herb |
| **Tropic Bazaar** | tropical, blue tropical, swamp | pine resin, fur, ice, silver, flint | palm, bamboo, coconut, reed, coral |
| **Frontier Post** | desert, savannah 45 | wood, reed, clay, herbs, water items | salt, copper, sandstone, cactus |
| **Northern Depot** | tundra, snowfield | bamboo, coconut, cactus flesh, cloth, herbs | fur, resin, pine, ice, silver |

### Prices

`price = base(category) × level_factor(level) × attribute_bonus × regional_demand(market, category) × saturation(market, item)`

- `base` per category and `level_factor` = 1 + 0.06 × level *(design)*; so level-40 fibre is worth 3.4× level-1 fibre. This is where the crafted-level rule pays off: higher-level goods sell for more.
- `attribute_bonus`: +25% per latent attribute, +100% for a rare (green pip) attribute.
- `regional_demand`: from `market.json`, 0.5 (abundant) to 3.0 (scarce).
- `saturation`: each unit the player sells lowers that item's price at that market by 2%, recovering 10% of the gap per real hour *(design)*. Dumping 50 units halves the price; the trader who spreads sales across markets earns more. This is the arbitrage loop.
- Listing fee 5% of the ask, paid up front (PRD sink). Sales settle when the simulated buyer takes them: instantly at or below the computed price, slower above it (a listing 20% over the price sells in about an hour; 50% over never).

### Buying

Markets also **sell** to the player: abundant regional goods at price × 1.3, scarce ones rarely and at price × 2.5. That lets a non-hunter buy meat and a non-tailor buy cloth, which is what forces specialisation to feel fine instead of punishing.

### Unstable goods

Anything still flagged `unstable` cannot be listed. Cargo-warp it first (PRD §14.5). The market screen says so plainly.

### Animals

Bonded animals can be listed as animal items (PRD §14.4). Price = species base × grade multiplier (S 2.0, A 1.5, B 1.0, C 0.7). This is how a capture specialist makes a living.

### T-stone sinks that make selling matter

Sailing to unstable islands, warp hops, opening craters, market listing fees, and later domain tax on city islands. Without sinks the market is pointless; the sinks are the reason to sell.

## Data

`market.json` carries the four markets, category base prices, regional demand multipliers, saturation and recovery rates, listing fee, buy multipliers, and animal grade multipliers. M9 implements the market screen, the simulated settlement, and the price memory in the save file.

## Acceptance

1. Sell 40 units of desert salt at the Temperate Exchange and watch the price fall by roughly half; come back after an hour and it has recovered a fifth of the way.
2. The same salt at the Frontier Post is worth a fifth as much.
3. A level-30 knife lists for about 2.8× a level-1 knife of the same recipe.
4. An `unstable` item cannot be listed until cargo-warped.
