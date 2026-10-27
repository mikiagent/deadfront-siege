extends RefCounted
## Optional signed percentage traits and their original sources. Values use
## fractions (0.1 means 10 percentage points), not whole percentages.

const VERSION := 1
const EFFECT_CAP := 0.2

## Create one source for an actual material lot. Existing stacks are unchanged
## unless the caller explicitly attaches the returned data to their attributes.
static func create(traits: Array) -> Dictionary:
	var bytes := Crypto.new().generate_random_bytes(16)
	if bytes.size() != 16:
		return {}
	var source := bytes.hex_encode()
	var records: Array[Dictionary] = []
	for value: Variant in traits:
		if not value is Dictionary:
			return {}
		var row: Dictionary = value
		records.append({"id": row.get("id", ""), "value": row.get("value", null), "source": source})
	var lot := {"version": VERSION, "sources": [source], "traits": records}
	return lot if _valid(lot) else {}

## Preserve each contributor. Repeated ancestry is rejected, including when a
## player splits one stack or combines a previous output with an ancestor.
static func combine(a: Dictionary, b: Dictionary) -> Dictionary:
	if not _valid(a) or not _valid(b):
		return {"ok": false, "reason": "invalid lot"}
	var sources: Array = a.sources.duplicate()
	for source: Variant in b.sources:
		if source in sources:
			return {"ok": false, "reason": "shared source"}
		sources.append(source)
	sources.sort()
	var traits: Array = a.traits.duplicate(true)
	traits.append_array(b.traits.duplicate(true))
	traits.sort_custom(func(left: Dictionary, right: Dictionary) -> bool:
		if left.id != right.id:
			return left.id < right.id
		return left.source < right.source)
	return {"ok": true, "lot": {"version": VERSION, "sources": sources, "traits": traits}}

## Positive and negative contributions remain separate: one never cancels the
## other. Caps apply to the displayed effect, not to retained source records.
static func totals(lot: Dictionary) -> Dictionary:
	if not _valid(lot):
		return {}
	var result: Dictionary = {}
	for record: Dictionary in lot.traits:
		var id: String = record.id
		var value: float = float(record.value)
		if not result.has(id):
			result[id] = {"positive": 0.0, "negative": 0.0}
		if value > 0.0:
			result[id].positive = minf(EFFECT_CAP, float(result[id].positive) + value)
		elif value < 0.0:
			result[id].negative = maxf(-EFFECT_CAP, float(result[id].negative) + value)
	return result

static func _valid(lot: Dictionary) -> bool:
	var version: Variant = lot.get("version", null)
	if not (version is int or version is float) or float(version) != float(VERSION):
		return false
	var sources: Variant = lot.get("sources", null)
	var traits: Variant = lot.get("traits", null)
	if not sources is Array or sources.is_empty() or not traits is Array:
		return false
	var seen_sources: Dictionary = {}
	for source: Variant in sources:
		if not source is String or source.is_empty() or seen_sources.has(source):
			return false
		seen_sources[source] = true
	var seen_traits: Dictionary = {}
	for record: Variant in traits:
		if not record is Dictionary:
			return false
		var id: Variant = record.get("id", null)
		var source: Variant = record.get("source", null)
		var value: Variant = record.get("value", null)
		if not id is String or id.is_empty() or not source is String or not seen_sources.has(source):
			return false
		if not (value is int or value is float) or not is_finite(float(value)):
			return false
		var key := JSON.stringify([source, id])
		if seen_traits.has(key):
			return false
		seen_traits[key] = true
	return true
