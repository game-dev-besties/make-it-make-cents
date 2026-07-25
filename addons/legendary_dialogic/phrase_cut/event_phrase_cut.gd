@tool
class_name DialogicPhraseCutEvent
extends DialogicEvent
## A writer-compiled dialogue line whose phrases the player can cut to save
## the per-episode word budget. Its segments are read from the episode's
## generated phrase-data sidecar, keyed by `line_id`.

@export var speaker: String = ""
@export var portrait: String = ""
@export var line_id: String = ""

const PHRASE_CUT_OVERLAY := preload("res://ui/phrase_cut/phrase_cut_overlay.tscn")
const SPONSOR_CREDIT := 3

var regex: RegEx = RegEx.create_from_string(
	r"^phrase_cut\s+(?<speaker>[A-Za-z_][A-Za-z0-9_-]*)(?:\s*\((?<portrait>[^)]*)\))?\s+(?<line_id>[A-Za-z_]\w*)\s*$"
)
var _active_overlay: PhraseCutOverlay
var _active_text_event: DialogicTextEvent


func _init() -> void:
	event_name = "PhraseCut"
	event_description = "A line whose phrases the player can delete to save the word budget."
	set_default_color("Color2")
	event_category = "Main"
	event_sorting_index = 5
	expand_by_default = false
	disable_editor_button = true


func to_text() -> String:
	if portrait:
		return "phrase_cut %s (%s) %s" % [speaker, portrait, line_id]
	return "phrase_cut %s %s" % [speaker, line_id]


func from_text(text: String) -> void:
	var match: RegExMatch = regex.search(text.strip_edges())
	if match == null:
		return
	speaker = match.get_string("speaker")
	portrait = match.get_string("portrait")
	line_id = match.get_string("line_id")


func is_valid_event(text: String) -> bool:
	return regex.search(text.strip_edges()) != null


func _execute() -> void:
	var phrase_cut: DialogicPhraseCutSubsystem = dialogic.get_subsystem("PhraseCut") as DialogicPhraseCutSubsystem
	if phrase_cut == null:
		push_error("PhraseCut event requires the PhraseCut Dialogic subsystem.")
		finish()
		return
	var timeline_path: String = dialogic.current_timeline.resource_path
	phrase_cut.ensure_loaded_for_timeline(timeline_path)
	var data: Dictionary = phrase_cut.get_data(line_id)
	var raw_segments: Variant = data.get("segments", [])
	var segments: Array = raw_segments if raw_segments is Array else []
	if segments.is_empty():
		push_error("PhraseCut line '%s' has no phrase metadata beside '%s'." % [line_id, timeline_path])
		finish()
		return
	var character: DialogicCharacter = _resolve_character()
	_apply_speaker(character)
	_forward_speaker_to_stage(character)

	var game_stats: Node = dialogic.get_node_or_null("/root/GameStats")
	if game_stats == null or not game_stats.has_method("remaining_budget") or not game_stats.has_method("spend"):
		push_error("PhraseCut requires the GameStats autoload with remaining_budget() and spend().")
		finish()
		return

	var ui: PhraseCutOverlay = PHRASE_CUT_OVERLAY.instantiate() as PhraseCutOverlay
	_active_overlay = ui
	_overlay().add_child(ui)
	var budget: int = int(game_stats.call("remaining_budget"))
	var recovery_data: Dictionary = _recovery_data(data)
	var recovery_policy: Dictionary = phrase_cut.consume_recovery_policy()
	var speaker_name := speaker
	if character != null:
		var display_name := character.get_display_name_translated()
		if not display_name.is_empty():
			speaker_name = display_name
	ui.setup(
		segments,
		budget,
		speaker_name,
		{
			"can_use_pity": (
				_policy_allows(recovery_policy, "allow_pity")
				and _recovery_available(game_stats, "can_use_pity")
			),
			"can_use_sponsor": (
				_policy_allows(recovery_policy, "allow_sponsor")
				and _recovery_available(game_stats, "can_use_sponsor")
			),
			"pity_text": String(recovery_data.get("pity_text", PhraseCutOverlay.DEFAULT_PITY_TEXT)),
			"sponsor_text": String(recovery_data.get("sponsor_text", PhraseCutOverlay.DEFAULT_SPONSOR_TEXT)),
		},
	)
	await ui.resolved
	var result: Dictionary = ui.result.duplicate(true)
	ui.queue_free()
	_active_overlay = null

	# Submitting a phrase cut doesn't go through Dialogic's normal advance
	# input, so Auto-Skip's own disable_on_user_input never sees it. Without
	# this, fast-forward would carry straight on into whatever follows.
	if dialogic.has_subsystem("Inputs"):
		dialogic.Inputs.auto_skip.enabled = false

	_apply_delivery(game_stats, result)
	_record_phrase_memory(segments, result)
	var delivered_text := String(result.get("kept_text", ""))
	if not delivered_text.is_empty():
		await _speak_with_dialogic(delivered_text, character)
	finish()


