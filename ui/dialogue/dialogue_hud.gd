@tool
class_name DialogueHud
extends Control

## Small, engine-independent dialogue presentation.  It can be driven by a
## Dialogic adapter or previewed in the editor through its exported fields.

@export_category("Preview")
@export var speaker_name := "Narrator":
	set(value):
		speaker_name = value
		_refresh()

@export_multiline var dialogue_text := "The evening is waiting.":
	set(value):
		dialogue_text = value
		_refresh()

@export var advance_hint := "Click or press Space":
	set(value):
		advance_hint = value
		_refresh()

@onready var _speaker: Label = %Speaker
@onready var _line: RichTextLabel = %Line
@onready var _hint: Label = %AdvanceHint


func _ready() -> void:
	_refresh()


func show_line(new_speaker: String, new_text: String) -> void:
	speaker_name = new_speaker
	dialogue_text = new_text
	show()


func clear_line() -> void:
	hide()


func _refresh() -> void:
	if not is_instance_valid(_speaker):
		return
	_speaker.text = speaker_name
	_line.text = dialogue_text
	_hint.text = advance_hint
