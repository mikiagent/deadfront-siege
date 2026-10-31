#!/bin/bash
# UTAHARMS (owner 2026-10-31: "utahraptor is in a pretty good state, it just needs to use its arms in the attacks too
# sometimes"): the utahraptor's arms in its attacks, nothing else redone.
#   grab_bite  = its attack_primary (the deinonychus bite moved across) + raptor_overlay.py's grab-and-rake;
#                TacticalBrain plays it for half the bites (utahraptor.json tactics.bite_alt / bite_alt_chance)
#   bite_combo = the lunge combo with the arm rakes added (one hand per bite, both on the third)
# --keep adds the arm turns on top of the clip's own and keeps its tail; --arm-gain 0.6 --shoulder 0 keeps the chest
# skin under the gate (the full raptor amplitude on the shoulder root stretched a torso edge 19x).
# Gate: Blender -b -P tools/gait/check_raptor.py -- utahraptor.glb <dir> --height 4.62 (stretch; its bites inherit
# the deinonychus step-in float of 0.26 m)
set -euo pipefail
cd "$(dirname "$0")/../.."
BL=${BLENDER:-/Applications/Blender.app/Contents/MacOS/Blender}
U=game/assets/creatures/utahraptor; DE=game/assets/creatures/deinonychus
T=$(mktemp -d)
run() { "$BL" -b "$@" > "$T/log_$RANDOM.txt" 2>&1 || { echo "FAILED: $*"; exit 1; }; }
mkdir -p $T/x
run -P tools/gait/transfer_clips.py -- $DE/deinonychus.glb $U/utahraptor.glb $T/x $DE/anim/attack_primary.glb $DE/anim/bite_combo.glb --floor-feet --pin-toes
run -P tools/gait/raptor_overlay.py -- $U/utahraptor.glb $T/x/attack_primary.glb $U/anim/grab_bite.glb --clip attack_primary --name grab_bite --keep --arm-gain 0.6 --shoulder 0
run -P tools/gait/raptor_overlay.py -- $U/utahraptor.glb $T/x/bite_combo.glb $U/anim/bite_combo.glb --clip bite_combo --keep --arm-gain 0.6 --shoulder 0
rm -rf "$T"
echo "UTAH ARMS OK"
