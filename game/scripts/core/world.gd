extends Node
## Owns the loaded island, travel, pioneer level, T-stones, and cargo waiting at home.

signal island_changed(id: StringName)
signal pioneer_changed(level: int)

var islands: Dictionary = {} ## id string -> Dictionary
var island_id: StringName = &""
var island_def: Dictionary = {}
var home_terrain: StringName = &""
## ISLANDPICK / spec 29 section 4: the five Tamed Island shapes (data/world/island_shapes.json)
## and the one picked at character creation. "" on a save from before the picker and on a new
## world until the pick: def_of then builds the stock island (seed 17), so old saves keep theirs.
var home_shapes: Array = []
var home_shape: StringName = &""
var t_stones: int = 20 ## ASSUMPTION: starting T-stones
## BAGUI: the premium currency (spec 33's gold gem with a "+"; docs/design/skills.md names Warp Gems).
## Shown by CurrencyBar in the nav menu, bag and market headers. The Harbour's sailings cost it
## (pay_sail, each island's sail_cost); the first standing order grants 10 (objectives.json). There
## is no purchase flow (the "+" is a placeholder). ASSUMPTION: a new game starts with 25 (five 5-gem
## sailings); the owner sets the real grant and prices.
const START_WARP_GEMS := 25
var warp_gems: int = START_WARP_GEMS
var pioneer_level: int = 0
var pioneer_xp: int = 0
var home_claims: Array = []  # [[x, z, w, d], ...] tile rects on the home island (saved)
var unstable_claims: Array = []  # same, current unstable island only (not saved)
## CLAIMS2 / spec 29: the domain record saved for the Tamed Island and for the island the survivor is
## standing on. The legacy rects above stay as a mirror (and are what an old save is migrated from).
var home_domain: Dictionary = {}
var away_domain: Dictionary = {}
## DOMAIN-D / spec 29 section 4: the Tamed Island's Personal Communications Center record - the
## island's Pioneer rank and the exact instances held for the unfinished upgrade step. Saved under
## home.comm_center only once it has progress, so an old save keeps its exact shape.
var home_comm_center: Dictionary = {}
var free_claim_used: bool = false
var objective: int = 0 ## index into Data.world_objectives (Data.world_tutorial while the tutorial runs)
## TUTORIAL ISLAND (Tutorial): {"done", "did"}. Done for every save written before it (they own a home);
## a new survivor gets Tutorial.fresh() when character creation finishes. Saved as "tutorial".
var tutorial: Dictionary = {"done": true, "did": {}}
var visited_islands: Dictionary = {} ## persistent voyage log
var raid_victory: bool = false ## persists only a player/pet T-rex kill on volcanic_60
var objective_best: int = 0 ## high-water progress on the current order (materials get spent)
var _objective_acc: float = 0.0
var player_name: String = ""
## The title she chose to wear over her name (a titles.json value); "" = none. Saved as "player_title".
var player_title: String = ""
## Character creation's look (CharacterLook: gender, height, colours, parts, portrait); saved as "character_look".
var look: Dictionary = {}
var occupation: String = ""  # gathers +1, crafts +10, buildings +15; bar wraps every 100 (ASSUMPTION)
var pioneer_crafts: Dictionary = {}
## kind -> times placed (saved): > 0 means the kind is known, so its next placement pays
## build_repeat instead of build_first (rules.json "xp").
var pioneer_buildings: Dictionary = {}
## XPECON: builds placed inside rules.json xp.build_spam_seconds, {kind, pos, t}. Transient on
## purpose: a real placement time cannot be saved, and a reloaded island pays for a fresh build.
var build_recent: Array = []
var cargo_home: Inventory = Inventory.new(60) ## ASSUMPTION: 60 slots for mobile UI
var remaining_lifetime: float = 0.0
var crater_discovered: bool = false
## LANDMARKS (docs/design/island-resources.md sections 5.3 and 5.6): the landmarks found, per island
## id -> {site id: true}, and each opened dormant site's state, island id -> {site id: {"left": s}}
## (seconds of play its window still runs). Saved under "landmarks"; an old save has neither and
## behaves as a first visit everywhere.
var landmarks_found: Dictionary = {}
var landmark_state: Dictionary = {}
signal landmark_found(site: Dictionary)
var _sink_warned: bool = false
var harvested: Dictionary = {} ## node_id -> {pool, pool_max, session_gathered}
var runtime: Node3D
var last_save_unix: int = 0
var _home_buildings_cache: Array = []
## Moved camp pieces (fire, bench, shed, cargo warp): node name -> {cell, rot}; applied when the
## island builds them, saved under home.camp_layout.
var camp_layout: Dictionary = {}
var _save_acc: float = 0.0
## Map fog + trail per island (spec 25), keyed by island id. `map_fog` is the current island's.
## Saved under the save's "map" field; an old save has none and starts with the camp area known.
var map_fogs: Dictionary = {}
var map_fog: MapFog = null
## Set when a save without fog was loaded: the first island built then starts with the camp area
## revealed, instead of fully grey. A fresh world gets no such gift.
var _reveal_camp_on_new_fog: bool = false
var _walk_acc: float = 0.0
## True from a fresh start until character creation AND the first island pick have finished. No save
## may be written before that: the 60 s autosave did once, on the creation screen, and a reload then
## skipped both and loaded a default "Survivor" (playtest 2026-10-21).
var creation_pending: bool = false
var _fade: ColorRect

