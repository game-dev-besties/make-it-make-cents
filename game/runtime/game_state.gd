class_name GameStateStore
extends Node
## Persistent campaign state and the current cutscene's word budget.
##
## The project registers one instance as the `GameStats` autoload. Dialogue
## timelines can read the named stat properties directly while gameplay code
## uses the small budget and recovery API below.

signal budget_changed(current_budget: int, previous_budget: int)
signal value_changed(key: StringName, value: Variant)
signal story_flag_changed(flag_name: StringName, value: Variant, previous_value: Variant)
signal reset_completed

const SPONSOR_SUCCESS_PENALTY := 3
const STORY_FLAGS_PATH := "res://story/flags.json"

var money_total_saved := 0
var cutscene_budget := 0
var cutscene_spent := 0
var cutscene_reserved_savings := 0
## Sponsor-funded words can be spoken, but cannot become family savings.
var cutscene_sponsor_credit := 0

var intro_grandma_praised_for_silence := false
var intro_pills_confiscated := false
var son_success := 5:
	set(value):
		son_success = clampi(value, 1, 10)
var son_silly := 0:
	set(value):
		son_silly = clampi(value, 0, 10)
var dad_success := 5:
	set(value):
		dad_success = clampi(value, 1, 10)
var dad_silly := 0:
	set(value):
		dad_silly = clampi(value, 0, 10)
var grandma_success := 5:
	set(value):
		grandma_success = clampi(value, 1, 10)
var grandma_silly := 0:
	set(value):
		grandma_silly = clampi(value, 0, 10)

var _values: Dictionary = {}
var _story_flags: Dictionary = {}
var _story_flag_definitions: Dictionary = {}
var _story_flag_definitions_loaded := false
var _cutscene_open := false


func reset() -> void:
	reset_for_new_game()


func reset_for_new_game() -> void:
	var previous_budget := remaining_budget()
	money_total_saved = 0
	cutscene_budget = 0
	cutscene_spent = 0
	cutscene_reserved_savings = 0
	cutscene_sponsor_credit = 0
	_cutscene_open = false
	_values.clear()
	_story_flags.clear()
	_ensure_story_flag_definitions()
	intro_grandma_praised_for_silence = false
	intro_pills_confiscated = false
	son_success = 5
	son_silly = 0
	dad_success = 5
	dad_silly = 0
	grandma_success = 5
	grandma_silly = 0
	if previous_budget != 0:
		budget_changed.emit(0, previous_budget)
	reset_completed.emit()


func set_value(key: StringName, value: Variant) -> void:
	_values[key] = value
	value_changed.emit(key, value)


func get_value(key: StringName, fallback: Variant = null) -> Variant:
	return _values.get(key, fallback)


func has_value(key: StringName) -> bool:
	return _values.has(key)


func set_story_flag(flag_name: StringName, value: Variant) -> bool:
	_ensure_story_flag_definitions()
	var name := String(flag_name)
	if not _story_flag_definitions.has(name):
		push_error("Unknown story flag '%s'." % name)
		return false
	if not _story_flag_accepts(name, value):
		push_error(
			"Story flag '%s' does not accept value %s."
			% [name, JSON.stringify(value)]
		)
		return false
	var previous_value: Variant = get_story_flag(flag_name)
	_story_flags[name] = value
	story_flag_changed.emit(flag_name, value, previous_value)
	return true


func get_story_flag(flag_name: StringName, fallback: Variant = null) -> Variant:
	_ensure_story_flag_definitions()
	var name := String(flag_name)
	if _story_flags.has(name):
		return _story_flags[name]
	var definition: Variant = _story_flag_definitions.get(name)
	if definition is Dictionary:
		return definition.get("default", fallback)
	return fallback


func has_story_flag(flag_name: StringName) -> bool:
	_ensure_story_flag_definitions()
	return _story_flag_definitions.has(String(flag_name))


func story_flag_equals(flag_name: StringName, expected: Variant) -> bool:
	return get_story_flag(flag_name) == expected


