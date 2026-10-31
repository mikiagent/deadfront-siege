# COELOMOVES: one deinonychus profile for four species, skittish-territorial grazers

Branch `claude/mmo-coelomoves` (from `origin/claude/mmo-overhaul`). Not merged to canon. No credits spent.

Owner asks (2026-10-31, verbatim):
- "give the coelophysis all of the same attacks as deinonychus"
- "Gallimimus AI is completely braindead. Give it patched deinonychus's brain as a template and we will tune after"
- "megaloceros ... should get territorial and engage the player after running away once. Have it run away when its weak or something like that. Same behavior for Gallimimus"
- "Utahraptor model is great, but the animations and AI suck. Give it the deinonychus brain for now and we will workshop it as we go"
- "Velociraptor has the gliding problem, honestly also give it the deinonychus brain."

## What shipped

**One profile.** The deinonychus tactics (`ai.json` pack_flanker) are the single profile. A species JSON names it as
`"tactics": {"base": "pack_flanker", "scale": k, ...overrides}`. `TacticalBrain.resolve` starts from the base,
multiplies its distances (`SCALED_KEYS`: ring, strafe, hops, leaps, pounce ranges, ambush radii) by `scale`, then
applies the overrides. Nested dicts such as enraged and alpha merge one level. `CreatureDef.tactics` carries the
block, and `TacticalBrain.tactics_for_def(def)` is now what `Creature._make_brain`, the brain setup and the lab
spawn panel read. Species without a block still use their archetype's tactics, unchanged.

| Species | Brain | Profile overrides (all ASSUMPTION) | Moves |
|---|---|---|---|
| Coelophysis | TacticalBrain (was CreatureBrain) | scale 1, pounce x2.0, combo [0.8, 1.04, 1.44], pounce_radius 1.2 | the deinonychus set: backstep/strafe sequences into pounce, charge or combo; ambush from cover; leap-in; back-leaps; power strafes |
| Gallimimus | TacticalBrain (was CreatureBrain) | no pounce, no ambush; kick = attack_heavy (spring-and-rake), heavy_cd 3, only within heavy_reach_m 1.8; peck = attack_primary; peck flurry = combo; territorial | runs from the first threat, turns and fights, runs again under 30 % HP |
| Utahraptor | TacticalBrain (was RaptorPackBrain) | scale 1.4, pounce x3.0, combo [1.2, 1.5, 2.0], keeps the ambush | the deinonychus set at its size |
| Velociraptor | TacticalBrain (was RaptorPackBrain) | scale 0.75, pounce x2.0, combo x0.8, no tree ambush | sniff, then the 3 s investigate hold, then the deinonychus set |
| Megaloceros | TacticalBrain (brain data only) | `ai.json` antlered tactics: base horned_charger, retreat 0.3, territorial | display, straight antler ram, attack_heavy at point blank, hind kick; skittish-territorial. No clip or size changes; the model is being rebuilt on claude/mmo-sp-megaloceros |

**Skittish-territorial** (`tactics.territorial`, `TacticalBrain._territorial_tick`): the first threat sends the
animal running (the normal skittish flee). After `flee_once_s` 3 s, or when the flight outruns the leash, it turns on
the threat if the threat is within `leash_m` 30 m (its leash grows to 30 m while territorial). It then fights. Under
`weak_frac` 30 % HP it is no longer provoked and runs (retreat_mode flee). Once the threat is gone (leash break) it
forgets and grazes, and the next threat starts the cycle again. Timid natures only flee.

**RAPTORFEEL kept on the velociraptor:** TacticalBrain now does the sniff and investigate hold for any rig with an
`investigate` clip (`_spot`, `_investigate_hold`, `on_aggro` ends the hold on a hit). t_raptorfeel passes on TacticalBrain.

**Hits land where the jaws reach** (CM5). I measured the snout at the bite's hit frame on each clip and set the
archetype `attack_range` so the survivor's surface at contact reach sits just inside it:

| Species | Old range | New range | Snout reach | Before |
|---|---|---|---|---|
| Coelophysis | 1.6 | 2.2 | 2.28 m | the head went 0.7 m through her |
| Gallimimus | 1.6 | 2.8 | 3.13 m | |
| Velociraptor | 2.0 | 1.3 | 1.32 m | it bit air 0.6 m short |
| Utahraptor | 2.2 | 4.6 | 5.08 m | the head went 2.5 m through her |

