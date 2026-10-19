# W1-TAME: pet record integrity, honest growth and complete taming routes

Branch `claude/mmo-w1-tame` (cut from `claude/mmo-overhaul` at ea2d167). Credits spent: 0.

## What shipped

- **`game/scripts/pets/pet_stats.gd` (new): `PetStats.compute(def, genetics, level)` is the one pet stat
  formula.** `stat = species base x IV quality x (1 + level growth + level-up points + trained EVs)`.
  Growth terms add and never compound. Level-up points (`level_gains`) and EVs now change stats.
  `PetStats.grade_rate(grade)` gives the XP rate and hunger efficiency.
- **`CreatureGenetics`**: `multiplier()` is split into `iv_multiplier()` (85-115 %) and `growth()`
  (`GAIN_STEP` 0.0008 per level-up point, `EV_STEP` 0.001 per EV). For a wild animal (no points, no EVs)
  `multiplier()` returns the same value as before.
- **`PetRecord`**:
  - New fields: `uid`, `owner`, `origin`, `tamer`, `tamed_at`, `wild_level`, `name` and `parent_uids`.
    All round-trip through `to_dict()`/`from_dict()`. Old saves load with defaults: a fresh uid, origin
    `tame`, owner "".
  - `hp/attack/...` are a cache. `recompute()` rebuilds them from species + genetics + level after
    `add_xp`, after `train` and on every load, so a save carrying the old compounded numbers is corrected.
  - The grade always comes from `genetics.overall_tier()`, and that grade sets `xp_rate` and
    `hunger_efficiency`. The grade argument of `from_def` is accepted and ignored.
  - `from_def` takes the wild level (capped at 60).
  - Bags are sized from the species on load and never shrink below the saved row count, so legacy
    10-slot saves re-expand.
  - `RESPAWN_TIME` is 180 s.
  - `train(stat, n)` is the EV training API for the screens package.
  - `matches_wild()` is removed (it had no callers).
- **`CaptureSystem.attempt`** refuses at or above 30 % HP. The captured stack carries the wild `level`.
  It no longer carries `grade_seed`. It returns `bool`.
- **`FieldTame`**: species above capture tier 1 need their Capture Technique. Without it, the plate hint
  and the refusal both read `Needs Capture Technique N`, and no food is accepted. A full roster refuses
  the feed before any food is eaten, so the animal is no longer bagged and freed. A completed tame keeps
  the wild level, gets `origin=tame` and `tamer`, and carries its HP fraction into the pet's HP pool.
  `_roll_grade` is gone.
- **`TamingPen`**: on success the animal goes straight into `player.bonded` with `origin=capture`, its
  wild level and its captured genetics, and the survivor gets a notice. The pen no longer creates a
  `tamed_animal` item, so nothing can be lost to a full bag. A legacy `tamed_animal` item from an old
  save is bonded when the survivor uses any pen. A pen that finishes while no survivor is present waits
  and does not discard the animal.
- **`capture_lab`** wears the animals below 30 % HP through the real groggy-plus-hit path. It checks the
  smilodon technique lock, completes one field tame and one net-to-pen tame, prints
  `[capture] PASS bonded+=2` and exits 1 on any failed check. **`pets_lab`** counts all five of its
  checks toward the exit code.
- **`game/tests/t_tame.gd`** (new): tests for bags, growth bounds, `add_xp`/`train` against
  `PetStats.compute`, the single grade, uids and the capture rules.

## Acceptance checklist (every line below was printed by a run I made)

Run with `gslot.sh perl -e 'alarm N; exec @ARGV' Godot --headless --path game ...` from the work tree.

