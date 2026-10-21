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
