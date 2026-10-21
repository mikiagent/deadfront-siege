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

## B2: Sell (done, 0becbc49 + 7c1a4456 + efca7a54)

Base sync: ECON is still not merged into `claude/mmo-overhaul`; `claude/mmo-econ` moved to f5dd8ee8 (r4: recovery rids,
grant guard) and was merged (4be0a3d2). ECON's hooks patch is unchanged since "Apply ECON hooks (EXCHANGE base)" and the
cf43dd44 re-apply, so nothing was re-applied.

Shipped (spec §12 has the detail):
- **Sell tab** (`market_sell.gd`, `market_picker.gd`, `market_sell_form.gd`): an exact-instance picker of the **server**
  character (bag stacks in slot order, its bonded pets, then what waits in market storage as "Stored" cells), on the Bag
  reference's look (textured panel, dashed compartments, grey "Lv. n", "×n", yellow brackets). Refused cells stay
  visible, dimmed, with a lock or blocked mark and the reason in the panel (locked, unstable, broken, denied def,
  summoned or loaded pet; anything else is the server's own words).
- **Panel**: tan name band (B disc before a bonded pet's name), card and the asset's own facts, Quantity stepper for a
  stack, Price each (field + chevron steppers, no "+"), "Recent price N · usual range a – b", 12/24/48/72 h chips (24
  default), preview Listing fee (paid now) / Market tax (when it sells) / You receive / Net after the fee from
  `EconRules` with the engine's rounding, yellow "List for N" along the bottom; disabled with the reason ("Set a
  price", "Not enough tradable T-stones" + "Bound T-stones can't pay market fees", "Can't be sold").
- **List** re-reads `char.get` and finds the instance's slot **by uid**, then `vault.deposit` and `market.list_fixed`
  with the uid the deposit answered (part of a stack under a new uid, the rest keeps its own). Stored items skip the
  deposit. A refused second step leaves the item in market storage, still picked, with the reason.
- **Caged pets as cages**: a bonded pet is its own cell and listing (`pet:<species>`, its uid, `tamed_animal` art + B);
  a captured animal is its `captured_animal` cage (`item:captured_animal`, its uid, "Captured Compsognathus").
- `MarketScreen.open(player, &"sell", uid)` preselects an instance (INVUI's "Sell on Market").
- Harness: the viewer also holds two bones, a crafted knife, a captured cage, a bonded compy and a locked stone stack.

Changed against the design (each checked against the docs):
- **H3 dropped; the band is advice.** H3 (server refuses listings outside 0.25x-4x of the reference) made run_all fail
  in the hooks tree: `[tests] FAIL count=26`, e.g. `econ: market.list_fixed should succeed: ... "price must be between
  25 and 400"`: ECON's reference-poisoning tests list at outlier prices on purpose. Contract 6.5's band is the
  reference filter (ECON already keeps outlier trades out of the reference), spec 06 says "Players choose own
  prices", and the reference is per def, so a wall would cap a rare-trait bone at 4x a plain one. Now: steppers and
  the starting price keep to the band; a typed price may leave it with "Outside the usual range a – b for this item.
  Check the price; rare traits can be worth more." and "List anyway for N"; over `max_unit_price` is pulled to it; the
  server takes any 1..max_unit_price (t_exchange checks it). # ASSUMPTION (A6 revised).
- Starting price only from the market's own numbers (ref, last trade, cheapest ask); none: empty field, "Set a price".
- The "Waiting in your market storage" strip is the Stored cells (list again from there); Receive stays in My Market (B3).
- `MarketHarness.lock_first` sets the "locked" flag on the server character directly. # shortcut: the server has no
  lock intent until W3-SRVACT.
- INVUI's components exist on claude/mmo-invui (410c38df) but sit on W2-INV's Inventory, which this base does not have,
  so the picker and panel are this package's own with the same look and `# swap: INVUI ...` markers.

Hooks patch: unchanged for B2 (H0-H2 only); `git apply --check` passes on efca7a54.

### Checks run (B2)

t_exchange's Sell checks, all through `MarketClient -> VaultBridge.client`:
- picker cells == the server bag's uids in slot order + pet uids + vault uids (8 cells); a bonded pet is a B pet carrier,
  a captured one a crate ("Captured Compsognathus").
- locked stack: reason shown, no form, List disabled; a forced `vault.deposit` of it is refused by the server
  (`invalid_asset` ... locked), bag and wallet unchanged.
- bone: band = `MarketFormat.band(ref)` [13, 200] shown; a typed 250 is warned ("List anyway for"), the down stepper
  brings it to 200 and clears the warning; preview labels == `MarketFormat.preview`.
- List 1 of 2 bones at 20 (real clicks, double tap): one listing, fee 1 paid once; the listing is 1 bone with the
  stack's level and attributes under a new uid, the other bone stays in the bag under its uid; after account 2 buys it
  the seller's wallet moved exactly net 18 (= preview).
- the bonded pet and the cage are listed under their own uids (`pet:compsognathus`, `item:captured_animal`), the pet
  left the character; a stored item lists with no deposit.
- a stack that left the bag elsewhere before List: "That item is no longer in your bag.", nothing listed. Mutation run:
  using the picker's old slot instead of the uid re-read fails it (`FAIL a stack that left the bag ...: No longer
  available.`), then reverted.
- `open(sell, uid)` picks that instance.
- errors: price 0 -> "Set a price"; 5,000,000 -> pulled to 1,000,000; bound coins only -> List disabled with the fee
  reason; a stale balance -> the deposit happens, `list_fixed` says insufficient_funds, the panel says "Not enough
  tradable T-stones. ... safe in your market storage", wallet still 20, the stone is a picked Stored cell; the server
  refuses unit_price 0 and 1,000,001 (wallet unchanged); a price above the band lists (advice, not a wall); refusal
  reasons for tamed_animal, unstable, broken, summoned pet, loaded pet; a plain stack has none.

Gates (efca7a54 content; branch = no hooks, hooks tree = `scratchpad/trees/exch-hooks`, 4be0a3d2 + hooks patch + the
efca7a54 test):
- every `game/tests/t_*.gd` on the branch (gate run at 4be0a3d2) and in the hooks tree: 21 x PASS, rc 0; `t_save` 5
  SCRIPT ERRORs (deliberate, as on base), all others 0 (incl. `[t_econ] PASS`, `[t_ui] PASS`, `[t_uiicons] PASS
  ids=169 ...`).
- `run_all.gd` both: `[tests] PASS` (3 SCRIPT ERRORs after `[econ] fault test: the next SCRIPT ERROR and ERROR lines
  are deliberate`). `tools/smoke.sh --no-import` both: `SMOKE PASS`.
- `t_exchange` at efca7a54: branch `[t_exchange] PASS` (HOOK H0/H1/H2 absent lines), hooks tree `-- --require-hooks`
  `[t_exchange] PASS`; 0 SCRIPT ERROR each; 3 PENDING lines left (B3 x2, B4).
- With H3 applied (before dropping it): `[t_exchange] PASS` but run_all `[tests] FAIL count=26` (above).
- No new Godot .ips: 34 before this step's first run and 34 after the last.

Lab (`market_ui_lab`, hooks tree, opened through the HUD menu's Island Market button; new screens `sell`, `sell_pet`,
`sell_none`), 0 SCRIPT ERROR, exit 0 every run:
- 1600x900: `measure sell picker=50.9% cols=6 cell=133px cells=8 form=554x780 form_min=454x163 fits=true list=534x60
  'List for 100'`, `targets_under_44=0 clipped_labels=0 plus_buttons=0`.
- 844x390: `measure sell picker=40.6% cols=4 cell=82px cells=8 form=380x332 form_min=354x98 fits=true list=368x44
  'List for 100'`, `targets_under_44=0 clipped_labels=0 plus_buttons=0`.
- Shots looked at next to the two market references and the Bag reference (`durango-bag-instances.webp`, the picker
  and panel follow it; scratchpad `ex2/final/`): sell at 1600x900 gl_compatibility, Forward+ (same pixels) and 844x390;
  sell_pet at 1600x900 and 844x390; sell_none at 1600x900; the Buy confirm (unchanged after sharing asset_lines).
  Matched: header, torn edge, rail with the bracketed yellow Sell tag, Bag-style grid with grey Lv and "×n", yellow
  brackets on the pick, tan name band with the B disc like "B Zebraceratops", yellow primary along the bottom.
  Fixed after looking: empty compartments drawn before the item cells (the grid kept old fillers first), the 844x390
  panel hid the preview under the List button (tighter rhythm, level and facts on one line, two preview pairs a line,
  the range in the price caption), "×2", the B disc and "Stored" under the bracket corners, an empty card gap above the
  no-selection text.
- Left as is: captured cages and the bonded pet share the placeholder art until ICONS2's renders merge (the B disc and
  "Captured ..." tell them apart); "Stored" and "Lv. 1" sit close on 82 px phone cells.

## For the next agent (B3 My Market, B4 polish)

- My Market reads `market.mine` (listings, closed_listings, trades) and `vault.get`; Receive All is `inbox.take`, then
  one `vault.withdraw {uid}` per item and pet (spec §3.5). The Sell tab already shows vault items as Stored cells and
  re-reads after every write; after Receive All call `ms.sell.reload()` if Sell is open.
- Turn the B3 PENDING lines in `t_exchange` into checks; reuse `_open`, `_open_sell`, `_click`, `_click_cell`,
  `_entry`, `_hook_absent`. The harness already seeds an active, a sold and an expired listing and two vault items.
- INVUI's components are on claude/mmo-invui over W2-INV's Inventory; swap the `# swap: INVUI ...` parts when both reach
  this base.
- ICONS2's `captured_animal` / `tamed_animal` renders are not on this base (claude/mmo-icons2, unmerged): picker cells,
  rows and the Sell card show the same placeholder until it merges; ItemArt picks the renders up with no code change.
- Risks: the band is advice only (owner may want a wall; then it belongs in ECON with its tests changed); a picker read
  and a deposit are two ops, so a bag change between them is caught by the uid re-read, not prevented; ECON should own a
  `release()` for its static Loggers; H1/H2 change ECON's search code while ECON is still being fixed, so the patch may
  need a rebase at merge; `market.mine` can still exceed NET's 64 KiB frame (H4 note for W1-INT/ECON).

Credits spent: none. Meshy/Tripo not used.
