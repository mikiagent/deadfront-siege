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
## ISLAND RESET (docs/design/island-resources.md sections 3.4 and 5.5, A1 + A2): one record per
## expedition island id, {"generation": int, "left": seconds of play until it resets (-1 = never
## visited, no clock), "harvested": its node snapshot}. Every started clock runs while the game runs
## on any island and never while it is closed; leaving and coming back does not restart it. At 0 the
## island rerolls: generation + 1, a new seed, found landmarks, fog and harvest state cleared.
## Saved as "expeditions"; an old save has none (generation 0, a first visit).
var expeditions: Dictionary = {}
var _life_warned: Dictionary = {} ## warning seconds already shown on this visit
signal island_reset(id: StringName, generation: int)
## UNSTABLE ISLES (docs/design/unstable-isles.md): the one generated, short-life island on offer or
## live ({} when none), the play seconds before the next may roll, and how many have been rolled.
var drift: Dictionary = {}
var drift_cooldown: float = 0.0
var drift_count: int = 0
signal drift_offered(id: StringName)
signal drift_sunk(id: StringName)
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

const SAVE_PATH := "user://save_1.json"
const CARGO_FEE := 2 ## ASSUMPTION: T-stones to cargo-warp a bag of unstable goods

func _ready() -> void:
	_load_islands("res://data/islands")
	_load_shapes()
	call_deferred("_boot")

func _process(delta: float) -> void:
	if map_fog != null:
		map_fog.advance_trail(delta)
	if not creation_pending:
		tick_expeditions(delta)
		tick_drifts(delta)
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
	# ISLAND RESET: a rerolled expedition island builds from hash(template seed, generation); generation
	# 0 keeps the template's own seed, so a first visit (and every old save) is unchanged.
	var gen := expedition_generation(str(id))
	if gen > 0:
		d = d.duplicate(true)
		d["seed"] = expedition_seed(int(d.get("seed", 17)), gen)
		d["generation"] = gen
		d["avoid_centres"] = ((expeditions[str(id)] as Dictionary).get("last_centres", []) as Array).duplicate(true)
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
		if LoadingScreen.active():
			LoadingScreen.current.finish()
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
		# a real save: SaveGame._apply also lifts "creation pending". LOADING: under the overlay.
		LoadingScreen.run("Loading your save", func () -> void: _load_now(host))
		return true
	if LoadingScreen.active():
		LoadingScreen.current.finish()  # the boot overlay lifts off character creation
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
	Factions.reset()
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
			LoadingScreen.run("Entering the %s" % str(def_of(Tutorial.ISLAND).get("display_name", "Tutorial Island")),
				func () -> void: Tutorial.begin(host))
			return
		# ISLANDPICK: the Tamed Island shape step sits inside character creation's own sheet (the
		# old free-standing terrain panel would open over it). It hands back the one permanent pick.
		var ip = (load("res://scripts/ui/island_pick.gd") as GDScript).instance_on(host)
		ip.picked.connect(func (shape_id: StringName) -> void:
			# Only a pick the world accepts proceeds: the screen re-enables itself otherwise.
			var ok := [false]
			await LoadingScreen.run(sail_title(&"home_grassland", shape_id), func () -> void: ok[0] = complete_pick(host, shape_id))
			if not ok[0]:
				print("[world] tamed island pick refused: shape=%s" % shape_id)
				ip.failed()
				return
			ip.close()
		)
		ip.open()
	)

