class_name SaveGame
extends RefCounted
## Snapshot C save. Ids only, never node references. Writes are atomic (tmp + rename) and keep the
## previous good save as .bak. A save this build cannot read is kept, never silently replaced.

const SCHEMA := SaveMigrations.CURRENT_SCHEMA
const MAX_OFFLINE_SECONDS := 7 * 24 * 3600 # ASSUMPTION: a week of offline growth; a wrong device clock cannot fast-forward farms further

## Automated runs (--lab, --smoke, --bot, probe/test flags, --script) save under user://runs/<name>/
## so they never read or write the player's save, and every launch of one starts from a fresh world.
static var path: String = _pick_path()
## Set while an unreadable save is on disk and the player has not confirmed a new game. Every
## save_now() is refused, which also stops World's 60 s autosave from overwriting it.
static var blocked_reason: String = ""
## Held while a save is being applied: a load that aborts partway leaves it set, so the half-built
## world is never autosaved over the good file.
const LOAD_UNFINISHED := "the last load did not finish"

static func _pick_path() -> String:
	var run := run_name(OS.get_cmdline_user_args(), OS.get_cmdline_args())
	if run == "":
		return "user://save_1.json"
	SaveFile.wipe_dir("user://runs/%s" % run) # also any .bak/.tmp/.corrupt-* a previous launch left
	return "user://runs/%s/save_1.json" % run

static func run_name(user_args: PackedStringArray, args: PackedStringArray) -> String:
	# A path segment: "/" and ".." in a --lab value must not climb out of user://runs/.
	return _raw_run_name(user_args, args).validate_filename().replace(".", "_")

static func _raw_run_name(user_args: PackedStringArray, args: PackedStringArray) -> String:
	for a in user_args:
		if a.begins_with("--lab=") and a.length() > 6:
			return a.substr(6)
	for a in user_args:
		if a in ["--smoke", "--bot", "--web-soak"] or a.ends_with("-probe") or a.ends_with("-test"):
			return a.trim_prefix("--")
	if "--web-soak" in args:
		return "web-soak"
	var i := maxi(args.find("--script"), args.find("-s"))
	if i >= 0 and i + 1 < args.size():
		return args[i + 1].get_file().get_basename()
	return ""

static func exists() -> bool:
	return FileAccess.file_exists(path) or FileAccess.file_exists(path + ".bak")

static func save_now() -> bool:
	if blocked_reason != "":
		print("[save] refused: %s is unreadable (%s); confirm a new game first" % [path, blocked_reason])
		return false
	var player := _player()
	if player == null:
		return false
	World._snapshot_harvest()
	var buildings: Array = []
	if World.runtime:
		for n in World.runtime.get_tree().get_nodes_in_group("placed_building"):
			# The old island may still be queue_free pending during a travel callback.
			if n.is_queued_for_deletion() or not World.runtime.is_ancestor_of(n): continue
			var b = n
			var persist := true
			if b and b.has_method("get"):
				var pv: Variant = b.get("persist_building")
				if pv != null:
					persist = bool(pv)
			if b and b.has_method("to_dict") and persist and b.get("is_cargo") != true:
				buildings.append(b.to_dict())
	var snares: Array = []
	if World.runtime:
		for n in World.runtime.get_tree().get_nodes_in_group("ground_snare"):
			if n.get_parent() == World.runtime and not n.is_queued_for_deletion(): snares.append(n.to_dict())
	var pets: Array = []
	for rec in player.bonded:
		pets.append(rec.to_dict())
	var skills: Dictionary = {}
	for id in Data.survival_unlocked:
		skills[str(id)] = bool(Data.survival_unlocked[id])
	var payload := {
		"schema": SCHEMA,
		"player": {
			"vitals": player.vitals.to_dict(),
			"statuses": player.statuses.to_array(),
			"inventory": player.inventory.to_array(),
			"inventory_extras": player.inventory.extras_to_dict(),
			"position": [player.global_position.x, player.global_position.y, player.global_position.z],
		},
		"pets": pets,
		"ground_snares": snares,
		"skills": skills,
		"home": {
			"terrain": str(World.home_terrain),
			"buildings": buildings if World.is_home() else World._home_buildings_cache,
			"cargo": World.cargo_home.to_array(),
			"claims": World.home_claims,
			"camp_layout": World.camp_layout,
		},
		"pioneer_xp": World.pioneer_xp,
		"skills_v2": player.skills.to_dict() if player.skills else {},
		"player_name": World.player_name,
		"occupation": World.occupation,
		"pioneer_level": World.pioneer_level,
		"pioneer_crafts": World.pioneer_crafts,
		"pioneer_buildings": World.pioneer_buildings,
		"t_stones": World.t_stones,
		"visited_islands": World.visited_islands,
		"raid_victory": World.raid_victory,
		"objective": World.objective,
		"objective_best": World.objective_best,
		"island_id": str(World.island_id),
		"unstable": {
			"remaining": World.remaining_lifetime,
			"harvested": World.harvested,
			"crater_discovered": World.crater_discovered,
		},
		"clock": Game.time_of_day,
		"saved_unix": int(Time.get_unix_time_from_system()),
	}
	if World.is_home():
		World._home_buildings_cache = buildings
	else:
		# The island the survivor is standing on: its buildings, storage and staked claims.
		payload["away"] = {"buildings": buildings, "claims": World.unstable_claims}
	if not SaveFile.write_atomic(path, JSON.stringify(payload)):
		print("[world] save failed")
		return false
	World.last_save_unix = int(payload["saved_unix"])
	print("[world] saved schema=%d island=%s" % [SCHEMA, World.island_id])
	return true

