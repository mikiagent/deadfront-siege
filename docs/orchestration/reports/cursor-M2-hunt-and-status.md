# Cursor M2 — hunt and status

Hunt overlay, status data, on-model FX, counters, and `hunt_lab`.

## What shipped
- `Vitals` on the player (Health / Energy / Fatigue). `# ASSUMPTION:` Health regen 1.5/s, Energy 2/s while not `blocks_regen`. Fatigue from walking, gathering, and damage; `exhausted` at max.
- `data/statuses.json` filled from roster PRD §3.1–3.2 plus dizziness / groggy / knockdown, plus `enraged` for M3 net-fail.
- `StatusEffects`: stack, refresh, 0.5 s DoT tick, cap 3, 4th replaces lowest `weakness_rank`. Untreated bleed → 25% `infected_wound`.
- FX: drip particles + darken (bleed), green tint (venom), limp timescale 0.65 (fracture), mute flag hides telegraphs (deafened), wobble (groggy). HUD icons with timer + stacks.
- Hunt: tap creature to start. Auto-attack from equipped weapon (`attack_rate`, `damage`, `damage_type`, `is_work_tool`). Damage = attack − defense × 0.5, floor 5%. Behind +25%. Blade crit 25% → `bleeding_target`. Blunt 35% → groggy. Tactics: 1 Body Tackle, 2 Kick, Space roll (0.4 s i-frames), 4 reserved for Net. H toggles Chase/Hold. B uses bandage.
- Telegraph ring on `attack_windup`; rolling inside it prints `[combat] dodged`.
- Species tokens: velociraptor heavy → bleed ×2 + knockdown; deinonychus bleed ×3; utahraptor `deep_bleed`.
- Bandage / pressure dressing / bonfire cauterise (−5 HP). Blood trail decals every 1.5 m while `bleeding_target`.

## Lab output (F5 cap, then pack pounce)
```
[status] Player +groggy x1
[status] Player +dizziness x1
[status] Player +bleed x1
[status] Player -groggy
[status] Player +venom x1
[combat] hunt start velociraptor
[status] Player +bleed x3
[status] Player +knockdown x1
[combat] velociraptor hit player dmg=85.0 clip=attack_heavy
```
F5 applies groggy, dizziness, bleed, then venom; groggy (weakness_rank 1) is the one that drops. Deep bleed from utahraptor sets `blocks_regen` until cauterise / pressure dressing.

## Assumptions
- Work-tool weapons deal ×0.45 damage.
- Player innate defense 20 for incoming creature hits.
- Blunt groggy chance 35%; slash bleeding_target chance 25%.

## Reproduce
```
/Applications/Godot_mono.app/Contents/MacOS/Godot --path game -- --lab=hunt_lab
```
F5 = cap test, F6 = heal, B = bandage, Space = roll on the pounce ring.
