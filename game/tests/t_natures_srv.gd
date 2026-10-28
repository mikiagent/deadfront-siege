extends SceneTree
## NATURES server round trip: the character store (srvdom) keeps a pet's nature across a snapshot,
## a journal replay and a read-back, and the tame intent rolls/keeps it through the same rules as
## the local game (natures.json: a Docile animal needs one preferred feed, a Stubborn one more).
## Run: Godot --headless --path game --script res://tests/t_natures_srv.gd -> "[t_natures_srv] PASS".
## Scripts are load()ed on the first frame: `--script` compiles this file before the autoloads exist.

var _fails: PackedStringArray = []
var _started := false

func _process(_delta: float) -> bool:
	if _started or root.get_node_or_null("Data") == null:
		return false
	_started = true
	_run()
	return false

func _expect(ok: bool, what: String) -> void:
	if not ok:
		_fails.append(what)
		print("[t_natures_srv] FAIL %s" % what)

func _world() -> Variant:
	var w: Variant = load("res://scripts/server/world_facade.gd").new()
	w.add_node("bush", Vector3(-1.5, 0, 0), [
		{"item": "berry", "tool": "none", "min": 1, "max": 2, "left": 400},
	], 1, "bush")
	# Two grazers side by side: one Docile, one Stubborn (the nature rides on the island row).
	w.add_creature("docile1", "protoceratops", Vector3(1, 0, 1), 90.0, {"nature": "docile", "knocked": true})
	w.add_creature("stub1", "protoceratops", Vector3(2, 0, 1), 90.0, {"nature": "stubborn", "knocked": true})
	w.add_creature("plain1", "protoceratops", Vector3(1, 0, 2), 90.0, {"knocked": true})
	return w

func _feed(st: Variant, acct: int, net_id: String, tries: int = 6) -> int:
	var feeds := 0
	for i in tries:
		var res: Dictionary = st.apply("act.tame", acct, {"net_id": net_id, "food": "berry"}, 3 + i)
		if not bool(res.get("ok", false)):
			break
		feeds += 1
		if res.has("pet_uid"):
			break
	return feeds

func _run() -> void:
	var Store: GDScript = load("res://scripts/server/character_store.gd")
	var st: Variant = Store.new(_world(), "", 31)
	for acct in [1]:
		_expect(bool(st.apply("char.create", acct, {"name": "Tess%d" % acct}, 1).get("ok", false)), "char.create %d" % acct)
	for i in 4:
		st.apply("act.gather", 1, {"node_id": "bush", "option": 0}, 2)
	var docile_feeds := _feed(st, 1, "docile1")
	var stubborn_feeds := _feed(st, 1, "stub1")
	var plain_feeds := _feed(st, 1, "plain1")
	print("[t_natures_srv] feeds: docile=%d plain=%d stubborn=%d" % [docile_feeds, plain_feeds, stubborn_feeds])
	_expect(stubborn_feeds > plain_feeds, "a Stubborn animal tamed in %d feeds, a plain one in %d" % [stubborn_feeds, plain_feeds])
	var pets: Dictionary = st.character(1).d.pets
	_expect(pets.size() == 3, "three tames bonded %d pets" % pets.size())
	var natures := {}
	for uid: String in pets:
		var row: Dictionary = pets[uid]
		natures[str(row.get("nature", ""))] = natures.get(str(row.get("nature", "")), 0) + 1
		_expect(CreatureNatures.is_valid(StringName(str(row.get("nature", "")))), "pet %s has nature '%s'" % [uid, row.get("nature", "")])
	print("[t_natures_srv] pet natures: %s" % [natures])
	_expect(int(natures.get("docile", 0)) == 1 and int(natures.get("stubborn", 0)) == 1, "the Docile and Stubborn animals did not keep their natures: %s" % [natures])
	# Round trip: the same store replayed from its journal and booted from its snapshot (user://).
	var live: String = st.state_json()
	var replayed: Variant = Store.new(_world(), "", 31)
	for line in st.lines:
		replayed.replay_line(line)
	var replay_ok: bool = replayed.state_json() == live
	_expect(replay_ok, "the journal replay does not reproduce the pets' natures")
	var dir := "user://t_natures_srv_store"
	_clear(dir)
	var disk: Variant = Store.new(_world(), dir, 31)
	_expect(disk.open() == "", "the store directory opens")
	for acct in [1]:
		disk.apply("char.create", acct, {"name": "Tess%d" % acct}, 1)
	for i in 4:
		disk.apply("act.gather", 1, {"node_id": "bush", "option": 0}, 2)
	_feed(disk, 1, "docile1")
	disk._close_journal()  # a crash: boot replays the journal
	var booted: Variant = Store.new(_world(), dir, 31)
	var why: String = booted.open()
	var back: Dictionary = booted.character(1).d.pets
	var kept: String = str((back.values()[0] as Dictionary).get("nature", "")) if not back.is_empty() else ""
	print("[t_natures_srv] disk: %s, pet nature '%s'" % [why if why != "" else "reopened", kept])
	_expect(why == "" and kept == "docile", "a rebooted store reads back the Docile nature (got '%s', %s)" % [kept, why])
	booted.close()
	_clear(dir)
	if _fails.is_empty():
		print("[t_natures_srv] PASS")
		quit(0)
	else:
		print("[t_natures_srv] FAIL count=%d" % _fails.size())
		quit(1)

func _clear(dir: String) -> void:
	var d := DirAccess.open(dir)
	if d == null:
		return
	for f in d.get_files():
		DirAccess.remove_absolute(dir.path_join(f))
