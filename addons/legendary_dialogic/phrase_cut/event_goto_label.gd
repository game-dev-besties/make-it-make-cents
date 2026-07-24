@tool
class_name DialogicGotoLabelEvent
extends DialogicEvent
## Jumps to a label in the current timeline without adding a return-stack entry.

@export var label_name := ""

var _pattern := RegEx.create_from_string(
	r"^goto_label\s+(?<label>[A-Za-z_][A-Za-z0-9_]*)\s*$"
)


func _init() -> void:
	event_name = "Go To Label"
	event_description = "Loops to a local label without adding a Dialogic return point."
	set_default_color("Color4")
	event_category = "Flow"
	disable_editor_button = true


func to_text() -> String:
	return "goto_label %s" % label_name


func from_text(text: String) -> void:
	var match := _pattern.search(text.strip_edges())
	if match != null:
		label_name = match.get_string("label")


func is_valid_event(text: String) -> bool:
	return _pattern.search(text.strip_edges()) != null


func _execute() -> void:
	if dialogic == null or not dialogic.has_subsystem("Jump"):
		push_error("GotoLabel requires Dialogic's Jump subsystem.")
	else:
		dialogic.Jump.jump_to_label(label_name)
	finish()
