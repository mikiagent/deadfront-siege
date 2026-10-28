# claude-charcreate2: CHARCREATE landed on today's integration line

Branch `claude/mmo-charcreate2`, cut from `claude/mmo-overhaul` at 7d537d51. `git merge claude/mmo-charcreate`
(tip e3a30556, no rebase), then the package's hooks applied by hand to today's code. Credits spent: 0. No art,
no sound, no paid generation. Not pushed, not merged into mmo-overhaul.

## What landed

Everything in `docs/orchestration/reports/claude-mmo-charcreate.md`: the Durango-style Gender/Profession step,
Create Character (height slider, a portrait rendered from the player's model with Pattern/Background, a Colour tab
for skin, outfit 1-3, eye and lip through the baked texture masks), the Name step (1-20 chars), data-driven part
slots (`game/data/characters/appearance.json`), `CharacterLook`, `PortraitService`, `t_charcreate`, `charcreate_lab`.

Hooks (the package's patch no longer applied as text; done by hand where the files had moved):

- `world.gd`: `var look`; the creation `done` handler keeps `CharacterLook.clean(cc.look)` and puts it on the
  player's rig, then opens ISLANDPICK exactly as before.
- `save_game.gd`: saves `character_look`; load cleans it and applies it after the worn pieces attach.
- `save_sanitizer.gd`: `"character_look": {}` in SHAPE.
- `player_equipment.gd`: `equip()` calls `CharacterLook.refresh(rig)` so armour takes the chosen colours.
- `player_portrait.gd` (DOMAIN): your own portrait is `PortraitService.of_player()`; others keep the silhouette.
  DOMAIN's own snapshot code is gone. `t_domain`'s portrait checks follow (PortraitService renders, cached while
  nothing changes, redrawn on a new look).
- `ui_real_capture_lab.gd`: the old card/EnterRift checks are replaced by checks on the three steps (patch applied
  cleanly).

## Conflicts and resolutions

- The text merge had no conflicts. Base never touched `character_creation.gd` or `survivor.json`.
- **ISLANDPICK.** Its pick screen hangs off `CharacterCreation.done` in `World.start_new` and uses the static
  `CharacterCreation.layout_for`. CHARCREATE keeps both the signal (`done(occupation, gender, name)`, then
  `queue_free`) and `layout_for` unchanged, so the order is: Gender/Profession -> Create Character -> Name -> Tamed
  Island pick (layer 62) -> `complete_pick` -> world. The look is set before the pick opens, and `load_island`
  reparents the same player rig, so the look survives the landing. `t_charcreate`'s flow test now drives the whole
  chain: it taps the forest card and SELECT AND MOVE, then checks that creation finished, `home_shape == forest` and the
  look is unchanged, then saves and loads.
- **Save name clash.** The item-appearance worker adds `look` on item instances. The character's field is saved as
  top-level **`character_look`** (not the package's `"look"`), so the two never share a key. `World.look` stays the
  in-memory name. `t_charcreate`'s save asserts check `character_look`, at the same strength as before. The old-save
  check now asserts that the golden has neither key.

## Save change and its test

`character_look` is optional and additive. `CharacterLook.clean` is the trust boundary: it coerces every field to a
value from `appearance.json`, and a missing or wrong-typed field falls back to the default look. The sanitizer drops a
non-Dictionary value. Tests: `t_charcreate._test_old_save` loads `fixtures/save_v3_golden.json` (no look) with no
block, the default look, the name and occupation kept and the usual size. `_test_flow_and_save` round-trips height
1.06, skin and outfit1 colours and gender "f". `t_save` and `t_savefix` pass. Docs:
`docs/current/saves-persistence.md` (the new row), `hud.md` (domain banner portrait), `ui-screens.md` (the charcreate
entry; its screenshot predates the restyle).

## Gates (headless, via gslot)

- import: exit 0, 0 errors.
- `[t_charcreate] PASS` (log shows `[world] new survivor Ana-Lu Quispe. (farmer, f)` then
  `[world] tamed island shape=forest seed=2311 ...`)
- `[t_islandpick] PASS`, `[t_domain] PASS`, `[t_srvdom] PASS`, `[t_ui] PASS`,
  `[t_uiicons] PASS ids=191 files=125 ... '[icons] PASS drawn=125 svgs=125'`
- `[t_save] PASS` (its 5 deliberate SCRIPT ERRORs)
- Every other `game/tests/t_*.gd` (65 total): exit 0, PASS, 0 SCRIPT ERROR (incl. t_player, t_items, t_invslots,
  t_savefix, t_bags, t_islandgen).
- run_all: exit 0, `[tests] PASS`. Its SCRIPT ERRORs are the 3 known TouchControls compile-order ones plus 2 that
  `[econ] fault test` announces as deliberate.
- `tools/smoke.sh --no-import`: `[smoke] ok player_pos=(0.0, 1.0, 0.0) phase=day`, `SMOKE PASS`, 0 SCRIPT ERROR.

No windowed run (the machine is reserved), so `ui_real_capture_lab` and `charcreate_lab` were not run here.

## Needs an on-screen look (844x390 and 1600x900)

- All three creation steps, and the hand-off from Name OK to the Tamed Island pick (no frame where neither shows,
  no jump).
- Domain banner: your own round portrait is now the PortraitService headshot (pattern and background), not
  DOMAIN's gear snapshot.
- In the world: the chosen height and colours on the player after the pick lands, and armour taking the colours.
- Recapture `docs/current/screens/charcreate.webp`.

## Open, unchanged from the package

Female base, painted portraits, hair and feature options (all owner-gated art); on-screen keyboard lift untested on
a device; `CcUi` duplicates the torn-band chrome (fold into BAGS' when convenient).