const SAVE_PATH := "user://save_1.json"
const CARGO_FEE := 2 ## ASSUMPTION: T-stones to cargo-warp a bag of unstable goods

func _ready() -> void:
	_load_islands("res://data/islands")
	_load_shapes()
	_ensure_fade()
	call_deferred("_boot")

func _process(delta: float) -> void:
	if map_fog != null:
		map_fog.advance_trail(delta)
	if str(island_def.get("kind", "")) == "unstable" and remaining_lifetime > 0.0:
		remaining_lifetime = maxf(0.0, remaining_lifetime - delta)
		var warn_at := float(Data.world_rules.get("sink_warning_seconds", 60))
		if remaining_lifetime <= warn_at and remaining_lifetime > 0.0 and not _sink_warned:
			_sink_warned = true
			print("[world] sink warning %.0fs" % remaining_lifetime)
		if remaining_lifetime <= 0.0:
			print("[world] island sinking — return to camp")
			recall_camp()
	_objective_acc += delta
	if _objective_acc >= 0.5:
		_objective_acc = 0.0
		var p := _player()
		if p and not p.dead:
			Objectives.settle(p)
	# Fog/trail: 4 Hz is a smooth brush at walking speed and costs one small circle test per tick.
	_walk_acc += delta
	if _walk_acc >= 0.25:
		_walk_acc = 0.0
		var w := _player()
		if w and not w.dead and runtime and runtime.has_method("surface_y"):
			note_map_walk(w.global_position)
			check_landmarks(w.global_position)
	_tick_landmark_windows(delta)
	_save_acc += delta
	if _save_acc >= 60.0:
		_save_acc = 0.0
		if creation_pending:
			return  # nothing exists to save yet; SaveGame refuses too, this keeps the log quiet
		_save_now()

func is_home() -> bool:
	return str(island_def.get("kind", "")) == "private"

func is_unstable() -> bool:
	return str(island_def.get("kind", "")) == "unstable"

func is_tutorial() -> bool:
	return str(island_def.get("kind", "")) == "tutorial"

## The home island carries the chosen Tamed Island shape: its seed drives the landmass, its
## display name the island title. Every other island is the catalogue row unchanged.
func def_of(id: StringName) -> Dictionary:
	var d := islands.get(str(id), {}) as Dictionary
	if str(id) == "home_grassland" and home_shape != &"":
		var s := shape_def(home_shape)
		if not s.is_empty():
			d = d.duplicate(true)
			d["seed"] = int(s.get("seed", d.get("seed", 17)))
			d["display_name"] = str(s.get("display_name", d.get("display_name", "Private Island")))
			d["home_shape"] = str(home_shape)
	return d

func shape_def(id: StringName) -> Dictionary:
	for row in home_shapes:
		if row is Dictionary and str((row as Dictionary).get("id", "")) == str(id):
			return row as Dictionary
	return {}

## The shapes in catalogue order; a card each on the pick screen.
func shape_ids() -> Array[String]:
	var out: Array[String] = []
	for row in home_shapes:
		if row is Dictionary:
			out.append(str((row as Dictionary).get("id", "")))
	return out

## Takes the one permanent pick: the home island's terrain row and landmass seed. Returns false
## once a shape is held - the choice is final (PRD 4.2, "Terrain selection is final").
func pick_shape(id: StringName) -> bool:
	if home_shape != &"":
		return false
	var s := shape_def(id)
	if s.is_empty():
		return false
	home_shape = id
	home_terrain = StringName(str(s.get("terrain", id)))
	return true

func _load_shapes() -> void:
	home_shapes.clear()
	var f := FileAccess.open("res://data/world/island_shapes.json", FileAccess.READ)
	if f == null:
		push_error("[world] missing data/world/island_shapes.json")
		return
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	if not parsed is Dictionary:
		push_error("[world] data/world/island_shapes.json is not an object")
		return
	for row in (parsed as Dictionary).get("shapes", []):
		if row is Dictionary and str((row as Dictionary).get("id", "")) != "":
			home_shapes.append(row)

func _boot() -> void:
	if Game.smoke_test:
		return
	if Game.lab_name != "" and Game.lab_name != "home_lab":
		return
	if Game.lab_name == "home_lab":
		return
	var host := get_tree().current_scene
	if host == null or host.is_in_group("shell"):
		return  # downloader shell is showing; shell/boot.gd calls _boot once the game scene is up
	if runtime != null and is_instance_valid(runtime):
		return  # already booted
	ensure_survivor(host)

## Boot's one decision: load a real survivor, or open character creation. A save written before the
## survivor existed (the bug's 60 s autosave, or a save from before creation existed) counts as no
## save: it opens creation again, keeping the file until the new world's first save replaces it.
## Returns true when a save was loaded, false when creation is opening.
func ensure_survivor(host: Node) -> bool:
	var sg := load("res://scripts/core/save_game.gd") as GDScript
	var saved := _save_exists() and not ("--new-game" in OS.get_cmdline_user_args())
	if saved and not sg.has_precreation_save():
		_load_now(host)  # a real save: SaveGame._apply also lifts "creation pending"
		return true
	start_new(host)
	return false

