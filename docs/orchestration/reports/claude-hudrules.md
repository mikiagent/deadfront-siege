# HUDRULES — status split, chip tooltips, stomach ring, orders in combat, collapsible orders

Branch `claude/mmo-hudrules` (from `claude/mmo-overhaul`), worktree `.claude/worktrees/mmo-hudrules`.

Owner rules (2026-10-28, verbatim in the task):
1. Status effects only on the player; under the health bar only buffs, boons, debuffs, with hover/click/tap tooltips.
2. A circular stomach indicator right of the health bar.
3. Orders hide in combat unless the fight fulfils them.
4. DoT numbers take the colour of the status causing them; no green negative status (poison purple).
5. Orders collapsible into the minimap.
6. Orders auto-expand while you work on them.

## What shipped

- **Status kinds** (`game/data/statuses.json`): every status has `kind` and a short factual `desc`;
  `StatusDef.kind`, `desc` and `is_modifier()`. `StatusFx` draws boxes for `kind: effect` only
  (`StatusFx.effects`). Particles and tints still follow `fx`, so Hot Food (a buff) still shows embers.
- **Chip row** (`game/scripts/ui/hud_buff_row.gd`, new): the modifier statuses, then the food buffs
  (`BuffSlots` rows). Each chip has a tooltip with name, BUFF/BOON/DEBUFF, the food buff's stats, the
  `desc` and time left. Hover shows it, a click pins/unpins it, a tap toggles it (the emulated mouse
  press is ignored). It is placed on a free spot off `taken_rects`, as block `buff_tip`. On a compact
  canvas each chip's touch area is 64x64; where neighbours overlap, the nearest chip wins.
- **Stomach ring** (`game/scripts/ui/hud_stomach.gd`, new): right of the HP and energy bars, as tall as
  both. GOLD, LIFE under 25 %, with a white stomach glyph (`game/assets/icons/ui/_src/icons_p.py` →
  `stomach.svg`, `ui_icons.json` "stomach"). The bars are 44 / 36 px shorter; the face row and the
  treadmill keep the full width.
- **Orders in combat**: an optional `fight` list in `objectives.json` (meat `"*"`, tame
  `zebraceratops`, volcano_raid `tyrannosaurus`) and `OrdersSheet.served_by_fight`. In combat, the card
  and the badge hide unless the fight serves the shown order. On a landscape phone the target plate owns
  the centre band, so a serving order draws as a 40 px strip under the chip row.
- **Collapsible orders** (`game/scripts/ui/hud_orders_badge.gd`, new): collapsed by default to a badge
  over the minimap's top-left corner (`notice` glyph and "i/n"). The minimap's own draw paints it, since
  the map control draws over the HUD. A tap on the badge expands the card; a tap on the card collapses
  it. The state lives for the session only (`OrdersSheet.hud_expanded`): there is no UI-settings store,
  and the save format is off-limits. A changed order flashes the badge GOLD for 2.4 s.
- **Auto-expand**: the shown order's fill is polled every 0.25 s. A rise, or a fight that serves the
  order, expands the card for 4 s after the last progress. A manual collapse inside that window keeps it
  collapsed until the window runs out (`HuntHud.orders_tap`, `_tick_orders_auto`).
