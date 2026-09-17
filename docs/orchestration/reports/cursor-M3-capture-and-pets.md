# Cursor M3 — capture and pets

Knockdown is the capture window. A tamed velociraptor keeps the wild stat block (R2).

## What shipped
- Groggy + another hit → `knockdown` clip, capturable for 4 s. Tactic 4 shows **Net** when the player holds a sufficient-tier net and the matching `capture_technique` node.
- `data/skills/survival.json`: `capture_technique_I..V`, `animal_management_I..IV` (base bonded cap 3, +1 each, max 7). F7 toggles nodes. `# ASSUMPTION:` no SP economy.
- Net chance = tool-tier base (I 35% … V 75%, `# ASSUMPTION:`) × (1.5 − HP fraction), clamp 5–90%. Success → `captured_animal` (4 slots) with species/variant/grade_seed. Fail → knockdown ends, `enraged` +20% attack for 20 s.
- `BuildPlacer`: 1 m snap ghost, red on overlap. C places `makeshift_taming_pen` (4 branch + 2 twine). Bonfire is also placeable.
- Taming pen: 30 real minutes × `Game.time_scale` (F8 = ×60). Feed carnivore meat shortens. `# ASSUMPTION:` 70% success; grade S/A/B/C changes hunger efficiency and pet XP rate only.
- Bond into `Player.bonded`. F9 bond, F10 summon/dismiss. `PetBrain` follows, attacks hunt target, Hold body-blocks. Hunger `# ASSUMPTION:` `0.4 * wild HP`; at 0 the pet skips combat.
- Mount: `interact` on a pet whose `tamed_role` includes `mount`. Bag: `# ASSUMPTION:` 10 slots if JSON has no `bag_slots`.

## Lab output (PRD §24 test 6, headless)
```
[status] velociraptor +groggy x1
[status] velociraptor +knockdown x1
[capture] velociraptor attempt p=0.23 → success
[capture] velociraptor attempt p=0.24 → fail
[status] velociraptor +enraged x1
[capture] pen start velociraptor
[capture] pen velociraptor escaped
[capture] pen start velociraptor
[capture] pen velociraptor B
[capture] bonded velociraptor grade=B hp=640 atk=95 def=40 spd=700
[capture] summoned velociraptor hp=640 (wild hp=640)
[capture] mounted velociraptor
```
Wild `velociraptor.json` is hp 640, attack 95, defense 40, speed 700. Bonded and summoned values match.

## Reproduce
```
/Applications/Godot_mono.app/Contents/MacOS/Godot --path game -- --lab=capture_lab
```
Club to groggy, second hit to knockdown, 4 = Net. C = place pen, E = insert / feed. F8 time scale, F7 skills, F9 bond, F10 summon, E on the pet to mount.
