# Completeness critique of the wave plan (2026-10-18)

Written by the audit's completeness critic after the survivor-v2 merge. Amendments it triggered are in STATUS.md.

**Completeness critique of the DEADFRONT audit register (`scratchpad/audit/register.md`)**

The register is stale against the current work tree. HEAD is now f583837; the register was written at cb03754. Since then the survivor-v2 branch was merged (387 files changed in `game/`), and STATUS.md recorded owner decisions that settle register questions 3, 6, 7, 8, 9, 10, 12, 13 and 19. STATUS.md now says "Owner questions (open): none".

**A. Plan not updated for owner decisions**

1. **Survival meters have no package.** P0, blocker none.
   - STATUS.md: "ARK-style survival meters (health, stamina, hunger, thirst, temperature) and hazards are IN".
   - The register still files survival-01 as owner_decision P1 and still asks it as question 8.
   - No package owns hunger, thirst or temperature meters, drinking, starvation, or HUD bars for them. W2-PROCESS covers spoilage only; W2-WEATHER only feeds fatigue.
2. **Breeding is IN but still parked in Wave 4.** P1 (raise tame-01 back to P0), blocker none.
   - W4-TAMING is still blocked as owner_decision, behind W3-SRVACT.
   - Its genetics, egg and mutation domain could be built now as node-free code, the same way W1-SRVDOM is.
3. **Hybrid combat has no acceptance.** P1, blocker none.
   - Owner answer: keep tap-target auto-attack and add an action mode (click-to-swing, dodge, block, aimed ranged).
   - W4-WORLD's acceptance still reads "Defined after the owner's answers".
   - No W1–W3 package has block, click-to-swing or aimed ranged. pc-defense-01 and pc-combat-05 are still marked owner_decision.
4. **Death loot bag is untested.** P1.
   - Owner answer: inventory drops in a recoverable loot bag; equipped gear loses durability.
   - W1-COMBAT "closes" durability-01, but its only test is "10 landed club hits lower its durability by 10".
   - No package builds or tests the bag: ownership, despawn timer, server authority.
5. **Caves are IN** but only appear in W4-WORLD as "caves if allowed". P2.
6. **Wild dinosaurs attacking structures is now a yes**, but W2-ECO still says "only if the owner says yes" and dino-ai-17 is still P3 owner_decision. There is no test that a blocked raptor breaks through a wall. P2.
7. **Survivor-v2 is merged, so the other_session blockers are gone.**
   - W2-PLAYER, W2-PANIM, W2-INV and W2-CVIEW are unblocked.
   - Every finding on `player.gd`, `creature_view.gd` and `items.json` was measured before the merge and needs re-measuring.
   - My lab run logs "[data] items=164 ... recipes=82"; the register's sources counted 153 and 71.
   - The Stegosaurus box override is still at `creature_view.gd:65-66` (`force_safe_placeholder := def.id == &"stegosaurus"`). dino-art-02 is now a one-line fix with no blocker.

**B. Systems no auditor covered, or covered too thinly**

1. **Camera.** P0 owner_decision (projection), P1 none (occlusion).
   - `iso_camera.gd` is 44 lines: fixed orthographic camera, pitch -35.264, yaw 45, ortho size capped at 28 m, no rotation, no occlusion handling.
   - W2-BUILDSYS (two-storey house with roof) and W2-TERRAIN (25 m relief) will hide the player, and nothing plans a roof cutaway or fade.
   - The owner's aimed-ranged mode needs a different camera.
   - W1-LIGHT's shadow fix is defined against "the camera's 45° axis". Any orbiting camera reopens lv-shadow-01.
   - Sky, horizon and dinosaur scale are unreadable; this sits at P2 (lv-sky-17).
2. **Mobile and touch input were never exercised.** P1, blocker owner_decision (question 20, mobile vs desktop as the ship gate).
   - AGENTS.md says mobile is the primary target. Across all audit logs, 316 runs printed "controls mode=hidden", 3 printed "mode=tap", and none ran with `--touch`.
   - `virtual_joystick.gd` and `touch_controls.gd` were not audited.
   - `tools/export_ios.sh` and `release_ios.sh` appear nowhere in the register.
   - No mobile memory or GPU measurement exists. For reference, the desktop probe shows "mem static=323MB video=336MB tex=219MB".
