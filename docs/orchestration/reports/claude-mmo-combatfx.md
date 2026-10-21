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
- the commit with this report and the hooks patch

An earlier builder run left uncommitted work in this tree, written for the first reading (balloon to 1.6x, red
outline on the target). I kept its plumbing, which sends every number to one drawer instead of the plates and the HUD.
I rewrote the drawer, the data, the test and the lab for the correction.

The call sites are in files that other packages own, so they are not committed on the branch. They ship as
`docs/orchestration/reports/claude-mmo-combatfx-hooks.patch` (10 files, 33+/132-). The work tree has the patch
applied, and every gate below ran with it applied (`git diff` matches the patch byte for byte).
`git apply --cached --check` passes on `claude/mmo-overhaul` 809be2e8. It also passes after
`claude-mmo-targetui-hooks.patch` (from the `claude/mmo-targetui` branch), because both touch `creature_plates.gd`
and `hunt_hud.gd` but in different hunks. `combat_fx.gd` compiles without the patch, but nothing calls it until the
patch lands, so the branch and the patch must land together.

Credits spent: none (no Meshy, no Tripo).

## What the owner gets

- **Every hit shows a number** at the struck creature (white) or over the survivor (red). Hits on your pet are red
  too. Heals are a green `+25`, a dodged bite is a small grey `DODGE`, and each bleed tick is a small number. Status
  words (BLEEDING, GROGGY) use the same placement so they don't print on top of the numbers. The game has no miss or
  block on the player's side, so there is no word for those.
- **Sizes rise with significance.** On the 1600x900 canvas a normal number is 20 px, a big hit 25 px and a crit
  30 px. A big hit is at least 10% of the target's max HP (`big_hit_frac`). Your crits are gold, bold and outlined.
  A crit you take stays red but starts at crit size. Phones use 0.8x (16/20/24 px at 844x390). The widest a crit
  ever gets is 42 px, so it never covers the target.
- **Motion, as the owner described it.** A quick pop from 0.6x to 1.0x over 0.08 s. Then the number grows smoothly
  to 1.4x while its opacity falls to 0, and it rises one number-height with an ease-out. Each number lives 0.75 s.
  The test steps 45 frames at 60 fps and finds no size step over 0.015x, no height step over 0.9 px, no reversal and
  no sideways drift.
- **Rapid hits stay legible.** A new number on the same target takes the nearest free spot beside the older ones,
  checked over their whole remaining paths. At 10 hits/s no two readable numbers overlap, and the furthest one sits
  155 px from the anchor. Each target keeps at most 8 numbers.
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

## Gates

All gates ran on 6df377fd plus the hooks patch, in this work tree, on 2026-10-21.

| gate | result |
|---|---|
| every `game/tests/t_*.gd` (24 files) | exit 0, `PASS`. `t_save` prints its 5 deliberate SCRIPT ERRORs; every other file has 0 |
| `run_all.gd` | exit 0, `[tests] PASS` |
| `tools/smoke.sh` | exit 0, `SMOKE PASS` |
| combat labs: combatfx_lab, hunt_lab, combat_rules_lab, capture_lab, pets_lab, pet_passthrough_lab, wild_ai_sweep_lab | exit 0, PASS, 0 SCRIPT ERROR. One exception: `combat_rules_lab` failed one wall-clock timing check on the first run (`stone-knife damage lands 0.193 s after the swing starts (want >= 0.25)`) while the machine load average was about 15. Three reruns passed at 0.278 to 0.279 s, the same as the earlier round (0.280 s). The lab notes that this check is load-sensitive, and nothing in this package touches the swing timing |

`t_combatfx` (47 `ok` lines) fails on the old code. Its first check, "CreaturePlates owns a CombatFx", fails there. It
checks the size ladder (normal < big < crit, from melee, the slingshot and a creature's bite) and the colours by
direction (dealt white, crit gold, taken red, pet red, heal green, dodge grey). It also checks one number per bleed
tick, the pop, swell, fade and rise curves, smoothness over 45 frames, no overlap at 10 hits/s, edges, the HUD floor,
a number over a freed creature finishing where it was, and cleanup. Mutation check for this round's floor: with
`f["floor"] = 0.0` the new case fails ("15 frames over it"), and with the fix it passes.

Logs: `/private/tmp/claude-501/-Users-milankinzy-Documents-deadfront-siege/72cebc8b-d241-430b-9ea6-94d65339bfef/scratchpad/combatfx/gates2/`
(`gates.txt` has one line per gate).

### Frame cost at 10 hits/s

`combatfx_lab --fx=stress`, windowed 1600x900, vsync off, 3 s phases. A warm-up phase runs first. Every hit phase
runs the whole hit path (flash, blood burst, plate), so "numbers on" minus "numbers off" is the cost of the numbers.

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

- Integrator: merge the branch, then `git apply docs/orchestration/reports/claude-mmo-combatfx-hooks.patch` (it applies
  cleanly on top of TARGETUI's patch, and TARGETUI's applies cleanly on top of it). t_combatfx fails until the patch is in.
- Tuning: everything is in `game/data/combat_fx.json`: `size_px`, `tiers`, `big_hit_frac`, `life_s`, `expand_to`,
  `rise_lines`, colours and `compact_scale`.
- Any new damage path: call `CombatFx.pop_number(anchor, amount, kind)`, where kind is `&"hit"`, `&"crit"`,
  `&"heal"`, `&"dot"` or `&"dodge"`. A creature's `combat_float` signal already reaches it through CreaturePlates.
- `ASSUMPTION`s to list for the owner: every value in `combat_fx.json`, and the ranged crit chance and multiplier in
  `combat_tuning.json`.
