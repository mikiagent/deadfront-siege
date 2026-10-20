# TASK: tune a death-ragdoll profile for every rigged dinosaur (data only)

## Why

DEADFRONT (Godot 4.7.1, typed GDScript, project in `game/`) is a dinosaur survival game. The owner reported that
dead dinosaurs do not stay on the ground (death clips that end legs-up or floating, bodies hovering or sinking on
slopes and next to rocks) and asked for ragdolls on death. The ragdoll SYSTEM is built and committed on this branch:

- `game/scripts/creatures/ragdoll.gd` (lifecycle: 0.3 s of the death clip, then physics, then freeze),
  `ragdoll_rig.gd` (builds one capsule `PhysicalBone3D` per profile body, joints, mass), `ragdoll_skin.gd`
  (CPU skinning so ground contact is judged on the real skin).
- `game/data/creatures/ragdoll.json`: the per-species PROFILES. Read its `_doc` block first: it is the schema.
  Only `velociraptor` has a profile today, and it passes every gate. It is your reference.
- `game/scripts/dev/ragdoll_lab.gd`: the gate. It kills each species on a heightmap collider like the island's in
  three set-ups (flat, a 20-degree slope pushed downhill, a low rock under the head) and measures the frozen body.

Your job: write and tune a profile for the other ten species until every lab case passes. Data only.

## What a case must do (the lab prints one line per case; `ok` or `FAIL` plus the reasons)

- `mode=ragdoll` (a fallback means the profile did not fit the rig, a NaN, a body over 30 m/s or a joint torn
  more than 35 %), `settle` <= 3.5 s.
- skin contact: `skin_min` within +-0.06 m of the ground and `below6cm=0`. `conform` is the vertical shift the
  system applied after the freeze (+ = it had to lift the body because skin sank into the ground).