func load_island(host: Node, id: StringName, at: Vector3, show_terrain: bool) -> void:
	# ISLAND RESET: the island being left keeps its own harvest state (two expedition islands never
	# share one snapshot).
	if is_unstable() and runtime != null and is_instance_valid(runtime) and not runtime.is_queued_for_deletion():
		_snapshot_harvest()
	_clear_runtime()
	build_recent.clear()  # a load or a crossing starts the build-spam window over
	island_id = id
	visited_islands[str(id)] = true
	island_def = def_of(id)
	_sink_warned = false
	_life_warned.clear()
	if is_unstable():
		# ISLAND RESET: the island's own clock (started on its first visit, never restarted by an
		# arrival) and its own harvest state, not the last expedition island's.
		var row := expedition_row(str(id), true)
		remaining_lifetime = float(row["left"])
		var snap: Variant = row.get("harvested", {})
		harvested = (snap as Dictionary).duplicate(true) if snap is Dictionary else {}
	var terrain := home_terrain if is_home() and home_terrain != &"" else &"meadow"
	var ir = _build_runtime(host, terrain)
	# UNSTABLE ISLES: a rolled isle must be a real destination (doc section 7): its Rift Pool and its
	# landmark minimum reachable from the dock. A roll that is not (a swamp chain whose mud cuts the
	# harbour off) re-rolls its seed before anyone sees it, at most twice.
	for _retry in 2:
		if not is_drift(str(id)) or _drift_valid(ir):
			break
		print("[world] unstable isle %s seed %d is not a valid destination; re-rolling" % [id, int(drift.get("seed", 0))])
		ir.free()
		drift["seed"] = absi(hash("%d|reroll" % int(drift.get("seed", 0)))) % 2000000000
		_install_drift()
		island_def = def_of(id)
		ir = _build_runtime(host, terrain)
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
	var title := ("Warping to %s" if mode == &"warp_home" else "Sailing to %s") % str(dest.get("display_name", to_id))
	await _fade_to(func () -> void:
		if str(island_def.get("kind", "")) == "unstable":
			_snapshot_harvest()
		# Capture the live camp before replacing its runtime, including unsaved storage.
		if is_home(): _save_now()
		remaining_lifetime = 0.0 # each destination starts its own island lifetime
		load_island(host, to_id, pos, false)
		Tasks.note(&"land")  # FACTIONS: Three Islands counts real arrivals by travel, never a save load (t_save re-save)
		if runtime and runtime.has_method("arrival_point"):
			player.global_position = runtime.arrival_point() + Vector3.UP
		if is_home():
			(load("res://scripts/core/save_game.gd") as GDScript)._restore_buildings(_home_buildings_cache, SaveMigrations.CURRENT_SCHEMA)
		_save_now()
	, title)

## LOADING: "Sailing to Meadow Isle" for the Tamed Island being picked (its name comes from the shape).
func sail_title(to_id: StringName, shape_id: StringName = &"") -> String:
	var nm := str(shape_def(shape_id).get("display_name", "")) if shape_id != &"" else ""
	return "Sailing to %s" % (nm if nm != "" else str(def_of(to_id).get("display_name", to_id)))

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
	Tasks.note(StringName("build:" + str(kind)))  # FACTIONS: missions that name a building
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

# ------------------------------------------------------------------------------------ island reset

## Seconds of play an expedition island lives (rules.json lifetime_hours by tier band: 6 h at 15-25,
## 12 h at 30-45, 24 h at 50-60; doc section 5.5). An island row's own lifetime_seconds wins only when
## it is not the old 2-hour test value.
func expedition_lifetime(id: String) -> float:
	var d := islands.get(id, {}) as Dictionary
	if bool(d.get("generated", false)):
		return float(drift_rules().get("life_s", 2400))
	var tier := int(d.get("tier", 25))
	var bands: Dictionary = Data.world_rules.get("lifetime_hours", {})
	for key in bands.keys():
		var parts := str(key).split("-")
		if parts.size() == 2 and tier >= int(parts[0]) and tier <= int(parts[1]):
			return float(bands[key]) * 3600.0
	return float(d.get("lifetime_seconds", 6 * 3600))

## The island's record, made (clock started) on `start` when it has none or none running.
func expedition_row(id: String, start: bool = false) -> Dictionary:
	var row: Variant = expeditions.get(id, null)
	if not row is Dictionary:
		row = {"generation": 0, "left": -1.0, "harvested": {}}
		if start:
			expeditions[id] = row
	if start and float((row as Dictionary).get("left", -1.0)) <= 0.0:
		(row as Dictionary)["left"] = expedition_lifetime(id)
	return row as Dictionary

