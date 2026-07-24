@tool
class_name DialogicPhraseCutEvent
extends DialogicEvent
## A legacy compiled dialogue line whose phrases the player can cut to save
## the per-episode word budget. Its segments are read from the adjacent
## `<timeline>.phrases.json` sidecar, keyed by `line_id`.

@export var speaker: String = ""
@export var portrait: String = ""
@export var line_id: String = ""

const PHRASE_CUT_OVERLAY := preload("res://ui/phrase_cut/phrase_cut_overlay.tscn")

var regex: RegEx = RegEx.create_from_string(r"phrase_cut\s+(?<speaker>\w+)(?:\s*\((?<portrait>[^)]*)\))?\s+(?<line_id>\w+)")


func _init() -> void:
	event_name = "PhraseCut"
	event_description = "A line whose phrases the player can delete to save the word budget."
	set_default_color("Color2")
	event_category = "Main"
	event_sorting_index = 5
	expand_by_default = false


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
	return text.strip_edges().begins_with("phrase_cut ")


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
	var min_keep: int = int(data.get("min_keep", 1))
	var character: DialogicCharacter = _resolve_character()
	_apply_speaker(character)

	var game_stats: Node = dialogic.get_node_or_null("/root/GameStats")
	if game_stats == null or not game_stats.has_method("remaining_budget") or not game_stats.has_method("spend"):
		push_error("PhraseCut requires the GameStats autoload with remaining_budget() and spend().")
		finish()
		return

	var ui: PhraseCutOverlay = PHRASE_CUT_OVERLAY.instantiate() as PhraseCutOverlay
	_overlay().add_child(ui)
	var budget: int = int(game_stats.call("remaining_budget"))
	ui.setup(segments, min_keep, budget, speaker)
	await ui.resolved
	var result: Dictionary = ui.result
	ui.queue_free()

	_record_phrase_memory(segments, result)
	game_stats.call("spend", int(result.get("cost", 0)))
	_speak(String(result.get("kept_text", "")), character)
	await dialogic.Inputs.dialogic_action
	finish()


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


func _overlay() -> Node:
	if dialogic.has_subsystem("Styles") and dialogic.Styles.has_active_layout_node():
		return dialogic.Styles.get_layout_node()
	return dialogic


func _record_phrase_memory(segments: Array, result: Dictionary) -> void:
	var known_ids: Array = []
	for segment_value: Variant in segments:
		if segment_value is Dictionary and segment_value.get("type") == "phrase" and segment_value.has("id"):
			known_ids.append(String(segment_value["id"]))
	var phrase_memory: Node = dialogic.get_node_or_null("/root/PhraseMemory")
	if phrase_memory != null and phrase_memory.has_method("set_line"):
		phrase_memory.call("set_line", known_ids, result.get("kept_ids", []))


func _speak(text: String, character: DialogicCharacter) -> void:
	if not dialogic.has_subsystem("Text") or text.is_empty():
		return
	var final_text: String = dialogic.Text.parse_text(text, 0)
	dialogic.Text.about_to_show_text.emit({"text": final_text, "character": character, "portrait": portrait, "append": false})
	await dialogic.Text.textbox_handle_auto_visibility(final_text)
	dialogic.Text.update_dialog_text(final_text, false, false)
	dialogic.Text.text_started.emit({"text": final_text, "character": character, "portrait": portrait, "append": false})
