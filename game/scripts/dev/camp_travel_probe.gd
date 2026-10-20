extends Node
var failures:=0
func check(ok:bool,label:String)->void:
	print("[camptravel] %s %s" % ["PASS" if ok else "FAIL",label])
	if not ok: failures+=1
func run(host:Node)->void:
	await get_tree().create_timer(0.8).timeout
	for n in get_tree().root.find_children("CharacterCreation","CharacterCreation",true,false):n.queue_free()
	World.home_terrain=&"meadow"
	World.load_island(host,&"home_grassland",Vector3(0,1,18),false)
	await get_tree().create_timer(0.5).timeout
	var p:=get_tree().get_first_node_in_group("player") as Player
	p.skills.trees["survival"]["level"]=55
	World.t_stones=20
	# Explicitly seeded fixture camp: not earned building/material evidence. The basket goes on the
	# first legal cell near camp: since W1-SAVE a load refunds a building on unclaimed land.
	var grid:BuildGrid=World.runtime.build_grid
	var camp:=BuildGrid.tile_of(World.runtime._camp_pos)
	var cell:=camp
	for dz in range(-3,4):
		for dx in range(-3,4):
			if cell==camp and grid.can_place(&"basket",camp+Vector2i(dx,dz),1)=="":
				cell=camp+Vector2i(dx,dz)
	check(grid.can_place(&"basket",cell,1)=="","fixture basket cell %s is placeable" % cell)
	var basket=(load("res://scripts/world/placed_building.gd") as GDScript).make(&"basket")
	World.runtime.add_child(basket)
	basket.set_grid_pose(cell,1)
	basket.global_transform=grid.placement_transform(&"basket",cell,1)
	grid.occupy(basket,grid.cells_for(&"basket",cell,1))
	basket.storage.add(ItemStack.make(&"branch",7,{"level":55},55))
	World._home_buildings_cache.clear()
	for repeat in 2:
		World.travel(&"volcanic_60",&"sail")
		await get_tree().create_timer(0.8).timeout
		check(World.island_id==&"volcanic_60","seeded route departs")
		check(World._home_buildings_cache.size()==1,"camp cached before departure, no fixture pre-save")
		World.travel(&"home_grassland",&"harbour_home")
		await get_tree().create_timer(0.8).timeout
		var count:=0
		for b in get_tree().get_nodes_in_group("placed_building"):
			if str(b.get("kind"))=="basket" and not b.is_cargo:
				count+=1
				check(b.build_cell==cell and b.build_rot==1,"basket pose restored")
				check(b.storage.count_of(&"branch")==7 and b.storage.slots[0].level==55,"stored material count/quality restored")
		check(count==1,"exactly one basket after return%d" % repeat)
	check(World.t_stones==10,"two5T sail debits, returns free")
	var r := LabResult.new("camptravel")
	r.expect(failures == 0, "%d camp checks failed" % failures)
	r.finish(get_tree(), "done failures%d seeded fixture, NOT earned camp journey" % failures)
