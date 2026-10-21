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

## B3: My Market and Receive All (done, b9685fc7 + docs commit)

Base sync: ECON is still not merged into `claude/mmo-overhaul` (no merge of claude/mmo-econ in its log); HEAD already
contains `claude/mmo-econ` f5dd8ee8 (nothing new to merge), and ECON's hooks patch is unchanged since cf43dd44, so
nothing was re-applied.

Shipped (spec §13 has the detail):
- **My Market tab** (`market_mine.gd`): a sub-tab band (Active n/50, Sold, Expired, History; the shown one lighter with
  yellow brackets like the rail), rows in the Buy row style, a footer with the status line, "n waiting in market
  storage" and a yellow Receive All. Every row is one `market.mine` answer: Active = open listings ("Ends in 2 d 11 h",
  white Cancel); Sold = closed listings sold ("Sold · +N credited", N from the account's own trades for that listing);
  Expired = expired and cancelled ("… · back in storage", units = qty minus units sold); History = the account's trades
  ("Bought" / "Sold" / "Sold to Settlers", "· 13 h ago", the trade total). Sold / Expired page with the server
  (page_size 20, a pager when there is a page 2).
- **Cancel**: the listing panel (MarketConfirm) in a cancel mode: the asset's facts, "Listed at N", that it goes to market
  storage and that the listing fee is not refunded; Keep listing / Cancel listing; one `market.cancel`. A listing that
  sold meanwhile: "No longer available.", nothing moves, the tab re-reads.
- **Receive All**: `inbox.take` (the events become the status line), then one `vault.withdraw {uid}` per item and pet,
  0.25 s apart. Changed from spec §3.5: every uid is tried once and a refusal does not stop the rest (a stack can still
  merge after a knife found no slot); the first refusal is the reason ("2 still waiting: Your bag is full."; bag_full's
  server msg names def ids, so it is not appended). Disabled when nothing waits; pressing again only retries what is
  still there. Proceeds need no claim (A5: the engine credits sales straight to the wallet). The header's wallet is
  re-read when My Market opens.
- `MarketClient.now()` (device clock; the harness clock on LocalMarketClient) for "ends in" and "ago".
  # shortcut: NetMarketClient uses the device clock until NET reports a server-time offset.
- `MarketHarness.fill_bag` loots single knives from a "pile" corpse until the server answers `bag_full` (plain
  materials stack to 999 a slot on this base, so gathering cannot fill a bag).

Assumptions added (spec §13): History does not name the other party (trade rows carry account ids, not names; an ECON
change if wanted); Receive All tries every uid instead of stopping at the first refusal.

Hooks patch: unchanged (H0-H2; B3 needs no change outside the package). It applies to b9685fc7: the hooks tree below was
built from it with `mkscratch.sh exch-hooks b9685fc7 <patch>` ("Applied patch to ... cleanly" for both files).

### Checks run (B3)

New t_exchange checks (all through `MarketClient -> VaultBridge.client`; the two B3 PENDING lines are gone):
- My Market sub-tab rows == `market.mine` ids for Active, Sold, Expired and History; a sold row says the net its sale
  credited, equal to the seller's wallet delta (+19 for a 20 sale); History tells Bought, Sold and Sold to Settlers apart;
  an active row says when it ends and has Cancel.
- Cancel: the panel says the kept fee; a double tap cancels once ("Cancelled."), the wallet is unchanged (fee kept), the
  exact units (uid, count, level, attributes) are back in market storage, the row leaves Active, storage holds one more,
  Expired shows "Cancelled · back in storage"; a listing bought by another account while the panel is open: "No longer
  available." and char, vault and wallet unchanged.
- Receive All: storage count shown; after the press storage is empty and every unit is in the bag; a bought knife is home
  under its own uid with its durability and level; the status says "Received 3 into your bag." plus the inbox news ("Sold
  Fibre Stalk ×1 to Trader2"); `inbox.take` afterwards returns no events; the button is disabled and a forced second
  press changes nothing ("Nothing was waiting.").
- Full bag: 2 of 3 still waiting with "2 still waiting: Your bag is full."; every unit is in the bag or in storage; a
  second press with the bag still full moves nothing.
- Mutation run (then reverted): Receive All without `inbox.take` and My Market rows in reverse order -> `[t_exchange]
  FAIL count=3` ("My Market sold rows == market.mine (["L357", "L377"] vs ["L377", "L357"])", "the inbox was taken",
  the status/news check).

Gates at b9685fc7 (branch = no hooks; hooks tree = `scratchpad/trees/exch-hooks`, b9685fc7 + the hooks patch, imported once):
- every `game/tests/t_*.gd`, both trees: 21 x PASS, rc 0; `t_save` 5 SCRIPT ERRORs (deliberate, as on base), all others
  0 (incl. `[t_econ] PASS`, `[t_ui] PASS`, `[t_exchange] PASS`).
- `t_exchange`: branch `[t_exchange] PASS` with the HOOK H0/H1/H2 absent lines; hooks tree `-- --require-hooks`
  `[t_exchange] PASS` (`sorts checked across pages: price_asc, price_desc, level_desc, level_asc, durability_asc,
  durability_desc`, `menu: HUD MENU -> Island Market -> MarketScreen visible=true`); 1 PENDING line left (B4).
- `run_all.gd` both: `[tests] PASS`; its 2 SCRIPT ERROR lines are FaultyEngine's after `[econ] fault test: the next SCRIPT
  ERROR and ERROR lines are deliberate` (a grep count says 3 because that announcement line contains the words).
- `tools/smoke.sh --no-import` both: `SMOKE PASS`.
- No new Godot .ips: 34 before this step's first run and 34 after the last (newest still Godot-2026-10-20-202004.ips).

Lab (`market_ui_lab`, new screens `my_market_sold`, `my_market_history`, `my_market_cancel`, `my_market_received`;
`my_market` now shows the tab), 0 SCRIPT ERROR, exit 0 every run:
- 1600x900: `measure my_market tab=active rows=1 visible=5 row=122px cancel=177x58 receive=220x58 'Receive All'`,
  `targets_under_44=0 clipped_labels=0 plus_buttons=0`.
- 844x390: `measure my_market tab=active rows=1 visible=4 row=48px cancel=94x44 receive=150x44 'Receive All'`,
  `targets_under_44=0 clipped_labels=0 plus_buttons=0` (History: 6 rows, 4 visible).
- Hooks tree: `[market_lab] menu: pressing the HUD's Island Market button`, then the same measure lines.
- Shots looked at next to both market references (scratchpad `ex3/`): my_market, my_market_sold, my_market_history,
  my_market_cancel, my_market_received at 1600x900 gl_compatibility and 844x390 gl_compatibility; my_market at 1600x900
  Forward+ (same pixels); my_market (1600) and my_market_received (844) again in the hooks tree, opened through the HUD
  menu. Matched: header and torn edge, the rail with the bracketed yellow My Market ledger, gold names over grey types,
  "Lv. n", coin prices, dotted separators, the selection's yellow brackets on the sub-tab. Fixed after looking: "13 h 0
  min ago" (zero minor units dropped), the Settlers status ellipsized (the Cancel column's width goes to the status off
  Active), the Receive All button touching the panel edge, "1 T-stones", a stray separator after History.
- Left as is: History rows read `Lv. —` (a trade record keeps no level); the bought/sold icons for pets and cages are the
  same placeholder art until ICONS2's renders merge.

## B4: polish, responsive layouts, input, 500 listings (done, ccec4775 + 209fcebe + 6fc138df + b8f39260 + docs commit)

Base sync: ECON is still not merged into `claude/mmo-overhaul`. `claude/mmo-econ` moved to 031e0efa (ECON r5) and was merged
(983bf9e0); ECON's hooks patch changed its `intent_handlers.gd` hunk (roster cap moved to VaultBridge, a grant part keeps
creator/created_at), re-applied in 75cadf2c (the file hashes to the patch's ca9224c5). r5 makes a listing fee a sink that
bound T-stones pay first, so Sell now checks the whole wallet against the fee (ccec4775); buys stay tradable-only.

Shipped (spec §14 has the detail):
- **Scrolling lists** (`market_drag_scroll.gd`, new): every market list (Buy rows, the category column, Sell's picker, My
  Market) drags with a finger or the mouse; the row under the finger does not fire after a drag; the wheel works; focus is
  followed. Before B4 a phone could not scroll any list made of rows (Godot's own drag-scroll needs a touchscreen and never
  sees a press a STOP button took).
- **Buy scrolls through the whole market** (no pager, like the references): near the end the list asks the server for the
  next page and appends it, a listing already shown is skipped; a bought or vanished row leaves and the last page is asked
  again, so nothing is skipped either.
- **Keys and gamepads**: with nothing focused the first arrow / Tab / d-pad lands on the first row; Enter opens the listing
  with Close (or Keep listing) focused; Escape closes the panel first and focus returns to the row, then the screen.
- **Safe areas**: header buttons and pills, body, confirm and search sheet keep inside the insets; the band spans the screen.
- **44 pt targets on every phone**: 667x375 is drawn on DisplayMode's 804 px canvas, so 44 px was 36 pt; the market's
  targets are 53 px there (44 pt). Level / Durability / Price take their share or what their full word needs; the name is
  the one cut. Sell keeps Quantity and Price on one line and its fee / tax / proceeds preview above List for every instance.
- `MarketHarness.seed_bulk`, lab screens `buy_500` and `sell_tool`, `--insets=L,R,B`, new measure lines; t_exchange's last
  PENDING line is gone.

Changed against the design, each checked against the docs: Buy's pager is gone (the references have none; spec gate 12 now
reads "scrolled to the end"); My Market's Sold / Expired keep their small pager. Targets are 44 **pt**, not 44 canvas px
(GAUNTLET's rule is about the glass; type keeps DisplayMode's 10 pt floor at 667x375, its own # ASSUMPTION).

Hooks patch: unchanged (H0-H2; B4 needs nothing outside the package). It applies to b8f39260: the final hooks tree was built
from it with `mkscratch.sh exch-b4h b8f39260 <patch>` ("Applied patch to ... cleanly" for both files).

### Checks run (B4)

New t_exchange checks (all through `MarketClient -> VaultBridge.client`):
- 500 listings seeded by real ops: page 1 shows 20 rows and no pager; scrolled to its end the list is
  `market.search`'s 500 uids in the server's order (10 pages of 50 compared), each once; every page built in < 8 ms.
  Quote: `[t_exchange] 500 listings: 500 rows in the server's order over 25 pages, build max 1.96 ms; drag 150 px opened
  nothing; keys row 1 -> row 2 -> listing -> back`.
- A drag of 150 px over a row scrolls the list by 150 and opens nothing; a tap afterwards opens its listing; Down with nothing
  focused focuses row 1, Down row 2, Enter opens row 2 with Close focused, Escape closes it and row 2 has focus again.
- Safe area: with 47/47/21 px insets every visible target is inside the safe rect and the header band spans the screen.
- Sell under ECON r5: bound-only coins enable List (`a bound-only seller lists: fee N paid from bound`, bound 20 -> 20 - fee),
  a fee over the wallet disables it with "The listing fee is N T-stones; you have 20.", a stale balance still ends safe in
  storage ("Not enough T-stones for the listing fee. ...").
- The sorts-across-pages check now reads the appended list (same order and uid set as the server's).
- Mutation run: the new t_exchange against the pre-B4 market files (git stash of `game/scripts/ui/market/`) ->
  `[t_exchange] FAIL count=12`, e.g. `FAIL page 1 shows 20 rows and no pager`, `FAIL scrolled to its end the list is the
  server's 500 listings in order (20 rows, 500 wanted, pages 1)`, `FAIL a drag over the rows scrolls them (0 px) and opens
  nothing`, `FAIL an arrow with nothing focused lands on the first row (PagePrev...)`, `FAIL with 47/47/21 px insets every
  target is inside the safe area ... MarketBack [P: (16.0, 17.0) ...`; restored, `[t_exchange] PASS`.

Gates at b8f39260, run one tree after the other (branch = no hooks; hooks tree = `scratchpad/trees/exch-b4h`, b8f39260 + the
hooks patch, imported once):
- every `game/tests/t_*.gd`, both trees: 21 x PASS, rc 0; `t_save` 5 SCRIPT ERRORs (deliberate, as on base), all others 0
  (incl. `[t_econ] PASS`, `[t_ui] PASS`, `[t_exchange] PASS`).
- `t_exchange`: branch `[t_exchange] PASS` with `HOOK H0/H1/H2 absent` lines and 0 PENDING lines; hooks tree
  `-- --require-hooks` `[t_exchange] PASS` (`sorts checked across pages: price_asc, price_desc, level_desc, level_asc,
  durability_asc, durability_desc`, `categories: Animals 4 rows, clades 11`, `menu: HUD MENU -> Island Market ->
  MarketScreen visible=true`, the 500-listing line with `build max 1.75 ms`).
- `run_all.gd` both: `[tests] PASS` (its SCRIPT ERROR lines follow `[econ] fault test: the next SCRIPT ERROR and ERROR lines
  are deliberate`). `tools/smoke.sh --no-import` both: `SMOKE PASS`.
- An earlier gate run (6fc138df, both trees at once while lab shots ran, load average 11-13) had `[t_save] FAIL count=2` in
  each tree, different checks each time (hostile save cases; full cargo kept rows). `t_save` alone then passed in both trees
  (`[t_save] PASS`, 5 SCRIPT ERRORs), and so did both final sequential runs: load-dependent, not market code.
- No new Godot .ips: 34 before the final runs (newest `Godot-2026-10-20-202004.ips`), 33 after (macOS pruned the 2026-10-13
  report), newest unchanged.

Lab (`market_ui_lab`, hooks tree, every run opened by pressing the HUD menu's Island Market button: `[market_lab] menu:
pressing the HUD's Island Market button` x65): 68 runs, rc 0, 0 SCRIPT ERROR each. Every screen (menu, buy, buy_search,
buy_taming, confirm, sell, sell_pet, sell_tool, sell_none, five My Market screens, offline) at 1600x900 gl_compatibility,
844x390 and 667x375; buy, buy_taming, confirm, sell, my_market at 1920x1080 and 1600x900 Forward+; ten screens at 844x390
with 47/47/21 px insets; buy_500 three times. In every run: `targets_under_44=0` (in points), `clipped_labels=0`,
`outside_safe=0`, `plus_buttons=0`, `heads_cut=0`; Sell's every instance `hidden_under_list=0`. Names cut: only "Captured
Compsognathus" at 844x390 under a notch with the category column open (table 422 px; ellipsized, the confirm shows it whole).
- Points: `window=(668.0, 376.0) pt canvas=(804.0, 453.0) target_min=53px (44 pt) type_min=10.0pt`, `window=(844.0, 390.0)
  ... target_min=44px`, `window=(1920.0, 1080.0) pt canvas=(1600.0, 900.0) ... type_min=14.4pt`.
- 500 listings (gate 12): `buy_500_glc_1600: listings=500 rows=500 unique=500 pages=25 build_max=1.58ms frames=504 in 4.6s
  frame_max=26.7ms over33=0`; Forward+ `build_max=1.38ms ... frame_max=12.6ms over33=0`; 844x390 `build_max=1.35ms
  frames=199 in 1.7s frame_max=18.5ms over33=0`. Seeding 490 listings by real ops took ~240 ms.
- Menu at all three sizes: `rows=Bag, Craft, Map, Island Market, Save, Debug info: OFF scrolls=false`.
- Shots looked at next to both references (scratchpad `ex4/final2/shots`, and the fix rounds `ex4/s2`-`s8`): buy, buy_taming,
  buy_search, confirm, sell, sell_tool, my_market, my_market_received, buy_500 at 1600x900 gl_compatibility; buy, buy_taming,
  sell at 1920x1080; buy at 1600x900 Forward+; buy_taming, buy_search, sell, sell_pet, sell_tool, confirm at 844x390 with
  the notch insets; buy, buy_taming, buy_search, confirm, sell, sell_pet, my_market, my_market_history, my_market_received,
  offline at 667x375; menu and my_market_cancel at 844x390. Matched: torn-edged black header with back, white island name,
  the T-stone pill and X; rail with the bracketed yellow active tab; textured weathered panels; gold names over grey types;
  "Lv. n", cur/max, coin prices; dotted separators; "Item Name/Type" and the sort arrows with the yellow active Price; the
  category column with the gold-gradient selected row and its yellow chevron; the B disc on the bonded pet. Fixed after
  looking: Sell's panel ran off the right edge at 667x375 and under a notch (the price's up chevron cut off), the Sell
  preview sat under List on phones (every instance under a notch) and on the desktop for the knife, Durability was cut to
  "Durabil…" under a notch with the category column open, the 667x375 duration chips were 52 px under the 53 px target.
- Left as is: the cage and carrier art are ICONS2's placeholders (the B disc and "Captured …" tell them apart); a cage or
  pet shows "—" for durability where the reference shows 100/100 (the validator refuses durability on cages; nothing is
  invented); type at 667x375 is DisplayMode's 10 pt floor.

Incident (my error, reported for the owner): mid-way through the final chain a cleanup outside this run removed the scratch
hooks trees under `scratchpad/trees/` (exch-hooks among them). My gate and shot scripts did not check their `cd`, so a
failed `--script res://tests/t_*.gd` run, `run_all.gd`, `tools/smoke.sh --no-import` and a few market-lab boots ran in the
session's working directory, the owner's checkout `/Users/milankinzy/Documents/deadfront-siege` (22:44-22:46), whose `game/`
has no override.cfg, so they used the default user dir `~/Library/Application Support/Godot/app_userdata/Durango-like
(working title)`. I stopped them within two minutes. Read-only check afterwards: `save_1.json` (2026-10-18 02:34),
`save_1.json.bak` and `bot_save.json` unchanged, nothing in the checkout outside `.git` changed (find -newermt), no runs/
folder left; Godot's log rotation (5 files) in that user dir's `logs/` dropped whatever older logs were there. Other runs
keep writing there too (a 23:06 log in it opens `res://tests/t_domain.gd`, which is not mine). Nothing else was done in
those folders. The scripts now refuse to run without the tree and its `game/override.cfg`; the hooks tree was rebuilt
as `exch-b4h` and every hooks-tree number above comes from it.

## For the next agent

- W3-EXCHANGE's build steps are done (B1-B4, 0 PENDING). What is left is merge work: ECON merges first; then H1/H2 go to
  ECON (market_query.gd) and H0 to the integrator (hunt_hud.gd's menu), from `claude-mmo-exchange-hooks.patch`.
- My Market re-reads on open, after a cancel and after Receive All; when W1-INT pushes inbox events over the socket, call
  `ms.mine.reload()` on a pushed sold / expired event while the tab is shown (spec §10).
- INVUI's components are on claude/mmo-invui over W2-INV's Inventory; swap the `# swap: INVUI ...` parts when both reach
  this base. ICONS2's `captured_animal` / `tamed_animal` renders (claude/mmo-icons2) are picked up by ItemArt with no code
  change.
- Risks: the band is advice only (owner may want a wall; then it belongs in ECON with its tests changed); a picker read
  and a deposit are two ops, so a bag change between them is caught by the uid re-read, not prevented; ECON should own a
  `release()` for its static Loggers; H1/H2 change ECON's search code while ECON is still being fixed, so the patch may
  need a rebase at merge; `market.mine` returns every open listing and up to 100 trades with full asset dicts and can
  still exceed NET's 64 KiB frame (H4 note for W1-INT/ECON: page `listings` and `trades`); NetMarketClient's "ends in" uses
  the device clock; offset paging can still skip a listing another player sells while you scroll (the server has no
  cursor; ECON could add one); drag-scrolling was proven with mouse events headless and in the lab, not on a touchscreen
  (the touch path is Godot's touch-to-mouse emulation, on by default).

Credits spent: none. Meshy/Tripo not used.
