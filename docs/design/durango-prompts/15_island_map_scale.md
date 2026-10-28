# 15. Island scale, shape and the map screen (owner reference, 2026-10-20)

Owner's words, verbatim: "To give you an idea of the scale and shape of an island, as well as the UI"

Reference: `docs/reference/durango-island-map.webp` (Durango: Wild Lands map screen, 1306x624). The rest of this file is the orchestrator's reading of that screenshot, not the owner's text.

What the screenshot shows:
- **Island scale.**
  - Using the 50 m scale bar, the island measures about 165 x 215 m (an estimate from the screenshot).
  - It is a "Lv. 10 Tamed Island" in the Grassland climate.
  - Our docs agree: world-design.md gives 240 x 240 m for unstable islands, and rules.json sets the home island at 160 m. Note that island_runtime.gd builds unstable islands at twice the far-shore radius, about 480 m across.
- **Island shape.**
  - The coastline is irregular, not round. The revealed land is a ragged ring of beach and grass around a fogged interior, with dark rock patches.
  - The player's claimed domain is the orange strip on the south coast, next to the harbour anchor. A dotted trail shows the route walked.
- **Map rendering.** A painted, watercolour-like top-down map. Unexplored areas are covered by drifting cloud (fog of war), and water is blue-grey.
- **Left info panel.**
  - Header art with "Lv. 10 Tamed Island" and a tree silhouette.
  - Rows: Climate (Grassland), Island Life Span (- for a stable island), Current Fatigue 0 / 100 with a bar and a face icon, and Fatigue Change Rate 0.
  - A white laurel emblem with "An island with no great difficulties.", and a 50 m scale bar at the bottom.
- **Map markers.**
  - The player's arrow sits in a gold ring with coordinates under it ("X 453 Y 345").
  - "<name>'s Domain" is shown with the owner's portrait. The harbour is an anchor icon, and small blue markers appear along the coast.
- **Legend (bottom right):** Your Location, Other Player, Shelter, Harbor, Bonfire.
- **Buttons and controls:** "To Harbor" and "To Waypoint" at the bottom right, and a close X at the top right.

## Landmarks and the exploration reward (owner screenshot, 2026-10-27)

Pasted screenshot (not on disk); the reading follows. It is the same left info panel as the stable-island reference above, for a settled island — Safe House No. 9 (banner: palm art, "Lv. 5 The Company's Safe House"):
- Over the familiar Climate / Island Life Span / Current Fatigue 0/277 / Fatigue Change Rate rows, two additions: **Landmarks Found 2 / 13** with a small progress bar, and an **Exploration Reward** row paying out coins (151). Landmark discovery is tracked per island, and the market currency is its reward channel.
- The action button on this variant is "To Camp" (the stable-island reference shows To Harbor / To Waypoint).
- The marker cluster keeps the compass pin shelter/harbour icons and "X 409 Y 390" coordinates; the laurel emblem and flavour line ("An island with no great difficulties.") are unchanged.
- For us: `islands-and-loop-plan.md` currently budgets **one landmark per island**; 2/13 found suggests the original tracked several per island. Fold "Landmarks Found x / y" into the landmark spec and decide the reward rate with the ECON owners — a per-landmark payout, not a lump sum, keeps discount on partial exploration honest.

## The Sail menu (owner, second screenshot, same day)

Owner's words, verbatim: "Menu scrolls rightward and has many islands"

The screenshot arrived with the message but was not saved to disk, so it is not in docs/reference. The text below is the orchestrator's reading of it.

- **Header:** "Sail" with a back arrow, a map/chart item counter ("0 +"), the coin counter (12,330) and a close X. A round button at the top right has a ship/clock icon.
- **The map itself:**
  - It is a horizontal sea chart that scrolls to the right, with a compass rose and drifting clouds.
  - The sea is cut into vertical bands that get darker and higher-level as you go right.
- **Named islands on the left.**
  - Ancora Lv. 1 and The Company's Safe House Lv. 5 have small palm-tree icons.
  - Moon City Island Lv. 10 is shown with its actual island shape, a red location pin and a house icon (home).
- **Sea zones further right.** Each is a round icon with ripple rings, its climate art, and a name and level:
  - Savanna Sea Lv. 15 (umbrella tree)
  - Tropical Sea Lv. 18
  - Temperate Sea Lv. 20 (a "?" icon: not yet discovered)
  - Tropical Sea Lv. 25
  - Tundra Sea Lv. 30 (snowy pine)
- **Zone badges.** Discovered zones carry a green check; some also carry a gold swirl badge.
- **What this means for us:** a sea of many islands ordered by level from left to right. You pick a destination here, and the harbour sails you there.