3. **Creature render cost in the web renderer is under-weighted.** P0, blocker partly renderer.
   - `performance/probe_home_gl.log`: "[probe:creatures+60] frame_ms avg=161.71 p50=150.76 p95=233.97" in gl_compatibility on an M5 Pro, about 6 fps. Forward+ is 35.44 ms avg.
   - Each creature brings a Label3D, a particle system and two AnimationPlayers (label3d=84, particles=85, anim_players=170).
   - The register cites only physics_ms 16.42, and W1-AI's acceptance gates physics_ms only.
   - `abl_gl.log` baseline shows a hitch, "p99=164.82 worst=190.98", that is not in the register.
   - Every probe reports "gpu_ms avg=0.00", so GPU cost was never measured. No Chrome fps figure exists anywhere.
4. **Persistence of the world.** P0 for a persistent MMO.
   - W3-SRVWORLD's acceptance has no restart test: structures, node depletion, pets and wild population surviving a server restart.
   - W4-HOST covers acknowledged ledger operations only.
   - There is no structure decay or upkeep anywhere.
5. **Netcode feel.** P1, blocker none.
   - All net acceptance runs on loopback. There is no latency or packet-loss injection, no interpolation or jitter metric, and no lag-compensated hit validation, which the action mode combined with server-side damage requires.
   - Replication of other players' 4-slot armor, held weapon and mount state is in no acceptance.
   - There is no concurrent-player target per island process, although a headless island costs 231 MB ("mem_delta=231 MB").
6. **PvP, tribes and permissions.** P1 owner_decision.
   - The PRD default is "no PvP" (`docs/orchestration/plan.md:16`). It is never restated as a constraint or asked.
   - `clan` and `tribe` return nothing in `scripts/`.
   - W3-SOCIAL's tribe panel has no shared ownership of pets or structures, no rule for pets attacking other players, and no griefing rules (blocking the harbour, kiting wild dinosaurs into bases).
