# claude-mmo-rest: Rest sits you down, heals you and lowers exhaustion

Owner, verbatim: "resting should sit you down and heal you and lower exhaustion. I tried this on vercel and it didn't
work". Production is `31c064a08` (stamp `31c064a08/2284b9bf56`) on `claude/mmo-overhaul`.

Branch `claude/mmo-rest`, cut from `claude/mmo-overhaul` at 2206de22. It merges ddaab662, then 946da955 (HUD-DAYNIGHT,
merge `9706364d`), then 809be2e8 (W2-DATA sync, docs only, so the game tree is unchanged). Commits:

- `6241b962` rest_lab, the reproduction lab (committed before any game change)
- `4aa06fd3` RestState, `data/rest.json`, the rest icon, t_rest, the lab's Sleep trial and motion trace
- `09b119a5` the icon's import settings, the sit-to-sleep test case, the lab's hex shot and frame trace
- `9706364d` merge of `claude/mmo-overhaul` 946da955 (HUD-DAYNIGHT's dial and HUD changes; the patch re-applied
  cleanly)
- this report and `claude-mmo-rest-hooks.patch`

The call sites are in files other packages own, so the branch does not commit them. They ship as
`docs/orchestration/reports/claude-mmo-rest-hooks.patch` (11 files, 127+/11-). `git apply --cached --check` passes
on the branch head and on `claude/mmo-overhaul` at 809be2e8. The work tree has the patch applied, and every
gate below ran with it applied on the merged tree. `rest_state.gd` and `t_rest.gd` depend on the patch, so the branch and the patch must land
together.

Credits spent: none. No Meshy, no Tripo, no downloads.

## Why resting did nothing for the owner

I reproduced it on the production commit (scratch tree `rest-prod` at 31c064a08) and on the base. Both builds give
the same numbers. `rest_lab` starts a hurt, tired survivor (HP 40, fatigue 60, no statuses, no creatures, no rain) at
four spots on the home island. At each spot it tries every way to rest: a Rest hex, then the Sleep hex, then the
interact key (E). It records pose, HP and fatigue for 30 s.

| Spot | Hexes offered | What the attempt did | Pose | HP over 30 s | Fatigue over 30 s |
|---|---|---|---|---|---|
| open grass, 18 m from camp | Claim | E: nothing | standing idle | 41 → 65 | 60.02 → 60.58 |
| 1.9 m from the camp bonfire | Cook | E: Cauterise, which does nothing without a bleed | standing idle | 41 → 65 | 60.01 → 60.29 |
| 1.9 m from the camp tent, Sleep hex | Sleep, Cook | lies down for 10 s | lying (`sleep`) | 41 → 49 at 10 s, 65 at 30 s | **60.01 until t = 10 s**, then 0.00 |
| same, with a tap on the ground 5 s in | Sleep, Cook | "Sleep interrupted" | gets up and walks | 41 → 65 | 60.01 → 60.48 (prod) / 60.81 (base) |

The HP rise in every row is the passive 0.8 HP/s regen. A survivor standing still gets the same.

There are three causes:

1. **There was no Rest.** Sleep was the only recovery verb, and its hex only shows within 3.2 m of a tent or straw roll.
   Open ground offered Claim and the bonfire offered Cook. Resting anywhere else did nothing: HP rose at the passive
   rate and fatigue kept climbing. The fatigue panel still said "rest between harvests", but there was no verb for it.
2. **Sleep gave nothing until its last frame.** It lies the survivor down instead of sitting. It adds no healing on
   top of the passive rate. It holds fatigue flat for the whole 10 s and clears it only when the timer ends.
3. **Any input cancelled Sleep for nothing.** A click on the ground (a tap-to-walk on desktop Chrome), a WASD key or a
   hit in those 10 s showed "Sleep interrupted" and kept nothing. On Vercel a single click while waiting threw the
   sleep away.

I can't know which of these the owner hit. Each one reproduces "it didn't work".

Before shots (production 31c064a08):
`/private/tmp/claude-501/-Users-milankinzy-Documents-deadfront-siege/72cebc8b-d241-430b-9ea6-94d65339bfef/scratchpad/rest/shots/before/{1600x900_glc,1600x900_fwd,844x390_glc}/{open,fire,tent,tent_tap}_<w>x<h>.png`.
They show the survivor standing at the open spot and at the fire with only Claim or Cook offered, and lying flat at the
tent with no status chip.

