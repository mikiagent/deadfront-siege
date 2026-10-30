extends SceneTree
## FACTIONS acceptance (docs/design/factions.md): the five factions and their mission data; missions are
## tracked per faction from accept (Tasks category "faction"), unlock levels / min ranks / the 4-active cap
## / once-per-period gate accept; Receive pays reputation (Committee gold x1.8), crosses ranks and pays
## the rank unlock (support crate items, or SP for Radio University); deliveries take the items; the
## factions block and the active missions survive save -> load, an old save (no blocks) loads with no
## reputation; the Factions screen lists the five factions and accepts / receives with a ghost-fill bar.
## Shots with `-- --factionshots=<dir>` (windowed).
## Usage: godot --headless --path game --script res://tests/t_factions.gd -> "[t_factions] PASS", exit 0/1.

var _fails: Array[String] = []
var _started := false
var _host: Node3D
var _player
var _hud
var W: Node
var T: GDScript
var F: GDScript
var SG: GDScript
var IS: GDScript

func _process(_delta: float) -> bool:
	if _started:
		return false
	if root == null or root.get_node_or_null("Data") == null or root.get_node_or_null("World") == null:
		return false
	_started = true
	_run.call_deferred()
	return false

func _expect(ok: bool, what: String) -> void:
	if not ok:
		_fails.append(what)
	print("[t_factions] %s %s" % ["ok" if ok else "FAIL", what])

func _frames(n: int) -> void:
	for i in n:
		await process_frame

func _shot_dir() -> String:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--factionshots="):
			return a.trim_prefix("--factionshots=")
	return ""

func _run() -> void:
	W = root.get_node("World")
	T = load("res://scripts/core/tasks.gd")
	F = load("res://scripts/core/factions.gd")
	SG = load("res://scripts/core/save_game.gd")
	IS = load("res://scripts/items/item_stack.gd")
	_host = Node3D.new()
	_host.name = "TFactionHost"
	root.add_child(_host)
	var kit: Dictionary = load("res://scripts/dev/lab_kit.gd").build(_host, 4.0)
	_player = kit["player"]
	for c in (kit["ui"] as CanvasLayer).get_children():
		if c.has_method("open_comms"):
			_hud = c
	W.home_terrain = &"meadow"
	W.load_island(_host, &"home_grassland", Vector3(0, 1, 18), false)
	await _frames(2)
	_player.process_mode = Node.PROCESS_MODE_DISABLED
	T.clock_override = 1_700_000_000  # a Tuesday, 22:13 UTC
	T.reset()
	F.reset()
	_test_data()
	_test_tracking()
	_test_receive_and_ranks()
	_test_gates()
	await _test_screen()
	await _test_save()
	if _shot_dir() != "":
		await _shots(_shot_dir())
	T.clock_override = -1
	if _fails.is_empty():
		print("[t_factions] PASS")
		quit(0)
	else:
		print("[t_factions] FAIL count=%d" % _fails.size())
		quit(1)

func _row(key: String) -> Dictionary:
	return T.find(key, _player)

func _test_data() -> void:
	var ids: Array = F.ids()
	_expect(ids.size() == 5, "five factions (%s)" % [ids])
	var data: Node = root.get_node("Data")
	var recipes := {}
	for r in data.recipes:
		recipes[str(r)] = true
	var bad: Array = []
	for id in ids:
		var f: Dictionary = F.def(id)
		_expect(str(f.get("colour", "")) != "" and str(f.get("motto", "")) != "" and (f.get("titles", []) as Array).size() == 4, "%s has a colour, a motto and four tier titles" % id)
		_expect((f.get("missions", []) as Array).size() >= 5, "%s has at least five missions" % id)
		for m: Dictionary in f.get("missions", []):
			for what in (m["count"] if m["count"] is Array else [m["count"]]):
				var s := str(what)
				if s.begins_with("craft:") and not recipes.has(s.trim_prefix("craft:")):
					bad.append(s)
				if (s.begins_with("gather:") or s.begins_with("deliver:")) and data.item(StringName(s.get_slice(":", 1))) == null:
					bad.append(s)
		for band in (f.get("crate_bands", {}) as Dictionary).values():
			for it in band:
				if data.item(StringName(str(it))) == null:
					bad.append("crate " + str(it))
	_expect(bad.is_empty(), "every mission recipe, item and crate item exists (%s)" % [bad])
	_expect(F.rank_need(1) == 50 and F.rank_need(10) == 2750 and F.rank_of_points(149) == 1 and F.rank_of_points(150) == 2, "rank thresholds 25 n (n+1)")
	_expect(F.title("company") == "Stranger", "a newcomer is a Stranger")