func expedition_generation(id: String) -> int:
	var row: Variant = expeditions.get(id, null)
	return int((row as Dictionary).get("generation", 0)) if row is Dictionary else 0

static func expedition_seed(template_seed: int, generation: int) -> int:
	return absi(hash("%d|%d|reset" % [template_seed, generation])) % 2000000000

## Every started clock counts down while the game runs (A2: on any island, never while closed). The
## current island also mirrors into remaining_lifetime (HUD, map) and warns at 10 min and 60 s.
func tick_expeditions(delta: float) -> void:
	var due: Array[String] = []
	for id in expeditions.keys():
		var row: Variant = expeditions[id]
		if not row is Dictionary or float((row as Dictionary).get("left", -1.0)) <= 0.0:
			continue
		var left := maxf(0.0, float((row as Dictionary)["left"]) - delta)
		(row as Dictionary)["left"] = left
		if left <= 0.0:
			due.append(str(id))
	if is_unstable():
		remaining_lifetime = float(expedition_row(str(island_id)).get("left", remaining_lifetime))
		for warn_s in [600.0, float(Data.world_rules.get("sink_warning_seconds", 60))]:
			if remaining_lifetime > 0.0 and remaining_lifetime <= warn_s and not _life_warned.has(warn_s):
				_life_warned[warn_s] = true
				_sink_warned = true
				var p := _player()
				if p:
					p.notice("This island %s in %s: pack your kits and ship your cargo" % [
						"sinks" if is_drift(str(island_id)) else "resets",
						"10 minutes" if warn_s >= 600.0 else "%d seconds" % int(warn_s)])
				print("[world] sink warning %.0fs" % remaining_lifetime)
	for id in due:
		if is_drift(id):
			sink_drift(id)
		else:
			reset_expedition(id)

## The island rerolls (doc section 5.5 step 5): generation + 1 (a new seed), its found landmarks,
## opened sites, fog and harvest state cleared, and its clock starts again. When the survivor stands
## on it, its placed buildings refund half their materials and its storage moves to the home vault
## (A1), then the new layout builds and the survivor lands at its harbour with the sail menu open.
func reset_expedition(id: String) -> void:
	var row := expedition_row(id)
	# The old layout's landmark centres: the next generation's sites keep away from them, so a reset
	# reads as a new island (doc section 6, M4: 70 % of centres move over 40 m).
	if str(island_id) == id:
		var old: Array = []
		for s in current_landmarks():
			old.append([float((s as Dictionary).get("x", 0.0)), float((s as Dictionary).get("z", 0.0))])
		row["last_centres"] = old
	row["generation"] = int(row.get("generation", 0)) + 1
	row["harvested"] = {}
	row["left"] = expedition_lifetime(id)
	expeditions[id] = row
	landmarks_found.erase(id)
	landmark_state.erase(id)
	map_fogs.erase(id)
	print("[world] island %s reset generation=%d" % [id, int(row["generation"])])
	if str(island_id) == id and runtime != null and is_instance_valid(runtime):
		var salvage := salvage_buildings()
		var host := runtime.get_parent()
		_clear_runtime()  # no outgoing snapshot: the old layout's harvest state is gone
		harvested = {}
		map_fog = null
		unstable_claims = []
		away_domain = {}
		var player := _player()
		# LOADING: the reroll rebuilds the island under the overlay, not as a hard cut.
		await LoadingScreen.run("The island shifted: charting %s" % str(def_of(StringName(id)).get("display_name", id)), func () -> void:
			load_island(host, StringName(id), Vector3.ZERO, false)
			if player and runtime and runtime.has_method("arrival_point"):
				player.global_position = runtime.arrival_point() + Vector3.UP
		)
		if player:
			player.notice("The island shifted. %s" % ("Your camp's salvage went to the home vault." if salvage > 0 else "A new coast waits."))
		var ui = (load("res://scripts/ui/world_ui.gd") as GDScript).ensure()
		if ui and ui.has_method("show_harbour"):
			ui.show_harbour()
	island_reset.emit(StringName(id), int(row["generation"]))

