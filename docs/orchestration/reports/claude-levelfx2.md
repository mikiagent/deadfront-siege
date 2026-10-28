# claude-levelfx2: LEVELFX re-applied on canon, plus the top-middle feed (2026-10-28)

Branch `claude/mmo-levelfx2`, cut from `claude/mmo-overhaul` 2ceaf4e0. Canon (072bcb84, BRAINICON) was merged in at 11b4c21b.
I did not merge the stale `claude/mmo-levelfx` branch (1115 commits behind). I copied in its new files (`fx/level_up_fx.gd` + shader, `level_up_celebration.gd`,
`level_fx.json`, `t_levelfx.gd`, `levelfx_lab`) and wrote the hooks again against the current HUD. No credits were spent and no audio was added.

## What shipped

- **Light at the survivor** (ported unchanged apart from a 0.1 s delta clamp): a gold pillar, rings, rays, sparkles and a shadowless OmniLight
  for a character level-up, and a small ring and light for a skill level-up. While she rides, it stands on the saddle and its rings stay on the ground.
- **Wiring**: canon's `SkillState.skill_leveled` (it fires on XP level-ups only, not on unlocks or the occupation head start) drives
  `LevelUpCelebration.push_skill`. `World.pioneer_changed` drives `push_character`. `skill_changed` keeps its pulse recount.
- **Pulse** (replaces the old Skills hex halo): each level-up that shows pulses the MENU hex (gold rim, glow, rings off its badge corner) for about 2.7 s.
  With the nav menu open, rings also spread off the Skills entry's badge (`NavMenu._draw_root`, redrawn every frame while the pulse runs).
- **Skill points use the brain glyph** (coordinator / BRAINICON): the desktop stack's row reads "[brain] 50 (+10)". The phone banner ends with
  "· [brain] 40". `_levelup_sp` was added. The asserts in t_ui and t_w2_skills now check the brain row and the number instead of the words.
- **Character stack at the far left** (owner: "move this UI to the far left please"): x = vitals + 16 (24 px at 1600x900), centred in the
  height between the vitals and the quick slots (y 230–642 at 1600x900). The status chips and the XP feed under the vitals are drawn after it and keep off it.
  Phones keep the centre-band banner, because 390 px leaves no room for a left column of 13 lines (ASSUMPTION).