func _test_tracking() -> void:
	_expect(T.accept("faction.company.herbs", _player) == "", "the Company's herb mission is accepted")
	_expect(T.accept("faction.chlorophyll_forum.bond", _player) == "", "the Forum's taming mission is accepted")
	T.note(&"gather:herb_leaf", 4)
	T.note(&"tame")
	var herbs := _row("faction.company.herbs")
	_expect(int(herbs["got"]) == 4 and not herbs["claimable"], "herbs count 4/6 from accept (%s/%s)" % [herbs["got"], herbs["want"]])
	_expect(_row("faction.chlorophyll_forum.bond")["claimable"], "the tame completes the Forum's mission, not the Company's")
	T.note(&"gather:berries", 3)
	_expect(int(_row("faction.company.herbs")["got"]) == 4, "berries do not count for herbs")
	T.note(&"gather:herb_leaf", 2)
	_expect(_row("faction.company.herbs")["claimable"], "6/6 herbs: Receive is offered")
	_expect(T.claimable_count(_player) >= 2 and T.claimable_count(_player, &"faction") == 2, "the Tasks badge counts the faction missions waiting")
	# Counting starts at accept: a fresh accept of fuel ignores earlier gathers.
	T.note(&"gather:branch", 5)
	T.accept("faction.company.fuel", _player)
	_expect(int(_row("faction.company.fuel")["got"]) == 0, "progress counts from accept, not before")

func _test_receive_and_ranks() -> void:
	var bag_before: int = _player.inventory.count_of(&"bandage")
	var gold: int = W.t_stones
	var r: Dictionary = T.claim("faction.company.herbs", _player)
	_expect(not r.is_empty() and F.points("company") == 50 and F.rank("company") == 1, "Receive pays 50 reputation: rank 1 (%d)" % F.points("company"))
	_expect(W.t_stones == gold + 6, "and its gold")
	_expect(r.get("ranks", []) == [1] and F.title("company") == "Walk-and-Talker", "rank 1 = the tier 1 title Walk-and-Talker")
	_expect(_player.inventory.count_of(&"bandage") == bag_before + 1 and _player.inventory.count_of(&"twine") >= 1, "rank 1 pays the support crate (bandage, twine, berries)")
	_expect(_row("faction.company.herbs").is_empty() and not T.active.has("faction.company.herbs"), "a received mission leaves the active list")
	_expect(T.claim("faction.company.herbs", _player).is_empty(), "and never pays twice")
	# Delivery: rank 1 opens Bandages for Newcomers; Receive takes the bandages.
	_expect(T.accept("faction.company.bandages", _player) == "", "rank 1 opens the bandage delivery")
	_player.inventory.add(IS.make(&"bandage", 3))
	var held: int = _player.inventory.count_of(&"bandage")
	_expect(_row("faction.company.bandages")["claimable"], "holding 3 bandages completes the delivery")
	T.claim("faction.company.bandages", _player)
	_expect(_player.inventory.count_of(&"bandage") == held - 3, "Receive takes the 3 bandages")
	# Radio University pays SP per rank (no crates).
	var sp0: int = _player.skills.sp_extra
	F.add_rep("radio_university", 160, _player)
	_expect(F.rank("radio_university") == 2 and _player.skills.sp_extra == sp0 + 2, "two Radio University ranks pay 2 SP")
	# The Committee's high pay.
	T.active["faction.committee.hunt"] = {"base": 0, "at": "x"}
	_expect(int(_row("faction.committee.hunt")["rewards"]["t_stones"]) == 11, "Committee gold x1.8 (6 -> 11)")
	T.abandon("faction.committee.hunt")

func _test_gates() -> void:
	_expect(T.accept("faction.pioneer_council.ore", _player).begins_with("Unlocks at level"), "the Pioneer Council is locked below level 16")
	_expect(T.accept("faction.company.clothes", _player).begins_with("Needs rank"), "a rank 4 mission is refused at rank 1")
	_expect(T.accept("faction.company.herbs", _player) != "", "a daily mission cannot be taken twice in a day")
	T.active.clear()
	for k in ["faction.company.meals", "faction.chlorophyll_forum.berries", "faction.chlorophyll_forum.seeds", "faction.chlorophyll_forum.crater"]:
		T.accept(k, _player)
	_expect(T.active.size() == 4 and T.accept("faction.company.fish", _player).ends_with("(the most)"), "at most 4 active missions (PRD)")
	_expect(T.offers("company", _player).size() <= 3, "a board offers at most 3 missions")
	T.clock_override += 86400
	_expect(T.accept_block("faction.company.herbs", _player) == "" or T.accept_block("faction.company.herbs", _player).ends_with("(the most)"), "the next UTC day reopens the daily mission")
	T.clock_override -= 86400
	T.roll()

