extends Node
var failures:=0
func check(ok:bool,label:String)->void:
	print("[cargocapacity] %s %s" % ["PASS" if ok else "FAIL",label])
	if not ok:failures+=1
func run(host:Node)->void:
	await get_tree().create_timer(0.8).timeout
	for n in get_tree().root.find_children("CharacterCreation","CharacterCreation",true,false):n.queue_free()
	World.home_terrain=&"meadow"
	World.load_island(host,&"volcanic_60",Vector3(0,1,18),false)
	await get_tree().create_timer(0.5).timeout
	var p:=get_tree().get_first_node_in_group("player") as Player
	p.inventory=Inventory.new(3)
	var ore:=ItemStack.make(&"black_iron",8,{},55)
	ore.set_flag(&"unstable",true)
	p.inventory.add(ore)
	World.cargo_home=Inventory.new(1)
	World.cargo_home.add(ItemStack.make(&"stone",1))
	World.t_stones=20
	World.cargo_warp(p)
	check(p.inventory.count_of(&"black_iron")==8 and World.t_stones==20,"full cargo preserves all ore and no fee")
	World.cargo_home=Inventory.new(1)
	var cap:=Data.item(&"black_iron").stack_max
	World.cargo_home.add(ItemStack.make(&"black_iron",cap-2,{},55))
	World.cargo_warp(p)
	check(p.inventory.count_of(&"black_iron")==6 and World.cargo_home.count_of(&"black_iron")==cap and World.t_stones==18,"partial shipment preserves6unstable remainder,2Tfee")
	check(p.inventory.slots[0].is_unstable() and not World.cargo_home.slots[0].is_unstable(),"only accepted cargo stabilizes")
	World.cargo_home=Inventory.new(1)
	World.cargo_warp(p)
	check(p.inventory.count_of(&"black_iron")==0 and World.cargo_home.count_of(&"black_iron")==6 and World.t_stones==16,"whole shipment retained and2Tfee")
	print("[cargocapacity] failures%d seeded capacity fixture, not earned cargo" % failures)
	get_tree().quit(0 if failures==0 else 1)
