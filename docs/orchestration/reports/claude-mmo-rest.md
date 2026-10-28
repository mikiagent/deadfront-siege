# claude-mmo-rest: Rest sits you down, heals you and lowers exhaustion

Owner, verbatim: "resting should sit you down and heal you and lower exhaustion. I tried this on vercel and it didn't
work". Production is `31c064a08` (stamp `31c064a08/2284b9bf56`) on `claude/mmo-overhaul`.

Branch `claude/mmo-rest`, cut from `claude/mmo-overhaul` at 2206de22. It merges ddaab662, then 946da955 (HUD-DAYNIGHT,
merge `9706364d`), then 809be2e8 (W2-DATA sync, docs only), then acc684a6 (STATUS docs only, merge `a0a8527d`).
WATER, which the brief says is "merging now", was merged and its hooks applied before 809be2e8 (`c5f1db63`,
`3abc6503`; its hooks patch reverse-applies on acc684a6), so this branch already builds on it. Commits:

- `6241b962` rest_lab, the reproduction lab (committed before any game change)
- `4aa06fd3` RestState, `data/rest.json`, the rest icon, t_rest, the lab's Sleep trial and motion trace
- `09b119a5` the icon's import settings, the sit-to-sleep test case, the lab's hex shot and frame trace
- `9706364d` merge of `claude/mmo-overhaul` 946da955
- `3dab2bae` round-1 report and hooks patch
- fix round 1: `b52165d9`, `77b24c12`, `c8f6d9cb`, `329d1748`, merge `a0a8527d`, and this report and patch

The call sites are in files other packages own, so the branch does not commit them. They ship as
`docs/orchestration/reports/claude-mmo-rest-hooks.patch` (12 files, 114+/8-). `git apply --cached --check` passes
on the branch head and on `claude/mmo-overhaul` at acc684a6. The work tree has the patch applied, and every gate below
ran with it applied on the merged tree. `rest_state.gd`, `hud_rest_box.gd` and `t_rest.gd` depend on the patch, so
the branch and the patch must land together.

Credits spent: none. No Meshy, no Tripo, no downloads.

## Fix round 1

| Finding | Severity | What changed | Check |
|---|---|---|---|
| A damage-over-time status blocked every way to recover. A raw-meat Stomachache (300 s, 0.2 dps, no cure) refused Rest ("Treat your stomachache before resting.") and its first tick ended Sleep with no notice. | major | Status ticks no longer refuse, stand up or wake. `StatusEffects` sets `ticking` around a DoT tick on a Player, and `Player._on_vitals_damaged` returns early on a tick while she rests or sleeps. Creature hits still end both (they are not ticks). `refusal()` drops the DoT loop and keeps `blocks_regen`, which still stops the rest healing. | t_rest `_test_status_ticks`: with a Stomachache the Rest hex sits her down at the tent, she is still seated after 4.5 s of ticks, Health rises at 3.0 - 0.2 = +2.8/s and fatigue falls; a real hit still stands her up; Sleep at the tent with a Stomachache completes (fatigue 60 to 0.01). `_test_refusals`: Rest is allowed while bleeding. |
| Same, as the acceptance line "Rest always available out of combat". | major | As above. Rest is refused only in combat, mounted, rolling, knocked down, in water, already asleep, or dead. | as above; lab trials `tent_sick` and `tent_sleep_sick` |
| The chip showed the rest rate, not what she nets. | (part of the major) | `RestState.net_hp_per_s()`: the place's rate plus passive regen, less what her statuses deal. A DoT tick also pauses passive regen (vitals.gd REGEN_LOCK_S), so passive counts only without one; `blocks_regen` leaves only the loss. The chip names the cause: "+2.8 HP/s (stomachache)", "-1.2 HP/s (stomachache, deep bleed)" in red. | t_rest: the chip reads "+2.8 HP/s (stomachache)" and, with a Deep Bleed, starts with "-" and names it |
| A load only ever started a rest. A save made standing loaded seated if she was resting at the time. | minor | `save_game.gd` calls `rest.load_saved(saved)`: if she is resting it stops without a clip and resets the pose (`anim.revive()`), then sits her down only for a real `true`. | t_rest: save standing, sit down, load: `resting=false clip=idle visual_y=0.00` |
| The rates box drawing was inline in hunt_hud.gd (+22 lines). | minor | New `scripts/ui/hud_rest_box.gd` (`HudRestBox.chip()` and `HudRestBox.draw()`). The hunt_hud hunk is now 8 lines: the chip, then one call for the box. The chip goes through `HudRestBox.chip`, so hunt_hud keeps its two `HudStatusChip.draw(` rows, which t_uiicons counts. | t_rest: the HUD draws `rest`; t_uiicons PASS |
| On desktop the box sat below the Claim hex's slot even when no Claim hex was there, about 75 px under its chip. | minor | The offset applies only when the HUD's context row holds `claim` (and not on a landscape phone). Otherwise the box starts right under the chip row. | t_rest: by the fire (no Claim) the chip row ends at 282 and the box starts at 280; in the open the box (y 324) clears the Claim hex (y 232-302). Shots `fire` and `open`. |
| Open-ground rest healed 1.8 HP/s, making medicine nearly redundant. | minor | `rest.json` open `hp_per_s` 1.0 to 0.3, so 1.1 HP/s with passive (40 to 74 HP in 30 s). Fire and shelter keep 2.8 and 3.8 as the bonuses. | t_rest rate check reads the data: open +0.30/s |
| Only the place changed the rate; spec 01:19 also names hygiene and conditions. | minor | `RestState.fatigue_per_min()` divides the place's fatigue recovery by `statuses.fatigue_mult()`, the existing data WATER added (Dirty 1.2, Very Dirty 1.5, Thirsty 1.2, Clean 0.8). Dirty at the tent: 30 to 25/min, and the chip says "-25 fatigue/min (dirty)". | t_rest `_test_rate("shelter", dirty)`: fatigue -25.00/min, chip names it |
| The Rest hex showed where it is always refused: mounted, in water, with a ticking status. | minor | Partly wrong: mounted, `context_actions()` already returns only Dismount, so the Rest hex never showed there. In water it did; `RestState.offered()` now hides it. With a ticking status Rest is now allowed. | t_rest: in water the hexes are `["claim"]` |