## The permanent Tamed Island pick, taken once at creation: build the chosen island, land the
## survivor at its harbour (the same landing the old terrain sheet used), finish creation, save and
## open the arrival welcome. False when the pick is refused (already held, unknown shape), so the
## caller can leave the screen up instead of building a second island.
func complete_pick(host: Node, shape_id: StringName) -> bool:
	if not pick_shape(shape_id):
		return false
	var dest := def_of(&"home_grassland")
	var harbour: Array = dest.get("harbour", [0, 0, 18])
	var at := Vector3(float(harbour[0]), 1.0, float(harbour[2]))
	load_island(host, &"home_grassland", at, false)
	var p := _player()
	if p and runtime != null and runtime.has_method("arrival_point"):
		p.global_position = (runtime as IslandRuntime).arrival_point() + Vector3.UP
	finish_creation()  # creation and the pick are done: saving starts here
	_save_now()
	_show_arrival(host)
	print("[world] tamed island shape=%s seed=%d arrival=%s" % [
		home_shape, int(shape_def(home_shape).get("seed", 17)),
		str(p.global_position if p else at)])
	return true

## The "YOU MADE IT" welcome the shared world UI already owns (layer 92); reused, not duplicated.
func _show_arrival(host: Node) -> void:
	var ui = (load("res://scripts/ui/world_ui.gd") as GDScript).instance_on(host)
	if ui != null and ui.has_method("_show_arrival"):
		ui.call("_show_arrival", host)

func has_shape(id: StringName) -> bool:
	return not shape_def(id).is_empty()

## Character creation and the first island pick are done: the world may save from here on.
func finish_creation() -> void:
	creation_pending = false
	_save_acc = 0.0

func start_new(host: Node) -> void:
	creation_pending = true
	home_terrain = &""
	home_shape = &""
	island_id = &"home_grassland"
	visited_islands.clear()
	raid_victory = false
	objective = 0
	objective_best = 0
	Tasks.reset()
	tutorial = {"done": true, "did": {}}
	# Character creation first (M10), then the home island with the terrain pick.
	var cc := CharacterCreation.new()
	cc.name = "CharacterCreation"
	host.add_child(cc)
	cc.done.connect(func (occ: String, gender: String, nm: String) -> void:
		occupation = occ
		player_name = nm
		look = CharacterLook.clean(cc.look)
		var p := _player()
		if p and p.skills:
			p.skills.apply_occupation(occ)
		if p:
			CharacterLook.apply(p.rig, look)
			Digestion.of(p).seed_starter()  # FULLFATIGUE: she starts "normal", not "empty" at x2 exhaustion
		print("[world] new survivor %s (%s, %s)" % [nm, occ, gender])
		# TUTORIAL ISLAND: a new survivor lands on the shared tutorial island; its last order opens
		# the Tamed Island pick. --skip-tutorial keeps the old straight-to-the-pick flow (dev).
		if not Tutorial.skip_requested():
			Tutorial.begin(host)
			return
		# ISLANDPICK: the Tamed Island shape step sits inside character creation's own sheet (the
		# old free-standing terrain panel would open over it). It hands back the one permanent pick.
		var ip = (load("res://scripts/ui/island_pick.gd") as GDScript).instance_on(host)
		ip.picked.connect(func (shape_id: StringName) -> void:
			# Only a pick the world accepts proceeds: the screen re-enables itself otherwise.
			if not complete_pick(host, shape_id):
				print("[world] tamed island pick refused: shape=%s" % shape_id)
				ip.failed()
				return
			ip.close()
		)
		ip.open()
	)

func load_island(host: Node, id: StringName, at: Vector3, show_terrain: bool) -> void:
	_clear_runtime()
	build_recent.clear()  # a load or a crossing starts the build-spam window over
	island_id = id
	visited_islands[str(id)] = true
	island_def = def_of(id)
	_sink_warned = false
	if remaining_lifetime <= 0.0 and not bool(island_def.get("permanent", false)):
		remaining_lifetime = float(island_def.get("lifetime_seconds", 7200))
	var ir = (load("res://scripts/world/island_runtime.gd") as GDScript).new()
	ir.name = "IslandRuntime"
	host.add_child(ir)
	var terrain := home_terrain if is_home() and home_terrain != &"" else &"meadow"
	ir.build(island_def, terrain)
	runtime = ir
	if str(island_def.get("kind", "")) == "tutorial":
		Tutorial.dress(ir)
	var dp := host.get_node_or_null("DefaultPlayfield")
	if dp:
		dp.visible = false
		dp.process_mode = Node.PROCESS_MODE_DISABLED
	var player := _player()
	if player:
		if player.get_parent() != ir:
			player.reparent(ir)
		at.y = ir.surface_y(at.x, at.z) + 1.0
		player.global_position = at
		_apply_harvested(ir)
	# An unknown island starts with the camp known (spec 25: your base is on the map), not the
	# harbour you happened to arrive at.
	var camp_at: Variant = ir.get("_camp_pos")
	_ensure_map_fog(ir, camp_at if camp_at is Vector3 and (camp_at as Vector3) != Vector3.ZERO else (player.global_position if player else at))
	print("[world] island %s nodes=%d creatures=%d terrain=%s" % [
		id, int(ir.harvest_count), int(ir.creature_count), terrain])
	if int(island_def.get("tier", 0)) >= 30:
		Tasks.note(&"explore30")  # TASKSCREEN: weekly Explore Level-30 Islands (DW-T0125)
	island_changed.emit(id)
	if show_terrain and is_home() and home_terrain == &"":
		(load("res://scripts/ui/world_ui.gd") as GDScript).instance_on(host).show_terrain()

