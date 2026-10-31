# CANONRED2: the 12 red tests on canon

Branch `claude/mmo-canonred2`, cut from `origin/claude/mmo-overhaul` at 432c79c9. Not merged to canon.

Eleven of the 12 failed at the start. t_claimfix passed on the first run and was not changed.
Every fix is in a test, except the `well_fed` icon, which the HUNGER dsc run had added by hand. It is
now drawn from `_src` and has the icon set's import settings. No game logic changed.

| Test | Cause | Fix |
|---|---|---|
| t_invscreens, t_uichar | KNIFESPLIT renamed the combat `stone_knife` to "Stone Dagger". | Assert "Stone Dagger". |
| t_foodcat | HUNGER (owner-approved memo, 2026-10-29) changed `fullness` to stomach points per food class, so the values are no longer the catalog's. t_hunger owns the class bands. | Every mapped food must still have a fullness. The roast must pay the `fullness` in foods.json. |
| t_eatqueue | Under HUNGER, `Digestion.schedule` no longer fills the stomach, so the overfill never happened. The single-eat section also started from a near-full stomach left by the starter meal. | Overfill with `set_fullness(OVERFULL_MAX)`. Start the single eats from an empty stomach, so the test still checks the owner's bug: the Full status must not block. |
| t_uiicons | (1) `HudStatusChip.draw_named` uses the `Data` autoload, so loading it in `_init` before the first frame failed to compile. (2) The HUNGER dsc run hand-wrote `well_fed.svg`: not from source, wrong import settings, too light, and off-centre. (3) LEVELBADGE moved both HUD chip rows to `HudBuffRow`. | (1) `await process_frame` first. (2) `well_fed` is now drawn in `_src/icons_p.py`: the stomach at 0.76 scale with a solid heart by the gullet. A heart cut out of the stomach looked the same as the plain stomach (IoU 0.96). The import file now matches the set (scale 2, mipmaps, lossless). Adding it moved the weight median up one place, which pushed `knockdown` (already 0.600 x median) below the floor, so its chevrons are 34 wide instead of 30. (3) Assert that the chip rows draw through `HudBuffRow` and that `HudBuffRow` draws `HudStatusChip.icon_for`. |
| t_uigather | At 844x390 the camera is still easing after the teleport. The node's pill anchor crosses a centre notice, and a pill over a HUD block is hidden by design. Pills also slide 5 px a frame. The test looked after 4 frames. | Wait up to 180 frames for the node's pill to settle, then tap it as before. |
| t_skillbuy | KNIFESPLIT removed the `makeshift_shovel_hoe` gate from the Stone Dagger recipe. That was weapon_tools' only Lv. 1 node, so it now gates nothing and is NOT_IN_GAME (not for sale). | A tree counts as "has levels in" only when one of its nodes at that level does something in the game. |
| t_player | AUTOABILITY is on by default and casts Tackle, then Kick, before any basic swing. The kick pushes the raptor about 1.9 m, out of reach while HOLD keeps her still, so 0 hits. The F check then swings at nothing in reach. | Turn `auto_ability` off for the HOLD-cadence and manual-F check, then turn it back on. t_autoability tests the casts. |
| t_tactical | The auto-cast kick fired during the 60-frame wait, so the manual `use_kick` was refused on cooldown. | Turn `auto_ability` off for `_test_tackle_kick`, then turn it back on. |
| t_movepriority | The auto-tackle lunge moved her more than 1 m (the "no route" baseline), and auto-casts replaced the basic swings that the damage test counts. | Turn `auto_ability` off once at setup. These checks are about move orders against the basic auto-attack. |
| t_hudredraw | It was a probe that never printed PASS, so `all_tests.sh` always marked it failed. | It prints PASS unless the idle HUD repaints more than t_fieldhud allows (6 of 60 frames). |

## Gates
- The 12 named tests: all PASS.
- `run_all.gd`: `[tests] PASS`.
- `tools/smoke.sh`: `SMOKE PASS`.
- Full `tools/all_tests.sh` (TEST_TIMEOUT=1200, JOBS=6, machine load average 7-9 from other agents):
  155 of 160 passed. I re-ran the 5 failures one at a time:
  - t_eyetrails, t_petfollow, t_ragdoll: PASS alone. They failed only under parallel load: a script-time
    budget, a settle timeout and a physics stretch.
  - t_buildspeed, t_perfgates: still red alone. home_grassland built in 2594 ms (t_buildspeed) and
    2678 ms (t_perfgates) against a 2500 ms budget, with load average still about 7. Under 6 parallel
    jobs it took 3.4 to 3.7 s. This branch changes no build code (tests and icon SVGs only), so canon
    has the same result. Either the budget sits too close to the edge on a shared machine, or a recent
    merge (TOWNPOLISH, PERF2, UNSTABLEISLES) slowed the build. Measure on an idle machine before
    deciding which.

## Assumptions / for the next agent
- `foods.json` assumption strings still say "Fullness is the catalog's". They are wrong since HUNGER, but I left the data text alone.
- The weapon_tools node "Makeshift Shovel / Hoe" gates nothing now. Gating the `hoe` recipe with it would make it for sale again, but that is a design decision (1 SP for a hoe), so it is not made here.
- The AUTOABILITY knockback interaction is untouched: while HOLD is on, an auto-kick can push the target out of reach. Whether HOLD should skip push abilities is a question for the owner (logged here, not changed).

No credits spent.
