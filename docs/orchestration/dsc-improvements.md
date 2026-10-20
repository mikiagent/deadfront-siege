# DeepseekCLI improvement log

One dated entry per dsc job: job, outcome, cost, time, cause, and a paste-ready prompt for the DeepseekCLI repo
(https://github.com/mikiagent/deepseekcli). GAUNTLET.md "DeepSeek workers" lists the prompts already due.

- 2026-10-20 mmo-camp (18 Blender camp pieces): success, $0.51, 0.8 h. Narrow kit-based build with a hash-guarded gate.
  Review later found the game's dirt disc hid the fields: gate should render previews with the in-game ground disc.
- 2026-10-20 quads-loco2 (quad walk/run): success, $1.26, 2.4 h. Gate measured stride in mesh units, skin stretch and hips.
  Lost time retrying milestone 1 against the full gate -> prompt 1.
- 2026-10-20 mmo-icons2 (65 item icons): stalled, $0.87, 3.5 h, 0/4 milestones. 20-minute full gate per attempt,
  out-of-scope .uid failed scope check, stop waited on a Blender run -> prompts 2, 4, 5.
- 2026-10-20 ragdoll profiles: stalled, $0.57, 2.1 h, 0/4 milestones. Open-ended physics tuning -> prompt 3; keep tuning for Claude.
