class_name Taste
extends RefCounted
## Spec 32 §7: seven flavour dimensions score a food to a grade; the grade carries a status (and an
## XP / fatigue multiplier). Every threshold and percentage is # ASSUMPTION and lives in
## data/foods.json's taste_grades block: the reconstruction describes the grades and calls its own
## scoring reconstructed, so nothing here is presented as a Nexon constant.
## Repeatedly eating the same dominant flavour lowers satisfaction until the memory fades
## (spec 32 §7 "taste and flavor fatigue"); that penalty is data (repeat_penalty), never a constant.

## The dominant flavour of a food: the highest scoring one, ties broken by the documented order.
static func dominant(flavors: Dictionary, order: Array) -> String:
	var best := ""
	var best_v := -INF
	for f: Variant in order:
		var v := float(flavors.get(str(f), 0.0))
		if v > best_v:
			best_v = v
			best = str(f)
	return best

## Score 0-100 from the bundle's taste score minus the repeat penalty for its dominant flavour.
## `memory` is {flavor: {"score": float, "t": unix seconds}} and is updated in place when `remember`.
static func score(foods_doc: Dictionary, entry: Dictionary, memory: Dictionary, now_s: float = -1.0, remember: bool = false) -> Dictionary:
	var block: Dictionary = foods_doc.get("taste_grades", {})
	var order: Array = block.get("flavors", [])
	var flavors: Dictionary = entry.get("flavors", {})
	var dom := dominant(flavors, order)
	var base := float(entry.get("taste_score", float(block.get("normal_score", 50.0))))
	var penalty := 0.0
	var mem_seconds := float(block.get("repeat_memory_seconds", 600.0))
	var step := float(block.get("repeat_penalty", 8.0))
	var cap := float(block.get("repeat_penalty_max", 32.0))
	if dom != "" and memory.has(dom):
		var row: Dictionary = memory[dom]
		var t := now_s if now_s >= 0.0 else Time.get_unix_time_from_system()
		var age := maxf(0.0, float(t) - float(row.get("t", t)))
		# A run of the same flavour remembers up to the cap and forgets one eat per memory window.
		var decay := floorf(age / maxf(1.0, mem_seconds))
		penalty = clampf((float(row.get("score", 0.0)) - decay) * step, 0.0, cap)
	var total := clampf(base - penalty, 0.0, 100.0)
	var grade: Dictionary = grade_for(block, total)
	if remember and dom != "":
		var t2 := now_s if now_s >= 0.0 else Time.get_unix_time_from_system()
		var had: Dictionary = memory.get(dom, {"score": 0.0, "t": t2})
		var stale := int(floorf(maxf(0.0, t2 - float(had.get("t", t2))) / maxf(1.0, mem_seconds)))
		var runs := maxf(0.0, float(had.get("score", 0.0)) - float(stale)) + 1.0
		memory[dom] = {"score": runs, "t": t2}
	return {
		"flavor": dom,
		"score": total,
		"penalty": penalty,
		"grade": str(grade.get("grade", "normal")),
		"xp_mult": float(grade.get("xp_mult", 1.0)),
		"fatigue_mult": float(grade.get("fatigue_mult", 1.0)),
		"status": str(grade.get("status", "")),
		"duration": float(grade.get("duration", 0.0)),
	}

## The grade whose `min` the score clears; the last row of the table is the floor.
static func grade_for(block: Dictionary, total: float) -> Dictionary:
	var rows: Array = block.get("grades", [])
	var best: Dictionary = {}
	var best_min := -INF
	for row: Variant in rows:
		if row is Dictionary and total >= float((row as Dictionary).get("min", 0.0)) and float((row as Dictionary).get("min", 0.0)) > best_min:
			best = row as Dictionary
			best_min = float(best.get("min", 0.0))
	return best
