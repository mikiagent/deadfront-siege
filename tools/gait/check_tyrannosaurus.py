#!/usr/bin/env python3
"""SP-TYRANNOSAURUS species gate: every T. rex clip on the v2 skin through check_rex_clips.py (sink, float, slip,
airborne, ends, moonwalk; the lying clips rest on the floor). Exit 0 only on REXCHECK PASS.

usage: python3 tools/gait/check_tyrannosaurus.py      (BLENDER=... overrides the Blender path)
"""
import glob
import os
import subprocess
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
D = os.path.join(ROOT, "game/assets/creatures/tyrannosaurus")
BL = os.environ.get("BLENDER", "/Applications/Blender.app/Contents/MacOS/Blender")
out = subprocess.run([BL, "-b", "-P", os.path.join(ROOT, "tools/gait/check_rex_clips.py"), "--", os.path.join(D, "tyrannosaurus.glb")]
                     + sorted(glob.glob(os.path.join(D, "anim/*.glb"))), capture_output=True, text=True)
print("\n".join(l for l in out.stdout.splitlines() if l.startswith("REXCHECK")))
sys.exit(out.returncode)