func describe_story_flag(flag_name: StringName, value: Variant = null) -> String:
	_ensure_story_flag_definitions()
	var name := String(flag_name)
	var definition: Variant = _story_flag_definitions.get(name)
	if not definition is Dictionary:
		return ""
	var described_value: Variant = get_story_flag(flag_name) if value == null else value
	for entry: Variant in definition.get("values", []):
		if (
			entry is Dictionary
			and entry.get("value") == described_value
		):
			return String(entry.get("description", ""))
	return ""


func get_story_flags() -> Dictionary:
	_ensure_story_flag_definitions()
	var result: Dictionary = {}
	for name: Variant in _story_flag_definitions:
		result[name] = get_story_flag(StringName(name))
	return result


func apply_episode(episode: EpisodeDefinition) -> void:
	if episode == null:
		return
	begin_cutscene(episode.word_budget)
	reset_score_for(episode.score_owner)
	for key: Variant in episode.state_changes:
		set_value(StringName(key), episode.state_changes[key])


func reset_score_for(score_owner: StringName) -> bool:
	match score_owner:
		&"son":
			son_success = 5
			son_silly = 0
		&"dad":
			dad_success = 5
			dad_silly = 0
		&"grandma":
			grandma_success = 5
			grandma_silly = 0
		&"":
			return false
		_:
			push_warning("Unknown score owner '%s'." % score_owner)
			return false
	return true


func begin_cutscene(next_budget: int) -> void:
	var previous_budget := remaining_budget()
	cutscene_budget = max(0, next_budget)
	cutscene_spent = 0
	cutscene_reserved_savings = 0
	cutscene_sponsor_credit = 0
	_cutscene_open = true
	if cutscene_budget != previous_budget:
		budget_changed.emit(cutscene_budget, previous_budget)


func spend(amount: int) -> int:
	var previous_budget := remaining_budget()
	var charged: int = mini(maxi(0, amount), previous_budget)
	cutscene_spent += charged
	cutscene_sponsor_credit = maxi(0, cutscene_sponsor_credit - charged)
	if charged > 0:
		budget_changed.emit(remaining_budget(), previous_budget)
	return charged


func add_budget(amount: int) -> int:
	var credit: int = maxi(0, amount)
	if credit == 0:
		return 0
	var previous_budget := remaining_budget()
	cutscene_budget += credit
	budget_changed.emit(remaining_budget(), previous_budget)
	return credit


func set_remaining_budget(amount: int) -> int:
	var previous_budget := remaining_budget()
	var next_budget := maxi(0, amount)
	if next_budget < previous_budget:
		var removed_budget := previous_budget - next_budget
		var removed_sponsor_credit := mini(
			cutscene_sponsor_credit,
			removed_budget,
		)
		cutscene_sponsor_credit -= removed_sponsor_credit
		cutscene_reserved_savings += removed_budget - removed_sponsor_credit
	elif next_budget > previous_budget:
		var released_savings := mini(
			cutscene_reserved_savings,
			next_budget - previous_budget,
		)
		cutscene_reserved_savings -= released_savings
	cutscene_budget = cutscene_spent + next_budget
	cutscene_sponsor_credit = mini(cutscene_sponsor_credit, next_budget)
	if next_budget != previous_budget:
		budget_changed.emit(next_budget, previous_budget)
	return next_budget


func remaining_budget() -> int:
	return max(0, cutscene_budget - cutscene_spent)


func can_use_pity() -> bool:
	return _cutscene_open


func use_pity() -> bool:
	if not can_use_pity():
		return false
	return true


func can_use_sponsor() -> bool:
	return _cutscene_open


func use_sponsor(credit: int) -> bool:
	if not can_use_sponsor():
		return false
	cutscene_sponsor_credit += add_budget(credit)
	return true


func apply_sponsor_penalty(
	speaker: StringName,
	success_delta: int = -SPONSOR_SUCCESS_PENALTY,
) -> bool:
	match String(speaker).to_lower():
		"son", "percy":
			son_success += success_delta
		"dad", "marco":
			dad_success += success_delta
		"grandma", "rosa":
			grandma_success += success_delta
		_:
			return false
	return true


func end_cutscene() -> void:
	if not _cutscene_open:
		return
	var savable_budget := maxi(0, remaining_budget() - cutscene_sponsor_credit)
	money_total_saved += cutscene_reserved_savings + savable_budget
	cutscene_reserved_savings = 0
	cutscene_sponsor_credit = 0
	_cutscene_open = false