func _test_screen() -> void:
	T.active.clear()
	T.taken.clear()
	var comms: Node = _hud.call("open_comms", "company")
	await _frames(3)
	_expect(comms != null and comms.call("is_open") and comms.get("selected") == "company", "a board opens the Factions screen on its faction")
	_expect(comms.find_children("Faction_*", "Button", true, false).size() == 5, "the Factions screen lists five factions")
	var acc: Array = comms.find_children("Accept", "Button", true, false).filter(func (b: Node) -> bool: return not (b as Button).disabled)
	_expect(not acc.is_empty(), "the Company's offers have live Accept buttons")
	for b in comms.find_children("*", "Button", true, false):
		if (b as Button).is_visible_in_tree() and (b as Button).size.y < 63.5 and str(b.name) in ["Accept", "Receive", "Abandon"]:
			_expect(false, "%s is a 64 px tap target (%s)" % [b.name, (b as Button).size])
	(acc[0] as Button).pressed.emit()
	await _frames(2)
	_expect(T.active.size() == 1, "Accept on screen starts the mission")
	var key: String = T.active.keys()[0]
	var m: Dictionary = T.mission_def(key)
	var what: Variant = m["count"]
	if str(what if what is String else what[0]).begins_with("deliver:"):
		_player.inventory.add(IS.make(StringName(str(what).get_slice(":", 1)), int(m["want"])))
	else:
		T.note(StringName(str(what if what is String else what[0])), int(m["want"]))
	comms.call("select", "company")
	await _frames(2)
	var rec: Button = comms.find_child("Receive", true, false)
	_expect(rec != null, "a complete mission shows Receive")
	if rec:
		var p0: int = F.points("company")
		rec.pressed.emit()
		await _frames(2)
		var bar = comms.find_child("Faction_company", true, false).find_child("Bar", true, false)
		_expect(F.points("company") > p0 and float(bar.get("target")) > float(bar.get("shown")), "Receive raises reputation and the bar leads with its ghost fill (%.2f > %.2f)" % [bar.get("target"), bar.get("shown")])
		await create_timer(2.5).timeout
		_expect(absf(float(bar.get("target")) - float(bar.get("shown"))) < 0.01, "the real fill catches up with the ghost")
	(comms.get("close_btn") as Button).pressed.emit()

func _test_save() -> void:
	T.active.clear()
	T.taken.clear()
	T.accept("faction.chlorophyll_forum.berries", _player)
	T.note(&"gather:berries", 2)
	var rep_before: Dictionary = F.to_dict()
	_expect(SG.save_now(), "the game saves")
	var raw: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(SG.path))
	_expect(raw.has("factions") and (raw["tasks"] as Dictionary).has("active"), "the save carries the factions block and the active missions")
	F.reset()
	T.reset()
	SG.load_now(_host)
	await _frames(2)
	_expect(F.to_dict() == rep_before, "reputation survives save -> load (%s)" % [F.to_dict()])
	_expect(int(_row("faction.chlorophyll_forum.berries").get("got", -1)) == 2, "an active mission and its progress survive save -> load")
	# An old save has no factions block and no active missions.
	F.from_dict(null)
	T.from_dict({"claimed": {}, "done": {}, "counts": {}, "day": 1, "week": 1})
	_expect(F.rep.is_empty() and T.active.is_empty() and F.rank("company") == 0, "an old save loads with no reputation and no faction missions")
	F.from_dict({"rep": {"company": "junk", "nobody": 50, "committee": 75}})
	_expect(F.points("company") == 0 and not F.rep.has("nobody") and F.points("committee") == 75, "a forged block loads only known factions with numbers")
	T.from_dict({"claimed": {}, "active": {"faction.nobody.x": {"base": 1}, "faction.company.herbs": {"base": "x"}}})
	_expect(T.active.is_empty(), "forged active missions are dropped")

func _shots(dir: String) -> void:
	DirAccess.make_dir_recursive_absolute(dir)
	T.reset()
	F.reset()
	F.add_rep("company", 120, _player)
	F.add_rep("chlorophyll_forum", 40, _player)
	T.accept("faction.company.fuel", _player)
	T.accept("faction.chlorophyll_forum.berries", _player)
	T.note(&"gather:berries", 8)
	for view in [Vector2i(1600, 900), Vector2i(844, 390)]:
		root.size = view
		root.content_scale_size = view
		await _frames(3)
		var comms: Node = _hud.call("open_comms", "company")
		await _frames(4)
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(dir.path_join("factions_screen_%dx%d.png" % [view.x, view.y]))
		comms.call("select", "chlorophyll_forum")
		await _frames(3)
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(dir.path_join("factions_forum_%dx%d.png" % [view.x, view.y]))
		(comms.get("close_btn") as Button).pressed.emit()
	print("[t_factions] shots in %s" % dir)
