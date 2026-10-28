class_name MarketRow
extends Button
## One row of a market list: ONE instance (owner rule: items never stack). Icon, gold name with a
## grey type line under it, "Lv. n", "cur/max" durability and the price with a coin, or a note in
## place of the price (spec 14 listing table). Selected rows get the GOLD wash and corner brackets.

var v: Dictionary = {} ## the row view (MarketRow.view_of): icon, name, type, level, dur, price, note
var cols := PackedFloat32Array([0.55, 0.70, 0.85]) ## Lv / durability / price column starts, as width fractions
var px := 18 ## name size; the type line and columns follow it
var picked := false:
	set(b):
		picked = b
		queue_redraw()

func _init(p_view: Dictionary = {}) -> void:
	v = p_view
	flat = true
	focus_mode = Control.FOCUS_ALL
	clip_contents = true
	var empty := StyleBoxEmpty.new()
	for s in ["normal", "hover", "pressed", "focus", "disabled", "hover_pressed"]:
		add_theme_stylebox_override(s, empty)

## The row view of an economy asset dict (bag row, vault row or listing asset). `price` < 0 shows
## `note` instead. Pets are "B <Species>" (bonded), cages "Captured <Species>", as the references.
static func view_of(asset: Dictionary, price: int = -1, note: String = "") -> Dictionary:
	var out := {"price": price, "note": note, "uid": str(asset.get("uid", "")), "asset": asset}
	if asset.has("species"): # a bonded pet
		var sp := str(asset.species)
		out.merge({"icon": &"captured_animal", "name": "B " + _species_name(sp), "type": "Bonded animal",
			"level": int(asset.get("level", 1)), "dur": "—", "pet": true})
		return out
	var id := StringName(str(asset.get("id", "")))
	var def: ItemDef = Data.item(id)
	var name := def.display_name if def else str(id).capitalize()
	var type_line := str(def.categories[0]).capitalize() if def and not def.categories.is_empty() else ""
	var sp := str((asset.get("attributes", {}) as Dictionary).get("species", ""))
	if str(id) == "captured_animal" and sp != "":
		name = "Captured " + _species_name(sp)
		type_line = _species_name(sp)
	var dmax := int(asset.get("max_durability", def.max_durability if def else 0)) # an instance carries its own max
	var t := str((asset.get("attributes", {}) as Dictionary).get("tint", ""))
	out.merge({"icon": id, "name": name, "type": type_line, "level": int(asset.get("level", 1)),
		"dur": "%d/%d" % [int(asset.get("durability", dmax)), dmax] if dmax > 0 else "—", "pet": false,
		"tint": Color(t) if t.begins_with("#") and t.length() >= 7 else Color.WHITE})
	return out

static func _species_name(sp: String) -> String:
	var c: CreatureDef = Data.creature(StringName(sp))
	return c.species if c and c.species != "" else sp.capitalize()

## Trait chips for the instance (spec §5): attribute keys, flags. ASSUMPTION: polarity data does not
## exist yet (spec §9 q2), so every chip reads negative-grey except "flawless" (positive).
static func traits_of(asset: Dictionary) -> Array:
	var out: Array = []
	var attrs: Dictionary = asset.get("attributes", {})
	for k: String in attrs:
		if k in ["species", "level", "tint"]: # instance facts shown elsewhere (name, Lv., icon colour), not traits
			continue
		var val: Variant = attrs[k]
		out.append([("%s Lv. %d" % [k.capitalize(), int(val)]) if (val is int or val is float) else k.capitalize(), &"negative"])
	for f in asset.get("flags", []):
		out.append([str(f).capitalize(), &"positive" if str(f) == "flawless" else &"negative"])
	return out

