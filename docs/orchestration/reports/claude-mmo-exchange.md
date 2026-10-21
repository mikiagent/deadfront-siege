# W3-EXCHANGE report (Claude): Island Market screens

Branch `claude/mmo-exchange` (worktree `.claude/worktrees/mmo-exchange`), stacked on `claude/mmo-econ`. ECON is not merged
into `claude/mmo-overhaul` yet. B1 merged ECON a21cf5b4 (escrow keeps per-instance fields) and re-applied the two new
`intent_handlers.gd` hunks of ECON's hooks patch (cf43dd44; the file now hashes to the patch's d9e5a8bc).

## Design step (done, 1cf02efb)

Spec `docs/orchestration/mmo/exchange-spec.md` (screens, data, error text, hooks H0-H4, build plan B1-B4, 14 gates,
assumptions A1-A12). Transport: `MarketClient` (offline base), `NetMarketClient` (socket), `LocalMarketClient` (labs and
tests only, labelled "Local test server: not the live market"). `MarketHarness`: the real VaultBridge, fed only by client ops.

## B1: shell, offline state, HUD menu entry, Buy (done, 4ceaadf5 + docs commit)

Shipped (`game/scripts/ui/market/`, spec §11 lists the files):
- **Shell**: header (back, the island's name, tradable T-stones, bound T-stones with a lock only when > 0, test-server
  badge, X; black band with the torn edge; no premium pill, no "+"), left rail Buy / My Market / Sell (active tab
  lighter with four yellow brackets, yellow cart and label), weathered backdrop (shader, no texture files), opaque on
  layer 96, `ui_cancel` closes the top overlay, then the screen.
- **Offline (today's single-player build)**: "Island Market offline" and why; no rail, no rows, no counters; 0 ops sent.
- **Buy**: table header with search, "Item Name/Type", Level / Durability / Price (sortable only when the server has
  the sort; active one yellow); name search as a removable chip; categories in the search sheet open the category
  column (Animals: View All + 11 real clades, "Compy Type" etc.; item categories: their defs); one row per listing
  instance (three branches = three rows, three uids); bonded pet = B badge + `tamed_animal` icon; captured =
  "Captured <species>" + `captured_animal` icon; own listing reads "Your listing" and has no Buy; pager when there is
  a page 2. Every change asks `market.search` again; nothing is sorted or filtered client-side.
- **Buy confirm**: the asset's own facts (level, type, durability, material, processing, seller; pets grade and
  stats), price, "Your tradable T-stones N -> N - price", the seller's tax in T-stones from EconRules; Buy sends one
  `market.buy` (disabled while pending and after the sale, so a double tap sends one). Success says where the item
  went (market storage: My Market -> Receive All) and refreshes header and table. Every refusal in words.
- **NetMarketClient** against NET's real API (claude/mmo-net): `request` -> NetRequest, `await done`, a timeout is
  resent with `retry(req)` under the same rid; no rid in the body (NetClient puts it on the envelope).
- **Hooks patch** `docs/orchestration/reports/claude-mmo-exchange-hooks.patch` (not applied on this branch; applies
  cleanly to 4ceaadf5): H0 `hunt_hud.gd` menu row "Island Market" after Map + `_open_market()` / `open_market()`
  (MarketLayer, layer 96); H1 `market_query.gd` sorts `level_asc`, `durability_asc`, `durability_desc` (no durability
  last); H2 `market_category` ("animal" = pets + cages), `clade`, `def_id`, `species` also matching captured cages,
  `FILTERS` const. H1/H2 are ECON-owned files: merge with ECON or bounce to ECON. Without them the UI degrades
  honestly (Durability header without arrows, no categories in the search sheet).

Assumptions added in B1 (spec §11): every category and every cage-able clade shows even when empty; a ×N lot is
bought whole; My Market and Sell show one honest line until B2/B3.

### Checks run (B1)

Branch (no hooks), at 4ceaadf5 (the lab `menu` screen added after it is not loaded by any test):
- every `game/tests/t_*.gd`: 21 x `PASS`, rc 0; `t_save` 5 SCRIPT ERRORs (deliberate, as on base), all others 0.
- `t_exchange`: `[t_exchange] HOOK H1 absent: level_asc/durability sorts skipped`, `HOOK H2 absent`, `HOOK H0 absent`,
  `[t_exchange] PASS`; 5 PENDING lines left (B2-B4).
- `run_all.gd`: `[tests] PASS` (3 SCRIPT ERRORs after `[econ] fault test: the next SCRIPT ERROR and ERROR lines are deliberate`).
- `tools/smoke.sh --no-import`: `SMOKE PASS`.

