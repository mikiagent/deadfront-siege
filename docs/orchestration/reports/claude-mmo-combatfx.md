# claude-mmo-combatfx: damage numbers (spec 24, owner correction)

First owner request: "this guy shot a bow and arrow at the stego and it critted, the crit number expands and balloons
out, max visibility". The newest owner request is the binding one: "the crit thing I think you took too literally.
Just add damage numbers, make them small and informative but make them bigger if you hit a crit or did a lot of
damage", "you want them to kind of expand out and dissipate", "you can make it float up too". So this package covers
damage numbers only. The target outline from the first reading has been dropped. Spec:
`docs/design/durango-prompts/24_crit_numbers.md`. Reference: `docs/reference/durango-crit-number.webp`.

Branch `claude/mmo-combatfx`. Commits:

- `e19bfa22`: CombatFx, `data/combat_fx.json`, `t_combatfx`, `combatfx_lab` (new files only)
- `7d8e0fad`: merge of `claude/mmo-overhaul` at 809be2e8 (HUD-DAYNIGHT, W2-DATA sync), no conflicts
- `6df377fd`: numbers stay under the HUD's fixed top blocks; the lab prints the live renderer and warms up before timing
- `7a16fbf9`: round-0 report and hooks patch
- `47b4d181`: review round 1 fixes (code, data, test, lab, regenerated hooks patch); see "Review round 1" below
- the commit with this updated report

An earlier builder run left uncommitted work in this tree, written for the first reading (balloon to 1.6x, red
outline on the target). I kept its plumbing, which sends every number to one drawer instead of the plates and the HUD.
I rewrote the drawer, the data, the test and the lab for the correction.

The call sites are in files that other packages own, so they are not committed on the branch. They ship as
`docs/orchestration/reports/claude-mmo-combatfx-hooks.patch` (11 files, 35+/132-; round 1 added `bonfire.gd` and
one line in `status_effects.gd`). The work tree has the patch
applied, and every gate below ran with it applied (`git diff` matches the patch byte for byte).
`git apply --cached --check` passes on `claude/mmo-overhaul` 809be2e8 and on its tip acc684a6 (docs-only commits
since). It also passes after `claude-mmo-targetui-hooks.patch` from the `claude/mmo-targetui` branch at 4b423f03,
because both touch `creature_plates.gd` and `hunt_hud.gd` but in different hunks. `combat_fx.gd` compiles without the patch, but nothing calls it until the
patch lands, so the branch and the patch must land together.

Credits spent: none (no Meshy, no Tripo).

## What the owner gets

- **Every hit shows a number** at the struck creature (white) or over the survivor (red). Hits on your pet are red
  too. Heals are a green `+25`, a dodged bite is a small grey `DODGE`, and each bleed tick is a small number, on a
  creature or on the survivor (deep bleed, pinned; the bonfire's cauterise shows a red `5`). Status words (BLEEDING,
  GROGGY) use the same placement so they don't print on top of the numbers; a word prints once while it is still
  up, and only next to its target. The game has no miss or block on the player's side, so there is no word for those.
- **Sizes rise with significance.** On the 1600x900 canvas a normal number is 20 px, a big hit 25 px and a crit
  30 px. A big hit is at least 10% of the target's max HP (`big_hit_frac`). Your crits are gold, bold and outlined.
  A crit you take stays red but starts at crit size. Phones use 0.9x (18/22.5/27 px at 844x390) with a 5 px outline
  (7 px on a crit). The widest a crit ever gets is 42 px on the desktop canvas, so it never covers the target.
- **Motion, as the owner described it.** A quick pop from 0.6x to 1.0x over 0.08 s. Then the number grows smoothly
  to 1.4x while its opacity falls to 0, and it rises one number-height with an ease-out. Each number lives 0.75 s.
  The test steps 45 frames at 60 fps and finds no size step over 0.015x, no height step over 0.9 px, no reversal and
  no sideways drift.
