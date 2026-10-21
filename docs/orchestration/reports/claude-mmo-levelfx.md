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
- `dbb1dd57` hold times (6 s / 4 s), lab drain waits for queued level-ups, report draft
- `48dce70f` final gates, shots and numbers (round 0)
- `4ba39907` **fix round 1**: the four review findings, their checks in t_levelfx, mounted shots in levelfx_lab, hooks patch
- the last commit: this report updated for fix round 1

Credits spent: none (no Meshy, no Tripo). No audio.

## Fix round 1 (review findings)

All four findings were real. Each one is fixed and has a check that fails on the round-0 code. **The checks fail on the old
code**: in a throwaway tree at `48dce70f` with the round-0 hooks patch and only the final `t_levelfx.gd` copied in, it exits
1 with 9 FAILs (log `/private/tmp/claude-501/-Users-milankinzy-Documents-deadfront-siege/72cebc8b-d241-430b-9ea6-94d65339bfef/scratchpad/levelfx/r1/t_old_final.log`). On the new code it prints `[t_levelfx] PASS` (54 ok lines; the gate run `gates5/t_levelfx.log` too).

| # | Finding | Fix | Check (t_levelfx) | Old code | New code |
|---|---|---|---|---|---|
| 1 major | Desktop skill banner at the top centre: pickup toasts and notices re-place around it every frame, so they jumped 52-60 px as it started and ended. Camp pills were hidden too. | On the desktop the skill banner now takes the character stack's slot, under the vitals at the top left (same column layout: the hex icon over the ink plate). Toasts, notices and the target plate stay in the top-centre column, so nothing re-places when it starts or ends. The phone was not affected, and on the phone the toasts stack on the left. | `_test_toasts`, 1600x900: a toast and a notice while a processing level-up starts, a second toast while it ends. 4.2 s, 823-825 frame pairs: no toast or notice may move more than its own rise (35 px/s), and none may sit under the banner. | FAIL, worst 35.69 px beyond the rise (toast at 3.26 s, the banner ending) | ok, 0.00 px, 0 frames under the banner |
| 2 minor | Phone: a target plate appearing under a showing banner. The banner glided down across the plate's name and bar for about 0.17 s, and its height snapped from 100 to 84 px. | Pushed down by a plate (or changing form), the block moves under the plate at once and fades back in over `replace_in_s` (0.2 s). It never crosses the plate, and the height change happens while it is invisible. When the plate leaves, it still glides up, and its height eases too (largest step 11 px of 124). | `_test_phone`, 844x390, for the character banner and the skill tile: the plate is set mid-watch. No frame has the banner across the plate. Every move over 40 px happens while the fade-back-in is under 0.15. When the plate leaves, the banner is back where it stood and, for the character banner, took several frames. | FAIL, 11 overlap frames each | ok, 0 overlaps; the 124 px re-place happens only while faded |
| 3 minor | Phone: every skill level-up hid the quest card for 2.2-3.3 s, so the card blinked while gathering. | A skill level-up keeps the quest card. It takes the band's free part left of the card as a tile: the hex icon over the category over its gold level, 94x100 px at 844x390, beside the card as in the gather reference. A character level-up still takes the whole band. If that part is narrower than `tile_min_px` (64), the skill banner takes the whole band as before. `HuntHud` asks `LevelUpCelebration.hides_quest(band, quest_rect)` before it draws the card. | `_test_phone`: card drawn in 87 of 87 frames of a skill level-up, banner drawn, 0 overlaps. Card drawn in 0 frames of a character level-up. | FAIL, card in 0 of 88 frames | ok |
| 4 minor | Riding the T. rex, the light stood at the mount's root, inside and behind its body. The rider got no light. Dismounting mid-way left the light on the mount. | Riding, the light is still a child of the mount's root (no bone jitter), but it stands where she sits: her model root on the saddle, 6.9 m up a T. rex, held in the mount's frame. Its ground rings stay on the ground under her and spread wider with the saddle height (`mount.ring_per_m` 0.1/m, so x1.7 on the T. rex), so they show past the mount's feet, where the camera looks. Mounting or dismounting mid-way moves the light to the new anchor the next frame. | `_test_mounted`: on the saddle (y 6.88, seat 6.89 m); rings 0.2 m over the mount's feet; within 0.41 m of her during the saddle's bob, 0.000 m moved on the mount; dismount mid-way puts it at her feet (parent Player, y -1.00). | FAIL, 3 checks: at the mount's feet (y 0.00, seat 6.88 m), 8.48 m from her; parent Creature after the dismount | ok |