The new t_rest fails 13 checks on the round-1 code (scratch tree `rest-r1` at 3dab2bae with the round-1 patch, only
t_rest.gd replaced), with no SCRIPT ERROR: the dirty rate and chip, allowed while bleeding, the hex in water, the five
Stomachache checks, the Sleep with a Stomachache, the box under the chip row, and the standing load. Log:
`.../scratchpad/rest/fix1/t_rest_round1.log`.

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

There are four causes:

1. **There was no Rest.** Sleep was the only recovery verb, and its hex only shows within 3.2 m of a tent or straw roll.
   Open ground offered Claim and the bonfire offered Cook. The fatigue panel said "rest between harvests", but there
   was no verb for it.
2. **Sleep gave nothing until its last frame.** It added no healing on top of the passive rate and held fatigue flat
   for the whole 10 s.
3. **Any input cancelled Sleep for nothing.** A click on the ground, a WASD key or a hit in those 10 s showed "Sleep
   interrupted" and kept nothing.
4. **Any status tick cancelled Sleep** (found in review). On production, `Player._on_vitals_damaged` ends a sleep on
   every damage, and a Stomachache, Bleed or Venom ticks every 0.5 s. A survivor who had eaten raw meat in the last
   5 minutes was woken within half a second, with no notice.

I can't know which of these the owner hit. Each one reproduces "it didn't work".

Before shots (production 31c064a08):
`/private/tmp/claude-501/-Users-milankinzy-Documents-deadfront-siege/72cebc8b-d241-430b-9ea6-94d65339bfef/scratchpad/rest/shots/before/{1600x900_glc,1600x900_fwd,844x390_glc}/{open,fire,tent,tent_tap}_<w>x<h>.png`.

## What ships

- **A Rest action everywhere out of combat.** It has a context hex (white seated-figure icon, caption REST) and the X
  key on desktop. Online it is an `act.rest {"on": bool}` intent through `PlayerActions.rest()`, so a retried send
  cannot flip the state back. While she rests the hex hides, as Sleep's does; she gets up by moving. X toggles. The
  hex also hides in water, where Rest is refused (mounted, the context row shows only Dismount).
- **She sits down.** The seated pose is `sleep_down` held on its 1.0 s frame, where she sits up on one arm. Getting up
  plays `sleep_up` from its matching 0.68 s frame, and the visual rises as the clip ends. t_rest measures 0.000 m of
  drift over 2 s seated. Choosing Sleep at a tent while seated lies her down from the sit.
