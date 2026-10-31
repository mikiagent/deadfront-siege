# Animal encyclopedia, combat and butchering

## Animal catalog
The wiki identifies 220 registered wild species, including 214 from original animal definitions and six introduced or cloned in the restoration. Of these, 64 are listed as tameable; 97 occur on reachable restoration islands. **Species-count is not the same as unique visually modeled animals available in 2019.**

## Per-species records
The animal encyclopedia shows habitat, level bands, life/attack/defense, Kill XP, body-part butchering yields, material attributes and taming eligibility. The combat page includes combat rolls, breakable parts, AI/ecology behavior and bosses.

## Implementation implications
Represent each species as data containing movement and attack patterns, collision/anatomy, habitat, difficulty, harvest tables and taming flags. Animal-specific loot generates *individual* material instances. Combat and butchering should reference the same persistent wild-animal ID; deplete body parts rather than infinitely respawning meat from a corpse.

## Provenance warning
Animal combat rolls, spawning ecology, server-side loot distribution and boss logic include many Estimated restoration rules. Extract original data fields separately, then balance new AI independently.

References: [Animal formulas](https://kghj76138.github.io/durango-homecoming-guide/en/animals.html), [220-animal encyclopedia](https://kghj76138.github.io/durango-homecoming-guide/en/animals-list.html).
