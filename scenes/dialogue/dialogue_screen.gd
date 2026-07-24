extends Control
## Reusable, editor-authored visual-novel screen.
##
## DialogueRunner owns story state. This scene only presents the current node
## and forwards phrase selections back to the runner.

signal dialogue_finished(dialogue_id: String)

const DIALOGUE_RUNNER_SCRIPT := preload("res://scripts/dialogue/dialogue_runner.gd")

@export var show_debug_scores := false

var _runner := DIALOGUE_RUNNER_SCRIPT.new()
var _dialogue_id := ""
var _current_node: Dictionary = {}
var _queued_response: Dictionary = {}

@onready var _scene_label: Label = %SceneLabel
@onready var _budget_label: Label = %BudgetLabel
@onready var _score_label: Label = %ScoreLabel
@onready var _background_texture: TextureRect = %BackgroundTexture
@onready var _background_label: Label = %BackgroundLabel
@onready var _character_label: Label = %CharacterLabel
@onready var _expression_label: Label = %ExpressionLabel
@onready var _speaker_label: Label = %SpeakerLabel
@onready var _dialogue_text: Label = %DialogueText
@onready var _continue_button: Button = %ContinueButton
@onready var _phrase_panel := %PhraseCutPanel
@onready var _music_player: AudioStreamPlayer = %MusicPlayer
@onready var _sfx_player: AudioStreamPlayer = %SfxPlayer


func start_dialogue(path: String) -> void:
	_dialogue_id = ""
	_current_node.clear()
	_queued_response.clear()
	_reset_cues()
	show()
	var load_error := _runner.load_dialogue(path)
	if load_error != OK:
		_show_error("%s\n\n%s" % [
			"Could not load dialogue: %s" % path,
			_runner.last_error(),
		])
		return

	_dialogue_id = _runner.dialogue_id()
	_render(_runner.start())


func _render(node: Dictionary) -> void:
	_current_node = node
	_phrase_panel.hide()
	_update_status()

	if node.is_empty():
		if _runner.last_error().is_empty():
			_finish_dialogue()
		else:
			_show_error(_runner.last_error())
		return

	_apply_visuals(node)
	_apply_audio_cues(node)

	var node_type := String(node.get("type", ""))
	match node_type:
		"line":
			_show_line(node)
		"phrase":
			_show_phrase_choice(node)
		"end":
			_show_ending(node)
		_:
			_show_error("Unknown dialogue node type: %s" % node_type)


func _show_line(node: Dictionary) -> void:
	_set_dialogue_text(
		String(node.get("speaker", "")),
		String(node.get("text", "")),
	)
	_continue_button.text = "Continue"
	_continue_button.show()
	_continue_button.grab_focus()


func _show_phrase_choice(node: Dictionary) -> void:
	var speaker := String(node.get("speaker", ""))
	var prompt := String(node.get("prompt", "Choose which phrases Penny should say."))
	_set_dialogue_text(speaker, prompt)
	_continue_button.hide()

	_phrase_panel.setup(
		node.get("segments", []) as Array,
		int(_runner.state().get("budget", 0)),
		speaker,
		_runner.can_use_pity(),
		_runner.can_use_sponsor(),
	)
	_phrase_panel.show()


func _show_ending(node: Dictionary) -> void:
	_set_dialogue_text(
		String(node.get("speaker", "Narrator")),
		String(node.get("text", "End of scene.")),
	)
	_continue_button.text = "Return to title"
	_continue_button.show()
	_continue_button.grab_focus()


func _set_dialogue_text(speaker: String, text: String) -> void:
	_speaker_label.text = speaker.capitalize()
	_speaker_label.visible = not speaker.is_empty()
	_dialogue_text.text = text


func _apply_visuals(node: Dictionary) -> void:
	var speaker := String(node.get("speaker", ""))
	var expression := String(node.get("expression", "neutral"))

	_character_label.text = speaker.capitalize() if not speaker.is_empty() else "Narrator"
	_expression_label.text = "Expression: %s" % expression.capitalize()

	# A missing background field means "keep the previous background."
	if node.has("background"):
		var background := String(node["background"])
		_background_label.text = (
			"Background: %s" % background.replace("_", " ").capitalize()
			if not background.is_empty()
			else "Background artwork goes here"
		)
		if background.is_empty() or not ResourceLoader.exists(background):
			_background_texture.texture = null
		else:
			_background_texture.texture = load(background) as Texture2D


func _apply_audio_cues(node: Dictionary) -> void:
	if node.has("music"):
		var music_path := String(node["music"])
		if music_path.is_empty():
			_music_player.stop()
			_music_player.stream = null
		elif ResourceLoader.exists(music_path):
			var music := load(music_path) as AudioStream
			if music != null and _music_player.stream != music:
				_music_player.stream = music
				_music_player.play()

	var sfx_path := String(node.get("sfx", ""))
	if not sfx_path.is_empty() and ResourceLoader.exists(sfx_path):
		var sfx := load(sfx_path) as AudioStream
		if sfx != null:
			_sfx_player.stream = sfx
			_sfx_player.play()


func _update_status() -> void:
	var current_state := _runner.state()
	_scene_label.text = _dialogue_id.replace("_", " ").capitalize()
	_budget_label.text = "Budget: $%d" % int(current_state.get("budget", 0))
	_score_label.visible = show_debug_scores
	_score_label.text = "Success: %d    Silly: %d" % [
		int(current_state.get("success", 0)),
		int(current_state.get("silly", 0)),
	]


func _show_error(message: String) -> void:
	push_error(message)
	_current_node = {"type": "end"}
	_set_dialogue_text("Dialogue error", message)
	_continue_button.text = "Return to title"
	_continue_button.show()
	_phrase_panel.hide()


func _finish_dialogue() -> void:
	_queued_response.clear()
	_reset_cues()
	hide()
	dialogue_finished.emit(_dialogue_id)


func _on_continue_button_pressed() -> void:
	if not _queued_response.is_empty():
		var response := _queued_response
		_queued_response = {}
		_render(response)
		return
	if String(_current_node.get("type", "")) == "end":
		_finish_dialogue()
		return
	_render(_runner.advance())


func _on_phrase_cut_panel_resolved(
	kept_ids: Array[String],
	kept_text: String,
	delivery_mode: String,
) -> void:
	_phrase_panel.hide()
	var response := _runner.submit_phrase(kept_ids, delivery_mode)
	if response.is_empty():
		_render(response)
		return

	_queued_response = response
	var selected_speaker := String(_current_node.get("speaker", ""))
	if delivery_mode == "silence":
		selected_speaker = "narrator"
		kept_text = "Penny says nothing."
	_render({
		"type": "line",
		"speaker": selected_speaker,
		"expression": String(_current_node.get("expression", "neutral")),
		"text": kept_text,
	})


func _reset_cues() -> void:
	_background_texture.texture = null
	_background_label.text = "Background artwork goes here"
	_music_player.stop()
	_music_player.stream = null
	_sfx_player.stop()
	_sfx_player.stream = null
