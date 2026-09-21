class_name ClimatePalette
extends RefCounted
## Resolves data-driven climate colours without depending on IslandRuntime.

const DEFAULTS := {
	"grass": Color(0.30, 0.58, 0.22),
	"dry": Color(0.53, 0.49, 0.27),
	"dirt": Color(0.44, 0.34, 0.24),
	"sand": Color(0.79, 0.72, 0.54),
	"rock": Color(0.47, 0.46, 0.44),
}

static func resolve(row: Dictionary) -> Dictionary:
	var result := DEFAULTS.duplicate()
	var custom: Dictionary = row.get("palette", {})
	for key in custom:
		var text := str(custom[key])
		var parsed := Color.from_string(text, Color.WHITE)
		if parsed != Color.WHITE or text.to_lower() == "#ffffff":
			result[key] = parsed
	return result