- **Rapid hits stay legible.** A new number takes the nearest on-screen spot beside its target that stays clear of
  every readable number (any target's), checked over their whole remaining paths, with 6 px between them. At
  10 hits/s no two readable numbers overlap: in the middle of the screen (furthest 170 px out), beside a target at
  either side edge or past it (the numbers fan out to the open side), and across three bodies 40 px apart. Each
  target keeps at most 8 numbers.
- **Mounted.** A mounted survivor's number sits over the rider in the saddle, not on the mount's flank.
- **Never clipped, never over the top HUD.** A number's whole path (widest swell plus full rise) is clamped inside
  the screen. It also stays below the HUD's fixed top blocks (vitals, target plate, quest, map) in its column. In
  this round's phone shots a crit high on the Stegosaurus floated over the target's `1466 / 1500`, and the clamp now
  stops that. The floor is read once when the number spawns, so a status chip that appears later cannot make it jump.
- **One drawer.** The old per-plate `Label` floats and the HUD's survivor floats are gone. Before, they stacked
  `BLEEDING` and `-34!` on top of the plate's name (`deliver/before_1600x900_glc_crit.png`). Now `CombatFx` (one
  `Control` that CreaturePlates owns, on layer 58) draws them all from `data/combat_fx.json`. Every value in that file
  is an `# ASSUMPTION` until the owner tunes it.
- **Ranged crits.** The base had no crit on a ranged hit. The hooks give the slingshot shot a crit roll
  (`ranged.crit_base` 0.08 + 0.002 per ranged level, `crit_mult` 1.75, in `combat_tuning.json`).
  `# ASSUMPTION:` the owner's bow crit implies that shots can crit. There is no bow item yet, so the lab's "bow" beats
  use the slingshot's StoneProjectile, the projectile a bow will use.
- **Fixes the hooks also carry:** a bleed tick printed twice (once from `status_effects.gd`, once from
  `Creature.on_status_tick_damage`). A creature's crit printed over the attacker instead of the survivor.
  `creature_plates.gd`'s `var hud_rects: Array[Rect2] = ... if hud else []` was a SCRIPT ERROR whenever no HUD was
  present (it showed in the test on the base).

Out of scope: crit sound, screen shake on crit, and number merging (the lanes already keep numbers readable).

## Review round 1

Six findings (1 major, 5 minor). All six are fixed, and each fix has a check. The 13 new `t_combatfx` checks all
fail on the round-0 code. I ran the new test file in a scratch tree of 7a16fbf9 with the round-0 hooks patch:
`FAIL count=13`, log `scratchpad/combatfx/r1/t_r0code.log`. Shots and zooms named `r1/...` below are in
`scratchpad/combatfx/deliver/r1/`.