Allosaurus shares apex_raptor's range. It has no model and still uses RaptorPackBrain.

## Clips

Deinonychus clips moved onto each rig with `tools/gait/transfer_clips.py` (all four are on the same Velociraptor.fbx
donor skeleton). Timing and anim_events are unchanged, since events are per clip and shared:
- coelophysis, utahraptor, velociraptor: attack_primary, attack_heavy, bite_combo, pounce, charge, hop_back, leap_back, dodge_left, dodge_right
- gallimimus: the same set minus the pounce. Its old attack_primary "kick" was replaced: the stance foot slid 7.8 cm and never lifted.

Two new transfer options, both needed for the gates:
- `--floor-feet` pitches a foot about its toe tip when its skin dips under the floor, or lifts it on push-off. Toes went 3-9 cm into the ground without it.
- `--pin-toes` holds a hind toe where it touched down while it is down. The band is 2 % of the leg or 1.5 % of body height, whichever is larger.

`tools/gait/check_leap.py` gained two options:
- `--ref-clip` measures prints from the clip's own takeoff and landing frames, not the bind rest. Transplant rigs stand in a stance that is not their bind pose, which made every clip, deinonychus's own included, read a constant 16-34 cm "slide".
- `--stance` judges stepping attacks: a toe glides only while it is down, so a lifted step passes.

Natural charge speeds were added to anim_events.json for the four species.

**Gait results, all PASS** (`check_leap.py --ref-clip`, plus `--grounded --stance` for the attacks; 31 clips):
penetration at most 0.19 cm and planted slide at most 0.46 cm (game scale). Coelophysis, utahraptor and velociraptor:
pounce, hop_back, leap_back, dodge_left, dodge_right, attack_primary, attack_heavy, bite_combo. Gallimimus: the same
without the pounce. `audit_gaits.py --gate` GATE PASS; walk and run are untouched. Deinonychus's own clips still fail
the old rest-referenced check, because of the rest-pose issue above.

## Tests and gates

`game/tests/t_coelomoves.gd` checks:
- the data: one base profile for all four species; coelophysis sequences, point_blank, ambush and distances equal deinonychus's; scaling works; gallimimus has no pounce; megaloceros is territorial
- every fight clip loads
- in a 70 s fight against a stationary survivor, each move fires and lands: combo, pounce and charge-bite for the three raptors; kick, peck flurry and charge-bite for gallimimus. The plain bite is a last resort in this profile, so attack_primary lands as the charge's bite, as for deinonychus.
- the body stays on the ground outside leaps
- gallimimus flees once, turns territorial, never pounces, runs under 30 % HP, and forgets once the threat is gone

Gates, after merging origin/claude/mmo-overhaul (0152e8d4):
- t_coelomoves, t_combat, t_canim, t_godlab, t_raptorfeel, t_tactical, t_kicktackle, t_saddles, t_ankyloai PASS
- earlier on this branch: t_alphas, t_ai, t_swarm, t_zebra, t_styraco PASS
- `run_all.gd` [tests] PASS; `tools/smoke.sh --no-import` SMOKE PASS

t_raptorfeel's "after the hold it commits" now accepts any TacticalBrain fight state; it had accepted only
approach and attack, the RaptorPackBrain states.

Shots (windowed off-screen `creature_lab --clipsheet`, self-quitting, front three-quarter over side, 8 frames per clip):
`coelomoves_coelophysis_sheet.jpg`, `coelomoves_gallimimus_sheet.jpg`, `coelomoves_utahraptor_sheet.jpg`,
`coelomoves_velociraptor_sheet.jpg` beside this report.

## Things the next agent needs

- **Charge glide:** compyfeel (claude/mmo-compyfeel) owns the shared charge movement and animation fix. Nothing here touches it. The four species now have charge clips and natural charge speeds, so they inherit the fix.
- **Navmesh in tests:** without a navmesh, `Creature` steers straight only at goals within 12 m. The utahraptor's x1.4 ring starts charges from about 14 m, so t_coelomoves bakes a navmesh like LabKit does. Real maps use tile paths or navmesh.
- **Open Questions:** CM1-CM5 in `docs/vision/WildLandsMMO_Open_Questions.md` cover the scales, multipliers, territorial numbers and reaches. Fight-lab rows for all five species read "reworked per owner 2026-10-31, re-test".
- **RaptorPackBrain** is now used only by allosaurus.
