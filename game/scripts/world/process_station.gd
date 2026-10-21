class_name ProcessStation
extends Node3D
## Process jobs on a placed station (drying rack, smoker, crock pot, steamer; processing.json).
## Inputs leave the bag and sit on the station; a job finishes on the wall clock (now_s), so it
## keeps running with the player 50 m away, on another island or with the game closed. Outputs wait
## on the station until collected. State is only timestamps: no ticking is needed for correctness,
## _process just advances and redraws (stage model, contents, smoke/steam, glow; ProcessFx). The status
## text (label_text) replaces the station's name on its HUD chip (HudPills) while anything is on it.

const NODE_NAME := "Process"
const REDRAW_S := 0.25
const RULES_PATH := "res://data/processing.json"

static var _rules: Dictionary = {}
## Added to the wall clock: labs and tests fast-forward station jobs with it.
static var clock_skew_s: float = 0.0

var station_id: StringName = &""
var cfg: Dictionary = {}
## In order: {recipe, inputs: Array[ItemStack], queued_at, started (-1 = waiting), level, burnt, by}.
var jobs: Array[Dictionary] = []
## Finished, waiting to be collected: {recipe, stack: ItemStack}.
var outputs: Array[Dictionary] = []
## What the last collect_into moved, per item id (the COLLECT toast).
var last_collected: Dictionary = {}

var _redraw_left: float = 0.0
var _shown_stage: String = "?"
var _models: Dictionary = {}  # stage id -> PackedScene
var _fx: CPUParticles3D
var _glow: OmniLight3D
var _contents: Node3D

## The clock jobs run on: wall time, so they keep going while the game is closed.
static func now_s() -> float:
	return Time.get_unix_time_from_system() + clock_skew_s

## processing.json, parsed once.
static func rules() -> Dictionary:
	if _rules.is_empty() and FileAccess.file_exists(RULES_PATH):
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(RULES_PATH))
		if parsed is Dictionary:
			_rules = parsed as Dictionary
	return _rules

static func config_for(sid: StringName) -> Dictionary:
	var st: Variant = (rules().get("stations", {}) as Dictionary).get(str(sid), {})
	return st if st is Dictionary else {}

## Seconds a job of this recipe takes on this station; 0 = the station does not run it.
static func job_seconds(sid: StringName, rid: StringName) -> float:
	var row: Variant = (config_for(sid).get("recipes", {}) as Dictionary).get(str(rid), {})
	return maxf(0.0, float((row as Dictionary).get("seconds", 0.0))) if row is Dictionary else 0.0

static func of(n: Node) -> ProcessStation:
	return n.get_node_or_null(NODE_NAME) as ProcessStation if n else null

## Called by CraftStation._ready: kinds with a processing.json row get a ProcessStation child, and
## `saved` ones too (a save with jobs on a kind the rules dropped: load_dict makes them outputs).
static func attach_to(host: Node3D, sid: StringName, saved: bool = false) -> ProcessStation:
	var existing := of(host)
	if existing:
		return existing
	var c := config_for(sid)
	if c.is_empty() and not saved:
		return null
	var ps := ProcessStation.new()
	ps.name = NODE_NAME
	ps.station_id = sid
	ps.cfg = c
	host.add_child(ps)
	return ps

func _ready() -> void:
	if cfg.is_empty():
		cfg = config_for(station_id)
	_fx = ProcessFx.build_smoke(cfg)
	_glow = ProcessFx.build_glow(cfg)
	_contents = Node3D.new()
	_contents.name = "Contents"
	for n: Node3D in [_fx, _glow, _contents]:
		if n:
			add_child(n)
	advance(now_s())
	_redraw()

func slots() -> int:
	return maxi(1, int(cfg.get("slots", 1)))

func capacity() -> int:
	return slots() + maxi(0, int(cfg.get("queue", 0)))

func running_count() -> int:
	var n := 0
	for j in jobs:
		if float(j["started"]) >= 0.0:
			n += 1
	return n

func runs(rid: StringName) -> bool:
	return job_seconds(station_id, rid) > 0.0

func is_active() -> bool:
	return running_count() > 0

