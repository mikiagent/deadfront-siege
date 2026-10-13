# Sleep interaction and fatigue balance - October13

Owner requests: tent should have a sleep button and lay the survivor down; exhaustion builds too quickly, but tired/exhausted penalties should be stronger.

## Landed independently of the pending animation

Tent, canvas tent and straw roll tap now open the existing station-style SLEEP hex. A separate press starts the existing validated sleep state. Distant presses report "Move closer to sleep" instead of failing silently. Nearby context sleep and keyboard interaction remain available. No new building tiers, use counts or sleep restoration changes.

All positive fatigue gains are multiplied by0.5 at the common Vitals entrypoint, covering time, running, gathering, combat, climate and statuses. Food/rest keep their original reductions; coziness still applies afterward. Baseline full fatigue takes90minutes rather than45. Saved fatigue values are not rewritten.

Stamina penalties match existing HUD stages:

| State | Fatigue | Stamina cap | Stamina refill multiplier |
|---|---:|---:|---:|
| Rested | below25% |100%|100%|
| Tired |25-49%|85%|50%|
| Weary |50-74%|65%|35%|
| Exhausted |75%+|50%|20%|

The exhausted flag now matches the displayed75% threshold (formerly95%). No health drain, stat/damage changes or gathering lockout. This is an initial balance choice: longer outings, stronger rest incentive, still playable when depleted.

## Evidence

Godot4.7.1 full regression suite PASS. Added checks for halved exertion, unchanged rest and exact stage boundaries/caps/refill multipliers. The `--lab=sleep_lab` seeded fixture calls real tent tap/menu and sleep entrypoints: menu does not auto-start, movement interrupts without consuming a use, full10second completion restores fatigue and consumes exactly one use.

A modeled10minute outing (600seconds running,120gather units,30attacks, baseline time; no food/coziness) adds90.61fatigue instead of181.22before clamping. This is arithmetic fixture evidence, not an earned or human-feel playtest. Continuous exertion still needs rest; pacing tuning remains open to owner feedback.

Rendered Godot4.7.1 Compatibility screenshot inspected: SLEEP hex readable over the tent, exhausted96% HUD and50/100stamina. Existing tent/floor materials appear overbright in this renderer; not tent-art acceptance. Sleeping clip not yet delivered, so laid-down start/loop/wake visual acceptance is pending. No production deployment.

Reproduce: Godot4.7.1 --headless --path game --script res://tests/run_all.gd; then --headless --path game -- --lab=sleep_lab. For the explicit-menu screenshot run with a display and --rendering-method gl_compatibility -- --lab=sleep_lab --shot=/tmp/tent-sleep-menu.png.

## Animation integration completed

Base929c58b includes the CC0 KayKit clip deliverydd08bb1. RiggedModel now loops `sleep`; PlayerAnim sequences `sleep_down` -> `sleep` -> `sleep_up` -> idle. Player._start_sleep starts the animation; completion/movement/nav interruption wakes it. Wake movement waits for the2.333second stand-up so the survivor does not slide along terrain while seated. Combat hit/knockdown/death takes precedence and clears sleep animation locks; it does not consume a sleep use.

Player's collider-centred origin is normally0.9m above terrain. Sleeping clips were authored with ground contact at root0, so world integration initially floated. A reversible Visual-only offset matches actual surface_y under the survivor; collider position and survivor skeleton remain untouched. The offset stays lowered through most of get-up, then returns near its final standing frame. Damage/death/revive restore the offset immediately.

Updated sleep_lab uses actual home-island terrain and camp camera, no creatures for a deterministic fixture. Godot4.7.1 regression PASS, boot smoke PASS. Fixture asserts start transition, LOOP_LINEAR sleep, movement wake/idle, full completion/wake/idle, fatigue reset, exact single-use consumption, and damage interruption without another use. Seeded fatigue fixture, not earned progression or human-feel acceptance.

Inspected rendered640x360 home-world captures: start/down, lying loop on terrain beside the tent, seated get-up still at terrain level, and standing idle after wake. Earlier float and mid-wake lift were corrected and recaptured. Existing camp props remain brightly lit in Compatibility rendering; terrain and survivor are readable. Remote software-render speed is not a production performance measurement. Images transferred to the parent for review; no production deployment by this task.