| finding | what changed | check (round 1 / round 0) |
|---|---|---|
| **major**: lanes collapse at the side edges | `_free_lane` now searches in screen space. `_base` clamps the anchor's on-screen point into the screen first. It rejects spots where the number would leave [half width, view width - half width] and adds the two screen bounds as candidate spots, so next to a target at an edge the numbers fan out to the open side. `placement` adds the lane to that same clamped point. Its clamp now only catches an anchor that moved toward an edge after the spawn | `_test_edge_lanes`: 10 hits/s for 1.5 s, one crit in five, anchors at x = 0, 80, 1520, 1600, -200 and 1800 on the 1600 px test canvas. Worst frame has 0 overlapping readable pairs and 0 clipped in every case. Round 0 gives 15 / 6 / 6 / 10 / 21 / 21; the reviewer measured 15 / 6 / 6 / 10 for the first four |
| minor: lanes separate numbers on one target only | `_free_lane` blocks on every readable number on any target, using the vertical offset between the two anchors (`_reach(g, f, dy)`) | `_test_close_targets`, three anchors 40 px apart. At 10 hits/s in all: 0 overlaps, furthest 4.9 widths (112 px). At the reviewer's 10 hits/s on each: 0 overlaps, 21 readable at once. Round 0: 6 and 27 |
| minor: no number for the survivor's DoTs or the bonfire | hooks: the Player branch of `StatusEffects._dot` and `Bonfire.cauterise` call `CombatFx.pop_number` | `_test_survivor_dot`: a deep-bleed tick shows a small red `1`, cauterise a red `5`. Round 0 shows nothing for either |
| minor: status words pushed 280-300 px out, BLEEDING three times | `add_word` skips a word already live on that target. It drops a word whose nearest clear spot is more than `word_max_lane_px` (100 px x the phone scale) from its target | `_test_words`: three crits that each re-apply the bleed give 1 BLEEDING (round 0: 3). GROGGY next to a crowd of 9 numbers is dropped (round 0 placed it more than 100 px out). `r1/1600x900_glc/flurry_1600x900.png` has no far-off BLEEDING |
| minor: phone legibility | data only: `compact_scale` 0.8 -> 0.9, `outline_px` 4 -> 5, `crit_outline_px` 6 -> 7, `pad_px` 3 -> 6, `visible_alpha` 0.3 -> 0.2 | `r1/zoom_hit_844.png`: the white `19` has a clear dark edge over the pale stand-in. `r1/zoom_flurry_844.png`: `19  5  34 ... 19  19  19` read as separate numbers |
| minor (plausible): mounted number on the mount's flank | Confirmed in the code: the saddle path sets `p.position = Vector3.ZERO` on the mount's root. A mounted survivor's number now anchors on `p.rig`, which `_follow_saddle` places on the saddle | `_test_mounted` (T. rex): the number sits at 10.0 m = rider 8.0 m + 2.0 m. Round 0 put it at 3.0 m = mount root 1.0 m + 2.0 m. The rider's and the mount's numbers sit apart. Lab beat `mounted`: rider 8.3 m, number 10.3 m. Shots `r1/*/mounted_*.png` |

Trade-offs and limits:
- With the pad doubled, the furthest number in the single-target flurry moved from 155 to 170 px (4.6 to 5.1 of its
  widths). The bound in `t_combatfx` moved from 5.0 to 5.5 widths, with a comment that says why.
- At 30 hits/s on three bodies within 80 px (the reviewer's probe), numbers never overlap but spread up to 553 px
  from their target. Legibility wins over closeness there. If real fights get that dense, merging is the next step
  (marked `shortcut:` in `_free_lane`, where a full screen falls back to overprinting the nearest spot). At a
  realistic 10 hits/s in all they stay within 112 px.
- Placing one number now checks every live number, not just the target's own: at most 564 us in the single-target
  flurry and at most 1214 us with 21 live numbers, with other workflows' Godot runs going at the same time (round 0:
  204 us). The test limit is 2000 us.
- The survivor's plain bleed (0.15 HP a tick) and venom (0.2) stay under the 0.5 HP floor that keeps a `0` off the
  screen, so they still show nothing. Deep bleed (0.5) and pinned (1.0) do show.

## Gates

Round 1: all gates ran on 47b4d181 plus the hooks patch, in this work tree, on 2026-10-21, one run each.

| gate | result |
|---|---|
| every `game/tests/t_*.gd` (24 files) | exit 0, `PASS`. `t_save` prints its 5 deliberate SCRIPT ERRORs; every other file has 0 |
| `run_all.gd` | exit 0, `[tests] PASS` |
| `tools/smoke.sh` | exit 0, `SMOKE PASS` |
| combat labs: combatfx_lab (now with the `mounted` beat), hunt_lab, combat_rules_lab, capture_lab, pets_lab, pet_passthrough_lab, wild_ai_sweep_lab | exit 0, PASS, 0 SCRIPT ERROR, first run each. In round 0, `combat_rules_lab` failed its load-sensitive swing-timing check once at load average ~15 and passed on three reruns |