func waiting_count() -> int:
	return jobs.size() - running_count()

## 0..1 for a job, by the station clock.
func job_progress(j: Dictionary, now: float = -1.0) -> float:
	var t := now_s() if now < 0.0 else now
	if float(j["started"]) < 0.0:
		return 0.0
	return clampf((t - float(j["started"])) / maxf(0.1, job_seconds(station_id, StringName(str(j["recipe"])))), 0.0, 1.0)

## Why `inv` cannot load one `rid` now, or "" when it can. `picks` (bag index per recipe slot) are
## the instances to use; empty = the default picks.
func refuse_reason(inv: Inventory, rid: StringName, player: Player = null, picks: Array[int] = []) -> String:
	var rec := Crafting.recipe(rid)
	if rec.is_empty() or not runs(rid) or Crafting.station_id(rec) != str(station_id):
		return "%s does not run %s" % [str(cfg.get("label", station_id)), rid]
	if jobs.size() >= capacity():
		return "The %s is full." % str(station_id).replace("_", " ")
	if player and Crafting.progression_block(player, rec) != "":
		return Crafting.progression_block(player, rec)
	var use := picks if not picks.is_empty() else Crafting.default_picks(inv, rec)
	if not Crafting.picks_valid(inv, rec, use):
		var missing := Crafting.missing_ingredient_name(inv, rec)
		if missing != "":
			return "Needs %s." % missing
		var pi := Crafting.primary_index(rec)
		var lead := use[pi] if pi < use.size() else -1
		var spent := lead >= 0 and lead < inv.slot_count and inv.slots[lead] != null and Crafting.processing_left(rec, inv.slots[lead]) == 0
		return "No processing left on that one." if spent else "That one is no longer in your bag."
	return ""

## Load up to `count` jobs of `rid` from the bag. Inputs leave the bag now; returns jobs loaded.
## The first job takes exactly `picks`, the instances the craft card showed, or nothing: spec 08:98
## "a multi-material recipe consumes specific instance IDs atomically", so no substitute. Queued
## repeats take the default picks.
func load_from(inv: Inventory, rid: StringName, count: int = 1, player: Player = null, rng: RandomNumberGenerator = null, picks: Array[int] = []) -> int:
	var rec := Crafting.recipe(rid)
	var loaded := 0
	var now := now_s()
	advance(now)
	var use := picks
	while loaded < count and refuse_reason(inv, rid, player, use) == "":
		if use.is_empty():
			use = Crafting.default_picks(inv, rec)
		var levels := Crafting.consumed_levels(inv, rec, use)
		var inputs := Crafting.consume_for_craft(inv, rec, use)
		use = []
		if inputs.is_empty():
			break
		jobs.append({
			"recipe": str(rid),
			"inputs": inputs,
			"queued_at": now,
			"started": now if running_count() < slots() else -1.0,
			"level": Crafting.crafted_level_for(rec, levels, player),
			"burnt": Crafting.rolls_burn(rec, Crafting.skill_level_for(rec, player), rng),
			"by": World.player_name if player else "",
		})
		loaded += 1
	if loaded > 0:
		print("[process] %s loaded %d x %s (%d/%d) %.0fs each" % [station_id, loaded, rid, jobs.size(), capacity(), job_seconds(station_id, rid)])
		_redraw()
	return loaded

## Finish every job due by `now`, in time order; a freed slot starts the next waiting job at the
## moment it freed (not at the next frame), so offline catch-up matches a watched run.
func advance(now: float) -> bool:
	var did := false
	while true:
		var fi := -1
		var fend := INF
		for i in jobs.size():
			var st := float(jobs[i]["started"])
			if st < 0.0:
				continue
			var e := st + job_seconds(station_id, StringName(str(jobs[i]["recipe"])))
			if e <= now and e < fend:
				fi = i
				fend = e
		if fi < 0:
			break
		_finish(fi)
		did = true
		for j in jobs:
			if float(j["started"]) < 0.0:
				j["started"] = maxf(float(j["queued_at"]), fend)
				break
	return did

