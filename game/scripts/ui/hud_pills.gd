class_name HudPills
extends RefCounted
## HuntHud's world label pills (buildings, stations and harvest nodes within 8 m): which objects get
## one, the tool icons they need, and drawing them onto the HUD's canvas off its taken rects. Static
## functions over the HUD, split out of hunt_hud.gd (review: no god-file growth).

const TOOL_ICON_ITEM := {"axe": "work_axe", "pick": "work_pick", "knife": "stone_knife", "none": "hands", "": "hands"}

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
	var rows: Array = []
	var pp := hud.player.global_position
	# A bonfire is in "placed_building", "craft_station" AND "bonfire", so without this the camp
	# drew three identical labels stacked on one object.
	var labelled := {}
	for grp in ["placed_building", "craft_station", "bonfire", "taming_pen", "cargo_warp", "harbour", "harvest"]:
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
		var timer := ""
		var top := 1.2
		if grp == "harvest":
			var hn := n3 as HarvestNode
			if hn == null:
				continue
			name = (hn.family if hn.family != "" else str(hn.node_id)).replace("_", " ").capitalize()
			top = hn.top_of_node()
			if hn.depleted:
				dot = Color(0.5, 0.5, 0.5)
				var left := hn.regen_left()
				if left > 0.0:
					timer = "%dm %02ds" % [int(left / 60.0), int(left) % 60]
			elif hn.required_tool_class != &"" and hn.required_tool_class != &"none" and not hud.player.inventory.has_tool_class(hn.required_tool_class):
				dot = UiTokens.DANGER
		else:
			var kind: Variant = n3.get("kind")
			if kind == null:
				kind = n3.get("station_id")
			name = str(kind if kind != null else n3.name).replace("_", " ").capitalize()
			if grp == "cargo_warp":
				name = "Cargo Warp"
			elif grp == "harbour":
				name = "Harbour"
		var active_row := n3 == radial_node or n3 == hud.player.gather_target
		var kind_n := int(per_kind.get(name, 0))
		if kind_n >= 2 and not active_row:
			continue
		per_kind[name] = kind_n + 1
		var priority := 100 if active_row else int(40.0 - d)
		if name == "Workbench" or name == "Cargo Warp":
			priority += 5
		var text := UiTokens.ellipsis(hud._font, name, UiTokens.LABEL_MAX_W - 28.0, 14)
		var tw := hud._font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 14).x
		var working := (grp == "harvest" and (n3 == hud.player.gather_target or (gather_radial_node(hud) == n3))) or (grp == "corpse" and n3 is Corpse and (n3 as Corpse).tapped_recently(4.0))
		var tools: Array = tools_for_node(hud, n3, grp) if working else []
		var w := minf(tw + 28.0, UiTokens.LABEL_MAX_W)
		if timer != "":
			w = maxf(w, hud._font.get_string_size(timer, HORIZONTAL_ALIGNMENT_LEFT, -1, UiTokens.meta(hud.get_viewport_rect().size)).x + 16.0)
		var sp := cam.unproject_position(n3.global_position + Vector3(0, top + 0.35, 0))
		# The box covers what is drawn: tool icons poke 8 px over the pill, a regrow timer hangs under it.
		pending.append({
			"anchor": sp, "w": w, "h": 22.0 + (8.0 if not tools.is_empty() else 0.0) + (20.0 if timer != "" else 0.0), "priority": priority,
			"text": text, "dot": dot, "timer": timer, "tools": tools,
			"a": 1.0 if n3 == radial_node else 1.0 - smoothstep(5.5, 8.0, d),
		})
		shown += 1
	var view := hud.get_viewport_rect().size
	var pill_i := 0
	# The survivor is only stepped away from: a building behind it keeps its label.
	var fig := HudLayout.figure_rect(hud)
	var hard: Array[Rect2] = []
	for x in avoid:
		if x != fig:
			hard.append(x)
	var soft: Array[Rect2] = [fig]
	for item in UiTokens.layout_labels(pending, view, hard, soft):
		var box: Rect2 = item["rect"]
		hud.drawn_blocks["pill%d" % pill_i] = box
		pill_i += 1
		var tools: Array = item["tools"]
		var rect := Rect2(box.position + Vector2(0.0, 8.0 if not tools.is_empty() else 0.0), Vector2(box.size.x, 22.0))
		var a: float = item["a"]
		var text: String = item["text"]
		var dot: Color = item["dot"]
		var bg := UiTokens.INK
		bg.a *= a
		hud.draw_rect(rect, bg)
		hud.draw_circle(Vector2(rect.position.x + 10.0, rect.position.y + 11.0), 4.0, Color(dot.r, dot.g, dot.b, a))
		hud.draw_string(hud._font, Vector2(rect.position.x + 20.0, rect.position.y + 16.0), text, HORIZONTAL_ALIGNMENT_LEFT, rect.size.x - 24.0, 14, Color(1, 1, 1, a))
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
