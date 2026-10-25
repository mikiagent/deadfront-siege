# World generation, travel and climate

## Region templates
The original data contains 262 region templates: 212 normal islands, 11 frontier, 9 safe house, 8 civilized, 6 ruins, 5 Tamed Island, 4 season/PvP, 4 Ancora and 3 trial. These are region definitions, not 262 simultaneously active playable islands.

## Common climates
Temperate forest (neutral); tropical forest (heat); desert (scorching sun); tundra (chill); snowfield (strong winds); savanna/grassland (neutral); swamp (humid); volcano (special volcanic); bamboo forest (neutral).

## Sailing
Harbors launch an island-selection interface with archipelago, island level and unstable index progression. Unstable index limits and lower-level island handling vary between original definitions and restoration balancing.

## Weather
Weather tables are original named classifications but their weights and times are estimated in the restoration. Example normal table: Sunny 45%, Cloudy 30%, Rain 18%, Heavy Rain 7%. Tundra/snow table includes Snow and Heavy Snow. These figures should be treated as fork estimates.

## Environmental status
Wet increases discomfort from cold; shade alleviates heat; indoor Home and camp Cozy reduce climate-related effects. Specific resistance coefficients are listed on the wiki; distinguish original status definitions from the restoration's estimated scheduling and application logic.

## Island encounter planning
Island-specific level, herds, resources and craters connect exploration to fatigue, crafting and pet progression. Recreate island templates as declarative biome records, not hardcoded map-specific special cases.

References: [World, sailing and weather](https://kghj76138.github.io/durango-homecoming-guide/en/world.html), [Gathering and islands](https://kghj76138.github.io/durango-homecoming-guide/en/gather.html).