| Item | Exact output |
|---|---|
| t_tame passes (spec named it t_pets.gd; the wave rule names it t_tame.gd) | `[t_tame] PASS` |
| 140-slot triceratops bag, slot 50 survives JSON; legacy 10-slot dict loads into 140 | `[t_tame] bag slots fresh=140 roundtrip=140 legacy=140 slot50=stone x7` |
| Every tameable species: Lv60 HP <= 3.0x Lv1, attack <= 2.5x, never above the wild T. rex (worst case: IV 31, all 177 level points and 100 EVs in the stat) | `[t_tame] growth species=16 worst Lv60/Lv1 hp=x2.89 attack=x1.36 (was x93.8 / x17.8) rex hp=200000 atk=1100` |
| Stats after add_xp equal PetStats.compute exactly; train() raises the trained stat | `[t_tame] raptor lv=60 hp 711 -> 1903 (x2.68) attack trained 122.2 -> 126.5` (asserts `==` on all seven stats) |
| 200 random genetics: rec.grade == overall_tier(), xp_rate from that grade | `[t_tame] grade 200 random genetics mismatches=0 IV0 grade=D- xp_rate=0.85` |
| `grep -rn '_roll_grade' game/scripts` returns nothing | no output, `rc=1` |
| 1,000 tames, 1,000 distinct non-empty uids, from_def origin defaults to tame (real tame/capture origins are asserted by capture_lab); level = wild level, capped at 60 | `[t_tame] uids distinct=1000/1000 sample=p_c61f3bbcd95e8376 level wild25=25 wild75=60` |
| RESPAWN_TIME 180; net refuses at 50 % HP with a real Player holding two tier-II nets (returns false, nets and bag unchanged); at 25 % HP with force_result=1 it returns true, uses one net and bags a captured_animal; fresh survivor's smilodon refused with the hint and no food icon | `[capture] refused: velociraptor at 50% HP, needs under 30%`, `[capture] velociraptor attempt p=0.56 → success` and `[t_tame] rules respawn=180 net@50%=false net@25%=true nets=1 smilodon='Needs Capture Technique 5' food_id=''` |
| The net test can fail: mutant with the gate loosened to `fraction < 0.6` (restored afterwards) | `[t_tame] FAIL net refuses at 50 % HP (returned true, nets 1, bagged true)`, `mutant rc=1` |
| A forged save cannot buy stats or bag space: 1,000,000 level gains on a Lv1 pet, 100 EVs in all seven stats, 50,000 bag rows | `[t_tame] untrusted load lv1 gains=0 evs=300 hp=776 atk=100 slots=10 lv60 gains=177` |
| capture_lab: below 30 %, one field tame, one pen tame, PASS line, exit 0 | `[capture] ok compsognathus down below 30 % HP (25%)`, `[capture] ok field tame bonded compsognathus grade=B lv=15 wild=15 origin=tame uid=p_6ac7ec2bf50c8cc6` (now compared with the level read before feeding), `[capture] ok pen tame bonded velociraptor grade=B- lv=25 wild=25 origin=capture uid=p_79f05756d5e8d351`, `[capture] PASS bonded+=2`, `capture_lab exit 0` |
| capture_lab exits 1 otherwise (forced the pen to fail, then restored the file) | `[capture] FAIL pen tame bonded (none); bonded +1`, `forced-fail exit 1` |
| pets_lab: five checks drive the exit code | `[petslab] PASS 5/5`, `pets_lab exit 0` |
| Existing suite | `[tests] PASS` (run_all.gd, exit 0) |
| Smoke | `SMOKE PASS` (`tools/smoke.sh --no-import` through gslot) |

## Screenshots inspected

- `scratchpad/w1/tame/capture_lab_plates.png` (windowed `--lab=capture_lab --shot`). It shows the
  Lv. 15 Compsognathus plate with its HP bar at about a quarter and the `Tame 0/3` hint under it, with
  two knocked-down compys beside the survivor. The smilodon in that frame is the existing pink box
  placeholder with only a small HP bar. Its `Needs Capture Technique 5` hint was checked by log and
  test, not by pixels, because only the focused creature gets the full plate.