## The player chose to start over after an unreadable save (character creation finished). Its bytes
## are already kept as .corrupt-<unix>, so the slot is cleared and saving resumes.
static func confirm_new_game() -> void:
	if blocked_reason == "" or blocked_reason == LOAD_UNFINISHED: # that file is readable: never delete it
		return
	blocked_reason = ""
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	print("[save] new game confirmed; saving to %s again" % path)

static func load_now(host: Node) -> void:
	var main := SaveFile.read(path)
	if main.has("data"):
		_apply_guarded(host, main["data"], int(main["schema"]), false)
		return
	var bak := SaveFile.read(path + ".bak")
	if bak.has("data"):
		if main.has("error"):
			# Moved aside: left in place, the next save would rotate these bytes into .bak.
			print("[save] %s unreadable (%s); kept as %s" % [path, main["error"], SaveFile.quarantine(path, true).get_file()])
		print("[save] restored %s.bak" % path)
		_apply_guarded(host, bak["data"], int(bak["schema"]), true)
		return
	var kept := ""
	for r in [bak, main]:
		if r.has("error"):
			kept = SaveFile.quarantine(r["path"], false).get_file()
			blocked_reason = r["error"]
			print("[save] %s unreadable (%s); kept as %s" % [r["path"], r["error"], kept])
	World.start_new(host)
	if blocked_reason != "":
		print("[save] saves are refused until the player confirms a new game")
		_warn_new_world(host, blocked_reason, kept)

## A script error inside _apply returns here with the world half-built: saving stays refused for
## the session so the next autosave cannot replace the good file with that state.
static func _apply_guarded(host: Node, data: Dictionary, source_schema: int, from_backup: bool) -> void:
	_apply(host, data, source_schema, from_backup)
	if blocked_reason == LOAD_UNFINISHED:
		print("[save] load of %s did not finish; saves are refused this session so it stays untouched" % path)
		var player := _player()
		if player:
			player.notice("Your save could not be fully loaded. It is kept untouched; progress this session will not be saved")

## Character creation opened because the save could not be read: say so on screen, and treat
## finishing it as the player's confirmation that a new world may take the save slot.
static func _warn_new_world(host: Node, why: String, kept: String) -> void:
	var cc := host.get_node_or_null("CharacterCreation") as CharacterCreation
	if cc == null:
		return
	cc.done.connect(func (_occ: String, _gender: String, _nm: String) -> void: confirm_new_game())
	var note := Label.new()
	note.name = "SaveWarning"
	note.text = "Your saved world could not be loaded: %s. It is kept untouched as %s. Creating a survivor starts a new world." % [why, kept]
	note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	note.add_theme_color_override("font_color", Color(1.0, 0.74, 0.42))
	note.add_theme_font_size_override("font_size", 18)
	# In the layout column under the subtitle: the card grid shrinks to make room, and the column
	# already sits inside character creation's margins (bottom-anchored, it covered the start row).
	var boxes := cc.find_children("*", "VBoxContainer", true, false)
	if boxes.is_empty() or boxes[0].get_child_count() < 2:
		cc.add_child(note)
		return
	var sub := boxes[0].get_child(1) as Label # title, subtitle, cards, details
	if sub:
		note.add_theme_font_size_override("font_size", sub.get_theme_font_size("font_size"))
	boxes[0].add_child(note)
	boxes[0].move_child(note, 2)

static func offline_seconds(saved_unix: int) -> int:
	return clampi(int(Time.get_unix_time_from_system()) - saved_unix, 0, MAX_OFFLINE_SECONDS)