- lying down: `hips` (height above the ground under the hips bone) <= 50 % of the standing value printed after it.
- no raised limb: `foot_max` (highest bone listed in the profile's `feet`) <= 75 % of standing hips.
- `stretch` <= 0.010, `limit_over` <= 8 degrees (joint measured against its profile limit from rest),
  `up_y` > -0.35 (not on its back), no physics left after the freeze, a corpse with loot.

## How to tune (what worked for velociraptor)

1. Start from the donor: coelophysis, compsognathus, deinonychus, gallimimus and utahraptor use the SAME 37-bone
   biped donor skeleton as velociraptor (same bone names, different proportions and scale): copy the velociraptor
   profile and rescale radii. megaloceros, protoceratops and zebraceratops share a 39-bone quadruped donor: like
   the bipeds plus front legs `FrontLeg.* > FrontUpLeg.* > FrontLowLeg.*`, and BOTH `BackFoot.*` and
   `FrontFoot.*` hang off `root` (IK feet) - reparent them under `BackLowLeg.*` / `FrontLowLeg.*`.
   tyrannosaurus (30 bones: Hips, Spine1-2, Chest, Neck1-2, Head, Jaw, Arm/Forearm/Hand.L/R, Tail1-7,
   Thigh/Shin/Metatarsal/Toe.L/R; Tail1 sits on the hips with zero length) and stegosaurus (34 bones: hips,
   hind_thigh/shin/foot/toe_L/R, spine_01 (zero length) > spine_02 > shoulder_L/R > front_upperarm/forearm/foot/
   toe_L/R, spine_03 > neck_01 > neck_02 > head > jaw, tail_01..07) are bespoke rigs with a normal hierarchy
   (no reparent needed). Their GLBs face -Z (the donor rigs face +Z): flip the sign of hinge ranges accordingly.
2. `--rl-suggest` prints, per profile body, how far the skin it carries reaches from the capsule line (p50/p80/
   p95 radius, past_tip, before_head). The lab line's `lowest=[...]` names the bones carrying the lowest skin.
3. Make the capsules of parts that touch the ground first (tail, feet, head, belly) at least as fat as the skin
   (about p90-p95) so physics stops them, and `conform` ends near 0 or negative. Thin capsules let skin sink;
   the conform then lifts the whole body, the hips rise and the lie-down gate fails.
4. The root body (the one with no ancestor body) spans the trunk: use `from`/`to` (velociraptor: Body from Tail2
   to Shoulders). Its bone must be an ancestor of every other body bone, or bodies fall apart.
5. Joints: `cone` = swing/twist/side limits about the bone line (built as a 6DOF joint), optional asymmetric bend
   with `axis` + `min`/`max`. `hinge` for knees, ankles, elbows: `axis` in REST skeleton space (lateral X for all
   these rigs), `min`/`max` = right-hand rotation of the child about that axis from rest, in degrees. Knees and
   elbows must only bend their natural way (the gate measures it). Necks and tails: small swings (10-20 degrees
   per joint) and angular_damp 4 so they do not noodle.
6. Keep 6-16 bodies (four ragdolls must fit in 2 ms of physics). Unlisted bones follow their parent rigidly.
   List the feet/hands/toe-tip bones under `feet`.
7. Change one species at a time and re-run only that species. The physics is not perfectly repeatable: a case
   that passes by a hair may fail on the next run; leave margin.

## Commands (run Godot ONLY like this, from this work tree, never with --editor, never --import)

    G=/private/tmp/claude-501/-Users-milankinzy-Documents-deadfront-siege/1899b1df-f06b-4b94-91be-9e3f3c22081d/scratchpad/gslot.sh
    GD=/Applications/Godot_mono.app/Contents/MacOS/Godot
    $G perl -e 'alarm 900; exec @ARGV' $GD --headless --fixed-fps 60 --path game -- --lab=ragdoll_lab --rl-species=utahraptor
    $G perl -e 'alarm 900; exec @ARGV' $GD --headless --fixed-fps 60 --path game -- --lab=ragdoll_lab --rl-suggest --rl-species=utahraptor
    ./verify_ragdoll.sh utahraptor,deinonychus      # quick check of some species
    ./verify_ragdoll.sh                             # the real gate: all 11 species x 3 set-ups + t_ragdoll

The lab and test make no sound; never play audio by other means. Grep the logs for `[ragdoll_lab]`,
`[rl-suggest]` and `[ragdoll]` lines; the rest is noise.

## Rules (binding)

- Change only `game/data/creatures/ragdoll.json`, and inside it only `species.*` entries (the shared sections
  budget/timing/impulse/guards/conform/physics/_doc must stay byte-for-byte equal in value; the verify checks).
  You may adjust the velociraptor entry only if it keeps passing.
- Do not touch `game/scripts/`, `game/scenes/`, `game/tests/`, `game/assets/`, `game/override.cfg`,
  `game/.godot/`, `TASK.md` or `verify_ragdoll.sh`. Do not add files except an optional `REPORT.md` at the root.
- Do not invent anatomy beyond the GLBs; use the bone names the rigs have.
- Commit with a clear message ending with the line `Co-Authored-By: DeepSeek (dsc) <noreply@deepseek.com>`.
  `git add game/data/creatures/ragdoll.json` (and REPORT.md) only; never `git add -A`. Never push.
- If a species cannot pass a gate for a reason outside the profile (for example its skin weights tear in any
  pose), stop tuning that one, keep its best profile, and write the numbers and the reason in REPORT.md.

## Milestones

1. All five donor bipeds pass: `./verify_ragdoll.sh coelophysis,compsognathus,deinonychus,gallimimus,utahraptor`.
2. The three donor quadrupeds pass: `./verify_ragdoll.sh megaloceros,protoceratops,zebraceratops`.
3. tyrannosaurus and stegosaurus pass.
4. `./verify_ragdoll.sh` (all 11 + t_ragdoll) exits 0. Commit. Write REPORT.md: per species the final lab line
   numbers (settle, conform, hips ratio, peak) and anything you could not fix.
