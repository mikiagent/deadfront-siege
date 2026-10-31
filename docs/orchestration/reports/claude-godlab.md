# claude-godlab: fight lab with GOD mode (2026-10-30)

Branch `claude/mmo-godlab` (from `origin/claude/mmo-overhaul` eb564e56). Not merged to canon.

## Shipped
- `Game.god_mode` (dev-only flag, `game/scripts/core/game.gd`): set by `--god` only beside a `--lab=` (not
  `--lab=tutorial`), or by the creature lab, which turns it on by default and off in `_exit_tree`. Never saved.
- Single choke point `game/scripts/combat/vitals.gd`: `take_damage` emits `damaged` but costs nothing (no death);
  `spend_energy` / `spendable_energy` / `drain_energy` always succeed for free; `add_fatigue` adds nothing.
  The creature lab's old per-frame refill (max_health 1e6, energy, fatigue) is gone.
- Creature lab (`lab_spawn_panel.gd`): GOD button (key G), NEXT button (key T): clears wild animals, spawns the
  next species of the list as one Aggressive animal 8 m ahead and `brain.on_aggro(player)`. Picker lists
  `CreatureDef.has_model` species only, "Stand-ins: off" toggle adds the rest. An info line after each spawn
  shows brain, archetype, verb, moves (tactics steps or the brain's fixed moves) and authored fight clips
  (plus contract clips missing, which play idle). Alpha toggle unchanged. All new buttons 64 px.
- With `--god`, F is the real attack (hunt, tactics) instead of the lab's flat 100 damage.
- `tools/fight_lab.command` (executable): runs the canon worktree `mmo-overhaul` windowed with
  `-- --lab=creature_lab --god --skip-charcreate`. Documented in HANDOFF.md section 4.
- `docs/current/fight-lab.md` (+ README row): launch, controls, the 15 modelled species with brain/moves/clips
  and an empty verdict column.

## Gates
t_godlab PASS, t_combat PASS, t_canim PASS, t_labspawn PASS (updated for the modelled-only default),
run_all `[tests] PASS`, `tools/smoke.sh --no-import` SMOKE PASS. Off-screen shot: GOD ON, raptors biting,
survivor 100/100.

## Notes for the next agent
- The launcher points at the canon worktree: Milan sees GOD/NEXT only after this branch is merged there.
- CreatureBrain species (ankylosaurus, coelophysis, gallimimus, megaloceros, stegosaurus) only swing
  attack_primary/attack_heavy; their kick/charge clips never show in a fight.
- NEXT uses the Aggressive nature (tactic cooldowns x0.7, its own nature knobs); that is the game's
  "aggressive", not a neutral baseline.
- Credits spent: 0.