## BAGUI (owner 2026-10-28: "Harbor should use Warp Gems to teleport to islands"): a sailing's
## sail_cost is paid in Warp Gems. "" when paid, else the refusal the player sees; a refusal spends nothing.
func pay_sail(cost: int) -> String:
	if warp_gems < cost:
		return "Needs %d Warp Gems to sail (you have %d)." % [cost, warp_gems]
	warp_gems -= maxi(0, cost)
	return ""

func travel(to_id: StringName, mode: StringName) -> void:
	var dest := def_of(to_id)
	if dest.is_empty():
		print("[world] unknown island %s" % to_id)
		return
	var player := _player()
	if player == null:
		return
	# ASSUMPTION: the tutorial island's only way off is its last order (the Tamed Island grant).
	if is_tutorial() and Tutorial.active():
		player.notice("Finish the orders here first: the last one earns your own island")
		return
	if mode == &"sail":
		var required := route_level(to_id)
		if player.skills == null or player.skills.level_of("survival") < required:
			player.notice("Needs Survival %d" % required)
			return
		var why := pay_sail(int(dest.get("sail_cost", 0)))
		if why != "":
			player.notice(why)
			return
	if mode == &"harbour_home" or (mode == &"warp_home"):
		_strip_unstable_on_foot(player)
	var host := runtime.get_parent() if runtime else get_tree().current_scene
	var harbour: Array = dest.get("harbour", [0, 0, 12])
	var pos := Vector3(float(harbour[0]), 1.0, float(harbour[2]))
	await _fade_to(func () -> void:
		if str(island_def.get("kind", "")) == "unstable":
			_snapshot_harvest()
		# Capture the live camp before replacing its runtime, including unsaved storage.
		if is_home(): _save_now()
		remaining_lifetime = 0.0 # each destination starts its own island lifetime
		load_island(host, to_id, pos, false)
		if runtime and runtime.has_method("arrival_point"):
			player.global_position = runtime.arrival_point() + Vector3.UP
		if is_home():
			(load("res://scripts/core/save_game.gd") as GDScript)._restore_buildings(_home_buildings_cache, SaveMigrations.CURRENT_SCHEMA)
		_save_now()
	)

## Survival gates follow trees.json's L10/20/30/40/50 island nodes.
## Intermediate bands fill every five levels; volcano opens at Survival55.
func route_level(id: StringName) -> int:
	if id == &"home_grassland":
		return 0
	return clampi(int(def_of(id).get("tier", 60)) - 5, 10, 55)

func harbour_routes() -> Array[String]:
	var routes: Array[String] = []
	for id in islands:
		if id != "home_grassland" and str((islands[id] as Dictionary).get("kind", "")) != "tutorial":
			routes.append(str(id))
	routes.sort_custom(func (a: String, b: String) -> bool:
		var ta := int(def_of(StringName(a)).get("tier", 0))
		var tb := int(def_of(StringName(b)).get("tier", 0))
		return a < b if ta == tb else ta < tb
	)
	return routes

func record_raid_kill(species: StringName, source: Node) -> void:
	if source is Player:
		Tutorial.note("kill")
	if raid_victory or island_id != &"volcanic_60" or species != &"tyrannosaurus":
		return
	if not (source is Player or (source is Creature and (source as Creature).is_pet)):
		return
	raid_victory = true
	var player := _player()
	if player:
		player.notice("VICTORY: the volcano tyrant has fallen")
	print("[raid] VICTORY volcanic_60 tyrannosaurus")
	_save_now()

func warp_home() -> void:
	travel(&"home_grassland", &"warp_home")

func recall_camp() -> void:
	if runtime == null or not is_unstable():
		return
	var camp: Array = island_def.get("camp", [0, 0, 8])
	var player := _player()
	if player:
		player.global_position = Vector3(float(camp[0]), 1.0, float(camp[2]))
		if runtime and runtime.has_method("surface_y"):
			player.global_position.y = runtime.surface_y(float(camp[0]), float(camp[2])) + 1.0
	print("[world] returned to camp")

func cargo_warp(player: Player) -> void:
	if not is_unstable():
		print("[world] cargo warp is at the unstable camp")
		return
	if t_stones < CARGO_FEE:
		print("[world] cargo warp needs %d Gold" % CARGO_FEE)
		return
	var moved := 0
	for i in range(player.inventory.slot_count - 1, -1, -1):
		var s := player.inventory.slots[i]
		if s == null or not s.is_unstable():
			continue
		# Ship only accepted units. A full cargo basket must not destroy the bag.
		var copy := s.duplicate_stack()
		copy.set_flag(&"unstable", false)
		var offered := copy.count
		var left := cargo_home.add(copy)
		var accepted := offered - left
		if accepted > 0:
			player.inventory.remove_at(i, accepted)
			moved += 1
	if moved <= 0:
		print("[world] nothing accepted by cargo basket (empty shipment or full storage)")
		return
	t_stones -= CARGO_FEE
	print("[world] cargo warp %d stacks fee=%d" % [moved, CARGO_FEE])