func to_dictionary() -> Dictionary:
	return {
		"money_total_saved": money_total_saved,
		"cutscene_budget": cutscene_budget,
		"cutscene_spent": cutscene_spent,
		"cutscene_reserved_savings": cutscene_reserved_savings,
		"cutscene_sponsor_credit": cutscene_sponsor_credit,
		"cutscene_open": _cutscene_open,
		"intro_grandma_praised_for_silence": intro_grandma_praised_for_silence,
		"intro_pills_confiscated": intro_pills_confiscated,
		"son_success": son_success,
		"son_silly": son_silly,
		"dad_success": dad_success,
		"dad_silly": dad_silly,
		"grandma_success": grandma_success,
		"grandma_silly": grandma_silly,
		"values": _values.duplicate(true),
		"story_flags": get_story_flags(),
	}


func load_dictionary(data: Dictionary) -> void:
	var previous_budget := remaining_budget()
	money_total_saved = max(0, int(data.get("money_total_saved", 0)))
	cutscene_budget = max(0, int(data.get("cutscene_budget", data.get("budget", 0))))
	cutscene_spent = clampi(int(data.get("cutscene_spent", 0)), 0, cutscene_budget)
	cutscene_reserved_savings = max(0, int(data.get("cutscene_reserved_savings", 0)))
	cutscene_sponsor_credit = clampi(
		int(data.get("cutscene_sponsor_credit", 0)),
		0,
		remaining_budget(),
	)
	_cutscene_open = bool(data.get("cutscene_open", false))
	intro_grandma_praised_for_silence = bool(
		data.get(
			"intro_grandma_praised_for_silence",
			data.get("grandma_praised_for_silence", false),
		)
	)
	intro_pills_confiscated = bool(
		data.get("intro_pills_confiscated", data.get("pills_confiscated", false))
	)
	son_success = int(data.get("son_success", 5))
	son_silly = int(data.get("son_silly", 0))
	dad_success = int(data.get("dad_success", 5))
	dad_silly = int(data.get("dad_silly", 0))
	grandma_success = int(data.get("grandma_success", 5))
	grandma_silly = int(data.get("grandma_silly", 0))
	var stored_values: Variant = data.get("values")
	var loaded_values: Dictionary = {}
	if stored_values is Dictionary:
		loaded_values = stored_values
	_values = loaded_values.duplicate(true)
	_story_flags.clear()
	_ensure_story_flag_definitions()
	var stored_story_flags: Variant = data.get("story_flags")
	if stored_story_flags is Dictionary:
		for raw_name: Variant in stored_story_flags:
			var name := String(raw_name)
			var value: Variant = stored_story_flags[raw_name]
			if (
				_story_flag_definitions.has(name)
				and _story_flag_accepts(name, value)
			):
				_story_flags[name] = value
	var current_budget := remaining_budget()
	if current_budget != previous_budget:
		budget_changed.emit(current_budget, previous_budget)


func _ensure_story_flag_definitions() -> void:
	if _story_flag_definitions_loaded:
		return
	_story_flag_definitions_loaded = true
	var flags_file := FileAccess.open(STORY_FLAGS_PATH, FileAccess.READ)
	if flags_file == null:
		push_error("Story flag schema could not be opened at %s." % STORY_FLAGS_PATH)
		return
	var parsed: Variant = JSON.parse_string(flags_file.get_as_text())
	if not parsed is Dictionary:
		push_error("Story flag schema must contain a JSON object.")
		return
	var raw_flags: Variant = parsed.get("flags")
	if not raw_flags is Array:
		push_error("Story flag schema needs a `flags` array.")
		return
	for raw_definition: Variant in raw_flags:
		if not raw_definition is Dictionary:
			continue
		var name := String(raw_definition.get("name", ""))
		if name.is_empty():
			continue
		_story_flag_definitions[name] = raw_definition.duplicate(true)


func _story_flag_accepts(flag_name: String, value: Variant) -> bool:
	var definition: Variant = _story_flag_definitions.get(flag_name)
	if not definition is Dictionary:
		return false
	for entry: Variant in definition.get("values", []):
		if entry is Dictionary and entry.get("value") == value:
			return true
	return false
