# Tree transparency and gather UI checks (2026-10-20)

Both checks are read-only. They compare our build with the owner's references: spec 21 for the trees, spec 22 for gathering.

## Trees (spec 21)

**The fade works.**
- Share of the survivor that shows in the frame:

  | Spot | Trees solid | Trees faded |
  |---|---|---|
  | temperate_25, three crowns in the way | 0.035 | 0.575 |
  | home_grassland | 0.48 | 0.77 |
  | tropical_25 | 0.68 | 0.85 |

- Compat and Forward+ agree to within 0.002.

**Gaps against the reference:**
- The trunk is dithered along with the crown; the reference keeps the trunk solid.
- Overlapping faded crowns merge into one pale mass.
- A crown over water washes out to a tint.
- The 4x4 dither shows as a screen-door pattern at 1:1.

**Forest density is the biggest gap.**
- The densest spots hold 3-6 trees, and about 90 % of the frame is flat green ground.
- island_scatter.gd uses fixed floors that do not scale with area. Unstable islands get about 4 trees per hectare; home gets about 24.
- Fix: scale the floors by planted area, or plant forest patches of 15-30 trees. Add 2-4 understory props per clump (Plant, Rock_Moss, WoodLog_Moss, TreeStump_Moss).

**Lighting:**
- Fixes:
  - Raise ambient from 0.3 to about 0.45.
  - Soften the sun: light_angular_distance about 1.5 deg in Forward+, shadow_blur about 1.5 in compat.
- Forward+ comes out darker than compat.
- Home ground turns olive in Forward+.

**Occlusion fix:** skip the discard below about 3 m for "between" props, so trunks stay solid. The occlusion_lab tree_kept gate then needs new limits.

## Gather UI (spec 22)

**Gather time on the hex:**
- It reads a static table (HarvestNode.OPTION_SECONDS), so it will be wrong once W2-GATHER's tool timing merges: a bare-handed branch takes about 2.2 s while the hex says 1.6 s.

**Hex count, name tag and node label:**
- The count is passes left in the node, not the yield.
- The name tag floats in a separate box.
- The node label sits in an opaque box.
- The names read backwards ("Bush Berries").

**Hex look and placement:**
- Ours are pointy-top with a thin outline; Durango's are flat-top with a thick rim and a large white icon.
- Ours sit 120-180 px apart, and the layout re-solves every frame, so the hexes jump sides while the survivor walks.

**Orders card:**
- No quest-name header and no checkbox.
- The hint is cut off.
- At 844x390 the card hides while a creature plate is up.
- Order 1's hint mentions a "wheel" that does not exist.

**No tutorial pointer exists anywhere.** GUIDE builds one: a resolver from each step to its target (node, hex, HUD control, station or creature), shown the first time only and saved.

**Package scopes and gates:** the GATHERUI and GUIDE scopes and gates are in each package's workflow script, under handoff/workflows/.
