# claude-canonred3: t_tutorial, t_playerturn and t_ragdoll green again

Branch `claude/mmo-canonred3` from `origin/claude/mmo-overhaul` 0cb8ff09. Not merged. No paid generation.

## 1. t_tutorial budgets (LOOKPASS grass)
Canon numbers: 262 town MultiMeshes (ceiling 220) and 88,813 ground-cover instances (ceiling 80,000).
LOOKPASS added 30,792 tufts (headless counts Forward+ density) in one MultiMesh per 32 m chunk per kind,
which was ~45 batches. Without the grass the town is 217 batches and cover 58,021.

Neither ceiling was raised. Fix in `town_dress.gd`:
- **Grass patches**: one grass mesh now carries 3 tufts (`TUFTS_PER_PATCH`), so the same ~30 k tufts are
  ~9.6 k instances. Same blades per m2, same triangles, same wear thinning, same colours. Flowers stay single
  tufts. Patch centres sit 0.2-0.8 m into their tile so a patch does not spill onto a street.
- **One batch per kind over the whole town** (2 MultiMeshes instead of ~45). The visibility range is
  `IsoCamera.cull_range(town half-diagonal)` because the range is measured to the batch centre.

Result: **219 MultiMeshes, cover 69,477**, `grass_tufts` 30,774.

Cost: the grass no longer frustum-culls per 32 m chunk, so the game-camera shots draw about 130-160 k more
primitives (600 k -> 760 k mean, 15 tris per patch). Draw calls are flat (120 -> 119). Frame time
(Mac, Forward+, 1600x900, vsync off, 11 game-camera day shots, `townpolish_shots.gd --perf`, mean of the
per-shot means). Runs alternated canon/branch:

| run | canon 0cb8ff09 | this branch |
|---|---|---|
| 1 | 5.60 ms (p95 9.99) | 6.58 ms (p95 14.10) |
| 2 | 7.57 ms (p95 14.42) | 4.67 ms (p95 8.97) |
| 3 | 5.57 ms (p95 7.86) | 6.69 ms (p95 13.47) |

Other agents were running Godot on the Mac, so the runs swing by 2-3 ms in both directions. I can't see a
frame-time change above that noise. Phone and web were not measured. They build half the grass density.

Shots (`reports/canonred3/`, off-screen `--position 6000,3000`, self-quitting, `-- --skip-charcreate`,
day 0.42, 1600x900): `before_/after_` market, pens and harbour. The grass reads the same density and colour.
It is a little clumpier, in threes. The homes shot frames a different spot from run to run (on canon too),
so I left it out.

## 2. t_playerturn `tap_walk_away_target_gone: no position jitter`: the game was wrong
Trace: the opener was a body tackle, which lunges her into the deinonychus. The test then moves the animal
around her, and the depenetration shoved her 3.2 m in one frame (z -1.79 -> +1.43). That carried her past
her route's next waypoint (0.08, 0.08). The path follower only advances on reaching a waypoint within
0.25 m, so she walked 1.4 m back to it and then forward again. That reverses her velocity, and the test is
right to count it as jitter. In the other case the opener was a kick, so she was never shoved.

The same backtrack would happen in play after any knockback or shove mid-route. Fix in
`player_sim._tile_nav_dir`: if she moved more than `SHOVE_REPLAN_M` (0.5 m) since the last physics frame,
the route is re-planned from where she stands. A walking or sprinting frame moves under 0.1 m, and the
`unstick` step is 0.45 m. All 14 t_playerturn cases now show 0 velocity flips.

## 3. t_ragdoll (coordinator follow-up)
`_test_placeholder_body` still expected the stegosaurus placeholder that STEGOFIX removed. It now expects
`using_glb`, a frozen death that does not take the "no skeleton" fallback (it simulates a ragdoll), and the
corpse on the ground (y=0.000). The "no profile" and NaN tests still cover the fallback path.

## 4. t_tutorial bot, red under the budgets (and before LOOKPASS)
After the budgets were fixed, t_tutorial still failed on the bot. The bot also fails at ba65da3b (before
LOOKPASS), on `tut_butcher: no carcass`. Two causes:
- **tut_axe**: `bot_survivor._craft` sent one `nav_to` toward the bench, about 200 m from the river. A
  compsognathus bite or a tackle on the way clears nav, so the walk ended for good. The walk now re-issues
  the route as a ground order (`move_order`, which outranks the auto-fight) whenever nav is idle, with a
  45 s budget instead of 25 s.
- **tut_butcher**: when the bot kills a compsognathus early (on the water trip), `did.kill` meets the hunt
  order before it comes up. By the butcher order that carcass is gone, so there is no carcass and no pointer
  target. A player in that spot would see the pointer go dead.
  - Game fix (`tutorial.gd` `world_point("corpse")`): with no carcass, the pointer falls back to a
    compsognathus to hunt.
  - Bot fix (`tutorial_bot._loot_corpse`): with no carcass, it hunts one first.

## Gates (this branch)
| Gate | Result |
|---|---|
| t_tutorial (own HOME, 1200 s) | PASS: 219 batches, cover 69,477, all 21 orders |
| t_playerturn | PASS, all cases 0 velocity flips |
| t_perfgates | PASS |
| t_lighting | PASS |
| t_ragdoll | PASS |
| t_data (reads bot_survivor) | PASS |
| run_all.gd | `[tests] PASS` |
| tools/smoke.sh --no-import | SMOKE PASS |

## For the next agent
- The town sits at 219 of 220 batches. Anything new in TownDress needs batches freed elsewhere or a
  reasoned ceiling change.
- `TUFTS_PER_PATCH` (3) and the patch offsets are visual tuning (# ASSUMPTION class, same as LP5).
- The early-kill path in the tutorial was not hit in my passing runs. The pointer fallback and the bot's
  hunt-first branch are simple, but untested by a deterministic case.

## 5. Follow-up after the canon merge (49ff065a): `tut_butcher: meat cut refused: carcass gone`
The integration run failed the butcher step this way. The bot killed a compsognathus, but the rest of the
pack kept biting, and each bite cancelled the cut. The bot also always took the *first* carcass in the
group. After about 94 s of fighting, that carcass hit its 90 s lifetime and despawned at the cut.
- Game (`corpse.gd`): an unlooted carcass does not count down its lifetime while the local survivor
  stands within cut reach (3.5 m). Looted-empty carcasses still fade on their own clock. This stops a
  carcass vanishing under a player who is fighting off the pack before cutting.
- Bot (`tutorial_bot._loot_corpse`): it always takes the nearest carcass that is not fading and picks
  again if that one is gone. Each of 4 attempts is: walk to it, fight off attackers, wait out the hit
  lockout, then cut.

Merged origin/claude/mmo-overhaul in. On the merged tree, t_tutorial passed 3 of 3 runs, each with its own HOME.
Run 2 hit the early-kill path ("tut_hunt already true when it came up", the first carcass had despawned)
and passed the butcher step in 68 s. t_playerturn, t_perfgates, t_lighting, t_ragdoll, t_butcher and t_data
pass, run_all.gd `[tests] PASS`, smoke SMOKE PASS.
