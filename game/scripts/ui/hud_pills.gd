class_name HudPills
extends RefCounted
## HuntHud's world label pills (buildings, stations and harvest nodes within 8 m): which objects get
## one, the tool icons they need, and drawing them onto the HUD's canvas off its taken rects. Static
## functions over the HUD, split out of hunt_hud.gd (review: no god-file growth).

const TOOL_ICON_ITEM := {"axe": "work_axe", "pick": "work_pick", "knife": "stone_knife", "none": "hands", "": "hands"}
const GLIDE_PX := 5.0  ## px per frame a pill slides toward a new row (it hopped a whole row in one frame)

## Each pill's offset from its anchor as last drawn, by object instance id.
static var _last_offset := {}

## The last frame's drawn chips: {node, anchor, rect}. Read by labs that check a chip sits by its object.
static var last_drawn: Array = []
## The harvest and carcass pills drawn last frame, tappable (UIGATHER §4.1, LOOTRADIAL): {node, rect}.
static var hit_pills: Array = []

## Pill height and type size: a larger box on desktop (B1 mockup), the shipped 22 / 14 on a phone.
static func pill_metrics(view: Vector2) -> Vector2i:
	return Vector2i(22, 14) if UiTokens.is_compact(view) else Vector2i(30, 18)

## The harvest node or carcass whose pill is under `point` (screen px), else null. A tap there selects the node
## like a tap on the node itself.
static func node_at(point: Vector2) -> Node3D:
	for d: Dictionary in hit_pills:
		var n: Variant = d["node"]
		if (d["rect"] as Rect2).grow(4.0).has_point(point) and n is Node3D and is_instance_valid(n):
			return n as Node3D
	return null

static func gather_radial_node(hud: HuntHud) -> Node3D:
	var gr: Variant = hud.player.get("_gather_radial")
	if gr and gr.has_method("is_open") and gr.is_open():
		return gr.node
	return null

## [[icon, have]] per distinct tool the node's yields need; corpses need a knife.
static func tools_for_node(hud: HuntHud, n3: Node3D, grp: String) -> Array:
	var out: Array = []
	var seen: Dictionary = {}
	var classes: Array = []
	if grp == "harvest" and n3 is HarvestNode:
		for o in (n3 as HarvestNode).options():
			classes.append(str(o.get("tool", "none")))
	elif grp == "corpse":
		classes.append("knife")
	else:
		return out
	for c in classes:
		if seen.has(c):
			continue
		seen[c] = true
		var have := true
		if c != "none" and c != "" and hud.player and hud.player.inventory:
			have = hud.player.inventory.has_tool_class(StringName(c))
		out.append([ItemIcons.texture(StringName(str(TOOL_ICON_ITEM.get(c, "hands")))), have])
	return out