static func _apply(host: Node, data: Dictionary, source_schema: int, from_backup: bool) -> void:
	blocked_reason = LOAD_UNFINISHED # cleared as the last statement; also lifts an older block
	if source_schema != SCHEMA:
		print("[world] migrated save schema=%d -> %d" % [source_schema, SCHEMA])
	var schema := source_schema
	World.home_terrain = StringName(str(data.get("home", {}).get("terrain", "")))
	World.pioneer_crafts = data.get("pioneer_crafts", {})
	World.pioneer_buildings = data.get("pioneer_buildings", {})
	World.t_stones = int(data.get("t_stones", 20))
	World.visited_islands = data.get("visited_islands", {}).duplicate()
	World.raid_victory = bool(data.get("raid_victory", false))
	World.objective = int(data.get("objective", 0))  # older saves start the standing orders over
	World.objective_best = int(data.get("objective_best", 0))
	World.remaining_lifetime = float(data.get("unstable", {}).get("remaining", 0.0))
	World.harvested = data.get("unstable", {}).get("harvested", {})
	World.crater_discovered = bool(data.get("unstable", {}).get("crater_discovered", false))
	World.cargo_home.load_array(data.get("home", {}).get("cargo", []))
	World._home_buildings_cache = data.get("home", {}).get("buildings", [])
	World.home_claims = data.get("home", {}).get("claims", [])
	var cl: Variant = data.get("home", {}).get("camp_layout", {})
	World.camp_layout = (cl as Dictionary).duplicate() if cl is Dictionary else {}
	World.player_name = str(data.get("player_name", ""))
	World.occupation = str(data.get("occupation", ""))
	Game.time_of_day = float(data.get("clock", 0.35))
	var skills: Dictionary = data.get("skills", {}) # sanitized: known survival ids -> bool
	for id in skills:
		Data.set_survival_unlocked(StringName(id), skills[id] is bool and skills[id])
	var away: Dictionary = data.get("away", {})
	if away.has("claims"):
		World.unstable_claims = away["claims"] # read by the island's claim setup in load_island
	var iid := StringName(str(data.get("island_id", "home_grassland")))
	var pos_a: Array = data.get("player", {}).get("position", [0, 1, 12])
	var pos := Vector3(float(pos_a[0]), float(pos_a[1]), float(pos_a[2]))
	World.load_island(host, iid, pos, false)
	# After the island: arriving fires island_changed, whose survival XP is for travel, not for loading.
	World.pioneer_level = int(data.get("pioneer_level", 0))
	World.pioneer_xp = int(data.get("pioneer_xp", 0))
	_restore_buildings(World._home_buildings_cache if World.is_home() else away.get("buildings", []), schema)
	var saved_unix := int(data.get("saved_unix", Time.get_unix_time_from_system()))
	var elapsed := offline_seconds(saved_unix)
	if int(Time.get_unix_time_from_system()) - saved_unix > elapsed:
		print("[save] offline catch-up clamped %ds -> %ds" % [int(Time.get_unix_time_from_system()) - saved_unix, elapsed])
	for row in data.get("ground_snares", []):
		if row is Dictionary and World.runtime:
			var remaining: Dictionary = row.duplicate(true)
			remaining["life_left"] = float(row.get("life_left", 0.0)) - elapsed
			GroundSnare.restore(remaining, World.runtime)
	var player := World._player()
	if player == null:
		blocked_reason = ""
		return
	# Re-seat the player on the terrain: saves from older builds (or a regenerated
	# island) can hold a y that is now inside the ground, and a body that starts
	# below the one-sided heightmap falls forever.
	var seat := pos
	if World.runtime and World.runtime.has_method("surface_y"):
		seat.y = World.runtime.surface_y(pos.x, pos.z) + 1.0
	player.global_position = seat
	print("[world] loaded player at %s (saved y=%.2f)" % [seat.snapped(Vector3.ONE * 0.1), pos.y])
	player.inventory.load_array(data.get("player", {}).get("inventory", []))
	var extras: Variant = data.get("player", {}).get("inventory_extras", null)
	if extras is Dictionary:
		player.inventory.extras_from_dict(extras as Dictionary)
	# Derive equipment capacity before restoring statuses, whose sync clamps health.
	player.refresh_equipment_vitals()
	player.vitals.from_dict(data.get("player", {}).get("vitals", {}))
	player.statuses.from_array(data.get("player", {}).get("statuses", []))
	if player.skills:
		player.skills.from_dict(data.get("skills_v2", {}))
	player.bonded.clear()
	for row in data.get("pets", []):
		if row is Dictionary:
			player.bonded.append(PetRecord.from_dict(row))
	# Field growth catch-up (same offline window as tent rest).
	if elapsed > 0 and World.runtime:
		for n in World.runtime.get_tree().get_nodes_in_group("field"):
			if n is FieldPlot:
				(n as FieldPlot).advance_offline(float(elapsed))
		print("[farm] offline catch-up %ds" % elapsed)
	print("[world] loaded island=%s terrain=%s pioneer=%d" % [iid, World.home_terrain, World.pioneer_level])
	if from_backup:
		player.notice("Your last save was damaged; the backup before it was loaded")
	blocked_reason = ""

