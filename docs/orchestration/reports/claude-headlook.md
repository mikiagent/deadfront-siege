# HEADLOOK: every rigged animal turns its neck and head toward the player

Branch `claude/mmo-headlook`, from `origin/claude/mmo-overhaul` (fde2d334). Canon (e32ea4e2, allocharge) merged
before the final gate run. Pushed, not merged to canon.
Owner: "Can you add head movement that tracks the player to every model by default?"

## Credits
None.

## What shipped
- **`scripts/creatures/head_look.gd` (`HeadLook`, a SkeletonModifier3D).** `CreatureView.setup` adds it to every
  rigged creature, next to PlantedFlinch, after the clip is applied. Each frame:
  - Target: `brain.attack_target` while it is valid (the player or pet it is aware of or fighting, or a structure). The
    aim point is the survivor's face (+1.4 m), another animal's head height, or a structure's middle. No target, or a
    sleeping, downed or dead animal: the look fades out.
  - Yaw and pitch are measured from the head bone to the aim point in the body's frame, then clamped per species.
  - Spread: the neck bones (every `Neck*`/`neck_*` ancestor directly above the head, 1-3 bones depending on the rig)
    share half the turn, and the head takes the other half. No single joint pivots.
  - Smoothing: the angles move at 200 deg/s at most, and the weight eases through smoothstep (0.4 s in, 0.3 s out).
    A frame longer than 1/30 s is treated as 1/30 s, so a hitch cannot swing the head.
  - Out of range: a target past 1.5x the clamp (90 deg at the default, so beside or behind the animal) fades the look
    out. It does not pin the head at its limit.
  - Clips that drive the head fade the look to 0 within 0.15 s. The default list is `CreatureAnim.ONESHOT + ATTACKS +
    LEAPS` (every bite, roar, charge move, hit_react, dodge and leap) minus `alert`, plus death, knockdown, sleep, feed,
    charge, pin_foot, grab, bite_shake and sniff. Idle, walk, run, alert, investigate, strafes (circle) and stalk keep
    the full look.
- **Data** (`pipeline.head_look` in the species JSON, optional): `{"enabled": false}` opts a species out, `yaw_deg` and
  `pitch_deg` set the clamps, and `off_clips` adds clips to the off list. Defaults are 60/30. Smaller clamps are
  set for these species:
  ankylosaurus 30/15; triceratops, styracosaurus, zebraceratops, woolly_rhino 35/20; stegosaurus 40/20;
  pachycephalosaurus, tyrannosaurus, tarbosaurus, megarex, gallimimus, therizinosaurus 45/25; spinosaurus 50/25.
- **Skipped quietly:** a species with no head bone or no rig. Today that is brachiosaurus and protoceratops (no model).
  All 27 rigged species have `Head`/`head` and 1-3 neck bones.
- **Jaw:** the jaw is a child of the head and is never posed by HeadLook, so it moves with the head and keeps the
  clip's opening.
- **`tests/t_headlook.gd`**, plus `scripts/dev/headlook_lab.gd` / `scenes/dev/headlook_lab.tscn` for the shots.

## Hit sweeps
The sweeps (tactical_brain jaw and claw points, hurtboxes, crit spots) read bones after the modifiers have run. A
look that is on during an attack would therefore move the jaw point. HeadLook prevents this by fading to exactly 0 on
every attack clip within 0.15 s, and t_headlook checks that the head is back on the clip's pose. The earliest authored
hit in anim_events.json is bite_combo at 0.092 of the clip, about 0.14 s or later. At that point the weight is at most
smoothstep(0.07), about 1 %, which is under 0.5 deg at a 30 deg look. Every other hit lands well after the fade.
Hurtboxes and crit spots on the head follow the head where it is drawn, which is the point. t_hitboxes, t_critspots
and t_combat pass.

## Gates (after merging canon e32ea4e2)
- **t_headlook PASS**, 27 species. For each one:
  - with the survivor 30 deg to the left in idle, the head bone's added yaw is +29.7 to +31.0 deg (left), inside the clamp;
  - with her 30 deg to the right, the yaw is -29.3 to -30.0;
  - during attack_primary, the weight is 0.000 and the head is on its clip pose (0.000 deg);
  - with her behind, the look fades to 0;
  - per-frame change stays at or under 5.07 deg in a 60 fps frame. The gate X is **6 deg/frame**.
- **Cost:** 2.9-3.6 us per animal per frame across runs. That is under 0.09 ms for 24 animals, the perf budget's creature cap (gate: 60 us
  per animal). HeadLook adds one node per rigged creature, which does not tick, and it returns early when its weight is 0.
- **t_hitboxes PASS, t_critspots PASS, t_combat PASS.**
- **run_all `[tests] PASS`.** `tools/smoke.sh --no-import` **SMOKE PASS**.
- **t_canim FAIL, same on canon:** `_on_damaged starts hit_react (got idle)` for styracosaurus, therizinosaurus,
  triceratops, utahraptor and carnotaurus. Canon e32ea4e2 run alone gives the same 5 lines.
- **t_perfgates FAIL, same on canon, box under load:** `home_grassland builds in ~2.7 s (budget 2.5 s)` at load
  average 15-17. Canon e32ea4e2 run alone at the same moment failed the same way (2780 ms, savannah 3186 ms).
  build_ms is island build time, and HeadLook adds nothing to it beyond one node per creature.

## Shots
`docs/orchestration/reports/headlook/`: velociraptor, tyrannosaurus, triceratops and gallimimus, with the survivor
40 deg left, centre and 40 deg right (`<species>_<side>.png`, 12 shots). The caption shows the applied yaw, pitch and
weight. They were taken off-screen and windowed (`--position 6000,3000 -- --skip-charcreate --lab=headlook_lab
--out=DIR`) and the run quits itself.

## Assumptions (all `# ASSUMPTION` in head_look.gd or the JSON `_note`)
- The neck takes half the turn and the head the other half.
- The clamps: default 60/30, and the per-species values above.
- The fade-out multiplier is 1.5x the clamp.
- Turn rate 200 deg/s. Fades: 0.4 s in, 0.3 s out, 0.15 s when an off clip starts.
- Aim heights: 1.4 m for the survivor, 0.7 x height for an animal, 0.5 m for anything else.

## For the next agent
- HeadLook post-multiplies onto the clip's pose each frame. That relies on every clip keying the neck and head bones,
  which today's Tripo and dsc bakes all do. A clip that leaves them unkeyed would let the turn build up frame after frame.
- A new head-driving clip is covered automatically if it goes into CreatureAnim.ONESHOT, ATTACKS or LEAPS. A looping one
  (like `charge`) has to go into `EXTRA_OFF` or a species' `off_clips`.
