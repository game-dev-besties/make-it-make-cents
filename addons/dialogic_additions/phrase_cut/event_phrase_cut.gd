@tool
class_name DialogicPhraseCutEvent
extends DialogicEvent
## A dialogue line whose phrases the player (the chatbot) can DELETE to save
## the word budget. Compiled from `speaker (expr): [phrase] [phrase|cost] …`
## lines in story/*.md. The phrase segments + costs live in the cutscene's
## sidecar phrases.json, keyed by line_id.
##
## At runtime: set the speaker portrait/expression, open PhraseCutUI, let the
## player toggle phrases off, deduct the kept cost from GameStats, then show
## the assembled sentence and await advance. TODO(editor): validate in-editor.

@export var speaker: String = ""
@export var portrait: String = ""   # expression
@export var line_id: String = ""

var regex := RegEx.create_from_string(r'phrase_cut\s+(?<speaker>\w+)(?:\s*\((?<portrait>[^)]*)\))?\s+(?<line_id>\w+)')


func _init() -> void:
	event_name = "PhraseCut"
	event_description = "A line whose phrases the player can delete to save budget."
	set_default_color('Color2')
	event_category = "Main"
	event_sorting_index = 5
	expand_by_default = false


#region SAVING/LOADING
func to_text() -> String:
	if portrait:
		return "phrase_cut %s (%s) %s" % [speaker, portrait, line_id]
	return "phrase_cut %s %s" % [speaker, line_id]


func from_text(string: String) -> void:
	var r := regex.search(string.strip_edges())
	if not r:
		return
	speaker = r.get_string('speaker')
	portrait = r.get_string('portrait')
	line_id = r.get_string('line_id')


func is_valid_event(string: String) -> bool:
	return string.strip_edges().begins_with("phrase_cut ")
#endregion


#region EXECUTION
func _execute() -> void:
	# dialogic.PhraseCut isn't available (see CutsceneRunner.gd); use get_subsystem() directly.
	var data: Dictionary = dialogic.get_subsystem("PhraseCut").get_data(line_id)
	var segments: Array = data.get("segments", [])
	var min_keep: int = int(data.get("min_keep", 1))

	var character := _resolve_character()
	_apply_speaker(character)

	# Open the phrase-cut overlay.
	var ui := Control.new()
	ui.set_script(preload("res://addons/dialogic_additions/phrase_cut/phrase_cut_ui.gd"))
	_overlay().add_child(ui)
	ui.setup(segments, min_keep, GameStats.remaining_budget(), speaker)
	await ui.resolved
	var result: Dictionary = ui.result
	ui.queue_free()

	# Record which id'd phrases were kept, so the next if/elif can branch on it.
	var known_ids: Array = []
	for seg in segments:
		if seg is Dictionary and seg.get("type") == "phrase" and seg.has("id"):
			known_ids.append(String(seg["id"]))
	PhraseMemory.set_line(known_ids, result.get("kept_ids", []))

	GameStats.spend(int(result.get("cost", 0)))
	_speak(String(result.get("kept_text", "")), character)

	# Wait for the player to advance, then continue the timeline.
	await dialogic.Inputs.dialogic_action
	finish()


func _resolve_character() -> DialogicCharacter:
	if speaker.is_empty() or speaker == "_":
		return null
	var c := DialogicResourceUtil.get_character_resource(speaker)
	if c == null:
		c = DialogicCharacter.new()
		c.display_name = speaker
		c.set_identifier(speaker)
	return c


func _apply_speaker(character: DialogicCharacter) -> void:
	if dialogic.has_subsystem("Portraits") and character:
		dialogic.Portraits.change_speaker(character, portrait)
		if not portrait.is_empty() and dialogic.Portraits.is_character_joined(character):
			dialogic.Portraits.change_character_portrait(character, portrait)
	if dialogic.has_subsystem("Text"):
		dialogic.Text.update_name_label(character)


func _overlay() -> Node:
	if dialogic.has_subsystem("Styles") and dialogic.Styles.has_active_layout_node():
		return dialogic.Styles.get_layout_node()
	return dialogic


func _speak(text: String, character: DialogicCharacter) -> void:
	if not dialogic.has_subsystem("Text") or text.is_empty():
		return
	var final := dialogic.Text.parse_text(text, 0)
	dialogic.Text.about_to_show_text.emit({"text": final, "character": character, "portrait": portrait, "append": false})
	await dialogic.Text.textbox_handle_auto_visibility(final)
	dialogic.Text.update_dialog_text(final, false, false)
	dialogic.Text.text_started.emit({"text": final, "character": character, "portrait": portrait, "append": false})
#endregion
