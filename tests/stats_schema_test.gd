extends SceneTree

const GAME_STATE_SCRIPT := preload("res://game/runtime/game_state.gd")
const STATS_PATH := "res://story/stats.json"
const RUNTIME_SERIALIZED_KEYS := [
	"cutscene_budget",
	"cutscene_spent",
	"cutscene_reserved_savings",
	"cutscene_sponsor_credit",
	"cutscene_open",
	"pity_used",
	"sponsor_used",
	"values",
	"story_flags",
]

var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var stats_file := FileAccess.open(STATS_PATH, FileAccess.READ)
	_check(stats_file != null, "The writer stat schema should exist at %s." % STATS_PATH)
	if stats_file == null:
		_finish()
		return

	var parsed: Variant = JSON.parse_string(stats_file.get_as_text())
	_check(parsed is Dictionary, "The writer stat schema should contain a JSON object.")
	if not parsed is Dictionary:
		_finish()
		return

	var raw_stats: Variant = parsed.get("stats")
	_check(raw_stats is Array and not raw_stats.is_empty(), "`stats` should be a nonempty array.")
	if not raw_stats is Array:
		_finish()
		return

	var state: GameStateStore = GAME_STATE_SCRIPT.new()
	var runtime_properties: Dictionary = {}
	for property: Dictionary in state.get_property_list():
		runtime_properties[String(property.get("name", ""))] = true
	var serialized_state := state.to_dictionary()

	var schema_properties: Dictionary = {}
	for raw_stat: Variant in raw_stats:
		if not raw_stat is String:
			_failures.append("Every writer stat must be a dotted string; got %s." % raw_stat)
			continue
		var dotted_name := String(raw_stat)
		var name_parts := dotted_name.split(".", false)
		if name_parts.size() != 2:
			_failures.append("Writer stat `%s` is not a `group.name` path." % dotted_name)
			continue
		var property_name := dotted_name.replace(".", "_")
		if schema_properties.has(property_name):
			_failures.append(
				"Writer stats `%s` and `%s` flatten to the same GameStats property `%s`."
				% [schema_properties[property_name], dotted_name, property_name]
			)
			continue
		schema_properties[property_name] = dotted_name
		_check(
			runtime_properties.has(property_name),
			"`%s` is compiler-visible but GameStateStore has no `%s` property."
			% [dotted_name, property_name],
		)
		_check(
			serialized_state.has(property_name),
			"`%s` exists in the writer schema but GameStateStore does not serialize `%s`."
			% [dotted_name, property_name],
		)

	for raw_key: Variant in serialized_state:
		var serialized_key := String(raw_key)
		if serialized_key in RUNTIME_SERIALIZED_KEYS:
			continue
		_check(
			schema_properties.has(serialized_key),
			"GameStateStore serializes story stat `%s`, but story/stats.json does not declare it."
			% serialized_key,
		)

	state.free()
	_finish()


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _finish() -> void:
	if _failures.is_empty():
		print("Writer stat schema checks passed.")
		quit(0)
		return
	for failure in _failures:
		printerr("FAIL: ", failure)
	quit(1)
