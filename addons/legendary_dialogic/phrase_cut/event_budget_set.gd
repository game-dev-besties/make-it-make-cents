@tool
class_name DialogicBudgetSetEvent
extends DialogicEvent
## Sets the exact number of taxed words available for the current cutscene.

@export_range(0, 100000, 1, "or_greater") var amount := 0

var _pattern := RegEx.create_from_string(r"^budget_set\s+(?<amount>\d+)\s*$")


func _init() -> void:
	event_name = "Set Word Budget"
	event_description = "Sets the exact remaining word budget for the current cutscene."
	set_default_color("Color3")
	event_category = "Gameplay"
	disable_editor_button = true


func to_text() -> String:
	return "budget_set %d" % amount


func from_text(text: String) -> void:
	var match := _pattern.search(text.strip_edges())
	if match != null:
		amount = int(match.get_string("amount"))


func is_valid_event(text: String) -> bool:
	return _pattern.search(text.strip_edges()) != null


func _execute() -> void:
	var game_stats := dialogic.get_node_or_null("/root/GameStats")
	if game_stats == null or not game_stats.has_method("set_remaining_budget"):
		push_error("BudgetSet requires the GameStats autoload with set_remaining_budget().")
	else:
		game_stats.call("set_remaining_budget", amount)
	finish()
