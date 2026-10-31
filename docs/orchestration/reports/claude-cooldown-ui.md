# Combat ability cooldown UI (claude/mmo-cooldown-ui)

Owner ask (2026-10-31): "The combat UI should reflect the cooldown amounts similar to harvesting a
resource (circular, going clockwise) put the timer countdown in the button if possible", for
abilities like kick and tackle.

## What shipped

- `HexButton.set_ability(left, total, lock)` (game/scripts/ui/hex_button.gd) is the single entry
  point for every ability hex. While cooling down it draws the harvest pie (`UiTokens.pie_points`,
  the same call and colour as the gather radial's `fill_ratio`), filling clockwise from the top
  until the ability is ready. The seconds left, rounded up, sit in the middle at about 0.85 of the
  hex radius (around 29 logical px on a 72 px hex) with a dark outline, over a faint icon.
- A `lock` reason greys the hex, adds a red lock badge (the existing `lock` UI icon) and replaces
  the caption with one red word. These are `WINDED` (no_attack, tackle and kick only), `STAMINA`
  (energy below the move's cost) and `DOWN` (knockdown / cannot_act).
- The old 16-slice grey dial for `HexButton.cooldown` is gone. Nothing set that field, so it was
  never drawn.
- `HuntHud` (game/scripts/ui/hunt_hud.gd, `_process`) drives tackle, kick and roll through
  `set_ability`, with totals from combat_tuning.json (`tackle.cooldown`, `kick.cooldown`) and
  `RollRules.cooldown_s()`. The new static `HuntHud.ability_lock(player, stamina, attack)` picks the
  lock reason. In siege mode the tackle hex (TOXIN) keeps its old catapult-reload disable.
- Sizes and layout are unchanged: skill hexes stay at 72 px and HudLayout still places them inside
  the safe area.
- Lab: `game/scripts/dev/cooldown_ui_lab.gd` (+ scenes/dev/cooldown_ui_lab.tscn) kicks a frozen
  zebraceratops and saves six frames.

## Gates (merged head, after merging origin/claude/mmo-overhaul at 92dcbc45)

- run_all: `[tests] PASS`. The new `_test_ability_cooldown_hex` checks the sweep fraction, the
  rounded-up seconds and the disabled state at 6.0 / 2.3 / 0 s left, that the pie runs clockwise,
  and the lock badge and caption.
- `tools/smoke.sh --no-import`: SMOKE PASS.

## Screenshots (844x390 at 2x, windowed off-screen, `-- --skip-charcreate`)

docs/orchestration/reports/cooldown-ui/: 1_kick_just_used (6), 2_kick_mid_cooldown (3, pie ~57 %),
3_kick_ready, 4_lock_winded, 5_lock_no_stamina, 6_lock_knockdown.

Fixed after the first look: "NO STAMINA" and "KNOCKED DOWN" captions ran into each other across
the three hexes, so they became STAMINA and DOWN.

One run's mid-cooldown frame showed the World Atlas instead of the HUD. No code in the merge
touches it, and a rerun was clean. The likeliest cause is a stray click on the minimap of the
off-screen window.

## Assumptions / for the next agent

- ASSUMPTION: the lock words (WINDED / STAMINA / DOWN) are mine; the PRD does not name them.
- Net has no cooldown (`Hunt._net_cd` is never set), so it keeps its gold/disabled logic.
- Credits spent: 0.

Run the lab: `Godot --path game --position 6000,3000 --resolution 1688x780 -- --skip-charcreate --lab=cooldown_ui_lab --shot-dir=DIR`
