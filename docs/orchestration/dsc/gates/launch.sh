#!/usr/bin/env bash
# launch.sh <key> <code|blender> [model]: install staging/<key>-TASK.md (+ the shared rules), .dsc.json, commit, baseline, start.
D=/private/tmp/claude-501/-Users-milankinzy-Documents-deadfront-siege/72cebc8b-d241-430b-9ea6-94d65339bfef/scratchpad/dsc
k=$1; kind=$2; model=${3:-}
T=/Users/milankinzy/Documents/deadfront-siege/.claude/worktrees/mmo-$k
[ -d "$T" ] || { echo "$k: no tree"; exit 1; }
cd "$T" || exit 1
mkdir -p docs/orchestration/dsc
f=docs/orchestration/dsc/$k-TASK.md
if [ "$kind" = code ]; then
  lab=$(bash -c ". $D/job_$k.conf; echo \$LAB")
  { cat $D/staging/$k-TASK.md; sed -e "s/KEY/$k/g" -e "s/--lab=LAB/--lab=$lab/g" $D/common-footer.md; } > $f
  V="bash $D/verify_job.sh $k"; MS="bash $D/verify_job_ms.sh $k {n}"
  prot='"docs/reference/**", "game/project.godot", "game/override.cfg", "game/tests/t_save.gd", "game/scripts/camera/iso_camera.gd"'
else
  { cat $D/staging/$k-TASK.md; sed -e "s/KEY/$k/g" $D/staging/blender-footer.md; } > $f
  V="bash $D/verify_blender.sh $k"; MS="bash $D/verify_blender.sh $k m{n}"
  prot='"docs/reference/**", "game/project.godot", "game/override.cfg", "game/scripts/**", "game/tests/**"'
fi
cat > .dsc.json <<JSON
{
  "watchdogIdleSec": 0,
  "maxTurns": 300,
  "checkpointExclude": ["*_Image_*.jpg", "game/assets/props/meshy/*", "*.pyc", "__pycache__/**", "*.orig", "*.rej", "*.blend1"],
  "protectedPaths": [$prot],
  "mapIgnore": ["game/assets/creatures/**", "game/assets/characters/**", "archive/**", "assets/**", "research/**", "hosting/**"]
}
JSON
git add $f && git commit -q -m "$(echo $k | tr a-z A-Z) task

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
echo "$k baseline: $(bash -c "$V 1" 2>&1 | grep -m1 FAIL)"
margs=(); [ -n "$model" ] && margs=(--model "$model")
dsc cook start $f --once --verify "$V" --milestone-verify "$MS" "${margs[@]}" --budget 6 --max-hours 6 --effort medium 2>&1 | grep -E "started|rror" | sed "s/^/$k: /"
