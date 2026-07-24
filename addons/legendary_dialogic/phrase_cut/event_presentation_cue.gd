@tool
class_name DialogicPresentationCueEvent
extends DialogicEvent
## Sends a named animation cue to the currently mounted episode stage.

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
	var tree := dialogic.get_tree() if is_instance_valid(dialogic) else null
	var stage_host := tree.get_first_node_in_group(&"story_stage_host") if tree != null else null
	if stage_host == null:
		push_warning("Presentation cue '%s' has no active StageHost." % cue_id)
	elif not stage_host.has_method("play_cue"):
		push_warning("The active StageHost cannot play presentation cues.")
	else:
		stage_host.call("play_cue", StringName(cue_id))
	finish()
