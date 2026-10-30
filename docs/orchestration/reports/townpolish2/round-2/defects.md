# Round 2 (roads drawn, town domain, occlusion box test)

1. **Streets render black** (spot, phone): cull_disabled showed the back faces, whose flipped normals
   point down. Fixed by winding the quads clockwise and going back to cull_back.
2. Ground pale mint in clear daylight (market_game_day): meadow tint. Town zone -> the climate's lush
   zone (forest on grassland).
3. Street shots show the survivor knee-deep (homes_street_day): the known teleport ground-snap issue of
   the capture script's _place_player (round-6 leftover, player package), not the road.
4. Windows: lit panes sit flush in the frames at night (phone/homes_game_night). Done.
5. Houses beside the survivor no longer fade; the one between camera and survivor does. Done.
6. t_tutorial: bot fails tut_drink, routes back and forth outside the north gate.
