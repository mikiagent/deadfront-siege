# Claude Code prompt | CONTINUE DEADFRONT, do not rebuild

**Use this instead of the new-project `M0-FOUNDATION` prompt in separate PR #19.** This version is intended for the already implemented and deployed `game/` project on `main`. The first task is compatibility/risk protection, not rebuilding a new engine.

## Copy into Claude Code

```text
You are the lead Godot engineer and systems integrator for DEADFRONT.
You are CONTINUING the EXISTING GAME, not starting from scratch.

Repository: https://github.com/mikiagent/deadfront-siege
Use the current origin/main as the code base, not old PR #19's clean rebuild.
Read, in order:
  docs/continuation/README.md
  docs/continuation/00-AS-BUILT-BASELINE.md
  docs/continuation/01-INCREMENTAL-ARCHITECTURE.md
  docs/continuation/02-COMPATIBILITY-AND-MIGRATIONS.md
  docs/continuation/03-SYSTEM-BRIDGE.md
  docs/continuation/04-INCREMENTAL-MILESTONES.md
  docs/continuation/05-FIRST-TICKET.md
  docs/continuation/06-REGRESSION-AND-RELEASE.md
  docs/continuation/08-DECISIONS-AND-RISKS.md
Then read HANDOFF.md, GAUNTLET.md, owner-confirmed entries in
docs/game-design/decisions.md and only the domain chapters actually
relevant to the current ticket. Verify against current code; do not
trust dated snapshot prose over current origin/main.

MANDATORY BASE:
- Reuse game/project.godot, res://shell/boot.tscn, the existing autoloads
  Data/Game/World/InputSetup/ShellLoader/TouchControls, main scenes,
  player scripts, existing item/creature systems, Godot 4.7 typed GDScript,
  the existing saved players, in-game UI and asset files.
- Preserve save_1.json, schema 3 migration chain and all saved progression,
  materials/levels, creatures/genetics, placed buildings, island/cargo,
  equipment, skills and real inventory counts.
- Keep existing test.sh, smoke.sh, dev labs, export, web pack/hash and
  Vercel deployment scheme. Do not create a parallel Godot game.
- Existing code is the baseline. New owner-confirmed design is the future
  goal, but requires additive adapters and explicit migration where needed.
- A design-only feature must never be reported as shipped.

BEFORE EACH CHANGE:
1. Fetch and record exact origin/main SHA; inspect current code and
   current user-visible behavior. Run baseline tests and record results.
2. State one bounded visible outcome, approved rule IDs, exact code
   owner/extension seam, old API and save schema fields to preserve.
3. Propose the minimum design math/contract required. Do not choose
   unapproved progression rates, loss policies or irreversible conversions.
4. Write red regression tests and expected old/new behavior and rollback.
5. Implement by extending current classes, maintaining existing call
   signatures and old-save fixtures. Extract narrow helpers rather than
   growing player.gd, island_runtime.gd or hunt_hud.gd.
6. Test existing full suite, smoke, relevant dev labs, migration and
   actual interactive pixels at desktop 1600x900; preserve touch.
7. Commit a small PR. Do NOT deploy to live production unless explicitly
   requested and the build/stamp/soak gates pass.

FIRST TASK: C0 (docs/continuation/05-FIRST-TICKET.md).
Protect schema 0-3 save compatibility and add non-destructive
recoverability for corrupt/interrupted/future-version save files.
Do not change any player-facing economy, combat, creature stats or
crafting mechanics in C0. Implement inside EXISTING game/scripts/core
and existing test infrastructure.

Only after C0 evidence is accepted propose C1 material-fusion extension
of the current Crafting.build_output(...) and ItemStack representation,
using legacy recipes without new fusion rules unchanged.

Report at finish:
- exact starting and resulting Git SHA
- specific current classes extended; old paths preserved
- exact tests run, outputs and failure information
- old-save/stack/crafting/UI compatibility proof
- screenshots/visual gate and deploy status (if authorized)
- gameplay decisions still OPEN and recommended next bounded ticket

Do not run the M0 fresh-build prompt or replace save root schemas.
```

## Short prompt for later C1 material fusion

```text
Implement continuation ticket C1A in the CURRENT DEADFRONT game, not
a rewrite. Read the owner-approved fusion rule version first. Preserve
Inventory.add/transfer_to semantics, ItemStack serialization+stacking,
Crafting._plan and build_output signatures, existing station recipe
behavior and old saved schema. Add an opt-in recipe trait resolver for
two actual consumed material lots. Preserve both signed trait records,
source provenance and deterministic duplicate merge cap. Do not change
old recipes until they are explicitly opted in. Add headless tests for
two signed inputs, same-ID cap, preview/consumption agreement, split
and merge, save/reload, and ingredient rollback. Then run full tests,
craft_lab, smoke and real craft UI inspection. No live deploy without
explicit instruction. Report blockers before inventing trait odds/caps.
```

## Short prompt for later C9 platform saddle

```text
Implement the approved platform-saddle **continuation** slices by
extending Player.mount/dismount, PetRecord, CreatureView.mount_socket,
FieldCatapult/SiegeProjectile and existing Inventory/World. Do not
replace the current mount or stationary catapult. Preserve single rider
behavior and existing source IDs. Fit only approved species and geometry.
Add 1 crewed + 2 auto + 1 shared physical ammo-box maximum, real driver
and gunner occupants, atomic shared ammo, actual NPC control orders,
legal hostiles and zone protections, load/stability effects, world-space
projectile launch, save/reload and no duplication. Two legal modes:
player drives + existing tribe human guns; existing tribe human drives
+ player guns. Crew/guns are not free phantom actors. Add focused labs,
save migrations and pixel checks. Stop at the first unapproved design
choice rather than producing fake mounted siege gameplay.
```