func note_craft(recipe_id: StringName) -> void:
	Tasks.note(&"craft")  # TASKSCREEN: every craft counts toward the craft tasks, and per recipe
	Tasks.note(StringName("craft:" + str(recipe_id)))
	if pioneer_crafts.has(str(recipe_id)):
		return
	pioneer_crafts[str(recipe_id)] = true
	add_xp(25)  # first time crafting a recipe: a discovery bonus, not a free level

## XP a placement of `kind` at `at` pays (rules.json "xp"): 0 when another of its kind stands
## within build_spam_radius_m and was placed less than build_spam_seconds ago; build_repeat when the
## kind was placed before (pioneer_buildings, which is saved); build_first the first time ever.
func build_placement_xp(kind: StringName, at: Vector3) -> int:
	var cfg: Dictionary = Data.world_rules.get("xp", {})
	var radius := float(cfg.get("build_spam_radius_m", 10.0))
	var window := float(cfg.get("build_spam_seconds", 60.0))
	if at == Vector3.ZERO:
		# A caller with no position to give (build_flow, outside this task) cannot be judged by
		# distance: it pays the first/repeat award and never counts as a twin for anyone else.
		return int(cfg.get("build_repeat", 8)) if int(pioneer_buildings.get(str(kind), 0)) > 0 else int(cfg.get("build_first", 30))
	var now := float(Time.get_ticks_msec()) / 1000.0
	var keep: Array = []
	for e: Dictionary in build_recent:
		if now - float(e.get("t", 0.0)) < window:
			keep.append(e)
	build_recent = keep
	for e: Dictionary in build_recent:
		var was := e.get("pos", Vector3.ZERO) as Vector3
		if str(e.get("kind", "")) == str(kind) and was.distance_to(at) <= radius:
			return 0
	build_recent.append({"kind": str(kind), "pos": at, "t": now})
	if int(pioneer_buildings.get(str(kind), 0)) > 0:
		return int(cfg.get("build_repeat", 8))
	return int(cfg.get("build_first", 30))

## A build was placed. Remembers the kind (pioneer_buildings: the saved first-of-kind memory) and
## pays the build XP once, to the Construction tree, which mirrors it into World.add_xp, so the
## skill and the character bar both follow rules.json's numbers. `extra_xp` is a blueprint's own
## reward (build_flow), paid in the same grant instead of a second one. Returns the XP paid.
func note_building(kind: StringName, at: Vector3 = Vector3.ZERO, player: Player = null, extra_xp: int = 0) -> int:
	# The first-of-kind memory and the spam rule are the Tamed Island's (is_home), as before: an
	# unstable island is a visit, so every build there pays the repeat award (the old flat 8) and no
	# kind is remembered.
	Tasks.note(&"build")  # TASKSCREEN: daily Construct a Building (DW-T0123)
	Tutorial.note("build")
	var total := maxi(0, extra_xp)
	if is_home():
		total += build_placement_xp(kind, at)
		pioneer_buildings[str(kind)] = int(pioneer_buildings.get(str(kind), 0)) + 1
	else:
		total += int((Data.world_rules.get("xp", {}) as Dictionary).get("build_repeat", 8))
	if total <= 0:
		return 0
	var who := player if player else _player()
	if who and who.skills:
		who.skills.add_xp("construction", float(total)) # mirrors into World.add_xp and the Survival route
	else:
		add_xp(total)
	return total

# ------------------------------------------------------------------------------------ landmarks

## The landmarks of the island being played (IslandRuntime.landmarks), [] off-island.
func current_landmarks() -> Array:
	if runtime == null or not is_instance_valid(runtime):
		return []
	var v: Variant = runtime.get("landmarks")
	return v if v is Array else []

func landmark_is_found(island: String, site_id: String) -> bool:
	var row: Variant = landmarks_found.get(island, null)
	return row is Dictionary and bool((row as Dictionary).get(site_id, false))

## Found / total on the island being played: the map's "Landmarks Found x / y".
func landmarks_found_count() -> Vector2i:
	var all := current_landmarks()
	var n := 0
	for s in all:
		if landmark_is_found(str(island_id), str((s as Dictionary).get("id", ""))):
			n += 1
	return Vector2i(n, all.size())

## True while a dormant site's opened window still runs (IslandLandmarks.build regrows it on a reload).
func landmark_open(island: String, site_id: String) -> bool:
	var row: Variant = landmark_state.get(island, {})
	if not row is Dictionary:
		return false
	var st: Variant = (row as Dictionary).get(site_id, null)
	return st is Dictionary and float((st as Dictionary).get("left", 0.0)) > 0.0

## True once a dormant site's window has closed: it stays empty (and unsealed) until the island resets.
func landmark_spent(island: String, site_id: String) -> bool:
	var row: Variant = landmark_state.get(island, {})
	if not row is Dictionary:
		return false
	var st: Variant = (row as Dictionary).get(site_id, null)
	return st is Dictionary and bool((st as Dictionary).get("spent", false))