7. **Weight and encumbrance** are absent: grepping for `encumb` and `max_weight` finds nothing. In ARK, weight drives hauling, pet value and market logistics. Not in the register. P1 owner_decision.
8. **Player progression depth** (stat points, unlocks) was not audited. Only ui-level-01 touches it, and my screenshot still shows "0" and "Lv. 0 0.0%". P2.
9. **Exploration** has no loot crates or supply drops, no map discovery, and no swimming (`swim` returns nothing in `scripts/`). P1.
10. **Never mentioned at all** (zero register hits): onboarding or tutorial, accessibility (W1-ICONART signals rarity by colour only), key rebinding, web graphics quality settings, telemetry and crash reporting, privacy and account deletion (App Store rule once W4-HOST adds accounts). P2 each.
11. **The code being merged was never run by an auditor.** P0 evidence gap.

    | Branch | Size | Audit evidence |
    |---|---|---|
    | `claude/mmo-econ` | +3,926 lines (`economy_tests.gd` alone is 1,238) | none |
    | `claude/mmo-net` | +2,426 lines | none |
    | `claude/mmo-audio` | 938 files | none |

    - No audit log contains output from economy_tests, net_tests, NET SMOKE or audio_tests.
    - `multiplayer/net_probe.gd` is a raw WebSocketMultiplayerPeer loopback test.
    - `econ-verify/` holds two probes that exercise HEAD pet code, not the economy engine.
    - The marketplace (ranked #4, the owner's headline) and "NET SMOKE PASS" rest on the branch authors' own reports.
12. **Audio** was audited at HEAD, where the game is silent, not the 456-file work in progress.
    - W1-INT's audio acceptance is only audio_lab PASS plus Deafened at -20 dB.
    - Nothing checks that every events.json entry resolves to a file, a licence row per file, loudness, that gameplay actions actually fire events, or web Sample-mode playback.
    - STATUS.md's sound-settings requirement (Creatures slider, mute hotkey, `--mute`, `DEADFRONT_MUTE`) is not in W2-HUD's acceptance.

**C. Claims that rest on no evidence**

1. The header says only P2/P3 rows went unverified, but 52 P0/P1 rows are marked V=U. Examples: tame-12 (P0), econ-conservation-01 (which five packages claim to close), net-interest-13, net-timers-12, world-mmo-state-11, sec-admin-13, sec-gather-11, qa-ci-01, ui-theme-01, audio-web-14, pc-defense-01, craft-02.
2. Section 1 says "Severity is the verified one", which those 52 rows contradict. lv-exposure-02 sits in the #3 P0 row but is filed as P1.
3. Every performance number is native, vsync off, with a GPU time of 0.00. "129 creatures fill 90 % of a 60 Hz tick" is physics time only.

**D. Screenshots and measurements that should have been taken**

- The MMO branch served locally and captured in desktop Chrome, the actual judge. The only web captures are production shots of the old main build (`lighting-vfx/prod-web-*.jpg`, `qa/soak/artifacts`).
- 390x844 with `--touch` (joystick, safe area).
- Survivor v2 at the gameplay camera on the real island, to re-measure pc-anim-01, and the T. rex mount being ridden.
  - I took `scratchpad/audit/completeness/equip_mount_head.png` (Forward+, equip_mount_lab). It shows the v2 survivor in hide/bone armor on a flat green void with no ground plane, so it cannot settle grounding.
- Two clients on the net branch side by side.
- A player inside a structure or under trees at dusk in gl_compatibility (occlusion).
- An 85-creature scene in compat with a frame-time overlay.
- Loudness and event-count measurements of the audio work.

**E. Acceptance criteria that are not measurable**

- **W4-WORLD:** "Defined after the owner's answers", and the answers now exist.
- **W1-QA:** perf_budget_lab thresholds are "recorded after" later merges, so there is no number. No Chrome fps gate exists anywhere; production_soak "records rAF p95" with no threshold.
- **No pass rule, only "inspected":** W1-STRUCTART ("no flat salmon palette, readable silhouettes"), W2-PROCESS ("visibly pass through 3 stages"), W2-VFX ("shows flame and smoke"), and the "screenshots inspected" lines in W2-TERRAIN, W2-RERIG, W2-BUILDSYS and W3-NATUREART. Each needs a pixel metric (for example, pairwise stage mean-RGB delta of at least 0.05) or a named reviewer.
- **W1-LIGHT:** section 5 says final colour sign-off happens in Chrome, but no acceptance step requires it. Thresholds are measured only in local compat, which the register itself says "reads brighter than WebGL".
- **W3-EXCHANGE:** "≥ 55 fps" with no renderer, machine or browser given.
- **W4-HOST:** "plays a session", with no duration or operation count.
- **W1-WEB:** "≤ 200 MB", while the baseline is quoted three ways: 303 MB (§1 #23), 317 MB (§5), and 317,479,824 bytes, which is 302.8 MiB. The unit is undefined.
- **W1-ARTA/ARTB:**
  - The 10k–20k triangle budget contradicts the PRD's `"target_polycount": 12000` (`docs/prd/dinosaur-roster-and-3d-pipeline.md:202`), which perf-mesh-01 cites.
  - The blocker is listed as "credits" although spend is approved. The real gate was Gate-1, now batch-approved, and it is not checked in acceptance.
- **W1-ICONART:** "≥ 60 items" is about 37 % of the 164 items at HEAD, while the owner asked for rendered item art. W2-SCREENS rims will show symbol fallbacks for about 100 items.
- **W3-SRVWORLD/W3-NETQA:** loopback only. They need RTT/loss injection and a persistence-after-restart test.
- **Every package:** the "screenshots inspected at 1600x900 and 390x844" gate is self-inspection by the implementer. GAUNTLET.md:26-27 requires production-stamp proof for each request; the plan requires it only at release.

I did not re-run smoke, unit tests or labs, did not re-measure survivor grounding on the real island, and did not read the econ, net or audio branch code. The plan's per-package JSON files (`plan/w1.json`, `w2.json`, `w34.json`) were not read line by line. Biggest risk: Wave 1 worktrees are already cut from ea2d167, before the survivor-v2 merge and the owner decisions, so their "must not touch" rules and blockers are out of date.
