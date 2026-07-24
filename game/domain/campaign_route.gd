class_name CampaignRoute
extends Resource
## A named exit from an episode to another episode in a campaign.

@export var exit_id: StringName
@export var next_episode_id: StringName
@export var required_state: Dictionary = {}
@export var minimum_budget_enabled := false
@export var minimum_budget := 0


func is_available(game_state: GameStateStore) -> bool:
	if game_state == null:
		return required_state.is_empty() and not minimum_budget_enabled
	if minimum_budget_enabled and game_state.remaining_budget() < minimum_budget:
		return false
	for key in required_state:
		if game_state.get_value(StringName(key)) != required_state[key]:
			return false
	return true


func validate() -> PackedStringArray:
	var errors := PackedStringArray()
	if next_episode_id.is_empty():
		var route_name := String(exit_id) if not exit_id.is_empty() else "automatic"
		errors.append("Route '%s' has no destination episode ID." % route_name)
	return errors