func _draw() -> void:
	var r := Rect2(Vector2.ZERO, size)
	var hover := is_hovered() or has_focus()
	if picked:
		draw_rect(r, UiTokens.GOLD_DIM)
	elif hover:
		draw_rect(r, Color(1, 1, 1, 0.04))
	# fine dotted separator under the row (the Bag / references)
	var x := 0.0
	while x < size.x:
		draw_line(Vector2(x, size.y - 1), Vector2(minf(x + 3, size.x), size.y - 1), Color(UiTokens.DIVIDER, 0.6))
		x += 7.0
	var f := UiTokens.ui_face()
	var fb := UiTokens.ui_face(UiTokens.WEIGHT_BOLD)
	var small := maxi(UiTokens.TYPE_MIN, px - 5)
	var pad := 12.0
	var ic := minf(size.y - 16.0, px * 2.6)
	var tex := ItemIcons.texture(StringName(str(v.get("icon", ""))))
	if tex:
		draw_texture_rect(tex, Rect2(pad, (size.y - ic) * 0.5, ic, ic), false, v.get("tint", Color.WHITE)) # natural colour (spec 35)
	var tx := pad * 2 + ic
	var name_w := size.x * cols[0] - tx - pad
	var name_col := UiTokens.GOLD if not disabled else UiTokens.MUTED
	var has_type := str(v.get("type", "")) != ""
	var name_y := size.y * (0.46 if has_type else 0.5) + px * 0.35
	draw_string(fb, Vector2(tx, name_y), UiTokens.ellipsis(fb, str(v.get("name", "")), name_w, px), HORIZONTAL_ALIGNMENT_LEFT, -1, px, name_col)
	if has_type:
		draw_string(f, Vector2(tx, name_y + small + 6), UiTokens.ellipsis(f, str(v.type), name_w, small), HORIZONTAL_ALIGNMENT_LEFT, -1, small, UiTokens.MUTED)
	var mid := size.y * 0.5 + px * 0.35
	var lv := int(v.get("level", 1))
	_col(f, 0, ("Lv. %d" % lv) if lv > 0 else "—", mid, UiTokens.TEXT)
	_col(f, 1, str(v.get("dur", "—")), mid, UiTokens.TEXT)
	var price := int(v.get("price", -1))
	if price >= 0:
		var t := _num(price)
		var w := f.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x
		var cx := size.x - pad - w - px * 0.9
		MarketRow.draw_coin(self, Vector2(cx, size.y * 0.5), px * 0.42)
		draw_string(f, Vector2(size.x - pad - w, mid), t, HORIZONTAL_ALIGNMENT_LEFT, -1, px, UiTokens.TEXT)
	elif str(v.get("note", "")) != "":
		var w2 := size.x * (1.0 - cols[2]) - pad
		var n := UiTokens.ellipsis(f, str(v.note), w2, small)
		draw_string(f, Vector2(size.x - pad - f.get_string_size(n, HORIZONTAL_ALIGNMENT_LEFT, -1, small).x, mid), n, HORIZONTAL_ALIGNMENT_LEFT, -1, small, UiTokens.META)
	if picked:
		UiTokens.draw_brackets(self, r.grow(-2.0), UiTokens.GOLD, minf(UiTokens.BRACKET_ARM, size.y * 0.3))

func _col(f: Font, i: int, t: String, y: float, c: Color) -> void:
	var x0 := size.x * cols[i]
	var x1 := size.x * (cols[i + 1] if i + 1 < cols.size() else 1.0)
	var w := f.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x
	draw_string(f, Vector2(x0 + (x1 - x0 - w) * 0.5, y), t, HORIZONTAL_ALIGNMENT_LEFT, -1, px, c)

## The T-stone coin: a small gold disc with a darker ring (no glyph font needed).
static func draw_coin(ci: CanvasItem, c: Vector2, r: float) -> void:
	ci.draw_circle(c, r, UiTokens.GOLD)
	ci.draw_arc(c, r * 0.62, 0, TAU, 20, UiTokens.CTA_INK, maxf(1.0, r * 0.18), true)

## 27927 -> "27,927"
static func _num(n: int) -> String:
	var s := str(absi(n))
	var out := ""
	while s.length() > 3:
		out = "," + s.right(3) + out
		s = s.left(s.length() - 3)
	return ("-" if n < 0 else "") + s + out
