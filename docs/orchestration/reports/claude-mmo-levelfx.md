# claude-mmo-levelfx: light-effect level-ups (owner 2026-10-21)

Owner, verbatim: "as a rule of thumb: make it flashy. Level ups should have light effect animations. Also watch out for
glitchy movement of UI and player". References: `docs/reference/durango-levelup-loot-reference.webp` (gold "Lv. 5" and the
reward lines top left) and `durango-gather-hud-levelup.webp` (a hex icon under a flare, "Skill Category Level Up",
"Processing Lv. 4").

Branch `claude/mmo-levelfx` from `claude/mmo-overhaul` (ddaab662), merged with `claude/mmo-overhaul` 946da955
(HUD-DAYNIGHT) at 3b2abb7e. Commits:

- `1eb5cafd` levelfx_lab, the reproduction lab (committed before any game change; the BEFORE shots come from it)
- `ad911126` LevelUpFx, LevelUpCelebration, level_fx.json, t_levelfx
- `fcf89c7b` shared sparkle material, light on the mount while riding, one light at a time, character level first, hooks patch
- `3b2abb7e` merge of claude/mmo-overhaul 946da955 (HUD-DAYNIGHT touched hunt_hud.gd and ui_real_capture_lab.gd)
- `84faa60d` hooks patch regenerated on 946da955
- `d7da2009` rings lifted off bumpy ground, glow behind the level on the phone banner
- the last commit: hold times (6 s / 4 s), lab drain waits for queued level-ups, this report

Credits spent: none (no Meshy, no Tripo). No audio.

## Where level-ups happen (found first)

- Character level: `World.add_xp` (`game/scripts/core/world.gd:416`) loops and emits `World.pioneer_changed(stored)` once per
  level. Every skill XP grant also lands there (`SkillState.add_xp` mirrors it).
- Skill category level: `SkillState._resolve` (`game/scripts/skills/skill_state.gd:88`) raises a tree and emits
  `skill_changed`. `skill_changed` also fires on unlocks, refunds and the occupation's Lv. 20 head start, so it cannot mean
  "level-up". A tree is capped at the character level, and survival mirrors every grant, so a character level-up usually
  releases a banked survival level right away. `SkillState` hears `pioneer_changed` before the HUD, because the survivor is
  built before the HUD, so that survival level arrives before the character level that freed it.
- The old notice: `HuntHud._on_level_up` filled `_levelup_lines` and `_levelup_t`. The desktop drew a static gold stack top
  left for 6.5 s. The landscape phone drew `HudLayout.draw_levelup_banner` in the centre band. A skill level-up had no HUD
  notice at all. Nothing appeared in the world. A second level-up during the 6.5 s overwrote the first in place.

## What shipped

New files (mine):

| File | What |
|---|---|
| `game/scripts/fx/level_up_fx.gd` (`LevelUpFx`) | The light at the survivor's feet. **Character**: a gold pillar of light that rises from the ground in 0.42 s, two ground rings spreading to 3.4 m and 2.3 m, a slowly turning 14-ray burst behind her, a short flash on her, 44 rising sparkles, and a shadowless OmniLight (energy 7, range 7.5 m) that flares and fades in about 1.2 s. It lasts 2.0 s. **Skill**: one ring to 2 m, 18 sparkles, and a light of energy 3 and range 4.5 m, lasting 1.6 s. It is one-shot and frees itself. It is a child of the survivor, so it rides her interpolated transform. While she rides, it is a child of the mount's root instead, because `Player.mount` hangs her from a saddle bone, which bobs with the mount's animation. Nothing in it touches the camera. |
| `game/scripts/fx/level_up_fx.gdshader` | One additive, unshaded shader with four shapes: the pillar tube (soft at the silhouette, dimmer across the middle so the survivor stays readable), the ring, the ray burst and the glow disc. The rays and the flash are pushed along the view axis: the rays sit behind her and the flash sits in front. Additive meshes plus a real light, because gl_compatibility (the web build) has far weaker post glow than Forward+. |
| `game/scripts/ui/level_up_celebration.gd` (`LevelUpCelebration`) | The HUD side, a queue. One level-up shows at a time. A character level goes ahead of waiting categories. A waiting entry of the same kind and category is replaced by the newer one, so one grant worth two character levels shows the last level once. The showing one holds 6 s, or 4 s when others wait (skill: 2.8 s, or 1.7 s), then fades over 0.45 s. The next one also waits for the last light to end, so two lights never play at once. **Desktop character**: "LEVEL UP", then the level pops in (it grows from 0.2 to 1.24 and settles to 1), over a warm glow, a lens streak and a short turning ray fan. The reward lines slide 14 px in from the left, one by one. The badge on the vitals pulses gold three times, with rings. **Phone character**: the old centre-band banner, same layout, now with the pop, a gold edge glow, a sweep and a glow kept inside the box. **Skill**: the category's hex icon (the white UI icon, gold rim) pops under a flare, with "Skill Category Level Up" and "Processing Lv. N" on an ink plate. It sits at the top centre on the desktop (as in the gather reference) and in the centre band on a phone. A target plate that appears under a phone banner pushes it down with an eased glide, not a snap. The `shown(kind, level, tree)` signal is the audio hook. Nothing plays a sound yet. |
| `game/data/level_fx.json` | Every colour, timing, size, count and energy above, marked as ASSUMPTION values. |
| `game/tests/t_levelfx.gd` | The acceptance test (see Gates). |
| `game/scripts/dev/levelfx_lab.gd`, `game/scenes/dev/levelfx_lab.tscn` | Shots and frame sequences (see Motion, Cost). |