## 4 Hz from _process (and the tests): a landmark is found when the survivor walks within its
## discovery radius (doc section 5.6, 18 m # ASSUMPTION). Returns the site found this call, or {}.
func check_landmarks(pos: Vector3) -> Dictionary:
	if creation_pending:
		return {}
	for s in current_landmarks():
		var site: Dictionary = s
		if landmark_is_found(str(island_id), str(site.get("id", ""))):
			continue
		var r := float(site.get("discovery_radius", 18.0))
		var dx := pos.x - float(site.get("x", 0.0))
		var dz := pos.z - float(site.get("z", 0.0))
		if dx * dx + dz * dz <= r * r:
			discover_landmark(site)
			return site
	return {}

## Marks one landmark found on the island being played and pays for it once: Gold by island tier
## (IslandLandmarks.gold_for_tier), and on the island's first find the Joy of Discovery fatigue drop.
## False when it was already found.
func discover_landmark(site: Dictionary) -> bool:
	var key := str(island_id)
	var sid := str(site.get("id", ""))
	if sid == "" or landmark_is_found(key, sid):
		return false
	var row: Dictionary = landmarks_found.get(key, {}) if landmarks_found.get(key, {}) is Dictionary else {}
	var first := row.is_empty()
	row[sid] = true
	landmarks_found[key] = row
	var gold := int(site.get("gold", 20))
	t_stones += gold
	if sid == "crater":
		crater_discovered = true
	var player := _player()
	if player:
		if first:
			player.vitals.rest(absf(float(IslandLandmarks.rules().get("joy_fatigue", -20))))
		var c := landmarks_found_count()
		var sealed := " (sealed)" if bool(site.get("dormant", false)) and not landmark_open(key, sid) else ""
		player.notice("Landmark found: %s%s  +%d Gold  (%d / %d)" % [str(site.get("display", sid)), sealed, gold, c.x, c.y])
	print("[landmarks] found island=%s id=%s gold=%d" % [key, sid, gold])
	landmark_found.emit(site)
	return true

## Opens a found dormant landmark at the site for Gold (doc section 5.3, A3): charges once, grows its
## node group, starts its window. "" when it opened, else the refusal the player sees (nothing spent).
func open_landmark(site_id: String) -> String:
	var key := str(island_id)
	var site := IslandLandmarks.site_by_id(runtime as IslandRuntime, site_id)
	if site.is_empty() or not bool(site.get("dormant", false)):
		return "Nothing to open here"
	if landmark_spent(key, site_id):
		return "This site is spent until the island resets"
	if landmark_open(key, site_id) or int(site.get("planted", 0)) > 0:
		return "Already open"
	var cfg: Dictionary = IslandLandmarks.rules().get("dormant", {})
	var cost := int(cfg.get("open_cost_gold", 50))
	if t_stones < cost:
		return "Needs %d Gold to open (you have %d)" % [cost, t_stones]
	if not IslandLandmarks.open_site(runtime as IslandRuntime, island_def, site):
		return "The site will not open"
	t_stones -= cost
	var row: Dictionary = landmark_state.get(key, {}) if landmark_state.get(key, {}) is Dictionary else {}
	row[site_id] = {"left": float(cfg.get("window_s", 1200))}
	landmark_state[key] = row
	if not landmark_is_found(key, site_id):
		discover_landmark(site)
	var seal: Variant = site.get("seal", null)
	if seal is Node and is_instance_valid(seal):
		(seal as Node).queue_free()
	site.erase("seal")
	print("[landmarks] opened island=%s id=%s cost=%d" % [key, site_id, cost])
	return ""

## An opened dormant window counts down only while that island is the one being played (the game
## running there); at 0 the site's unharvested nodes wither and it stays spent.
func _tick_landmark_windows(delta: float) -> void:
	var row: Variant = landmark_state.get(str(island_id), null)
	if not row is Dictionary:
		return
	for sid in (row as Dictionary).keys():
		var st: Variant = (row as Dictionary)[sid]
		if not st is Dictionary or float((st as Dictionary).get("left", 0.0)) <= 0.0:
			continue
		var left := maxf(0.0, float((st as Dictionary)["left"]) - delta)
		(st as Dictionary)["left"] = left
		if left <= 0.0:
			(st as Dictionary)["spent"] = true
			var site := IslandLandmarks.site_by_id(runtime as IslandRuntime, str(sid))
			if not site.is_empty():
				var gone := IslandLandmarks.wither_site(runtime as IslandRuntime, site)
				site["spent"] = true
				print("[landmarks] withered island=%s id=%s nodes=%d" % [str(island_id), str(sid), gone])

func discover_crater() -> void:
	# LANDMARKS: the crater is one landmark now; its find pays through discover_landmark (tier Gold).
	for s in current_landmarks():
		if str((s as Dictionary).get("id", "")) == "crater":
			discover_landmark(s)
			crater_discovered = true
			return
	if crater_discovered:
		return
	crater_discovered = true
	var player := _player()
	if player:
		var drop := absf(float(Data.world_rules.get("craters", {}).get("discover_fatigue", -20)))
		player.vitals.rest(drop)
	t_stones += int(Data.world_rules.get("craters", {}).get("discover_tstones", 30))
	print("[world] crater discovered")

func _strip_unstable_on_foot(player: Player) -> void:
	var lost := 0
	for i in range(player.inventory.slot_count - 1, -1, -1):
		var s := player.inventory.slots[i]
		if s and s.is_unstable():
			player.inventory.remove_at(i, s.count)
			lost += 1
	if lost > 0:
		print("[world] unstable goods destroyed")

