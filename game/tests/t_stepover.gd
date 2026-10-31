extends SceneTree
## Owner 2026-10-21: "Animals are getting stuck on resources like grass. Make it so smaller resources can be
## stepped over and larger/taller resources actually block." Small nodes have no solid body and are not path
## blockers; trees and tall nodes keep both. Prints "[t_stepover] PASS" or FAIL lines; exits 0 / 1.

var failures: Array[String] = []
var _done := false

func _process(_delta: float) -> bool:
	if _done:
		return true
	if get_root() == null or get_root().get_node_or_null("Data") == null:
		return false
	_done = true
	var scene: PackedScene = load("res://scenes/world/harvest_node.tscn")
	var step := ["Grass", "Grass_Short", "FibreTuft", "DryGrassTuft", "FlaxPlant", "HerbPlant", "BushBerries", "Bush", "PeatNode", "BranchPile", "TreeStump"]
	var block := ["CommonTree", "PineTree", "AcaciaTree", "GraniteBoulder", "CopperOreNode", "Rock", "Cactus", "BambooPlant"]
	for fam in step + block:
		var n = scene.instantiate()
		n.family = fam
		get_root().add_child(n)
		var want: bool = fam in block
		if n.blocks_movement() != want:
			failures.append("%s blocks_movement=%s, want %s" % [fam, n.blocks_movement(), want])
		if (n.collision_layer == 1) != want:
			failures.append("%s collision_layer=%d, want %d" % [fam, n.collision_layer, 1 if want else 0])
		var zone = n.get_node_or_null("TapZone")
		if zone == null or zone.collision_layer != 2:
			failures.append("%s lost its tap zone (still must be tappable)" % fam)
		n.queue_free()
	if failures.is_empty():
		print("[t_stepover] PASS step=%d block=%d" % [step.size(), block.size()])
		quit(0)
	else:
		for f in failures:
			print("[t_stepover] FAIL %s" % f)
		quit(1)
	return true
