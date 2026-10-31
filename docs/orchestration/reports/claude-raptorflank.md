# RAPTORFLANK: Raptor arms, its clips fixed, the flank move, a natural slate morph (+ utahraptor arms)

Branch `claude/mmo-raptorflank`, from `origin/claude/mmo-overhaul`, with canon merged in again before this report.
Pushed, not merged to canon. Credits: Tripo 0, Meshy 0, Higgsfield 0.

What the owner said:
- "Slate Raptor needs to be moving its arms as part of the attack. the pounce and pin is awesome. I think the
  animations are weird on this one. There should be a move that's like run past, turn, strafe, attack from behind."
- "all Raptors have the same problem (same model). Slate was such a weird color btw"
- "utahraptor is in a pretty good state, it just needs to use its arms in the attacks too sometimes"

## What was weird (measured on the rig, before)
1. **Arms frozen.** The pounce, dodges, hops, leaps, hit_react, knockdown, death, walk, run, strafes and charge
   had 0 deg of arm motion. The bites moved the arms only a little: the arm's own joints peaked at 34 deg.
   - On this rig the arms hang from `Body`, not the chest. When the torso pitched in a bite, the chest moved and the
     arms stayed behind.
2. **Scorpion tail.** In the bite, the combo, the pounce and the dodges, the tail swung straight up. The
   deinonychus tail turns did not carry over to this rig's tail rest.
3. **Shuffling feet.** The deinonychus walk moved across never lifted a foot: toe clearance was 3 cm or less in
   the swing. The source walk itself dips 10 cm into the floor, and `--floor-feet` flattened that into a skate.
4. **Strafes slid.** Their natural speed was not baked, so they played at the walk's 1.17 m/s while the planted
   foot covered about 0.95 m/s, a 20 % slide.
5. **Frozen leaps.** The pounce and the leap clips had no spine, tail or arm motion at all from the hips up.
6. Idle tail sway was 40 deg.

## What changed
- **Gaits are the raptor's own** (`tools/gait/raptor.json` + `make_gait.py`): walk, run, charge, strafe_left/right
  and walk_back.
  - Feet lift 35-50 cm in the walk, about 55 cm in the strafe and about 85 cm in the run.
  - The arms and hand claws swing against the legs, and the tail and head move.
  - The strafe plants the feet a little wider and takes a shorter stride, so the legs never cross (front-view check).
  - Natural speeds are baked in `anim_events.json` (walk 1.16, run 5.40, charge 7.92, strafes 1.67,
    walk_back 1.16 m/s), so the strafes are stride-matched.
  - Change to the shared `make_gait.py`: a new opt-in `swing_toe_pivot`. Without it, the toe dug 11 cm into the
    ground at toe-off because the heel-off pivot snapped away. Other species' configs are unaffected.
- **New `tools/gait/raptor_overlay.py`** reworks the transferred one-shots: idle, attack_primary, bite_combo,
  pounce, hop_back, leap_back, dodges, hit_react, knockdown and death.
  - The arms are glued to the chest, then keyed: they grab forward with the hand claws spread, rake down clenched on
    each hit, and flare for balance in the air.
  - In the combo the left hand rakes on bite 1, the right on bite 2 and both on bite 3. The combo keeps its own arm
    turns underneath, because resetting them tore the arm-to-thigh skin 21x.
  - The tail is keyed as small counter-balance turns, so the scorpion flick is gone.
- **`make_raptor_moves.py`**: the arms are glued to the chest, and there are hand and elbow grabs in the sickle
  slash, the pin bites and the crest flare. Two new clips:
  - `charge_turn`: the flank's skid-turn.
  - `flank_rake`: the leap-rake from behind, hit at 0.56, from both sickle feet and the jaws.
- **Pounce and pin are unchanged as moves.** The pounce clip only gained arms (thrown forward, claws clamp on the
  hit) and a level tail.
- **Rebuild:** `tools/gait/build_raptor.sh --clips-only` rebuilds all 24 clips byte for byte.
- **Gate:** `check_raptor.py` adds the new leaps to its airborne list and the rake's hit part.

## The flank (TacticalBrain, `tactics.flank`)
It is a sequence finisher in four phases:
1. **Pass.** It runs at the charge gait past the prey on the side its back is nearer. It aims 1.5 m beyond her line
   and 5 m out to the side.
2. **Skid-turn.** It plays the `charge_turn` clip. The yaw swings round the short way, only while airborne, so no
   foot skids.
3. **Strafe.** It sidesteps on the strafe clips, facing her, on a 5.5 m ring toward her back. It needs at least
   0.8 s of strafing and has at most 4 s.
4. **Rake.** At 140 deg or more off her facing, it leap-rakes (x2.0). Then it backs off.