## Saved rows are rebuilt only where the grid would accept them now. An unknown kind or a row that
## fails can_place (overlap, off the claim, water, slope) is refunded to the camp cargo instead.
static func _restore_buildings(rows: Array, schema: int) -> void:
	if World.runtime == null:
		return
	var grid := World.runtime.get("build_grid") as BuildGrid
	var was_ignoring := false
	# No clear_occupancy(): the runtime is fresh, and the cells it holds are the island's own camp
	# pieces, which restored rows must not overlap.
	if grid:
		was_ignoring = grid.ignore_distance
		grid.ignore_distance = true # nobody stands beside a building while it is loaded
	var kits := _kits_by_kind()
	for row in rows:
		if not row is Dictionary:
			continue
		var normalized := _normalize_build_row(row as Dictionary, schema)
		var kind := StringName(str(normalized.get("kind", "")))
		var why := "" if kits.has(kind) else "unknown kind"
		if why == "" and grid:
			why = grid.can_place(kind, _cell_of(normalized), int(normalized.get("rot", 0)))
		if why != "":
			_refund(normalized, kits.get(kind, &""), why)
			continue
		var b := _spawn_building(normalized)
		if b == null:
			continue
		World.runtime.add_child(b)
		_place_building(b, normalized, grid)
	if grid:
		grid.ignore_distance = was_ignoring

## Placeable kinds -> the kit item that places them (items.json place_as).
static func _kits_by_kind() -> Dictionary:
	var out := {}
	for id in Data.items:
		var def: ItemDef = Data.items[id]
		if def.place_as != &"":
			out[def.place_as] = id
	return out

static func _refund(row: Dictionary, kit: StringName, why: String) -> void:
	var back: Array[ItemStack] = []
	if kit != &"":
		back.append(ItemStack.make(kit, 1))
	for s in row.get("contents", []):
		if s is Dictionary and str(s.get("id", "")) != SaveSanitizer.SLOT_LOCK:
			back.append(ItemStack.from_dict(s))
	var lost := 0
	for stack in back:
		lost += World.cargo_home.add(stack)
	print("[save] refunded %s at %s (%s): %d stacks to camp cargo, %d items lost" % [row.get("kind", "?"), _cell_of(row), why, back.size(), lost])

static func _normalize_build_row(row: Dictionary, schema: int) -> Dictionary:
	var out := row.duplicate(true)
	if schema >= 2 and out.has("cell"):
		return out
	var x := float(out.get("x", 0.0))
	var z := float(out.get("z", 0.0))
	var tile := BuildGrid.tile_of(Vector3(x, 0.0, z))
	out["cell"] = [tile.x, tile.y]
	out["rot"] = int(out.get("rot", 0))
	return out

static func _spawn_building(row: Dictionary) -> Node3D:
	var kind := StringName(str(row.get("kind", "basket")))
	match kind:
		&"catapult":
			return FieldCatapult.from_dict(row) if float(row.get("hp",200)) > 0 else null
		&"workbench", &"drying_rack", &"smoker", &"crock_pot", &"mortar", &"stone_grill", &"steamer", &"well":
			return CraftStation.from_dict(row)
		&"bonfire", &"stone_fire_pit", &"campfire":
			return Bonfire.from_dict(row)
		&"makeshift_taming_pen":
			return TamingPen.from_dict(row)
		&"field_small", &"field_large":
			return FieldPlot.from_dict(row)
		_:
			return (load("res://scripts/world/placed_building.gd") as GDScript).from_dict(row)

static func _cell_of(row: Dictionary) -> Vector2i:
	var cell_v: Variant = row.get("cell", [0, 0])
	if cell_v is Array and (cell_v as Array).size() >= 2:
		return Vector2i(int(cell_v[0]), int(cell_v[1]))
	return Vector2i.ZERO

static func _place_building(node: Node3D, row: Dictionary, grid: BuildGrid) -> void:
	var kind := StringName(str(row.get("kind", "basket")))
	var cell := _cell_of(row)
	var rot := int(row.get("rot", 0))
	if grid:
		node.global_transform = grid.placement_transform(kind, cell, rot)
		if node.has_method("set_grid_pose"):
			node.set_grid_pose(cell, rot)
		grid.occupy(node, grid.cells_for(kind, cell, rot))
		return
	node.global_position = Vector3(float(row.get("x", 0.0)), 0.0, float(row.get("z", 0.0)))

static func _player() -> Player:
	return Engine.get_main_loop().root.get_tree().get_first_node_in_group("player") as Player
