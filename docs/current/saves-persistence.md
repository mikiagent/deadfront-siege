# Saves & persistence — file, schema, contents, rescue, autosave

Snapshot assembly: `game/scripts/core/save_game.gd` (`SaveGame`). File layer — atomic write,
`.bak`, migrations, quarantine: `game/scripts/core/save_migrations.gd` (`SaveMigrations`). Load
rules for the world: `game/scripts/core/save_restore.gd`. Validation after migration:
`game/scripts/core/save_sanitizer.gd` (`SaveSanitizer`). Every loader path goes through
`SaveMigrations.read` and then `SaveSanitizer.clean`.

## File locations (`SaveGame.path`, `SaveGame.run_name`)
- Player save: `user://save_1.json`. One slot; there is no slot picker.
- Automated runs (`--lab`, `--shot`, `--smoke`, `--bot`, `--web-soak`, `*probe`, `*-test`,
  `--script <file>`): `user://runs/<name>/save_1.json`, and the folder is wiped on launch
  (`SaveMigrations.wipe_dir`), so each run starts from a fresh world.
- Engine user dir: no custom user dir is configured (`game/project.godot` sets only
  `config/name="WildLands MMO"` and no `custom_user_dir_name`), so Godot's default applies and
  `user://` resolves to `~/Library/Application Support/Godot/app_userdata/WildLands MMO/` on
  macOS. The game code never reads that path; it is engine config.
- Siblings of the save: `.tmp` (write target), `.bak` (previous good save), and
  `.corrupt-<unix>` quarantined copies. There is no separate autosave file — the autosave writes
  the same `save_1.json`.

## Schema
- Top key `schema`; current value `SaveMigrations.CURRENT_SCHEMA` = 4 (`SaveGame.SCHEMA` mirrors it).
- Migration chain (`SaveMigrations.migrate`): v0 → 1 adds the `schema` marker plus empty
  `player` / `home` / `unstable`; 1 → 2 grid-cell building poses (old x/z rows still load);
  2 → 3 adds `player.inventory_extras` and `home.camp_layout`; 3 → 4 building-piece rows, marker
  bump only.
- A save with a schema above 4 is refused ("made by a newer version"); a non-numeric marker is
  treated as −1 and refused. Neither is deleted.

