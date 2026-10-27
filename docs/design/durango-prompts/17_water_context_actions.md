# 17. Water context actions (owner, 2026-10-20)

Owner's words, verbatim: "when next to water, menu items pop up like washing and drinkinh"

Reference: `docs/reference/durango-water-actions.webp` (the Durango HUD). The rest of this file is the orchestrator's reading.

- **In the reference:** the survivor stands in shallow water at the beach. The bottom-right hex cluster shows the sprint hex plus two water hexes, Wash (a hand under drops) and Drink (a cup with a drop). "Shoal of Fish", reed and clam nodes are labelled nearby.
- **What the PRD binds:**
  - :105: "Contextual prompts appear when standing on/near interactables (water: drink / wash / fill container)."
  - :314: "Fresh water: drink (cuts heat fatigue), wash (clears dirty), fill containers ..."
  - §6.3 :409-416: Hungry / Thirsty / Full / Quenched are status effects that change the fatigue rate, not meters.
  - :434 and :447: Dirty and Very dirty raise fatigue by 20 % and 50 % until washed. "Dirt is not cosmetic. Wash in water."
  - :284: standing in water for 5 s makes the survivor Wet.
  - :72 and :1030: no hunger, thirst or temperature meters.
- **What the base already has:**
  - `player_input.gd` context_actions shows Drink and Wash when `in_water` is true, or when the terrain under the survivor is below 0.15 m. It misses a survivor standing NEXT to the water.
  - Drink adds 5 energy, and Wash rests 2 fatigue. Neither effect matches the PRD.
  - The white drink.svg and wash.svg icons exist.