## What ships

- **A Rest action everywhere out of combat.** It has a context hex (white seated-figure icon, caption REST) at every
  spot and the X key on desktop. Online it is an `act.rest {"on": bool}` intent through `PlayerActions.rest()`, so a
  retried send cannot flip the state back. While she rests the hex hides, as Sleep's does; she gets up by moving. X
  toggles.
- **She sits down.** The seated pose is `sleep_down` held on its 1.0 s frame, where she sits up on one arm. The visual
  is grounded as for sleep. Getting up plays `sleep_up` from its matching 0.68 s frame, and the visual rises as the
  clip ends. There is no T-pose and no sliding: t_rest measures 0.000 m of drift over 2 s seated. Choosing Sleep at a
  tent while seated lies her down from the sit instead of restarting the clip.
- **She recovers by place.** Rates are in `data/rest.json`, re-read twice a second while she sits:

  | Place | When | Health | Fatigue |
  |---|---|---|---|
  | open | anywhere else | +1.0 HP/s (+0.8 passive = 1.8) | -6 /min |
  | fire | within 3.0 m of a bonfire, stone fire pit or burning campfire | +2.0 HP/s (2.8) | -15 /min |
  | shelter | within 3.2 m of a tent, canvas tent, straw roll, log shelter or cabin bed | +3.0 HP/s (3.8) | -30 /min |

  The order follows the docs: spec 01:19 lists tents, beds, campfires and safe camps; PRD :118 makes a residence the
  main fatigue dump; PRD :803 makes tents cheap fatigue management. The numbers are ASSUMPTIONS, because no doc gives
  any. Vitals clamps both values: Health stops at its maximum and fatigue stops at 0. A status that blocks regen (Deep
  Bleed) also blocks rest healing.
- **The bonfire's sitting effects (PRD :285).** Sitting down by the fire clears Wet. While she sits there, heat fatigue
  is x1.2 and cold fatigue x0.8, applied through `Player.tick_climate_fatigue`.
- **Rest ends with the stand-up when:**
  - she moves: a move key, the joystick or a tap-to-walk, including tapping a node or a creature;
  - she takes damage: the hit plays the stand-up, not a standing flinch from the floor;
  - she enters combat: she starts hunting, or takes a hit;
  - a creature closes in: any creature whose brain targets her and is in alert, approach, attack or retreat.

  Rest is refused, with the reason shown, in these cases:
  - within 5 s of a hit (the same lock as Sleep);
  - while she is hunting or being hunted;
  - mounted, rolling, knocked down or in water;
  - while a status deals damage, because its ticks would stand her up ("Treat your bleed before resting.").

  Autofeed waits while she rests, so a quick meal cannot pop her out of the sit.
- **The Resting chip (spec 01:22).** It is the first chip in the status row, drawn with the rest icon. A dark box under
  it shows the live rates, for example "Resting by the fire / +2.8 HP/s / -15 fatigue/min". When she is full it reads
  "HP full", and "Rested" when fatigue is near 0. It reads "Sleeping" with the shelter rates while she sleeps. Under
  the minimap the box sits below the Claim hex's slot, so the two never overlap.
- **Sleep at beds and tents.** While asleep she now recovers at the shelter rate, so Health and fatigue move on
  screen. The completed sleep still gives its full restore (tent: fatigue to 0). An interrupted sleep keeps what it
  gave, which is never more than resting there gives. A bedding use is still spent only on completion, so a straw roll
  cannot be milked.
- **Save and load (spec 01:22).** The save writes `"resting": true` in the player block. A load sits her back down,
  and anything other than a real `true` is ignored. Health and fatigue come back as saved, and the rest goes on.
- The fatigue panel's "Time awake" remedy now names Rest: "Rest (sit down): faster by a fire or a tent. Sleeping in a
  tent or bed clears it."

## After numbers (same lab, same spots, the work tree with the hooks applied)

| Spot | Hexes | Attempt | Pose at 5 s | HP over 30 s | Fatigue over 30 s |
|---|---|---|---|---|---|
| open | Rest, Claim | Rest hex | seated | 41 → 95 (1.8/s) | 60.02 → 57.58 |
| fire | Rest, Cook | Rest hex | seated | 41 → 100 by about 21 s (2.8/s) | 60.01 → 52.78 |
| tent | Sleep, Rest, Cook | Rest hex | seated | 41 → 100 by about 16 s (3.8/s) | 60.01 → 45.27 |
| tent, Sleep hex | Sleep, Rest, Cook | Sleep hex | lying | 41 → 60 at 5 s, 79 at 10 s | 57.56 at 5 s, 0.00 at 10 s |
| tent, tap 5 s in | Sleep, Rest, Cook | Rest hex | seated, then up | 41 → 60 at 5 s, then passive | 57.56 kept at 5 s, then walking |