Evidence that I looked, and what I tried first for #4: scaling the whole light by the rider's height (clamped at 3x) buried
the T. rex in a 4 m pillar and a 10 m ring that filled the screen, and the rays quad clipped the ground in a hard line
(`/private/tmp/claude-501/-Users-milankinzy-Documents-deadfront-siege/72cebc8b-d241-430b-9ea6-94d65339bfef/scratchpad/levelfx/fix1/1600x900_fwd/mounted_char_night_peak_1600x900.png`). The saddle placement with the rings on the ground is in
`/private/tmp/claude-501/-Users-milankinzy-Documents-deadfront-siege/72cebc8b-d241-430b-9ea6-94d65339bfef/scratchpad/levelfx/final2/*/mounted_char_{day,night}_{peak,mid}_*.png`. Known limit: riding a big mount, the camera frames the mount's
feet, so the rider and most of her pillar sit at the top edge of the view. The rings, and the OmniLight on the mount's back,
carry the effect there. Camera framing for big mounts belongs to the camera package.

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
| `game/scripts/fx/level_up_fx.gd` (`LevelUpFx`) | The light at the survivor's feet. **Character**: a gold pillar of light that rises from the ground in 0.42 s, two ground rings spreading to 3.4 m and 2.3 m, a slowly turning 14-ray burst behind her, a short flash on her, 44 rising sparkles, and a shadowless OmniLight (energy 7, range 7.5 m) that flares and fades in about 1.2 s. It lasts 2.0 s. **Skill**: one ring to 2 m, 18 sparkles, and a light of energy 3 and range 4.5 m, lasting 1.6 s. It is one-shot and frees itself. It is a child of the survivor, so it rides her interpolated transform. While she rides, it is a child of the mount's root instead, because `Player.mount` hangs her from a saddle bone, which bobs with the mount's animation. Since fix round 1 it stands where she sits on the saddle, held in the mount's frame, with its rings left on the ground and spread wider by the saddle height. Mounting or dismounting mid-way moves it. Nothing in it touches the camera. |
| `game/scripts/fx/level_up_fx.gdshader` | One additive, unshaded shader with four shapes: the pillar tube (soft at the silhouette, dimmer across the middle so the survivor stays readable), the ring, the ray burst and the glow disc. The rays and the flash are pushed along the view axis: the rays sit behind her and the flash sits in front. Additive meshes plus a real light, because gl_compatibility (the web build) has far weaker post glow than Forward+. |
| `game/scripts/ui/level_up_celebration.gd` (`LevelUpCelebration`) | The HUD side, a queue. One level-up shows at a time. A character level goes ahead of waiting categories. A waiting entry of the same kind and category is replaced by the newer one, so one grant worth two character levels shows the last level once. The showing one holds 6 s, or 4 s when others wait (skill: 2.8 s, or 1.7 s), then fades over 0.45 s. The next one also waits for the last light to end, so two lights never play at once. **Desktop character**: "LEVEL UP", then the level pops in (it grows from 0.2 to 1.24 and settles to 1), over a warm glow, a lens streak and a short turning ray fan. The reward lines slide 14 px in from the left, one by one. The badge on the vitals pulses gold three times, with rings. **Phone character**: the old centre-band banner, same layout, now with the pop, a gold edge glow, a sweep and a glow kept inside the box. **Skill**: the category's hex icon (the white UI icon, gold rim) pops under a flare, with "Skill Category Level Up" and "Processing Lv. N" on an ink plate. Since fix round 1 it sits under the vitals on the desktop, the character stack's slot, off the toast and notice column. On a phone it is a tile beside the quest card: the icon over the category over its level. It takes the whole band only when that part is under 64 px. A target plate that appears under a phone banner moves it below the plate at once, and it fades back in there; when the plate leaves, it glides back up. The `shown(kind, level, tree)` signal is the audio hook. Nothing plays a sound yet. |
| `game/data/level_fx.json` | Every colour, timing, size, count and energy above, marked as ASSUMPTION values. |
| `game/tests/t_levelfx.gd` | The acceptance test (see Gates). |
| `game/scripts/dev/levelfx_lab.gd`, `game/scenes/dev/levelfx_lab.tscn` | Shots and frame sequences (see Motion, Cost). |

