# Round 0 (baseline, canon d1f710b3) defects

Shots: rain/ (game camera, rain, 1600x900), spot/ (the owner's broken-road spot, x -27 z 231).

1. **Windows protrude as dark slabs** (homes_game_day: the side walls of the left and right houses).
   Cause: `house()` built the window glow pane with `Basis.scaled()`, which scales in WORLD axes. On a
   wall turned 90 degrees (or any yaw) the 0.04 m "thickness" landed along the wall and the 0.86 m
   width stuck straight out of it: a skewed slab, which reads as a card facing the camera. Same bug
   skewed the plinths, corner posts, stall canvas, lanterns and workshop plinths on every turned lot.
2. **Road clips into the terrain** (spot_*): the dirt strip had a vertex every 2 m at its two edges
   only; a hill north of the camp (9 m within 60-100 m) bulged through the middle. A strip also broke
   wherever `is_dry` failed, leaving jagged triangular ends and slivers.
3. **Rock patch over the road** (spot_*): the dark cobble is the terrain's ROCK paint on that hill
   (slope > 0.72), not a decal; the road ran up it.
4. Washed-out yellow-green ground in town (homes_game_day): a savanna patch of the biome noise falls on
   the town (only a 21 m camp disc was forced to meadow).
5. Round-6 leftovers: bare grass between homes, double fence posts at joins, houses fading while beside
   the survivor, arbitrary-angle houses (owner: lock to the grid, face south).
