# Cursor milestone M2 — hunt combat and status effects

Combat here is a hunt overlay: auto-attack plus weavable tactics, telegraphed heavy attacks, a timed roll, and status effects that are readable on the model, not only in the HUD. Bleed is the currency of the raptor slice.

## Read first
- `AGENTS.md`, `docs/orchestration/plan.md`, your M1 report
- `docs/prd/dinosaur-roster-and-3d-pipeline.md` §3 (all status numbers and rules; this is the spec) and §2.1 (which species applies what)
- `docs/prd/durango-wild-lands-systems-prd.md` §6.1–6.4 (vitals), §10.2–10.5 (hunt), §21 item 9 (UX)
- `scripts/creatures/creature_anim.gd` signals from M1

## Tasks

1. **Vitals** component (`scripts/combat/vitals.gd`) on the player: Health, Energy, Fatigue with max values and slow auto-regen for Health and Energy (PRD §2.3). Fatigue only accumulates in this milestone (walking, gathering, taking damage) and triggers `exhausted` at max (evasion/accuracy −80%, gathering disabled). Food and rest come later.

2. **Statuses as data**: fill `game/data/statuses.json` with every row of roster PRD §3.1 and §3.2 plus Durango's kept ones (dizziness, groggy, knockdown): id, dps, duration, max_stacks, flags (`blocks_regen`, `no_sprint`, `no_roll`, `cannot_act`, `hide_telegraphs`), stat multipliers (move, defense, accuracy), `weakness_rank` (for the cap rule), `cleared_by[]`, `fx` (particle/tint/limp/mute). Numbers come from the PRD tables, not from your head.

3. **StatusEffects** component (`scripts/combat/status_effects.gd`) usable by player and creatures: `apply(id, source)`, stacking up to `max_stacks`, refresh on reapply, tick DoT every 0.5 s, expose aggregate multipliers and flags. **Cap of three simultaneous debuffs; the fourth replaces the lowest `weakness_rank`.** Bleed that expires untreated has a 25% chance to apply `infected_wound`. Print `[status] <target> +<id> x<stacks>` and `-<id>`.

4. **On-model FX**: bleed and deep bleed → GPUParticles3D drip at the hit point plus albedo darkening on the model; venom → green tint; fracture → locomotion blend time scale 0.65 and a lean; deafened → the telegraph ring does not render and the master audio bus is lowered; groggy → wobble; knockdown → the `knockdown` clip. Every status also gets a HUD icon with a timer and stack count.

5. **Hunt overlay** (`scripts/combat/hunt.gd`): a hunt starts on aggro or on `tap` over a creature (long-press optional). Auto-attack ticks at the equipped weapon's rate (add `attack_rate`, `damage`, `damage_type` slashing/blunt, `is_work_tool` to weapon ItemDefs; work knives fight badly). Damage = attack − defense × 0.5, floor 5% of attack; blade crits apply `bleeding_target`. Tactics bar with four slots bound to `tactic_1..4`: Body Tackle (Groggy, 8 s cooldown), Kick (knockback), Roll (`roll` action, 0.4 s invulnerability, blocked by `no_roll`), and an empty slot reserved for Net in M3. Chase/Hold toggle. Directional bonus: hits from behind +25%.

6. **Telegraphs**: on a creature's `attack_windup`, draw a yellow ring decal at the impact point sized to the attack; rolling out of the ring before `attack_hit` avoids the hit and prints `[combat] dodged <species> <clip>`.

7. **Species attacks apply statuses** from `status_applied`: velociraptor pounce (`attack_heavy`) → knockdown + bleed x2; deinonychus rake → bleed x3; utahraptor claw → deep_bleed (stacks). Wire through a `CreatureAttack` resource keyed by clip so the JSON can later override per species.

8. **Counters as items**: `bandage` consume clears bleed; `pressure_dressing` clears deep bleed; a `bonfire` world node with an interact verb "Cauterise" clears deep bleed for 5 HP. Blood trail: creatures with `bleeding_target` drop a small decal every 1.5 m for the duration so a fled animal can be tracked.

9. **Lab** `scenes/dev/hunt_lab.tscn`: player with a stone knife and 3 bandages, a bonfire, a velociraptor pack of 3, one utahraptor 40 m away. Debug keys: F5 applies four different statuses to the player in a row (to prove the cap), F6 heals.

## Acceptance
- `tools/smoke.sh` passes.
- A hunt against the pack is winnable with the bandages and a roll on the pounce; losing is possible if you ignore both. Paste `[combat]` and `[status]` lines from `get_debug_output` in the report.
- F5 shows three icons, then the weakest is replaced by the fourth.
- Deep bleed from the utahraptor visibly stops health regen until cauterised.
- Write `docs/orchestration/reports/cursor-M2-hunt-and-status.md`.
