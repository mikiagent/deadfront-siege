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
	# shortcut: two runs launched at once under the same name share (and wipe) one folder; add the pid
	# to the folder name if parallel runs of one lab ever need their own saves.
	SaveMigrations.wipe_dir("user://runs/%s" % run) # also any .bak/.tmp/.corrupt-* a previous launch left
	return "user://runs/%s/save_1.json" % run

static func run_name(user_args: PackedStringArray, args: PackedStringArray) -> String:
	# A path segment: "/" and ".." in a --lab value must not climb out of user://runs/.
	return _raw_run_name(user_args, args).validate_filename().replace(".", "_")

static func _raw_run_name(user_args: PackedStringArray, args: PackedStringArray) -> String:
	for a in user_args:
		if a.begins_with("--lab=") and a.length() > 6:
			return a.substr(6)
	for a in user_args:
		if a.begins_with("--shot="): # the house screenshot flag: a capture must never touch the real slot
			return "shot"
		if a in ["--smoke", "--bot", "--web-soak"] or a.ends_with("-probe") or a.ends_with("-test"):
			return a.trim_prefix("--")
	if "--web-soak" in args:
		return "web-soak"
	var i := maxi(args.find("--script"), args.find("-s"))
	if i >= 0 and i + 1 < args.size():
		return args[i + 1].get_file().get_basename()
	return ""

## True for a save the 60 s autosave wrote before a survivor existed: schema 3 with no name or no
## occupation. Older schemas (v0-v2) never stored those fields at all and are real saves; they load.
static func is_precreation(data: Dictionary, schema: int) -> bool:
	if schema < 3:
		return false
	return str(data.get("player_name", "")).strip_edges() == "" or str(data.get("occupation", "")) == ""

## Only the main file: a .bak is the previous good save, never the one boot should judge.
static func has_precreation_save() -> bool:
	var r := SaveMigrations.read(path)
	return r.has("data") and is_precreation(r["data"] as Dictionary, int(r["schema"]))

static func exists() -> bool:
	return FileAccess.file_exists(path) or FileAccess.file_exists(path + ".bak")