Hooks in files other packages own ship as `docs/orchestration/reports/claude-mmo-levelfx-hooks.patch` (4 files, 33+/46-).
They are not committed on the branch. The work tree has them applied, and every gate below ran with them applied:

- `hunt_hud.gd`: `_levelup_t` is gone. `_levelups := LevelUpCelebration.new()` takes its place. `bind()` connects
  `SkillState.level_up` to it. `_on_level_up` pushes the character level-up and adds "(+N)" to the SP line, the SP this
  level paid. `_process` ticks the queue. `_draw` draws the badge pulse and the celebration, which records its
  `drawn_blocks["levelup"]` rect as before. The file is 8 lines shorter.
- `hud_layout.gd`: `draw_levelup_banner` is removed (moved into LevelUpCelebration).
- `skill_state.gd`: a new `signal level_up(tree, level)`, emitted only in `_resolve` (an XP level). It does not fire on
  unlocks, refunds or the occupation head start.
- `ui_real_capture_lab.gd`: the level-up is checked as it pops and again once settled. A new `skill_levelup` screen is
  checked and shot. `_levelup_t` resets became `_levelups.clear()`. The PASS line lists `skill_levelup` and keeps
  HUD-DAYNIGHT's `hud_daynight`.

`git apply --check` of the patch passes on `claude/mmo-overhaul` 809be2e8, the head when I finished; it changed only docs
since 946da955. `mkscratch.sh levelfx-gates claude/mmo-levelfx <patch>` printed "Applied patch ... cleanly" for all 4
files.

## Before and after (look)

Shots, windowed, from levelfx_lab on the home island beside the camp. Each is taken at the effect's peak (0.5 s) and
mid-way (1.1 s), by day (0.45) and by night (0.93):

- BEFORE (base 1eb5cafd = ddaab662 + lab): `/private/tmp/claude-501/-Users-milankinzy-Documents-deadfront-siege/72cebc8b-d241-430b-9ea6-94d65339bfef/scratchpad/levelfx/shots/before/{1600x900_fwd,1600x900_glc,844x390_glc}/{char,skill}_{day,night}_{peak,mid}_<w>x<h>.png`
- AFTER (d7da2009 + hooks): `.../scratchpad/levelfx/shots/after/{1600x900_fwd,1600x900_glc,844x390_glc}/...` (same names)
- Real-UI gate shots: `.../scratchpad/levelfx/uireal3/{1600x900_glc,844x390_glc}/{levelup,skill_levelup,busy_levelup}_<w>x<h>.png`

I opened every one, next to the two references:

- **Before**: a character level-up is a static gold stack top left on the desktop and a flat ink banner on the phone. Peak
  and mid are pixel-identical apart from the clock. Nothing happens at the survivor. A skill level-up shows nothing at all:
  the peak and mid shots are the idle HUD.
- **After, character**: a gold pillar stands on the survivor from the ground to about 2.5 times her height, inside two
  bright rings, with rays fanning behind her and sparkles rising. At night the OmniLight warms the grass around her. In
  Forward+ the pillar blooms; in gl_compatibility it reads the same, slightly harder-edged. The survivor stays visible inside
  the tube. At mid the inner ring has spread and the outer one fades. Top left: "LEVEL UP" with a glowing gold "Lv. 4" and a
  streak, then the lines sliding in (Pioneer XP, T-stones, "Available Skill Points: 30 (+10)", the title, the stats). This
  is the loot reference's layout with motion and glow. The badge has a gold ring. At 844x390 the banner pops in the centre
  band and the pillar and rings stay between HANDS and the map.