- **Colours**: `UiTokens.HEAL` (green, healing only) and `UiTokens.POISON` (#a36bd9). Venom, poisoned,
  poisoned_target, infected_wound and stomachache are now purple, which covers the box rim, the bubbles
  and the tick numbers. The creature venom tint (`creature.gd`) and the plate "V" chips
  (`creature_plates.gd`) use POISON too. A DoT tick number takes its status's `fx_color`
  (`StatusFx._on_tick`).
- **Capture hook**: `--shot=` paths containing `hudrules` run `HudrulesShot.stage` (`game/scripts/dev/`).
  It skips character creation on a fresh profile, then applies bleed, Well Rested, a stew buff and a
  digesting meal. Other words in the path add more: `expanded` opens the card, `tip` pins the Well Rested
  tooltip, and `combat` starts a fight with a deinonychus while "Hunt something for meat" is the order.
- Docs: `docs/current/hud.md`, `docs/current/survival-needs.md`, and six owner rules added to
  `docs/design/ui-redesign-spec.md` §11.

## Round 2: after merging canon `04016b23`

- `t_targetui` failed after the canon merge, so I updated its phone assert to the collapsed-orders rule.
  With only a selection there is no plate and no card, and the minimap badge shows. Once the player
  expands the orders, the card takes the band, and the test checks that it overlaps no other drawn block.
- The mounted energy bar is segmented and darker blue (owner). The new tokens are
  `UiTokens.PLAYER_ENERGY` and `UiTokens.MOUNT_ENERGY`, and `MOUNT_ENERGY_SEGMENTS` is 10 (ASSUMPTION:
  a tick every 10 %). `_bar` draws 2 px dark gaps between segments, and HuntHud records
  `energy_bar_color` and `energy_bar_segments`. `t_energy` asserts that riding draws the bar in
  MOUNT_ENERGY with 10 segments, that MOUNT_ENERGY is a darker shade of the player's blue, and that on
  foot the bar is PLAYER_ENERGY with no segments. The amber mounted bar is gone.
- Capture hook: `mounted` in the shot path summons a zebraceratops and mounts it.

Round 2 gates, after the canon merge and import:
- PASS with 0 SCRIPT ERRORs: t_targetui, t_energy, t_mounts, t_hudrules, t_ui, t_fieldhud, t_statusfx,
  t_uigather, t_rest, t_foodfx.
- PASS with the base branch's own errors: t_uiicons (2), t_uinav (1), and run_all `[tests] PASS` (6).
- `tools/smoke.sh --no-import`: SMOKE PASS.

## Status kind mapping (ASSUMPTION)

| kind | statuses |
|---|---|
| effect (box beside her) | bleed, deep_bleed, venom, fracture, pinned, deafened, infected_wound, bleeding_target, groggy, knockdown, snared, poisoned_target, dizziness, enraged, poisoned |
| debuff | wet, full, stomachache ("Stomach Pain"), tastes_bad, dirty, very_dirty, thirsty, tastes_horrible, tastes_disgusting |
| boon (care / rest) | well_rested, clean, quenched |
| buff (food / drink) | caffeinated, tastes_great, tastes_delicious, hot_food, cold_food, vigor, every BuffSlots food buff (e.g. Dutch Coffee: Maximum Fatigue) |

## Other assumptions

- The stomach ring's fill: no satiety meter exists (the PRD forbids one), so the ring shows the share of
  eaten Energy still digesting (`Digestion` rows, remaining / total). It is empty when nothing is
  digesting, including at the start of a game and after foods with no spec-32 bundle (dried and smoked
  outputs). It only reads values; no hunger rule changed.
- `fight: ["*"]` on "Hunt something for meat": any animal fight serves it.
- No shipped order says "kill N deinonychus". The deinonychus capture uses the meat order, which any
  fight serves.
- The auto-expand window is 4 s. "Progress" means the shown order's fill rose. Gathering a node that
  has not paid out yet does not count until the first unit lands.
- The badge count is the order's number out of the total ("8/28"), the same as the card header.

## Gates

- `t_hudrules` (new) PASS, 164 checks at 844x390 and 1600x900, 0 SCRIPT ERRORs. It checks that:
  - every status has a kind and a desc, no negative status is green-hued, and the poison family is
    exactly POISON;
  - bleed gives a world box and no chip, while Well Rested and a food buff give chips and no box;
  - the tooltip opens on hover, on a click (pinned) and on a tap, closes on toggle, and sits on screen
    and off every taken rect;
  - chip and badge touch areas are 64 px or more on 844x390;
  - the stomach ring tracks 1.0, 0.75, 0.25 and 0 of the digesting meal, sits inside the vitals at the
    right, level with the HP bar, and is at least 28 px;
  - orders start collapsed, the badge reads the order number, and a tap or click toggles it;
  - combat hides the card against a non-matching creature and auto-expands it against a matching one
    (zebraceratops for the tame order, deinonychus for meat "*"), then collapses 4 s after progress
    stops;
  - gathering a branch auto-expands the card, and a manual collapse sticks for the activity;
  - each DoT tick number (bleed, venom, poisoned, stomachache) is its fx colour.
- t_ui, t_fieldhud, t_statusfx, t_uigather, t_rest and t_foodfx PASS with 0 SCRIPT ERRORs.
- t_uinav PASS with 1 SCRIPT ERROR and t_uiicons PASS with 2 (`build.py --check` drew 130 of 130). The
  base branch's merge-gate logs show exactly the same errors.
- run_all `[tests] PASS` with 6 SCRIPT ERRORs, the same count as the base merge gate.
- `tools/smoke.sh --no-import`: SMOKE PASS.

## Captures (`docs/orchestration/reports/hudrules/`, posterised to 4 bits a channel to stay under 300 KB)

| File | What it shows |
|---|---|
| `collapsed_1600_top.png` | 1600x900, top 300 px scaled to 1200: bleed box beside her only; Well Rested and stew chips under the vitals; stomach ring; the orders badge "1/28" on the minimap |
| `expanded_tip_1600_top.png` | Same, card expanded, the Well Rested tooltip pinned |
| `combat_1600_crop.png` | 1600x900 top 480 px: fighting a deinonychus, "Hunt something for meat" stays up |
| `collapsed_tip_844.png` | 844x390: collapsed badge, Well Rested tooltip open |
| `expanded_844.png` | 844x390: card expanded left of the minimap |
| `mounted_1600_top.png` / `mounted_844.png` | Riding a zebraceratops: the energy bar is the mount's, segmented and darker blue |
| `onfoot_1600_top.png` / `onfoot_844.png` | The same scene on foot: the player's own blue, no segments |
| `combat_844.png` | 844x390 combat vs a deinonychus: the plate takes the band, the order draws as the strip under the chips |

What I changed after looking at the captures:
- The minimap control painted over a badge the HUD drew, so the badge is now drawn by the minimap's draw signal.
- At 844x390 the order card covered the target plate, which led to the strip.
- The tooltip found no free spot at 844, so it now tries several x positions and is 210 px wide on compact canvases.

## Risks

- On a compact canvas the chip touch areas (64x64) overlap their 30 px neighbours. The nearest chip
  wins, so each chip's own region is about 30x64.
- The badge's 64 px touch area on a phone covers the minimap's top-left edge. A tap there toggles orders
  instead of opening the map.
- A manually expanded card on a landscape phone still yields the band to the plate or the level-up
  banner, as before, and shows the badge in the meantime.
- In the 1600 combat capture a creature status ("Groggy") shows on the target plate; that is the
  creature's, unchanged.
- On desktop the stomach ring shortens the bars to 188 px, so the mount's name no longer fits beside its
  numbers ("106 / 106" only). The existing fallback handles it; the segmented darker blue still marks the
  mount. In the captures the mount's energy is full: it was set to 64 % at mount time but refilled before
  the shot.
- Credits spent: none.