Fatigue gains during each run were time only (+0.32 to +0.65 over 30 s), plus walking after the tap.

**Motion trace** (`rest_lab -- --trace`, the hips socket every physics frame at 60 Hz):
- Sit: the hips glide from 1.08 m to 0.34 m above the ground over 1.0 s, then hold. The largest step between two
  frames is 5.6 cm, on the first frame, where idle hands over to `sleep_down` without a blend. The base's Sleep has
  the same hand-over.
- Stand: the hips glide from 0.35 m to 1.14 m over 1.0 s. The largest step is 5.8 cm, where `sleep_up` hands over to
  idle while the visual rises over 0.25 s.
- The hips never go below 0.34 m, so she does not sink into the ground. There are no jumps of 10 cm or more.

After shots (windowed, the real HUD):
`/private/tmp/claude-501/-Users-milankinzy-Documents-deadfront-siege/72cebc8b-d241-430b-9ea6-94d65339bfef/scratchpad/rest/shots/after/{1600x900_glc,1600x900_fwd,844x390_glc,844x390_fwd}/`:

- `open_hexes`: standing in the open, the Rest hex with its white icon at the bottom right.
- `open`: seated in the open, with the chip "Resting / +1.8 HP/s / -6 fatigue/min" under the Claim hex.
- `fire`: seated beside the bonfire, facing it, with the chip "Resting by the fire / +2.8 HP/s / -15 fatigue/min".
- `tent`: seated by the tent ("Resting in shelter / +3.8 HP/s / -30 fatigue/min").
- `tent_sleep`: lying by the tent with the "Sleeping" chip and the shelter rates.
- `tent_tap`: seated at 4 s, the same as `tent`. The shot comes before the tap at 5 s. The stand-up after the tap is
  in the numbers above and in t_rest.

These are from the merged tree, so they include HUD-DAYNIGHT's dial, which sits left of the minimap and clears the
chip and the box. I looked at every PNG. Forward+ and gl_compatibility differ only in terrain tone. At 844x390 the lab runs without
touch, so it uses the compact desktop layout. The chip and box sit under the minimap there, and the rate text is the
HUD's small meta size, the same as the map coordinates. On a touch phone the status row moves under the vitals panel,
and the box follows it.

## Test

`game/tests/t_rest.gd` (run: `godot --headless --path game --script res://tests/t_rest.gd`). It checks:
- the Rest hex at all three places, the X key, and the icon;
- Sleep raising HP and lowering fatigue while still asleep;
- the seated frame, grounding and no sliding;
- HP and fatigue rates per place within 6 % of the data (passive regen off, fatigue gains added back from the log),
  and open < fire < shelter;
- the clamps, and the chip's "HP full" and "Rested";
- sit to sleep;
- stand-up on a move key, a tap, damage, a hit, and a velociraptor targeting her;
- refusals after a hit and while bleeding;
- Wet cleared and the climate multipliers by the fire;
- the HUD drawing the rates block;
- the online `act.rest` intent and the X key toggle;
- a save mid-rest that reloads seated with the saved HP and fatigue.

On the unchanged base (scratch tree `rest-base` at ddaab662 plus only t_rest.gd) it fails 8 checks with no SCRIPT
ERROR: no Rest hex at any of the three spots, no X key, no icon, no Health or fatigue change while asleep, and no
RestState. On the package it passes.

## Gates (work tree with the hooks applied)

Run on the merged tree (946da955 plus the package), the patch applied, through `gslot.sh`. Logs are in
`/private/tmp/claude-501/-Users-milankinzy-Documents-deadfront-siege/72cebc8b-d241-430b-9ea6-94d65339bfef/scratchpad/rest/gates2/`.

- All 24 `game/tests/t_*.gd` PASS: t_ai, t_build, t_canim, t_combat, t_data, t_daynight_dial, t_harbour, t_iconart,
  t_items, t_light, t_lighting, t_occlude, t_player, **t_rest**, t_save, t_server_domain, t_srvdom, t_structart,
  t_tame, t_ui, t_uiicons, t_w2_skills, t_water, t_web.
