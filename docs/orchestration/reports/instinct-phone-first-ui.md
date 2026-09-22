# Phone-first first-run UI and contextual sheets

## Shipped
- Character creation detects short phone-landscape viewports. At 844x390 it uses a 4-column by 2-row occupation grid, 18 px card text, short skill-first copy, and a compact single-row identity/start bar. Desktop keeps the richer story copy.
- Terrain choice is now a compact bottom card with five colored terrain previews and 18 px labels instead of five anonymous rows.
- Harbour, pause, and fallback map/station panels now use a bottom sheet over a 42% scrim. The game world remains visible; the first action is a large green primary button and the close target is 54 px.
- No deployment was performed. Player interaction routing and web shell code are untouched.

## Validation
- `tools/test.sh`: `[tests] PASS` (Godot 4.5.1 emitted the existing save-schema warning because the repo targets 4.7.1).
- `tools/smoke.sh --no-import`: `SMOKE PASS`.
- Rendered at 844x390 with Godot's screenshot path and visually inspected:
  - `phone-ui-before-character-creation.png`
  - `phone-ui-after-character-creation.png`
  - `phone-ui-after-terrain-picker.png`

Credits spent: 0.
