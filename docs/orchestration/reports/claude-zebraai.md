# Report: ZEBRAAI (creature lab dropdown + zebraceratops AI), Claude

Branch `claude/mmo-zebraai`, cut from `origin/claude/mmo-overhaul` (0fea2471). Not pushed, not merged.
No credits spent.

## Try it
`Godot --path game -- --lab=creature_lab --species=zebraceratops`
- Or open the lab, press **SPAWN**, pick **Zebraceratops** in the species dropdown, a nature (Brave to
  see the standoff, Timid to see it run, Random), count 3 (a herd), SPAWN. F3 prints each move.
- A default zebra runs from you on sight. Hit it three times (or hit one of a herd) to start the fight.
  A Brave one lowers its head at you; walk within ~5 m and it charges. Sidestep or roll the charge
  and it stands staggered for 1.5 s.

## Part 1: every species in the lab (commit 1)
- The SPAWN panel's species list is now a dropdown (`OptionButton` "SpeciesPicker", 64 px tall, popup
  rows ~64 px at 20 px text, scrolls past six rows) listing all 19 species in `game/data/creatures`.
- The 8 species without a GLB (allosaurus, ankylosaurus, brachiosaurus, dilophosaurus, smilodon,
  styracosaurus, tarbosaurus, triceratops) read "(stand-in)" and spawn as the box placeholder that
  `CreatureView._build_placeholder` already builds for model-less creatures.
- `t_labspawn` now checks: every species listed, stand-in marked only without a model, picking a row
  selects it, and every species spawns and clears.

## Part 2: zebraceratops AI (commit 2)
Profile `ai.json archetypes.pack_mule.tactics` (pack_mule = zebraceratops and protoceratops, so the
protoceratops gets it too), run by `TacticalBrain`. Every number is an ASSUMPTION, logged as Z1-Z6 in
`docs/vision/WildLandsMMO_Open_Questions.md`. Template section: `docs/current/enemy-ai-template.md`
"Herd grazer extras".
- **Grazing / alert:** unchanged herd roam; on sight it plays alert. The tactics only run while it is
  provoked: skittish default after 3 hits, Brave after 1, Aggressive always, or rallied by the herd.
  Provocation ends after 15 s or once the prey is past 16 m from its home (`stand_down`).
- **Natures:** Timid never fights back, it only runs. Brave stands its ground with a threat display
  (alert pose) and charges if you come within 5 m or hit it. Aggressive charges on sight. Others flee on
  sight until provoked.
- **Threat display → horn charge:** main sequence display (1.2 s, head lowered) → charge; also plain
  charge and strafe → charge. The charge runs a line locked at its start, 2.5 m past her, at 1.5× run
  with the `charge` clip; contact in front is one hit at 1.8× attack (roll dodges it). A miss staggers
  it 1.5 s.
- **Kick:** the `kick` clip, 1.4× attack, only at point blank with the prey in its rear arc, usually
  right after a charge through her. `kick` is now a one-shot attack in `CreatureAnim` (hit at
  `anim_events` hit_frac 0.45).
- **Fillers:** hold (alert pose), strafe-walk, bluff charge (feint), scurry back (walk_back clip).
- **Herd defends a hurt member:** a hit herdmate pulls the others (not Timid, not freshly hit) onto the
  attacker for 8 s; the hurt one runs.
- **Hurt:** below 25 % HP it flees 4 s, then comes back while still provoked.
- **Taming:** unchanged. A knocked-down animal does not think; capture at ≤ 30 % or stunned still works
  (t_tame, t_capture09, t_tamingodds pass).
- Side fix: an Aggressive grazer of any species used to go back to grazing after its alert (the
  natures doc says it charges on sight). `CreatureBrain._provoked` now counts `auto_engage` for grazers.
- `BrainFlight.flee` no longer bounces a provoked grazer straight back into the fight during a
  tactical flight (`_holds_flee`).

## Missing clips (for the art thread)
- A front-foot **stamp** for the threat display (it uses `alert` now).
- A horn **impact / toss** pose at the charge's hit (the hit happens on the run-through, no strike pose).
- No dodge/hop clips needed: it scurries with `walk_back` and has no power strafe.

## Tests
- New `game/tests/t_zebra.gd` (seeded, frame-locked, stationary survivor): Brave displays then charges
  and lands horn hits; default flees on sight and charges after 3 hits; Timid only flees; a hit herdmate
  rallies two defenders who charge while the hurt one runs; a sidestepped charge misses and staggers;
  kick only from behind and lands once; past guard_m it stands down.
- `t_ai`: the "shot beyond the leash" check now pins a Loyal zebra (a seeded Brave one stands its
  ground, which is the new behaviour).
- Full `bash tools/all_tests.sh` (machine under heavy load, ~47 Godot runs): 128 tests, 126 pass. The two
  failures: t_ai (the Brave case above, fixed after the run; passes) and t_weather (thunder delay timing
  under load; passes on rerun, untouched by this branch). Rerun of t_weather, t_ai, t_zebra, t_labspawn:
  4/4 pass. `tools/smoke.sh --no-import`: SMOKE PASS.

## Next
- Owner check in the lab: is a herd of three that defends too hard for a first tame (Z3)?
- The charge-hit pose and stamp clips above.
