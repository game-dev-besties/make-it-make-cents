class_name CampaignPlayer
extends Node
## Coordinates campaign content, stage presentation, state mutation, and Dialogic.

signal episode_started(episode: EpisodeDefinition)
signal episode_finished(episode: EpisodeDefinition)
signal dialogue_finished(episode: EpisodeDefinition)
signal exit_requested(exit_id: StringName)
signal route_unavailable(exit_id: StringName)
signal campaign_finished
signal validation_failed(errors: PackedStringArray)
signal integration_warning(message: String)

@export var stage_host: NodePath
@export var dialogic: NodePath
@export var game_state: GameStateStore

var campaign: CampaignDefinition
var current_episode: EpisodeDefinition
var _dialogic_node: Node
var _assigned_stage_host: StageHost


func _ready() -> void:
	_connect_dialogic()


func set_game_state(next_game_state: GameStateStore) -> void:
	game_state = next_game_state


func set_stage_host(next_stage_host: StageHost) -> void:
	_assigned_stage_host = next_stage_host


func set_dialogic(next_dialogic: Node) -> void:
	_dialogic_node = next_dialogic
	_connect_dialogic()


func start_campaign(next_campaign: CampaignDefinition) -> bool:
	if next_campaign == null:
		validation_failed.emit(PackedStringArray(["Cannot start an empty campaign."]))
		return false
	var errors := next_campaign.validate()
	if not errors.is_empty():
		validation_failed.emit(errors)
		return false
	campaign = next_campaign
	if game_state != null:
		game_state.reset_for_new_game()
	return play_episode(campaign.get_episode(campaign.first_episode_id))


func play_episode(episode: EpisodeDefinition) -> bool:
	if episode == null:
		integration_warning.emit("Cannot play an empty episode.")
		return false
	var host := _get_stage_host()
	if host == null:
		integration_warning.emit("CampaignPlayer needs a StageHost assigned to 'stage_host'.")
		return false
	current_episode = episode
	if game_state != null:
		game_state.apply_episode(episode)
	host.show_presentation(episode.presentation_scene)
	episode_started.emit(episode)
	_start_dialogue(episode)
	return true


func request_exit(exit_id: StringName) -> bool:
	if current_episode == null:
		return false
	exit_requested.emit(exit_id)
	return advance(exit_id)


func advance(exit_id: StringName = &"") -> bool:
	if current_episode == null:
		return false
	var route := _find_route(exit_id)
	if route == null:
		route_unavailable.emit(exit_id)
		return false
	episode_finished.emit(current_episode)
	if game_state != null:
		game_state.end_cutscene()
	var next_episode := campaign.get_episode(route.next_episode_id) if campaign != null else null
	if next_episode == null:
		integration_warning.emit("Route '%s' has no playable destination." % route.exit_id)
		return false
	return play_episode(next_episode)


func finish_campaign() -> void:
	if current_episode != null and game_state != null:
		game_state.end_cutscene()
	current_episode = null
	campaign_finished.emit()


func validate_campaign_definition(definition: CampaignDefinition = campaign) -> PackedStringArray:
	if definition == null:
		return PackedStringArray(["No campaign has been supplied."])
	return definition.validate()


func _find_route(exit_id: StringName) -> CampaignRoute:
	for route in current_episode.routes:
		if route != null and route.exit_id == exit_id and route.is_available(game_state):
			return route
	return null


func _get_stage_host() -> StageHost:
	if is_instance_valid(_assigned_stage_host):
		return _assigned_stage_host
	if stage_host.is_empty():
		return null
	return get_node_or_null(stage_host) as StageHost


func _connect_dialogic() -> void:
	if _dialogic_node == null:
		if dialogic.is_empty():
			return
		_dialogic_node = get_node_or_null(dialogic)
	if _dialogic_node == null:
		integration_warning.emit("The node assigned to 'dialogic' could not be found.")
		return
	if _dialogic_node.has_signal("timeline_ended") and not _dialogic_node.is_connected("timeline_ended", _on_timeline_ended):
		_dialogic_node.connect("timeline_ended", _on_timeline_ended)


func _start_dialogue(episode: EpisodeDefinition) -> void:
	if episode.dialogue_timeline_path.is_empty():
		integration_warning.emit("Episode '%s' has no dialogue timeline." % episode.id)
		_on_timeline_ended()
		return
	if _dialogic_node == null:
		_connect_dialogic()
	if _dialogic_node == null or not _dialogic_node.has_method("start"):
		integration_warning.emit("Dialogic is unavailable; episode '%s' is staged without dialogue." % episode.id)
		return
	_load_phrase_data(episode)
	_dialogic_node.call("start", episode.dialogue_timeline_path)


func _load_phrase_data(episode: EpisodeDefinition) -> void:
	if episode.phrase_data_path.is_empty() or _dialogic_node == null:
		return
	if not _dialogic_node.has_method("get_subsystem"):
		return
	var subsystem: Variant = _dialogic_node.call("get_subsystem", "PhraseCut")
	if subsystem != null and subsystem.has_method("load_for"):
		subsystem.call(
			"load_for",
			episode.phrase_data_path,
			episode.dialogue_timeline_path,
		)


func _on_timeline_ended() -> void:
	if current_episode == null:
		return
	dialogue_finished.emit(current_episode)
	var automatic_route := _find_route(&"")
	if automatic_route == null:
		finish_campaign()
		return
	advance(automatic_route.exit_id)
