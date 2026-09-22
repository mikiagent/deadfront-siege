extends Node3D
## Pet respawn cooldown acceptance: a dead pet shows the circular countdown ring in the PETS
## sheet and cannot be summoned until the timer runs out.

var _player: Player
var _hud: HuntHud

func _ready() -> void:
	var kit := LabKit.build(self)
	_player = kit["player"]
	var ui: CanvasLayer = kit["ui"]
	for c in ui.get_children():
		if c is HuntHud:
			_hud = c
	print("[boot] lab=pets_lab")
	call_deferred("_demo")

func _demo() -> void:
	await get_tree().process_frame
	# Bond two raptors; one dies and goes on the respawn cooldown.
	var def := Data.creature(&"velociraptor")
	var alive := PetRecord.from_def(def, &"A")
	var down := PetRecord.from_def(def, &"B")
	_player.bonded.append(alive)
	_player.bonded.append(down)
	down.start_respawn()
	# Functional: summoning the downed pet is blocked, the other works.
	_player.summon_pet(0)
	var out_before := _player.live_pets().size()
	_player.summon_pet(1)
	var blocked := _player.live_pets().size() == out_before
	print("[petslab] summon blocked while down: %s" % ("yes" if blocked else "NO"))
	# Save round trip preserves the remaining cooldown.
	var copy := PetRecord.from_dict(down.to_dict())
	print("[petslab] save round trip: %s" % ("yes" if copy.respawning() and is_equal_approx(copy.respawn_left, down.respawn_left) else "NO"))
	# Timer ticks down and releases.
	down.tick_respawn(PetRecord.RESPAWN_TIME)
	print("[petslab] respawning after full tick: %s" % ("yes" if down.respawning() else "no"))
	# Re-arm for the visual: mid-countdown ring in the open sheet.
	down.respawn_left = PetRecord.RESPAWN_TIME * 0.6
	_hud._toggle_sheet(&"pets")
	await get_tree().process_frame
	await get_tree().process_frame
	var ring := _find_ring(_hud)
	print("[petslab] ring in sheet: %s text_secs=%.0f" % ["yes" if ring != null else "NO", down.respawn_left])
	# Finish the countdown while the sheet is open: it rebuilds with Summon back.
	down.respawn_left = 0.0
	await get_tree().process_frame
	await get_tree().process_frame
	var ring2 := _find_ring(_hud)
	var has_summon := false
	if _hud._sheet:
		for b in _hud._sheet.find_children("*", "Button", true, false):
			if (b as Button).text.begins_with("Summon"):
				has_summon = true
	print("[petslab] sheet rebuilt without ring: %s summon-back: %s" % ["yes" if ring2 == null else "NO", "yes" if has_summon else "NO"])
	# Re-arm a fresh countdown for the screenshot, then reopen.
	down.respawn_left = PetRecord.RESPAWN_TIME * 0.6
	_hud._refresh_sheet()
	await get_tree().process_frame
	await get_tree().process_frame
	if DisplayServer.get_name() == "headless":
		get_tree().quit(0 if blocked and has_summon else 1)
	# headed --shot run: Game autoload takes the screenshot after its delay.

func _find_ring(root: Node) -> RespawnRing:
	if root is RespawnRing:
		return root
	for c in root.get_children():
		var r := _find_ring(c)
		if r:
			return r
	return null