## A1 (approved): what stood on the island when it reset. Every placed building's storage moves to
## the home vault (cargo_home) whole, and the building itself refunds half the materials its kit's
## recipe takes (# ASSUMPTION: 50 %, rounded down per slot, each slot paid in the lowest-level item of
## its category). Returns the stacks moved.
func salvage_buildings() -> int:
	if runtime == null:
		return 0
	var moved := 0
	for n in runtime.get_tree().get_nodes_in_group("placed_building"):
		if not is_instance_valid(n) or n.is_queued_for_deletion() or n.get("persist_building") == false:
			continue
		if not runtime.is_ancestor_of(n):
			continue
		var back: Array[ItemStack] = BuildPlacer.stored_items(n)
		back.append_array(building_refund(BuildPlacer.kind_of_building(n)))
		for st in back:
			st.set_flag(&"unstable", false)
			if cargo_home.add(st) < st.count:
				moved += 1
	if moved > 0:
		print("[world] reset salvage %d stacks to the home vault" % moved)
	return moved

## Half (rounded down) of a building kind's kit recipe, as stacks; [] when it has no recipe.
func building_refund(kind: StringName) -> Array[ItemStack]:
	var out: Array[ItemStack] = []
	var kit := BuildPlacer.kit_for(kind)
	if kit == &"":
		return out
	var recipe: Dictionary = {}
	for rid in Data.recipes:
		var r: Dictionary = Data.recipes[rid]
		if str((r.get("output", {}) as Dictionary).get("id", "")) == str(kit):
			recipe = r
			break
	var share := float((Data.world_rules.get("reset", {}) as Dictionary).get("building_refund", 0.5))
	for slot in recipe.get("slots", []):
		var n := int(floor(float((slot as Dictionary).get("count", 1)) * share))
		var item := _category_item(StringName(str((slot as Dictionary).get("category", ""))), str((slot as Dictionary).get("item", "")))
		if n > 0 and item != &"":
			for _i in n:
				out.append(ItemStack.make(item, 1))
	return out

## The item a refund pays a recipe slot in: the slot's own item, else the lowest-level item of its
## category (ties by id, so a refund is the same every time).
func _category_item(cat: StringName, item: String) -> StringName:
	if item != "" and Data.item(StringName(item)) != null:
		return StringName(item)
	var best: StringName = &""
	var best_lv := 1 << 30
	for id in Data.items:
		var def: ItemDef = Data.items[id]
		if def == null or not def.has_category(cat):
			continue
		var lv := def.base_level
		if lv < best_lv or (lv == best_lv and str(id) < str(best)):
			best_lv = lv
			best = StringName(str(id))
	return best

# ------------------------------------------------------------------------------------ unstable isles

## rules.json "unstable_isles" (all # ASSUMPTION, docs/design/unstable-isles.md section 2).
func drift_rules() -> Dictionary:
	return Data.world_rules.get("unstable_isles", {}) as Dictionary

func is_drift(id: String) -> bool:
	return bool((islands.get(id, {}) as Dictionary).get("generated", false))

## True once the survivor has landed (the isle's own clock runs): the route can no longer expire.
func drift_landed() -> bool:
	return not drift.is_empty() and expeditions.has(str(drift.get("id", "")))

## Seconds left on the board (offer) or before it sinks (landed); 0 with no isle.
func drift_time_left() -> float:
	if drift.is_empty():
		return 0.0
	if drift_landed():
		return float(expedition_row(str(drift["id"])).get("left", 0.0))
	return float(drift.get("offer_left", 0.0))

## The highest roster tier a survivor of this Survival level can sail to (route_level = tier - 5).
func _sailable_top(survival: int) -> int:
	var top := 15
	for id in islands:
		var d: Dictionary = islands[id]
		if str(d.get("kind", "")) != "unstable" or bool(d.get("generated", false)):
			continue
		if route_level(StringName(str(id))) <= survival:
			top = maxi(top, int(d.get("tier", 15)))
	return top