Hooks applied (throwaway tree `scratchpad/trees/exch-hooks` = 4ceaadf5 + the hooks patch, imported once):
- `t_exchange -- --require-hooks`: `sorts checked across pages: price_asc, price_desc, level_desc, level_asc,
  durability_asc, durability_desc`, `categories: Animals 4 rows, clades 11`, `menu: HUD MENU -> Island Market ->
  MarketScreen visible=true`, `[t_exchange] PASS`.
- every `t_*.gd` PASS (incl. `[t_econ] PASS`, `[t_ui] PASS`), `run_all` `[tests] PASS`, smoke `SMOKE PASS`.

What t_exchange B1 checks (all through MarketClient -> VaultBridge.client): offline screen sends 0 searches and shows
only back/close; NetMarketClient retry reuses the rid; rows == `market.search` uids in order; every offered sort over
3+ pages equals the server's full order; a real click on a row and on Buy moves the exact instance (uid, level,
attributes) to the buyer's vault, debits exactly the price once (double click), pays the seller price - tax once, and
removes the row; errors each with its text and both stores unchanged: own listing (no Buy; server self_trade),
bound coins only (Buy disabled; stale balance -> server insufficient_funds), trade lock ("New accounts can trade in
30 min."), offline, sold under us ("No longer available.", row leaves); H2 Animals / clade / Wood / def / chip; H0 menu.

Lab (`market_ui_lab`, hooks tree, opened by pressing the HUD menu's real Island Market button), 0 SCRIPT ERROR lines,
exit 0 every run:
- 1600x900: `header=10.6% (95px) rail=10.5% cat=29.0% row=13.6% (122px) ... targets_under_44=0 clipped_labels=0 plus_buttons=0`
- 844x390: `header=11.3% (44px) ... row=12.3% (48px) rows=10 visible=6 chip=false`, with a chip `visible=5`,
  `targets_under_44=0 clipped_labels=0 plus_buttons=0`; menu sheet `rows=Bag, Craft, Map, Island Market, Save,
  Debug info: OFF scrolls=false`.
- Shots looked at next to both references (scratchpad `ex/`): buy, buy_search, buy_taming, confirm, offline at 1600x900
  gl_compatibility, 1600x900 Forward+ and 844x390 gl_compatibility; menu at 1600x900 and 844x390. Matched: header
  band and torn edge, rail with bracketed yellow Buy, sort headers with the yellow active Price, chip, gold names over
  grey types, dotted separators, the gold-gradient category row with the yellow chevron, B badge on the bonded pet.
  Fixed after looking: backdrop too dark (references sit at 0x28-0x50 per channel, ours was 0x10-0x25), loose letter
  spacing (outline-only condense), double-spaced wrapped labels, full-height confirm and offline panels, the clade
  row the lab could not pick (":" in a node name).
- Crash reports: my first six B1 lab runs (20:10-20:14) each left a Godot .ips (SIGABRT, `recursive_mutex::lock` under
  `NSApplication terminate`). Cause: MarketEngine's and CharacterStore's static error-counting Loggers are never
  removed; `MarketHarness.release_loggers()` now runs on lab exit and no run since left one (last .ips 20:20:04
  belongs to no run of mine: my queued gates started 20:21:40). The two .ips at 19:55/19:56 have the same signature
  and fall in the design step's lab window, so the design step's "no new .ips" line was likely wrong.

## For the next agent (B2 Sell, B3 My Market)

- Sell lists from the **server** character's bag (`char.get`), never the local bag (A12). Use `MarketHarness`
  (it already seeds bags, an active / sold / expired listing and two vault items for Receive All).
- Turn the B2/B3 PENDING lines in `t_exchange` into checks; reuse `_open`, `_click`, `_hook_absent`.
- H3 (band refusal in `market_book.gd`) goes into the same hooks patch; regenerate it with `git diff` of the hooked
  files on a tree where the current patch is applied, then restore those files (never commit them on this branch).
- INVUI still has no components on `claude/mmo-invui` (design only); keep the `# swap: INVUI ...` markers.
- ICONS2's `captured_animal` / `tamed_animal` renders are not on this base (claude/mmo-icons2, unmerged): both rows
  show the same placeholder until it merges; ItemArt picks the renders up with no code change.
- Risks: ECON should own a `release()` for its static Loggers (the harness reaches into ECON/SRVDOM statics); H1/H2
  change ECON's search code while ECON is still being fixed, so the patch may need a rebase at merge; `market.mine`
  can still exceed NET's 64 KiB frame (H4 note for W1-INT/ECON).

Credits spent: none. Meshy/Tripo not used.
