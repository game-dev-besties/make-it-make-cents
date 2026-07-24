@tool
class_name DialogicPresentationCueEvent
extends DialogicEvent
## Requests a matching animation from the currently mounted story stage.

@export var cue_id: String = ""

var _pattern: RegEx = RegEx.create_from_string(r"presentation_cue\s+(?<cue>[A-Za-z_]\w*)")


func _init() -> void:
	event_name = "Presentation Cue"
	event_description = "Requests a named presentation animation."
	set_default_color("Color5")
	event_category = "Presentation"


func to_text() -> String:
	return "presentation_cue %s" % cue_id


func from_text(text: String) -> void:
	var match: RegExMatch = _pattern.search(text.strip_edges())
	if match != null:
		cue_id = match.get_string("cue")


func is_valid_event(text: String) -> bool:
	return _pattern.search(text.strip_edges()) != null


func _execute() -> void:
	var presentation := dialogic.get_tree().get_first_node_in_group(&"active_story_presentation")
	if presentation != null and presentation.has_method("play_cue"):
		presentation.call("play_cue", StringName(cue_id))
	finish()
