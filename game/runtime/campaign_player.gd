class_name CampaignPlayer
extends Node
## Coordinates campaign content, stage presentation, state mutation, and Dialogic.

signal episode_started(episode: EpisodeDefinition)
signal episode_transition_requested(episode: EpisodeDefinition)
signal episode_finished(episode: EpisodeDefinition)
signal dialogue_finished(episode: EpisodeDefinition)
signal exit_requested(exit_id: StringName)
signal route_unavailable(exit_id: StringName)
signal campaign_finished
signal campaign_aborted
signal validation_failed(errors: PackedStringArray)
signal integration_warning(message: String)

@export var stage_host: NodePath
@export var dialogic: NodePath
@export var game_state: GameStateStore

var campaign: CampaignDefinition
var current_episode: EpisodeDefinition
var _dialogic_node: Node
var _dialogic_text_subsystem: Node
var _dialogic_background_subsystem: Node
var _assigned_stage_host: StageHost
var _pending_episode: EpisodeDefinition


func _ready() -> void:
	_connect_dialogic()


func _exit_tree() -> void:
	_disconnect_dialogic()


func set_game_state(next_game_state: GameStateStore) -> void:
	game_state = next_game_state


func set_stage_host(next_stage_host: StageHost) -> void:
	_assigned_stage_host = next_stage_host


func set_dialogic(next_dialogic: Node) -> void:
	if _dialogic_node != next_dialogic:
		_disconnect_dialogic()
	_dialogic_node = next_dialogic
	_connect_dialogic()


func start_campaign(next_campaign: CampaignDefinition) -> bool:
	return start_campaign_at(next_campaign)


## Starts a campaign at a specific episode for editor/debug playtesting.
## Passing an empty ID follows the campaign's normal first-episode route.
func start_campaign_at(
	next_campaign: CampaignDefinition,
	episode_id: StringName = &"",
) -> bool:
	if next_campaign == null:
		validation_failed.emit(PackedStringArray(["Cannot start an empty campaign."]))
		return false
	var errors := next_campaign.validate()
	if not errors.is_empty():
		validation_failed.emit(errors)
		return false
	var target_id := episode_id if not episode_id.is_empty() else next_campaign.first_episode_id
	var target_episode := next_campaign.get_episode(target_id)
	if target_episode == null:
		validation_failed.emit(
			PackedStringArray(
				["Campaign '%s' has no episode '%s'." % [next_campaign.id, target_id]],
			),
		)
		return false
	campaign = next_campaign
	_reset_dialogic_history()
	if game_state != null:
		game_state.reset_for_new_game()
	return play_episode(target_episode)


func play_episode(episode: EpisodeDefinition) -> bool:
	if episode == null:
		integration_warning.emit("Cannot play an empty episode.")
		return false
	var host := _get_stage_host()
	if host == null:
		integration_warning.emit("CampaignPlayer needs a StageHost assigned to 'stage_host'.")
		return false
	if (
		episode.show_title_transition
		and not get_signal_connection_list(&"episode_transition_requested").is_empty()
	):
		_pending_episode = episode
		episode_transition_requested.emit(episode)
		return true
	return _begin_episode(episode)


## Called by the application shell after its chapter card has completed.
func continue_pending_episode(episode: EpisodeDefinition) -> bool:
	if episode == null or episode != _pending_episode:
		return false
	_pending_episode = null
	return _begin_episode(episode)


func _begin_episode(episode: EpisodeDefinition) -> bool:
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
	_close_campaign_state()
	campaign_finished.emit()


## Stops an in-progress campaign and its Dialogic timeline. This is distinct
## from finish_campaign(), which is called after Dialogic has already ended.
func abort_campaign() -> void:
	_close_campaign_state()
	var dialogic_handler := _dialogic_node as DialogicGameHandler
	if dialogic_handler != null and dialogic_handler.current_timeline != null:
		await dialogic_handler.end_timeline(true)
	var host := _get_stage_host()
	if host != null:
		host.clear_presentation()
	campaign_aborted.emit()


func _close_campaign_state() -> void:
	if current_episode != null and game_state != null:
		game_state.end_cutscene()
	current_episode = null
	_pending_episode = null


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
	if not is_instance_valid(_dialogic_node):
		if dialogic.is_empty():
			return
		_dialogic_node = get_node_or_null(dialogic)
	if _dialogic_node == null:
		integration_warning.emit("The node assigned to 'dialogic' could not be found.")
		return
	if _dialogic_node.has_signal("timeline_ended") and not _dialogic_node.is_connected("timeline_ended", _on_timeline_ended):
		_dialogic_node.connect("timeline_ended", _on_timeline_ended)
	_connect_dialogic_text()
	_connect_dialogic_backgrounds()


