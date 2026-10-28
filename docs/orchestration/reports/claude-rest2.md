# claude-rest2: REST landed on the integration line

Branch `claude/mmo-rest2`, cut from `claude/mmo-overhaul` at 6d5ee484. Not pushed, not merged into mmo-overhaul.
Owner bug: "Resting should sit you down and heal you and lower exhaustion. It didn't work on Vercel."
Credits spent: none. No Meshy, Tripo or Codex.

## What canon already had (read from code and tests at 6d5ee484)

- **Sleep only at bedding**: `PlayerSim.start_sleep` (tents, straw rolls, log shelter, cabin bed). Since then
  canon added walk-to-bed ("Sleep from anywhere": routes to a bedding beyond `SLEEP_REACH` 2.2 m) and the gradual
  drain (88d5e97a: exhaustion eases linearly across the sleep, an interrupted sleep keeps what it paid).
- **No Rest action.** No `rest` InputMap action, no Rest hex, no `rest.json`, nothing that sat her down. The only
  "rest" in canon was a roll refusal string. Sleep still healed nothing beyond passive 0.8 HP/s.
- **A status tick still ended a sleep**: `Player._on_vitals_damaged` called `interrupt_sleep()` on every damage,
  including Stomachache/Bleed ticks.
- NEEDS (eat, drink, wash, fill, dry off, feed pets) and the exhaustion treadmill (6fe26d41) do not overlap REST;
  the treadmill now also shows rest's fatigue drop for free.

So most of REST still applied. I used `git merge claude/mmo-rest` (new files only: RestState, rest.json, the icon,
HudRestBox, t_rest, rest_lab) and `git apply --3way` of `claude-mmo-rest-hooks.patch`, resolving conflicts by hand.

## What landed

Commits: `c06d7f28` (merge + hooks), `083b8816` (pre-merge fixes), `9bbfbf8c` (old-save fixture test),
`2bb05c24` (docs), and this report.

Conflict resolutions (`c06d7f28`):
- Icons: canon's `icons_k.py` is Ride/Rename (PETRADIAL). REST's rest drawing moves to `icons_l.py`, added to
  `build.py` MODULES/SOLID. `rest.svg` is unchanged.
- Input: `rest: [KEY_X]` beside canon's `gather_nearest: [KEY_SPACE]`.
- Save: `"resting"` beside FOODFX's `foodfx` block; load calls `rest.load_saved()` after FOODFX.
- **One rest/sleep system**: canon's gradual drain stays the only exhaustion change while asleep. REST's sleep hook
  called `rest.recover(&"shelter")` (Health + fatigue); it now calls `RestState.heal(&"shelter")` (Health only),
  so canon's sleep numbers are untouched. The chip's sleep fatigue line reads the sleep's own drain
  (`PlayerSim.sleep_fatigue_per_min()`, e.g. "-600 fatigue/min" at a tent). `interrupt_sleep` keeps canon's
  `_sleep_pending` clear and also stops a rest.
- HUD: canon moved the status row under the vitals (left), so REST's Claim-hex offset is gone; the rates pill goes
  right under the chips, or under the SAVEFIX max-HP note when it shows.
- t_rest: the tent spot moves from 1.9 m to 1.6 m (`TENT_M`) so canon's 2.2 m lie-down reach is met in place.

## Pre-merge fixes (`083b8816`)

| Review item | Fix | Check |
|---|---|---|
| One upright seated pose everywhere (open-ground pose read as a knockdown) | `PlayerAnim._ensure_sit_clip()` builds a one-key looping "sit" clip at runtime: hips and legs from `sleep_down` at 1.05 s (knees up), spine/head/arms from `idle`, the three spine bones turned in shares until hips→head is vertical. `sleep_down` blends into it at 0.8 s (0.4 s blend); stand-up blends into `sleep_up` at 0.68 s; Sleep-from-sit blends into `sleep_down` at 1.05 s. Same clip at every place. | t_rest `_expect_upright` at open, fire, shelter, shelter+dirty: torso lean 2.1°, hips 0.29 m, head 0.88 m, lowest hand 0.17 m, feet 0.16 m. rest_lab `--trace`: largest hips step 5.7 cm/frame sitting, 4.5 cm standing (no step ≥ 10 cm). |
| Nameplate off the torso | `HudLayout.nameplate_anchor()`: the capsule centre lowered by the visual's sink, so seated/lying the name hangs at the ground and glides with the grounding tween. Also applies to canon sleep (same visual sink). | t_rest: anchor -0.05 m vs hips 0.29 m above ground |
| Readable rest pill | `HudRestBox.draw` is a rounded `UiTokens.panel_style` pill at `UiTokens.body` size (14 px compact, 16 desktop), fitted to its text, max 280 px; was meta-size text in a square box 154 px wide. | t_rest: pill 157x76 at body 16 px, three lines, ≤ 280 px; still right under the chip row |
| Visible recovery feedback | `HudRestBox.tick` (from `HuntHud._process`) adds a "+N HP" (green) and "-N fatigue" (teal) float over her each second a whole point was gained while resting or sleeping (`HudEventState.add_float`; damage floats unchanged). | t_rest: both floats seen within 6 s by the fire |

