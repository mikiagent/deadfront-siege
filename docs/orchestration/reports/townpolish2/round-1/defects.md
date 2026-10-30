# Round 1 (grid re-layout, flat town, scaled_local fix)

Fixed since round 0: windows are flat panes in their frames (scaled_local), the town is one plane (no
rock patch, no bulges), every lot is on the 1 m grid in 90 degree steps, fronts south by default.

1. **No streets drawn at all** (spot_wide_day, homes_wide_day): the tile quads were wound
   counter-clockwise from above, so cull_back dropped every one.
2. Ground still pale yellow-green in clear daylight: the town now gets meadow, which is itself pale.
3. Trees were CardProp painted cards (later owner direction: 3D only, no new cards).
4. Only one gate (north): the E, S and W avenue ends are in the sea or on the beach. Accepted.
