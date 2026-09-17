# Cursor milestone M3 — capture, taming pen, pets

The capture window is Knockdown; the reward is the same animal you fought. Design rule R2: **a tamed creature keeps its wild stat block**. It is balanced by upkeep, cooldown and the bonded cap, never by cutting HP.

## Read first
- `AGENTS.md`, `docs/orchestration/plan.md`, your M2 report
- `docs/prd/durango-wild-lands-systems-prd.md` §12 (pipeline, caps, functions, hunger) and §24 test 6
- `docs/prd/dinosaur-roster-and-3d-pipeline.md` §1 R2, §2.1 capture tiers, §3.2 (Groggy → Knockdown → capture)

## Tasks

1. **Knockdown as the capture window**: a `groggy` target that takes another hit is knocked down (`knockdown` clip, holds 4 s). While down, a creature is `capturable` and the reserved tactic slot shows **Net** if the player carries a capture tool of sufficient tier. Blunt weapons and Body Tackle raise groggy chance.

2. **Survival tree stub** `game/data/skills/survival.json`: nodes `capture_technique_I..V` (unlock species by `capture_tier`) and `animal_management_I..IV` (+1 bonded cap each, base 3, so 7 max). A debug panel (F7) toggles nodes; no SP economy yet, mark it `# ASSUMPTION:`.

3. **Net attempt**: chance = base by tool tier (I 35%, II 45%, III 55%, IV 65%, V 75%, `# ASSUMPTION:`) × (1.5 − HP fraction), clamped 5–90%, requires the matching technique node. Success removes the creature and adds a `captured_animal` ItemStack occupying 4 slots, carrying species, variant, and a hidden grade seed. Failure ends the knockdown early with the creature enraged (+20% attack for 20 s). Print `[capture] <species> attempt p=<chance> → <result>`.

4. **Build placement** (minimal, shared by M5 later): `scripts/world/build_placer.gd` shows a ghost of a building scene under the cursor, snaps to a 1 m grid, red when overlapping, consumes ItemStacks by category slot on confirm. Buildings: `makeshift_taming_pen` (branches + twine) and `bonfire` (from M2, now placeable).

5. **Taming pen**: holds one captured animal. Timer 30 real minutes scaled by a `Game.time_scale` debug multiplier; feeding species-appropriate food (meat for carnivores) shortens it. On completion roll success (70%, `# ASSUMPTION:`) and grade S/A/B/C affecting only hunger efficiency and pet XP rate, never base stats. Failure spawns the animal wild next to the pen and it flees. Print `[capture] pen <species> <grade|escaped>`.

6. **Bond, summon, pet**: a `tamed_animal` item bonds into `Player.bonded: Array[PetRecord]` up to the cap. Summon/dismiss from the inventory. A summoned pet is a `Creature` with `is_pet = true`: same stats, `PetBrain` follows the player, attacks what the player attacks, body-blocks when told Hold. Hunger budget per species drains over time; at zero the pet refuses combat but still follows.

7. **Mount and bag**: `interact` on a pet whose `tamed_role` includes `mount` attaches the player to a socket on the CreatureView and moves at the pet's `move_speed_mps`; `interact` again dismounts. Pets with `bag` in `tamed_role` (or any pet, 10 slots `# ASSUMPTION:`) expose an Inventory in the UI, and items on a pet do not drop on player death (death itself is M5).

8. **Lab** `scenes/dev/capture_lab.tscn`: player with a club, capture net I and II, branches and twine for a pen, raptor meat; a velociraptor pack; `Game.time_scale` bound to F8 (x60).

## Acceptance
- `tools/smoke.sh` passes.
- The PRD §24 test 6 sequence works end to end on a velociraptor: stunned, netted, penned, failed and retried, bonded, ridden, used as a bag. Paste the `[capture]` lines.
- A bonded velociraptor's HP, attack, defense and speed equal the wild values in `velociraptor.json`.
- Write `docs/orchestration/reports/cursor-M3-capture-and-pets.md`.