func _snapshot_harvest() -> void:
	harvested.clear()
	if runtime == null:
		return
	for n in runtime.get_tree().get_nodes_in_group("harvest"):
		var node := n as HarvestNode
		if node == null:
			continue
		harvested[str(node.node_id)] = {
			"pool": node.pool,
			"pool_max": node.pool_max,
			"session_gathered": node.session_gathered,
			"regen_left": node.regen_left(),
			"depleted": node.depleted, # backward compatibility while schema is still 1
			"pools": node.pools_snapshot(),
		}
	if runtime and runtime.has_method("harvest_tile_snapshot"):
		harvested["__tiles"] = runtime.harvest_tile_snapshot()

func _apply_harvested(ir: Node) -> void:
	for n in ir.get_tree().get_nodes_in_group("harvest"):
		var node := n as HarvestNode
		if node == null:
			continue
		var row: Variant = harvested.get(str(node.node_id), null)
		if row is Dictionary:
			var pool_max := int(row.get("pool_max", node.pool_max))
			var pool := float(row.get("pool", float(node.pool_max if not bool(row.get("depleted", false)) else 0.0)))
			var session_gathered := int(row.get("session_gathered", node.session_gathered))
			var regen_left := float(row.get("regen_left", -1.0))
			node.restore_snapshot(pool, pool_max, session_gathered, regen_left)
			var snap: Variant = row.get("pools", null)
			if snap is Dictionary:
				node.restore_pools(snap as Dictionary)
	var tiles_v: Variant = harvested.get("__tiles", {})
	if tiles_v is Dictionary and ir.has_method("apply_harvest_tile_snapshot"):
		ir.apply_harvest_tile_snapshot(tiles_v as Dictionary)

## The current island's fog, made on first visit (or when the land mask is for a bigger island).
## An island never seen before starts with the camp area known (spec 25: the camp is your base).
func _ensure_map_fog(ir: Node3D, camp: Vector3) -> void:
	var key := str(island_id)
	var size_m: float = float(ir.get("_size")) if ir and ir.get("_size") != null else 200.0
	var f: Variant = map_fogs.get(key, null)
	if f == null or not (f is MapFog) or not (f as MapFog).matches(size_m):
		f = MapFog.new()
		(f as MapFog).setup(key, size_m)
		map_fogs[key] = f
		if _reveal_camp_on_new_fog and camp != Vector3.ZERO:
			(f as MapFog).reveal(camp, MapFog.OLD_SAVE_REVEAL_M)
			_reveal_camp_on_new_fog = false
	map_fog = f as MapFog
	map_fog.land_from(ir)

## One step of the fog/trail (called from _process, the HUD minimap and the lab). Cheap enough at
## 4 Hz: one circle test over a handful of 2 m cells.
func note_map_walk(pos: Vector3) -> void:
	if map_fog == null or creation_pending:
		return
	map_fog.walk(pos)

func map_map() -> Dictionary:
	var rows := {}
	for key in map_fogs:
		var f: Variant = map_fogs[key]
		if f is MapFog:
			rows[str(key)] = (f as MapFog).to_dict()
	return {"islands": rows}

## Rows come from a user-editable file: keep only plausible islands (<= 1 km, <= 200 kB of fog,
## trail points inside the world) before building a bitmap from them (SaveSanitizer is out of this
## task's scope, so the cap lives here where the row is read).
func load_map_map(row: Dictionary) -> void:
	map_fogs.clear()
	map_fog = null
	var islands: Variant = row.get("islands", {})
	if not islands is Dictionary:
		return
	for key in (islands as Dictionary).keys():
		var d: Variant = (islands as Dictionary)[key]
		if not d is Dictionary:
			continue
		var f: Dictionary = d as Dictionary
		var size_v: Variant = f.get("size", 160.0)
		if not (size_v is int or size_v is float) or not is_finite(float(size_v)) or float(size_v) <= 0.0 or float(size_v) > 1000.0:
			continue
		if str(f.get("fog", "")).length() > 200000:
			continue
		var clean := {"id": str(f.get("id", key)), "size": float(size_v), "fog": str(f.get("fog", "")), "trail": []}
		var pts: Variant = f.get("trail", [])
		if pts is Array:
			for p in pts:
				if p is Array and (p as Array).size() >= 2:
					var a: Variant = (p as Array)[0]
					var b: Variant = (p as Array)[1]
					if not ((a is int or a is float) and (b is int or b is float) and is_finite(float(a)) and is_finite(float(b)) and absf(float(a)) <= 1000.0 and absf(float(b)) <= 1000.0):
						continue
					var clean_point: Array = [float(a), float(b)]
					if (p as Array).size() >= 3:
						var age: Variant = (p as Array)[2]
						if not (age is int or age is float) or not is_finite(float(age)):
							continue
						clean_point.append(maxf(0.0, float(age)))
					clean["trail"].append(clean_point)
		map_fogs[str(key)] = MapFog.from_dict(clean)

func _clear_runtime() -> void:
	if runtime and is_instance_valid(runtime):
		runtime.queue_free()
	runtime = null

func _player() -> Player:
	return PlayerRegistry.local()

func _ensure_fade() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 80
	layer.name = "WorldFade"
	add_child(layer)
	_fade = ColorRect.new()
	_fade.color = Color(0, 0, 0, 0)
	_fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(_fade)