static func save_now() -> bool:
	# Never before character creation and the first island pick: such a save would skip both on the
	# next launch and load a default survivor (playtest 2026-10-21).
	if World.creation_pending:
		print("[save] deferred: character creation has not finished")
		return false
	var buildings := _live_buildings()
	# Before any refusal: World.travel rebuilds the home camp from this cache after saving, so a
	# refused save must still record what was built this session.
	if World.is_home() and World.runtime:
		World._home_buildings_cache = buildings
	if blocked_reason != "":
		if blocked_reason == LOAD_UNFINISHED:
			print("[save] refused: the load of %s did not finish this session, so the file is left untouched" % path)
		else:
			print("[save] refused: %s is unreadable (%s); confirm a new game first" % [path, blocked_reason])
		return false
	var player := _player()
	if player == null:
		return false
	World._snapshot_harvest()
	var snares: Array = []
	if World.runtime:
		for n in World.runtime.get_tree().get_nodes_in_group("ground_snare"):
			if n.get_parent() == World.runtime and not n.is_queued_for_deletion(): snares.append(n.to_dict())
	var pets: Array = []
	for rec in player.bonded:
		if rec != null:
			pets.append(rec.to_dict())
	var skills: Dictionary = {}
	for id in Data.survival_unlocked:
		skills[str(id)] = bool(Data.survival_unlocked[id])
	var payload := {
		"schema": SCHEMA,
		# Fog of war + walked trail per island (spec 25). Backward compatible: builds before this
		# field load it as absent and World starts with the camp area revealed.
		"map": World.map_map(),
		"player": {
			"vitals": player.vitals.to_dict(),
			"statuses": player.statuses.to_array(),
			"inventory": player.inventory.to_array(),
			"inventory_extras": player.inventory.extras_to_dict(),
			"position": [player.global_position.x, player.global_position.y, player.global_position.z],
			# FOODFX (spec 32 §11.9/§13): the delayed digestion rows (remaining, never re-paid) and the
			# exclusive buff slots with their own time left, so a reload mid-meal mid-buff is exact.
			"foodfx": {
				"digestion": Digestion.of(player).to_dict(),
				"buffs": BuffSlots.of(player).to_dict(),
			},
			"resting": player.sim.rest.resting,
		},
		"pets": pets,
		# TRIBE M1: members, recruits waiting at the dock, the boat timer. An old save has no row: no members.
		"tribe": Tribe.to_save(),
		"ground_snares": snares,
		"skills": skills,
		"home": {
			"terrain": str(World.home_terrain),
			# ISLANDPICK: the permanent Tamed Island shape. "" for a save from before the picker
			# and for a world whose pick never happened; def_of then builds the stock island.
			"shape": str(World.home_shape),
			"buildings": World._home_buildings_cache, # refreshed above when the survivor is home
			"cargo": World.cargo_home.to_array(),
			"claims": World.home_claims,
			"camp_layout": World.camp_layout,
		},
		"pioneer_xp": World.pioneer_xp,
		"skills_v2": player.skills.to_dict() if player.skills else {},
		"player_name": World.player_name,
		"player_title": World.player_title,
		"occupation": World.occupation,
		"character_look": World.look, # CHARCREATE; namespaced apart from item instances' own "look"
		"pioneer_level": World.pioneer_level,
		"xp_curve": 2,  # LEVELBAR: the exponential curve; a save without it is migrated on load
		"pioneer_crafts": World.pioneer_crafts,
		"pioneer_buildings": World.pioneer_buildings,
		"t_stones": World.t_stones,
		"warp_gems": World.warp_gems,
		"visited_islands": World.visited_islands,
		"raid_victory": World.raid_victory,
		"objective": World.objective,
		"objective_best": World.objective_best,
		"tasks": Tasks.to_dict(), # TASKSCREEN: claimed tasks, daily/weekly counts and their reset day/week
		"factions": Factions.to_dict(), # FACTIONS: reputation per faction (missions live in "tasks")
		"island_id": str(World.island_id),
		"unstable": {
			"remaining": World.remaining_lifetime,
			"harvested": World.harvested,
			"crater_discovered": World.crater_discovered,
		},
		"clock": Game.time_of_day,
		"saved_unix": int(Time.get_unix_time_from_system()),
		"pending_refunds": SaveRestore.pending_refunds,
	}
	# CLAIMS2 / spec 29: the domain record is written only once a domain exists, so a save with no
	# declared domain keeps exactly the old shape (an old save and its fixtures re-save unchanged).
	if not World.home_domain.is_empty():
		(payload["home"] as Dictionary)["domain"] = World.home_domain
	# DOMAIN-D / spec 29 section 4: the Personal Communications Center's rank and held contributions.
	# Written only once the island has some, so a save with no center keeps exactly the old shape.
	if not World.home_comm_center.is_empty():
		(payload["home"] as Dictionary)["comm_center"] = CommCenter.to_save()
	# TUTORIAL ISLAND: written only while the tutorial runs. A save without the row loads as done, so
	# every home survivor's save keeps exactly its old shape.
	if Tutorial.active():
		payload["tutorial"] = World.tutorial
	if not World.is_home():
		# The island the survivor is standing on: its buildings, storage and staked claims.
		payload["away"] = {"buildings": buildings, "claims": World.unstable_claims}
		if not World.away_domain.is_empty():
			(payload["away"] as Dictionary)["domain"] = World.away_domain
	if not SaveMigrations.write_atomic(path, JSON.stringify(payload)):
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
	# Review fix: do not lift World.creation_pending here; character creation may still be open, and the
	# island pick (World.finish_creation) lifts it once the new survivor exists.
	print("[save] new game confirmed; saving to %s again" % path)

