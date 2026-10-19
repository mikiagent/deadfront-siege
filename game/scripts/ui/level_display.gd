class_name LevelDisplay
extends RefCounted
## The one player level every screen shows. Before this the HUD, the bag and the fatigue panel
## showed three different numbers (pioneer level, pioneer level + 1, skill-tree average).
## ASSUMPTION: the pioneer level (World.pioneer_level, fed by every skill XP grant) is the player
## level, shown as stored, matching the HUD badge, XP bar and level-up banner.

## Shown where a level cannot be worked out yet (a recipe the bag cannot make).
const NONE := "Lv. —"

static func player_level() -> int:
	return World.pioneer_level

## Every level label goes through here, so the format is the same on every screen.
static func label(level: int) -> String:
	return "Lv. %d" % level

static func player_label() -> String:
	return label(player_level())
