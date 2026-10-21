# Joint positions of the Deinonychus rig in the prep frame (Blender, head +Y, right side +X, feet z=0, 3.6 m tall).
# Each bone: (head, tail, parent). .R bones are given; .L mirror x.
J = {
 "Hips":   ((0, -0.45, 2.36), (0, 0.05, 2.44), "root"),
 "Spine1": ((0, 0.05, 2.44), (0, 0.45, 2.47), "Hips"),
 "Spine2": ((0, 0.45, 2.47), (0, 0.85, 2.48), "Spine1"),
 "Chest":  ((0, 0.85, 2.48), (0, 1.18, 2.56), "Spine2"),
 "Neck1":  ((0, 1.18, 2.56), (0, 1.42, 2.86), "Chest"),
 "Neck2":  ((0, 1.42, 2.86), (0, 1.60, 3.08), "Neck1"),
 "Neck3":  ((0, 1.60, 3.08), (0, 1.80, 3.20), "Neck2"),
 "Head":   ((0, 1.80, 3.20), (0, 2.74, 3.02), "Neck3"),
 "Jaw":    ((0, 2.02, 3.03), (0, 2.64, 2.88), "Head"),
 "Arm.R":     ((0.36, 1.05, 2.25), (0.52, 0.78, 1.82), "Chest"),
 "Forearm.R": ((0.52, 0.78, 1.82), (0.56, 1.20, 1.48), "Arm.R"),
 "Hand.R":    ((0.56, 1.20, 1.48), (0.60, 1.32, 0.92), "Forearm.R"),
 "Thigh.R":      ((0.30, -0.40, 1.90), (0.36, 0.02, 1.42), "Hips"),
 "Shin.R":       ((0.36, 0.02, 1.42), (0.27, -0.45, 0.82), "Thigh.R"),
 "Metatarsal.R": ((0.27, -0.45, 0.82), (0.30, -0.36, 0.12), "Shin.R"),
 "Toe.R":        ((0.30, -0.36, 0.12), (0.40, 0.42, 0.03), "Metatarsal.R"),
 "Sickle.R":     ((0.22, -0.34, 0.20), (0.17, 0.08, 0.40), "Metatarsal.R"),
}
TAIL_Y = (-0.45, -5.37)
def tail_z(y):  # tail centreline from the slices (median of |x|<0.25 above z 0.9), smoothed
    import numpy as np
    ys = [-0.45, -1.2, -2.0, -3.0, -4.0, -5.0, -5.37]; zs = [2.36, 2.36, 2.38, 2.44, 2.40, 2.30, 2.24]
    return float(np.interp(y, ys[::-1], zs[::-1]))
NT = 8
for i in range(NT):
    y0 = TAIL_Y[0] + (TAIL_Y[1] - TAIL_Y[0]) * i / NT; y1 = TAIL_Y[0] + (TAIL_Y[1] - TAIL_Y[0]) * (i + 1) / NT
    J[f"Tail{i+1}"] = ((0, y0, tail_z(y0)), (0, y1, tail_z(y1)), "Hips" if i == 0 else f"Tail{i}")
for k in [k for k in list(J) if k.endswith(".R")]:
    h, t, p = J[k]
    J[k[:-2] + ".L"] = ((-h[0], h[1], h[2]), (-t[0], t[1], t[2]), p[:-2] + ".L" if p.endswith(".R") else p)
ORDER = ["root"] + list(J)
