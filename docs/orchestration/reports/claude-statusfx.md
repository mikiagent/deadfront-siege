# STATUSFX: status effects shown on the survivor (Claude)

Branch `claude/mmo-statusfx`, cut from `claude/mmo-overhaul` at 91c69e6c. Not merged or pushed.

Owner's words (2026-10-28): "status effects should appear next to the player as a box with the effect
symbol inside (bleed is a claw mark, red color, and then there's some kind of particle effect or
overlay, and it shows red negative numbers for the bleed tick damage)".

## What shipped

- **Boxes beside her**, from `game/scripts/ui/status_fx.gd`, drawn by `HuntHud`. Each active status gets a
  square box, 10 px from her figure rect. The first box sits at her shoulders and the others stack
  down. Boxes are 42 px on desktop and 32 px at 844x390. Each has an ink fill, a 2 px rim in the
  status colour, its white icon, a 4 px time-left bar and a stack-count disc. The column stays on one
  side until that side is blocked, slides off `taken_rects`, and is skipped when there is no room. It
  is added to `drawn_blocks` (`statusfx`), so toasts keep off it. When the box above one ends, the box
  below glides up into its place.
- **The claw icon** (`claw.svg`) is drawn by the new module `_src/icons_n.py`, registered in `build.py`.
  Its `.import` file copies the house settings. `ui_icons.json` maps `bleed` and `claw` to it, so the
  HUD chip row shows the claw too. `deep_bleed` keeps its three drops, and the creature-side
  `bleeding_target` keeps the old drop.
- **Data**: each status in `statuses.json` now has an `fx` block with `body` (the old string hint),
  `color`, `icon`, `particles` and `vignette`. `StatusDef` parses these into `fx_color`, `fx_icon`,
  `fx_particles` and `fx_vignette`; a bare string still parses. A new status needs only data.
  `statuses.json` was re-serialised with indent 2, which only reflows the one-line `well_rested` row.
- **VFX**: each status with a particle preset gets one CPUParticles3D under the player, with at most 3
  emitters and 8-10 unshaded spheres each. It is freed the frame the status ends.
  - Bleed shows red drips, venom and poisoned show green bubbles, and hot_food shows embers.
  - "tint" statuses draw a faint colour glow over her figure.
  - Bleed and deep bleed draw a red screen-edge vignette (alpha 0.16) that brightens to 0.42 on each
    tick and fades back.
- **Tick numbers**: `StatusEffects` emits a new signal, `ticked(id, amount)`, on each damage-over-time
  tick that hits the player. `amount` is the Health actually lost, measured before and after
  `take_damage`.
  - `HudEventState.add_tick` floats a red 16 px "-N" (hits use 22 px) on the hit numbers' path. It pops
    in from 70 % size, rises and fades.
  - Fractions show one decimal: a 3-stack bleed shows "-0.5" per 0.5 s tick, a 1-stack bleed "-0.2".
  - Two ticks on the same frame stand side by side.
- **Capture hook**: when `--shot=` contains `statusfx`, she gets a 3-stack bleed; with `poison` also in
  the path, she also gets venom.
- No stun or hurt logic was changed. `_on_vitals_damaged` and `take_damage` are untouched; the only
  change in `_dot` is the measurement and the signal.

## Gates

- `t_statusfx` (new) PASS, 110 checks, at 844x390 and 1600x900. It checks that:
  - every status has a valid fx block, and bleed has the claw icon, drips, a vignette and a red colour;
  - the box is within 24 px of her figure, level with her, on screen, clear of every taken rect and of
    her figure;
  - each of three ticks adds exactly one red number that equals the Health lost and is smaller than
    22 px, and pulses the vignette;
  - bleed and venom boxes stack without overlap;
  - boxes, particles and the vignette are gone once treated.
- t_uiicons PASS (it regenerates all 128 SVGs byte for byte with `build.py --check`), and t_ui,
  t_fieldhud, t_player, t_combat, t_foodfx and t_rest PASS, each with 0 SCRIPT ERRORs.
- `tools/smoke.sh --no-import` printed SMOKE PASS.
- run_all printed `[tests] PASS` with 6 SCRIPT ERRORs, all of which the base branch also logs: the
  TouchControls compile-order errors and the deliberate econ-fault errors.

## Captures (`docs/orchestration/reports/statusfx/`)

The PNGs were palette-quantised to stay under 300 KB.

| File | What it shows |
|---|---|
| `before_844.png` | The same spot at 844x390 with no status |
| `statusfx_bleed_844.png` | Bleeding on a phone |
| `statusfx_poison_844.png` | Bleeding and poisoned on a phone |
| `statusfx_bleed_1600.png` | 1600x900, cropped 800x450 around her |
| `statusfx_poison_1600_crop.png` | Both boxes, drips and bubbles at 1600x900 |

What I changed after looking at the captures:
- The first drips were invisible: 3 cm spheres, an alpha fade and emission inside her torso. They are
  now opaque 6 cm spheres that shrink out, emitted from 0.3 m out.
- The vignette read orange over grass, so it now uses the family red with green and blue cut.
- The boxes were small, so they went from 34 to 42 px on desktop.
- The stack count covered the icon, so it moved to a disc outside the box.
- Bleed and venom ticks on the same frame printed on top of each other, so the second number now
  stands beside the first.

## Assumptions (`# ASSUMPTION` / data)

- Palette: bleed red (LIFE `#d8503a`), poison and sickness green `#8fd14f`, hot orange `#e8962a`, wet
  and cold blue (ENERGY), positive buffs GOLD, Well Rested soft gold `#f0d78c`, other negatives MUTED
  grey.
- No burn status exists, so embers are given to hot_food.
- Positive buffs get no particles, only the box.
- The vignette strength is set by eye; no doc gives one.
- Tick numbers show the real fractional damage per tick ("-0.2") rather than summing ticks into whole
  points.
- All damage-over-time numbers are red, including poison.

## Risks and notes for the next agent

- The column is placed against her `figure_rect`, which is as wide as her nameplate. With a long name,
  the boxes sit further out.
- When the survivor walks right next to a HUD block, the column can flip sides or slide.
- A tick shows "-0.2" four times every 2 s for a light bleed. If the owner wants whole numbers,
  accumulate in `StatusFx._on_tick` the way `HudRestBox` does.
- `taken_rects()` is now built twice per HUD frame: once for the boxes, then again as before.
- One 844x390 capture was taken with `--rendering-method gl_compatibility`, the web renderer. The drips,
  bubbles, boxes and numbers all render. That run also logged "Too many instances using shader instance
  variables" (4096 limit). The new particle materials use no instance uniforms, so the error most likely
  comes from elsewhere, but I did not check whether the base branch logs it too.