## What is saved (`SaveGame.save_now`)
| key | content |
|---|---|
| `schema` | format version |
| `map` | per-island fog and walked trail |
| `player` | `vitals`, `statuses`, `inventory`, `inventory_extras` (`worn`, `quick_food`, `tool_index`), `position`, `foodfx` (digestion incl. `fullness` points and `empty_for_s`, buffs) |
| `pets` | bonded pet rows (`PetRecord.to_dict`, incl. each pet's bag) |
| `ground_snares` | snare rows |
| `carcasses` (pending) | BUTCHER: carcasses still lying on the island — `species`, `position`, `cuts_left` of `cuts_budget`, which part ids were already cut, and the units left on each. Sanitized by `SaveSanitizer._carcasses` (known species, part ids and counts clamped, off-island rows dropped); `SaveRestore.carcasses` respawns them through `CarcassParts.corpse_from_row`. The sanitizer and the restore hook ship; the two `save_game.gd` call sites sit outside that job's SCOPE and come as `docs/orchestration/reports/dsc-butcher-save-hook.patch`. |
| `skills` | legacy survival ids → bool |
| `skills_v2` | skill trees |
| `home` | terrain, shape, buildings (with their storage `contents`), cargo, claims, camp layout, optional domain / comm center. UNCLAIM needs no format change: a released plot is simply absent from `domain.cells` (and from the mirrored `claims` rects), so a save after a release cannot resurrect it and `IslandClaims.setup` rebuilds only what the record still lists. |
| `pioneer_xp`, `pioneer_level`, `pioneer_crafts`, `pioneer_buildings`, `player_name`, `occupation` | progression |
| `character_look` | optional (CHARCREATE): `gender`, `height` (0.92-1.08, visual only), `colors` (skin, outfit1-3, eye, lip), `parts`, `portrait` (`pattern`, `bg`). `CharacterLook.clean` coerces every field to what `data/characters/appearance.json` offers; a save without it (older builds) loads with the default look. Namespaced apart from item instances' own `look`. |
| `t_stones`, `warp_gems` | currencies (T-stones read "Gold" on screen since BAGUI) |
| `tribe` | TRIBE: members, recruits waiting at the dock, the boat timer (`Tribe.to_save`); no row = no members |
| `tasks` | TASKSCREEN: claimed tasks, daily / weekly counts and their reset day / week (`Tasks.to_dict`) |
| `tutorial` | written only while the tutorial runs; a save without it loads as done |
| `visited_islands`, `island_id`, `clock`, `saved_unix` | travel + day clock |
| `raid_victory`, `objective`, `objective_best` | objectives |
| `unstable` | remaining time, harvested nodes, crater discovered (legacy single snapshot; an old save carries it into `expeditions`) |
| `landmarks` | LANDMARKS: `found` and `state` (opened dormant windows) per island id; an old save loads as a first visit |
| `expeditions` | ISLAND RESET: per expedition island `{generation, left, harvested}` (only touched nodes) |
| `drift` | UNSTABLE ISLES: `row` (the isle on offer or live), `cooldown`, `count` (rolls so far) |
| `pending_refunds` | structures that could not be re-placed into cargo |
| `away` | buildings/claims/domain while off the home island (only then) |

Ids only, never node references. Live creature, AI and spawn state is not saved: creatures
respawn from island data. A save is refused while `World.creation_pending` (character creation and
the first island pick have not finished), and `saved_unix` is written on every successful save.

## Sanitizer (`SaveSanitizer.clean`)
- `MAX_LEVEL` 60 (pet, stack and tree levels), `MAX_T_STONES` 100000, `WORLD_LIMIT` 2000.0 m from
  the island origin (positions, claims, domain cells), `MAX_CLAIM_TILES` 14, `MAX_RANK` 7,
  `DEFAULT_POSITION` `[0, 1, 12]` for a malformed position.
- Wrong-typed fields are erased so loader defaults apply. Unknown item ids drop the row; `count`
  ≥ 1 and ≤ the def's stack max; durability ≤ a fresh stack's `max_durability`; `attributes.species`
  must exist in the creature data.
- `home.shape` must be a shape id in `game/data/world/island_shapes.json`; `island_id` must be a
  known island, else `home_grassland`.
- Skill trees: node unlocks must exist, meet level and prerequisites, and fit the earned SP
  budget; unknown legacy survival ids are dropped.
- `saved_unix` clamped to `[0, now]`; vitals numeric and `[0, 1000000]`.
- `clean` sets the `CHECKED` sentinel `__sanitized` as its last step; a save read without that key
  is rejected ("it could not be checked").

## Rescue & failure paths
- `SaveMigrations.write_atomic`: writes `.tmp`, verifies its byte count, refreshes `.bak`, renames.
  A short write leaves the previous save untouched.
- `SaveGame.load_now`: main good → applied. Main bad, `.bak` good → main quarantined and the
  backup applied with a "Your last save was damaged" notice. Both bad → a new world starts, the
  bad bytes are kept via `SaveMigrations.quarantine` (deduped by sha256), and `SaveGame.blocked_reason`
  refuses every save until `SaveGame.confirm_new_game`.
- `SaveGame._apply_guarded` sets `LOAD_UNFINISHED` before applying and clears it last, so a load
  that aborts mid-way can never be autosaved over the good file.
- After load: the survivor is re-seated at surface height + 1.0 and moved to camp if the saved spot
  is not dry land. Offline catch-up is capped by `MAX_OFFLINE_SECONDS` = 604800 (7 days).
- Buildings that fail to re-place are refunded to home cargo; anything cargo cannot take stays in
  `pending_refunds` and is retried on every load (`SaveRestore.retry_refunds`).

## Autosave cadence & triggers
- Every 60.0 s (`World._process`, `_save_acc >= 60.0`), not while character creation is pending.
- `NOTIFICATION_APPLICATION_PAUSED` (mobile background) → immediate save.
- Also: island pick completed, before and after a travel swap, raid victory, building layout
  finished, and the manual "Save" in the pause menu and the hunt HUD. Death, sleep and claim
  placement do not save.