Hooks in files other packages own ship as `docs/orchestration/reports/claude-mmo-levelfx-hooks.patch` (4 files, 45+/52-).
They are not committed on the branch. The work tree has them applied, and every gate below ran with them applied:

- `hunt_hud.gd`: `_levelup_t` is gone. `_levelups := LevelUpCelebration.new()` takes its place. `bind()` connects
  `SkillState.level_up` to it. `_on_level_up` pushes the character level-up and adds "(+N)" to the SP line, the SP this
  level paid. `_process` ticks the queue. `_draw` draws the badge pulse and the celebration, which records its
  `drawn_blocks["levelup"]` rect as before. Fix round 1: `quest_rect(r, mp)` is split out of `_draw_quest` (same
  geometry), the card is skipped only when `_levelups.hides_quest(band, quest_rect(r, mp))`, and `draw()` also gets the
  card's drawn rect. The file is 6 lines shorter than the base (+26/-32).
- `hud_layout.gd`: `draw_levelup_banner` is removed (moved into LevelUpCelebration).
- `skill_state.gd`: a new `signal level_up(tree, level)`, emitted only in `_resolve` (an XP level). It does not fire on
  unlocks, refunds or the occupation head start.
- `ui_real_capture_lab.gd`: the level-up is checked as it pops and again once settled. A new `skill_levelup` screen is
  checked and shot. `_levelup_t` resets became `_levelups.clear()`. The PASS line lists `skill_levelup` and keeps
  HUD-DAYNIGHT's `hud_daynight`.

`git apply --cached --check` of the fix-round patch passes on `claude/mmo-overhaul` acc684a6, the head now. It changed only
docs since 946da955, and the 4 files are identical there and on this branch. `mkscratch.sh levelfx-gates 4ba39907 <patch>`
printed "Applied patch ... cleanly" for all 4 files. The work tree's diff of the 4 files equals the patch byte for byte.

## Before and after (look)

Shots, windowed, from levelfx_lab on the home island beside the camp. Each is taken at the effect's peak (0.5 s) and
mid-way (1.1 s), by day (0.45) and by night (0.93):