static func load_now(host: Node) -> void:
	var main := SaveMigrations.read(path)
	if main.has("data"):
		_apply_guarded(host, main["data"], int(main["schema"]), false)
		return
	var bak := SaveMigrations.read(path + ".bak")
	if bak.has("data"):
		if main.has("error"):
			# Moved aside: left in place, the next save would rotate these bytes into .bak.
			print("[save] %s unreadable (%s); kept as %s" % [path, main["error"], SaveMigrations.quarantine(path, true).get_file()])
		print("[save] restored %s.bak" % path)
		# Only a damaged main file is worth a notice; a missing one (crash before the rename) is not.
		_apply_guarded(host, bak["data"], int(bak["schema"]), main.has("error"))
		return
	var kept := ""
	for r in [bak, main]:
		if r.has("error"):
			kept = SaveMigrations.quarantine(r["path"], false).get_file()
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
	SaveRestore.pending_refunds = []
	if source_schema != SCHEMA:
		print("[world] migrated save schema=%d -> %d" % [source_schema, SCHEMA])
	var schema := source_schema
	World.home_terrain = StringName(str(data.get("home", {}).get("terrain", "")))
	# ISLANDPICK: an old save has no shape row; it keeps the island it always had (home_shape ""),
	# and the pick is never offered again because the survivor already exists. The row is user
	# editable JSON, so it only counts when it names one of the five catalogue shapes: an unknown id
	# loads the stock island instead of driving the landmass from a forged value. (SaveSanitizer is
	# the general trust boundary but is outside this task's SCOPE; see the report.)
	var shape_row := str((data.get("home", {}) as Dictionary).get("shape", ""))
	World.home_shape = StringName(shape_row if World.has_shape(StringName(shape_row)) else "")
	World.pioneer_crafts = data.get("pioneer_crafts", {})
	World.pioneer_buildings = data.get("pioneer_buildings", {})
	World.t_stones = int(data.get("t_stones", 20))
	World.warp_gems = int(data.get("warp_gems", World.START_WARP_GEMS)) # an older save gets the new-game grant
	World.visited_islands = data.get("visited_islands", {}).duplicate()
	World.raid_victory = bool(data.get("raid_victory", false))
	World.objective = int(data.get("objective", 0))  # older saves start the standing orders over
	World.objective_best = int(data.get("objective_best", 0))
	# TUTORIAL ISLAND: no row = a survivor from before the tutorial, who owns a home: done, never shown.
	World.tutorial = Tutorial.from_save(data.get("tutorial", null))
	# TASKSCREEN: after World.tutorial, so an old save reads the list it was running (Objectives._steps).
	Tasks.from_dict(data.get("tasks", null)) # no block (older save): the orders already finished load as received
	Factions.from_dict(data.get("factions", null)) # FACTIONS: no block (older save) = no reputation yet
	World.remaining_lifetime = float(data.get("unstable", {}).get("remaining", 0.0))
	World.harvested = data.get("unstable", {}).get("harvested", {})
	World.crater_discovered = bool(data.get("unstable", {}).get("crater_discovered", false))
	World.cargo_home.load_array(data.get("home", {}).get("cargo", []))
	World._home_buildings_cache = data.get("home", {}).get("buildings", [])
	World.home_claims = data.get("home", {}).get("claims", [])
	# CLAIMS2 / spec 29: the domain record. An old save has "claims" only; IslandClaims migrates
	# those rects into covering cells when the island builds (and covers every placed building).
	World.home_domain = data.get("home", {}).get("domain", {})
	# DOMAIN-D / spec 29 section 4: the center's record (absent in a save from before it existed).
	CommCenter.from_save((data.get("home", {}) as Dictionary).get("comm_center", {}))
	var cl: Variant = data.get("home", {}).get("camp_layout", {})
	World.camp_layout = (cl as Dictionary).duplicate() if cl is Dictionary else {}
	var map_row: Variant = data.get("map", {})
	World.load_map_map(map_row as Dictionary if map_row is Dictionary else {})
	# An older save has no fog at all; its islands then open with the camp area known (task: old
	# saves load with everything near the camp revealed). A fresh world starts fully grey.
	World._reveal_camp_on_new_fog = not (map_row is Dictionary and (map_row as Dictionary).has("islands"))
	World.player_name = str(data.get("player_name", ""))
	World.player_title = str(data.get("player_title", "")) # older saves: no title worn
	World.occupation = str(data.get("occupation", ""))
	World.look = CharacterLook.clean(data.get("character_look", {})) # optional: older saves get the default look
	Game.time_of_day = float(data.get("clock", 0.35))
	var skills: Dictionary = data.get("skills", {}) # sanitized: known survival ids -> bool
	for id in skills:
		Data.set_survival_unlocked(StringName(id), skills[id] is bool and skills[id])
	var away: Dictionary = data.get("away", {})
	if away.has("claims"):
		World.unstable_claims = away["claims"] # read by the island's claim setup in load_island
	var away_dom: Variant = away.get("domain", {})
	World.away_domain = (away_dom as Dictionary).duplicate(true) if away_dom is Dictionary else {}
	var iid := StringName(str(data.get("island_id", "home_grassland")))
	var pos_a: Array = data.get("player", {}).get("position", [0, 1, 12])
	var pos := Vector3(float(pos_a[0]), float(pos_a[1]), float(pos_a[2]))
	World.load_island(host, iid, pos, false)
	# After the island: arriving fires island_changed, whose survival XP is for travel, not for loading.
	World.pioneer_level = int(data.get("pioneer_level", 0))
	World.pioneer_xp = int(data.get("pioneer_xp", 0))
	var gained_levels := 0
	if int(data.get("xp_curve", 1)) < 2:  # saved on the linear curve (LEVELBAR 2026-10-28)
		var m := World.migrate_linear_xp(World.pioneer_level, World.pioneer_xp)
		gained_levels = m.x - World.pioneer_level
		World.pioneer_level = m.x
		World.pioneer_xp = m.y
	_restore_buildings(World._home_buildings_cache if World.is_home() else away.get("buildings", []), schema)
	SaveRestore.retry_refunds(data.get("pending_refunds", []))
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
	# Load rescue: a save written on the old layout (or in open water) can put the survivor where the
	# new island has sea, a cliff or the river bed. Walk them to the camp instead of the seabed.
	# is_dry, not spawn_ok: spawn_ok's strict mode refuses the 25 m landing ring around the camp,
	# and the camp is exactly where a legitimate save may stand.
	if World.runtime and World.runtime.has_method("is_dry") and not World.runtime.is_dry(seat):
		var camp: Vector3 = World.runtime._camp_pos
		player.global_position = Vector3(camp.x, World.runtime.surface_y(camp.x, camp.z) + 1.0, camp.z)
		print("[save] load rescue: saved position was not dry land; moved to the camp %s" % player.global_position)
	# Legacy stacks split into instances; what no longer fits the bag goes to home cargo (W2-INV).
	player.inventory.load_array(data.get("player", {}).get("inventory", []), World.cargo_home)
	var extras: Variant = data.get("player", {}).get("inventory_extras", null)
	if extras is Dictionary:
		player.inventory.extras_from_dict(extras as Dictionary)
	CharacterLook.apply(player.rig, World.look) # after the worn pieces attach, so they take the colours too
	# Derive equipment capacity before restoring statuses, whose sync clamps health.
	player.refresh_equipment_vitals()
	player.vitals.from_dict(data.get("player", {}).get("vitals", {}))
	if gained_levels > 0:  # the recomputed level pays its per-level vitals, quietly (no celebration on load)
		var per: Dictionary = (JSON.parse_string(FileAccess.get_file_as_string("res://data/skills/pioneer_levels.json")) as Dictionary).get("per_level", {})
		player.vitals.grant_level_bonus(float(per.get("max_health", 0)) * gained_levels, float(per.get("max_energy", 0)) * gained_levels)
	player.statuses.from_array(data.get("player", {}).get("statuses", []))
	# FOODFX: buff rows and digestion first, so a status sync or a capacity change sees the final set.
	var foodfx: Variant = (data.get("player", {}) as Dictionary).get("foodfx", {})
	if foodfx is Dictionary:
		var slots := BuffSlots.of(player)
		if slots != null:
			# restore() = from_dict + publish: rows, the FoodBuffState mirror Crafting/climate read,
			# and the capacity bonuses. Loading the rows alone would leave a saved ability buff inert.
			slots.restore(player, (foodfx as Dictionary).get("buffs", {}))
		var digestion := Digestion.of(player)
		if digestion != null:
			digestion.from_dict((foodfx as Dictionary).get("digestion", {}))
			digestion.seed_starter()  # FULLFATIGUE: an old save with nothing digesting starts "normal", once
	player.sim.rest.load_saved(data.get("player", {}).get("resting", false))  # spec 01:22: seated or standing, as saved
	if player.skills:
		player.skills.from_dict(data.get("skills_v2", {}))
	player.bonded.clear()
	for row in data.get("pets", []):
		if row is Dictionary:
			var rec := PetRecord.from_dict(row)
			if rec != null: # an aborted from_dict would otherwise break every later save_now
				player.bonded.append(rec)
	# W2-INV (spec 05:20/26): building contents and pet bags load on their own; a uid one of them
	# repeats (an edited save) is reminted, so every instance has one location.
	var held: Array = [World.cargo_home, player.inventory]
	for n in host.get_tree().get_nodes_in_group("placed_building"):
		if not n.is_queued_for_deletion() and World.runtime and World.runtime.is_ancestor_of(n): # not the old island's
			held.append(n.get("storage"))
	for rec in player.bonded:
		held.append(rec.bag)
	Tribe.from_save(data.get("tribe", null))
	for r in Tribe.members:
		held.append(r.carry)
	var reminted := InventoryMigration.unique_uids(held)
	if reminted > 0:
		print("[inv] load: %d duplicate uids reminted" % reminted)
	# Field growth catch-up (same offline window as tent rest).
	if elapsed > 0 and World.runtime:
		for n in World.runtime.get_tree().get_nodes_in_group("field"):
			if n is FieldPlot:
				(n as FieldPlot).advance_offline(float(elapsed))
		print("[farm] offline catch-up %ds" % elapsed)
	# A survivor was loaded: creation is behind us, so the autosave runs again (a failed load that
	# opened creation leaves the flag up until that creation finishes).
	World.creation_pending = false
	print("[world] loaded island=%s terrain=%s pioneer=%d tutorial=%s" % [iid, World.home_terrain, World.pioneer_level, "running step %d" % (World.objective + 1) if Tutorial.active() else "done"])
	Tutorial.resume(host)  # a tutorial whose orders are all done re-opens its Tamed Island grant
	if from_backup:
		player.notice("Your last save was damaged; the backup before it was loaded")
	blocked_reason = ""