- **After, skill**: a gold ring and sparkles at her feet. At the top centre, the processing hex icon sits under a flare and
  streak above "Skill Category Level Up / Processing Lv. 2" on an ink plate. This is very close to the gather reference. On
  the phone the icon sits left in the band with the two lines beside it.
- Known look differences from the reference: the reference colours only the numbers gold ("Strength **+ 5**"); ours
  colours the whole stat line gold, as the base did. The skill icon is the white UI glyph, not the reference's painted art.

## Motion (owner's glitch gate), measured

levelfx_lab records every frame:

| Sequence | 1600x900 Forward+ | 1600x900 gl_compat | 844x390 gl_compat |
|---|---|---|---|
| burst (one grant: 2 character levels, gathering, survival), 8.6 s | 1034 frames; order `character:7, skill:survival:7, skill:gathering:7`; max 1 light alive; block jump 0.00 px; camera offset 0; camera jerk 0.00 m/s | 1039 frames, same order and values | 1181 frames, same order and values |
| level-up while walking 14 m (1.5 s) | light off her feet max 0.0000 m; camera shake offset 0.0000; HUD block jump 0.00 px | same | same |
| camera velocity jerk, walk without vs with a level-up | 0.22 vs 0.21 m/s | 20.40 vs 35.48 m/s | 19.80 vs 6.60 m/s |

The last row is reported, not gated. On the windowed gl_compatibility runs the per-frame camera step follows uneven frame
pacing, and that happens with or without a level-up (the calm walk scores 20 m/s on its own). The level-up adds no camera
input: `trauma` and `h_offset`/`v_offset` stay 0 in every frame (t_levelfx checks it), and nothing in the package touches
the camera. The HUD celebration's rect comes from fixed anchors: only the pop scale and the line slide move, and the
recorded block is identical every frame while one level-up shows.

## Cost

Frame time over 90 idle frames, then the 100 frames of one character level-up. The OmniLight is shadowless with a 7.5 m
range; the meshes are 1 cylinder (24 segments, no caps) and 4 quads/planes; there are 44 CPU particles.

| Run | idle frame (max) | level-up frame (max) | render CPU idle / level-up | draw calls idle / level-up (max) |
|---|---|---|---|---|
| 844x390 gl_compat, vsync (after_phone.log) | 8.51 ms (10.54) | 9.56 ms (15.43) | 4.25 / 4.48 ms | 275 / 303 (306) |
| 844x390 gl_compat, `--disable-vsync --cost-only`, 3 samples | 8.03 / 7.95 / 5.87 ms | 7.07 / 8.43 / 6.24 ms (max 15.13) | 3.02-3.35 / 3.03-3.82 ms | 180 / 200 (263) |
| 1600x900 gl_compat (after_glc.log) | 8.69 ms (10.09) | 8.46 ms (11.73) | 3.14 / 2.98 ms | 257 / 286 (290) |
| 1600x900 Forward+ (after_fwd.log) | 8.33 ms (8.33) | 8.33 ms (8.33) | 0.31 / 0.28 ms | 278 / 306 (309) |

There are about 28 more draw calls while it plays and no frame over 25 ms in any run. **Found and fixed on the way**: the first
build gave every level-up a fresh `StandardMaterial3D` for its sparkles. Godot frees a BaseMaterial3D's generated shader with
the last material that uses it, so every level-up recompiled it: one 118-131 ms frame per level-up on gl_compatibility
(`--cost-only`, 3 of 3 samples). The sparkle quad and its material are now built once per session (`LevelUpFx._spark_mesh`),
and an invisible two-frame warm-up copy plays when the HUD first ticks, so the session's first level-up compiles nothing
either. t_levelfx checks that a later level-up reuses the same quad. GPU time is not reported: Godot returns 0 for it on this
Mac's gl_compatibility.

## Gates

All with the hooks applied, in `mkscratch.sh levelfx-gates claude/mmo-levelfx docs/orchestration/reports/claude-mmo-levelfx-hooks.patch`
(branch at d7da2009, `--import` done, 0 SCRIPT ERROR in its import log), then rerun after the last commit (see the end of
this section):