func _finish(i: int) -> void:
	var j: Dictionary = jobs[i]
	jobs.remove_at(i)
	var rec := Crafting.recipe(StringName(str(j["recipe"])))
	var inputs: Array = j["inputs"]
	var consumed: Array[ItemStack] = []
	for s in inputs:
		consumed.append(s as ItemStack)
	var out := Crafting.build_output(rec, consumed[0], int(j["level"]), consumed, bool(j.get("burnt", false)))
	if not out.is_fungible() and out.uid == "":  # in-place output keeps its identity
		out.stamp_identity("craft", str(j.get("by", "")))
	outputs.append({"recipe": str(j["recipe"]), "stack": out})
	print("[process] %s finished %s -> %s x%d lv%d" % [station_id, j["recipe"], out.def_id, out.count, out.level])

func ready_count() -> int:
	var n := 0
	for o in outputs:
		n += (o["stack"] as ItemStack).count
	return n

## Move finished outputs into `inv`; what does not fit stays on the station. XP is paid once, when
## a job's last unit leaves the station. Returns units moved; last_collected has them per item id.
func collect_into(inv: Inventory, player: Player = null) -> int:
	advance(now_s())
	var moved := 0
	last_collected = {}
	while not outputs.is_empty():
		var o: Dictionary = outputs[0]
		var s: ItemStack = o["stack"]
		var id := s.def_id
		var before := s.count
		var left := inv.add(s)
		moved += before - left
		if before > left:
			last_collected[id] = int(last_collected.get(id, 0)) + before - left
		if left > 0:
			s.count = left
			if player:
				player.notice("Bag is full: %d left on the %s." % [ready_count(), str(station_id).replace("_", " ")])
			break
		outputs.remove_at(0)
		if str(o["recipe"]) == "":
			continue  # an input handed back (its recipe left the station's rules): no craft, no XP
		var rec := Crafting.recipe(StringName(str(o["recipe"])))
		World.note_craft(StringName(str(o["recipe"])))
		if player:
			Crafting.grant_craft_xp(player, rec)
	if moved > 0:
		print("[process] %s collected %d" % [station_id, moved])
		_redraw()
	return moved

## Jobs still waiting for a slot hand their own inputs back, the same instances (spec 11:155
## cancellations; 08:39 a default pick may take the wrong food). All or nothing on the bag: returns the
## jobs taken back, 0 when none wait or the bag cannot take every unit.
func take_back_into(inv: Inventory, player: Player = null) -> int:
	advance(now_s())
	var back: Array[ItemStack] = []
	var keep: Array[Dictionary] = []
	for j in jobs:
		if float(j["started"]) >= 0.0:
			keep.append(j)
			continue
		for s in j["inputs"]:
			back.append(s as ItemStack)
	if back.is_empty():
		return 0
	if not BuildPlacer.fits_in_bag(inv, back):
		if player:
			player.notice("Bag is full: make room to take them back.")
		return 0
	for s in back:
		inv.add(s)
	var n := jobs.size() - keep.size()
	jobs = keep
	print("[process] %s took back %d waiting" % [station_id, n])
	_redraw()
	return n

## Everything on the station: inputs of unfinished jobs and finished outputs.
func contents() -> Array[ItemStack]:
	var out: Array[ItemStack] = []
	for j in jobs:
		for s in j["inputs"]:
			out.append(s as ItemStack)
	for o in outputs:
		out.append(o["stack"] as ItemStack)
	return out

## What a destroyed station held, handed over and cleared so no copy stays behind (spec 10:102 "A
## change in building state must not silently delete stored items"; 11:155 demolished stations).
func salvage_contents() -> Array[ItemStack]:
	var out := contents()
	jobs.clear()
	outputs.clear()
	_redraw()
	return out

## The stacks in a saved process dict (to_dict), for a row that is refunded instead of rebuilt.
static func saved_stacks(d: Dictionary) -> Array[ItemStack]:
	var seen := {}
	var out: Array[ItemStack] = []
	for j: Dictionary in _dicts(d.get("jobs")):
		out.append_array(_clean_stacks(j.get("inputs"), seen))
	for o: Dictionary in _dicts(d.get("outputs")):
		out.append_array(_clean_stacks([o.get("stack")], seen))
	return out