## Assumptions (`# ASSUMPTION:` in code)

1. `PetStats.LEVEL_GROWTH`, `CreatureGenetics.GAIN_STEP` and `EV_STEP` are tuned to the acceptance
   ceilings. Tarbosaurus (700 attack) must stay under the T. rex's 1100 with perfect genetics, which
   caps the worst-case attack growth at about +36 %. Levelling therefore mostly raises HP (up to
   x2.89), and attack moves slowly. These are three constants if the owner wants a different curve.
2. `FieldTame.FREE_CAPTURE_TIER = 1`: tier-1 species (compsognathus, zebraceratops, coelophysis,
   protoceratops) can be field-tamed without a technique, so a new survivor can still make a first
   tame and the bot's `tame` rung keeps working. The PRD (section 12.1) gates even tier I behind
   Capture Technique I at Survival 15. **Owner question:** gate tier 1 as well?
3. D grades use C's rate (0.85). The old table only had S/A/B/C.
4. Pets saved before uids get a fresh local uid and `origin=tame` on load.
5. Offline uids are `p_` plus 16 random hex characters. The server issues its own `p<seq>` ids
   (contracts section 4). Offline `owner` is "".
6. When a species declares no bag, the pet has 10 bag slots (unchanged from before). A loaded bag is
   the species size, or 10 if a legacy save holds up to 10 rows; extra rows are dropped.
7. `origin = capture` for pen tames. The contracts v2 origin list (section 0.5) does not have it yet;
   see integrator hook 6.
8. Untrusted genetics on load: the EV total is trimmed to 300 and level gains to 3 x (level - 1), in
   `CreatureGenetics.STATS` order (the first stats keep their points). `PetRecord.recompute()` applies
   the level-gain cap, so every path that builds a record is covered.

## Behaviour changes to know at merge

- Levelled pets in existing saves are recomputed on load. A pet levelled under the old formula loses
  its compounded stats; for example, a Lv60 raptor saved with 60,295 HP loads with about 1.9k. This
  is the fix for tame-04, not a regression.
- Fresh tames now start at the creature's `level`. In the labs that is the species tier (compy 15,
  raptor 25) because labs spawn creatures at their tier. On real islands W1-AI's ring levels decide.
- `CaptureSystem.attempt` now returns `bool`. Existing callers ignore the result, which is fine.

## Integrator hooks (files this package must not edit)

1. **Economy AssetValidator (W2-INT)**:
   - Add `"uid", "owner", "origin", "tamer", "tamed_at", "wild_level", "name", "parent_uids"` to
     `PET_KEYS`. Today it refuses any pet with these fields as "unknown pet field".
   - Replace `GROWTH`/`_expected` with `PetStats.value(def, genes, level, stat)`.
   - Replace `GRADE_RATES` with `PetStats.grade_rate(grade)`.
   - The `respawn_left` bound reads `PetRecord.RESPAWN_TIME`, which is now 180.
   - The level-gain bound `3 * (level - 1)` still holds.
2. **player.gd `_begin_field_tame` (W2-PLAYER)**: show the refusal on screen and not only in the log.
   After `print("[tame] refused: %s" % FieldTame.refuse_message(creature))`, add
   `notice(FieldTame.refuse_message(creature))`. The plate already shows the hint.
3. **player.gd `bond_from_inventory` (W2-PLAYER, legacy items only)**: pass the level as the fifth
   argument, `PetRecord.from_def(def, grade, variant, genetics, int(stack.attributes.get("level", 1)))`.
4. **creature.gd `stat_value` (W1-AI)**: the live pet and its record disagree today (the creature
   uses `genetics.multiplier()`, which has no level term: up to 35 % ranged defense and 11.8 % ranged
   attack apart at Lv60). Replace the body with
   `return pet_record.stat_value(stat) if is_pet and pet_record else PetStats.value(def, genetics if genetics else CreatureGenetics.neutral(), level, stat)`
   (use whatever field `become_pet(rec)` stores the record in), so stats also do not jump at the
   moment of taming.
