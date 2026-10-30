# Round 4 defects (after round 3 fixes)

Fixed since round 3: no wicket posts in the gate openings (gate_144_day), stall lanterns at night
(market_game_night), short grass kept in town.

| # | Defect | Where seen | Severity |
|---|---|---|---|
| R4-1 | Crop beds sink under the grass on sloped fields: every 2 m bed stood at the lot's lowest corner, so the soil and furrows were buried and the crops stood on lawn. (Round 3's "tilled bed under each crop" was the wrong fix and is reverted: field_crop_N already carries its bed.) | farms_wide_day | major |
| R4-2 | An open window hole shows the sky-lit roof underside on one log house (homes2_wide_day, left house, side wall). Not reproduced on other houses; window glow boxes sit in every other window. | homes2_wide_day | minor (watch) |
| R4-3 | Street probe: the survivor stands knee-deep on slopes even with the probe reading the ground height; the town pieces beside him sit on the ground, so it is the player's ground snap in a teleport, not the town. | homes_street_day | probe / not this package |