func _connect_dialogic_text() -> void:
	if not is_instance_valid(_dialogic_node):
		return
	if _dialogic_node.has_method("has_subsystem"):
		if not bool(_dialogic_node.call("has_subsystem", "Text")):
			return
	if not _dialogic_node.has_method("get_subsystem"):
		return

	var text_subsystem := _dialogic_node.call("get_subsystem", "Text") as Node
	if not is_instance_valid(text_subsystem):
		return
	if _dialogic_text_subsystem != text_subsystem:
		_disconnect_dialogic_text()
		_dialogic_text_subsystem = text_subsystem
	if (
		_dialogic_text_subsystem.has_signal("about_to_show_text")
		and not _dialogic_text_subsystem.is_connected(
			"about_to_show_text",
			_on_dialogic_text_about_to_show,
		)
	):
		_dialogic_text_subsystem.connect(
			"about_to_show_text",
			_on_dialogic_text_about_to_show,
		)
	if (
		_dialogic_text_subsystem.has_signal("text_started")
		and not _dialogic_text_subsystem.is_connected(
			"text_started",
			_on_dialogic_text_started,
		)
	):
		_dialogic_text_subsystem.connect(
			"text_started",
			_on_dialogic_text_started,
		)
	if (
		_dialogic_text_subsystem.has_signal("text_finished")
		and not _dialogic_text_subsystem.is_connected(
			"text_finished",
			_on_dialogic_text_finished,
		)
	):
		_dialogic_text_subsystem.connect(
			"text_finished",
			_on_dialogic_text_finished,
		)


func _connect_dialogic_backgrounds() -> void:
	if not is_instance_valid(_dialogic_node):
		return
	if _dialogic_node.has_method("has_subsystem"):
		if not bool(_dialogic_node.call("has_subsystem", "Backgrounds")):
			return
	if not _dialogic_node.has_method("get_subsystem"):
		return

	var background_subsystem := _dialogic_node.call("get_subsystem", "Backgrounds") as Node
	if not is_instance_valid(background_subsystem):
		return
	if _dialogic_background_subsystem != background_subsystem:
		_disconnect_dialogic_backgrounds()
		_dialogic_background_subsystem = background_subsystem
	if (
		_dialogic_background_subsystem.has_signal("background_changed")
		and not _dialogic_background_subsystem.is_connected(
			"background_changed",
			_on_dialogic_background_changed,
		)
	):
		_dialogic_background_subsystem.connect(
			"background_changed",
			_on_dialogic_background_changed,
		)


func _disconnect_dialogic() -> void:
	if (
		is_instance_valid(_dialogic_node)
		and _dialogic_node.has_signal("timeline_ended")
		and _dialogic_node.is_connected("timeline_ended", _on_timeline_ended)
	):
		_dialogic_node.disconnect("timeline_ended", _on_timeline_ended)
	_disconnect_dialogic_text()
	_disconnect_dialogic_backgrounds()


func _disconnect_dialogic_text() -> void:
	if (
		is_instance_valid(_dialogic_text_subsystem)
		and _dialogic_text_subsystem.has_signal("about_to_show_text")
		and _dialogic_text_subsystem.is_connected(
			"about_to_show_text",
			_on_dialogic_text_about_to_show,
		)
	):
		_dialogic_text_subsystem.disconnect(
			"about_to_show_text",
			_on_dialogic_text_about_to_show,
		)
	if (
		is_instance_valid(_dialogic_text_subsystem)
		and _dialogic_text_subsystem.has_signal("text_started")
		and _dialogic_text_subsystem.is_connected(
			"text_started",
			_on_dialogic_text_started,
		)
	):
		_dialogic_text_subsystem.disconnect(
			"text_started",
			_on_dialogic_text_started,
		)
	if (
		is_instance_valid(_dialogic_text_subsystem)
		and _dialogic_text_subsystem.has_signal("text_finished")
		and _dialogic_text_subsystem.is_connected(
			"text_finished",
			_on_dialogic_text_finished,
		)
	):
		_dialogic_text_subsystem.disconnect(
			"text_finished",
			_on_dialogic_text_finished,
		)
	_dialogic_text_subsystem = null


func _disconnect_dialogic_backgrounds() -> void:
	if (
		is_instance_valid(_dialogic_background_subsystem)
		and _dialogic_background_subsystem.has_signal("background_changed")
		and _dialogic_background_subsystem.is_connected(
			"background_changed",
			_on_dialogic_background_changed,
		)
	):
		_dialogic_background_subsystem.disconnect(
			"background_changed",
			_on_dialogic_background_changed,
		)
	_dialogic_background_subsystem = null


func _on_dialogic_text_about_to_show(info: Dictionary) -> void:
	var host := _get_stage_host()
	if host != null:
		host.apply_dialogic_text(info)


func _on_dialogic_text_started(info: Dictionary) -> void:
	var host := _get_stage_host()
	if host != null:
		host.start_dialogic_speaking(info)


func _on_dialogic_text_finished(info: Dictionary) -> void:
	var host := _get_stage_host()
	if host != null:
		host.stop_dialogic_speaking(info)


func _on_dialogic_background_changed(info: Dictionary) -> void:
	var host := _get_stage_host()
	if host != null:
		host.apply_dialogic_background(info)


func _reset_dialogic_history() -> void:
	if not is_instance_valid(_dialogic_node) or not _dialogic_node.has_method("get_subsystem"):
		return
	var history := _dialogic_node.call("get_subsystem", "History") as Node
	if history == null:
		return
	history.set("simple_history_content", [])
	if history.has_signal("simple_history_changed"):
		history.emit_signal("simple_history_changed")


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
	var host := _get_stage_host()
	if host != null:
		host.stop_dialogic_speaking({}, true)
	if current_episode == null:
		return
	dialogue_finished.emit(current_episode)
	var automatic_route := _find_route(&"")
	if automatic_route == null:
		finish_campaign()
		return
	advance(automatic_route.exit_id)
