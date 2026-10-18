# Deadfront AAA audit and roadmap

Written 2026-10-18 against local `main` (1ed459b), with the survivor v2 equip and mount
work from `claude/survivor-v2-equip-mount-code-de20f0` in view. The bar is ARK: Survival
Evolved scoped to this game: a single-player first, mobile-first, stylized dinosaur survival
game, judged in desktop Chrome (web Compatibility renderer).

Ranking is by how much a new player would notice, divided by effort. "Self-contained" means
it needs no new paid assets, no owner decision and no save-format change.

## Where the game stands

| Area | State | Biggest gap vs ARK |
|---|---|---|
| Rendering | Procedural sky, day/night, fog, one shadowed sun, linear tonemap, no grade (`scripts/world/island_runtime.gd` `_apply_env_setup`, `_drive_day`) | Flat, washed image; no golden hour; no post |
| Audio | None. No AudioStreamPlayer anywhere, 0 sound files | Silence is the single loudest AAA gap |
| Survival loop | Health, energy, fatigue, climate fatigue, 164 items, 168 recipes, station kits (`combat/vitals.gd`, `items/`, `world/build_placer.gd`) | No hunger or thirst that can kill you, no temperature damage, no weight, death costs nothing |
| Creatures | 20 species in data, 11 with models; brains with roam/alert/attack/flee/sleep; field and pen taming; genetics; 12 mount species | 7 spawned species render as box placeholders (allosaurus, ankylosaurus, dilophosaurus, smilodon, styracosaurus, tarbosaurus, triceratops); no breeding; feed/sleep clips only on the T. rex |
| Equipment | Head/body/arms/legs visual armor, 3 kits, T. rex howdah ride (on the equip branch) | Held tools from `tools.json` not shown; most survivor v2 clips unwired |
| Multiplayer | None in code. `claude/mmo-*` branches hold docs only (`docs/orchestration/mmo/contracts.md`) | No net core at all |
| UI/UX | HUD, inventory, crafting, animals, map, touch layer, damage numbers, hit flash | No settings screen, no title menu, no camera shake or haptics |
| Tooling | `tools/test.sh` (37 tests), `tools/smoke.sh`, 22 labs, CI runs tests + smoke | Labs are not in CI |

## Roadmap

### Now: self-contained, high visibility

1. **Lighting and color grade.** *Done on `claude/aaa-lighting-grade`.* Filmic tonemap,
   contrast/saturation, soft glow, sun scatter in fog, and a golden-hour sun, fog and horizon
   that warm before night turns them blue. Everything used is supported by the web
   Compatibility renderer. Adds a `--tod=0..1` dev flag for repeatable lighting shots.
2. **Stegosaurus v2 in game.** *Done on `claude/project-thread-mtq26p`.* The code still forced
   the procedural placeholder written for the broken v1 skin; v2 renders and animates fine.
3. **Hit feel: camera shake and haptics.** A short shake and `Input.vibrate_handheld` on player
   damage (`player.gd` `_on_vitals_damaged`) and on heavy creature hits. Small, noticeable on
   phones.
4. **Labs in CI.** Run `ai_validation_lab`, `capture_lab`, `equip_mount_lab` and
   `species_look_lab` headless in `.github/workflows/ci.yml`; they already exit non-zero on
   failure.

### Next: needs assets or an owner call

5. **Audio foundation.** One autoloaded `Sfx` with pooled `AudioStreamPlayer3D`, wired to the
   hooks that already exist (`anim_events.json`, creature `_on_damaged`, harvest, eat, death
   card), then a day ambience loop and creature calls. Blocked only on downloading the CC0 packs
   the owner approved (`docs/orchestration/mmo/STATUS.md`); downloads need Milan's go-ahead.
6. **Fill the 7 placeholder species.** Either produce them through the Tripo + rig pipeline
   (the T. rex and Stegosaurus v2 path, credits needed) or pull them from `data/world/islands.json`
   until they exist. The far-shore allosaurus is the most visible.
7. **Hunger and thirst.** Add both to `Vitals` next to fatigue, wire them to the existing eat
   path and give the well and bucket a survival purpose. This touches saves, so it needs a
   migration test like the existing `save_v0`/`save_v2` fixtures.
8. **Death with a cost.** Drop the bag at the death spot, recoverable like a corpse
   (`player.gd` corpse loot flow). Owner call on how harsh this should be.
9. **Held tools and the rest of the survivor v2 clips.** Show `tools.json` tools in hand during
   gather_chop/gather_mine; wire sprint, alert, gather_berry, gather_dig, butcher, eat, drink.

### Later: big systems

10. **Breeding.** Two tamed records of a species, egg, hatch into a `PetRecord` with inherited IVs
    from `creature_genetics.gd`. Imprinting after that.
11. **Base building.** Snapping walls, roofs and ceilings with structure HP, on top of
    `build_grid.gd`.
12. **Multiplayer net core.** The `contracts.md` v1 slice: headless `--server`, `auth.hello`,
    presence. Everything multiplayer depends on it, and it touches every system's authority,
    so it should start only when the owner commits to multiplayer.
13. **Settings and title screens.** Volume (once audio exists), graphics quality, controls.

## Not checked

- None of this was checked in a deployed web build or on a phone. The lighting shots were taken
  locally with `--rendering-method gl_compatibility`, which is the renderer the web build uses.
- The 7 placeholder species were confirmed by asset presence and the `CreatureView` fallback
  path, not by screenshots.
