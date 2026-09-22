class_name Objectives
extends RefCounted
## The survivor's standing orders, read from data/world/objectives.json.
##
## One objective is current at a time. Every condition is evaluated against state the player
## can already see, so nothing else in the game has to report progress: no signals, no hooks,
## no new save fields beyond the index. World ticks this and the HUD card draws it.

## {"title","hint","progress","frac","done","last"} for the current step, or an empty Dictionary
## once the survivor has finished the list.
static func current(player: Player) -> Dictionary:
	var steps := _steps()
	var i := World.objective
	if player == null or i < 0 or i >= steps.size():
		return {}
	var step: Dictionary = steps[i]
	var state := _progress(player, step)
	state = _with_best(state)
	return {
		"id": str(step.get("id", "")),
		"title": str(step.get("title", "")),
		"hint": str(step.get("hint", "")),
		"progress": str(state["label"]),
		"frac": float(state["frac"]),
		"done": bool(state["done"]),
		"index": i,
		"count": steps.size(),
		"last": i == steps.size() - 1,
	}

## Advance while the current objective is satisfied, paying out each one. Returns the number
## completed this tick so the caller can decide whether to announce anything.
static func settle(player: Player) -> int:
	var steps := _steps()
	var done := 0
	while World.objective < steps.size():
		var step: Dictionary = steps[World.objective]
		var state := _with_best(_progress(player, step))
		if not bool(state["done"]):
			break
		var xp := int(step.get("xp", 0))
		var stones := int(step.get("t_stones", 0))
		if xp > 0:
			World.add_xp(xp)
		if stones > 0:
			World.t_stones += stones
		print("[objective] done %s (+%d xp%s)" % [
			step.get("id", "?"), xp, ", +%d T" % stones if stones > 0 else ""])
		World.objective += 1
		World.objective_best = 0
		done += 1
		if player and player.has_method("notice"):
			var next := current(player)
			if next.is_empty():
				player.notice("Standing orders complete")
			else:
				player.notice("Next: %s" % next["title"])
	return done

## Materials are spent as fast as they are gathered, so an order tracks the most the survivor
## ever held at once rather than what is in the bag this instant.
static func _with_best(state: Dictionary) -> Dictionary:
	var got := int(state["got"])
	World.objective_best = maxi(World.objective_best, got)
	got = maxi(got, World.objective_best)
	var want := int(state["want"])
	return {
		"done": got >= want,
		"frac": clampf(float(got) / float(maxi(1, want)), 0.0, 1.0),
		"label": "%d / %d" % [mini(got, want), want],
		"got": got, "want": want,
	}

static func _steps() -> Array:
	var raw: Variant = Data.world_objectives
	return raw if raw is Array else []

## {"done", "frac", "label"} for one step.
static func _progress(player: Player, step: Dictionary) -> Dictionary:
	if step.has("have"):
		var need: Dictionary = step["have"]
		var got := 0
		var want := 0
		for id in need:
			var n := int(need[id])
			want += n
			got += mini(n, player.inventory.count_of(StringName(str(id))))
		return _row(got, want)
	if step.has("have_any"):
		var any: Dictionary = step["have_any"]
		var best := 0
		var target := 1
		for id in any:
			target = int(any[id])
			best = maxi(best, player.inventory.count_of(StringName(str(id))))
		return _row(mini(best, target), target)
	if step.has("pets"):
		return _row(player.bonded.size(), int(step["pets"]))
	if step.has("away"):
		return _row(0 if World.is_home() else 1, 1)
	return _row(0, 1)

static func _row(got: int, want: int) -> Dictionary:
	want = maxi(1, want)
	return {
		"done": got >= want,
		"frac": clampf(float(got) / float(want), 0.0, 1.0),
		"label": "%d / %d" % [mini(got, want), want],
		"got": got, "want": want,
	}
