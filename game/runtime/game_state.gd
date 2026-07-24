class_name GameStateStore
extends Node
## Persistent campaign state and the current cutscene's word budget.
##
## The project registers one instance as the `GameStats` autoload. Dialogue
## timelines can read the named stat properties directly while gameplay code
## uses the small budget and recovery API below.

signal budget_changed(current_budget: int, previous_budget: int)
signal value_changed(key: StringName, value: Variant)
signal reset_completed

const SPONSOR_SUCCESS_PENALTY := 3

var money_total_saved := 0
var cutscene_budget := 0
var cutscene_spent := 0
var pity_used := false
var sponsor_used := false

var crush_fondness := 0
var crush_creeped_out := 0
var interviewer_impression := 0
var interviewer_weirded_out := 0
var doctor_patience := 0
var doctor_concern := 0
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
var _cutscene_open := false


func reset() -> void:
	reset_for_new_game()


func reset_for_new_game() -> void:
	var previous_budget := remaining_budget()
	money_total_saved = 0
	cutscene_budget = 0
	cutscene_spent = 0
	pity_used = false
	sponsor_used = false
	_cutscene_open = false
	_values.clear()
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


func apply_episode(episode: EpisodeDefinition) -> void:
	if episode == null:
		return
	begin_cutscene(episode.word_budget)
	for key in episode.state_changes:
		set_value(StringName(key), episode.state_changes[key])


func begin_cutscene(next_budget: int) -> void:
	var previous_budget := remaining_budget()
	cutscene_budget = max(0, next_budget)
	cutscene_spent = 0
	pity_used = false
	sponsor_used = false
	_cutscene_open = true
	if cutscene_budget != previous_budget:
		budget_changed.emit(cutscene_budget, previous_budget)


func spend(amount: int) -> int:
	var previous_budget := remaining_budget()
	var charged: int = mini(maxi(0, amount), previous_budget)
	cutscene_spent += charged
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


func remaining_budget() -> int:
	return max(0, cutscene_budget - cutscene_spent)


func can_use_pity() -> bool:
	return _cutscene_open and remaining_budget() == 0 and not pity_used


func use_pity() -> bool:
	if not can_use_pity():
		return false
	pity_used = true
	return true


func can_use_sponsor() -> bool:
	return _cutscene_open and remaining_budget() == 0 and not sponsor_used


func use_sponsor(credit: int) -> bool:
	if not can_use_sponsor():
		return false
	sponsor_used = true
	add_budget(credit)
	return true


func apply_sponsor_penalty(speaker: StringName) -> bool:
	match String(speaker).to_lower():
		"son", "leo":
			son_success -= SPONSOR_SUCCESS_PENALTY
		"dad", "marco":
			dad_success -= SPONSOR_SUCCESS_PENALTY
		"grandma", "rosa":
			grandma_success -= SPONSOR_SUCCESS_PENALTY
		_:
			return false
	return true


func end_cutscene() -> void:
	if not _cutscene_open:
		return
	money_total_saved += max(0, remaining_budget())
	_cutscene_open = false


func to_dictionary() -> Dictionary:
	return {
		"money_total_saved": money_total_saved,
		"cutscene_budget": cutscene_budget,
		"cutscene_spent": cutscene_spent,
		"cutscene_open": _cutscene_open,
		"pity_used": pity_used,
		"sponsor_used": sponsor_used,
		"crush_fondness": crush_fondness,
		"crush_creeped_out": crush_creeped_out,
		"interviewer_impression": interviewer_impression,
		"interviewer_weirded_out": interviewer_weirded_out,
		"doctor_patience": doctor_patience,
		"doctor_concern": doctor_concern,
		"son_success": son_success,
		"son_silly": son_silly,
		"dad_success": dad_success,
		"dad_silly": dad_silly,
		"grandma_success": grandma_success,
		"grandma_silly": grandma_silly,
		"values": _values.duplicate(true),
	}


func load_dictionary(data: Dictionary) -> void:
	var previous_budget := remaining_budget()
	money_total_saved = max(0, int(data.get("money_total_saved", 0)))
	cutscene_budget = max(0, int(data.get("cutscene_budget", data.get("budget", 0))))
	cutscene_spent = clampi(int(data.get("cutscene_spent", 0)), 0, cutscene_budget)
	_cutscene_open = bool(data.get("cutscene_open", false))
	pity_used = bool(data.get("pity_used", false))
	sponsor_used = bool(data.get("sponsor_used", false))
	crush_fondness = int(data.get("crush_fondness", 0))
	crush_creeped_out = int(data.get("crush_creeped_out", 0))
	interviewer_impression = int(data.get("interviewer_impression", 0))
	interviewer_weirded_out = int(data.get("interviewer_weirded_out", 0))
	doctor_patience = int(data.get("doctor_patience", 0))
	doctor_concern = int(data.get("doctor_concern", 0))
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
	var current_budget := remaining_budget()
	if current_budget != previous_budget:
		budget_changed.emit(current_budget, previous_budget)
