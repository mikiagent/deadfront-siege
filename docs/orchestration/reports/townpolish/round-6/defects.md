# Round 6 (final; canon 48f132d3 merged, north-up camera)

Fixed since round 5: the t_tutorial bot no longer wedges in town (wickets restored, no wicket post
beside a gate tower, gate towers block every tile they cover, lamps keep 2 m off walls and posts,
clutter stays out of the router grid). No ship-blocking defect found.

| # | Note (not ship-blocking) | Where seen |
|---|---|---|
| R6-1 | A pale bite in a ring road where the road strip breaks on a wet/steep point (the terrain shows through). | workshops_wide_day (bottom centre) |
| R6-2 | Lamps 41 -> 24: lamps that would stand in a pinch beside a house are skipped (t_tutorial needs >= 20). | build line |
| R6-3 | Plain grass between some homes (see round 5 R5-1). | homes_* |
| R6-4 | Occlusion dither and the survivor's slope snap after a teleport (other packages; see round 5). | homes_wide_day |
