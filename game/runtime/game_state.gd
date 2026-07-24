class_name GameStateStore
extends Node
## Lightweight, serializable game state. Add this script as an autoload when wiring the app.

signal budget_changed(current_budget: int, previous_budget: int)
signal value_changed(key: StringName, value: Variant)
signal reset_completed

@export var initial_budget := 0

var budget := 0
var money_total_saved := 0
var cutscene_budget := 0
var cutscene_spent := 0

var crush_fondness := 0
var crush_creeped_out := 0
var interviewer_impression := 0
var interviewer_weirded_out := 0
var doctor_patience := 0
var doctor_concern := 0
var son_success := 5
var son_silly := 0
var dad_success := 5
var dad_silly := 0
var grandma_success := 5
var grandma_silly := 0

var _values: Dictionary = {}


func _ready() -> void:
	budget = initial_budget


func reset() -> void:
	var previous_budget := budget
	budget = initial_budget
	_values.clear()
	budget_changed.emit(budget, previous_budget)
	reset_completed.emit()


func reset_for_new_game() -> void:
	reset()
	money_total_saved = 0
	cutscene_budget = 0
	cutscene_spent = 0
	crush_fondness = 0
	crush_creeped_out = 0
	interviewer_impression = 0
	interviewer_weirded_out = 0
	doctor_patience = 0
	doctor_concern = 0
	son_success = 5
	son_silly = 0
	dad_success = 5
	dad_silly = 0
	grandma_success = 5
	grandma_silly = 0


func change_budget(amount: int) -> void:
	var previous_budget := budget
	budget += amount
	if budget != previous_budget:
		budget_changed.emit(budget, previous_budget)


func set_value(key: StringName, value: Variant) -> void:
	_values[key] = value
	value_changed.emit(key, value)


func get_value(key: StringName, fallback: Variant = null) -> Variant:
	return _values.get(key, fallback)


func has_value(key: StringName) -> bool:
	return _values.has(key)


func apply_episode(episode: EpisodeDefinition) -> void:
	if episode == null:
		return
	begin_cutscene(episode.word_budget)
	for key in episode.state_changes:
		set_value(StringName(key), episode.state_changes[key])


func begin_cutscene(next_budget: int) -> void:
	cutscene_budget = next_budget
	cutscene_spent = 0


func spend(amount: int) -> void:
	cutscene_spent += max(0, amount)


func remaining_budget() -> int:
	return cutscene_budget - cutscene_spent


func end_cutscene() -> void:
	money_total_saved += max(0, remaining_budget())


func to_dictionary() -> Dictionary:
	return {
		"budget": budget,
		"values": _values.duplicate(true),
	}


func load_dictionary(data: Dictionary) -> void:
	var previous_budget := budget
	budget = int(data.get("budget", initial_budget))
	var stored_values: Variant = data.get("values")
	var loaded_values: Dictionary = {}
	if stored_values is Dictionary:
		loaded_values = stored_values
	_values = loaded_values.duplicate(true)
	budget_changed.emit(budget, previous_budget)