- **She recovers by place.** Rates are in `data/rest.json`, re-read twice a second while she sits:

  | Place | When | Health (with passive 0.8) | Fatigue |
  |---|---|---|---|
  | open | anywhere else | +0.3 HP/s (1.1) | -6 /min |
  | fire | within 3.0 m of a bonfire, stone fire pit or burning campfire | +2.0 HP/s (2.8) | -15 /min |
  | shelter | within 3.2 m of a tent, canvas tent, straw roll, log shelter or cabin bed | +3.0 HP/s (3.8) | -30 /min |

  The order follows spec 01:19, PRD :118 and PRD :803. The numbers are ASSUMPTIONS. Vitals clamps both values.
- **Conditions change the rates, they do not refuse the rest (spec 01:19).** A damage-over-time status (Stomachache,
  Bleed, Venom) comes off the Health rate and pauses passive regen. A Deep Bleed (`blocks_regen`) stops the rest
  healing. A status with a fatigue multiplier (Dirty, Very Dirty, Thirsty; Clean the other way) divides the fatigue
  recovery. Status ticks never stand her up or wake her.
- **The bonfire's sitting effects (PRD :285).** Sitting down by the fire clears Wet. While she sits there, heat fatigue
  is x1.2 and cold fatigue x0.8, through `Player.tick_climate_fatigue`.
- **Rest ends with the stand-up when** she moves (a move key, the joystick, a tap-to-walk), takes a hit, enters combat
  (she starts hunting or a creature hits her), or a creature whose brain targets her is in alert, approach, attack or
  retreat. Rest is refused, with the reason shown, within 5 s of a hit, while hunting or hunted, mounted, rolling,
  knocked down, in water or asleep. Autofeed waits while she rests.
- **The Resting chip (spec 01:22).** It is the first chip in the status row, drawn with the rest icon. A dark box right
  under the row shows what she nets, for example "Resting by the fire / +2.8 HP/s / -15 fatigue/min" or "Resting in
  shelter / +2.8 HP/s (stomachache) / -25 fatigue/min (dirty)". The Health line turns red when the net is a loss. It
  reads "HP full" and "Rested" at the limits, and "Sleeping" with the shelter rates while she sleeps. When the Claim
  hex stands beside the chips on desktop, the box goes below it.
- **Sleep at beds and tents.** While asleep she recovers at the shelter rate, so Health and fatigue move on screen.
  The completed sleep still gives its full restore. An interrupted sleep keeps what it gave. A bedding use is still
  spent only on completion.
- **Save and load (spec 01:22).** The save writes `"resting": true|false`. A load matches it: seated for a real
  `true`, standing (no clip, pose reset) otherwise. Health and fatigue come back as saved.
- The fatigue panel's "Time awake" remedy names Rest.

## After numbers (rest_lab headless, fix round 1, the work tree with the hooks applied)

| Spot | Hexes | Attempt | Pose at 5 s | HP over 30 s | Fatigue over 30 s |
|---|---|---|---|---|---|
| open | Rest, Claim | Rest hex | seated | 41 → 74 (1.1/s) | 60.02 → 57.58 |
| fire | Rest, Cook | Rest hex | seated | 41 → 97 at 20 s, 100 by 25 s (2.8/s) | 60.01 → 52.78 |
| tent | Sleep, Rest, Cook | Rest hex | seated | 41 → 100 by 20 s (3.8/s) | 60.01 → 45.27 |
| tent, Sleep hex | Sleep, Rest, Cook | Sleep hex | lying | 41 → 60 at 5 s, 79 at 10 s | 57.56 at 5 s, 0.00 at 10 s |
| tent, tap 5 s in | Sleep, Rest, Cook | Rest hex | seated, then up | 41 → 60 at 5 s, then passive | 57.56 kept at 5 s, then walking |
| tent, Stomachache + Dirty | Sleep, Rest, Cook | Rest hex | seated all 30 s | 40 → 54 at 5 s, 100 by 25 s (2.8/s) | 60.03 → 48.12 (-25/min less gains) |
| tent, Stomachache, Sleep hex | Sleep, Rest, Cook | Sleep hex | lying, sleep completes at 10 s | 40 → 68 at 10 s, then -0.2/s | 60.02 → 0.00 at 10 s |

Fatigue gains during each run were time (+0.32 to +0.65), walking after the tap, and +0.26 to +0.32 "combat" in the
Stomachache rows (vitals.gd adds 15 % of any damage as combat fatigue, ticks included).

Motion trace (`rest_lab -- --trace`, the hips socket every physics frame at 60 Hz): sitting, the largest step between
two frames is 5.7 cm and the hips never go below 0.34 m; standing, the largest step is 4.5 cm. No jump of 10 cm or more.