`t_combatfx` (47 `ok` lines in round 0, 62 in round 1) fails on the old code. Its first check, "CreaturePlates owns a CombatFx", fails there. It
checks the size ladder (normal < big < crit, from melee, the slingshot and a creature's bite) and the colours by
direction (dealt white, crit gold, taken red, pet red, heal green, dodge grey). It also checks one number per bleed
tick, the pop, swell, fade and rise curves, smoothness over 45 frames, no overlap at 10 hits/s, edges, the HUD floor,
a number over a freed creature finishing where it was, and cleanup. Mutation check for this round's floor: with
`f["floor"] = 0.0` the new case fails ("15 frames over it"), and with the fix it passes.

Logs: `/private/tmp/claude-501/-Users-milankinzy-Documents-deadfront-siege/72cebc8b-d241-430b-9ea6-94d65339bfef/scratchpad/combatfx/gates3/`
(round 1; `gates.txt` has one line per gate), `gates2/` (round 0), `r1/t_r0code.log` (the round-1 test on the round-0
code).

### Frame cost at 10 hits/s

`combatfx_lab --fx=stress`, windowed 1600x900, vsync off, 3 s phases. A warm-up phase runs first. Every hit phase
runs the whole hit path (flash, blood burst, plate), so "numbers on" minus "numbers off" is the cost of the numbers.

Round 1 (47b4d181, numbers now checked against every target's numbers), with other workflows' Godot runs holding
the other slots:

| renderer | run | no hits avg | 10 hits/s, numbers on avg / p95 | 10 hits/s, numbers off avg / p95 |
|---|---|---|---|---|
| gl_compatibility (web) | 1 | 9.02 ms | 12.26 / 18.21 ms | 14.16 / 18.59 ms |
| gl_compatibility (web) | 2 | 8.06 ms | 12.45 / 16.23 ms | 11.41 / 16.54 ms |
| Forward+ | 1 | 8.34 ms | 8.38 / 9.23 ms | 8.38 / 9.34 ms |
| Forward+ | 2 | 8.34 ms | 8.46 / 9.26 ms | 8.42 / 9.33 ms |

On minus off is -1.90 and +1.04 ms in gl_compatibility and 0.00 and +0.04 ms in Forward+, so the cost is still
inside the run-to-run noise. The warm-up phase again had the gl_compatibility first-hit hitch (130 and 145 ms), which
belongs to the hit effects (below). Logs: `scratchpad/combatfx/stress3_*.log`.

Round 0:

| renderer | run | no hits avg | 10 hits/s, numbers on avg / p95 | 10 hits/s, numbers off avg / p95 |
|---|---|---|---|---|
| gl_compatibility (web) | 1 | 8.96 ms | 12.37 / 16.04 ms | 11.82 / 15.59 ms |
| gl_compatibility (web) | 2 | 8.44 ms | 11.65 / 16.10 ms | 12.11 / 16.03 ms |
| Forward+ | 1 | 8.34 ms | 8.37 / 9.31 ms | 8.42 / 9.30 ms |
| Forward+ | 2 | 8.33 ms | 8.36 / 9.32 ms | 8.35 / 9.12 ms |

The numbers cost about as much as the run-to-run noise (+0.55 ms and -0.46 ms in gl_compatibility). In the test, placing one
number took at most 204 us. The first run, which had no warm-up, showed +2.5 ms and one 143 ms frame in
gl_compatibility. I traced that frame to the first hits: the base code with the hooks reversed and no CombatFx at all
has the same 142 ms frame on its first hits. So it is the hit effects' first-use cost in gl_compatibility, and the
numbers do not cause it. The hit FX owner should look at it, because the web build will hitch on the first hit of a
session. Logs: `scratchpad/combatfx/stress2_*.log`.

## Shots

Folder: `/private/tmp/claude-501/-Users-milankinzy-Documents-deadfront-siege/72cebc8b-d241-430b-9ea6-94d65339bfef/scratchpad/combatfx/deliver/`

Round 1 shots are in `deliver/r1/{1600x900_glc,1600x900_fwd,844x390_glc,844x390_fwd}/`: 15 per run (hit, big,
crit, bow, bow_crit, taken, taken_crit, flurry, seq_030 to seq_650, mounted). All 4 windowed runs exited 0 with
0 SCRIPT ERROR. I opened them next to the reference, and the main ones look like this:
- `crit_1600x900.png` (glc): a gold `34` above the Stegosaurus and BLEEDING beside it. `seq_500` shows it later in
  its life, larger and fading. `hit_1600x900.png` (fwd): a small white `19` between the plates.
- `flurry_1600x900.png`: `19 19 19 3 19` and a fading gold `34`, evenly spaced, with no BLEEDING far from the body
  (round 0 printed three).
- `flurry_844x390.png` and its zoom: `19 5 34 19 19 19` are separate numbers that sit beside the day/night dial, not
  on it. A number that has faded under 0.2 opacity can still sit under a new one. `hit_844x390.png` and its zoom: the
  white `19` reads over the pale stand-in body.
- `mounted_1600x900.png`: a red `420` over the rider on the T. rex saddle and the mount's red `40` on its body.
  `mounted_844x390.png`: `368` and `40` side by side. On the phone, the HUD floor keeps the rider's number under the
  target plate, so it sits over the rider's body rather than above the head.

Round 0 shots:

- `reference_durango-crit-number.png`: the reference.
- `before_{1600x900,844x390}_glc_{hit,crit}.png`: today's code. A normal hit shows no number at the target: it is
  tucked into the plate under the creature. A crit is a red `-34!` printed over `BLEEDING` and the plate's name.
- `after_{1600x900_glc,1600x900_fwd,844x390_glc,844x390_fwd}_{hit,crit,big,bow,bow_crit,taken_crit,flurry}.png`:
  windowed runs of `combatfx_lab`. Each number is frozen about 0.15 s into its life, right after the pop, when it
  reads at full opacity. A crit's peak readability comes at the end of the pop. Its peak size comes as it vanishes.
- `motion_crit_{1600x900_glc,844x390_glc,844x390_fwd}.png`: the same crit at 0.03, 0.08, 0.20, 0.35, 0.50 and
  0.65 s. It pops, rises, swells and fades. On the phone it now stays under the target plate.

All 4 shot runs print `[combatfx] PASS`, with exit 0 and 0 SCRIPT ERROR. The live renderer is confirmed by the
`renderer=` line and Godot's `OpenGL API ... Compatibility` header.

Compared with the reference: the reference's crit is a giant stretched yellow `86`, which is what the owner called
"too literal". Ours keeps the reference's yellow-with-dark-outline crit look at 1.5x a normal number. Normal hits are
small white numbers and readable at both sizes. Damage taken is red over the survivor. At 844x390 the 16 px normal
number is the smallest text in the scene that is not a meta label. It reads, but the owner may want `compact_scale`
nearer 0.9.

Caveats seen in the shots:
- The Stegosaurus in this tree renders as the box stand-in, and between runs it is sometimes knocked flat (the maul's
  GROGGY). That belongs to the creature art lane, not this package. `--species=velociraptor` reruns the beats on
  another body. On a 1500 HP raptor the maul's 84 is a normal hit (under 10%), so that run's `big` beat reports FAIL
  as designed.
- At 844x390 a gold crit can land beside the day/night dial without touching it. The dial is not one of the HUD's
  `drawn_blocks`, so the floor ignores it.

## For the next agent

- Integrator: merge the branch, then `git apply docs/orchestration/reports/claude-mmo-combatfx-hooks.patch` (11 files;
  it applies cleanly on top of TARGETUI's patch at 4b423f03). t_combatfx fails until the patch is in.
- Tuning: everything is in `game/data/combat_fx.json`: `size_px`, `tiers`, `big_hit_frac`, `life_s`, `expand_to`,
  `rise_lines`, colours and `compact_scale`.
- Tuning added in round 1: `pad_px` (gap between numbers), `visible_alpha` (below it a fading number may sit under a
  new one), `word_max_lane_px` (furthest a status word may sit from its target).
- Any new damage path: call `CombatFx.pop_number(anchor, amount, kind)`, where kind is `&"hit"`, `&"crit"`,
  `&"heal"`, `&"dot"` or `&"dodge"`. A creature's `combat_float` signal already reaches it through CreaturePlates.
- `ASSUMPTION`s to list for the owner: every value in `combat_fx.json`, and the ranged crit chance and multiplier in
  `combat_tuning.json`.
