@tool
class_name DialogicSpeakerNameEvent
extends DialogicEvent
## Changes a registered character's player-facing name during a timeline.

@export var character_id: String = ""
@export var display_name: String = ""

var _pattern := RegEx.create_from_string(
	r"^speaker_name\s+(?<character>[A-Za-z_][A-Za-z0-9_-]*)\s+(?<name>.+)\s*$"
)


func _init() -> void:
	event_name = "Set Speaker Name"
	event_description = "Changes a registered character's displayed name."
	set_default_color("Color5")
	event_category = "Presentation"
	disable_editor_button = true


func to_text() -> String:
	return "speaker_name %s %s" % [character_id, JSON.stringify(display_name)]


func from_text(text: String) -> void:
	var match := _pattern.search(text.strip_edges())
	if match == null:
		return
	character_id = match.get_string("character")
	var parsed_name: Variant = JSON.parse_string(match.get_string("name"))
	display_name = String(parsed_name) if parsed_name is String else ""


func is_valid_event(text: String) -> bool:
	var match := _pattern.search(text.strip_edges())
	if match == null:
		return false
	var parsed_name: Variant = JSON.parse_string(match.get_string("name"))
	return parsed_name is String and not String(parsed_name).is_empty()


func _execute() -> void:
	var character := DialogicResourceUtil.get_character_resource(character_id)
	if character == null:
		push_warning("Speaker name change references unknown character '%s'." % character_id)
	else:
		character.display_name = display_name
		if dialogic.has_subsystem("Text"):
			dialogic.Text.update_name_label(character, true)
	finish()