After shots (windowed, the real HUD, fix round 1):
`/private/tmp/claude-501/-Users-milankinzy-Documents-deadfront-siege/72cebc8b-d241-430b-9ea6-94d65339bfef/scratchpad/rest/shots/fix1b/{1600x900_glc,1600x900_fwd,844x390_glc,844x390_fwd}/`:

- `open_hexes`: standing in the open, the Rest hex (white icon) at the bottom right and Claim by the map.
- `open`: seated in the open; the chip "Resting / +1.1 HP/s / -6 fatigue/min" sits below the Claim hex.
- `fire`: seated beside the bonfire, facing it; the box right under the chip ("Resting by the fire / +2.8 HP/s /
  -15 fatigue/min").
- `tent`: seated by the tent ("Resting in shelter / +3.8 HP/s / -30 fatigue/min").
- `tent_sleep`: lying by the tent, "Sleeping" with the shelter rates.
- `tent_tap`: seated at 4 s, before the tap at 5 s.
- `tent_sick`: seated by the tent with the rest, Stomachache (295 s left) and Dirty chips, and "+2.8 HP/s
  (stomachache) / -25 fatigue/min (dirty)".
- `tent_sleep_sick`: lying by the tent with a Stomachache, "Sleeping / +2.8 HP/s (stomachache) / -30 fatigue/min".

I opened all 32 PNGs. Forward+ and gl_compatibility differ only in terrain tone. At 844x390 the lab runs without touch,
so it uses the compact desktop layout and the box text is the HUD's small meta size, as the map coordinates are. The
shots were taken before the last chip tweak (`329d1748`, no "(stomachache)" note after "HP full"); no shot is at full
Health, so no pixel in them depends on it.

## Test

`game/tests/t_rest.gd` (run: `godot --headless --path game --script res://tests/t_rest.gd`), 73 checks. It checks:
- the Rest hex at all three places, hidden in water; the X key; the icon;
- Sleep raising HP and lowering fatigue while still asleep;
- the seated frame, grounding and no sliding;
- HP and fatigue rates per place within 6 % of the data, open < fire < shelter, and Dirty dividing the fatigue rate
  by its fatigue_mult, with the chip naming it;
- the clamps, and the chip's "HP full" and "Rested";
- sit to sleep;
- stand-up on a move key, a tap, damage, a hit, and a velociraptor targeting her;
- refused after a hit, allowed while bleeding;
- a Stomachache: Rest sits her down and keeps her seated, net +2.8 HP/s, fatigue falls, the chip shows the net rate
  and why, a Deep Bleed turns it negative, a real hit still stands her up, and Sleep with it completes;
- Wet cleared and the climate multipliers by the fire;
- the HUD drawing the box right under the chip row without a Claim hex, and clear of the Claim hex with one;
- the online `act.rest` intent and the X key toggle;
- a save mid-rest that reloads seated, and a save made standing that loads standing.

On the unchanged base it fails (round 1: 8 checks, no Rest at all). On the round-1 code it fails 13 checks (above).

## Gates (work tree with the hooks applied, merged tree acc684a6 + package)

Run through `gslot.sh` on the tree that holds `329d1748` (merge of acc684a6 plus the package) with the patch applied.
Logs: `/private/tmp/claude-501/-Users-milankinzy-Documents-deadfront-siege/72cebc8b-d241-430b-9ea6-94d65339bfef/scratchpad/rest/gates5/`.

- All 24 `game/tests/t_*.gd` PASS: t_ai, t_build, t_canim, t_combat, t_data, t_daynight_dial, t_harbour, t_iconart,
  t_items, t_light, t_lighting, t_occlude, t_player, **t_rest** (73 checks), t_save, t_server_domain, t_srvdom,
  t_structart, t_tame, t_ui, t_uiicons, t_w2_skills, t_water, t_web.
- 0 SCRIPT ERROR everywhere except t_save, which prints its 5 deliberate ones.
- `run_all`: `[tests] PASS`, 0 SCRIPT ERROR. `tools/smoke.sh --no-import`: `SMOKE PASS`.
- `rest_lab` (the lab I touched): headless with `--trace`, exit 0, 0 SCRIPT ERROR, all seven trials and the motion
  trace. Sit: largest hips step 5.7 cm, hips never below 0.34 m. Stand: largest step 4.5 cm, ending in idle. No
  step of 10 cm or more. The windowed shot runs (1600x900 and 844x390, both renderers) also had 0 SCRIPT ERROR.
- An earlier full run this round (`gates3/`) caught t_uiicons failing on a third `HudStatusChip.draw(` in hunt_hud;
  `c8f6d9cb` moved the chip into `HudRestBox.chip`, and every gate above ran after it.

## Assumptions (the docs are silent; each is marked in data or code)

- The rates in the table above, and that `hp_per_s` adds to the passive 0.8 HP/s. Source: `data/rest.json` `_note`.
- Reach: 3.0 m to a fire, and 3.2 m to shelter (the Sleep hex's reach).
- "Lit fire" means any Bonfire node. Bonfires and stone fire pits always burn, and a placed campfire exists only while
  it burns.
- Shelter is a building kind on the list. The game has no closed-house test yet (W2-CONSTRUCT, spec 10:108), so a
  house kind joins `shelter_kinds` when houses exist.
- Conditions: fatigue recovery is divided by the existing `statuses.json` `fatigue_mult` (the factor by which the
  status speeds fatigue gain). Health is changed only by damage-over-time and `blocks_regen`. Wet is not a recovery
  multiplier (it already adds its own fatigue gain, and the fire clears it).
- Status ticks do not stand her up or wake her; only hits, fights and hunting creatures do.
- Sleep recovers at the shelter rate while asleep, and an interrupted sleep keeps that.
- The seated pose is `sleep_down` at 1.0 s, and the stand-up is `sleep_up` from 0.68 s. The rig has no sit clip.
- The desktop key is X. There is no gamepad binding.

## Not done, and what the next agent needs

- **Offline rest.** PRD :118 says a residence rest can run while logged off. The save keeps the rest state, but no
  offline catch-up is applied on load. `SaveGame._apply` already computes `elapsed`, so this could be one
  `rest.recover(place, elapsed)` once the rule (which places, what cap) is decided.
- **The server side of `act.rest`.** Like drink and wash, the intent is only queued.
- **A dedicated sit clip.** The held `sleep_down` frame reads as sitting back on one arm.
- **Comfort, furniture and temperature protection** (spec 01:19, spec 10 section 5) do not change the rates yet.
- **Net fatigue.** The chip shows the rest's fatigue recovery, not her net fatigue: a status with its own fatigue gain
  (Wet adds 30/min, Tastes Bad 50/min: `fatigue_per_min` x 100 per minute in `StatusEffects._dot`) can outrun it. The
  fatigue panel lists those gains. Those status gain values look high and belong to their owners.
- **Not mine, seen while testing:** a standing survivor with a damage-over-time status plays `hit_react` on every
  0.5 s tick (`Player._on_vitals_damaged` -> `_flinch`, unchanged from the base). The rest lab's motion trace caught
  it once, when a Stomachache leaked from the previous trial; the lab now clears statuses before the trace.

## Hooks (`claude-mmo-rest-hooks.patch`, 12 files)

| File | Change |
|---|---|
| `player_sim.gd` (W2-PLAYER) | `var rest: RestState`; `rest.tick()` after the sleep branch; Sleep recovers at the shelter rate; `start_sleep` ends a rest without a stand-up; `interrupt_sleep` (hurt or dead) ends a rest with one; autofeed waits while resting |
| `player_input.gd` (W2-PLAYER) | the Rest context hex when `rest.offered()`, `context_action("rest")`, the `rest` key action |
| `player_actions.gd` (W2-PLAYER) | `rest()`: the `act.rest {on}` intent online, `RestState.start/stop` offline |
| `player_anim.gd` | `sit()`, `stand_up()`, `is_sitting()`; a hit while seated plays the stand-up; Sleep from the sit continues the clip |
| `player.gd` | `_on_vitals_damaged` ignores a status tick while she rests or sleeps; climate fatigue times `sim.rest.climate_mult(group)` (PRD :285) |
| `status_effects.gd` | `ticking` is true while a damage-over-time tick lands on a Player |
| `save_game.gd` | writes `player.resting`; a load calls `rest.load_saved()` |
| `input_setup.gd` | `"rest": [KEY_X]` |
| `hunt_hud.gd` | 8 lines: the Resting chip first in the status row and one `HudRestBox.draw` call, below the Claim hex only when it is there |
| `fatigue_panel.gd` | the Time-awake remedy names Rest |
| `ui_icons.json` | `rest`, `resting` → `rest.svg` |
| `_src/build.py` | `icons_k` in `MODULES` and `SOLID` |

`vitals.gd` and `statuses.json` needed no change. The chip is drawn from RestState rather than as a status, so it takes
none of the three status slots.
