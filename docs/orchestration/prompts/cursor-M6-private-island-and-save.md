# Cursor milestone M6 — your own island, and saving the game

Durango's home loop: a permanent private island you pick once, build on without tax or decay, warp home to for free, and come back to between unstable islands. This milestone adds that island, the harbour travel between it and the unstable island from M5, and save/load so the home persists. Do it after M5 and M4.

## Read first
- `docs/prd/durango-wild-lands-systems-prd.md` §4.2 "Private tamed island", §4.3 travel table (port sail, domain warp, camp recall, cargo warp), §13.1 (domain claim rules; private islands have no tax and no decay), §13.3 building catalogue, §14.5 (unstable goods must be cargo-warped)
- `docs/orchestration/plan.md` decisions D4 (single-player, but data must not assume it) and D5 (snapshot C)
- Your M5 island generator and `game/data/islands/`

## Tasks

1. **Island registry and travel.** `game/data/islands/` gets `home_grassland.json` (private island: grassland climate, level 10 ecology, 160 × 160 m, permanent) alongside the M5 unstable island. A `World` autoload owns the loaded island, and a **harbour** node on each island opens the sea-route list (PRD §4.3): sail to an unstable island (costs T-stones, placeholder currency counter), free return home from any unstable harbour, free "warp home" from the map screen, and "return to camp" on unstable islands. Travel is a fade, a load of the target island scene, and placement at its harbour. No ocean sailing.

2. **Choose your terrain once.** First arrival at home shows a one-time choice of five terrains (PRD §4.2): meadow, forest, rocky, riverside, coastal. Each is the grassland generator with different vegetation densities and layout from the nature manifest. The choice is permanent and saved.

3. **Building on the home island.** Extend `BuildPlacer`: everything placed on the home island is protected, free, and never decays (PRD §13.1). Catalogue for now: bonfire, workbench, drying rack, taming pen, basket (storage, ~100 slots per PRD §9.2, `# ASSUMPTION:` 60 for mobile UI sanity), tent (rest: fatigue drains fast inside), fence segments and gate, sign (text). Pack-up returns the materials. Preview before consume (PRD §13.3 SHOULD).

4. **Home comforts.** Resting in the tent drains fatigue and continues while "logged off": on load, apply rest for elapsed real time (PRD §2.3). Baskets are inventories the pet can also dump into. A **Pioneer Level** counter rises with buildings placed and first-time crafts, shown on the HUD; no unlocks yet beyond the number.

5. **Unstable goods and cargo warp.** Items gathered on the unstable island carry the `unstable` flag (PRD §8.4). Bringing them home on foot through the harbour **destroys them with a warning**; the camp's **cargo warp** node sends them home to a cargo basket at the home harbour for a T-stone fee (PRD §14.5). Show the flag as a pip in the inventory.

6. **Save and load.** A `SaveGame` resource serialised to `user://save_1.json`: player vitals, statuses, inventory, bonded pets with hunger and grade, skills, home island terrain choice and every placed building with its contents, Pioneer Level, T-stones, current island id and position, the unstable island's remaining lifetime and its harvested-node state, world clock. Autosave on travel and every 60 s; manual save in the pause menu; load on boot if a save exists, else new game at the home harbour. Never store node references; store ids. Version the schema (`"schema": 1`).

7. **Map screen** (mobile-first): current island, remaining lifetime for unstable islands, harbour routes, warp-home button, fatigue breakdown (from M5), and the discovered crater marker.

## Acceptance
- PRD §24 test 4 and 5 in spirit: gather on the unstable island, sail home with unstable items on foot and lose them with the warning; cargo-warp the same items and find them in the cargo basket.
- Quit and relaunch: the home island, its buildings, basket contents, pets, and the terrain choice are exactly as left; the tent applied offline rest.
- Smoke passes; `--lab=home_lab` boots straight onto the home island. Report and commit as `M6: private island, travel, save/load`.
