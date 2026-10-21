# W3-EXCHANGE: Island Market screens (design)

Branch `claude/mmo-exchange`, stacked on `claude/mmo-econ` (plus ECON's hooks patch, commit "Apply ECON hooks (EXCHANGE base)").
Owns `game/scripts/ui/market/`, `game/scripts/dev/market_ui_lab.gd` + `market_harness.gd`, `game/scenes/dev/market_ui_lab.tscn`,
`game/tests/t_exchange.gd`, this file, `docs/orchestration/reports/claude-mmo-exchange.md`. Everything else it needs is an exact,
compiling change in `docs/orchestration/reports/claude-mmo-exchange-hooks.patch`.

## 0. What binds, newest first

1. Owner, 2026-10-20: "Gameplay HUD → Main Menu → Island Market → Buy / My Market / Sell" and the two references
   (`docs/reference/durango-market-buy-search.webp`, `durango-market-buy-taming.webp`), read in `docs/design/durango-prompts/14_island_market_ui.md`.
2. Owner, 2026-10-20 (STATUS, commit 548059bc): the market is an online feature on the server; W3-EXCHANGE builds the screens
   for the server path (socket transport; a local server for dev and tests until a host is picked) and shows an honest
   "market offline" state in offline single-player. Single-player characters are NOT moved into a server store.
3. Spec 06 (mechanics), spec 13 (shared Durango look, palette), contracts.md §0, §4-6, §8, `docs/design/economy.md`,
   GAUNTLET.md UI rules (white actions, coloured things, 44 px targets, 844x390 landscape, desktop 1600x900 gl_compatibility judges).
4. ECON's engine and data: `game/scripts/economy/*`, `game/data/economy/{market_rules,limits}.json`. The screens never
   restate a number ECON owns (fees, tax, durations, bands, trade lock, page sizes): they read `EconRules.load_default()`.

## 1. Reading the references (2000x1088, a landscape phone)

| Element | Search shot | Taming shot | Our rule |
|---|---|---|---|
| Header band | y 0-115 (10.6 % of h): back, white title, premium "691 [+]", coins "27,927", divider, X | same | 10-11 % of h; back, title, T-stone pill(s), X. **No premium pill, no "+"** (no monetization) |
| Torn edge under header | light ragged band | same | procedural band, 6-10 px |
| Left rail | x 115-325 (10.5 % of w), 3 tabs ~31 % of body h each | same | 10-12 % of w; tabs fill the rail height, each ≥ 44 px |
| Active tab | lighter fill, 4 yellow L brackets, yellow icon + label | same | `#E6BE54` brackets, icon, label |
| Category column | none | x 340-925 (29 % of w), title row, 7 rows ~118 px, selected = gold gradient + yellow chevron | 27-31 % of w, only while a category is chosen |
| Table header | magnifier, "Item Name/Type", "Level⇕", "Durability⇕" (clipped in the ref), "Price⇕" yellow | same | full words, never clipped; active sort yellow |
| Chip | "Stick, Short Stick ×" dark pill | none | one chip per active filter, × target ≥ 44x44 |
| Rows | ~148 px (13.6 % of h), icon, gold name, grey type, Lv., cur/max, coin + price, dotted separators | ~148 px, B badge on the bonded pet, crates for captured | one row per listing = one instance |

## 2. Transport (decided)

The screens talk only to **`MarketClient`** (`game/scripts/ui/market/market_client.gd`). Its one call is
`await client.request(op, args) -> {ok, r} | {ok:false, err, msg}`; every op is a `VaultBridge.client()` op on some server.
Writes (`MarketEngine.WRITE` + `vault.deposit`, `vault.withdraw`) get a fresh `rid`; a retry passes the SAME rid back, so
the server answers from its cache and nothing happens twice (contract 5.3).

| Transport | Class | When | What the player sees |
|---|---|---|---|
| none (offline) | `MarketClient` (base) | offline single-player: today's only player build. The game runs no in-process server, so there is none to use | "Island Market offline" panel: why, and that it needs a connection to the game server. No rows, prices, Buy, Sell or Receive |
| socket | `NetMarketClient` (B1) | `Game.net` exists and is connected (`--online=<ws>` / web `?online=`), i.e. after W1-INT merges NET and the server's market relay. Also the dev "local server": NET's `--server` process plus clients with `--online=ws://127.0.0.1:<port>` (plan-register's "two real clients on a local server") | the live market |
| lab/test | `LocalMarketClient` | labs and tests only, built by `MarketHarness`; never by the player path | a permanent "Local test server: not the live market" badge under the header |

- `NetMarketClient` duck-types `Game.get("net")` (`has_method("request")`): `var req = net.request(op, a)`, `await req.done`,
  read `ok/r/err/msg`; on `timeout`/`offline` it calls `net.retry(req)` (same rid), never a new request. NetClient is not a
  class on this base, so nothing is typed against it and the file compiles before NET lands. `MarketScreen.client_for_game()`
  returns a `NetMarketClient` when the link is up, else the offline base.
- The server side of the socket (`game/scripts/net/server_market.gd`: boot EconStore + CharacterStore + VaultBridge +
  `recover()`, `bridge.hello` on auth, every client frame through `bridge.client(op, id, a, now)` with the envelope rid copied
  into `a.rid`, `sys.tick` once a second, events pushed) is **W1-INT's** (plan-register:122, its file). EXCHANGE does not
  ship it; §10 lists exactly what the screens need from it.
- `MarketHarness` (`game/scripts/dev/market_harness.gd`) runs the real `VaultBridge` over an `EconStore` in the run's own
  user dir (`user://runs/<lab or test>/`, isolated by `override.cfg`) and a memory `CharacterStore` on a small server world.
  Every item, coin and listing enters through ops a client or the server tick sends: `act.gather/loot/craft/tame/capture`,
  selling gathered goods into Settlers' buy orders for tradable coins, `vault.deposit`, `market.list_fixed`, `market.buy`.
  ECON's default rules are used unchanged; the 30-min trade lock is waited out on the harness clock. Its "other players" are
  real accounts 2 and 3 (spec 06: simulated buyers in an honest harness; ECON's Settlers only post buy orders).
- Consequence, stated in the offline panel and the report: in the current single-player build nobody can use the market;
  it becomes usable when W1-INT ships NET + the server relay and a host (or a dev `--server`) runs. Even online, a fresh
  server character's bag is empty until server islands (W3-SRVWORLD/SRVACT) feed it, so Sell shows an honest empty picker.
- **No owner question:** STATUS 2026-10-20 (548059bc) settles authority (server only, offline state, no migration).

## 3. Screens and components (`game/scripts/ui/market/`, class_name per file)

INVUI (`claude/mmo-invui`) has no components yet (it has only merged W2-INV). EXCHANGE builds the minimum in its own files
with the spec 13 look; each is marked `# swap: INVUI <Component>` for the reconcile.

| File / class | What | Reads | Swap later for |
|---|---|---|---|
| `market_client.gd` MarketClient | transport base = offline (done) | — | — |
| `local_market_client.gd` LocalMarketClient | lab/test transport (done) | VaultBridge | — |
| `net_market_client.gd` NetMarketClient | socket transport (B1) | `Game.net` | — |
| `market_screen.gd` MarketScreen | root Control: full rect, opaque, MOUSE_FILTER_STOP, own `theme`; `open(player, tab := &"buy", uid := "")`, `close_screen()`, `is_open()`, `ui_cancel` closes; tab switching; offline panel | client, World.island_id | — |
| `market_theme.gd` MarketTheme | spec 13 palette, Theme built in code, condensed FontVariation over the fallback font (x-scale 0.9), one procedural noise texture (FastNoiseLite.get_image once) for panels, torn-edge band, dotted separator draw helper | — | INVUI theme resource |
| `market_glyphs.gd` MarketGlyphs | white procedural glyphs drawn with `draw_*`: cart, ledger, price tag, sort up/down triangles, B badge | — | W1-UIICONS ids if added |
| `market_header.gd` | back (`back` white icon), island title, T-stone pill = **tradable** (wallet − bound), lock pill = bound (only if > 0), test-server badge, X (`close`) | `wallet.get` {wallet, bound, held}; `MapScreen.island_name(World.island_id)` | — |
| `market_rail.gd` | Buy / My Market / Sell tabs, active = lighter fill + 4 brackets + gold icon/label | — | INVUI SelectionBrackets |
| `market_brackets.gd` | 4 yellow L corners around a rect | — | INVUI SelectionBrackets |
| `buy_view.gd` | search button, chip row, category column (when chosen), table, pager | `market.search` | — |
| `market_table.gd` | header (search, Item Name/Type, Level, Durability, Price; sortable only when the server has the sort), rows, "page n / m", empty state | search page | — |
| `listing_row.gd` | icon (ItemArt.texture_for + content_rect, modulated by ItemStack.tint_color), gold name, grey type line, `LevelDisplay.label`, "cur/max" or "—", coin + grouped price; seller name small; B badge for pets | listing view | INVUI ItemIcon, LevelLabel |
| `listing_detail.gd` | detail + Buy confirm: real asset (level, durability, attributes gold/grey/green, processing, pet stats, genetics, grade, lineage), price, your tradable balance, Buy, pending / done / server error | listing view, `wallet.get` | INVUI ItemInspectPanel |
| `sell_view.gd` (B2: `market_sell.gd` MarketSell + `market_picker.gd` MarketPicker + `market_sell_form.gd` MarketSellForm) | exact-instance picker of the **server** bag (+ pets, + market storage), price stepper/input, duration chips, preview, List | `char.get`, `vault.get`, `market.item_detail`, EconRules | INVUI InventoryGrid / InventorySlot, ItemInspectPanel |
| `my_market_view.gd` (B3: `market_mine.gd` MarketMine; Cancel is MarketConfirm's cancel mode) | sub-tabs Active / Sold / Expired / History, Cancel on Active, Receive All + "n waiting" | `market.mine`, `vault.get`, `inbox.take` | — |
| `market_format.gd` MarketFormat | pure helpers: fee/tax/proceeds preview, number grouping, error text, row model from a view, category + clade grouping | EconRules, Data | — |

### 3.1 Header
`[<] <Island name>  ...  [T 1,234] [lock 20] | [X]`. Back = close (one level; the menu sheet is already closed). The title
is the island the player stands on (`MapScreen.island_name`), never a constant. # ASSUMPTION: the books are one global market
(ECON has no island id in any op); the title names the place, not a separate book. Regional books are W4-ECONH.
Tradable is the big number because only tradable coins buy and pay fees; bound shows with the `lock` icon so the player sees
why a 20-coin wallet cannot buy. Counters refresh after every write (the response carries `wallet`) and on open.

### 3.2 Buy
- Default: all listings, sort `price_asc` (ECON's default, the reference's yellow Price), page 1 of `page_size_default` (20).
- Search button (`inspect` icon) opens a search sheet: text field (q, ≤ 40 chars) and the category list. Applying shows a chip
  per filter ("Stick ×", "Animals ×"); tapping × clears it and reloads page 1.
- Categories = the market categories (`market.json base_price_tstones` keys) that have listings, title-cased, plus
  "Animals" for `animal`. Item → category: `def.get(&"market_category")` (W2-DATA's field) else
  `Settlers.market_category(def, base, alias)`. # ASSUMPTION (14:16 and 06:11 name categories but not the list; W2-DATA's
  report says market categories are the market.json price keys). There is no "Taming Materials" in the data; "Animals" is
  its nearest real group (cages and bonded pets).
- Choosing a category shows the category column (title = category, "View All" first). For Animals the rows are one per
  clade of species that can be caged (creature json `tameable` or `capture_tier > 0`), labelled
  `<short name> Type`: Dromaeosauridae Raptor, Ceratopsia Ceratops, Tyrannosauridae Tyrant, Machairodontinae Sabertooth,
  Cervidae Megalo, Stegosauridae Stego, Ankylosauridae Ankylo, Ornithomimidae Mimid, Coelophysoidea Coelo,
  Compsognathidae Compy, Neotheropoda Dilo; only clades with at least one listing show. # ASSUMPTION: names are taxonomy
  short forms, no invented species; Avian and Wolf do not exist in the roster and are never shown. Selecting a clade sends
  `species` filters for its species (one request per page; see hook H2).
- Sort headers: Level, Durability, Price toggle asc/desc. A direction is offered only if `MarketQuery.SORTS` (shipped with
  the client) has it; otherwise the header is plain text with no arrows. Base ECON has `price_asc`, `price_desc`, `level_desc`;
  hook H1 adds `level_asc`, `durability_asc`, `durability_desc`. Never a client-side sort of one page.
- Row = one listing view (`market.search` result). Items: `ItemStack.from_dict(Provenance.strip(view.asset))` gives def,
  level, durability, attributes, tint. Name gold `#E6BE54` (def display name), type line grey = market category title.
  Count > 1 (a stack listed as one lot) shows "×N" after the name and the price is per unit. Pets (`type == "pet"`): icon
  `tamed_animal`, dark circle "B" badge, gold species display name, type line = species; level = PetDict level; durability "—".
  Captured cages (`id == captured_animal`): icon `captured_animal`, gold "Captured <Species>" from `attributes.species`, type
  line = species, durability "—" (the validator refuses durability on cages). Own listings show "yours" and no Buy.
- Tap a row → detail + confirm (§3.4). Pager: "‹  2 / 25  ›" (targets ≥ 44 px); the table reloads the page from the server.

### 3.3 Sell
- Picker: `char.get` → the server character's bag rows (one cell per stack/instance, ItemArt icon, level, count) and bonded
  pets. Ineligible cells stay visible, dimmed, with the reason: denied def (`limits.json denied_defs`, e.g. tamed_animal),
  locked, unstable ("Cargo-warp first", economy.md:46), broken, summoned pet, pet carrying items (contracts:99-101). Any
  other refusal comes back from `vault.deposit` and is shown verbatim. Vault items that are not listed (a failed second
  step, a return) show in a "Waiting in your market storage" strip with Receive / List again.
- Selected instance panel: icon, name, level, durability, attributes (gold positive, grey negative, green rare) read from the
  dict, never recomputed (13:471). Count stepper for stacks (1..count).
- Price: integer stepper + field, 1..`max_unit_price`. If `market.item_detail` has `ref_price`, show "Recent price N" and the
  band `ceil(ref × reference_outlier_low)`..`floor(ref × reference_outlier_high)` (0.25x-4x from market_rules.json); the
  stepper stays inside it. (B2: a typed price may leave it with a warning, and H3 was dropped; see §12.) No reference → no band. # ASSUMPTION
  (STATUS 141-142 planner default; ECON enforces nothing today).
- Duration chips from `durations_h` (12 / 24 / 48 / 72), default 24 h. # ASSUMPTION.
- Preview (MarketFormat, from EconRules; integers): `total = price × count`; `fee = max(listing_fee_min, ceil(total × listing_fee))`
  paid now from tradable coins and never refunded; `tax = ceil(total × sales_tax)` on sale; `you receive = total − tax`
  (paid straight to your wallet when it sells); `net after fee = total − tax − fee`. 20,000 → fee 1,000, tax 600, receive 19,400,
  net 18,400. Confirm disabled with the reason when tradable < fee.
- Confirm = `vault.deposit {bag_slot, count}` or `{pet_uid}` then `market.list_fixed {asset:{uid, count}, unit_price, duration_h}`.
  If the second step fails the asset is safe in the vault and appears in the Waiting strip with the server's message.

### 3.4 Buy confirm (detail)
Real asset dict, seller name, price, "Your tradable T-stones N → N − price". Buy = `market.buy {listing_id, count}`.
Button disabled while pending (one rid; a second tap does nothing). Success: "Bought. It is in your market storage: My Market →
Receive All", row removed, header refreshed. Failure: the server message, state unchanged, list refreshed when the listing is
gone. The item goes to the buyer's **vault** (contracts:157-159), not the bag.

### 3.5 My Market
- Sub-tabs: **Active** = `mine.listings` (Cancel → `market.cancel`, units back to the vault, fee kept, said in the confirm);
  **Sold** = `closed_listings` state sold, with "credited +net" (`price × qty − tax`); **Expired** = state expired (and
  cancelled), "back in storage"; **History** = `mine.trades` (bought/sold, price, other party, time).
- **Receive All**: `inbox.take` (clears events, shown as a toast list), `vault.get`, then one `vault.withdraw {uid}` per
  item/pet, paced ≤ 4/s (contract 5.4 write 5/s). (B3: tries every uid once instead of stopping at the first refusal, §13.)
  Proceeds are already in the wallet (ECON credits sales directly), so there is no coin claim. # ASSUMPTION: spec 06's
  "claimable proceeds" is served by direct credit + Receive All for items (contracts:157-158 are newer). Pressing it again
  moves nothing (each withdraw is idempotent by uid; an empty vault does nothing).

### 3.6 Main-menu entry (hook, hunt_hud.gd is not ours)
- Menu row after Map: `_sheet_btn(box, "Island Market", func () -> void: _close_sheet(); _open_market())` (6 rows: Bag, Craft,
  Map, Island Market, Save, Debug; ui_real_capture_lab's "all rows without scrolling" still holds: 2x3 at 844x390).
- `_open_market()` next to `_open_animals()`: one CanvasLayer "MarketLayer" at layer 96 with a `MarketScreen`, then
  `_market_screen.open(player)`. Public `open_market()` for labs, like `open_map()`.
- Public entry for INVUI's "Sell on Market": `MarketScreen.open(player, &"sell", uid)`; INVUI hides its button when
  `MarketScreen.client_for_game().is_online()` is false.

### 3.7 Look
Spec 13 palette: bg `#101714`, panels `#39392F` / `#26322C` with the noise texture, separators `#56534A` dotted, selection and
brackets `#E6BE54`, primary button `#F2C84C` (dark text), text `#ECEBE4`, secondary `#A6A69B`, disabled `#77786F`. Gold for
names (things), white for actions and icons (GAUNTLET:61). Fonts: the project's fallback font through a condensed
FontVariation; sizes from UiTokens (heading/body/meta), floor 12 px. Layer 96, opaque, so HANDS and plates never show through.

## 4. Data each element reads

| Element | Op / source | Fields |
|---|---|---|
| Header | `wallet.get`; World.island_id | wallet, bound |
| Buy table | `market.search` {q, category\|market_category, species, sort, page, page_size ≤ 20} | total, page, results[id, type, key, asset, qty, left, unit_price, seller_name, ends] |
| Category column | Data items (market_category), creature json (clade, tameable, capture_tier) | — |
| Detail | the listing view's `asset`; `wallet.get` | full dict |
| Sell picker | `char.get` | bag rows, pets |
| Sell band | `market.item_detail` {def_id \| species} | ref_price, last_price |
| Sell preview | `EconRules.load_default()` | listing_fee, listing_fee_min, sales_tax, max_unit_price, durations_h, reference_outlier_* |
| My Market | `market.mine` {page, page_size} | listings, closed_listings, trades |
| Receive All | `inbox.take`, `vault.get`, `vault.withdraw` | events; items[uid], pets[uid] |

## 5. Error text (server code → what the player reads; the server `msg` is shown under it)

offline "The Island Market needs a connection to the game server." · timeout "No answer from the server. Retrying…" (same rid) ·
insufficient_funds "Not enough tradable T-stones" · limit_reached (msg tells which: trade lock "New accounts can trade in N min",
50 listings, vault full, deposit cap, bonded roster) · self_trade "That is your own listing" · expired / not_found / closed
"No longer available" (row removed) · not_owner "Not your listing" · invalid_asset "This can't be sold on the market" ·
bag_full "N still waiting: Your bag is full." (the server's msg names def ids, so it is not shown) · rate_limited "Too fast, try again" · server_error "The market is busy finishing a
trade. Try again shortly." · unauthorized / bad_request "Something went wrong" + msg (a bug; logged).

## 6. Hooks (exact, compiling changes go in `claude-mmo-exchange-hooks.patch`, written in the build step that needs them)

| Id | File (owner) | Change | Step |
|---|---|---|---|
| H0 | `game/scripts/ui/hunt_hud.gd` (W1-UI / integrator) | menu row + `_open_market()` + `open_market()` (§3.6) | B1 |
| H1 | `game/scripts/economy/market_query.gd` (ECON) | SORTS += `level_asc`, `durability_asc`, `durability_desc` (key = level / durability, no-durability last) | B1 |
| H2 | same | `market_category` arg (items by market category; `animal` includes pets and cages); `species` also matches `captured_animal` cages by `attributes.species` | B1 |
| ~~H3~~ | `game/scripts/economy/market_book.gd` (ECON) | **Dropped in B2** (§12): refusing listings outside the band broke ECON's reference-poisoning tests (`[tests] FAIL count=26`, "price must be between 25 and 400") and contract 6.5's band filters the reference price, it is not a listing limit | — |
| H4 | report note for W1-INT | the server relay (§2) and the 64 KiB frame: `market.mine` can exceed it; ECON should page `trades` | — |

H1-H2 change ECON-owned search behaviour: the orchestrator merges them with ECON or bounces them to ECON. Until they
land the UI degrades honestly (no arrows for missing sorts; no categories in the search sheet). The band is advice either way (§12).

## 7. Build plan

- **B1 shell + navigation + Buy**: MarketTheme, glyphs, brackets, header, rail, MarketScreen (offline panel, test badge),
  NetMarketClient, buy_view/table/row/detail with real `market.buy`, search sheet + chips, categories + Animals clades,
  hooks H0-H2. Lab screens buy, buy_taming, confirm, offline; the lab opens the market through the HUD MENU sheet.
- **B2 Sell**: sell_view, MarketFormat preview, lab screen sell (H3 dropped, §12).
- **B3 My Market + Receive All** (done, §13): market_mine.gd, MarketConfirm cancel mode, lab screens my_market,
  my_market_sold, my_market_history, my_market_cancel, my_market_received.
- **B4 polish**: responsive at 1600x900, 1920x1080, 844x390, 667x375 (safe area), 500-listing performance (harness seeds 500
  listings by real ops; paging), focus/keyboard/gamepad (ui_cancel, focus_first), report.

## 8. Gates (measurable; t_exchange and the lab check them)

Proportions (lab measures the node rects; ±2 % of the viewport unless noted):
1. Header band 10-11 % of viewport height at 1600x900 and ≥ 44 px at 844x390; rail 10-12 % of width; category column
   27-31 % of width when shown; table fills the rest; at 1600x900 rows 13-14 % of height (±1 %).
2. At 844x390: every interactive target (back, X, tabs, sort headers, chips ×, rows, category rows, pager, steppers,
   duration chips, Confirm, Cancel, Receive All) ≥ 44x44 px; ≥ 5 rows visible with no chip, ≥ 4 with a chip.
3. No clipped text: every Label's text fits its rect or is ellipsized by UiTokens.ellipsis (the header reads "Durability" in
   full at 844x390 and 667x375); "Log Shelter Kit (Planned)" and "1,000,000" fit; no font under 12 px.
4. Colour: names gold `#E6BE54`, actions/icons white; no "+" or premium counter anywhere (node scan for "+" buttons).
Behaviour (t_exchange, through MarketClient → VaultBridge.client):
5. One row per listing; the rows' uids equal `market.search`'s uids; three listed single branches → three rows, three uids.
6. Every sort: the uid set of all pages is unchanged and the order matches the server sort across page 2.
7. Buy moves the exact asset (same uid, level, attributes) to the buyer's vault and debits exactly the price; seller gets
   price − tax once; Receive All puts it in the bag.
8. Sell: preview fee/tax/proceeds equal the ledger deltas after the real list_fixed and buy; the listed asset leaves the bag
   and appears in Active with the same uid.
9. A test per error path, each asserting the message shown and both stores unchanged: offline, self_trade,
   insufficient_funds with only bound coins, trade lock (fresh account), sold listing (expired/not_found), double tap (one
   debit), cancel (fee kept, units in vault), cancel of a closed listing, bag_full on Receive All (rest waiting, second press
   moves nothing), price outside 1..max refused by the server, outside the band warned (not refused, §12), denied def (tamed_animal) shown disabled.
10. Offline: no client → offline panel, 0 rows, 0 Buy/Sell/Receive buttons, 0 ops sent.
11. Menu: HUD MENU sheet → "Island Market" button → MarketScreen visible (lab presses the real button).
12. Performance: 500 listings (harness, real ops) page 1→25 with each page built in < 8 ms and no frame > 33 ms in the lab.
13. Shots looked at next to the references: buy, buy_taming, sell, my_market, confirm, offline at 1600x900 gl_compatibility
    (judge), 1600x900 Forward+, 844x390 gl_compatibility; 0 SCRIPT ERROR lines; no new Godot .ips.
14. `t_exchange` prints 0 `PENDING` lines at B4.

## 9. Assumptions (each checked against the docs)

| # | Assumption | Docs checked |
|---|---|---|
| A1 | Offline single-player shows the market offline; no in-process server in the player build | STATUS 548059bc; HANDOFF:254; spec 06 "honest harness" |
| A2 | Categories = market.json price keys via market_category; "Animals" for `animal` | 14:16; 06:11; W2-DATA report :34; no "Taming Materials" in items.json |
| A3 | Animal sub-rows = clades of cage-able species with short taxonomy names; no Avian/Wolf | creature json clade/tameable/capture_tier; AGENTS "no invented species" |
| A4 | Header title = current island; one global book | economy.md:19-28; ECON ops have no island id; plan W4-ECONH |
| A5 | Proceeds are credited directly; Receive All moves items only | contracts:157-158 vs spec 06:12 |
| A6 | Band 0.25x-4x of ref_price, shown; the steppers keep to it, a typed price may leave it with a warning; the server takes 1..max_unit_price (revised in B2, §12); none without a reference | STATUS:141-142; contracts 6.5; spec 06 "Players choose own prices"; market_rules reference_outlier_* |
| A7 | Default duration 24 h | contracts:161; durations_h |
| A8 | Bonded pet icon = `tamed_animal` render + drawn "B" badge (ICONS2's render is an open cage, not a carrier); cages tell apart by badge and "Captured" name | 14:19; STATUS:179-180; ICONS2 renders |
| A9 | Tab glyphs (cart, ledger, tag, sort arrows) drawn in-package, not added to ui_icons.json | GAUNTLET white actions; avoids editing W1-UIICONS' gated set |
| A10 | Auctions and buy orders are not in v1 screens (spec 14 shows fixed price only); Settlers orders appear only as labelled "Settlers" if ever shown | contracts 6.6; spec 14 |
| A11 | Market opens anywhere from the Main Menu (owner nav), not only at a harbour | 14:3 vs plan-register:1003 (older) |
| A12 | Sell lists from the server character's bag, never the local single-player bag | contracts §0.1 "offline saves never import" |

## 10. What W1-INT's relay must give the screens

`bridge.client` for every op in `VaultBridge.CLIENT_OPS` + `IntentHandlers.CLIENT_OPS` (char.get), the envelope rid as `a.rid`,
`sys.tick` each second, inbox events pushed (sold, expired, won, outbid, filled) so My Market refreshes, and responses
under the 64 KiB frame (the screens ask `page_size` ≤ 20).

## 11. B1 as built (2026-10-20)

Files (`game/scripts/ui/market/`): `market_screen.gd` MarketScreen, `market_header.gd` MarketHeader, `market_rail.gd`
MarketRail, `market_buy.gd` MarketBuy (was buy_view), `market_categories.gd` MarketCategories (the column),
`market_search.gd` MarketSearch (the sheet), `market_table.gd` MarketTable, `market_row.gd` MarketRow (was listing_row),
`market_confirm.gd` MarketConfirm (was listing_detail), `market_format.gd`, `market_theme.gd` (brackets, torn edge,
dotted lines and the backdrop shader live here; no market_brackets.gd), `market_glyphs.gd`, `net_market_client.gd`.

Changes against §3-§6, each checked against the docs:
- H2 (hooks patch) also adds `clade` and `def_id` filters and `MarketQuery.FILTERS`; the client offers a filter only
  when FILTERS has it (H1: a sort only when SORTS has it). A clade row sends `clade`, an item row `def_id` (one request).
- Categories: every market.json price key except `unstable_loot` shows, empty or not (an empty table says so), instead
  of 20 count requests per open. Clades: every cage-able clade shows (11 on today's roster). # ASSUMPTION, both.
- A lot listed as ×N is bought whole (`count = left`); a per-unit stepper comes with a need. # ASSUMPTION.
- Buy confirm shows "No buyer fee; the seller pays N T-stones market tax" (N from EconRules, the engine's rounding).
- My Market and Sell tabs show one honest line until B2/B3.
- `NetMarketClient` follows NET's real API (claude/mmo-net): `request(op, a) -> NetRequest`, `await req.done`,
  `retry(req)` under the same rid; the body carries no rid (NetClient puts it on the envelope); `account_id` names own rows.
- `MarketScreen.test_client` (static) is how labs and tests inject `LocalMarketClient`; the player path never sets it.
- `MarketTheme.size_label` pulls the line pitch to ~1.3x: the project font's symbol/emoji fallbacks report 38 px line
  height at 18 px, which double-spaced every wrapped label.
- `MarketHarness.release_loggers()`: MarketEngine and CharacterStore register static Loggers and never remove them;
  a windowed run that quits with them registered aborts in NSApplication terminate (one Godot .ips per lab shot).

## 12. B2 as built (2026-10-20): Sell

Files (`game/scripts/ui/market/`): `market_sell.gd` MarketSell (the tab: reads, selection, the two writes),
`market_picker.gd` MarketPicker (the grid), `market_sell_form.gd` MarketSellForm (the right panel). MarketFormat gained
`sell_entries`, `sell_refusal`, `preview`, `band`, `price_step`, `asset_lines` (shared with the Buy confirm);
MarketGlyphs gained `chevron_left`. `MarketScreen.open(player, &"sell", uid)` preselects an instance (INVUI's
"Sell on Market"). INVUI's components (claude/mmo-invui 410c38df) sit on W2-INV's Inventory, which this base lacks,
so the picker and panel are built here with the same look; `# swap:` markers name InventoryGrid / InventorySlot /
ItemInspectPanel.

- **Picker** = `char.get` bag rows (slot order, one cell per stack or instance, `_slot_lock` rows skipped), then the
  character's bonded pets (`tamed_animal` art + B badge), then `vault.get` items and pets with a "Stored" tag (the
  §3.3 "Waiting" strip as cells: they list with no deposit; Receive stays in My Market). Bag reference look: textured
  panel, dashed compartments filling the visible rows, grey "Lv. n" top-right, "×n", yellow brackets on the pick.
- **Refused cells** stay visible, dimmed, with a lock (locked flag) or blocked mark; the panel shows the reason and no
  form: limits.json `denied_defs` ("bond the animal or release it first"), `refused_flags` (locked: "Unlock it in
  your Bag", unstable: "Cargo-warp them first"), broken (durability 0 of a max), summoned or loaded pet. Everything
  else comes back from `vault.deposit` verbatim. A forced deposit of the locked stack is refused by the server too
  (`invalid_asset` "locked items cannot be traded"), nothing moves.
- **Panel**: tan name band (B disc before a bonded pet's name), card (art, type, Lv, stack size), the asset's own facts,
  Quantity stepper for a stack (starts at the whole stack), Price each (field + steppers), band line "Recent price N ·
  usual range a – b" (on a phone the range moves into the price caption), duration chips 12/24/48/72 (24 default),
  preview Listing fee (paid now) / Market tax (when it sells) / You receive / Net after the fee (two pairs a line on a
  phone), status line, yellow "List for N" along the bottom. Disabled with the reason: "Set a price", "Not enough
  tradable T-stones" (+ "Bound T-stones can't pay market fees"), "Can't be sold".
- **Starting price** only from the market's own numbers (`ref_price`, else `last_price`, else `best_ask`); none → the
  field is empty and List says "Set a price". # ASSUMPTION (nothing invented).
- **Band** (A6 revised): the steppers move inside 0.25x-4x of `ref_price`; a typed price may leave it, then the panel
  warns "Outside the usual range a – b for this item. Check the price; rare traits can be worth more." and the button
  reads "List anyway for N". Over `max_unit_price` is pulled to it. Why not a wall: the reference is per def, so a
  hard cap would stop a Black Sheen bone from asking more than 4x a plain bone (spec 06: "Players choose own prices"),
  contract 6.5's band is the reference filter (ECON already keeps outlier trades out of the reference), and H3 broke
  ECON's tests that list at outlier prices on purpose. # ASSUMPTION.
- **List** = `char.get` again to find the instance's current slot **by uid** (a stack that moved is never the one that
  leaves), `vault.deposit {bag_slot, count}` or `{pet_uid}`, then `market.list_fixed {asset:{uid, count}, unit_price,
  duration_h}` with the uid the deposit answered (a part of a stack gets a new uid; the rest keeps its own). A stored
  entry skips the deposit. If the second step fails the item is in market storage, stays picked as a Stored cell, and
  the panel says so with the server's reason. Success: "Listed <name> for N T-stones (fee F paid). It is in My Market →
  Active ...", header refreshed, picker re-read.
- **Harness**: the viewer also has two looted bones, a crafted knife, a captured cage, a bonded compy and a stone stack
  with the "locked" flag. # shortcut: `MarketHarness.lock_first` sets the flag on the server character directly (the
  server has no lock intent until W3-SRVACT), standing in for the Bag's Lock.

## 13. B3 as built (2026-10-20): My Market and Receive All

Files: `game/scripts/ui/market/market_mine.gd` MarketMine (the tab). MarketConfirm gained `open_cancel` / `cancel_listing`
(the listing panel in a cancel mode), MarketFormat `mine_rows`, `event_text`, `key_name`, `span`; MarketRow takes a prebuilt
model and shows `LevelDisplay.NONE` for a level of 0; MarketClient `now()` (the harness clock on LocalMarketClient);
MarketHarness `fill_bag`. No new hook: everything goes through ops already in `VaultBridge.CLIENT_OPS`.

- **Layout**: a sub-tab band in the table-header style (Active n/50, Sold, Expired, History; the shown one lighter with
  yellow brackets and a yellow label, like the rail), then rows in the Buy row style (icon, gold name over the grey type,
  Lv., a status column, coin + price), then a footer band: status line, "n waiting in market storage", yellow Receive All.
  Active rows have a white "Cancel"; the other sub-tabs give that width to the status column.
- **Rows** are one `market.mine` answer: Active = `listings` ("Ends in 2 d 11 h", "Ending…" once due and not yet settled);
  Sold = `closed_listings` with state sold ("Sold · +N credited", N = Σ total − tax of the account's trades whose `ref` is
  the listing; "Sold · credited" if those trades were pruned); Expired = the other closed states ("Expired / Cancelled ·
  back in storage", the count is qty minus units sold); History = `trades` ("Bought", "Sold", "Sold to Settlers" for npc
  buyers, "· 13 h ago", the trade total as the price, `Lv. —` because a trade record keeps no level). Closed listings are
  paged by the server (page_size 20); a "‹ n / m ›" pager shows on Sold / Expired when there is a page 2. Sub-tabs switch on
  the last answer; the tab re-reads on open, after a cancel and after Receive All. # ASSUMPTION: the other party is not
  shown in History: trade rows carry account ids, not names (an ECON change if wanted).
- **Cancel** opens the listing panel: the asset's facts, "Listed at N", "Cancelling takes it off the market and puts it in
  your market storage (My Market → Receive All). The listing fee of F T-stones is not refunded.", Keep listing / Cancel
  listing. One `market.cancel` (a second tap while pending sends nothing; after it the button is gone). Success: "Cancelled. It
  is in your market storage: Receive All brings it to your bag.", My Market re-reads. A listing that sold or expired meanwhile:
  "No longer available.", nothing moves, My Market re-reads.
- **Receive All**: `inbox.take` (its events become the status line: "Sold Fibre Stalk ×1 to Trader2: +5 credited. Berry ×1
  expired: back in storage.", three at most plus "And n more."), then one `vault.withdraw {uid}` per item and pet, 0.25 s
  apart, "Receiving i of n…". Changed from §3.5: every uid is tried once and a refusal does not stop the rest (a stack can
  still merge into the bag after a knife found no slot; a full bonded roster does not hold items back); the first refusal
  is the reason shown: "Received 1 into your bag. 2 still waiting: Your bag is full." Disabled with nothing waiting ("Market
  storage is empty"); pressing it again only retries what is still there, so nothing moves twice. Proceeds need no claim
  (A5). The header's wallet is re-read when My Market opens (sales credit while the screen is closed).
- **Harness**: `fill_bag` loots single knives from a "pile" corpse until the server says `bag_full` (plain materials
  stack to 999 per slot, ItemDef.from_dict, so gathering would need ~20,000 units to fill a bag).

