extends Node3D
## Manual listen for the audio layer: plays every event category in turn (UI, survivor,
## gathering, combat, each species' voice set, ambience beds, music moods) and prints a
## coverage table. Run: godot --path game -- --lab=audio_lab
## Headless coverage only: add --audio-lab-fast (no waits, exit code 1 on any missing file).

const CATEGORIES := [
	["ui", ["ui_"]],
	["survivor", ["step_", "survivor_"]],
	["gathering", ["gather_", "node_depleted_"]],
	["combat", ["swing_", "impact_", "armour_", "proj_", "knockdown_", "body_fall_", "creature_step_"]],
	["creatures", ["cv_"]],
	["ambience", ["amb_", "thunder"]],
	["music", ["music_"]],
]

var _fast: bool = false
var _audio: AudioDirector

func _ready() -> void:
	_fast = "--audio-lab-fast" in OS.get_cmdline_user_args()
	var cam := Camera3D.new()
	cam.position = Vector3(0, 1.6, 6)
	add_child(cam)
	cam.make_current()
	_audio = Game.audio
	_audio.beds.manual = true
	if "--audio-lab-settings" in OS.get_cmdline_user_args():
		# Visual check of the sound sheet: godot --path game -- --lab=audio_lab --audio-lab-settings --shot=x.png
		call_deferred("_show_settings")
		return
	call_deferred("_run")

func _show_settings() -> void:
	_audio.beds.preview(&"bed", &"amb_grassland_day", 0.4, 1.0)
	_audio.open_settings()
	await get_tree().process_frame
	await get_tree().process_frame
	print("[audio_lab] sound sheet open")

func _category(event: String) -> String:
	for row in CATEGORIES:
		for prefix in row[1]:
			if event.begins_with(prefix):
				return row[0]
	return "other"

func _wait(seconds: float) -> void:
	if not _fast:
		await get_tree().create_timer(seconds).timeout

func _run() -> void:
	var ev: Dictionary = _audio.events
	var front := Vector3(0, 1, 2)
	for row in CATEGORIES:
		var cat: String = row[0]
		print("[audio_lab] -- %s" % cat)
		var names: Array = ev.keys().filter(func (n: String) -> bool: return _category(n) == cat)
		names.sort()
		for n in names:
			var e: Dictionary = ev[n]
			if bool(e.get("loop", false)):
				var slot := &"music" if cat == "music" else &"bed"
				if e.get("mode", "2d") == "3d":
					continue  # fire loops attach to campfires, heard in game
				print("[audio_lab] loop %s" % n)
				_audio.beds.preview(slot, StringName(n), 1.0, 0.4)
				await _wait(6.0 if cat == "music" else 4.0)
				_audio.beds.preview(slot, &"", 0.0, 0.4)
				_audio.played_count[n] = int(_audio.played_count.get(n, 0)) + 1
				continue
			if cat == "music":
				print("[audio_lab] track %s" % n)
				_audio.beds.preview(&"music", StringName(n), 1.0, 0.5)
				await _wait(8.0)
				_audio.beds.preview(&"music", &"", 0.0, 0.5)
				_audio.played_count[n] = int(_audio.played_count.get(n, 0)) + 1
				continue
			var at := Vector3.INF if e.get("mode", "2d") == "2d" else front + Vector3(randf_range(-2, 2), 0, 0)
			_audio._last_play.erase(StringName(n))  # labs replay faster than event cooldowns
			_audio.play(StringName(n), at)
			if _fast:
				_audio.played_count[n] = maxi(1, int(_audio.played_count.get(n, 0)))
			await _wait(1.6 if cat == "creatures" else 0.7)
	_print_table()

func _print_table() -> void:
	var ev: Dictionary = _audio.events
	var missing_total := 0
	print("[audio_lab] %-10s %7s %6s %8s %7s" % ["category", "events", "files", "missing", "played"])
	for row in CATEGORIES + [["other", []]]:
		var cat: String = row[0]
		var n_ev := 0
		var n_files := 0
		var missing := 0
		var played := 0
		for n in ev:
			if _category(n) != cat:
				continue
			n_ev += 1
			for f in (ev[n] as Dictionary).get("files", []):
				n_files += 1
				if not ResourceLoader.exists(AudioDirector.AUDIO_ROOT + str(f)):
					missing += 1
					print("[audio_lab] MISSING %s -> %s" % [n, f])
			if int(_audio.played_count.get(n, 0)) > 0:
				played += 1
		missing_total += missing
		if n_ev > 0:
			print("[audio_lab] %-10s %7d %6d %8d %7d" % [cat, n_ev, n_files, missing, played])
	var species: Dictionary = _audio.creature_voices.get("species", {})
	print("[audio_lab] %-15s %-12s %-8s %5s" % ["species", "set", "colour", "pitch"])
	for sp in species:
		var v: Dictionary = species[sp]
		print("[audio_lab] %-15s %-12s %-8s %5.2f" % [sp, v.get("set", ""), v.get("colour", ""), float(v.get("pitch", 1.0))])
	print("[audio_lab] %s coverage events=%d missing=%d" % ["PASS" if missing_total == 0 else "FAIL", ev.size(), missing_total])
	if _fast:
		for v in _audio._voices:
			_audio._stop(v)
		await get_tree().create_timer(0.5).timeout  # let the mixer drop stopped voices before exit
		get_tree().quit(0 if missing_total == 0 else 1)
