class_name IngredientChoice
extends RefCounted
## The craft menu's chosen instances per ingredient (spec 13 s19), kept out of CraftUI: which bag
## instances the player picked for each recipe slot of one recipe, the picks Craft sends, and the
## slot that would spend an instance with traits nobody chose. Another recipe starts empty.

## The recipe the choice belongs to.
var rid := ""
## {recipe slot: [uid, or "#<bag slot>" for a stack]}.
var chosen := {}

func set_chosen(inv: Inventory, p_rid: String, i: int, picked: Array) -> void:
	if rid != p_rid:
		chosen = {}
		rid = p_rid
	var keys: Array[String] = []
	for k: Variant in picked:
		var st := inv.slots[int(k)]
		keys.append(st.uid if st.uid != "" else "#%d" % int(k))
	chosen[i] = keys

## Bag slots chosen for recipe slot `i` that are still in the bag; [] when none, or when one left
## (the choice is void and the default applies).
func slots(inv: Inventory, rec: Dictionary, i: int) -> Array[int]:
	var out: Array[int] = []
	if rid != str(rec.get("id", "")) or not chosen.has(i):
		return out
	for key: String in chosen[i]:
		var at := -1
		if key.begins_with("#"):
			var j := int(key.substr(1))
			at = j if j >= 0 and j < inv.slot_count and inv.slots[j] else -1
		else:
			for j in inv.slot_count:
				if inv.slots[j] and inv.slots[j].uid == key:
					at = j
		if at < 0:
			out.clear()
			return out
		out.append(at)
	return out

## What the other recipe slots of `rec` already took (the picker greys them out for slot `i`).
func taken(inv: Inventory, rec: Dictionary, i: int) -> Array:
	var out: Array = []
	for k in chosen.keys() if rid == str(rec.get("id", "")) else []:
		if int(k) != i:
			out.append_array(slots(inv, rec, int(k)))
	return out

## Picks for Craft: the chosen instances where the player chose, the default lead elsewhere;
## [] (the default plan) when nothing is chosen or the choice no longer makes the recipe.
func picks_for(inv: Inventory, rec: Dictionary) -> Array:
	var picks: Array = []
	var any := false
	var defaults := Crafting.default_picks(inv, rec)
	for i in defaults.size():
		var mine := slots(inv, rec, i)
		any = any or not mine.is_empty()
		picks.append(mine if not mine.is_empty() else defaults[i])
	return picks if any and Crafting.picks_valid(inv, rec, picks) else []

## Spec 13 s19 "do not automatically consume the most valuable item": the first recipe slot whose
## default would spend an instance with traits (Inventory.traits) the player did not choose; -1 none.
static func trait_slot(inv: Inventory, rec: Dictionary, picks: Array) -> int:
	var rows := Crafting.plan(inv, rec, picks)
	for i in rows.size():
		if i < picks.size() and picks[i] is Array:
			continue
		for part: Dictionary in rows[i].parts:
			if not Inventory.traits(inv.slots[int(part.idx)]).is_empty():
				return i
	return -1

## One ingredient as a 44 px button: "Berry 1/1", or the chosen instance ("Berry Lv. 25") in the
## selection gold; disabled when short (nothing to choose). `on_press` opens the picker.
func button(inv: Inventory, rec: Dictionary, i: int, sample_id: StringName, nm: String, have: int, need: int, on_press: Callable) -> Button:
	var b := Button.new()
	b.flat = true
	b.focus_mode = Control.FOCUS_ALL
	b.icon = ItemIcons.texture(sample_id)
	b.add_theme_constant_override("icon_max_width", 24)
	b.custom_minimum_size = Vector2(0, UiTokens.TARGET_MIN)
	b.add_theme_font_size_override("font_size", 14)
	var picked := slots(inv, rec, i)
	b.text = "%s %d/%d" % [nm, mini(have, need), need]
	if not picked.is_empty(): # the chosen instance's own art and name (a slot takes several kinds)
		var st := inv.slots[picked[0]]
		b.icon = ItemIcons.texture(st.def_id)
		var cd := st.def()
		var cn := cd.display_name if cd and cd.display_name != "" else LevelDisplay.nice_name(str(st.def_id))
		b.text = ("%s %s" % [cn, LevelDisplay.label(st.level)]) if picked.size() == 1 else ("%s ×%d chosen" % [cn, picked.size()])
	var tone := InvTheme.SELECT if not picked.is_empty() else (Color(0.8, 0.85, 0.75) if have >= need else Color(1.0, 0.55, 0.45))
	for c in ["font_color", "font_hover_color", "font_focus_color", "font_pressed_color"]:
		b.add_theme_color_override(c, tone)
	b.disabled = have < need
	b.tooltip_text = "Choose which ones to use"
	b.pressed.connect(on_press)
	return b
