# Joint positions of the Triceratops rig in the prep frame (Blender: head +Y, right side +X, feet on z=0, 9.0 m from
# beak tip to tail tip, 4.645 m to the frill top). Measured on the mesh with overlay.py renders (0.1 m grid) and the
# leg-column and sagittal cross-sections in measure.py. Each bone: (head, tail, parent). .R bones are given; .L mirror x.
import numpy as np
J = {
 "Hips":   ((0, -1.40, 2.95), (0, -0.50, 3.00), "root"),
 "Spine1": ((0, -0.50, 3.00), (0, 0.40, 2.98), "Hips"),
 "Spine2": ((0, 0.40, 2.98), (0, 1.20, 2.92), "Spine1"),
 "Chest":  ((0, 1.20, 2.92), (0, 1.95, 2.85), "Spine2"),
 "Neck1":  ((0, 1.95, 2.85), (0, 2.25, 2.80), "Chest"),
 "Neck2":  ((0, 2.25, 2.80), (0, 2.55, 2.75), "Neck1"),
 "Head":   ((0, 2.55, 2.75), (0, 4.10, 2.45), "Neck2"),
 "Jaw":    ((0, 3.08, 2.40), (0, 3.97, 2.08), "Head"),
 "UpperArm.R": ((0.78, 1.40, 2.30), (0.84, 1.15, 1.38), "Chest"),
 "Forearm.R":  ((0.84, 1.15, 1.38), (0.76, 1.38, 0.54), "UpperArm.R"),
 "Hand.R":     ((0.76, 1.38, 0.54), (0.78, 1.62, 0.14), "Forearm.R"),
 "Finger.R":   ((0.78, 1.62, 0.14), (0.80, 1.98, 0.05), "Hand.R"),
 "Thigh.R":      ((0.62, -1.40, 2.50), (0.66, -1.22, 1.32), "Hips"),
 "Shin.R":       ((0.66, -1.22, 1.32), (0.63, -1.58, 0.55), "Thigh.R"),
 "Metatarsal.R": ((0.63, -1.58, 0.55), (0.64, -1.32, 0.14), "Shin.R"),
 "Toe.R":        ((0.64, -1.32, 0.14), (0.66, -0.98, 0.05), "Metatarsal.R"),
}
TAIL_Y = (-2.0, -4.744)
def tail_z(y):  # tail centreline: mid of the top and bottom of the |x|<0.3 slices, smoothed
    ys = [-2.0, -2.5, -3.0, -3.5, -4.0, -4.5, -4.744]; zs = [2.75, 2.66, 2.48, 2.24, 2.12, 2.08, 2.06]
    return float(np.interp(y, ys[::-1], zs[::-1]))
NT = 6
for i in range(NT):
    y0 = TAIL_Y[0] + (TAIL_Y[1] - TAIL_Y[0]) * i / NT; y1 = TAIL_Y[0] + (TAIL_Y[1] - TAIL_Y[0]) * (i + 1) / NT
    J[f"Tail{i+1}"] = ((0, y0, tail_z(y0)), (0, y1, tail_z(y1)), "Hips" if i == 0 else f"Tail{i}")
for k in [k for k in list(J) if k.endswith(".R")]:
    h, t, p = J[k]
    J[k[:-2] + ".L"] = ((-h[0], h[1], h[2]), (-t[0], t[1], t[2]), p[:-2] + ".L" if p.endswith(".R") else p)
ORDER = ["root"] + list(J)