| Gate | Result |
|---|---|
| every `game/tests/t_*.gd` (23 files) | see below |
| `run_all.gd` | see below |
| `tools/smoke.sh --no-import` | see below |
| `ui_real_capture_lab` 1600x900 gl_compat | exit 0, `[uireal] PASS screens=hud,hud_daynight,craft,skills,atlas,radial,sheet_menu,sheet_build,levelup,skill_levelup,...`, 0 SCRIPT ERROR |
| `ui_real_capture_lab` 844x390 gl_compat | exit 0, `[uireal] PASS screens=hud,hud_daynight,...,levelup,skill_levelup,...,busy_levelup,...`, 0 SCRIPT ERROR |
| `levelfx_lab` 1600x900 Forward+, 1600x900 gl_compat, 844x390 gl_compat | each `[levelfx] PASS shots=8`, exit 0, 0 SCRIPT ERROR |

t_levelfx (37 checks, `[t_levelfx] PASS`):

- character level-up: one light, kind character, a child of the survivor at her feet (y -1.00); pillar, rings, rays and flash
  (5 meshes); a shadowless OmniLight of at most 8 m; 44 sparkles (budget 64); life 2.0 s from level_fx.json; the HUD shows
  `character:4`; the light flares (peak 7.0); it frees itself (survivor children 19 before and after); the HUD block is drawn
  for 334 frames and moves 0.00 px; camera offset 0, trauma 0, camera moved 0.0000 m
- skill level-up: survival rises a level; one light, kind skill, a ring and no pillar; 18 < 44 sparkles; the HUD shows
  `skill:survival:2`; a weaker light (3.0 < 7.0); it frees itself; the banner is drawn 247 frames and moves 0.00 px; no shake
- burst: one gathering grant gives two character levels and gathering levels, with survival banked at its cap; queued as
  `character::6`, `skill:survival:6`, `skill:gathering:6` (merged); shown in that order; max 1 light; 0 early starts; 0.00 px;
  camera still; the second character light reuses the first one's sparkle quad; everything ends on its own
- mounted: riding the T. rex (saddle path), the light is a child of the mount, 0.000 m off its feet the whole time
- the occupation's head start celebrates nothing

**The test fails on the old code**: in a throwaway tree at claude/mmo-overhaul 809be2e8, with only the new `t_levelfx.gd`
copied in, it exits 1: `FAIL the HUD holds a level-up queue (_levelups)`, `FAIL character level-up: one light effect (got 0)`,
`FAIL skill level-up: one light effect (got 0)`, `FAIL mounted: a level-up while riding plays one light, on the mount (0,
parent none)`, `FAIL count=4`. levelfx_lab on the base fails too: no light on either level-up, no skill celebration, and
the burst shows only `character:7`.

GATES_PLACEHOLDER

## Assumptions (marked `# ASSUMPTION:` in code)

1. The look of the light (gold pillar, rings, rays, sparkles, flash, OmniLight) is mine. The references show only the HUD side.
2. Queue rules: one level-up at a time, a character level first, the newest of a kind replacing a waiting one, a shorter hold
   while others wait (6 s / 4 s character, 2.8 s / 1.7 s skill). The references show one banner; the PRDs are silent.
3. The skill banner sits at the top centre on the desktop (gather reference) and in the centre band on a phone.
4. Every number in `level_fx.json`.
5. The SP line reads "Available Skill Points: 30 (+10)", with the SP this level paid (`SkillState.sp_for_level`) in brackets.

## For the next agent

- Audio: connect to `HuntHud._levelups.shown(kind, level, tree)`. It fires once per level-up as it starts to show.
- A future crit, rare-find or unlock moment can reuse `LevelUpFx` with a new section in `level_fx.json` (the parts are built
  from whichever keys a section has) and `LevelUpCelebration._flare` / `_pop` for the HUD.
- Levelling while dead: the celebration still shows and no light spawns (`not p.dead`).
- Not covered: a level-up indoors under a roof (the pillar may poke through a roof; occlusion is another package), and a
  level-up while the survivor is in a SubViewport preview (none exists).
- levelfx_lab: `Godot --path game --resolution 1600x900 [--rendering-method gl_compatibility] -- --lab=levelfx_lab --shot-dir=DIR`
  (also 844x390); `--cost-only` (add `--disable-vsync`) prints three idle-vs-level-up frame samples only.