## Rolls a new isle from `p_seed` (doc section 2): level band around the survivor's top sailable tier,
## a climate whose roster islands sit near it (the nearest roster row is the template: spawns, weather),
## a roster shape family, a smaller size. Installs it as a harbour route; returns its id ("" when none).
func roll_drift(p_seed: int, survival: int) -> String:
	if not drift.is_empty():
		return ""
	var r := drift_rules()
	var rng := RandomNumberGenerator.new()
	rng.seed = p_seed
	var spread := int(r.get("tier_spread", 5))
	var tier := clampi(_sailable_top(survival) + rng.randi_range(-1, 1) * spread, 15, 60)
	# Templates: roster expedition rows within 10 levels, one entry per climate (the nearest tier).
	var best := {}
	for id in islands:
		var d: Dictionary = islands[id]
		if str(d.get("kind", "")) != "unstable" or bool(d.get("generated", false)):
			continue
		var gap := absi(int(d.get("tier", 0)) - tier)
		if gap > 10:
			continue
		var cl := str(d.get("climate", ""))
		if not best.has(cl) or gap < int((best[cl] as Array)[1]):
			best[cl] = [str(id), gap]
	if best.is_empty():
		return ""
	var climates := best.keys()
	climates.sort()
	var climate := str(climates[rng.randi_range(0, climates.size() - 1)])
	var picks: Variant = IslandShape.fam_root().get("roster_pick", ["classic"])
	var fams: Array = picks if picks is Array and not (picks as Array).is_empty() else ["classic"]
	var size_r: Array = r.get("size_share", [0.9, 1.0])
	drift_count += 1
	drift = {
		"id": "drift_%d" % drift_count,
		"n": drift_count,
		"seed": absi(hash("%d|drift" % p_seed)) % 2000000000,
		"tier": tier,
		"climate": climate,
		"template": str((best[climate] as Array)[0]),
		"family": str(fams[rng.randi_range(0, fams.size() - 1)]),
		"size_m": roundi(float((islands[str((best[climate] as Array)[0])] as Dictionary).get("size_m", 368)) * rng.randf_range(float(size_r[0]), float(size_r[1]))),
		"offer_left": float(r.get("offer_window_s", 1200)),
	}
	_install_drift()
	print("[world] unstable isle %s rolled tier=%d climate=%s family=%s" % [drift["id"], tier, climate, drift["family"]])
	drift_offered.emit(StringName(str(drift["id"])))
	return str(drift["id"])

const _ROMAN := ["I", "II", "III", "IV", "V", "VI", "VII", "VIII", "IX", "X"]

## The isle's catalogue row: its template's row (spawns, guardians, weather) with the rolled seed,
## tier, climate, shape and size, and no fixed harbour (the dock goes on the southern-most coast).
func _install_drift() -> void:
	var id := str(drift.get("id", ""))
	var base: Dictionary = (islands.get(str(drift.get("template", "")), {}) as Dictionary).duplicate(true)
	for k in ["harbour", "camp", "_harbour_note", "map", "map_doc", "lifetime_seconds", "lifetime_hours", "display_name"]:
		base.erase(k)
	var n := int(drift.get("n", 1))
	base["id"] = id
	base["kind"] = "unstable"
	base["generated"] = true
	base["seed"] = int(drift["seed"])
	base["tier"] = int(drift["tier"])
	base["climate"] = str(drift["climate"])
	base["shape_family"] = str(drift["family"])
	base["size_m"] = int(drift["size_m"])
	base["display_name"] = "%s Drift %s" % [str(drift["climate"]).replace("_", " ").capitalize(), _ROMAN[(n - 1) % _ROMAN.size()] if n <= _ROMAN.size() else str(n)]
	if not base.has("sail_cost"):
		base["sail_cost"] = 5
	islands[id] = base

