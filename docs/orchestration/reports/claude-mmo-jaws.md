# claude-mmo-jaws: jaws, moonwalking, pipeline plan

Branch `claude/mmo-jaws` (off `claude/mmo-overhaul` 6aac9056). Game files unchanged.

## Shipped
- `tools/jaw/open_mouth.py`: rips a closed-mouth mesh along the mouth line and adds a mouth bag; only mesh + weights
  change, bones and clips stay valid. `tools/jaw/render_head.py`: head close-ups at clip frames, same camera for old/new.
- `docs/orchestration/mmo/creature-pipeline-plan.md`: diagnosis with numbers, the prompts in use, the plan, per-species checklist.
- T. rex blind A/B set: `docs/orchestration/mmo/jaws/tyrannosaurus/`.

## Findings
- 9 of 11 species have no jaw bone (Meshy auto-rig). T. rex has one, but the mesh was generated with the mouth shut,
  so the lips stretch; alert opens the jaw 52 deg vs the 25 deg the weights were tested at.
- `tools/audit_gaits.py` shows positive stance drift (moonwalk) on coelophysis, compsognathus, gallimimus,
  utahraptor and velociraptor, and one forward-sliding foot on the T. rex walk.
- Meshy bipeds all share one library walk (2.46 s) and run (0.71 s); Meshy quadrupeds share another pair.

## Failed / not done
- Closed mouth lost the blind A/B slightly (chin seam). Not copied into the game.
- No in-game look (anim lab) and no gait fixes this pass; the gait tool is on unmerged `claude/mmo-locomotion`.
- Blender MCP failed to connect; headless Blender only. Subagents with the default model failed to start
  (openrouter/auto); the judge ran with an explicit model.

Credits spent: 0 (no Meshy/Tripo calls).

## Next agent
1. Fix the chin seam and lining edges, re-judge, then put the T. rex mesh in the game and look in the anim lab.
2. Merge `claude/mmo-locomotion`, make `audit_gaits.py` a pass/fail gate, re-make raptor walk/run with `make_gait.py`.
3. Add `Jaw` bones to the Meshy species, run `open_mouth.py`, author bite/roar/eat clips.

## Round 2 (2026-10-28, same branch)

- T. rex: lip line from teeth roots, exact-crossing rip, lip lining. Blind round 3: new won 3/3 open-mouth scenes, closed tied. Not in game yet.
- Prompts: `docs/art/...tripo-prompts.md`, `tools/creature_pipeline.py`, `STYLE.md` and the game-asset-pipeline skill ask for a slightly parted mouth.
- `tools/jaw/add_jaw.py` (Jaw bone for rigs without one; mouth line from the painted seam; skull and jaw ramp to rigid along the snout)
  and `tools/jaw/key_jaw.py` (jaw keys in bite/heavy/roar/eat/idle at the clip's own fps).
- Velociraptor jaw: blind round 3 won the roar strongly, lost bite and rest slightly; bite opening cut to 12 deg. Candidate only, not in game.
- Moonwalk: `tools/audit_gaits.py --gate`; `tools/reverse_clip.py` reversed walk/run of coelophysis, compsognathus, gallimimus,
  utahraptor, velociraptor (in place clips, time-reversed). Gate passes; natural speeds rebaked. IN GAME.
- Deinonychus replaced (owner sheet v03, rust colouring): Higgsfield views (arms folded high, mouth parted, tail level), Tripo
  multiview 03ec4543 (first try 09db13d1 rejected: four legs), transplant rig, jaw, keyed clips. IN GAME. Rig import check passes.
- Credits: Tripo 100 (3105 -> 3005), Higgsfield ~2.5, Meshy 0.
- Not done: T. rex/velociraptor jaws into the game, jaws for the other Meshy species, own gait clips per species (make_gait on the
  unmerged locomotion branch), gate for non +z rigs (stegosaurus, T. rex).