## World labels keep off `avoid` (the HUD's blocks and every hex, taken_rects) and off the open
## gather radial's labels and title; one with no free spot near its anchor is not drawn.
static func draw(hud: HuntHud, cam: Camera3D, avoid: Array[Rect2]) -> void:
	if cam == null or hud.player == null:
		return
	var radial_node: Node3D = null
	avoid = avoid.duplicate()
	if hud.player.has_node("GatherRadialLayer/GatherRadial"):
		var gr := hud.player.get_node("GatherRadialLayer/GatherRadial") as GatherRadial
		if gr.is_open():
			radial_node = gr.node
			avoid.append_array(gr.label_rects)
			avoid.append(gr.title_box)
	# CRAFTRADIAL: an open station radial names its station in the ring's centre; no second chip.
	var sc: Variant = hud.player.get("station_craft")
	if radial_node == null and sc != null and sc.menu != null and sc.menu.visible and is_instance_valid(sc.menu.station):
		radial_node = sc.menu.station
	var rows: Array = []
	var pm := pill_metrics(hud.get_viewport_rect().size)
	var fs := pm.y
	var pp := hud.player.global_position
	# A bonfire is in "placed_building", "craft_station" AND "bonfire", so without this the camp
	# drew three identical labels stacked on one object.
	var labelled := {}
	for grp in ["placed_building", "craft_station", "bonfire", "taming_pen", "cargo_warp", "harbour", "harvest", "corpse"]:
		for n in hud.get_tree().get_nodes_in_group(grp):
			var n3 := n as Node3D
			if n3 == null or not n3.visible or n3 == radial_node:
				continue
			if labelled.has(n3.get_instance_id()):
				continue
			labelled[n3.get_instance_id()] = true
			var d := pp.distance_to(n3.global_position)
			# World labels are interaction hints, not permanent billboards. Keep the scene
			# clean until the survivor is close or the object is actively inspected.
			var active := n3 == radial_node or n3 == hud.player.gather_target
			if d > 8.0 and not active:
				continue
			rows.append([d, n3, grp])
	rows.sort_custom(func (a: Array, b: Array) -> bool: return a[0] < b[0])
	var pending: Array = []
	var shown := 0
	# Durango labels the thing you are about to use, not every trunk in the grove. Two of any
	# one kind is enough to read the area; the rest would be a wall of identical chips.
	var per_kind := {}
	for row in rows:
		if shown >= 12:
			break
		var n3: Node3D = row[1]
		var grp: String = row[2]
		var d: float = row[0]
		var name := ""
		var dot := Color(0.35, 0.85, 0.35)
		var glyph: Texture2D = null  # a harvest pill shows its resource symbol, greyed (spec §4.1)
		var timer := ""
		var top := 1.2
		if grp == "harvest":
			var hn := n3 as HarvestNode
			if hn == null:
				continue
			name = (hn.family if hn.family != "" else str(hn.node_id)).replace("_", " ").capitalize()
			glyph = HexButton.grey_texture(ItemIcons.texture(hn.yield_def_id))
			top = hn.top_of_node()
			if hn.depleted:
				dot = Color(0.5, 0.5, 0.5)
				var left := hn.regen_left()
				if left > 0.0:
					timer = "%dm %02ds" % [int(left / 60.0), int(left) % 60]
			elif hn.required_tool_class != &"" and hn.required_tool_class != &"none" and not hud.player.inventory.has_tool_class(hn.required_tool_class):
				dot = UiTokens.DANGER
		elif grp == "corpse":
			# A carcass reads like a harvest node: its first part's symbol, greyed; red without a knife.
			var c := n3 as Corpse
			if c == null:
				continue
			name = c.species_display_name()
			var parts := CarcassParts.parts(c.species)
			glyph = HexButton.grey_texture(ItemIcons.texture(parts[0]["id"] if not parts.is_empty() else &"loot_bag"))
			top = 1.0
			if c.loot.used_slots() <= 0 or c.cuts_left <= 0:
				dot = Color(0.5, 0.5, 0.5)
			elif not hud.player.inventory.has_tool_class(&"knife"):
				dot = UiTokens.DANGER
		else:
			var kind: Variant = n3.get("kind")
			if kind == null:
				kind = n3.get("station_id")
			name = str(kind if kind != null else n3.name).replace("_", " ").capitalize()
			if n3 is TownBuilding and (n3 as TownBuilding).display_name != "":
				name = (n3 as TownBuilding).display_name  # TUTORIAL ISLAND town: "Adventurer's Guild", "Market stall"
			if grp == "cargo_warp":
				name = "Cargo Warp"
			elif grp == "harbour":
				name = "Harbour"
		var active_row := n3 == radial_node or n3 == hud.player.gather_target
		var kind_n := int(per_kind.get(name, 0))
		# A process station's job status replaces its name on one line: a second line made the chip
		# taller than the gap to the next station, so dense camps pushed chips onto their neighbours.
		var ps := ProcessStation.of(n3)
		var status := ps.label_text() if ps else ""
		if kind_n >= 2 and not active_row and status == "":  # every working station keeps its status
			continue
		per_kind[name] = kind_n + 1
		var name_text := ""  # the fallback chip when a status has no spot by its station
		var name_w := 0.0
		if status != "":
			name_text = UiTokens.ellipsis(hud._font, name, UiTokens.LABEL_MAX_W - 28.0, fs)
			name_w = minf(hud._font.get_string_size(name_text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x + 28.0, UiTokens.LABEL_MAX_W)
			name = status
		var lead := float(fs) + 20.0 if glyph else 28.0  # the glyph is wider than the status dot
		var text := UiTokens.ellipsis(hud._font, name, UiTokens.LABEL_MAX_W - lead, fs)
		var tw := hud._font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		var working := (grp == "harvest" and (n3 == hud.player.gather_target or (gather_radial_node(hud) == n3))) or (grp == "corpse" and n3 is Corpse and (n3 as Corpse).tapped_recently(4.0))
		var tools: Array = tools_for_node(hud, n3, grp) if working else []
		var w := minf(tw + lead, UiTokens.LABEL_MAX_W)
		if timer != "":
			w = maxf(w, hud._font.get_string_size(timer, HORIZONTAL_ALIGNMENT_LEFT, -1, UiTokens.meta(hud.get_viewport_rect().size)).x + 16.0)
		var sp := cam.unproject_position(n3.global_position + Vector3(0, top + 0.35, 0))
		# Placed lowest on screen first, not nearest first: the camera shifts every pill alike, so this order
		# (and which pill steps up a row) holds while the survivor walks; by whole metres (or whole pixels)
		# two near bushes tied, the sort is not stable, and they traded rows frame to frame.
		var priority := (2000000000 if active_row else 0) + (1000000000 if name == "Workbench" or name == "Cargo Warp" else 0) + int(sp.y * 1000.0)
		# The box covers what is drawn: tool icons poke 8 px over the pill, a regrow timer hangs under it.
		pending.append({
			"anchor": sp, "w": w, "h": float(pm.x) + (8.0 if not tools.is_empty() else 0.0) + (20.0 if timer != "" else 0.0), "priority": priority,
			"text": text, "dot": dot, "glyph": glyph, "lead": lead, "harvest": grp == "harvest" or grp == "corpse", "timer": timer, "tools": tools, "id": n3.get_instance_id(),
			"node": n3, "at": sp, "slide": status != "", "name_text": name_text, "name_w": name_w,
			"a": 1.0 if n3 == radial_node else 1.0 - smoothstep(5.5, 8.0, d),
		})
		shown += 1
	var view := hud.get_viewport_rect().size
	var pill_i := 0
	# The survivor is only stepped away from: a building behind it keeps its label. While it walks the
	# labels hold their spots and fade where they cross it: stepping away, every label it passed hopped a row.
	var fig := HudLayout.figure_rect(hud)
	var walking := hud.player.velocity.length() > 0.5
	var hard: Array[Rect2] = []
	for x in avoid:
		if x != fig and not (walking and x == hud.drawn_blocks.get("nameplate")):
			hard.append(x)
	var soft: Array[Rect2] = []
	if not walking:
		soft.append(fig)
	for item: Dictionary in pending.duplicate():
		if item["slide"] and not _slide_clear(item, hard + soft):
			# No spot by its station for the status: the shorter name chip, else no chip (one far
			# off its station reads as the neighbour's).
			item["text"] = item["name_text"]
			item["w"] = item["name_w"]
			if not _slide_clear(item, hard + soft):
				pending.erase(item)
	last_drawn = []
	hit_pills = []
	var offsets := {}
	for item in UiTokens.layout_labels(pending, view, hard, soft):
		last_drawn.append({"node": item["node"], "anchor": item["at"], "rect": item["rect"]})
		var box: Rect2 = item["rect"]
		var anchor: Vector2 = item["anchor"]
		if _last_offset.has(item["id"]):
			box.position = anchor + (_last_offset[item["id"]] as Vector2).move_toward(box.position - anchor, GLIDE_PX)
		offsets[item["id"]] = box.position - anchor
		var under := false
		for h in hard:
			under = under or box.intersects(h)
		if under:
			continue  # gliding under a HUD block (a level-up opened over it): hidden until it is clear
		hud.drawn_blocks["pill%d" % pill_i] = box
		pill_i += 1
		var tools: Array = item["tools"]
		var rect := Rect2(box.position + Vector2(0.0, 8.0 if not tools.is_empty() else 0.0), Vector2(box.size.x, float(pm.x)))
		if item["harvest"]:
			hit_pills.append({"node": item["node"], "rect": rect})
		var a: float = item["a"] * (0.35 if walking and box.intersects(fig) else 1.0)
		var text: String = item["text"]
		var dot: Color = item["dot"]
		var bg := UiTokens.INK
		bg.a *= a
		hud.draw_rect(rect, bg)
		var glyph: Texture2D = item["glyph"]
		var mid := rect.position.y + rect.size.y * 0.5
		if glyph:
			# Grey symbol; a picked-clean node dims it and a missing tool tints it red (the old dot's cues).
			var gt := Color(1, 1, 1, a * (0.5 if dot == Color(0.5, 0.5, 0.5) else 1.0))
			if dot == UiTokens.DANGER:
				gt = Color(1.0, 0.5, 0.45, a)
			var gs := float(fs)
			hud.draw_texture_rect(glyph, Rect2(rect.position.x + 6.0, mid - gs * 0.5, gs, gs), false, gt)
		else:
			hud.draw_circle(Vector2(rect.position.x + 10.0, mid), 4.0, Color(dot.r, dot.g, dot.b, a))
		var lead: float = item["lead"]
		hud.draw_string(hud._font, Vector2(rect.position.x + lead - 8.0, mid + float(fs) * 0.36), text, HORIZONTAL_ALIGNMENT_LEFT, rect.size.x - lead + 4.0, fs, Color(1, 1, 1, a))
		var ix := rect.position.x + rect.size.x - 6.0 - float(tools.size()) * 14.0
		for t in tools:
			var tex: Texture2D = t[0]
			var ok: bool = t[1]
			if tex:
				hud.draw_texture_rect(tex, Rect2(ix, rect.position.y - 8.0, 12.0, 12.0), false, Color(1, 1, 1, a) if ok else Color(1.0, 0.45, 0.4, a))
			ix += 14.0
		var timer: String = item["timer"]
		if timer != "":
			var tt := UiTokens.ellipsis(hud._font, timer, 96.0, UiTokens.meta(view))
			var ttw := hud._font.get_string_size(tt, HORIZONTAL_ALIGNMENT_LEFT, -1, UiTokens.meta(view)).x
			var trect := Rect2(rect.position.x, rect.position.y + rect.size.y + 2.0, ttw + 16.0, 18.0)
			var tbg := UiTokens.INK
			tbg.a *= a
			hud.draw_rect(trect, tbg)
			hud.draw_string(hud._font, Vector2(trect.position.x + 8.0, trect.position.y + 14.0), tt, HORIZONTAL_ALIGNMENT_LEFT, -1, UiTokens.meta(view), Color(1, 0.9, 0.6, a))
		shown += 1
	_last_offset = offsets

## A status chip blocked where it stands (the survivor's figure, a HUD panel) steps sideways first, only
## as far as its station's anchor stays under it, then tries hanging just under the anchor and one row
## up. Returns false when no spot is free. Moving it rows up instead pushed the next station's chip up
## too, until in a dense camp row each status hung over the wrong station.
static func _slide_clear(item: Dictionary, taken: Array[Rect2]) -> bool:
	var w := minf(float(item["w"]), UiTokens.LABEL_MAX_W)
	var h := float(item["h"])
	var a: Vector2 = item["anchor"]
	for dy: float in [0.0, h + 4.0, -h - 4.0]:
		var dx := 0.0
		while dx <= w * 0.5 - 12.0:
			for x: float in [dx, -dx]:
				var r := Rect2(a + Vector2(x - w * 0.5, dy - h), Vector2(w, h)).grow(2.0)
				if not taken.any(func (t: Rect2) -> bool: return r.intersects(t)):
					item["anchor"] = a + Vector2(x, dy)
					return true
			dx += 4.0
	return false