## Kept for callers outside this package (World.travel, run_all, kitchen_lab, siege_probe).
## Modular pieces (schema 4) go back first: a kit standing on a foundation needs its floor.
static func _restore_buildings(rows: Array, schema: int) -> void:
	var kits: Array = []
	var pieces: Array = []
	for row in rows:
		var k := str((row as Dictionary).get("kind", "")) if row is Dictionary else ""
		if k == "loot_bag" and World.runtime:  # what a destroyed structure held, still on the ground
			World.runtime.add_child(LootBag.from_dict(row))
			continue
		(pieces if StructurePiece.is_piece_kind(StringName(k)) else kits).append(row)
	var grid: BuildGrid = World.runtime.get("build_grid") if World.runtime else null
	if grid and not pieces.is_empty():
		grid.structures.restore(pieces, World.runtime)
	SaveRestore.buildings(kits, schema)
	if grid:
		_restore_durability(kits, grid)

## A worn kit keeps its wear: rows carry "durability" (schema 4) and the rebuilt node gets it back.
static func _restore_durability(rows: Array, grid: BuildGrid) -> void:
	for row in rows:
		var v: Variant = row.get("durability") if row is Dictionary else null
		if not (v is int or v is float):
			continue
		var node := grid.occupant(SaveRestore.cell_of(row))
		var h := StructureHealth.of(node, true)
		if h and not node.has_method("receive_siege_hit"):  # the catapult saves its own hp
			h.hp = clampf(float(v), 1.0, h.max_hp)

static func _spawn_building(row: Dictionary) -> Node3D:
	return SaveRestore.spawn(row)

## Rows of the persistent, non-cargo buildings on the live island.
static func _live_buildings() -> Array:
	var out: Array = []
	if World.runtime == null:
		return out
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
			var row: Dictionary = b.to_dict()
			var h := StructureHealth.of(b)
			if h and h.missing() > 0.0:
				row["durability"] = h.hp
			out.append(row)
	var grid: Variant = World.runtime.get("build_grid")
	if grid is BuildGrid:
		out.append_array((grid as BuildGrid).structures.to_rows())
	return out

static func _player() -> Player:
	return PlayerRegistry.local()