5. **tools/test.sh (W1-QA)**: `godot --script` exited **0** on a parse error in t_tame.gd during
   development. The runner must grep for `[t_tame] PASS` and not trust the exit code alone.

6. **contracts.md section 0.5 (orchestrator) and the server validator (W1-SRVDOM / W2-INT)**: add
   `capture` to the origin list, which becomes
   `gather|loot|craft|tame|capture|breed|settlers|objective|market`. Without it the validator refuses
   pen tames.
7. **tools/test.sh (W1-QA / integrator)**: register t_tame. Append after the run_all line:
   `"$G" --headless --path "$ROOT/game" --script res://tests/t_tame.gd | tee /dev/stderr | grep -q '^\[t_tame\] PASS'`

## Labs to register

No new labs. Existing labs that now fail honestly:
- `capture_lab`: expect `[capture] PASS bonded+=2`, exit 0.
- `pets_lab`: expect `[petslab] PASS 5/5`, exit 0.

## Review round 1: findings and what changed

| Finding | Result |
|---|---|
| Blocker: net test passed with a null player | Fixed. The test uses a real `Player` with two `capture_net_ii` and checks the return value, the net count and the bag at 50 % and 25 % HP. The summary prints the real return values. The 0.6 mutant now fails (see checklist). |
| Genetics and bag trusted on load | Fixed in `CreatureGenetics.from_dict` (EV total <= 300), `PetRecord.recompute` (gains <= 3 x (level - 1)) and `PetRecord.from_dict` (bag <= max(species, 10)). Covered by `_test_untrusted_load`. |
| `capture` missing from the contract origin list | Comment fixed in `pet_record.gd`, assumption 7, integrator hook 6. |
| Tautological field-tame level check in capture_lab | Fixed: `wild_a` is read before feeding. |
| Self-assigned origin in the identity test | The hand-set `capture` origin is removed. The test asserts the `from_def` default, and capture_lab asserts both real paths. |
| Locked plate showed a food icon | `plate_hint` returns `food_id = &""` when locked, and `creature_plates._icon_for(&"")` returns null, so the icon hides. Asserted in t_tame. Not checked in pixels: only the focused creature gets the full plate in capture_lab. |
| Live pet vs record stat mismatch | Outside my files (creature.gd is W1-AI). Hook 4 is extended to cover pets. |
| Attack growth flattened | Not changed. This is an **owner question** (assumption 1). The other option is normal attack growth with a final per-species clamp at the wild T. rex attack. That is one line in `PetStats.value` if the owner prefers it. |
| No hook to register t_tame | Integrator hook 7. |

## Not done / left for later packages

- **tame-11, partly done.** The respawn time is 180 s and nets follow the 30 % rule. Pet HP is still not
  persisted: `player.summon_pet` sets HP to full, and fixing that needs player.gd and creature.gd
  (W2-PLAYER, W1-COMBAT). Hunt's NET button gating is W1-COMBAT.
- **tame-06, econ-dino-01 and sec-pets-03, partly done.** Identity and provenance fields exist.
  Server-owned RNG and authority are W1-SRVDOM and W3-SRVACT. Genetics are still rolled on the client.
- **tame-09, partly done.** Points and EVs now count, and `PetRecord.train()` exists, but no UI
  allocates EVs yet (W2-SCREENS).
- **sec-loss-08 and econ-conservation-01: only the taming paths are fixed.** The pen no longer drops
  items into a full bag, and a field tame at the cap no longer frees the animal. The other paths
  belong to other packages.
- Breeding is not built. `parent_uids` is ready for it (wave 2 / W4-TAMING).
- `run_all.gd` still prints its pre-existing `ERROR: Save schema 4 is newer than this build (3)`
  line, which predates this package.