- **TopFeed, the top-middle column** (`game/scripts/ui/top_feed.gd`; owner: skill level-ups top middle, gathering in the same UI with
  grey/yellow/green tiers):
  - Skill category level-ups are a row here (hex icon under the flare, "Skill Category Level Up", "<Cat> Lv. N").
    LevelUpCelebration still keeps the clock and the light.
  - Every gain is a row: art in the lot colour, name, "+n" and trait chips. It **retires the per-node yield card**; `yield_card.gd` keeps only
    the chip helpers and the left XP feed. A repeat of a showing item collapses into its row ("+3" then "+2" Stone gives one "+5" row).
    At most 3 rows show (2 on a phone); the rest wait, with a skill row first. New rows go under the ones showing, so rows only move up, and they ease there.
  - Tier rule, in `level_fx.json` "gain" (ASSUMPTION mapping):
    - green: a chip whose polarity is `rare` (the green pip), or a `flawless` attribute, or a rare find;
    - yellow: a `positive` chip;
    - grey: everything else.
  - The animation scales with the tier:
    - grey: small pop, 2.2 s;
    - yellow: bigger pop, gold edge, halo and 12 sparks, 3 s;
    - green: biggest pop, halo, a 14-ray sunburst and 26 sparks, 4 s.
  - The loot colours are their own (grey / gold / emerald) and never reuse the status colours.
  - Sound hook: `TopFeed.shown(kind, tier, id)`.
  - Rare-find lines: with a real HUD, `GatherFeedback.show_yield` and `announce_rares` call `HuntHud.feed_rare`, which lifts the row to green
    (or adds a green "Rare find" row for carcass parts). They no longer draw a stack by the node, so a gain gets one popup.
    A bare HUD (t_gather's stub) keeps the old stack and notice path, so those tests run unchanged.
  - Placement: on the desktop the column is centred under the vitals' bottom (y 112), below the domain banner and the target plate.
    On a phone it sits under the centre band, centred on the band's part left of the day/night dial, as 236 px one-line rows.
    The pop is capped at 1.06 there.

Files I touched that other packages own: `hunt_hud.gd`, `hud_layout.gd` (the old banner removed), `nav_menu.gd` (the pulse rings),
`gather_feedback.gd` (routing), `yield_card.gd` (the card retired), `ui_real_capture_lab.gd`, `uigather_lab.gd`, t_ui, t_w2_skills, t_uigather.
I did not touch creature AI.

## Gates (final code; logs in my scratchpad `lf/g/`)

| Gate | Result |
|---|---|
| t_levelfx (ported; the new checks are the neighbours at both sizes, the MENU/Skills pulse, TopFeed tiers/collapse/cap/rare routing/top-middle at both sizes, and the far-left stack with nothing under it) | `[t_levelfx] PASS` |
| t_ui, t_uiicons, t_fieldhud, t_uinav, t_uigather, t_statusfx, t_skillfeel, t_mounts, t_w2_skills, t_gather | all PASS, exit 0 |
| run_all | `[tests] PASS` |
| `tools/smoke.sh --no-import` | `SMOKE PASS` |
| levelfx_lab windowed: 1600x900 Forward+, 1600x900 gl_compatibility, 844x390 gl_compatibility | PASS shots=15 (Forward+, gl_compat 1600). The phone run's last pass failed one after-shot check on a stalled frame; that check is now made during the wait (see Risks) |
| ui_real_capture_lab 1600/844 gl_compat | `levelup`, `levelup_settled` and `skill_levelup` checks pass. The lab still FAILs on canon's own drift: atlas card count, bag columns, "3 toasts" (the yield card counted as one toast), a phone 11 pt atlas label, and a plate/AUTO overlap. None of these involve LEVELFX. Not fixed here |

## Shots (`docs/orchestration/reports/levelfx2/`, each ≤ 300 KB, palette-reduced)

- `levelup_foot_1600x900.png`: a character level-up at night, Forward+. Pillar and rings on her, and the far-left stack with the brain row.
- `levelup_mounted_1600x900_and_844x390.png`: riding the T. rex, desktop on top and phone below. The rings are under the mount and the phone banner is in the band.
- `skill_topmiddle_1600x900_and_844x390.png`: a skill level-up row at the top middle under a gain row, desktop and phone.
- `gain_tiers_1600x900_glcompat.png`: grey Stone, yellow Branch (Firm), green Fibre Stalk (Split Easily) with its sunburst and sparks, gl_compatibility.
- `gain_tiers_844x390.png`: the same three tiers on the phone.

What I saw: the level-up reads big and gold, and its light ends in 2 s. The stack holds about 6 s at the left edge, off the play area.
The green row bursts clearly, the yellow one glows a little and the grey one only pops. On the phone a row fits the 38 px strip between the band and her head.
A second phone row, or a skill row under a gain row, drops below her nameplate (y about 226), between HANDS and ATTACK.

## Frame cost (levelfx_lab `--cost`, windowed, vsync, machine shared with other agents)

| Run | idle frame | level-up frame (max) | render CPU idle → level-up | draws idle → level-up |
|---|---|---|---|---|
| 1600x900 Forward+ | 8.89 ms | 8.62 ms (19.25) | 0.36 → 0.44 ms | 322 → 366 |
| 1600x900 gl_compat | 9.03 ms | 10.56 ms (25.44, one 25 ms frame) | 3.43 → 3.98 ms | 326 → 373 |
| 844x390 gl_compat | 8.34 ms | 8.97 ms (25.0) | 3.10 → 3.33 ms | 310 → 352 |

A level-up adds about 45 draw calls and 0.1–0.5 ms of render CPU. TopFeed is canvas drawing (rects, a few polygons and dots) and was not timed on its own.

## Assumptions (marked in code)

1. The tier rule and every TopFeed number in `level_fx.json` "gain" (rows 3/2, widths 380/236, lives 2.2/3/4 s, the loot colours).
2. The desktop character stack sits at the far left, centred between the vitals and the quick slots. Phones keep the band banner.
3. Each level-up shown pulses the MENU hex and the Skills entry badge for ~2.7 s.
4. Phone TopFeed rows are one line (the best chip only).
5. The lab's earlier assumptions still hold (look of the light, queue rules, hold times).

## Risks / for the next agent

- **Windowed labs stall on this machine.** Frames took seconds of real time (once 35 s while the lab counted 0.6 s), so banners ended before their shots.
  I clamp the HUD and light deltas to 0.1 s (a hitch no longer skips a celebration), and the lab now checks the HUD during the wait and times shots on the celebration's clock.
  `--always-on-top` helps. One phone-lab run still failed one check before that last fix, and I did not re-run it after the fix.
- On a phone, a second TopFeed row lands below her nameplate. It stays off every taken rect but sits nearer the action. At 1280x720 the far-left stack may reach the status chips, which are drawn before it; I did not check that size.
- t_uinav prints one SCRIPT ERROR (a freed NavMenu read at t_uinav.gd:132) but passes. It looks like the test's own flow, not LEVELFX; I did not check it on canon.
- The old `claude/mmo-levelfx` branch is superseded; nothing from it needs merging.
- Not pushed and not merged. `game/override.cfg` is kept (custom user dir `deadfront-mmo-levelfx2`).
