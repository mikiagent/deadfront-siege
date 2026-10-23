# 14. Island Market UI (owner references, 2026-10-20)

Owner's words, verbatim: "Gameplay HUD → Main Menu → Island Market → Buy / My Market / Sell"

References (owner screenshots of the original Durango: Wild Lands market):
- `docs/reference/durango-market-buy-search.webp`: Buy tab with a search filter chip
- `docs/reference/durango-market-buy-taming.webp`: Buy tab with the Taming Materials category column and caged pets

Mechanics are in spec 06 (fixed-price Island Market, exact instances, fees/tax, Receive All; an honest harness, not a fake live market, when no online backend runs), contracts.md sections 0, 4-6, and the ECON engine. The rest of this file is the orchestrator's reading of the screenshots, not the owner's text.

What the screenshots show:
- **Header:** a back arrow, the island's name as the title ("Ananke Wilmington Island"), two currency counters (a premium currency with a "+" and the coin currency), and a close X. The dark header has the same torn-edge band as the Bag (spec 13).
- **Left rail:** three tall tabs with icons and labels, Buy (cart), My Market (ledger) and Sell (price tag). The active tab is lighter, with yellow corner brackets and a yellow label.
- **Buy, category view (second shot):** a middle column titled with the category ("Taming Materials"), listing sub-types as rows: View All, Avian Type, Wolf Type, Raptor Type, Megalo Type, Tricera Type, Sabertooth Type. The selected row is gold-highlighted with a yellow chevron.
- **Buy, listing table:**
  - A search icon, then column headers "Item Name/Type", "Level ⇕", "Durability ⇕" and "Price ⇕". Each header sorts; the active sort header is yellow.
  - An active search shows as a removable chip ("Stick, Short Stick ×").
  - Each row is ONE instance: icon, gold item name with a grey type line under it, "Lv. n", "cur/max" durability, and a coin icon with the price. Identical items are separate rows (three Raspberry Bush Branch rows).
- **Caged animals:** a bonded tame is listed as "B Oviraptor" with a pet-carrier icon. A captured wild one is "Captured Oviraptor" with a wooden crate icon. Both show level and durability.
- **Look:** the same earthy textured panels, gold names and fine dotted row separators as the Bag.
