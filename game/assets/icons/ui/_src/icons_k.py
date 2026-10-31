"""Sixth drawing pass (PETRADIAL, spec 23, docs/reference/durango-pet-radial.webp): Ride, a rider on a
dinosaur's back holding the reins, and Rename, a hide name tag with a portrait and name lines cut
through (the reference's name card). Solid polygons only, centred optically by geo2.place."""
from geo2 import *
from icons_g import chaikin

G = {}

# ride: a long-necked dinosaur facing right, two legs, the rider on its back, an arm to the neck.
BODY = chaikin([(5, 33), (14, 31), (24, 29.5), (36, 30), (42, 26), (45, 18), (49, 13.5), (55, 13.5), (59, 16.5), (57, 19.5),
                (51, 20.5), (48.5, 27), (47, 36), (42, 43), (32, 45.5), (21, 44.5), (14, 39)], 2)
G["ride"] = [([BODY, capsule((22, 42), (20, 56), 6.4), capsule((39, 42), (41, 56), 6.4),
               circle(27, 10, 4.8), band([(27, 16.5), (26.5, 27)], 8.0), band([(29, 19), (37, 22.5), (44.5, 20)], 4.4)], False)]

# rename: a stretched hide tag (uneven edges), the portrait (head and shoulders) and three name lines cut out.
TAG = chaikin([(7, 15), (20, 13.5), (32, 14.5), (45, 13.5), (57, 15), (56, 32), (57.5, 49), (44, 50.5), (32, 49.5), (19, 50.5),
               (6.5, 49), (8, 32)], 1)
SHOULDERS = arcp(19.5, 44, 9.5, 180, 360, 16)
G["rename"] = [([TAG, circle(19.5, 26, 5.2), SHOULDERS, capsule((33, 23), (50, 23), 4.4), capsule((33, 32), (50, 32), 4.4),
                 capsule((33, 41), (44, 41), 4.4)], True)]

I = place(G)
