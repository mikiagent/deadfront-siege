extends Node
var failures:=0
func check(ok:bool,label:String)->void:
	print("[cargocapacity] %s %s" % ["PASS" if ok else "FAIL",label])
	if not ok:failures+=1
## True when every black_iron in inv has the given unstable flag.
func ore_unstable(inv:Inventory,want:bool)->bool:
	for s in inv.slots:
		if s and s.def_id==&"black_iron" and s.is_unstable()!=want:return false
	return true
func run(host:Node)->void:
	await get_tree().create_timer(0.8).timeout
	for n in get_tree().root.find_children("CharacterCreation","CharacterCreation",true,false):n.queue_free()
	World.home_terrain=&"meadow"
	World.load_island(host,&"volcanic_60",Vector3(0,1,18),false)
	await get_tree().create_timer(0.5).timeout
	var p := PlayerRegistry.local()
	# W2-INV: ore does not stack, so 8 ore are 8 bag slots and cargo room is counted in free slots.
	p.inventory=Inventory.new(10)
	var ore:=ItemStack.make(&"black_iron",8,{},55)
	ore.set_flag(&"unstable",true)
	check(p.inventory.add(ore)==0 and p.inventory.used_slots()==8,"8 unstable ore fill 8 bag slots")
	World.cargo_home=Inventory.new(1)
	World.cargo_home.add(ItemStack.make(&"stone",1))
	World.t_stones=20
	World.cargo_warp(p)
	check(p.inventory.count_of(&"black_iron")==8 and World.t_stones==20,"full cargo preserves all ore and no fee")
	World.cargo_home=Inventory.new(3)
	World.cargo_home.add(ItemStack.make(&"stone",1))
	World.cargo_warp(p)
	check(p.inventory.count_of(&"black_iron")==6 and World.cargo_home.count_of(&"black_iron")==2 and World.t_stones==18,"partial shipment preserves6unstable remainder,2Tfee")
	check(ore_unstable(p.inventory,true) and ore_unstable(World.cargo_home,false),"only accepted cargo stabilizes")
	World.cargo_home=Inventory.new(6)
	World.cargo_warp(p)
	check(p.inventory.count_of(&"black_iron")==0 and World.cargo_home.count_of(&"black_iron")==6 and World.t_stones==16,"whole shipment retained and2Tfee")
	print("[cargocapacity] failures%d seeded capacity fixture, not earned cargo" % failures)
	get_tree().quit(0 if failures==0 else 1)