- BEFORE (base 1eb5cafd = ddaab662 + lab): `/private/tmp/claude-501/-Users-milankinzy-Documents-deadfront-siege/72cebc8b-d241-430b-9ea6-94d65339bfef/scratchpad/levelfx/shots/before/{1600x900_fwd,1600x900_glc,844x390_glc}/{char,skill}_{day,night}_{peak,mid}_<w>x<h>.png`
- AFTER, fix round 1 (4ba39907 + hooks, the final code): `.../scratchpad/levelfx/final2/{1600x900_fwd,1600x900_glc,844x390_glc}/...`
  (same names, plus `mounted_char_{day,night}_{peak,mid}`; the skill shots now have a gather's "+2 fiber" toast on screen).
  Contact sheets: `.../levelfx/final2/sheet_<config>.png`. Real-UI gate shots: `.../levelfx/uireal6/{1600x900_glc,844x390_glc}/`.
  I opened all of them. Desktop skill: the banner is under the vitals; the toast, Workbench and Cargo Warp pills stay at the
  top centre. Phone skill: the tile sits between the vitals and the quest card, and the card stays (as in the gather
  reference). Mounted: two bright rings around the T. rex's feet, and the light on the rider at the top edge of the view.
  Character shots: unchanged from round 0.
- AFTER, round 0 (dbb1dd57 + hooks): `.../scratchpad/levelfx/final/{1600x900_fwd,1600x900_glc,844x390_glc}/...` (same names).
  An earlier AFTER set (d7da2009 + hooks) is in `.../levelfx/shots/after/`; the last commit changed only hold times, so the
  0.5 s and 1.1 s frames match.
- Real-UI gate shots: `.../scratchpad/levelfx/uireal5/{1600x900_glc,844x390_glc}/{levelup,skill_levelup,busy_levelup}_<w>x<h>.png`

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
| burst (one grant: 2 character levels, gathering, survival), 10 s | 1202 frames; order `character:7, skill:survival:7, skill:gathering:7`; max 1 light alive; block jump 0.00 px; camera offset 0; camera jerk 0.00 m/s; light off her feet 0.0000 m | 1327 frames, same order and values | 1342 frames, same order and values |
| level-up while walking 14 m (1.5 s) | light off her feet max 0.0000 m; camera shake offset 0.0000; HUD block jump 0.00 px | same | same |
| camera velocity jerk, walk without vs with a level-up | 0.21 vs 49.64 m/s | 25.34 vs 23.78 m/s | 16.07 vs 30.15 m/s |

These are the final runs (dbb1dd57 + hooks, logs `final_{fwd,glc,phone}.log`). The last row is reported, not gated: it is
the camera's per-frame step divided by that frame's delta, so one late frame spikes it, with or without a level-up (the calm
gl_compatibility walk scores 25 m/s on its own). The Forward+ 49.64 is one such frame: that run hit a 62 ms frame as a
level-up started and a 58 ms frame while idle, with the machine at load average 13 (other agents' Godot runs). Six dedicated
Forward+ samples (`--cost-only --disable-vsync`, twice) never went over 10.04 ms on a level-up frame (see Cost), and an earlier
Forward+ run scored 0.22 vs 0.21 m/s. The level-up adds no camera
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
| final runs, vsync: 844x390 gl_compat / 1600x900 gl_compat / 1600x900 Forward+ | 9.67 (14.80) / 8.19 (14.86) / 8.91 (58.33) ms | 9.50 (14.77) / 9.25 (14.54) / 8.86 (61.68) ms | 3.77/3.83, 3.16/3.52, 0.38/0.34 ms | 265/294, 266/295, 279/308 |
| 1600x900 Forward+, `--disable-vsync --cost-only`, 6 samples (cost_fwd_{1,2}.log) | 8.33-8.35 ms (max 9.67) | 8.32-8.34 ms (max 10.04) | 0.29-0.32 / 0.30-0.34 ms | 254-262 / 285-291 (294) |

There are about 29 more draw calls while it plays. The only frames over 25 ms were the two in the final Forward+ run (58 ms
idle, 62 ms level-up), taken under load; none of the six dedicated Forward+ samples or any gl_compatibility run had one. **Found and fixed on the way**: the first
build gave every level-up a fresh `StandardMaterial3D` for its sparkles. Godot frees a BaseMaterial3D's generated shader with
the last material that uses it, so every level-up recompiled it: one 118-131 ms frame per level-up on gl_compatibility
(`--cost-only`, 3 of 3 samples). The sparkle quad and its material are now built once per session (`LevelUpFx._spark_mesh`),
and an invisible two-frame warm-up copy plays when the HUD first ticks, so the session's first level-up compiles nothing
either. t_levelfx checks that a later level-up reuses the same quad. GPU time is not reported: Godot returns 0 for it on this
Mac's gl_compatibility.

## Gates

Fix round 1, all on the final code (4ba39907) with the hooks applied. Headless gates: `mkscratch.sh levelfx-gates 4ba39907
docs/orchestration/reports/claude-mmo-levelfx-hooks.patch` ("Applied patch ... cleanly" for all 4 files, `--import` done),
logs in `/private/tmp/claude-501/-Users-milankinzy-Documents-deadfront-siege/72cebc8b-d241-430b-9ea6-94d65339bfef/scratchpad/levelfx/gates5/`. Windowed gates: this work tree at 4ba39907, whose uncommitted diff equals the hooks patch, logs
`/private/tmp/claude-501/-Users-milankinzy-Documents-deadfront-siege/72cebc8b-d241-430b-9ea6-94d65339bfef/scratchpad/levelfx/uireal6/{desk,phone}.log` and `/private/tmp/claude-501/-Users-milankinzy-Documents-deadfront-siege/72cebc8b-d241-430b-9ea6-94d65339bfef/scratchpad/levelfx/final2/{fwd,glc,phone}.log`. (Round 0 ran the same gates on dbb1dd57: logs
`gates4/`, `uireal5_*`, `final_*`.)

| Gate | Result |
|---|---|
| every `game/tests/t_*.gd` (24 files) | 24 of 24 exit 0 and print PASS; 0 SCRIPT ERROR except t_save's 5 deliberate ones |
| `run_all.gd` | exit 0, `[tests] PASS`, 0 SCRIPT ERROR |
| `tools/smoke.sh --no-import` | exit 0, `SMOKE PASS` |
| `ui_real_capture_lab` 1600x900 gl_compat | exit 0, `[uireal] PASS screens=hud,hud_daynight,craft,skills,atlas,radial,sheet_menu,sheet_build,levelup,skill_levelup,pet_out,plate,plate_front,combat,camp_bonfire,station_bonfire,camp_workbench,station_workbench,busy,busy_levelup,bag,charcreate,resize_other,resize_back shot_only=animals`, 0 SCRIPT ERROR |
| `ui_real_capture_lab` 844x390 gl_compat | exit 0, same PASS line, 0 SCRIPT ERROR |
| `levelfx_lab` 1600x900 Forward+, 1600x900 gl_compat, 844x390 gl_compat | each `[levelfx] PASS shots=12`, exit 0, 0 SCRIPT ERROR; burst order `character:9, skill:survival:9, skill:gathering:9`, max 1 light, block jump 0.00 px, camera offset 0 in all three |
| `git apply --cached --check` of the hooks patch on `claude/mmo-overhaul` acc684a6 (its head now) | clean |

Frame cost after fix round 1, 844x390 gl_compatibility, `--cost-only --disable-vsync`, 2 runs x 3 samples, run one at a
time (`/private/tmp/claude-501/-Users-milankinzy-Documents-deadfront-siege/72cebc8b-d241-430b-9ea6-94d65339bfef/scratchpad/levelfx/fix1_cost_phone_{1,2}.log`): idle 5.52-8.34 ms, level-up 6.68-9.07 ms (max 15.54); render CPU 2.49-3.83 /
2.95-4.04 ms; draw calls 244-255 idle / 271-283 level-up; no frame over 25 ms in any sample. The vsync'd lab runs, three
windows at once under load average 12, saw single 47-140 ms frames on gl_compatibility in idle and level-up alike. Those are
load, not the effect: the dedicated samples have none.

t_levelfx (54 checks, `[t_levelfx] PASS`; round 0 had 37, the fix-round ones are in the table at the top):

- character level-up: one light, kind character, a child of the survivor at her feet (y -1.00); pillar, rings, rays and flash
  (5 meshes); a shadowless OmniLight of at most 8 m; 44 sparkles (budget 64); life 2.0 s from level_fx.json; the HUD shows
  `character:4`; the light flares (peak 7.0); it frees itself (survivor children 19 before and after); the HUD block is drawn
  for 334 frames and moves 0.00 px; camera offset 0, trauma 0, camera moved 0.0000 m
- skill level-up: survival rises a level; one light, kind skill, a ring and no pillar; 18 < 44 sparkles; the HUD shows
  `skill:survival:2`; a weaker light (3.0 < 7.0); it frees itself; the banner is drawn 276 frames and moves 0.00 px; no shake
- burst: one gathering grant gives two character levels and gathering levels, with survival banked at its cap; queued as
  `character::6`, `skill:survival:6`, `skill:gathering:6` (merged); shown in that order; max 1 light; 0 early starts; 0.00 px;
  camera still; the second character light reuses the first one's sparkle quad; everything ends on its own
- mounted: riding the T. rex (saddle path), the light is a child of the mount, standing on the saddle with her, its rings on
  the ground; dismounting mid-way moves it to her feet
- the occupation's head start celebrates nothing

**The test fails on the old code** (round 0, against the base; for fix round 1 see the top): in a throwaway tree at claude/mmo-overhaul 809be2e8, with only the new `t_levelfx.gd`
copied in, it exits 1: `FAIL the HUD holds a level-up queue (_levelups)`, `FAIL character level-up: one light effect (got 0)`,
`FAIL skill level-up: one light effect (got 0)`, `FAIL mounted: a level-up while riding plays one light, on the mount (0,
parent none)`, `FAIL count=4`. levelfx_lab on the base fails too: no light on either level-up, no skill celebration, and
the burst shows only `character:7`.

## Assumptions (marked `# ASSUMPTION:` in code)

1. The look of the light (gold pillar, rings, rays, sparkles, flash, OmniLight) is mine. The references show only the HUD side.
2. Queue rules: one level-up at a time, a character level first, the newest of a kind replacing a waiting one, a shorter hold
   while others wait (6 s / 4 s character, 2.8 s / 1.7 s skill). The references show one banner; the PRDs are silent.
3. The skill banner sits under the vitals on the desktop, where the character stack sits. The gather reference has it at
   the top centre, but our toasts and notices live there. On a phone it is a tile beside the quest card, or takes the whole
   band when the part beside the card is under 64 px.
4. Every number in `level_fx.json`.
5. The SP line reads "Available Skill Points: 30 (+10)", with the SP this level paid (`SkillState.sp_for_level`) in brackets.
6. Riding, the light stands on the saddle and its rings stay on the ground, spread by 0.1 per metre of saddle height. A
   plate that pushes a phone banner down moves it at once and fades it back in over 0.2 s.

## For the next agent

- Audio: connect to `HuntHud._levelups.shown(kind, level, tree)`. It fires once per level-up as it starts to show.
- A future crit, rare-find or unlock moment can reuse `LevelUpFx` with a new section in `level_fx.json` (the parts are built
  from whichever keys a section has) and `LevelUpCelebration._flare` / `_pop` for the HUD.
- Levelling while dead: the celebration still shows and no light spawns (`not p.dead`).
- Riding a big mount, the camera frames the mount's feet, so the rider and her light sit at the top edge of the view (the
  T. rex saddle is 6.9 m up). Framing the rider is a camera-package job; the ground rings carry the effect meanwhile.
- HUD label pills (Workbench, Cargo Warp) give way to every HUD block. Under the phone's skill tile (band x 320-414) a pill
  there steps aside while it shows, as pills do for the character stack.
- Not checked: landscape phones under 720 px wide (667x375). There `HudLayout.centre_band` is empty (the vitals panel
  runs to the minimap), so both level-ups use the desktop slot under the vitals, where compact toasts also stack. The
  character stack did this in the base too. Phones between 720 and about 814 px wide have under 64 px beside the quest
  card, so a skill level-up takes the whole band and hides the card there, as in round 0.
- Not covered: a level-up indoors under a roof (the pillar may poke through a roof; occlusion is another package), and a
  level-up while the survivor is in a SubViewport preview (none exists).
- levelfx_lab: `Godot --path game --resolution 1600x900 [--rendering-method gl_compatibility] -- --lab=levelfx_lab --shot-dir=DIR`
  (also 844x390); `--cost-only` (add `--disable-vsync`) prints three idle-vs-level-up frame samples only.
