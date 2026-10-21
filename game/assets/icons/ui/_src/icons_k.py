"""Sixth drawing pass (REST): the Rest context action and the Resting chip. Solid polygons only,
centred optically by geo2.place like icons_g..j."""
from geo2 import *
from icons_g import figure

G = {}

# rest: the survivor sitting on the ground, leaning back on one straight arm with the knees up (sleep
# is the moon; heel, kick and chase are standing or running figures).
G["rest"] = [(figure((15.5, 12), [[(19.5, 27), (9.5, 47.5)], [(28, 46.5), (40.5, 30), (50, 50)]], w=7.0,
                     torso=[(20, 25.5), (28, 46)]), False),
             ([capsule((5, 56.5), (59, 56.5), 5.0)], False)]

I = place(G)
