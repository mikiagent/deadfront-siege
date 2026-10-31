# UIMARKET — Island Market screens (Claude)

Branch `claude/mmo-uimarket` off `claude/mmo-overhaul`. No credits spent, no economy rule changed.

## What shipped

- **`game/scripts/ui/market/`**: `MarketScreen` (§8 chrome: HEADER bar with ‹ + island name, T-stones
  pill, ✕, torn edge; left rail Buy / My Market / Sell with GOLD brackets; offline card; Esc closes),
  `MarketBuy`, `MarketMine`, `MarketSell`, `MarketRow` (one row = one instance), `MarketConfirm`
  (parchment-header dialog, trait chips, GOLD primary), `MarketRailTab`, `MarketGlyphButton`,
  `MarketClient` (offline base) and `LocalMarketClient` (dev/test transport).
- **Nav entry**: `MarketScreen.open_for(host, tab := &"buy", uid := "") -> MarketScreen` (public, one
  screen per host on its own CanvasLayer 96). `HuntHud.open_market(tab)` wraps it and sends ‹ back to
  the MENU sheet; the current MENU sheet has an "Island Market" row (one line). `back_pressed` and
  `closed` signals for whatever nav menu UINAV ships.
- **Offline (the player build)**: every tab shows "Island Market offline" with a tab-specific reason
  and sends nothing; the pill reads "—" (owner 2026-10-20).
- **Buy**: category column, search, Level / Durability / Price sort (both directions), one row per
  listing; confirm shows the instance (Lv., durability, trait chips), seller, price, tradable T-stones;
  Buy takes one unit; refused up front for own listings or too few tradable T-stones.
- **My Market**: Active (tap -> Cancel listing confirm), Sold, Expired, History (from `market.mine`),
  "n waiting" + Receive All (`inbox.take`, then `vault.withdraw` per stored uid; stops on a full bag).
- **Sell**: server bag rows + bonded pets (equipped gear excluded, locked rows greyed), price, duration
  cycle 12/24/48/72 h, fee / tax / proceeds preview computed with `EconRules` exactly as `MarketBook`
  charges, List = `vault.deposit` + `market.list_fixed` of count 1.
- **Dev**: `scripts/dev/market_harness.gd` (ported), `scripts/dev/market_lab.gd` + `scenes/dev/market_lab.tscn`
  (shots). **Test**: `game/tests/t_uimarket.gd` (+ `uimarket_checks.gd`).
- Docs: `docs/current/ui-screens.md` (Island Market section), `docs/current/economy-trading.md`.

## Taken from `claude/mmo-exchange`

- `MarketClient` / `LocalMarketClient` seam: ported, trimmed (synchronous `request`; no `learn()`, no
  NetMarketClient, since canon has no network transport).
- `MarketHarness`: ported; dropped `seed_bulk` and `fill_bag`; prices and earn target lowered because
  canon Settlers' orders now pay only ~26-36 tradable T-stones in the 48 windows `earn()` waits.
- Ideas only (rewritten on canon tokens): offline panel, rail, confirm flow, Sell = deposit + list,
  Receive All = inbox.take + withdraw. Not taken: MarketTheme shaders/paper, glyph module, search panel,
  drag scroll, the ECON hooks patch (H2 filters, H5 equipped refusal, H6 account_id/trade_lock in
  `wallet.get`) — those change economy code, which this package must not.

## Shots (looked at next to c2-bag / d1 / the Durango references)

`docs/orchestration/reports/uimarket/market_{offline,buy,buy_confirm,my_market,sell}_{1600x900,844x390}.png`
(all ≤ 101 KB). Listings come from the local test server, labelled on the rail.

## Gates (this worktree)

t_uimarket PASS, t_ui PASS, t_uiicons PASS, t_fieldhud PASS, t_uitokens PASS, t_econ PASS,
run_all `[tests] PASS`, `tools/smoke.sh --no-import` SMOKE PASS.

## Assumptions (`# ASSUMPTION:` in code where they live)

1. Buy categories are canon `market.search` filters (items.json categories + `asset=pet`), not the
   reference's clade sub-types (canon search has no clade filter without the old hooks).
2. Trait chip polarity: no data yet (spec §9 q2) — every chip negative-grey except `flawless`;
   `species`, `level`, `tint` are not shown as chips.
3. Sell lists exactly one unit per listing, Buy takes one unit (owner: items never stack).
4. Default listing duration 24 h; the button cycles the rules' `durations_h`.
5. Durability shows the instance's own `max_durability` when it has one.
6. The search is a text field with a clear button, not the reference's removable chip.

## Risks / for the next agent

- **Trade lock and equipped gear are client-side only where they are checked at all**: canon
  `wallet.get` does not expose `trade_lock_s`, so a fresh account sees the server's `limit_reached`
  message after pressing Buy/List; equipped gear is filtered out of Sell by the UI, but the server
  deposit would still accept (and silently unequip) it. ECON owns that fix (old hook H5).
- `market.list_fixed` failing after a successful deposit leaves the item in market storage; the Sell
  status says so and Receive All returns it.
- `hunt_hud.gd`: one MENU row + `open_market()` / `_market_back()` (10 lines); UINAV should keep the
  call when it rebuilds the menu.
- A SceneTree test that awaits must return false from `_process` until done (returning true quits the
  loop mid-await, which aborted with a libc++ mutex error).