Other details:
- If the strafe runs out of time it gives up.
- A survivor who keeps turning to face it denies her live back. It then rakes from where her back was when the flank
  began: turning is the counter.
- Pick rate: sequence weight 3 of 18, cooldown 9 s.
- Every number is a `# ASSUMPTION` in `raptor.json` `tactics._flank`.

## Slate morph
- Before: blue-grey with ice-blue feathers.
- Now: a dark olive-grey hide with darker bands across the back, flanks and tail (fading on the belly and head), and
  muted bronze feathers.
- `raptor_palettes.py` builds the bands from a UV-to-body-position map, so they run across the body, not across the
  texture atlas.
- The id stays `slate`, so saved pets keep their morph and no migration is needed. The other morph albedos are
  untouched.

## Utahraptor (UTAHARMS)
- New clip `grab_bite`: its own attack_primary with the raptor's grab-and-rake added on top. Its tail and its own
  arm turns are kept.
- Its `bite_combo` gains the arm rakes. It needed `--arm-gain 0.6 --shoulder 0`: the full amplitude on the shoulder
  root stretched a torso edge 19x.
- TacticalBrain plays `grab_bite` for half its bites (`tactics.bite_alt` / `bite_alt_chance` 0.5, an ASSUMPTION).
  Statuses apply as for the plain bite.
- Nothing else of its clips or AI changed. Rebuild: `tools/gait/build_utah_arms.sh`.

## Shots (`docs/orchestration/reports/raptorflank/`)
All are from off-screen windowed `raptor_lab` runs (`--position 6000,3000`, self-quitting). New lab flags:
`--close` (the chest and arms up close) and `--flank` (the live flank).
- `before_after_attacks_slate.jpg`: before and after pairs for the bite, combo, pounce, slash and pin bites, at the
  hit frames. Shows the arms, the tail and the old and new slate.
- `before_after_gaits_slate.jpg`: walk and strafe, before and after.
- `slate_morph_before_after.jpg`: the slate morph, before and after.
- `contact_sheet_side_after.jpg`: every clip at 30 % and 60 %, with the survivor for scale.
- `attacks_close_black_gold.jpg`: the attacks on the black_gold morph.
- `flank_overview_green.jpg` and `flank_chase_green.jpg`: the live flank on the green morph (pass, turn, strafe,
  rake, recover).

## Tests (after merging origin/claude/mmo-overhaul again)
- New `t_raptorflank`: **PASS**. It checks:
  - The arm joints turn more than 45 deg in every raptor attack (bite, combo, slash, pounce, pin, rake) on the
    black_gold and slate morphs. Before, the peak was 34 and the pounce was 0.
  - The utahraptor's grab_bite and combo arms move.
  - About half the utahraptor's bites are grabs (22 of 40).
  - The baked strafe speeds.
  - A seeded live fight runs flank, then turn, then strafe (on the strafe clips), then rake. It is 140 deg behind
    her facing at take-off, and the rake lands.
- PASS: t_sp_raptor, t_raptorfeel, t_combat, t_tactical, t_canim, t_noboxes, t_saddles, t_mounts, t_coelomoves (the
  utahraptor's test).
- `run_all.gd`: `[tests] PASS`. `tools/smoke.sh --no-import`: SMOKE PASS.
- `check_raptor.py`: RAPTOR_CHECK PASS on all 24 clips. `tools/audit_gaits.py --gate`: GATE PASS. The task named
  `tools/gait/audit_gaits.py`; the script lives at `tools/audit_gaits.py`.
- **`t_boneparts` FAILS on canon itself:** "megarex has a carcass but no bone part list". It came in with the
  sp-megarex merge, is not touched here, and needs a megarex row.
- No duplicate func names in the merged .gd files.

## Shared files touched
- code:
  - `tactical_brain.gd`: flank state, `bite_alt`, the `_jump_end` leap list;
  - `creature_anim.gd` / `creature_clips.gd`: clip lists for `flank_rake` and `grab_bite`;
  - `creature_attack.gd`: grab_bite statuses;
  - `lab_spawn_panel.gd`: fight clips;
  - `raptor_lab.gd`: `--close` and `--flank`.
- data: `anim_events.json` (raptor speeds, `flank_rake`, `grab_bite`, notes), `raptor.json`, `utahraptor.json`.
- tools: `make_gait.py` (opt-in `swing_toe_pivot`), `make_raptor_moves.py`, `raptor_palettes.py`, `check_raptor.py`,
  `build_raptor.sh`.
- new files: `raptor.json` (gait plan), `raptor_overlay.py`, `build_utah_arms.sh`, `game/tests/t_raptorflank.gd`.

## Open
- The flank rake (x2.0) on a fresh 100 HP survivor is a balance call, with the RP2 slash and pounce numbers.
- The combo's rear-up tell (60 %) still has the head high; that is the deinonychus combo's design, kept.
