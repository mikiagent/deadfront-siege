extends Node3D
## Seeded real-world plain fibre bush mapping/interaction fixture.
var _r := LabResult.new("plainbush")

func _ready() -> void:
	_r.deadline(get_tree(), 45.0)
	var kit := LabKit.build(self,24.0)
	var p: Player=kit["player"]
	Game.max_creatures_per_island=0
	Game.debug_overlay=false
	World.home_terrain=&"meadow"
	World.load_island(self,&"home_grassland",Vector3(0,1,12),false)
	var floor:=get_node_or_null("Nav/Floor")
	if floor: floor.queue_free()
	await get_tree().create_timer(0.6).timeout
	var runtime: Node3D=World.runtime
	var bushes: Array[HarvestNode]=[]
	for i in 4:
		var family: String="Bush" if i<2 else "Bush_Snow"
		var pos:=p.global_position+Vector3(-6.0+float(i)*4,0,-5)
		runtime._plant_at(family,"plainfixture_%d" % i,pos,&"fibre_stalk",&"knife","grassland",1,Color.GREEN)
		var n: HarvestNode=runtime._harvest_nodes["plainfixture_%d" % i]
		bushes.append(n)
		var expect: Array=Data.nature_families[family]["models"]
		_r.expect(expect[0].ends_with("-empty.glb") and expect[1].ends_with("-empty.glb"), "expect[0].ends_with(\"-empty.glb\") and expect[1].ends_with(\"-empty.glb\")")
		_r.expect(n._empty_batch==null and not n.berries_available(), "n._empty_batch==null and not n.berries_available()")
	for b in runtime._batches: b.commit()
	for n in runtime._harvest_nodes.values(): n.refresh_batched_visual()
	var cam: IsoCamera=kit["cam"]
	cam.size=12
	p.global_position=bushes[1].global_position+Vector3(0,1,3)
	cam._snap()
	LabKit.give(p,&"stone_knife_work",1)
	await get_tree().create_timer(0.6).timeout
	p._interact_tap_target(bushes[1])
	_r.expect(p._gather_radial.is_open(), "actual bush tap opens yield radial")
	await _capture("radial")
	p._gather_radial.close()
	for n in bushes:
		var index: int=-1
		var opts:=n.options()
		for i in opts.size():
			if opts[i]["item"]=="fibre_stalk": index=i
		_r.expect(index>=0, "plain fibre yield preserved")
		n.select_option(index)
		var before:=n.units_left_for(&"fibre_stalk")
		var stack:=n.roll_yield()
		_r.expect(stack.def_id==&"fibre_stalk", "stack.def_id==&\"fibre_stalk\"")
		_r.expect(n.consume_unit() and n.units_left_for(&"fibre_stalk")==before-1, "n.consume_unit() and n.units_left_for(&\"fibre_stalk\")==before-1")
		print("[plainbush] %s fibre%d->%d model=%s" % [n.family,before,n.units_left_for(&"fibre_stalk"),n._batch.name])
	var target:=bushes[1]
	target.select_option(0)
	p.global_position=target.global_position+Vector3(0,1,1.5)
	var count_before:=p.inventory.count_of(&"fibre_stalk")
	p._begin_gather(target)
	await get_tree().create_timer(5.0).timeout
	p._cancel_gather_and_butcher()
	_r.expect(p.inventory.count_of(&"fibre_stalk")>count_before, "real gather awards fibre to inventory")
	print("[plainbush] actual gather fibre inventory%d->%d" % [count_before,p.inventory.count_of(&"fibre_stalk")])
	await _capture("foliage")
	_r.finish(get_tree(), "4plain/snow fibre bushes, empty custom meshes, interaction/yields unchanged")

func _capture(stage: String) -> void:
	if DisplayServer.get_name()=="headless": return
	await get_tree().process_frame
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(LabResult.capture_path("plain-bush-" + stage))
