# Current implementation — what the build does today

One short doc per system, containing only present-tense facts and numbers, each citing the code
path that owns it. The audience is a fresh session (human or agent): read this instead of
trawling history. When the build changes a system, update its doc in the same commit.

| System | Doc | State |
|---|---|---|
| Survival needs (health, stamina, exhaustion) | [survival-needs.md](survival-needs.md) | **written 2026-10-27** — vitals trio + strain tiers, fatigue-status table, food relief & autofeed, sleep spots, day clock |
| HUD, vitals UI & status boxes | [hud.md](hud.md) | **written 2026-10-28** — layout zones per canvas, combat layer, treadmill belt, day/night dial, fatigue panel, STATUSFX boxes/particles/vignette/tick numbers, nav menu |
| Controls & input | [controls.md](controls.md) | truth inherited from the old layout (moves with any `input_setup.gd` change) |
| Items, traits & food effects | [items-traits.md](items-traits.md) | **generated 2026-10-28** — 246-item catalog, rarity/attrs, FOODFX with provenance tags, rare material attributes (5 % per-material roll, green pip, slot-1 carry); *editable source*: `game/data_sheets/items.csv` + `foods.csv` (canon) |
| Crafting, processing & cook roles | [recipes.md](recipes.md) | **generated 2026-10-28** — 180 recipes grouped by station, 8 repair tiers, the six roled cooking recipes and their slot-rule paragraph; *editable source*: `game/data_sheets/recipes.csv` + `repairs.csv` + `processing.csv` (canon) |
| World, islands, climate, flora & fauna | [world-biomes.md](world-biomes.md) | **generated 2026-10-28** — 15 islands, 10 climates with flora/materials, 19 fauna, butchering per species; *editable source*: `game/data_sheets/islands.csv` + `climates.csv` + `creatures.csv` + `butchering.csv` (canon) |
| Biome spawns: which creatures live where | [biome-spawns.md](biome-spawns.md) | **generated 2026-10-30**: per biome and per island (unstable templates, home, tutorial zones) the species that spawn, level, groups, chance, alpha, tameable, and "in game" vs "no model yet: falls through to X" (`CreatureDef.eligible`); regenerate with `tools/docs_wiki/gen_game_data.py` |
| Authored island maps (map lab) | [map-format.md](map-format.md) | `*.map.json` v1: grid layers, markers, validator codes, what the importer builds; editor `--lab=map_lab`, reader `MapDoc` |
| Inventory, bags, storage, multi-select & locks | [inventory-bags.md](inventory-bags.md) | **written 2026-10-28** — instance/uids, stacking categories, 5 bag types + capacity curves, 7 storage containers, batch lock/drop/destroy, save rows & load migration |
| Creatures, AI, capture & taming | [creatures-capture-taming.md](creatures-capture-taming.md) | **written 2026-10-28** — 19-species roster table, brains & brain selection, 10 AI states + archetypes, energy, spawns & 24 cap, capture rule, field tame, pen, bonded cap, pets, follow slots, mounts |
| Enemy AI template (class profiles) | [enemy-ai-template.md](enemy-ai-template.md) | **written 2026-10-28** — `TacticalBrain` + the deinonychus `tactics` profile: sequences, cooldowns, energy gates, clip set, natures, server rule |
| Saves & persistence | [saves-persistence.md](saves-persistence.md) | **written 2026-10-28** — `user://save_1.json` in Godot's default user dir, schema 4 + 4 migrations, key table, sanitizer clamps, .bak/quarantine rescue, 60 s autosave |
| Server & multiplayer contract | [server-contract.md](server-contract.md) | **written 2026-10-28** — local in-process engine only (no transport/auth/presence), client + system ops, journal+snapshot store, WorldFacade |
| Economy & trading | [economy-trading.md](economy-trading.md) | **written 2026-10-28** — single T-stone int, 2 sinks + 3 sources, XP table, market.json data, Island Market engine (offline in single player) |
| UI screens (every screen, phone landscape) | [ui-screens.md](ui-screens.md) | **captured 2026-10-28** — `docs/current/screens/` (31 WebP at 844x390 drawn 2x) + the newer sheet captures under `docs/orchestration/reports/`; rerun `tools/ui_screens.sh` |
| Glowing eyes, bloom & trails | [eyes.md](eyes.md) | **written 2026-10-28** — eyeshine dots, rim light, wisp/bloom/embers mesh, per-species `eyes`/`trail` data, cost & tests |
| Occlusion (see-through props) | [occlusion.md](occlusion.md) | **written 2026-10-28** — the between-camera-and-survivor rule, dither constants, 8 MultiMesh slots, roof fade, tests |
| Tribe members & dock recruits | [tribe.md](tribe.md) | **written 2026-10-28** (branch `claude/mmo-tribe`) — boat arrivals waiting at the dock for Accept/Deny, housing cap, orders, one job at a time, needs, gear, Tribe tab, save row |
| Tutorial island & new-survivor flow | [tutorial.md](tutorial.md) | **written 2026-10-28** — creation → tutorial island → 18 tutorial orders on the Orders system → Tamed Island pick → ferry home; pointer, save row, dev flags |
| Hitboxes and hurtboxes (how melee hits land) | [hitboxes.md](hitboxes.md) | **written 2026-10-31**: bone hurtboxes fitted from the skinned mesh, data-driven attack parts and windows swept over the clip, which move uses which parts, calibrated radii, debug draw (H in the fight lab) |
| Fight lab (god mode, species verdicts) | [fight-lab.md](fight-lab.md) | **written 2026-10-30**: `tools/fight_lab.command`, GOD/NEXT controls, every modelled species with its brain, moves and fight clips, a verdict column for Milan |
| Unstable isles (generated islands) | [unstable-isles.md](unstable-isles.md) | **written 2026-10-30**: what the generator rolls (level, template, shape, size, landmarks, Rift Pool), how a player reaches one, a 6-isle contact sheet, and `tools/unstable_isle.command` to land on a fresh one |
| Creature rigs and clips | [creature-clips.md](creature-clips.md) | **generated 2026-10-28** — per species: jaw, wings, and which of the 25 clips ship (bite_combo, leaps, dodges, strafes, walk_back, kick, charge...) |
| Species art (owner's reference sheets) | [species-art.md](species-art.md) | **written 2026-10-30**: 52 sheets for 32 species under `docs/art/species/`, each marked regular / Alpha skin / sex variant / reference only, with in-game status and the owner's naming decisions |

*(Sheets live in the canon worktree's `game/data_sheets/` — nine CSVs the owner can edit in any
spreadsheet app, synced back into `game/data/*.json` by the agent. The three generated pages come
from `tools/docs_wiki/gen_game_data.py`; re-run it after any balance pass or accepted sheet sync.)*

Rules for this folder:
- Facts, ranges, code paths — no history, no "why", no design debate. The past lives in deep
  docs; the future in `../vision/`.
- Every number in a doc must be traceable to a constant in a named file (or a rules.json key).
- Keep each doc under ~120 lines; a system's truth should fit on one screen or a table.
