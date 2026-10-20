# Claude implementation prompt: Durango-inspired Island Market and Player Economy

Implement a fixed-price player-to-player **Island Market**, using T-Stones and **exact item instances**. The historic game let players enter Main Menu → Island Market → Sell, select a specific inventory item, set price and register it. Add a convenient **Inventory → Sell on Market** shortcut as a deliberate modern enhancement, not a verified original bag-menu shortcut.

## Seller flow
Open Sell → show eligible inventory instances → select the exact bone/weapon with all attributes → enter price → preview registration fee, anticipated tax and proceeds → confirm. Authoritatively validate ownership, tradeability, market slots, asking price and available T-Stones; atomically charge fee, transfer selected item to escrow, create listing and update UI. Listed goods are unavailable for use, equipment, crafting or second listing. Preserve source instance ID and rare traits.

## Market lifecycle
Support Draft → Active → Sold/Expired/Canceled → Settled/Reclaimed. Store listing ID, seller, original instance ID, price, creation/expiration timestamps, state and charged fees. Expiration rules and listing limits should be configurable because original exact numbers are incompletely verified. Unclaimed expired/canceled items go to safe return storage, never vanish. Allow Seller tabs Active, Sold, Expired, History. Contemporary guides describe Sold/Expired and **Receive All** for claimable proceeds.

## Buyer flow
Browse/search by item name and categories, level range, price, durability, rare attribute and ordinary trait; sort ascending price, level, age etc. A detailed listing must reveal the **actual** instance's level, Firm/Tough Fiber etc, Black Sheen and processing remaining. Buying checks listing still active and buyer currency, atomically debits exact T-Stones, marks Sold, transfers specific item to safe buyer delivery, and creates seller claimable proceeds net of configurable tax. Handle full bags through secure claim/delivery rather than deleting purchases. Two buyers clicking simultaneously must not purchase twice. Offline sellers remain on the market if a persistent backend exists.

## Fees and currency
Use existing currency service or create integer-denominated T-Stones. Distinguish listing registration fees and sales taxes. Deduct exactly once; don't use floating-point money. Original market had both but no single universal rate is confirmed; reported fees varied by sale price. Example **only**: 20,000 price − 200 listing fee − 2,000 tax = 17,800 net. Keep price/fee/tax schedule configurable. Implement safe claim and **Receive All** idempotently with an audit ledger, no double payouts.

## Unique-item integration
Market escrow is another valid single location for the inventory system. Trading does not regenerate item definitions, stats or rare traits. Buyers get the original specific bone, not a generic replacement. Ordinary nonstackable materials appear as separate listings. Optional multiselect creates separate listings per instance, never merges five differently attributed bones into one stack. Players choose own prices; market does not enforce one value per item name.

## Security, persistence, UI
For multiplayer, all listing/escrow/balance/expiry/purchase actions must be server authoritative and resilient to simultaneous buyers, client retries, disconnects and server restarts. Index/paginate large markets. If the project has no online backend, implement an honest test harness with simulated buyers, not a falsely represented live market. UI tabs Buy, Sell, My Listings, Sold, Expired, History, with filters and confirmation. Test listing unique rare bone → inventory removal → another buyer buys → exact trait-preserving delivery → seller claims net T-Stones once → both reload; additionally cancellation, expiration, full bag, insufficient balance, double click, failed transaction and restricted goods.

## Implementation standards
Inspect the existing project and its architecture first. Reuse existing gameplay, inventory, persistence, UI, and network components rather than introducing parallel systems. Implement working code in the project's language and engine, not just pseudocode. Separate definitions/configuration from saved runtime state. Make balancing parameters configurable. Preserve unique instance IDs and enforce atomic ownership/currency transitions. Where multiplayer exists, validate gameplay authoritatively and make retried operations idempotent. Include tests and summarize modified files, verified behavior, assumptions, and remaining limitations.

**Historical fidelity:** Durango: Wild Lands was updated during 2019; published guides can describe different revisions. Distinguish verified original mechanics from contemporary player reports, community reconstruction formulas, and new design choices. Do not claim illustrative values are exact original Nexon server values.