func _clear_state() -> void:
	if is_instance_valid(_active_overlay):
		_active_overlay.queue_free()
	_active_overlay = null
	if _active_text_event != null:
		_active_text_event.call("_clear_state")
		_active_text_event = null


func _resolve_character() -> DialogicCharacter:
	if speaker.is_empty() or speaker == "_":
		return null
	var character: DialogicCharacter = DialogicResourceUtil.get_character_resource(speaker)
	if character == null:
		character = DialogicCharacter.new()
		character.display_name = speaker
		character.set_identifier(speaker)
	return character


func _apply_speaker(character: DialogicCharacter) -> void:
	if dialogic.has_subsystem("Portraits") and character != null:
		dialogic.Portraits.change_speaker(character, portrait)
		if not portrait.is_empty() and dialogic.Portraits.is_character_joined(character):
			dialogic.Portraits.change_character_portrait(character, portrait)
	if dialogic.has_subsystem("Text"):
		dialogic.Text.update_name_label(character)


func _forward_speaker_to_stage(character: DialogicCharacter) -> void:
	if not is_instance_valid(dialogic):
		return
	var tree := dialogic.get_tree()
	if tree == null:
		return
	var stage_host := tree.get_first_node_in_group(&"story_stage_host")
	if stage_host == null or not stage_host.has_method("apply_dialogic_text"):
		return
	stage_host.call(
		"apply_dialogic_text",
		{"character": character, "portrait": portrait},
	)


func _overlay() -> Node:
	if dialogic.has_subsystem("Styles") and dialogic.Styles.has_active_layout_node():
		return dialogic.Styles.get_layout_node()
	return dialogic


func _recovery_data(data: Dictionary) -> Dictionary:
	var raw_recovery: Variant = data.get("recovery", {})
	return raw_recovery if raw_recovery is Dictionary else {}


func _recovery_available(game_stats: Node, method: StringName) -> bool:
	return game_stats.has_method(method) and bool(game_stats.call(method))


func _policy_allows(policy: Dictionary, key: String) -> bool:
	return bool(policy.get(key, true))


func _apply_delivery(game_stats: Node, result: Dictionary) -> void:
	var delivery_mode := StringName(result.get("delivery_mode", PhraseCutOverlay.DELIVERY_NORMAL))
	match delivery_mode:
		PhraseCutOverlay.DELIVERY_NORMAL:
			game_stats.call("spend", maxi(0, int(result.get("cost", 0))))
		PhraseCutOverlay.DELIVERY_PITY:
			if not _consume_recovery(game_stats, "use_pity"):
				_fall_back_to_silence(result)
		PhraseCutOverlay.DELIVERY_SPONSOR:
			if not _consume_recovery(game_stats, "use_sponsor", [SPONSOR_CREDIT]):
				_fall_back_to_silence(result)
			elif game_stats.has_method("apply_sponsor_penalty"):
				game_stats.call("apply_sponsor_penalty", StringName(speaker))


func _consume_recovery(game_stats: Node, method: StringName, arguments: Array = []) -> bool:
	if not game_stats.has_method(method):
		return false
	var response: Variant = game_stats.callv(method, arguments)
	return bool(response) if response is bool else true


func _fall_back_to_silence(result: Dictionary) -> void:
	result["kept_ids"] = []
	result["kept_text"] = ""
	result["delivery_mode"] = PhraseCutOverlay.DELIVERY_SILENCE
	result["cost"] = 0


func _record_phrase_memory(segments: Array, result: Dictionary) -> void:
	var known_ids: Array = []
	for segment_value: Variant in segments:
		if segment_value is Dictionary and segment_value.get("type") == "phrase" and segment_value.has("id"):
			known_ids.append(String(segment_value["id"]))
	var phrase_memory: Node = dialogic.get_node_or_null("/root/PhraseMemory")
	if phrase_memory != null and phrase_memory.has_method("set_line"):
		phrase_memory.call(
			"set_line",
			known_ids,
			result.get("kept_ids", []),
			StringName(result.get("delivery_mode", PhraseCutOverlay.DELIVERY_NORMAL)),
		)


func _speak_with_dialogic(text: String, character: DialogicCharacter) -> void:
	if text.is_empty():
		return
	var text_event := DialogicTextEvent.new()
	_active_text_event = text_event
	text_event.text = text
	text_event.character = character
	text_event.portrait = portrait
	text_event.execute(dialogic)
	await text_event.event_finished
	text_event.call("_clear_state")
	if _active_text_event == text_event:
		_active_text_event = null