## The save file is user-editable and SaveSanitizer does not reach a row's process dict, so its stacks
## pass the same boundary here (known id, count within stack_max, level within MAX_LEVEL). A uid
## already seen on this station is a forged copy and is dropped.
static func _clean_stacks(rows: Variant, seen: Dictionary) -> Array[ItemStack]:
	var out: Array[ItemStack] = []
	if not rows is Array:
		return out
	for sd: Variant in SaveSanitizer.stacks(rows):
		if not sd is Dictionary:
			continue
		var s := ItemStack.from_dict(sd)
		if s.def() == null or s.count <= 0 or (s.uid != "" and seen.has(s.uid)):
			continue
		if s.uid != "":
			seen[s.uid] = true
		out.append(s)
	return out

static func _dicts(v: Variant) -> Array:
	return (v as Array).filter(func (r: Variant) -> bool: return r is Dictionary) if v is Array else []

## Why the station cannot be packed up now ("" = it can). BuildPlacer.pack_up_blocker asks this (via
## CraftStation) before it touches anything, on every pack-up path, so a refusal moves nothing and
## cancels no job, and packing up never destroys what hangs on the station.
func pack_up_block_reason() -> String:
	advance(now_s())
	var what := str(station_id).replace("_", " ")
	if not jobs.is_empty():
		return "the %s is still working: collect it when it is ready" % what
	if not outputs.is_empty():
		return "collect the %s first" % what
	return ""

func to_dict() -> Dictionary:
	var js: Array = []
	for j in jobs:
		var ins: Array = []
		for s in j["inputs"]:
			ins.append((s as ItemStack).to_dict())
		js.append({"recipe": j["recipe"], "inputs": ins, "queued_at": j["queued_at"], "started": j["started"],
			"level": j["level"], "burnt": j.get("burnt", false), "by": j.get("by", "")})
	var outs: Array = []
	for o in outputs:
		outs.append({"recipe": o["recipe"], "stack": (o["stack"] as ItemStack).to_dict()})
	return {"jobs": js, "outputs": outs}

## Restore saved jobs. Rows for recipes this station no longer runs are kept as finished outputs of
## their inputs (never deleted). Hand-edited numbers: a start in the future is clamped to now, one that
## is not a number leaves the job waiting (it restarts, never finishes early), level stays 1..60.
func load_dict(d: Dictionary) -> void:
	jobs.clear()
	outputs.clear()
	var now := now_s()
	var seen := {}
	for row: Dictionary in _dicts(d.get("jobs")):
		var ins := _clean_stacks(row.get("inputs"), seen)
		if ins.is_empty():
			continue
		var rid := StringName(str(row.get("recipe", "")))
		if not runs(rid) or Crafting.recipe(rid).is_empty():
			for s in ins:
				outputs.append({"recipe": "", "stack": s})
			continue
		var started := _num(row.get("started"), -1.0, now, -1.0)
		jobs.append({
			"recipe": str(rid),
			"inputs": ins,
			"queued_at": _num(row.get("queued_at"), 0.0, now, now),
			"started": started if started >= 0.0 else -1.0,
			"level": int(_num(row.get("level"), 1.0, float(SaveSanitizer.MAX_LEVEL), 1.0)),
			"burnt": row.get("burnt") is bool and bool(row["burnt"]),
			"by": str(row.get("by", "")),
		})
	for row: Dictionary in _dicts(d.get("outputs")):
		for s in _clean_stacks([row.get("stack")], seen):
			outputs.append({"recipe": str(row.get("recipe", "")), "stack": s})
	# Waiting jobs with a free slot (slots raised in config) start now.
	for j in jobs:
		if float(j["started"]) < 0.0 and running_count() < slots():
			j["started"] = now
	if is_inside_tree():
		advance(now)
		_redraw()

## A saved number within lo..hi; anything else (a string, an array, NaN) is the fallback.
static func _num(v: Variant, lo: float, hi: float, fallback: float) -> float:
	if not (v is int or v is float) or not is_finite(float(v)):
		return fallback
	return clampf(float(v), lo, hi)