func _fade_to(cb: Callable) -> void:
	_fade.mouse_filter = Control.MOUSE_FILTER_STOP
	var tw := create_tween()
	tw.tween_property(_fade, "color:a", 1.0, 0.25)
	await tw.finished
	cb.call()
	var tw2 := create_tween()
	tw2.tween_property(_fade, "color:a", 0.0, 0.25)
	await tw2.finished
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE

func _save_now() -> void:
	(load("res://scripts/core/save_game.gd") as GDScript).save_now()

func _save_exists() -> bool:
	return bool((load("res://scripts/core/save_game.gd") as GDScript).exists())

func _load_now(host: Node) -> void:
	(load("res://scripts/core/save_game.gd") as GDScript).load_now(host)

func _load_islands(_dir: String) -> void:
	islands.clear()
	for key in Data.world_islands.keys():
		if key.begins_with("_"):
			continue
		var row: Variant = Data.world_islands[key]
		if row is Dictionary:
			islands[str((row as Dictionary).get("id", key))] = (row as Dictionary).duplicate(true)
	var da := DirAccess.open("res://data/islands")
	if da:
		da.list_dir_begin()
		var fname := da.get_next()
		while fname != "":
			if not da.current_is_dir() and fname.ends_with(".json"):
				var f := FileAccess.open("res://data/islands/%s" % fname, FileAccess.READ)
				if f:
					var parsed: Variant = JSON.parse_string(f.get_as_text())
					if parsed is Dictionary:
						var id := str(parsed.get("id", fname.get_basename()))
						var base: Dictionary = islands.get(id, {})
						for k in parsed:
							base[k] = parsed[k]
						islands[id] = base
			fname = da.get_next()
		da.list_dir_end()
	for id in islands.keys():
		var d: Dictionary = islands[id]
		if not d.has("kind"):
			d["kind"] = "private" if bool(d.get("permanent", false)) else "unstable"
		if not d.has("sail_cost"):
			d["sail_cost"] = 5
		if not d.has("display_name"):
			d["display_name"] = str(id).replace("_", " ").capitalize()
		if not d.has("size_m"):
			var sizes: Dictionary = Data.world_rules.get("island_size_m", {})
			d["size_m"] = sizes.get("home" if d["kind"] == "private" else "unstable", 240)
		if not d.has("lifetime_seconds"):
			d["lifetime_seconds"] = float(d.get("lifetime_hours", 6)) * 3600.0
		islands[id] = d
	Game.max_creatures_per_island = int(Data.world_rules.get("creature_cap_mobile", 24))

func claims_for_current() -> Array:
	return home_claims if is_home() else unstable_claims

func domain_for_current() -> Dictionary:
	return home_domain if is_home() else away_domain

## One player level. Every skill-tree XP grant (gathering, fighting, crafting, cooking, building,
## farming...) also lands here (SkillState.add_xp), so the bottom bar moves with everything.
## Owner 2026-10-28: each level costs exponentially more. Stored level n needs
## round(base x growth^n x player_xp_cost_mult) XP (pioneer_levels.json xp_curve; ASSUMPTION base 110,
## growth 1.12; progression.json knob, owner 2026-10-28 "levels up slower").
static var _xp_curve: Dictionary = {}

static func xp_curve() -> Dictionary:
	if _xp_curve.is_empty():
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/skills/pioneer_levels.json"))
		var c: Variant = (parsed as Dictionary).get("xp_curve", {}) if parsed is Dictionary else {}
		_xp_curve = c if c is Dictionary and not (c as Dictionary).is_empty() else {"base": 110, "growth": 1.12, "segment_xp": 100, "max_segments": 40}
	return _xp_curve

static func xp_for_level(level: int) -> int:
	var c := xp_curve()
	return maxi(1, roundi(float(c["base"]) * pow(float(c["growth"]), maxi(0, level)) * Progression.mult("player_xp_cost_mult")))

## The pre-2026-10-28 linear curve, only to read an old save's total XP.
static func old_xp_for_level(level: int) -> int:
	return 100 + 25 * level

## [stored level, XP into it] for a total XP on the current curve.
static func level_from_total(total: int) -> Vector2i:
	var level := 0
	while total >= xp_for_level(level):
		total -= xp_for_level(level)
		level += 1
	return Vector2i(level, total)

## A save from before the exponential curve: the same total XP, the level recomputed on the new
## curve. Where that would drop her level the stored level stays as a floor, its bar emptied to the
## leftover clamped under the level's cost (owner asked for the curve; nobody loses a level).
static func migrate_linear_xp(stored_level: int, stored_xp: int) -> Vector2i:
	var total := stored_xp
	for l in stored_level:
		total += old_xp_for_level(l)
	var now := level_from_total(total)
	if now.x >= stored_level:
		return now
	return Vector2i(stored_level, clampi(stored_xp, 0, xp_for_level(stored_level) - 1))

func add_xp(n: int) -> void:
	if n <= 0:
		return
	pioneer_xp += n
	while pioneer_xp >= xp_for_level(pioneer_level):
		pioneer_xp -= xp_for_level(pioneer_level)
		pioneer_level += 1
		pioneer_changed.emit(pioneer_level)

func pioneer_progress() -> float:
	return clampf(float(pioneer_xp) / float(maxi(1, xp_for_level(pioneer_level))), 0.0, 1.0)
