# dsc — AUTOABILITY (2026-10-29)

Owner ask (verbatim): "there should be an auto-ability button that uses the player's most powerful
ability off cooldown and prioritizes that over basic attacks" and "put that on by default".

## What shipped

- **`game/scripts/combat/auto_ability.gd`** (new): `AutoAbility` — `rows()` reads the data-driven
  candidate list, `pick(hunt)` returns the best ready ability (highest damage per cast, tie-break
  longer cooldown; skips rows on cooldown, unaffordable, out of body-edge reach or out of line of
  sight), `try_cast(hunt)` casts it through `CombatTactics` (same damage/stagger/lock/cooldown as the
  manual press) and returns whether it fired.
- **`game/data/combat_tuning.json`** new `"auto_ability"` section: `abilities` rows
  `{id, damage, cooldown, energy, tune, auto}`. Tackle (6 dmg, 8 s, 15 energy) and Kick (4, 6 s, 10)
  are `auto:true`; Roll and Net are listed `auto:false` (utility stays manual). Adding an ability to
  the auto-rotation is one data row, no code.
- **`game/scripts/combat/hunt.gd`**: `Hunt.auto_ability = true` — ON by default for new and loaded
  games; `last_auto_cast` records what the auto-cast chose (tests/HUD). `_process` tries
  `AutoAbility.try_cast(self)` before `_auto_attack()` only when the basic swing is off cooldown and
  not pending. The existing priorities are untouched: a click-to-move order, the movement stick, a
  roll, a hurt stun and `cannot_act` all return before the hook (the same rules the auto-attack has).
- **`game/scripts/combat/combat_tactics.gd`**: tackle/kick set `h.last_auto_cast`.
- **`game/scripts/combat/vitals.gd`**: `spendable_energy()` read-only gate beside `spend_energy` so
  the picker checks affordability without spending or tripping the regen lock.
- **HUD**: `_auto_ability_hex` in `hunt_hud.gd` — a 64 px HexButton captioned AUTO-ABILITY next to
  AUTO (same `_combat_style`), visible in the combat layer, selected state mirrors the flag. Placed
  in all three layouts of `hud_layout.gd`: desktop left of AUTO, landscape phone between FEED and
  AUTO, portrait phone right of FEED.
- **Docs**: `docs/current/controls.md` "AUTO-ABILITY" section; assumption log
  `docs/vision/WildLandsMMO_Open_Questions.md` §AUTOABILITY (A1-A5).

## Save format: NOT touched (no additive field needed)

The task said to store the setting where AUTO's setting lives and flag an additive field if it was
the save. AUTO's setting is **not saved either**: `Hunt.auto` is a runtime field, reset per session.
AUTO-ABILITY follows the same pattern (`Hunt.auto_ability`, default `true`), so there is no save
migration and no save-sanitizer change. If the owner wants the toggle to survive a reload, both
flags should move into the save together.

## Verification

- `game/tests/t_autoability.gd` (new) prints `[t_autoability] PASS` — 7 checks: data rows load,
  default ON, a ready ability casts before any basic swing (swings==0), tackle on cooldown -> kick,
  both on cooldown -> basic attacks only, toggle off -> basic attacks only, picker ranks tackle over
  kick. Run: gslot.sh Godot --headless --path game --script res://tests/t_autoability.gd.
- Verify gate: `bash .../verify_autoability.sh` -> VERIFY PASS (t_autoability, t_combat, t_controls,
  t_targetui, run_all, smoke, report present).
- Credits spent: 0 (no Meshy, no image generation).

## Failures worth remembering

- A GDScript lambda captures locals **by value**: a swing counter must live in an Array the lambda
  mutates (`n[0] += 1`), `n += 1` inside `connect(func...)` never reaches the test.
- `--check-only --script` cannot resolve autoloads (Data/Game/World errors are noise) and needs a
  `--import` run after adding a `class_name`, else the global class cache misses it.
- The five gslot slots are shared across agents; the gate waits for a free slot. Never pipe Godot
  output; log to a file.

## Next agent

- The AUTO-ABILITY hex uses the AUTO icon (`data/ui_icons.json "auto"`); give it its own icon/symbol
  when the icon pass happens.
- When a real ability system lands (skills/gear powers), add rows to `auto_ability.abilities` with
  `auto:true` and a damage expression; `AutoAbility.pick` already handles cooldown/energy/reach.
- If "most powerful" should count status effects (groggy value, knockdown), extend the row with a
  `value` field and rank on it — the picker is the only place to change.

## Re-merge (2026-10-30, integrator follow-up)

Canon moved (FOODTORPOR, SLOWLEVELS, CREATURECHIPS, CHASESPRINT, STYRATACTICS landed on
`origin/claude/mmo-overhaul`), so the branch re-merged it (merge commit `b195a71e`).

- Conflicts in `docs/current/controls.md` and `docs/vision/WildLandsMMO_Open_Questions.md` only;
  both resolved keeping BOTH sides: controls.md now has AUTO-ABILITY followed by Chase sprint
  (before Full screen); Open Questions keeps AUTOABILITY, TASKSCREEN and STYRA together.
- Everything else auto-merged: `hunt.gd`/`auto_ability.gd`/`combat_tuning.json "auto_ability"`
  and the HUD hex all intact; canon code (CHASE_SPRINT, CreaturePlateChip, spoilage) present.
- One environment gotcha, not a code change: the 180-file merge left the `.godot` class cache
  stale, so the first gate run failed every test with "Identifier "TribeWork" not declared"
  cascades. Re-imported headless (`--import`) and all green.
- Re-ran the gate after the merge: **VERIFY PASS** (t_autoability, t_combat, t_controls,
  t_targetui, run_all, smoke all pass; log `/tmp/autoability_verify/`). `tools/smoke.sh
  --no-import` standalone: SMOKE PASS. t_autoability: `[t_autoability] PASS` exit 0.
- No new feature changes in this pass; the feature shipped at 564047c3 and behaves as before.
