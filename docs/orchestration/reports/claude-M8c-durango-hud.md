# Claude M8c — the Durango HUD (field + combat)

References: `docs/reference/durango-look-reference.webp`, `durango-combat-reference.jpg`, `durango-taming-reference.jpg`.

## What shipped (`scripts/ui/hunt_hud.gd`, class `HuntHud`, now also created in the main scene)
- **Top-left**: HP bar (red, ♥, `hp / max`), Energy bar (blue, ⚡), thin fatigue strip, status icons with countdowns, EXHAUSTED tag.
- **Top-right**: 180 px minimap rendered from the island's tile types (grass/sand/wet/shallow/deep/mud/rock), centred on the player, 1 px = 1.5 m, north up: player arrow, camp (gold), harbour (blue), crater once discovered, creatures (red) and pets (green). `Home` / `Survivable for N min` above, `X n Y n` tile coordinates and the clock below. Tapping opens the full map.
- **Bottom-left** hex row (`HexButton`): MENU (sheet: Bag, Craft, Map, Save), PETS (bonded list → summon / dismiss), BUILD (kits in the bag with footprint → placer), SKILLS (skill panel). **Bottom-right**: inspect hex (debug overlay toggle for now). **Bottom edge**: XP bar `Lv. N  P%` from the new `World.pioneer_xp` (+1 per gather unit; `pioneer_progress()`).
- **Name** under the survivor (`Player.display_name()` from survivor.json).
- **Combat layer** while `Hunt.target` exists: red frame top/bottom, top-centre target plate (name, `Lv. N` in red, portrait letter, wide red health bar with numbers, target status row), red `End Combat` button, honeycomb skill cluster (net / tackle / kick / roll with cooldown greying), yellow `Auto` hex (toggles `Hunt.auto`), `Attack Stance ◎` label, `Chase` / `Hold` hex bottom-left (toggles `Hunt.hold`), red ground ring on the target (`Hunt._attach_ring`). `[hud] target <species> lv=N hp=a/b` on target set.
- `TouchControls.hud_mode`: the old BAG/CRAFT/MAP and hunt button cluster are hidden; the place context buttons remain until the placement hexes land (M8d).

## Evidence
- `docs/orchestration/reports/m8c-hud.png` (home, explore), `m8c-hud-hunt.png` (hunt lab, combat layer with the target plate, cluster, Auto, Hold, End Combat)
- `tools/smoke.sh` → `SMOKE PASS`

## Not yet
- Target outline shader pass (the red ground ring stands in), hit burst sprite (M9a already floats damage numbers), stance cycling (label only), long-press inspect mode, safe-area check on a real phone.
