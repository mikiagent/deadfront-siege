extends SceneTree
## GAUNTLET.md "Binding product rules" as literals. Expected values come from the rule text,
## never from the code under test (a 60 s cooldown used to pass because the test read it back).
## Run: godot --headless --path game --script res://tests/t_rules.gd

const PET_DEATH_COOLDOWN_S := 180.0  # "3-minute death cooldown in Animals UI"
const ACTIVE_PETS := 3               # "Unlimited owned animals; three equipped/active"
const CAPTURE_BELOW_HP := 0.30       # "knocked out **and under 30% HP**"

var _r: LabResult
var _done := false

## Pet and taming classes reference the Data autoload, which --script does not create before
## _init, so the checks run on the first frame that has it (same pattern as run_all.gd).
func _process(_delta: float) -> bool:
	if _done:
		return true
	if get_root() == null or get_root().get_node_or_null("Data") == null:
		return false
	_done = true
	_r = LabResult.new("t_rules")
	# Loaded here, not named in the body: their scripts reference autoloads at compile time.
	var rec: Object = (load("res://scripts/pets/pet_record.gd") as GDScript).new()
	rec.call("start_respawn")
	var cooldown := float(rec.get("respawn_left"))
	_r.expect(is_equal_approx(cooldown, PET_DEATH_COOLDOWN_S),
		"pet death cooldown %.0f s, GAUNTLET says %.0f s" % [cooldown, PET_DEATH_COOLDOWN_S])
	var active := int((load("res://scripts/player/player.gd") as GDScript).get_script_constant_map().get("MAX_PETS_OUT", -1))
	_r.expect(active == ACTIVE_PETS, "active pet cap %d, GAUNTLET says %d" % [active, ACTIVE_PETS])
	var tame := load("res://scripts/pets/field_tame.gd") as GDScript
	_r.expect(bool(tame.call("health_allows_capture", CAPTURE_BELOW_HP - 0.001)), "capture refused just under 30 % HP")
	_r.expect(not bool(tame.call("health_allows_capture", CAPTURE_BELOW_HP)), "capture allowed at exactly 30 % HP")
	_r.expect(not bool(tame.call("health_allows_capture", 0.5)), "capture allowed at 50 % HP")
	_r.finish(self, "cooldown=%.0fs active=%d capture<%.0f%%" % [PET_DEATH_COOLDOWN_S, ACTIVE_PETS, CAPTURE_BELOW_HP * 100.0])
	return false