Found while running rest_lab on the merged tree: with canon's walk-to-bed, a Stomachache tick on the way cleared
`_sleep_pending`, so Sleep from 2.2 m with a Stomachache never lay down. `Player._on_vitals_damaged` now also
ignores ticks while `_sleep_pending` is set. t_rest checks it (fails without the fix: `pending=<null>`).

## Save format (flagged)

**New key `player.resting` (bool).** Old saves have no key and load standing with their own vitals. Fixture test:
t_rest loads the frozen `tests/fixtures/save_v3_golden.json` (no `resting`) after sitting her down:
`an old save without the key loads standing with its vitals (resting=false hp=100.5/100.1 fat=30.01/30.00)`.
t_save PASS (its 5 deliberate SCRIPT ERRORs).

## Gates (head of `claude/mmo-rest2`, logs in `/var/folders/xw/c1xrp24n76nbnlq85qnmbfrw0000gn/T/rest_*.log`)

- import: exit 0, 0 ERROR lines.
- `t_rest`: `[t_rest] PASS` (84 ok checks, 0 SCRIPT ERROR).
- `t_needs` `[t_needs] PASS`, `t_foodfx` `[t_foodfx] PASS`, `t_ui` `[t_ui] PASS`, `t_player` `[t_player] PASS`,
  `t_save` `[t_save] PASS` (5 deliberate SCRIPT ERROR), `t_iconart` PASS, `t_water` PASS, `t_canim` PASS,
  `t_build` PASS, `t_ai` PASS, `t_targetui` PASS, `t_mapui` PASS — all 0 SCRIPT ERROR except t_save.
- `t_uiicons`: FAIL, the known base failures only (food statuses caffeinated, tastes_*, hot_food, cold_food have no
  icon). No rest line fails; the rest chip keeps hunt_hud at two `HudStatusChip.draw(` rows.
- `tools/smoke.sh --no-import`: `SMOKE PASS`.
- `run_all.gd`: `[tests] PASS`, 3 SCRIPT ERROR (the known compile-order TouchControls ones).
- `rest_lab -- --secs=12 --trace` headless: exit 0, 0 SCRIPT ERROR; all seven trials seated/asleep as expected,
  tent_sleep_sick now sleeps (it did not before the tick fix).
- t_mounts not run (known base failure, not touched).

## Assumptions (unchanged from REST unless marked)

- `rest.json` rates open 0.3 / fire 2.0 / shelter 3.0 HP/s, -6 / -15 / -30 fatigue/min; reach 3.0 m fire, 3.2 m
  shelter; fatigue recovery divided by statuses' `fatigue_mult`. All `# ASSUMPTION`, not retuned.
- NEW: asleep, Health rises at the shelter rest rate; exhaustion only by canon's drain.
- NEW: the sit pose is built from two clips (no authored sit clip exists).
- NEW: recovery floats every 1 s, whole points only.
- Desktop key X; no gamepad binding.

## Needs an on-screen look (headless only this session; no screenshots taken)

1. The built sit pose: bone metrics say upright, but arms come from idle on a tipped pelvis; check hands don't
   clip the thighs and the lower-back curve reads naturally, at 844x390 and desktop.
2. The 0.8 s blend from `sleep_down` into the sit and the stand-up blend (trace shows no jumps; eye check).
3. The pill's placement at 844x390 with pet whistle hexes visible and with the max-HP note.
4. Floats over a seated survivor (anchored at the capsule chest point, so ~1 m above her head when seated).
5. Nameplate while sleeping in a tent now hangs at ground level (follows the visual); confirm it isn't hidden by
   the tent mesh.

## Not done

Offline rest catch-up, server side of `act.rest`, comfort/furniture/temperature modifiers, an authored sit clip,
net-fatigue display — as listed in REST's report. In the t_rest scene the survivor does not move along a nav route
(even without statuses); rest_lab walks fine, so it is a test-scene quirk, not investigated.