## The board: a new isle rolls once the cooldown is over (and the survivor has the first sail gate);
## an offer nobody sailed expires; a landed isle's clock is its expeditions row (tick_expeditions).
func tick_drifts(delta: float) -> void:
	var r := drift_rules()
	if r.is_empty():
		return
	if drift.is_empty():
		drift_cooldown = maxf(0.0, drift_cooldown - delta)
		if drift_cooldown > 0.0:
			return
		var p := _player()
		if p == null or p.skills == null or is_tutorial():
			return
		var surv := int(p.skills.level_of("survival"))
		if surv < int(r.get("min_survival", 10)):
			return
		if roll_drift(randi(), surv) != "":
			p.notice("An unstable isle surfaced: %s. Sail from the harbour within %d minutes." % [
				str(def_of(StringName(str(drift["id"]))).get("display_name", "")), int(float(drift["offer_left"]) / 60.0)])
		return
	if drift_landed():
		return
	drift["offer_left"] = maxf(0.0, float(drift.get("offer_left", 0.0)) - delta)
	if float(drift["offer_left"]) <= 0.0:
		print("[world] unstable isle %s left the board" % drift.get("id", ""))
		_erase_drift(str(drift.get("id", "")))

func _build_runtime(host: Node, terrain: StringName) -> Node:
	var ir = (load("res://scripts/world/island_runtime.gd") as GDScript).new()
	ir.name = "IslandRuntime"
	host.add_child(ir)
	ir.build(island_def, terrain)
	return ir

## A built isle with its Rift Pool and at least its budget's minimum of (reachable) landmarks.
func _drift_valid(ir: Node) -> bool:
	var sites: Array = ir.get("landmarks")
	var rift := false
	for s in sites:
		if str((s as Dictionary).get("type", "")) == "rift":
			rift = true
	return rift and sites.size() >= IslandLandmarks.budget_for(island_def).x

func _erase_drift(id: String) -> void:
	islands.erase(id)
	expeditions.erase(id)
	landmarks_found.erase(id)
	landmark_state.erase(id)
	map_fogs.erase(id)
	visited_islands.erase(id)
	drift = {}
	drift_cooldown = float(drift_rules().get("offer_every_s", 1800))

## The isle sinks for good (doc section 5): a survivor on it is pulled to the home harbour with the bag
## as it is (carried goods keep their unstable flag); placed kits and their storage go down with it;
## every trace of the isle (row, clock, landmarks, fog, harvest) is deleted.
func sink_drift(id: String) -> void:
	var on := str(island_id) == id and runtime != null and is_instance_valid(runtime)
	print("[world] unstable isle %s sank on=%s" % [id, str(on)])
	_erase_drift(id)
	if on:
		var host := runtime.get_parent()
		_clear_runtime()
		harvested = {}
		map_fog = null
		unstable_claims = []
		away_domain = {}
		remaining_lifetime = 0.0
		var player := _player()
		load_island(host, &"home_grassland", Vector3.ZERO, false)
		if player and runtime and runtime.has_method("arrival_point"):
			player.global_position = runtime.arrival_point() + Vector3.UP
		(load("res://scripts/core/save_game.gd") as GDScript)._restore_buildings(_home_buildings_cache, SaveMigrations.CURRENT_SCHEMA)
		if player:
			player.notice("The isle sank beneath you. The tide carried you home with your bag.")
	drift_sunk.emit(StringName(id))

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
	Tasks.note(&"crater")  # FACTIONS: crater survey missions (the island's landmark)
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
		# Only touched nodes: a missing row loads as a fresh node, and fourteen islands of full rows
		# would bloat the save.
		if node.session_gathered <= 0 and node.pool >= float(node.pool_max) and not node.depleted and node.regen_left() <= 0.0 and _pools_full(node):
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
	if is_unstable():
		expedition_row(str(island_id), true)["harvested"] = harvested.duplicate(true)

func _pools_full(node: HarvestNode) -> bool:
	for item in node.pools:
		if float(node.pools[item]) < float(node.pool_maxes.get(item, node.pool_max)):
			return false
	return true

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

## LOADING: every World transition runs under the loading overlay (it replaced the black fade).
func _fade_to(cb: Callable, title: String = "Loading") -> void:
	await LoadingScreen.run(title, cb)

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
