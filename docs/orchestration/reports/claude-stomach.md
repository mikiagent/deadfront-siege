# HUDRULES round 3: the stomach indicator

Branch `claude/mmo-stomach`, cut from canon `claude/mmo-overhaul` (`b82c729e`). Worktree `.claude/worktrees/mmo-stomach`.

Owner, verbatim:
- "it should be a circular bar where green is red is too full stomach, green is full, yellow is hungry,
  and red (again) is empty stomach. The stomach icon should change depending on hunger. Saturation is a
  yellow circular bar outside that is like a cooldown until you start getting hungry again"
- "make it so the stomach UI degrades clockwise, full is a green circle. stomach symbol should change to
  different states empty stomach looks shrunk, full stomach looks big"

## What shipped

- **Inner ring: fullness** (`game/scripts/ui/hud_stomach.gd`).
  - Full is a complete circle. It degrades clockwise: the lit arc always ends at 12 o'clock, and the gap
    opens clockwise from 12 o'clock (`HudStomach.arc_for`).
  - Colour comes from `STOPS`, blended between them: red when empty (0 to 0.1), yellow when hungry (0.3
    to 0.5), green when full (0.8 to 1.0), red when overfull (from 1.2). An empty stomach shows a faint
    red track, so the empty state is still red when there is nothing left to fill.
  - State thresholds: under 0.1 empty, under 0.4 hungry, under 0.7 normal, up to 1.0 full, above 1.0
    overfull.
- **Outer ring: saturation.** A thin yellow ring separated from the inner ring by a dark gap, since both
  can be yellow. It reads the digestion timer the food system already has: the longest digestion row's
  time left (remaining / rate) over its digest seconds. It is full on a fresh meal, drains clockwise like
  the inner ring, and is empty when nothing digests.
- **Glyph by state.** `game/assets/icons/ui/_src/icons_p.py` draws four variants through `build.py`:
  - `stomach_empty`: thin walls at 0.55, scaled to 0.8;
  - `stomach_hungry`: walls at 0.68, scaled to 0.86;
  - `stomach`: the full, round stomach, also used for the normal state;
  - `stomach_overfull`: swollen walls plus two pressure marks beside the gullet, fitted to the 6-58 live
    area.

  All four share the full stomach's optical centre, so the glyph does not jump between states. The
  variants are registered in `ui_icons.json`.

  On top of that, HuntHud eases the drawn scale toward `GLYPH_SCALE` (empty 0.92, hungry 0.95, normal
  0.98, full 1.0, overfull 1.06) at 0.6 per second. A state change therefore visibly grows or shrinks the
  glyph, and normal reads as a slightly smaller full stomach. The current values are in
  `stomach_glyph_scale`, `stomach_state`, `stomach_fill` and `stomach_saturation`.

  I tried a fifth, half-full drawing for "normal", but t_uiicons rejected it: at 24 px it had the same
  silhouette as its neighbours (IoU 0.85). A thinner "empty" also failed that test's ink-weight check
  (0.46 of the median). Both are fixed by the shapes above.
- **Tokens** (`game/scripts/ui/ui_tokens.gd`): `STOMACH_FULL` (green), `STOMACH_HUNGRY` (yellow),
  `STOMACH_EMPTY` and `STOMACH_OVERFULL` (LIFE red), and `SATURATION` (yellow). The comment there records
  that this green is the owner-sanctioned exception to "green = healing".
- **Capture hook:** a `--shot=` path containing `stomach_<state>` digests roasts that put the ring in that
  state (`game/scripts/dev/hudrules_shot.gd`).
- **Docs:** `docs/current/hud.md`, `docs/current/survival-needs.md`, and a §11 owner rule in
  `docs/design/ui-redesign-spec.md`.

## Assumptions

- **No satiety meter exists** (the PRD forbids one), and nothing in this build drives a Hungry status.
  Fullness is therefore the sum over digesting meals of the food's foods.json `fullness` times the share
  of its Energy still undigested, divided by the fullness cap (`defaults.caps.fullness`, 100). A roast is
  50, so two fresh roasts make a full stomach and three make it overfull. A digesting food with no
  `fullness` entry counts as 10.
- **Band edges and colour stops are mine.** The data names no hungry or full threshold.
- **Saturation is the digestion timer.** This means fullness also falls during saturation; the model has
  no separate "hunger starts after" phase.
- The `full` status (the eating gate) does not drive the overfull band. Overfull means more food is
  digesting than the fullness cap.

## Gates

- `t_hudrules` PASS, 0 SCRIPT ERRORs. The stomach checks:
  - fullness, state and saturation for each state, against exact values: empty, one fresh roast at 0.5
    (normal), 45, 30 and 6 of 60 left, two roasts (full), three (overfull);
  - saturation equals the digestion time left;
  - the band colours: red at 0 and 0.05, yellow at 0.4, green at 0.9, red at 1.3, and a yellow-to-green
    blend at 0.65;
  - a distinct glyph for empty, hungry, full and overfull, with normal drawing the full glyph smaller;
  - `arc_for` lights exactly fraction × TAU and always ends at 12 o'clock, with its start moving clockwise
    as the stomach empties (at 75 % the gap runs from 12 to 3 o'clock);
  - the eased glyph scale reaches `GLYPH_SCALE` for each state;
  - the ring sits inside the vitals and off every other taken rect at both sizes.
- t_foodfx, t_rest, t_ui, t_fieldhud, t_levelfx, t_statusfx, t_energy and t_targetui PASS, 0 SCRIPT ERRORs.
- t_uiicons PASS (133 of 133 regenerated byte for byte, IoU worst 0.80, weight 0.60 to 1.44) with the
  base branch's own 2 errors.
- run_all `[tests] PASS` with 6 SCRIPT ERRORs, the same count as the base.
- `tools/smoke.sh --no-import`: SMOKE PASS.

## Captures (`docs/orchestration/reports/stomach/`; I looked at them)

| File | What it shows |
|---|---|
| `states_1600.png` | The vitals at 1600x900, one row per state (empty, hungry, normal, full, overfull), scaled 2x |
| `states_844.png` | The same at 844x390 |
| `hungry_844_full.png` | The whole 844x390 HUD while hungry: a quarter of the inner ring lit from 9 to 12 o'clock, half the saturation ring |
| `overfull_1600_top.png` | 1600x900, top 300 px scaled to 1200: overfull, a red complete circle with the swollen glyph |

Reading the rows: empty has a faint red track and the small, thin glyph, with no saturation. Hungry lights
the inner ring from 9 to 12 o'clock in yellow, with half the outer ring. Normal lights the left half in
yellow over a full outer ring. Full is a complete green circle. Overfull is a complete red circle with the
swollen glyph.

## Risks

- Hungry and saturation are both yellow. Only the ring weight and the dark gap tell them apart, and on a
  30 px phone ring that is subtle.
- Fullness falls while the meal digests, so the "cooldown before hunger starts" is not a separate phase
  in this model.
- Captures run in a real window, so they briefly open on the owner's screen.
- Credits spent: none.
