# Regression, user-visible QA and release evidence

**Authority:** `HANDOFF.md` and `GAUNTLET.md` describe the repo's shipping protocol, but they contain older snapshots. Use current `origin/main` and actual deployed stamp at task start; do not assume a historical immutable URL is the live version.

## Permanent test gates

1. **Before modification:** `git fetch origin`, record exact `origin/main` SHA; compare against docs audit SHA; import project and run `tools/test.sh` and `tools/smoke.sh`. Record pre-existing failures.
2. **Focused behavioral reproduction:** use existing `game/tests/run_all.gd` assertions and `game/scripts/dev/*lab.gd` scenes; create one targeted regression for changed path with both old and new behavior where applicable.
3. **Save roundtrip:** load old schema 0-3 fixtures and representative latest-good real snapshot, save and reload; compare economic quantity totals, material lot attributes, structure placement, pet genetics and XP. For schema bump run the explicit new migration and check malformed/newer schema is not overwritten.
4. **Import/compile/full suite/smoke:** no parse errors; `[tests] PASS`; `SMOKE PASS`. Relevant labs must assert the exact mechanic, not generic boot.
5. **Visual and interaction:** actual desktop Chrome with real mouse and keyboard in 1600x900; touch 390x844 check when relevant. Inspect screen pixels and animation from real game, not logs, node tree or synthetic touch alone. Preserve HUD hex family, minimap, interaction radius, animation rigs and readability.
6. **Performance:** avoid increasing main-loop AI polling/creature count and enormous island/player/hunt-hud files without measured performance and extraction; pay attention to web pack/streaming.
7. **Only upon explicit release authorization:** run existing web export/deploy, inspect immutable build, production alias and actual `<commit>/<pack-hash>` display stamp; verify latest alias and saved player content. A Vercel deploy response isn't proof of alias promotion.
8. **Report:** baseline SHA, code commit, files changed, exactly which tests ran and their outcomes, old-save fixtures, screenshots/visual observations, deployment status, known risks and any unresolved owner decision.

## Commands (existing repo)

```bash
GODOT_PATH=/path/to/Godot_4.7
"$GODOT_PATH" --headless --path game --editor --quit
GODOT_PATH="$GODOT_PATH" ./tools/test.sh
GODOT_PATH="$GODOT_PATH" ./tools/smoke.sh
"$GODOT_PATH" --headless --path game -- --lab=ai_validation_lab
"$GODOT_PATH" --headless --path game -- --lab=ui_family_lab
# Feature-appropriate labs can include build_lab/craft_lab/capture_lab/island_lab and new focused labs.
# Only when release is specifically authorized:
./tools/export_web.sh
./tools/deploy_web.sh
CHROME_PATH=/path/to/chrome SOAK_ARTIFACTS=/tmp/deadfront-soak node tools/production_soak.mjs https://durango-like.vercel.app/
```

This is a *reproducible acceptance plan*, not evidence that all commands ran for this documentation PR.

## Feature-specific protection matrix

| Extension | Existing suite/lab to rerun | New decisive acceptance |
|---|---|---|
| Save migration | `_test_save_migrations`, `_test_sleep_building_save`, `build_lab` | v0-3 roundtrip, corrupt/future-file non-destruction |
| Item provenance/fusion | `_test_multistack_crafting`, `_test_storage_transfer`, `craft_lab` | both signed traits survive, ingredient conservation, stack split/merge |
| Food spoil | `_test_food_buffs`, `kitchen_lab`, offline field tests | bag/cargo/ground storage clocks, 0% -> rotten exactly once |
| Building prefabs | `_test_save_with_craft_stations`, `build_lab` | full capacity pack rejection, stable ID and maker, connected modules |
| Animal breeding and genetics | `_test_creature_genetics`, `capture_lab`, `pets_lab` | legacy IV 0-31 survives; new lineage saves |
| Mount/crew | `pets_lab`, relevant `ai_validation_lab` | physical seat occupancy, driver KO and gunner absence, no duplicate crew |
| Siege/auto turrets | `_test_catapult_recipe_save`, `siege_probe.gd` | stationary Player fire unchanged; single reserve ammo ledger |
| World/salvage/boats | `island_lab`, `home_lab`, `cargo_capacity_probe.gd` | no home wipe, stable cargo, actual protected depart event |
| Combat mass/armor | `_test_combat_counters`, `ai_validation_lab`, `tyrant_window_probe.gd` | local zones and contact; no pounce pin on intact Heavy plates |
| UI/accessibility | `ui_family_lab`, `ui_screenshot_lab`, production desktop soak | numerical tooltip accuracy, mouse/touch actual functions |

## Release stop signals

- Existing saves become unreadable or older schema gets silently reset.
- Successful recipe outputs/consumption change unexpectedly outside reviewed recipes.
- Duplication, dropped items in full storage, phantom NPC/crew/ammo, missing inventory/pet/structure, retargeted attack counters incorrectly.
- Incorrect creature visual / stuck animation / black canvas / obscured HUD / player cannot interact.
- Current live alias not serving expected build identity.
- Product rule still `OPEN` but code arbitrarily commits hard-to-migrate outcome, especially irreversible reset/loss or multiplayer capture.

## Governance

Design docs may be merged after owner review without shipping mechanics. This continuation documentation PR is docs-only, no tests in actual Godot or deployed game were run in writing it. Any code delivery is a separate PR and release decision.
