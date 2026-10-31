# ALPHA triceratops joints (prep frame: head +Y, right +X, feet on z=0, 10.93 m beak to tail, 4.645 m to the frill top).
# Same bone names, parents and roll rules as the regular triceratops (joints.py on the regular rig), placed on the
# alpha's bulkier, wider, lower-necked Tripo body. .R bones are given; .L mirror x.
import numpy as np
J = {
 "Hips":   ((0, -1.50, 2.55), (0, -0.60, 2.65), "root"),
 "Spine1": ((0, -0.60, 2.65), (0, 0.30, 2.70), "Hips"),
 "Spine2": ((0, 0.30, 2.70), (0, 1.10, 2.65), "Spine1"),
 "Chest":  ((0, 1.10, 2.65), (0, 1.80, 2.50), "Spine2"),
 "Neck1":  ((0, 1.80, 2.50), (0, 2.10, 2.40), "Chest"),
 "Neck2":  ((0, 2.10, 2.40), (0, 2.40, 2.30), "Neck1"),
 "Head":   ((0, 2.40, 2.30), (0, 4.00, 1.90), "Neck2"),
 "Jaw":    ((0, 2.78, 2.05), (0, 3.42, 1.62), "Head"),
 "UpperArm.R": ((1.00, 1.00, 2.00), (1.12, 0.85, 1.15), "Chest"),
 "Forearm.R":  ((1.12, 0.85, 1.15), (1.15, 1.22, 0.50), "UpperArm.R"),
 "Hand.R":     ((1.15, 1.22, 0.50), (1.16, 1.58, 0.14), "Forearm.R"),
 "Finger.R":   ((1.16, 1.58, 0.14), (1.17, 1.98, 0.05), "Hand.R"),
 "Thigh.R":      ((0.85, -1.45, 2.20), (1.05, -1.22, 1.20), "Hips"),
 "Shin.R":       ((1.05, -1.22, 1.20), (1.15, -1.65, 0.55), "Thigh.R"),
 "Metatarsal.R": ((1.15, -1.65, 0.55), (1.18, -1.25, 0.14), "Shin.R"),
 "Toe.R":        ((1.18, -1.25, 0.14), (1.19, -0.95, 0.05), "Metatarsal.R"),
}
TAIL_Y = (-2.1, -6.5)
def tail_z(y):
    ys = [-2.1, -3.0, -4.0, -5.0, -6.0, -6.5]; zs = [2.55, 2.2, 1.95, 1.8, 1.6, 1.48]
    return float(np.interp(y, ys[::-1], zs[::-1]))
NT = 6
for i in range(NT):
    y0 = TAIL_Y[0] + (TAIL_Y[1] - TAIL_Y[0]) * i / NT; y1 = TAIL_Y[0] + (TAIL_Y[1] - TAIL_Y[0]) * (i + 1) / NT
    J[f"Tail{i+1}"] = ((0, y0, tail_z(y0)), (0, y1, tail_z(y1)), "Hips" if i == 0 else f"Tail{i}")
for k in [k for k in list(J) if k.endswith(".R")]:
    h, t, p = J[k]
    J[k[:-2] + ".L"] = ((-h[0], h[1], h[2]), (-t[0], t[1], t[2]), p[:-2] + ".L" if p.endswith(".R") else p)
ORDER = ["root"] + list(J)
# Weighting tunables read by build_rig.py (TRIKE_JOINTS=joints_alpha); see build_rig.py for what each one does.
COLS = ((1.12, 1.02, 0.52, 0.74), (1.08, -1.45, 0.56, 0.76))  # leg columns (x, y, rx, ry): wider-set, thicker legs
COL_Z = (1.15, 1.45)          # the belly is at ~0.95 m (regular 1.4)
TRUNK_Z = (0.60, 0.90)
UP_R, SHIN_R, SHIN_Z = (0.80, 1.05), (0.60, 0.75), (1.25, 1.45)
TAIL_HW = ([-6.5, -5.0, -3.7, -2.8, -2.3, -2.0], [0.10, 0.30, 0.50, 0.75, 1.00, 1.20])
BODY = (0.60, 2.2, -2.9)
FRILL_CAND = (1.30, 2.50)
C_NECK, C_CHEST = (0.0, 2.05, 2.40), (0.0, 1.25, 2.50)
WING = (0.5, 2.9, 1.30)
HEAD_Y = (2.15, 2.30)
# mouth line (the Tripo mesh has a thin open slit from the corner y 2.8 to the beak hook)
MOUTH = ([2.80, 3.00, 3.20, 3.45, 3.60], [2.16, 2.03, 1.87, 1.68, 1.55])
JAW_Y, JAW_X, JAW_ZMIN = (2.72, 2.90), (0.50, 0.62), 1.30
ROSTRAL = (3.40, 0.0, 0.0)  # the hooked upper beak (y > 3.40) stays on Head
# |x| >, y >, z >: the solid frill and its rim spikes ride Head rigidly (its rear face reaches back to y 1.29 at the wings)
FRILL_BOXES = ((0.0, 1.45, 2.75), (0.75, 1.20, 3.05), (1.15, 1.20, 2.55), (0.0, 1.20, 3.85))
KNEE_DY = (0.80, 1.10)   # the thigh/upper arm own the flank further from the knee/elbow (bulky body)
FOOT_BLEND = 0.12        # the rigid foot's top 12 cm blends into the leg
SMOOTH_BOXES = ((0.85, -0.95, 0.0, 0.9, 1.9, 40),)  # the thin web of skin between the thigh front and the belly