# --- presentation ---

func _process(delta: float) -> void:
	_redraw_left -= delta
	if _redraw_left > 0.0:
		return
	_redraw_left = REDRAW_S
	advance(now_s())
	_redraw()

func stage_id() -> String:
	var stages: Array = cfg.get("stages", [])
	if stages.is_empty():
		return ""
	if is_active():
		var p := 1.0
		for j in jobs:
			if float(j["started"]) >= 0.0:
				p = minf(p, job_progress(j))
		var id := ""
		for st in stages:
			if p >= float((st as Dictionary).get("at", 0.0)):
				id = str((st as Dictionary).get("id", ""))
		return id
	return str(cfg.get("ready_stage", "")) if not outputs.is_empty() else str(cfg.get("idle_stage", ""))

func _redraw() -> void:
	if not is_inside_tree():
		return
	_swap_stage(stage_id())
	ProcessFx.show_strips(get_parent().get_node_or_null("Prop"), jobs.size() + outputs.size(), capacity())
	if _contents:
		ProcessFx.sync_contents(_contents, cfg, content_progress())
	var active := is_active()
	if _fx:
		_fx.emitting = active
	if _glow:
		_glow.visible = active

## 0..1 per thing on the station: finished outputs first (1), then jobs in order (waiting = 0).
func content_progress() -> Array[float]:
	var out: Array[float] = []
	for _o in outputs:
		out.append(1.0)
	var now := now_s()
	for j in jobs:
		out.append(job_progress(j, now))
	return out

## The station's HUD chip while anything is on it, one line so the chip keeps a name chip's height in a
## dense camp (two lines pushed chips onto the neighbour stations): "Drying 4/4 · 4:54",
## "2 ready · Drying 4:54", "Ready: 4 Dried Meat"; "" when empty (the chip shows the name).
func label_text() -> String:
	if is_active():
		var verb := str(cfg.get("label", "Working"))
		if not outputs.is_empty():
			return "%d ready · %s %s" % [ready_count(), verb, time_left_text()]
		return "%s %d/%d · %s" % [verb, jobs.size(), capacity(), time_left_text()]
	if not outputs.is_empty():
		var first: ItemStack = outputs[0]["stack"]
		var d := first.def()
		return "Ready: %d %s" % [ready_count(), d.display_name if d else str(first.def_id)]
	return ""

## m:ss until the soonest running job finishes ("" when none runs).
func time_left_text() -> String:
	var now := now_s()
	var soonest := INF
	for j in jobs:
		if float(j["started"]) >= 0.0:
			var secs := job_seconds(station_id, StringName(str(j["recipe"])))
			# A clock moved back must not show more time than the job takes.
			soonest = minf(soonest, minf(secs, float(j["started"]) + secs - now))
	return "" if soonest == INF else mmss(maxi(0, ceili(soonest)))

static func mmss(secs: int) -> String:
	return "%d:%02d" % [secs / 60, secs % 60]

## The station's own model per stage (props_manifest stages); kinds without stages keep theirs.
func _swap_stage(id: String) -> void:
	if id == "" or id == _shown_stage:
		return
	var host := get_parent() as Node3D
	var packed := _stage_scene(id)
	if host == null or packed == null:
		return
	var old := host.get_node_or_null("Prop")
	if old:
		host.remove_child(old)
		old.queue_free()
	var inst := packed.instantiate() as Node3D
	inst.name = "Prop"
	host.add_child(inst)
	_shown_stage = id

func _stage_scene(id: String) -> PackedScene:
	if _models.has(id):
		return _models[id]
	var row: Variant = (Data.props_manifest.get("buildings", {}) as Dictionary).get(str(station_id), {})
	var path := ""
	if row is Dictionary:
		for st in (row as Dictionary).get("stages", []):
			if st is Dictionary and str((st as Dictionary).get("id", "")) == id:
				path = str((st as Dictionary).get("glb", ""))
	var packed: PackedScene = load(path) as PackedScene if path != "" and ResourceLoader.exists(path) else null
	_models[id] = packed
	return packed
