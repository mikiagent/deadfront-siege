# W2-GATHER report (claude/mmo-w2-gather)

## What shipped
- `game/data/loot_tables.json`: rare gather finds per node role/family (resin on trees, flint and obsidian-pick-gated copper_ore on rock, berry_seed on bushes, spice_herb on plants, flax_seed on ground, pearl on coral, copper-pick-gated silver_ore on black iron). Tool tier and Gathering level raise the odds, with a cap. Butcher part gates by knife tier and butcher count/rare scaling.
- `game/data/gather_rules.json`: role tool affinity (axe on trees, pick on rock, knife on bushes and plants), bare hands 1.35x slower, rare XP bonuses.
- `game/scripts/gather/`: `LootTables` (data), `LootRoller` (pure roll math, injected RNG, usable by the server), `GatherService` (effective tool, seconds and yield per unit, after_unit: "+n Item" popup, rare roll into a free slot only, announcement, XP), `ButcherLoot` (carcass from butchering.json: counts scale with knife tier and Butchering level, scutes/dense bone/venom need a better knife, "rare" rows now roll their `chance` (default 0.12) instead of always dropping), `GatherFeedback` (2D popups on CanvasLayer 45, above world labels at 40; gold "RARE x" plus HUD notice "Rare find: x"), `GatherXp` (W2-SKILLS sink).
- `game/tests/t_gather.gd`, plus `--lab=gather_lab` (`game/scenes/dev/gather_lab.tscn`, `game/scripts/dev/gather_lab.gd`).

## Minimal edits outside owned dirs (integrator: keep or re-apply)
- `game/scripts/player/player_actions.gd`: `_scaled_gather_seconds` -> `return GatherService.unit_seconds(p, node)`; `_gather_yield_multiplier` -> `return GatherService.yield_multiplier(p, node)`; in `finish_gather` after `gt.consume_unit()`: `GatherService.after_unit(p, gt, stack.def_id, gained)`.
- `game/scripts/creatures/corpse.gd`: `_roll_loot()` body -> `ButcherLoot.roll_into(self, _owner)`.

## Integrator hooks still to apply
- `game/tests/run_all.gd`: nothing required; register `t_gather.gd` with the t_*.gd sweep.
- `tools/labs.txt`: add `gather_lab`.

## W2-SKILLS interface
`GatherXp.sink = func(player: Player, category: String, amount: float, source: Dictionary) -> void`; source = {verb: gather|butcher, item, rare, node_level}. Unset falls back to `player.skills.add_xp`. Today it carries only the rare-find bonus XP. The per-unit +2 gathering / +3 butchering XP calls in PlayerActions are unchanged.

## Gate lines seen (after merging claude/mmo-overhaul 1c89134a, tip ec5a2d66)
- import exit 0; `tools/smoke.sh --no-import` -> SMOKE PASS
- run_all -> `[tests] PASS`
- every t_*.gd exit 0 with PASS: t_ai, t_build, t_canim, t_combat, t_gather, t_harbour (islands=15), t_iconart, t_items, t_light, t_lighting, t_occlude, t_player, t_save, t_server_domain, t_srvdom, t_structart, t_tame, t_ui, t_uiicons, t_web
- t_gather lines: fibre seconds bare 1.76 knife 1.30; branch yield mult stone 1.00 flint 1.25; flint per stone unit bare 0.0485, obsidian pick 0.0725 (data 0.05); raptor meat per carcass stone knife 2.51, flint knife 3.27; talon rate 0.159. Mutation check: flint chance 0.2 -> `[t_gather] FAIL ... (got 0.2001)`, so the test can fail.
- `--gather-test` -> `[gathertest] ok +2 branch`; craft_lab, wild_ai_sweep_lab, plain_bush_lab PASS, 0 SCRIPT ERROR.
- gather_lab headless and windowed (1600x900 glc, 844x390 glc) -> `[gather_lab] PASS`. Seconds per pass with hands vs stone tools: fibre 1.77->1.30, branch 2.16->1.62, stone 3.78->2.81; logs refuse bare hands ('need tool axe'), a stone axe gathers them at 3.00. A rare flint landed. A raptor butchered with a stone knife gave meat, hide, bone and tendon. The bush depleted after 14 units and regrew after 90 s.

## Screenshots I looked at
`gl1600-{hands,tools,rare,butcher}.png` and `gl844-{hands,tools,rare,butcher}.png` (session scratchpad). On both sizes the yield popups ("+2 Log", "+3 Branch", "+3 Stone") and the gold "RARE Flint" with the "Rare find: Flint" notice are readable over the world labels. At 844x390 the rare popup draws over the ORDERS panel for about 1.4 s. In `loot_screen`, the lab's chest screen sits under the HUD and world labels. That comes from the LabKit layer order and was not checked in the real game.

## Assumptions
- Rare odds and bonuses are illustrative values in loot_tables.json; the PRDs give none.
- Bare hands are 1.35x slower than the role's tool.
- The carcass rolls when the animal dies, for the local survivor's best knife and Butchering level (single player; W3 should roll for the credited killer).
- Knife tier stands in for the Butchering part nodes until W2-BUTCHER adds them.
- A rare find only rolls into a free bag slot, so no item is ever minted and lost.
- In gather_lab the starter tools are handed over, and the seed is picked so the next stone unit rolls a find (the odds are proven in t_gather).

## What is left
1. W2-BUTCHER / W2-SKILLS: per-part Butchering nodes (Leather I, Bone I/II, Teeth, Horn), a per-part take refusal in the chest screen, Slaughter/Mining/Plant Gathering ability, flawless and mistake results, separate gather techniques per part (spec 12 s1-2).
2. W3-SRVACT: the server gather handler should call LootRoller with its own RNG (intent_handlers does not roll rares yet).
3. Yield popups for corpse takes (the HUD toasts already show them).
4. W2-DATA: once rarity moves into items.json, review the rare items picked here (resin and flint are marked common in item_rarity.json).
5. Not done: no Forward+ windowed run of gather_lab, no web export check.
