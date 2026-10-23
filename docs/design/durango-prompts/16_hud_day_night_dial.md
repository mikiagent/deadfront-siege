# 16. Day/night dial next to the minimap (owner, 2026-10-20)

Owner's words, verbatim: "We don't have the day/night cycle component in the UI next to the map"

Reference: `docs/reference/durango-hud-daynight.webp` (the Durango gameplay HUD). The rest of this file is the orchestrator's reading.

- **In the reference:** a small round day/night dial sits just left of the round minimap, in the top-right cluster. The minimap shows coordinates under it ("X 639 Y 457"). The quest tracker sits below that cluster, and the portrait column runs down the right edge.
- **Already in the game:** a day/night cycle, `Game.time_of_day` (0 = midnight, 0.5 = noon), and `Game.phase_name()` returning dawn, day, dusk or night. Lighting follows the cycle through lighting.json, and some climates set `day_night`.
- **Cycle length:** PRD:289 says "Cycle length was not found. Do not invent a 24-minute day." The dial reads the game's own cycle and never sets it.
