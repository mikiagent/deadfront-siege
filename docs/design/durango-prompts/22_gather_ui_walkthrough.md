# 22. Gather UI and the walkthrough guide (owner, 2026-10-20)

Owner's words, verbatim: "notice the game ui and how the resource gathering looks. The finger icon is a walkthrough guide"

The screenshot came with the message but was not saved to disk. The rest of this file is the orchestrator's reading of it.

- **Gather options at the node.** After tapping a Date Palm, a label "Date Palm / Lv. 1" sits over the node. Dark hexes float beside it, one per harvestable part. Each hex has a white part icon, the gather time on top ("1.0s"), and the yield count at the bottom right ("2", "3"), with the part name in a dark tag to its right ("Large Leaf", "Date").
- **Walkthrough guide.** A large white pointing hand, the "finger icon", hovers over the hex the player should tap next. It is a tutorial pointer tied to the current objective.
- **Quest tracker** (top right, under the minimap): "Find Food" with a checkbox row "Tropical Fruit Gathering 0 / 3".
- **HUD.**
  - Top left: health 376/376, stamina 106/108 and a fatigue bar with a face icon.
  - Under the vitals: a buff/skill icon with a count.
  - Top right: the minimap with coordinates and a target dial, and a collapse arrow over two companion portraits.
  - Bottom left: menu, heart, chat and keyboard buttons, plus a mount/switch button.
  - Bottom right: combat and search buttons and an outfit button.
- **Base today:**
  - A gather radial exists (W1-UI gather_radial.gd).
  - An Orders tracker exists ("ORDERS 1/28 · Gather 3 branches · Tap a tree and pick Branch... 0/3").
  - W2-GATHER (in finish-6) adds tool-dependent gather times and "+n Item" popups.