- 0 SCRIPT ERROR everywhere except t_save, which prints its 5 deliberate ones.
- t_uiicons covers the new icon: it is drawn from `_src` (build.py --check), white on the 64 grid, inside the weight
  band, and matches no other silhouette.
- `run_all`: `[tests] PASS`, 0 SCRIPT ERROR.
- `tools/smoke.sh --no-import`: `SMOKE PASS`.
- Labs I touched: `rest_lab` ran headless, with `--trace`, and windowed at 1600x900 and 844x390 in both renderers,
  with 0 SCRIPT ERROR in every run.
- The same set also passed before the 946da955 merge (`gates1/`, 23 tests then).

## Assumptions (the docs are silent; each is marked in data or code)

- The rates in the table above, and that `hp_per_s` adds to the passive 0.8 HP/s. Source: `data/rest.json` `_note`.
- Reach: 3.0 m to a fire, and 3.2 m to shelter (the Sleep hex's reach).
- "Lit fire" means any Bonfire node. Bonfires and stone fire pits always burn, and a placed campfire exists only while
  it burns.
- Shelter is a building kind on the list. The game has no closed-house test yet (W2-CONSTRUCT, spec 10:108), so a
  house kind joins `shelter_kinds` when houses exist. Comfort and furniture bonuses (spec 10 section 5) are not
  modelled.
- Sleep recovers at the shelter rate while asleep, and an interrupted sleep keeps that. The old comment's "no partial
  restoration on interruption" is replaced.
- Rest is refused while a status deals damage, because its ticks would stand her up every 0.5 s.
- Wet is cleared once when she sits down by the fire. Rain puts it back, as rain does anywhere.
- The seated pose is `sleep_down` at 1.0 s, and the stand-up is `sleep_up` from 0.68 s. The rig has no dedicated sit
  clip.
- The desktop key is X. There is no gamepad binding.

## Not done, and what the next agent needs

- **Offline rest.** PRD :118 says a residence rest can run while logged off. The save keeps the rest state, but no
  offline catch-up is applied on load. `SaveGame._apply` already computes `elapsed` for fields, so this could be one
  `rest.recover(place, elapsed)` once the rule (which places, what cap) is decided.
- **The server side of `act.rest`.** Like drink and wash, the intent is only queued. The server domain needs a handler
  when W3-SRVACT lands.
- **A dedicated sit clip.** The held `sleep_down` frame reads as sitting back on one arm. A sit-on-a-log clip would
  look better by a fire.

## Hooks (`claude-mmo-rest-hooks.patch`, 11 files)

| File | Change |
|---|---|
| `player_sim.gd` (W2-PLAYER) | `var rest: RestState`; `rest.tick()` after the sleep branch; Sleep recovers at the shelter rate; `start_sleep` ends a rest without a stand-up; `interrupt_sleep` (hurt or dead) ends a rest with one; autofeed waits while resting |
| `player_input.gd` (W2-PLAYER) | the Rest context hex (not while resting or asleep), `context_action("rest")`, the `rest` key action |
| `player_actions.gd` (W2-PLAYER) | `rest()`: the `act.rest {on}` intent online, `RestState.start/stop` offline |
| `player_anim.gd` | `sit()`, `stand_up()`, `is_sitting()`; a hit while seated plays the stand-up; Sleep from the sit continues the clip |
| `player.gd` | climate fatigue times `sim.rest.climate_mult(group)` (PRD :285) |
| `save_game.gd` | writes `player.resting`, and a load resumes the rest when it is a real `true` |
| `input_setup.gd` | `"rest": [KEY_X]` |
| `hunt_hud.gd` | the Resting chip first in the status row, through the one `HudStatusChip.draw` call t_uiicons requires, plus the rates box |
| `fatigue_panel.gd` | the Time-awake remedy names Rest |
| `ui_icons.json` | `rest`, `resting` → `rest.svg` |
| `_src/build.py` | `icons_k` in `MODULES` and `SOLID` |

`vitals.gd` and `statuses.json` needed no change. Rest uses `Vitals.heal` and `Vitals.rest`, which already clamp.
The chip is drawn from RestState rather than as a status, so it takes none of the three status slots and cannot push
out Dirty, Clean or a debuff.
